import Foundation

// Corresponds to the bitmask in t_format->formatTag
internal struct TextFormattingOptions: OptionSet {
    internal let rawValue: UInt8

    internal init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    internal static let bold          = TextFormattingOptions(rawValue: 1 << 0)
    internal static let italics       = TextFormattingOptions(rawValue: 1 << 1)
    internal static let strikethrough = TextFormattingOptions(rawValue: 1 << 2) // "struck" in C
    internal static let code          = TextFormattingOptions(rawValue: 1 << 3)
    // Heading level will be handled by a separate property in TextFormat,
    // as an OptionSet isn't ideal for a multi-bit value like h_level.
}

internal struct TextFormat {
    internal var options: TextFormattingOptions
    internal var headingLevel: UInt8 // Max value would depend on the mask in C (FORMAT_TAG_H_MASK)
                                  // FORMAT_TAG_H_LEVEL_OFFSET = 4
                                  // FORMAT_TAG_H_MASK = ((1<<4) - 1) = 15. So, 0-15. UInt8 is fine.
    
    internal var exponentLevel: UInt8
    internal var quoteLevel: UInt8
    internal var listNestLevel: UInt8
    internal var linkURL: String? // Changed from char* to String?

    internal var startPosition: UInt32
    internal var endPosition: UInt32

    // Initializer
    internal init(options: TextFormattingOptions = [],
                headingLevel: UInt8 = 0,
                exponentLevel: UInt8 = 0,
                quoteLevel: UInt8 = 0,
                listNestLevel: UInt8 = 0,
                linkURL: String? = nil,
                startPosition: UInt32,
                endPosition: UInt32) {
        self.options = options
        self.headingLevel = headingLevel
        self.exponentLevel = exponentLevel
        self.quoteLevel = quoteLevel
        self.listNestLevel = listNestLevel
        self.linkURL = linkURL
        self.startPosition = startPosition
        self.endPosition = endPosition
    }

    // Convenience methods to check options, similar to C macros
    internal var isBold: Bool {
        return options.contains(.bold)
    }

    internal var isItalics: Bool {
        return options.contains(.italics)
    }

    internal var isStrikethrough: Bool {
        return options.contains(.strikethrough)
    }

    internal var isCode: Bool {
        return options.contains(.code)
    }

    // Method to extract heading level from the C formatTag char, if needed during translation
    // The C MACROS are:
    // #define FORMAT_TAG_H_LEVEL_OFFSET    4
    // #define FORMAT_TAG_H_MASK ((1<<FORMAT_TAG_H_LEVEL_OFFSET) - 1) -> (16-1) = 15
    // #define FORMAT_TAG_GET_H_LEVEL(v) (((v) >> (FORMAT_TAG_H_LEVEL_OFFSET)) & (FORMAT_TAG_H_MASK))
    internal static func getHeadingLevel(from formatTag: UInt8) -> UInt8 {
        let hLevelOffset = 4
        let hMask = (1 << hLevelOffset) - 1 // This is 15
        return (formatTag >> hLevelOffset) & UInt8(hMask)
    }
    
    // Method to extract options from the C formatTag char
    internal static func getOptions(from formatTag: UInt8) -> TextFormattingOptions {
        var opts = TextFormattingOptions()
        if (formatTag & (1 << 0)) != 0 { opts.insert(.bold) }
        if (formatTag & (1 << 1)) != 0 { opts.insert(.italics) }
        if (formatTag & (1 << 2)) != 0 { opts.insert(.strikethrough) }
        if (formatTag & (1 << 3)) != 0 { opts.insert(.code) }
        return opts
    }
}

extension TextFormat: Equatable {
    internal static func == (lhs: TextFormat, rhs: TextFormat) -> Bool {
        // startPosition and endPosition are not compared as they define the range,
        // not the style itself.
        return lhs.options == rhs.options &&
               lhs.headingLevel == rhs.headingLevel &&
               lhs.exponentLevel == rhs.exponentLevel &&
               lhs.quoteLevel == rhs.quoteLevel &&
               lhs.listNestLevel == rhs.listNestLevel &&
               lhs.linkURL == rhs.linkURL
    }
}
