import JavaScriptKit
import Distributed
#if canImport(Darwin)
import func Darwin.getenv
#elseif canImport(Glibc)
import func Glibc.getenv
#elseif canImport(WASILibc)
import func WASILibc.getenv
#endif

enum WebWorkerHostError: Error {
    case unableToLoad(scriptPath: String, isModule: Bool)
}

/// Handles communication between worker and host (usually the main thread, but could be a worker itself)
internal class WebWorkerHost {
    private let jsObject: JSObject

    func matchesJSObject(_ otherObject: JSObject?) -> Bool {
        return self.jsObject == otherObject
    }

    var isReady = false {
        didSet {
            if isReady == false && oldValue == true {
                fatalError("Worker can become 'ready', but not 'not ready' again")
            }

            if isReady {
                queuedMessages.forEach { message in
                    postMessage(message)
                }
            }
        }
    }

    var incomingMessageClosure: JSClosure? {
        didSet {
            jsObject.onmessage = incomingMessageClosure.map { .object($0) } ?? .undefined
        }
    }

    init(scriptPath: String, isModule: Bool) throws {
        guard let jsObject = JSObject.global.Worker.function?.new(
            scriptPath,
            isModule ? ["type": "module"] : JSValue.undefined
        ) else {
            throw WebWorkerHostError.unableToLoad(
                scriptPath: scriptPath,
                isModule: isModule
            )
        }

        self.jsObject = jsObject
    }

    private var queuedMessages = [WebWorkerMessage]()
    func postMessage(_ message: WebWorkerMessage) {
        if isReady {
            _ = jsObject.postMessage!(message)
        } else {
            queuedMessages.append(message)
        }
    }
}
