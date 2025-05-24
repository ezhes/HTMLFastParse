import UIKit // For UIFont, UIColor, NSAttributedString etc.

public class HTMLAttributedStringConverter {

    // Font properties
    private var plainFont: UIFont!
    private var boldFont: UIFont!
    private var italicsFont: UIFont!
    private var italicsBoldFont: UIFont!
    private var codeFont: UIFont!

    // Color properties
    private var defaultFontColor: UIColor
    private let codeFontColor: UIColor
    private let containerBackgroundColor: UIColor
    private let quoteFontColor: UIColor
    private let linkColor: UIColor

    // Paragraph style properties
    private var quoteParagraphStyle1: NSMutableParagraphStyle!
    private var quoteParagraphStyle2: NSMutableParagraphStyle!
    private var quoteParagraphStyle3: NSMutableParagraphStyle!
    private var quoteParagraphStyle4: NSMutableParagraphStyle!
    private var defaultParagraphStyle: NSMutableParagraphStyle!

    // Other properties
    private var baseFontSize: CGFloat = 14 // Default, will be updated
    private let quotePadding: CGFloat = 20.0
    private let codeFontName: String = "CourierNewPSMT"

    public init() {
        // Initialize colors (same as Objective-C version)
        self.codeFontColor = UIColor(red: 255.0/255, green: 0/255, blue: 255.0/255, alpha: 1) // Fuchsia
        self.containerBackgroundColor = UIColor(red: 242.0/255, green: 242.0/255, blue: 242.0/255, alpha: 1) // Light gray
        self.quoteFontColor = UIColor(red: 119.0/255, green: 119.0/255, blue: 119.0/255, alpha: 1) // Gray
        self.linkColor = UIColor(red: 9.0/255, green: 95.0/255, blue: 255.0/255, alpha: 1) // Blue
        self.defaultFontColor = UIColor.black

        prepareStyles()
    }

    private func prepareStyles() {
        self.baseFontSize = UIFont.preferredFont(forTextStyle: .body).pointSize
        
        let fontDescriptor = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .body)
        
        self.plainFont = UIFont.systemFont(ofSize: baseFontSize, weight: .regular)
        self.boldFont = UIFont.systemFont(ofSize: baseFontSize, weight: .bold)
        
        if let italicDescriptor = fontDescriptor.withSymbolicTraits(.traitItalic) {
            self.italicsFont = UIFont(descriptor: italicDescriptor, size: baseFontSize)
        } else {
            self.italicsFont = UIFont.italicSystemFont(ofSize: baseFontSize) 
        }
        
        if let boldItalicDescriptor = fontDescriptor.withSymbolicTraits([.traitBold, .traitItalic]) {
            self.italicsBoldFont = UIFont(descriptor: boldItalicDescriptor, size: baseFontSize)
        } else {
            if self.boldFont != nil, let boldDescriptor = self.boldFont.fontDescriptor.withSymbolicTraits(.traitItalic) {
                 self.italicsBoldFont = UIFont(descriptor: boldDescriptor, size: baseFontSize)
            } else {
                 self.italicsBoldFont = UIFont.systemFont(ofSize: baseFontSize, weight: .heavy) 
            }
        }
        
        if let specificCodeFont = UIFont(name: self.codeFontName, size: baseFontSize) {
            self.codeFont = specificCodeFont
        } else {
            if #available(iOS 13.0, *) {
                self.codeFont = UIFont.monospacedSystemFont(ofSize: baseFontSize, weight: .regular)
            } else {
                self.codeFont = UIFont(name: "Menlo-Regular", size: baseFontSize) ?? UIFont.systemFont(ofSize: baseFontSize)
            }
        }

        self.defaultParagraphStyle = createDefaultParagraphStyle()
        self.quoteParagraphStyle1 = createParagraphStyle(forQuoteLevel: 1)
        self.quoteParagraphStyle2 = createParagraphStyle(forQuoteLevel: 2)
        self.quoteParagraphStyle3 = createParagraphStyle(forQuoteLevel: 3)
        self.quoteParagraphStyle4 = createParagraphStyle(forQuoteLevel: 4)
    }
    
    private func createDefaultParagraphStyle() -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let lineHeight = self.plainFont != nil ? self.plainFont.lineHeight : self.baseFontSize 
        style.paragraphSpacing = lineHeight / 4.0
        return style
    }

    private func createParagraphStyle(forQuoteLevel level: Int) -> NSMutableParagraphStyle {
        let style = NSMutableParagraphStyle()
        let indent = quotePadding * CGFloat(level)
        let lineHeight = self.plainFont != nil ? self.plainFont.lineHeight : self.baseFontSize
        style.paragraphSpacing = lineHeight / 4.0
        style.headIndent = indent
        style.firstLineHeadIndent = indent
        style.tailIndent = -indent 
        return style
    }
    
    public func setDefaultFontColor(_ color: UIColor) {
        self.defaultFontColor = color
    }

    private let htmlParser = HTMLParser() 

    public func attributedString(forHTML htmlString: String) -> NSAttributedString {
        guard !htmlString.isEmpty else {
            return NSAttributedString(string: "")
        }

        let tokenizationResult = htmlParser.tokenize(htmlString: htmlString)
        // Renamed swiftFormats to textFormats and updated its type
        let textFormats = htmlParser.linearizeAttributes(tags: tokenizationResult.tags, displayText: tokenizationResult.displayText)

        let displayText = tokenizationResult.displayText
        let attributedString = NSMutableAttributedString(string: displayText)

        let fullRange = NSRange(location: 0, length: attributedString.length)
        if attributedString.length > 0 { 
             attributedString.addAttributes([
                 .font: self.plainFont ?? UIFont.systemFont(ofSize: self.baseFontSize), 
                 .paragraphStyle: self.defaultParagraphStyle ?? createDefaultParagraphStyle(), 
                 .foregroundColor: self.defaultFontColor, 
                 .backgroundColor: UIColor.clear 
             ], range: fullRange)
        }

        if attributedString.length != tokenizationResult.visibleCharacterCount {
            let errorMsg = "\n\n\n[HTMLFastParse Internal Error]: Mismatch between attributed string length (\(attributedString.length)) and calculated visible characters (\(tokenizationResult.visibleCharacterCount)). Please report this."
            let errorAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: self.baseFontSize, weight: .bold),
                .foregroundColor: UIColor.red
            ]
            attributedString.append(NSAttributedString(string: errorMsg, attributes: errorAttributes))
            return NSAttributedString(attributedString: attributedString) 
        }
        
        // Iterate over textFormats (renamed from swiftFormats)
        for format in textFormats {
            applyFormatAttributes(format, to: attributedString)
        }

        return NSAttributedString(attributedString: attributedString) 
    }

    // Changed parameter type from SwiftFormat to TextFormat
    private func applyFormatAttributes(_ format: TextFormat, to attributedString: NSMutableAttributedString) {
        guard format.startPosition < format.endPosition else { return } 

        let range = NSRange(location: Int(format.startPosition), length: Int(format.endPosition - format.startPosition))
        
        guard range.location + range.length <= attributedString.length else {
            #if DEBUG
            print("[HTMLFastParse Internal Error]: Invalid range [\(range.location), \(range.length)] for attributed string of length \(attributedString.length). Format: \(format)")
            #endif
            return
        }

        if format.options.contains(.strikethrough) {
            attributedString.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: range)
        }

        let totalIndentLevel = Int(format.quoteLevel) + Int(format.listNestLevel)
        if totalIndentLevel > 0 {
            var paragraphStyleToApply: NSMutableParagraphStyle?
            switch totalIndentLevel {
                case 1: paragraphStyleToApply = self.quoteParagraphStyle1
                case 2: paragraphStyleToApply = self.quoteParagraphStyle2
                case 3: paragraphStyleToApply = self.quoteParagraphStyle3
                case 4: paragraphStyleToApply = self.quoteParagraphStyle4 
                default: 
                    paragraphStyleToApply = createParagraphStyle(forQuoteLevel: totalIndentLevel)
            }
            if let style = paragraphStyleToApply {
                attributedString.addAttribute(.paragraphStyle, value: style, range: range)
            }
        }
        
        if format.quoteLevel > 0 {
            attributedString.addAttribute(.foregroundColor, value: self.quoteFontColor, range: range)
        }

        if let linkURLString = format.linkURL, let url = URL(string: linkURLString) {
            attributedString.addAttribute(.link, value: url, range: range)
            if format.quoteLevel == 0 && !format.options.contains(.code) {
                 attributedString.addAttribute(.foregroundColor, value: self.linkColor, range: range)
            }
        }
        
        if format.options.contains(.code) {
            attributedString.addAttribute(.font, value: self.codeFont ?? UIFont.monospacedSystemFont(ofSize: self.baseFontSize, weight: .regular), range: range)
            attributedString.addAttribute(.backgroundColor, value: self.containerBackgroundColor, range: range)
            if format.quoteLevel == 0 && format.linkURL == nil {
                 attributedString.addAttribute(.foregroundColor, value: self.codeFontColor, range: range)
            }
        } else if format.headingLevel == 0 && format.exponentLevel == 0 { 
            if format.options.contains(.bold) && format.options.contains(.italics) {
                attributedString.addAttribute(.font, value: self.italicsBoldFont ?? self.boldFont ?? self.plainFont, range: range)
            } else if format.options.contains(.bold) {
                attributedString.addAttribute(.font, value: self.boldFont ?? self.plainFont, range: range)
            } else if format.options.contains(.italics) {
                attributedString.addAttribute(.font, value: self.italicsFont ?? self.plainFont, range: range)
            }
        } else { 
            var currentFontSize = self.baseFontSize
            if format.headingLevel > 0 {
                switch format.headingLevel {
                    case 1: currentFontSize *= 2.0
                    case 2: currentFontSize *= 1.5
                    case 3: currentFontSize *= 1.17
                    case 4: currentFontSize *= 1.12
                    case 5: currentFontSize *= 0.83
                    case 6: currentFontSize *= 0.75
                    default: break 
                }
            }
            if format.exponentLevel > 0 {
                currentFontSize *= 0.75 
                var baselineOffset: CGFloat = 0
                if format.exponentLevel == 1 { baselineOffset = currentFontSize * 0.3 } 
                else if format.exponentLevel >= 2 { baselineOffset = currentFontSize * 0.5 } 
                attributedString.addAttribute(.baselineOffset, value: baselineOffset, range: range)
            }

            var baseFontForSizing: UIFont = self.plainFont 
            if format.options.contains(.bold) && format.options.contains(.italics) {
                baseFontForSizing = self.italicsBoldFont ?? self.boldFont ?? self.plainFont
            } else if format.options.contains(.bold) {
                baseFontForSizing = self.boldFont ?? self.plainFont
            } else if format.options.contains(.italics) {
                baseFontForSizing = self.italicsFont ?? self.plainFont
            }
            
            attributedString.addAttribute(.font, value: baseFontForSizing.withSize(currentFontSize), range: range)
        }
    }
}
