import JavaScriptKit

private let ArrayConstructor = JSObject.global.Array.function!
private let ObjectConstructor = JSObject.global.Object.function!

// TODO: Move this to JavaScriptKit
public struct JSValueEncoder {
    public init() {}
    public func encode<T: Encodable>(_ value: T) throws -> JSValue {
        // Fast paths.
        // Without these, `Codable` will try to encode each value of the array
        // individually, which is orders of magnitudes slower.
        switch value {
        case let value as JSValue:
            return value
        case let value as [Double]:
            return JSTypedArray(value).jsValue
        case let value as [Float]:
            return JSTypedArray(value).jsValue
        case let value as [Int]:
            return JSTypedArray(value).jsValue
        case let value as [UInt]:
            return JSTypedArray(value).jsValue
        case let value as ConvertibleToJSValue:
            return value.jsValue
        default: break
        }

        let encoder = JSValueEncoderImpl(codingPath: [])
        try value.encode(to: encoder)
        return encoder.value
    }
}

private class JSValueEncoderImpl {
    let codingPath: [CodingKey]
    var value: JSValue = .undefined
    var userInfo: [CodingUserInfoKey : Any] = [:]

    init(codingPath: [CodingKey]) {
        self.codingPath = codingPath
    }
}

extension JSValueEncoderImpl: Encoder {
    func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        self.value = .object(ObjectConstructor.new())
        return KeyedEncodingContainer(JSObjectKeyedEncodingContainer<Key>(encoder: self))
    }

    func singleValueContainer() -> SingleValueEncodingContainer {
        return SingleJSValueEncodingContainer(encoder: self)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        self.value = .object(ArrayConstructor.new())
        return JSUnkeyedEncodingContainer(encoder: self)
    }
}

private struct JSObjectKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {
    var codingPath: [CodingKey] {
        return encoder.codingPath
    }

    let encoder: JSValueEncoderImpl
    init(encoder: JSValueEncoderImpl) {
        self.encoder = encoder
    }

    func encodeNil(forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .null
    }

    func encode(_ value: Bool, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .boolean(value)
    }

    func encode(_ value: String, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .string(value)
    }

    func encode(_ value: Double, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: Float, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: Int, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: Int8, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: Int16, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: Int32, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: Int64, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: UInt, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: UInt8, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: UInt16, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: UInt32, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode(_ value: UInt64, forKey key: Key) throws {
        encoder.value[dynamicMember: key.stringValue] = .number(Double(value))
    }

    func encode<T>(_ value: T, forKey key: Key) throws where T : Encodable {
        encoder.value[dynamicMember: key.stringValue] = try JSValueEncoder().encode(value)
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
    {
        let nestedEncoder = JSValueEncoderImpl(codingPath: encoder.codingPath)
        let container = JSObjectKeyedEncodingContainer<NestedKey>(encoder: nestedEncoder)
        nestedEncoder.value = .object(ObjectConstructor.new())
        encoder.value[dynamicMember: key.stringValue] = nestedEncoder.value
        return KeyedEncodingContainer(container)
    }

    func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
        preconditionFailure("??")
    }

    func superEncoder() -> Encoder {
        preconditionFailure("??")
    }

    func superEncoder(forKey key: Key) -> Encoder {
        preconditionFailure("??")
    }
}

private struct JSUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    var codingPath: [CodingKey] { encoder.codingPath }

    let encoder: JSValueEncoderImpl
    init(encoder: JSValueEncoderImpl) {
        self.encoder = encoder
    }

    func nestedContainer<NestedKey>(keyedBy keyType: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey : CodingKey
    {
        let encoder = JSValueEncoderImpl(codingPath: self.codingPath)
        return KeyedEncodingContainer(
            JSObjectKeyedEncodingContainer<NestedKey>(encoder: encoder)
        )
    }

    func superEncoder() -> Encoder {
        preconditionFailure("??")
    }

    func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let newEncoder = JSValueEncoderImpl(codingPath: codingPath) // TODO add index to codingPath
        newEncoder.value = .object(ArrayConstructor.new())
        return JSUnkeyedEncodingContainer(encoder: newEncoder)
    }

    var count: Int { Int(encoder.value.length.number!) }

    func encodeNil() throws {
        _ = encoder.value.push(JSValue.null)
    }

    func encode(_ value: Bool) throws {
        _ = encoder.value.push(JSValue.boolean(value))
    }

    func encode(_ value: String) throws {
        _ = encoder.value.push(JSValue.string(value))
    }

    func encode(_ value: Double) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: Float) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: Int) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: Int8) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: Int16) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: Int32) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: Int64) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: UInt) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: UInt8) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: UInt16) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: UInt32) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode(_ value: UInt64) throws {
        _ = encoder.value.push(JSValue.number(Double(value)))
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        let newEncoder = JSValueEncoderImpl(codingPath: []) // TODO: coding path?
        try value.encode(to: newEncoder)
        _ = encoder.value.push(newEncoder.value)
    }
}

private struct SingleJSValueEncodingContainer: SingleValueEncodingContainer {
    var codingPath: [CodingKey] { encoder.codingPath }
    let encoder: JSValueEncoderImpl
    init(encoder: JSValueEncoderImpl) {
        self.encoder = encoder
    }

    func encode<T>(_ value: T) throws where T: Encodable {
        encoder.value = try JSValueEncoder().encode(value)
    }

    public func encode(_ value: Bool) throws {
        encoder.value = .boolean(value)
    }

    public func encode(_ value: String) throws {
        encoder.value = .string(value)
    }

    public func encode(_ value: Double) throws {
        encoder.value = .number(value)
    }

    public func encode(_ value: Float) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: Int) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: Int8) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: Int16) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: Int32) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: Int64) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: UInt) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: UInt8) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: UInt16) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: UInt32) throws {
        encoder.value = .number(Double(value))
    }

    public func encode(_ value: UInt64) throws {
        encoder.value = .number(Double(value))
    }

    public func encodeNil() throws {
        encoder.value = .null
    }
}
