import Foundation

internal struct HTMLParsingResult {
    internal let displayText: String
    internal let tags: [HTMLTag]
    internal let visibleCharacterCount: Int

    internal init(displayText: String, tags: [HTMLTag], visibleCharacterCount: Int) {
        self.displayText = displayText
        self.tags = tags
        self.visibleCharacterCount = visibleCharacterCount
    }
}

internal class HTMLParser {

    internal init() {
        // Initializer for the parser
    }

    /**
     Tokenizes an HTML string into displayable text and a list of tags.
     This is the Swift equivalent of the C function `tokenizeHTML`.
    */
    // Internal helper for list type tracking
    private enum ListKind {
        case none, ordered, unordered
    }

    internal func tokenize(htmlString: String) -> HTMLParsingResult {
        var displayText = ""
        displayText.reserveCapacity(htmlString.count) // Optimization

        // Max stack depth isn't strictly necessary with Swift arrays but good for sanity.
        // Using htmlString.count as a rough upper bound similar to C.
        var htmlTags = Stack<HTMLTag>(capacity: htmlString.count / 5 + 10) 
        var completedTags: [HTMLTag] = []
        
        var isInTag = false
        var tagNameBuffer = "" // For collecting tag name and attributes
        
        var isInTable = false
        var tableContentStartIndexInHTML: String.Index? = nil // For original HTML string slicing

        var isInHTMLEntity = false
        var htmlEntityBuffer = ""

        var previousChar: Character? = nil // For Reddit mode newline handling
        
        var currentListKind: ListKind = .none
        var currentListValue: UInt = 1 // Starts at 1 for 'ol'

        var currentIndex = htmlString.startIndex
        
        while currentIndex < htmlString.endIndex {
            let char = htmlString[currentIndex]

            if char == '<' {
                isInTag = true
                tagNameBuffer = "" // Reset for the new tag
                
                // Peek next character to see if it's a closing tag
                let nextIndex = htmlString.index(after: currentIndex)
                if nextIndex < htmlString.endIndex && htmlString[nextIndex] != '/' {
                    // Potential opening tag, push a placeholder onto the stack.
                    // displayText.count is the current visible character count.
                    let newTag = HTMLTag(startPosition: UInt32(displayText.count), 
                                          endPosition: UInt32(displayText.count), // Temporary
                                          tag: nil, 
                                          tableData: nil)
                    htmlTags.push(newTag)
                }
            } else if char == '>' {
                isInTag = false
                let normalizedTagName = tagNameBuffer.lowercased()

                if normalizedTagName.hasPrefix("/") { // Closing tag e.g. </p>
                    let cleanTagName = String(normalizedTagName.dropFirst())
                    if var format = htmlTags.pop() {
                        format.endPosition = UInt32(displayText.count)
                        // If tag name was not set (e.g. from <p attr="">), set it now
                        if format.tag == nil {
                             format.tag = cleanTagName
                        }

                        if isInTable && cleanTagName == "table" {
                            isInTable = false
                            if let tableStart = tableContentStartIndexInHTML {
                                // Correctly get the index *before* the current '>'
                                // The C code's `i` for closing table is the index of '<' in "</table>"
                                // So, htmlString.index(before: currentIndex, offsetBy: (cleanTagName.count + 2))
                                // if currentIndex is the '>' of "</table>"
                                let tableHTMLContent = String(htmlString[tableStart..<htmlString.index(before: currentIndex, offsetBy: cleanTagName.count + 2)])
                                format.tableData = Base64Converter.encode(string: tableHTMLContent)
                            }
                            tableContentStartIndexInHTML = nil
                        }
                        completedTags.append(format)
                    }
                } else if normalizedTagName.hasSuffix("/") { // Self-closing tag e.g. <br/>
                    // The placeholder tag pushed at '<' needs to be popped.
                    _ = htmlTags.pop() // Discard the placeholder from the stack

                    let cleanTagName = String(normalizedTagName.dropLast())
                    if cleanTagName == "br" {
                        // Reddit mode: '\n' for <br/> if not in table
                        if !isInTable { // Assuming Reddit mode
                            // Filter consecutive newlines
                            if previousChar != '\n' {
                                displayText.append("\n")
                                previousChar = "\n"
                            }
                        }
                    } else {
                        // Other self-closing tags like <img />
                        let selfClosedTag = HTMLTag(startPosition: UInt32(displayText.count),
                                                     endPosition: UInt32(displayText.count),
                                                     tag: cleanTagName,
                                                     tableData: nil)
                        completedTags.append(selfClosedTag)
                    }
                } else { // Opening tag e.g. <p>
                    if var format = htmlTags.peek() { // Modify the tag on top of the stack
                        htmlTags.pop() // Pop to modify
                        format.tag = normalizedTagName
                        
                        if normalizedTagName == "table" {
                            isInTable = true
                            // The content starts *after* this current '>'
                            tableContentStartIndexInHTML = htmlString.index(after: currentIndex)
                            
                            // Append "[View table]" (Reddit mode)
                            let viewTableText = "[View table]"
                            for char_vt in viewTableText {
                                displayText.append(char_vt)
                                // previousChar is updated inside this loop, vital for the newline logic below
                                previousChar = char_vt 
                            }
                            // Add a newline after "[View table]" if not already on one
                            if previousChar != '\n' { // Check if "[View table]" itself ended with \n (it doesn't)
                                displayText.append("\n")
                                previousChar = "\n"
                            }

                        } else if normalizedTagName == "ol" {
                            currentListKind = .ordered
                            currentListValue = 1
                        } else if normalizedTagName == "ul" {
                            currentListKind = .unordered
                        } else if normalizedTagName == "li" {
                            if !isInTable { // List items not processed within tables for displayText
                                var prefix = ""
                                if currentListKind == .ordered {
                                    prefix = "\(currentListValue). "
                                    currentListValue += 1
                                } else if currentListKind == .unordered {
                                    prefix = "• " // Bullet point
                                }
                                // Filter newlines before adding list prefix
                                if !displayText.isEmpty && previousChar != '\n' {
                                    displayText.append("\n")
                                }
                                displayText.append(prefix)
                                previousChar = " " // Last char of prefix
                            }
                        }
                        htmlTags.push(format) // Push modified tag back
                    }
                }
                tagNameBuffer = "" // Reset after processing
            } else if char == '&' && !isInTable { // Start of an HTML entity, only if not in a table
                isInHTMLEntity = true
                htmlEntityBuffer = "&"
            } else if isInHTMLEntity && char == ';' && !isInTable { // End of an HTML entity
                isInHTMLEntity = false
                htmlEntityBuffer.append(";")
                
                let decodedEntity = HTMLEntityDecoder.decode(htmlEntityBuffer)
                
                if isInTag {
                    tagNameBuffer.append(decodedEntity)
                } else {
                    // Append decoded entity to displayText
                    // Reddit mode newline handling for decoded entity
                    for decodedChar in decodedEntity {
                        if decodedChar == '\n' {
                            if previousChar != '\n' {
                                displayText.append("\n")
                            }
                        } else {
                            displayText.append(decodedChar)
                        }
                        previousChar = decodedChar
                    }
                }
                htmlEntityBuffer = ""
            } else { // Character data
                if isInHTMLEntity {
                    htmlEntityBuffer.append(char)
                } else if isInTag {
                    tagNameBuffer.append(char)
                } else if isInTable {
                    // Skip character, it's part of table's raw HTML content
                } else {
                    // Regular character for displayText
                    // Reddit mode newline handling
                    if char == '\n' {
                        if previousChar != '\n' { // Avoid double newlines
                            displayText.append("\n")
                        }
                    } else {
                        displayText.append(char)
                    }
                    previousChar = char
                }
            }
            currentIndex = htmlString.index(after: currentIndex)
        }

        // Handle any unclosed tags
        while var unclosedTag = htmlTags.pop() {
            unclosedTag.endPosition = UInt32(displayText.count)
            completedTags.append(unclosedTag)
        }
        
        return HTMLParsingResult(displayText: displayText, 
                                  tags: completedTags, 
                                  visibleCharacterCount: displayText.count)
    }

    /**
     Processes parsed tags to create a linear list of formatting attributes.
     This is the Swift equivalent of the C function `makeAttributesLinear`.
    */
    private static let dataURIPrefix = "data:text/html;charset=utf-8;base64,"

    internal func linearizeAttributes(tags: [HTMLTag], displayText: String) -> [TextFormat] {
        if displayText.isEmpty {
            return []
        }

        // 1. Initialize characterFormats array
        // The startPosition and endPosition here are irrelevant as they are for the final TextFormat objects.
        // We use a default TextFormat, which has all options off and levels at 0.
        var characterFormats = [TextFormat](
            repeating: TextFormat(startPosition: 0, endPosition: 0), 
            count: displayText.count
        )

        // 2. Iterate Through Input tags and Apply Formatting
        for tag in tags {
            guard let tagText = tag.tag?.lowercased(), !tagText.isEmpty else { continue }

            // Ensure positions are valid and clamp if necessary.
            // The C code doesn't explicitly show clamping for this loop, but it's good practice.
            // However, startPosition and endPosition should be generated correctly by tokenize.
            let start = Int(tag.startPosition)
            let end = Int(tag.endPosition)

            // Skip if range is invalid or empty, or out of bounds for displayText
            if start < 0 || start >= displayText.count || end <= start || end > displayText.count {
                 // Or handle error / log warning
                continue
            }

            for j in start..<end {
                // Apply formatting based on tag type
                if tagText == "strong" {
                    characterFormats[j].options.insert(.bold)
                } else if tagText == "em" {
                    characterFormats[j].options.insert(.italics)
                } else if tagText == "del" {
                    characterFormats[j].options.insert(.strikethrough)
                } else if tagText == "code" {
                    characterFormats[j].options.insert(.code)
                } else if tagText.hasPrefix("h") && tagText.count == 2 {
                    if let level = UInt8(String(tagText.dropFirst())) {
                        if level >= 1 && level <= 6 {
                            characterFormats[j].headingLevel = level
                        }
                    }
                } else if tagText == "sup" {
                    characterFormats[j].exponentLevel += 1
                } else if tagText == "blockquote" {
                    characterFormats[j].quoteLevel += 1
                } else if tagText == "ol" || tagText == "ul" {
                    characterFormats[j].listNestLevel += 1
                } else if tagText.hasPrefix("a href=") {
                    // Extract URL: "a href=\"URL\"" or "a href='URL'"
                    // A more robust regex might be needed for all edge cases.
                    // Example: <a href="http://example.com"> or <a href='http://example.com'>
                    // Simplified extraction:
                    let hrefContent = String(tagText.dropFirst("a href=".count))
                    if hrefContent.hasPrefix("\"") && hrefContent.hasSuffix("\"") {
                        let url = String(hrefContent.dropFirst().dropLast())
                        characterFormats[j].linkURL = url
                    } else if hrefContent.hasPrefix("'") && hrefContent.hasSuffix("'") {
                        let url = String(hrefContent.dropFirst().dropLast())
                        characterFormats[j].linkURL = url
                    } else {
                        // Handle unquoted or malformed href if necessary, or assume valid format
                        characterFormats[j].linkURL = hrefContent // Fallback, might be incorrect
                    }
                } else if tagText == "table" {
                    if let tableData = tag.tableData, !tableData.isEmpty {
                        // Use the static dataURIPrefix from HTMLParser class itself
                        characterFormats[j].linkURL = HTMLParser.dataURIPrefix + tableData
                    }
                }
            }
        }

        // 3. Consolidate characterFormats
        if displayText.isEmpty { // Should be caught by the first check, but defensive
            return []
        }

        var resultSimplifiedFormats: [TextFormat] = []
        var activeStyleStartIndex = 0

        for i in 1..<displayText.count {
            // TextFormat is Equatable now.
            if characterFormats[i] != characterFormats[activeStyleStartIndex] {
                var finalFormat = characterFormats[activeStyleStartIndex]
                finalFormat.startPosition = UInt32(activeStyleStartIndex)
                finalFormat.endPosition = UInt32(i)
                resultSimplifiedFormats.append(finalFormat)
                activeStyleStartIndex = i
            }
        }

        // Commit the final style segment
        if displayText.count > 0 { // Ensure not called on empty string if initial check was bypassed
            var finalFormat = characterFormats[activeStyleStartIndex]
            finalFormat.startPosition = UInt32(activeStyleStartIndex)
            finalFormat.endPosition = UInt32(displayText.count)
            resultSimplifiedFormats.append(finalFormat)
        }
        
        return resultSimplifiedFormats
    }
}
