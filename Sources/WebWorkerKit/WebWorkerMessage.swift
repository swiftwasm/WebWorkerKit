import JavaScriptKit

enum WebWorkerMessageError: Error {
    case invalidMessageType(String?)
    case unableToDecode(JSValue)
}

enum WebWorkerMessage: ConvertibleToJSValue {
    case processReady
    case remoteCall(RemoteCallEnvelope)
    case reply(ReplyEnvelope)
    case initialize(id: WebWorkerIdentity)

    init(jsValue data: JSValue) throws {
        guard let stringMessageType = data[0].string else {
            throw WebWorkerMessageError.invalidMessageType(nil)
        }

        switch stringMessageType {
        case "initialize":
            let id = try JSValueDecoder().decode(WebWorkerIdentity.self, from: data[1])
            self = .initialize(id: id)
        case "remoteCall":
            let decoder = JSValueDecoder()
            guard
                let callID = data[1].callID.number,
                let invocationTarget = data[1].invocationTarget.string,
                let args = JSArray(from: data[1].args)
            else {
                throw WebWorkerMessageError.unableToDecode(data[1])
            }

            let genericSubs = try decoder.decode([String].self, from: data[1].genericSubs)
            let recipient = try decoder.decode(WebWorkerActorSystem.ActorID.self, from: data[1].recipient)

            let remoteCallEnvelope = RemoteCallEnvelope(
                callID: WebWorkerActorSystem.CallID(callID),
                recipient: recipient,
                invocationTarget: invocationTarget,
                genericSubs: genericSubs,
                args: args.map { $0 }
            )

            self = .remoteCall(remoteCallEnvelope)
        case "reply":
            guard let callID = data[1].callID.number else {
                throw WebWorkerMessageError.unableToDecode(data[1])
            }

            let decoder = JSValueDecoder()
            let replyEnvelope = ReplyEnvelope(
                callID: WebWorkerActorSystem.CallID(callID),
                sender: try? decoder.decode(WebWorkerIdentity.self, from: data[1].sender),
                value: data[1].value
            )

            self = .reply(replyEnvelope)
        case "processReady":
            self = .processReady
        default:
            throw WebWorkerMessageError.invalidMessageType(stringMessageType)
        }
    }

    var jsValue: JSValue {
        let encoder = JSValueEncoder()
        switch self {
        case .remoteCall(let callEnvelope):
            let recipient = try? encoder.encode(callEnvelope.recipient)
            let callEnvelope = [
                "callID": callEnvelope.callID,
                "genericSubs": callEnvelope.genericSubs,
                "invocationTarget": callEnvelope.invocationTarget,
                "args": callEnvelope.args,
                "recipient": recipient
            ].jsValue

            return ["remoteCall", callEnvelope].jsValue

        case .processReady:
            return ["processReady"].jsValue

        case .reply(let payload):
            let sender = try? encoder.encode(payload.sender)
            let replyEnvelope = [
                "callID": payload.callID,
                "sender": sender,
                "value": payload.value
            ].jsValue

            return ["reply", replyEnvelope].jsValue

        case .initialize(id: let payload):
            let id = try! encoder.encode(payload)
            return ["initialize", id].jsValue
        }
    }
}
