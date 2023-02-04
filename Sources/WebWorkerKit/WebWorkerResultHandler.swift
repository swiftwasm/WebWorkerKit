import JavaScriptKit
import Distributed

public struct WebWorkerResultHandler: DistributedTargetInvocationResultHandler {
    public typealias SerializationRequirement = WebWorkerActorSystem.SerializationRequirement

    let callID: WebWorkerActorSystem.CallID
    let system: WebWorkerActorSystem

    public func onReturn<Success: SerializationRequirement>(value: Success) async throws {
        let encoded = try JSValueEncoder().encode(value)
        let envelope = ReplyEnvelope(callID: self.callID, sender: nil, value: encoded)
        try system.sendReply(envelope)
    }

    public func onReturnVoid() async throws {
        let envelope = ReplyEnvelope(callID: self.callID, sender: nil, value: nil)
        try system.sendReply(envelope)
    }

    public func onThrow<Err: Error>(error: Err) async throws {
        print("onThrow: \(error)")
    }
}
