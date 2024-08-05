# WebWorkerKit

This library allows you to control a WebWorker using Swift's `distributed actor` feature. It abstracts away the creation of the WebWorker itself, and allows you to communicate between "threads" in pure Swift, calling back and forth between them with any Codable, Sendable types (as required by `distributed actor`).

It is used by [flowkey](https://www.flowkey.com)'s Web App to run realtime Audio DSP and ML in a background thread, so it is built with performance in mind.


## Usage Example

```main.swift
import WebWorkerKit

WebWorkerActorSystem.initialize() // important! sets up connection between WebWorkers and Main JS context (main thread).

if !WebWorkerActorSystem.thisProcessIsAWebWorker {
    doNormalMainWork()
}

// Runs on "main thread" (main JS context)
func doNormalMainWork() async throws {
    let myWorker = try MyDistributedActorWorker.new()
    let result = try await myWorker.doWork() // work will be performed within the Web Worker
    // ... use result ...
}
```

```MyDistributedActorWorker.swift
import WebWorkerKit

public struct SomeWorkResult: Codable, Sendable { // Codable, Sendable is important
    init(_ intermediateResults: Whatever) {...}
    // ...
}

distributed actor MyDistributedActorWorker: WebWorker {
    /// The JavaScript script URL to run that starts the (Swift Wasm) worker. Unless you know what you're doing, this *should* be `nil`.
    /// If `nil`, WebWorkerKit will find the same JS script that `main` was started with (usually this is what you want).
    static let scriptPath: String? = nil

    /// Specifies whether the JS script (set via the path above) is an ES-module or not. With WebWorkers, this needs to be set explicitly.
    static let isModule = false

    public distributed func doWork() async throws -> SomeWorkResult {
        let intermediateResults = try await calculateIntermediateResults() // this happens inside the web worker
        return SomeSendableWorkType(intermediateResults) // returned to "main" JS context
    }
}
```

## Bundling

When `WebWorkerKit` starts a new worker (via `MyDistributedActorWorker.new()`), it starts a new instance of the JS bundle it was created with. i.e. It creates a WebWorker and loads `main.swift` again via JS. That's why it's important to wrap any "main thread only" work in `if !WebWorkerActorSystem.thisProcessIsAWebWorker` to avoid duplication.

For that to work efficiently and smoothly, you'll need a JS bundle that loads and starts your Swift Wasm application, and nothing else. Carton and other simple bundlers will do this for you automatically – in those cases the entry point to your entire application *is* the Swift Wasm main bundle.

To integrate WebWorkerKit into a web app that is not written in 100% Swift Wasm, configure your bundler to create a separate JS bundle (entry point) for just the Swift part of your app. That should be enough to ensure that only the Swift part will load when a second instance of the Swift bundle is created, and not the entire web app (which would likely fail due to missing APIs in the WebWorker JS context).


## Known Limitations

flowkey's use case only requires a single, singleton, web worker instance per `WebWorker` type. Disallowing multiple separate `actor` instances is _not_ a technical limitation, we just didn't need it ourselves. We'd consider PRs that add that feature, provided the current functionality still remains.


## Future Experiments / Possibilities

It's currently untested and unsupported, but rather than reusing the _same_ JS+Wasm bundle, it's probably possible to use this library to create _separate_ Swift bundles that are loaded asynchronously and independently (e.g. for a plugin system). In theory this just requires the `WebWorker`-conforming `distributed actor` type to be available and binary compatible in both bundles.

To achieve this, you'd need to set the `scriptPath` static to the JS entrypoint that loads the separate Swift Wasm bundle.

Let me know if you get this working and I'll give you a shoutout from this README.
