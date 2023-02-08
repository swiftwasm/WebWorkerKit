import JavaScriptKit
import Distributed

public class WebWorkerCallEncoder: DistributedTargetInvocationEncoder, @unchecked Sendable {
    public typealias SerializationRequirement = WebWorkerActorSystem.SerializationRequirement

    var genericSubs: [String] = []
    var argumentData: [JSValue] = []
    var transfer: [JSValue] = []

    public func recordGenericSubstitution<T>(_ type: T.Type) throws {
        if let name = _mangledTypeName(T.self) {
            genericSubs.append(name)
        }
    }

    public func recordArgument<Value: SerializationRequirement>(_ argument: RemoteCallArgument<Value>) throws {
        let jsValue = try JSValueEncoder().encode(argument.value)
        if let transferable = argument.value as? WebWorkerTransferable {
            transferable.webWorkerTransfer(transfer: &self.transfer)
        }
        self.argumentData.append(jsValue)
    }

    public func recordReturnType<R: SerializationRequirement>(_ type: R.Type) throws {}
    public func recordErrorType<E: Error>(_ type: E.Type) throws {}
    public func doneRecording() throws {}
}
