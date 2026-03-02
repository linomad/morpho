import Foundation

enum AXAttributeStringDecoder {
    static func decode(_ value: CFTypeRef?) -> String? {
        guard let value else {
            return nil
        }

        if CFGetTypeID(value) == CFStringGetTypeID() {
            return value as? String
        }

        if let attributed = value as? NSAttributedString {
            return attributed.string
        }

        if let url = value as? URL {
            return url.absoluteString
        }

        if let nsURL = value as? NSURL {
            return nsURL.absoluteString
        }

        return nil
    }
}
