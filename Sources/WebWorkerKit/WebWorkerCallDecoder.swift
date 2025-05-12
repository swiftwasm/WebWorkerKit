import JavaScriptKit
import Distributed

final public class WebWorkerCallDecoder: DistributedTargetInvocationDecoder {
    enum Error: Swift.Error {
        case notEnoughArguments(expected: Codable.Type)
    }

    public typealias SerializationRequirement = Codable

    let decoder: JSValueDecoder
    let envelope: RemoteCallEnvelope
    var argumentsIterator: Array<JSValue>.Iterator

    init(system: WebWorkerActorSystem, envelope: RemoteCallEnvelope) {
        self.envelope = envelope
        self.argumentsIterator = envelope.args.makeIterator()

        let decoder = JSValueDecoder()
        self.decoder = decoder
    }

    public func decodeGenericSubstitutions() throws -> [Any.Type] {
        envelope.genericSubs.compactMap(_typeByName)
    }

    public func decodeNextArgument<Argument: Codable>() throws -> Argument {
        guard let data = argumentsIterator.next() else {
            throw Error.notEnoughArguments(expected: Argument.self)
        }

        return try decoder.decode(Argument.self, from: data)
    }

    public func decodeErrorType() throws -> Any.Type? {
        nil // not encoded, ok
    }

    public func decodeReturnType() throws -> Any.Type? {
        nil // not encoded, ok
    }
}
