import Distributed
import JavaScriptKit

extension WebWorkerActorSystem {
    public func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error,
          Res: SerializationRequirement
    {
        guard let replyData = try await withCallIDContinuation(recipient: actor, body: { callID in
            self.sendRemoteCall(to: actor, target: target, invocation: invocation, callID: callID)
        }) else {
            fatalError("Expected replyData but got `nil`")
        }

        do {
            let decoder = JSValueDecoder()
            return try decoder.decode(Res.self, from: replyData)
        } catch {
            assertionFailure("remoteCall: failed to decode response")
            fatalError()
        }
    }

    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error
    {
        _ = try await withCallIDContinuation(recipient: actor) { callID in
            self.sendRemoteCall(to: actor, target: target, invocation: invocation, callID: callID)
        }
    }

    private func withCallIDContinuation<Act>(recipient: Act, body: (CallID) -> Void) async throws -> JSValue?
        where Act: DistributedActor
    {
        try await withCheckedThrowingContinuation { continuation in
            let callID = Int.random(in: Int.min ..< Int.max)
            self.inFlightCalls[callID] = continuation
            body(callID)
        }
    }

    private func sendRemoteCall<Act>(
        to actor: Act,
        target: RemoteCallTarget,
        invocation: InvocationEncoder,
        callID: CallID
    )
        where Act: DistributedActor, Act.ID == ActorID
    {
        Task {
            let callEnvelope = RemoteCallEnvelope(
                callID: callID,
                recipient: actor.id,
                invocationTarget: target.identifier,
                genericSubs: invocation.genericSubs,
                args: invocation.argumentData
            )

            guard let childWorker = childWorkers[actor.id] else {
                fatalError("Invalid target")
            }

            childWorker.postMessage(.remoteCall(callEnvelope), transfer: invocation.transfer)
        }
    }
}

public struct RemoteCallEnvelope: @unchecked Sendable {
    let callID: WebWorkerActorSystem.CallID
    let recipient: WebWorkerActorSystem.ActorID
    let invocationTarget: String
    let genericSubs: [String]
    let args: [JSValue]
}
