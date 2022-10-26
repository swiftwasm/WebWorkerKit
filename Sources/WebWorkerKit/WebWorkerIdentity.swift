import Distributed

public struct WebWorkerIdentity: Sendable, Hashable, Codable {
    let typeName: String

    private init(typeName: String) {
        self.typeName = typeName
    }

    internal static func singleton(for type: any DistributedActor.Type) -> WebWorkerIdentity {
        return WebWorkerIdentity.init(typeName: _mangledTypeName(type.self)!)
    }

    internal func createActor(actorSystem: WebWorkerActorSystem) -> (any WebWorker)? {
        guard let daType = _typeByName(self.typeName) as? (any WebWorker.Type) else {
            return nil
        }

        return daType.init(actorSystem: actorSystem)
    }
}
