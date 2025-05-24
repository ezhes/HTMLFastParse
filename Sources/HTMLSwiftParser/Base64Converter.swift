import Foundation

internal enum Base64Converter {

    // Encodes a UTF-8 string to a Base64 encoded string
    internal static func encode(string: String) -> String? {
        guard let data = string.data(using: .utf8) else {
            return nil // Or handle error appropriately
        }
        return data.base64EncodedString()
    }

    // Encodes Data to a Base64 encoded string
    internal static func encode(data: Data) -> String {
        return data.base64EncodedString()
    }

    // Decodes a Base64 encoded string to a UTF-8 string
    internal static func decode(base64String: String) -> String? {
        guard let data = Data(base64Encoded: base64String) else {
            return nil // Or handle error appropriately
        }
        return String(data: data, encoding: .utf8)
    }

    // Decodes a Base64 encoded string to Data
    internal static func decodeToData(base64String: String) -> Data? {
        return Data(base64Encoded: base64String)
    }
}
