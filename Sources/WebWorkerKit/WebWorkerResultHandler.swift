import JavaScriptKit
import Distributed

public protocol WebWorkerTransferable {
    func webWorkerTransfer(transfer: inout [JSValue])
}

public struct WebWorkerResultHandler: DistributedTargetInvocationResultHandler {
    public typealias SerializationRequirement = WebWorkerActorSystem.SerializationRequirement

    let callID: WebWorkerActorSystem.CallID
    let system: WebWorkerActorSystem

    public func onReturn<Success: SerializationRequirement>(value: Success) async throws {
        let encoded = try JSValueEncoder().encode(value)
        var transfer: [JSValue] = []
        if let transferable = value as? WebWorkerTransferable {
            transferable.webWorkerTransfer(transfer: &transfer)
        }
        let envelope = ReplyEnvelope(callID: self.callID, sender: nil, value: encoded)
        try system.sendReply(envelope, transfer: transfer)
    }

    public func onReturnVoid() async throws {
        let envelope = ReplyEnvelope(callID: self.callID, sender: nil, value: nil)
        try system.sendReply(envelope)
    }

    public func onThrow<Err: Error>(error: Err) async throws {
        print("onThrow: \(error)")
    }
}
