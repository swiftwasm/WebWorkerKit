import JavaScriptKit
import Distributed
import JavaScriptEventLoop

private let rawPostMessageToHost = JSObject.global.postMessage.function!
private func postMessageToHost(_ message: WebWorkerMessage, transfer: [JSValue] = []) {
    rawPostMessageToHost(message, transfer)
}

final public class WebWorkerActorSystem: DistributedActorSystem, Sendable {
    public static let thisProcessIsAWebWorker = JSObject.global.importScripts.function != nil
    public static let shared: WebWorkerActorSystem = .init()
    public static func initialize() {
        // Necessary to use `Task`, `await`, etc.
        JavaScriptEventLoop.installGlobalExecutor()

        _ = Self.shared // initialize the singleton
    }

    public typealias ResultHandler = WebWorkerResultHandler
    public typealias ActorID = WebWorkerIdentity
    public typealias InvocationEncoder = WebWorkerCallEncoder
    public typealias InvocationDecoder = WebWorkerCallDecoder
    public typealias SerializationRequirement = Codable

    public typealias CallID = Int
    var inFlightCalls: [CallID: CheckedContinuation<JSValue?, Error>] = [:]

    var incomingMessageClosure: JSClosure?
    deinit {
        incomingMessageClosure?.release()
    }

    init() {
        // This closure receives messages from the host if we are a worker,
        // but it also receives messages back from the worker, if we are the host!
        let incomingMessageClosure = JSClosure { [weak self] args -> JSValue in
            let event = args[0]
            let message: WebWorkerMessage
            do {
                message = try WebWorkerMessage(jsValue: event.data)
            } catch {
                assertionFailure("incomingMessageClosure: Unable to decode message: \(error)")
                return .undefined
            }

            switch message {
            case .processReady:
                guard let worker = self?.childWorkers.first(where: { $1.matchesJSObject(event.currentTarget.object) }) else {
                    preconditionFailure("Received message from an unknown child worker!")
                    break
                }

                worker.value.isReady = true
            case .remoteCall(let callEnvelope):
                self?.receiveInboundCall(envelope: callEnvelope)
            case .reply(let replyEnvelope):
                self?.receiveInboundReply(envelope: replyEnvelope)
            case .initialize(id: let id):
                guard let actorSystem = self else {
                    break
                }

                id.createActor(actorSystem: actorSystem)
            }

            return .undefined
        }

        if Self.thisProcessIsAWebWorker {
            JSObject.global.onmessage = .object(incomingMessageClosure)
        } else {
            // We put this listener onto the WebWorkerHost.
            // We don't need to assign a global listener in this case.
        }

        self.incomingMessageClosure = incomingMessageClosure
        postMessageToHost(.processReady)
    }

    /// actors managed by the current process / address space
    var managedWorkers = [ActorID: any DistributedActor]()

    /// references to actors in child processes
    var childWorkers = [ActorID: WebWorkerHost]()

    public func actorReady<Act>(_ actor: Act) where Act: DistributedActor, ActorID == Act.ID {
        if managedWorkers[actor.id] != nil {
            fatalError("Currently only a single instance of a DistributedActor is allowed per type")
        }

        managedWorkers[actor.id] = actor

        // retrieve dead letter queue
        deadLetterQueue = deadLetterQueue.filter { envelope in
            let letterIsForThisActor = envelope.recipient == actor.id
            if letterIsForThisActor {
                receiveInboundCall(envelope: envelope)
            }

            return !letterIsForThisActor // remove processed messages from queue
        }
    }

    public func makeInvocationEncoder() -> WebWorkerCallEncoder {
        return WebWorkerCallEncoder()
    }

    public func resolve<Act>(id: WebWorkerIdentity, as actorType: Act.Type) throws -> Act? where Act : DistributedActor, ActorID == Act.ID {
        if let actor = managedWorkers[id] as? Act {
            return actor
        }

        if childWorkers[id] != nil {
            // We already have a child worker for this ID
            // We can continue to use it as we did before
            return nil
        }

        let (scriptPath, isModule) = getScriptDetails(for: Act.self)

        let childWorker = try WebWorkerHost(scriptPath: scriptPath, isModule: isModule)
        childWorker.incomingMessageClosure = incomingMessageClosure
        childWorker.postMessage(.initialize(id: id))
        childWorkers[id] = childWorker

        return nil
    }

    public func assignID<Act>(_ actorType: Act.Type) -> ActorID
        where Act: DistributedActor, ActorID == Act.ID
    {
        return .singleton(for: actorType.self)
    }

    public func resignID(_ id: ActorID) {
        print("resignID: \(id)")
        guard let managedWorker = managedWorkers[id] else {
            fatalError("Tried to resign ID of an actor that doesn't exist")
        }

        // TODO: terminate
//        childWorkers[id]

        managedWorkers.removeValue(forKey: id)
    }

    func sendReply(_ envelope: ReplyEnvelope, transfer: [JSValue] = []) throws {
        postMessageToHost(.reply(envelope), transfer: transfer)
    }

    private var deadLetterQueue = [RemoteCallEnvelope]()
    func receiveInboundCall(envelope: RemoteCallEnvelope) {
        Task {
            guard let anyRecipient = managedWorkers[envelope.recipient] else {
                deadLetterQueue.append(envelope)
                return
            }

            let target = RemoteCallTarget(envelope.invocationTarget)
            let handler = Self.ResultHandler(callID: envelope.callID, system: self)

            do {
                var decoder = Self.InvocationDecoder(system: self, envelope: envelope)
                func doExecuteDistributedTarget<Act: DistributedActor>(recipient: Act) async throws {
                    try await executeDistributedTarget(
                        on: recipient,
                        target: target,
                        invocationDecoder: &decoder,
                        handler: handler)
                }

                // As implicit opening of existential becomes part of the language,
                // this underscored feature is no longer necessary. Please refer to
                // SE-352 Implicitly Opened Existentials:
                // https://github.com/apple/swift-evolution/blob/main/proposals/0352-implicit-open-existentials.md
                try await _openExistential(anyRecipient, do: doExecuteDistributedTarget)
            } catch {
                print("failed to executeDistributedTarget [\(target)] on [\(anyRecipient)], error: \(error)")
                try! await handler.onThrow(error: error)
            }
        }
    }

    func receiveInboundReply(envelope: ReplyEnvelope) {
        guard let callContinuation = self.inFlightCalls.removeValue(forKey: envelope.callID) else {
            return
        }

        callContinuation.resume(returning: envelope.value)
    }
}

private func getScriptDetails(for Act: any DistributedActor.Type) -> (scriptPath: String, isModule: Bool) {
    let defaultScriptPath = CommandLine.arguments.first ?? ""

    func getScriptInfo<Act: WebWorker>(recipient: Act.Type) -> (scriptPath: String, isModule: Bool) {
        let scriptPath = recipient.scriptPath ?? defaultScriptPath
        let isModule = recipient.isModule
        return (scriptPath, isModule)
    }

    if let Act = Act.self as? any WebWorker.Type {
        return _openExistential(Act, do: getScriptInfo)
    } else {
        return (defaultScriptPath, false)
    }
}

public struct ReplyEnvelope: @unchecked Sendable {
    let callID: WebWorkerActorSystem.CallID
    let sender: WebWorkerActorSystem.ActorID?
    let value: JSValue?
}
