import JavaScriptKit
import Distributed

public protocol WebWorker: DistributedActor where ActorSystem == WebWorkerActorSystem, Self: Hashable {
    init(actorSystem: ActorSystem)

    /// Set a custom URL to initialize the web worker instance by.
    /// Defaults to the scriptPath the host (main thread) was loaded in.
    static var scriptPath: String? { get }

    /// Whether to load the worker script defined by `scriptPath` as an es-module
    static var isModule: Bool { get }
}

extension DistributedActor where ActorSystem == WebWorkerActorSystem {
    public static func new() throws -> Self {
        return try! Self.resolve(
            id: .singleton(for: Self.self),
            using: .shared
        )
    }
}
