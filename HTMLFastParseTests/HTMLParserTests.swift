import XCTest
@testable import HTMLFastParse // To access internal types like HTMLParser, HTMLTag etc.

class HTMLParserTests: XCTestCase {

    var parser: HTMLParser!

    override func setUpWithError() throws {
        try super.setUpWithError()
        parser = HTMLParser()
    }

    override func tearDownWithError() throws {
        parser = nil
        try super.tearDownWithError()
    }

    // MARK: - Basic Tag Tests
    func testEmptyString() {
        let result = parser.tokenize(htmlString: "")
        XCTAssertEqual(result.displayText, "")
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertEqual(result.visibleCharacterCount, 0)
    }

    func testStringWithNoTags() {
        let html = "Hello, world!"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, html)
        XCTAssertTrue(result.tags.isEmpty)
        XCTAssertEqual(result.visibleCharacterCount, html.count)
    }

    func testSimpleBoldTag() {
        let html = "<b>Hello</b>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Hello")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "b")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 5) // "Hello".count
            XCTAssertNil(tag.tableData)
        }
        XCTAssertEqual(result.visibleCharacterCount, 5)
    }

    func testSimpleItalicTag() {
        let html = "<em>World</em>" // Using <em> as it's common like <i>
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "World")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "em")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 5) // "World".count
        }
        XCTAssertEqual(result.visibleCharacterCount, 5)
    }

    func testSimpleParagraphTag() {
        let html = "<p>This is a paragraph.</p>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "This is a paragraph.")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "p")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 20) // "This is a paragraph.".count
        }
        XCTAssertEqual(result.visibleCharacterCount, 20)
    }

    func testTagWithSimpleAttribute() {
        let html = "<a href=\"example.com\">Link</a>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Link")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            // HTMLParser keeps the full attribute string as part of the tag name
            XCTAssertEqual(tag.tag, "a href=\"example.com\"")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 4) // "Link".count
        }
        XCTAssertEqual(result.visibleCharacterCount, 4)
    }
    
    func testTagWithSpacesInAttribute() {
        let html = "<img src=\"my image.png\">" // No display text for img typically
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "") // Assuming img produces no direct display text
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "img src=\"my image.png\"")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 0)
        }
        XCTAssertEqual(result.visibleCharacterCount, 0)
    }
    
    func testTagWithUnquotedAttribute() {
        // The C parser's behavior for unquoted attributes might be specific.
        // It seems to capture up to the next space or '>'.
        // Example: <a href=example.com>Link</a>
        // The original C code for parsing tags in `tokenizeHTML` copies characters into `tagNameBuffer`
        // until it hits '>'. If entities are in attributes, they are decoded into this buffer.
        // The HTMLParser in Swift adopted similar logic.
        let html = "<a href=example.com>Link</a>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Link")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "a href=example.com")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 4)
        }
        XCTAssertEqual(result.visibleCharacterCount, 4)
    }

    func testTagWithSingleQuotedAttribute() {
        let html = "<a href='example.com'>Link</a>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Link")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "a href='example.com'")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 4)
        }
        XCTAssertEqual(result.visibleCharacterCount, 4)
    }

    // MARK: - Nested Tag Tests
    func testSimpleNestedTags() {
        let html = "<p><b>Hello</b></p>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Hello")
        XCTAssertEqual(result.tags.count, 2, "Should be two tags: p and b")

        // Tags are usually ordered by end position or how they are popped from stack.
        // The C parser added tags to `completedTags` when the closing tag was encountered.
        // So, inner tags appear before outer tags if they end sooner or at the same time.
        // Let's assume order: <b> then <p>.
        
        if result.tags.count == 2 {
            // Using .first { } to find tags to be resilient to order changes.
            let tagB = result.tags.first { $0.tag == "b" }
            XCTAssertNotNil(tagB)
            XCTAssertEqual(tagB?.startPosition, 0) // "Hello" starts at 0 relative to <p>'s content start
            XCTAssertEqual(tagB?.endPosition, 5)   // "Hello".count

            let tagP = result.tags.first { $0.tag == "p" }
            XCTAssertNotNil(tagP)
            XCTAssertEqual(tagP?.startPosition, 0) // <p> content also starts at "Hello"
            XCTAssertEqual(tagP?.endPosition, 5)
        }
        XCTAssertEqual(result.visibleCharacterCount, 5)
    }

    func testMultiLevelNestedTags() {
        let html = "<a><b><i>Text</i></b></a>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Text")
        XCTAssertEqual(result.tags.count, 3)

        if result.tags.count == 3 {
            // Assuming order based on when closing tag is processed: i, b, a
            let tagI = result.tags.first { $0.tag == "i" }
            XCTAssertNotNil(tagI)
            XCTAssertEqual(tagI?.startPosition, 0)
            XCTAssertEqual(tagI?.endPosition, 4)

            let tagB = result.tags.first { $0.tag == "b" }
            XCTAssertNotNil(tagB)
            XCTAssertEqual(tagB?.startPosition, 0)
            XCTAssertEqual(tagB?.endPosition, 4)
            
            let tagA = result.tags.first { $0.tag == "a" }
            XCTAssertNotNil(tagA)
            XCTAssertEqual(tagA?.startPosition, 0)
            XCTAssertEqual(tagA?.endPosition, 4)
        }
        XCTAssertEqual(result.visibleCharacterCount, 4)
    }

    func testNestedWithTextInBetween() {
        let html = "<p>Prefix <b>bold</b> Suffix</p>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Prefix bold Suffix")
        XCTAssertEqual(result.tags.count, 2)

        if result.tags.count == 2 {
            // Order: <b> then <p>
            let tagB = result.tags.first { $0.tag == "b" }
            XCTAssertNotNil(tagB)
            XCTAssertEqual(tagB?.startPosition, 7)  // "Prefix ".count -> "bold" starts at index 7
            XCTAssertEqual(tagB?.endPosition, 11) // 7 + "bold".count

            let tagP = result.tags.first { $0.tag == "p" }
            XCTAssertNotNil(tagP)
            XCTAssertEqual(tagP?.startPosition, 0)
            XCTAssertEqual(tagP?.endPosition, 18) // "Prefix bold Suffix".count
        }
        XCTAssertEqual(result.visibleCharacterCount, 18)
    }
    
    func testAdjacentNestedTags() {
        let html = "<p><b>Bold1</b><i>Italic1</i></p>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Bold1Italic1")
        XCTAssertEqual(result.tags.count, 3) // p, b, i

        if result.tags.count == 3 {
            let tagB = result.tags.first { $0.tag == "b" }
            XCTAssertNotNil(tagB)
            XCTAssertEqual(tagB?.startPosition, 0)
            XCTAssertEqual(tagB?.endPosition, 5) // "Bold1".count
            
            let tagI = result.tags.first { $0.tag == "i" }
            XCTAssertNotNil(tagI)
            XCTAssertEqual(tagI?.startPosition, 5) // "Bold1".count -> "Italic1" starts at index 5
            XCTAssertEqual(tagI?.endPosition, 12) // 5 + "Italic1".count

            let tagP = result.tags.first { $0.tag == "p" }
            XCTAssertNotNil(tagP)
            XCTAssertEqual(tagP?.startPosition, 0)
            XCTAssertEqual(tagP?.endPosition, 12) // "Bold1Italic1".count
        }
        XCTAssertEqual(result.visibleCharacterCount, 12)
    }

    // MARK: - Self-Closing Tag Tests
    func testBrTag() {
        // Behavior of <br> or <br/> might depend on "reddit_mode" in original C parser.
        // The Swift translation of `tokenizeHTML` in `HTMLParser.swift` includes:
        // if tagNormalized == "br/" || tagNormalized == "br" {
        //    if !isInTable { // Assuming redditMode is effectively on, based on C translation
        //        // Original C code had #ifndef reddit_mode for adding \n
        //        // If reddit_mode is assumed ON, then <br/> does NOT add \n itself,
        //        // but it IS a tag.
        //        // If reddit_mode is assumed OFF, then <br/> ADDS \n.
        //        // The translated Swift code for `br/` and `br` does NOT add a `\n` to displayText.
        //        // It relies on HTML source providing actual newlines if needed around <br>.
        //    }
        //    // It's treated as a self-closing tag, so a SwiftTag is created.
        // }
        let html = "Hello<br/>World"
        let result = parser.tokenize(htmlString: html)
        
        // Current Swift translation of C code's "reddit_mode" implies <br/> itself doesn't add \n.
        // Newlines must be explicit in HTML input if desired in displayText.
        XCTAssertEqual(result.displayText, "HelloWorld", "In current 'reddit_mode' translation, <br/> does not add a newline to displayText.")
        XCTAssertEqual(result.tags.count, 1, "Should identify <br/> as a tag.")
        if let tag = result.tags.first {
            XCTAssertTrue(tag.tag == "br/" || tag.tag == "br", "Tag name should be 'br' or 'br/'")
            XCTAssertEqual(tag.startPosition, 5, "Tag should be positioned after 'Hello'") // "Hello".count
            XCTAssertEqual(tag.endPosition, 5, "Self-closing tag's end should be same as start")
        }
        XCTAssertEqual(result.visibleCharacterCount, 10) // "HelloWorld".count
    }

    func testHrTag() {
        let html = "Text<hr/>More text"
        let result = parser.tokenize(htmlString: html)
        // <hr/> typically doesn't add text, but acts as a separator.
        // The original C code treated unknown self-closing tags by adding them as actual tags.
        // The Swift `HTMLParser.tokenize` for self-closing tags (tagName.hasSuffix("/"))
        // other than "br/" or "br" does:
        //   newTag.tag = tagName (e.g. "hr/")
        //   newTag.startPosition = currentDisplayText.count
        //   newTag.endPosition = currentDisplayText.count
        //   completedTags.append(newTag)
        // So, like <br/>, it doesn't alter displayText.
        XCTAssertEqual(result.displayText, "TextMore text")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertTrue(tag.tag == "hr/" || tag.tag == "hr", "Tag name should be 'hr' or 'hr/'")
            XCTAssertEqual(tag.startPosition, 4) // "Text".count
            XCTAssertEqual(tag.endPosition, 4)
        }
        XCTAssertEqual(result.visibleCharacterCount, 12) // "TextMore text".count
    }

    func testBrTagWithoutSlash() {
        let html = "Hello<br>World"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "HelloWorld")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "br")
            XCTAssertEqual(tag.startPosition, 5)
            XCTAssertEqual(tag.endPosition, 5)
        }
        XCTAssertEqual(result.visibleCharacterCount, 10)
    }

    func testImgTagSelfClosing() {
        // <img ... /> is a common self-closing tag
        let html = "Text<img src=\"image.png\"/>After"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "TextAfter")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "img src=\"image.png\"/") // Includes the slash
            XCTAssertEqual(tag.startPosition, 4) // "Text".count
            XCTAssertEqual(tag.endPosition, 4)
        }
        XCTAssertEqual(result.visibleCharacterCount, 9) // "TextAfter".count
    }
    
    func testImgTagNotSelfClosed() {
        // <img ... > (no slash) is also common
        let html = "Text<img src=\"image.png\">After"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "TextAfter")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "img src=\"image.png\"") // No slash in tag name if not present
            XCTAssertEqual(tag.startPosition, 4)
            XCTAssertEqual(tag.endPosition, 4)
        }
        XCTAssertEqual(result.visibleCharacterCount, 9)
    }

    // MARK: - Attribute Handling Tests
    func testTagWithMultipleAttributes() {
        let html = "<a href=\"example.com\" target=\"_blank\">Link</a>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Link")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "a href=\"example.com\" target=\"_blank\"")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 4) // "Link".count
        }
        XCTAssertEqual(result.visibleCharacterCount, 4)
    }

    func testTagWithAttributeContainingEncodedCharacters() {
        // The C parser's tokenizeHTML would decode entities found within tag definitions (attributes).
        // The Swift HTMLParser.tokenize should replicate this using HTMLEntityDecoder.
        let html = "<a href=\"example.com?name=Fish%20&amp;%20Chips\">Link</a>"
        // "Fish%20&amp;%20Chips" should become "Fish%20&%20Chips" in the tag string
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Link")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "a href=\"example.com?name=Fish%20&%20Chips\"")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 4)
        }
        XCTAssertEqual(result.visibleCharacterCount, 4)
    }
    
    func testTagWithEmptyAttributeValue() {
        let html = "<input type=\"text\" disabled>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "input type=\"text\" disabled")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 0)
        }
        XCTAssertEqual(result.visibleCharacterCount, 0)
    }

    func testTagWithMixedQuotingAndSpacingInAttributes() {
        let html = "<div class='foo' id = bar title = \"hello world\">Text</div>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "Text")
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            // The parser should preserve the original spacing and quote style as part of the tag string.
            XCTAssertEqual(tag.tag, "div class='foo' id = bar title = \"hello world\"")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, 4) // "Text".count
        }
        XCTAssertEqual(result.visibleCharacterCount, 4)
    }

    // MARK: - List Parsing Tests
    func testSimpleUnorderedList() {
        let html = "<ul><li>Item 1</li><li>Item 2</li></ul>"
        // HTMLParser.tokenize, based on C version, adds "• " for <li> in <ul>
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "• Item 1• Item 2")
        XCTAssertEqual(result.tags.count, 3, "Should be ul, and two li tags")

        let ulTags = result.tags.filter { $0.tag == "ul" }
        XCTAssertEqual(ulTags.count, 1)
        XCTAssertEqual(ulTags.first?.startPosition, 0)
        XCTAssertEqual(ulTags.first?.endPosition, "• Item 1• Item 2".count)

        let liTags = result.tags.filter { $0.tag == "li" }
        XCTAssertEqual(liTags.count, 2)
        
        // Assuming order of li tags by appearance in completedTags
        if liTags.count == 2 {
             // Sort by start position to ensure consistent order for assertion
            let sortedLiTags = liTags.sorted { $0.startPosition < $1.startPosition }
            XCTAssertEqual(sortedLiTags[0].startPosition, 2) // After "• "
            XCTAssertEqual(sortedLiTags[0].endPosition, 2 + "Item 1".count) // "• Item 1"
            XCTAssertEqual(sortedLiTags[1].startPosition, 2 + "Item 1".count + 2) // After "• Item 1" and next "• "
            XCTAssertEqual(sortedLiTags[1].endPosition, 2 + "Item 1".count + 2 + "Item 2".count)
        }
        XCTAssertEqual(result.visibleCharacterCount, "• Item 1• Item 2".count)
    }

    func testSimpleOrderedList() {
        let html = "<ol><li>Item A</li><li>Item B</li></ol>"
        // HTMLParser.tokenize adds "1. ", "2. " etc. for <li> in <ol>
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "1. Item A2. Item B")
        XCTAssertEqual(result.tags.count, 3) // ol, li, li

        let olTags = result.tags.filter { $0.tag == "ol" }
        XCTAssertEqual(olTags.count, 1)
        XCTAssertEqual(olTags.first?.startPosition, 0)
        XCTAssertEqual(olTags.first?.endPosition, "1. Item A2. Item B".count)

        let liTags = result.tags.filter { $0.tag == "li" }
        XCTAssertEqual(liTags.count, 2)
        if liTags.count == 2 {
            let sortedLiTags = liTags.sorted { $0.startPosition < $1.startPosition }
            XCTAssertEqual(sortedLiTags[0].startPosition, 3) // After "1. "
            XCTAssertEqual(sortedLiTags[0].endPosition, 3 + "Item A".count)
            XCTAssertEqual(sortedLiTags[1].startPosition, 3 + "Item A".count + 3) // After "1. Item A" and "2. "
            XCTAssertEqual(sortedLiTags[1].endPosition, 3 + "Item A".count + 3 + "Item B".count)
        }
        XCTAssertEqual(result.visibleCharacterCount, "1. Item A2. Item B".count)
    }

    func testNestedLists() {
        let html = "<ul><li>First item<ul><li>Nested item</li></ul></li><li>Second item</li></ul>"
        // Expected displayText based on parser logic:
        // • First item• Nested item• Second item
        // (The inner ul doesn't add its own bullet to displayText, its li does)
        let expectedText = "• First item• Nested item• Second item"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, expectedText)
        XCTAssertEqual(result.tags.count, 5) // outer ul, li, inner ul, inner li, outer li

        let ulTags = result.tags.filter { $0.tag == "ul" }.sorted { $0.startPosition < $1.startPosition }
        XCTAssertEqual(ulTags.count, 2)
        if ulTags.count == 2 {
            XCTAssertEqual(ulTags[0].startPosition, 0) // Outer UL
            XCTAssertEqual(ulTags[0].endPosition, expectedText.count)
            XCTAssertEqual(ulTags[1].startPosition, "• First item".count) // Inner UL
            XCTAssertEqual(ulTags[1].endPosition, "• First item• Nested item".count)
        }
        
        let liTags = result.tags.filter { $0.tag == "li" }.sorted(by: { $0.startPosition < $1.startPosition })
        XCTAssertEqual(liTags.count, 3)
        if liTags.count == 3 {
            // "• First item" -> li content "First item"
            XCTAssertEqual(liTags[0].startPosition, 2) // After "• "
            XCTAssertEqual(liTags[0].endPosition, 2 + "First item".count)
            
            // "• Nested item" -> li content "Nested item"
            XCTAssertEqual(liTags[1].startPosition, "• First item".count + 2) // After "• First item" and "• "
            XCTAssertEqual(liTags[1].endPosition, "• First item".count + 2 + "Nested item".count)

            // "• Second item" -> li content "Second item"
            XCTAssertEqual(liTags[2].startPosition, "• First item• Nested item".count + 2)
            XCTAssertEqual(liTags[2].endPosition, expectedText.count)
        }
    }

    func testTableContainingList() {
        let listInTableHTML = "<ul><li>Item A</li><li>Item B</li></ul>"
        let tableHTML = "<table><tr><td>" + listInTableHTML + "</td></tr></table>"
        let expectedDisplayText = "[View table]\n" // Table content is opaque

        let result = parser.tokenize(htmlString: tableHTML)
        XCTAssertEqual(result.displayText, expectedDisplayText)
        XCTAssertEqual(result.tags.count, 1, "Only the table tag should be present at the top level")

        if let tableTag = result.tags.first {
            XCTAssertEqual(tableTag.tag, "table")
            XCTAssertNotNil(tableTag.tableData)
            if let tableData = tableTag.tableData {
                let decodedData = Base64Converter.decodeToData(base64String: tableData)
                XCTAssertNotNil(decodedData)
                if let data = decodedData, let decodedString = String(data: data, encoding: .utf8) {
                    XCTAssertEqual(decodedString, tableHTML, "Decoded table data should be the original table HTML, including the list")
                    // Optionally, parse the decodedString *again* to check internal list structure,
                    // but that might be overly complex for this test.
                    // The main point is that the table's *entire* content is preserved.
                }
            }
        }
    }

    func testListWithinBlockquote() {
        let html = "<blockquote><ul><li>Quoted item</li></ul></blockquote>"
        // Expected: "• Quoted item" (blockquote doesn't add visual markers itself in tokenize)
        let expectedText = "• Quoted item"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, expectedText)
        // Tags: blockquote, ul, li
        XCTAssertEqual(result.tags.count, 3)

        let blockquoteTag = result.tags.first { $0.tag == "blockquote" }
        XCTAssertNotNil(blockquoteTag)
        XCTAssertEqual(blockquoteTag?.startPosition, 0)
        XCTAssertEqual(blockquoteTag?.endPosition, expectedText.count)

        let ulTag = result.tags.first { $0.tag == "ul" }
        XCTAssertNotNil(ulTag)
        // ul tag range should also cover the "• Quoted item" as its content starts there
        XCTAssertEqual(ulTag?.startPosition, 0) 
        XCTAssertEqual(ulTag?.endPosition, expectedText.count)


        let liTag = result.tags.first { $0.tag == "li" }
        XCTAssertNotNil(liTag)
        XCTAssertEqual(liTag?.startPosition, 2) // After "• "
        XCTAssertEqual(liTag?.endPosition, expectedText.count)
    }
    
    func testFormattingInListInTable() {
        // This tests that complex content within a table is correctly base64 encoded.
        let complexCellContent = "<ul><li><b>Bold</b> list item</li></ul>"
        let tableHTML = "<table><tr><td>" + complexCellContent + "</td></tr></table>"
        let expectedDisplayText = "[View table]\n"

        let result = parser.tokenize(htmlString: tableHTML)
        XCTAssertEqual(result.displayText, expectedDisplayText)
        XCTAssertEqual(result.tags.count, 1)

        if let tableTag = result.tags.first {
            XCTAssertEqual(tableTag.tag, "table")
            XCTAssertNotNil(tableTag.tableData)
            if let tableData = tableTag.tableData {
                let decodedData = Base64Converter.decodeToData(base64String: tableData)
                XCTAssertNotNil(decodedData)
                if let data = decodedData, let decodedString = String(data: data, encoding: .utf8) {
                    XCTAssertEqual(decodedString, tableHTML, "Decoded table data must match original complex table HTML")
                }
            }
        }
    }

    // MARK: - HTML Entity Tests
    func testEntitiesInTextContent() {
        let html = "<p>Hello &amp; welcome &lt;world&gt;!</p>"
        // HTMLEntityDecoder should convert &amp; to & and &lt; to <, &gt; to >
        let expectedText = "Hello & welcome <world>!"
        let result = parser.tokenize(htmlString: html)
        
        XCTAssertEqual(result.displayText, expectedText)
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, "p")
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, expectedText.count)
        }
    }

    func testNumericEntitiesInTextContent() {
        let html = "<p>Numeric: &#65;&#x42;.</p>" // A, B
        let expectedText = "Numeric: AB."
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, expectedText)
        XCTAssertEqual(result.tags.count, 1)
    }

    func testEntitiesInAttributeValue() {
        // From a previous test: testTagWithAttributeContainingEncodedCharacters
        // It already covers this: <a href="example.com?name=Fish%20&amp;%20Chips">Link</a>
        // results in tag.tag = "a href=\"example.com?name=Fish%20&%20Chips\""
        // This confirms entities in attributes are decoded by the tokenizer into the tag's string.
        // We can add another variant for good measure.
        let html = "<img alt='&lt;image&gt;' src='foo.png'>"
        let expectedTagName = "img alt='<image>' src='foo.png'" // &lt; becomes <, &gt; becomes >
        
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "") // img is non-visual here
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, expectedTagName)
        }
    }
    
    func testMixedEntitiesInTextAndAttributes() {
        let html = "<a title='&quot;Title&quot;'>&lt;Click Here&gt;</a>"
        let expectedText = "<Click Here>"
        let expectedTagName = "a title='\"Title\"'"

        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, expectedText)
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, expectedTagName)
            XCTAssertEqual(tag.startPosition, 0)
            XCTAssertEqual(tag.endPosition, expectedText.count)
        }
    }
    
    func testUnknownEntityInText() {
        let html = "<p>Unknown &notanentity; entity.</p>"
        // The HTMLEntityDecoder, when it can't find an entity, appends the original sequence.
        let expectedText = "Unknown &notanentity; entity." 
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, expectedText)
    }

    func testUnknownEntityInAttribute() {
        let html = "<a data-custom='&customattr;'>Text</a>"
        let expectedTagName = "a data-custom='&customattr;'"
        let expectedText = "Text"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, expectedText)
        XCTAssertEqual(result.tags.count, 1)
        if let tag = result.tags.first {
            XCTAssertEqual(tag.tag, expectedTagName)
        }
    }
    
    func testListWithMixedContent() {
        let html = "<ol><li><b>Bold</b> item</li><li><i>Italic</i> item</li></ol>"
        let result = parser.tokenize(htmlString: html)
        XCTAssertEqual(result.displayText, "1. Bold item2. Italic item")
        // Expected tags: ol, li, b, li, i  (5 tags)
        XCTAssertEqual(result.tags.count, 5)

        let bTag = result.tags.first { $0.tag == "b" }
        XCTAssertNotNil(bTag)
        XCTAssertEqual(bTag?.startPosition, 3) // After "1. "
        XCTAssertEqual(bTag?.endPosition, 3 + "Bold".count) // "Bold item" -> "Bold"

        let iTag = result.tags.first { $0.tag == "i" }
        XCTAssertNotNil(iTag)
        XCTAssertEqual(iTag?.startPosition, "1. Bold item".count + 3) // After "1. Bold item" and "2. "
        XCTAssertEqual(iTag?.endPosition, "1. Bold item".count + 3 + "Italic".count) // "Italic item" -> "Italic"
    }

    // MARK: - Table Parsing Tests
    func testSimpleTable() {
        let rawTableHTML = "<table><tr><td>Cell 1</td></tr><tr><td>Cell 2</td></tr></table>"
        // The parser replaces table content with "[View table]\n" and base64 encodes the raw table.
        let expectedDisplayText = "[View table]\n"
        
        let result = parser.tokenize(htmlString: rawTableHTML)
        XCTAssertEqual(result.displayText, expectedDisplayText)
        XCTAssertEqual(result.tags.count, 1, "Should only be the main table tag")

        if let tableTag = result.tags.first {
            XCTAssertEqual(tableTag.tag, "table")
            XCTAssertEqual(tableTag.startPosition, 0)
            XCTAssertEqual(tableTag.endPosition, expectedDisplayText.count) // Length of the placeholder text
            
            XCTAssertNotNil(tableTag.tableData, "Table data should be present")
            if let tableData = tableTag.tableData {
                // Check if the tableData (Base64) decodes to the original rawTableHTML
                // Need to use Base64Converter for this.
                // Base64Converter.decode(base64String:) returns String?
                // Base64Converter.decodeToData(base64String:) returns Data?
                
                let decodedData = Base64Converter.decodeToData(base64String: tableData)
                XCTAssertNotNil(decodedData, "Base64 decoding of tableData failed")
                if let decodedData = decodedData {
                    let decodedString = String(data: decodedData, encoding: .utf8)
                    XCTAssertEqual(decodedString, rawTableHTML, "Decoded tableData does not match original table HTML")
                }
            }
        }
        XCTAssertEqual(result.visibleCharacterCount, expectedDisplayText.count)
    }

    func testTableWithSurroundingText() {
        let rawTableHTMLOnly = "<table><tr><td>Data</td></tr></table>"
        let fullHTML = "<p>Before table</p>" + rawTableHTMLOnly + "<p>After table</p>"
        
        let expectedDisplayText = "Before table[View table]\nAfter table"
        
        let result = parser.tokenize(htmlString: fullHTML)
        XCTAssertEqual(result.displayText, expectedDisplayText)
        // Expected tags: p (before), table, p (after)
        XCTAssertEqual(result.tags.count, 3)

        let tableTag = result.tags.first { $0.tag == "table" }
        XCTAssertNotNil(tableTag)
        if let tableTag = tableTag {
            XCTAssertEqual(tableTag.startPosition, "Before table".count)
            XCTAssertEqual(tableTag.endPosition, "Before table".count + "[View table]\n".count)
            
            XCTAssertNotNil(tableTag.tableData)
            if let tableData = tableTag.tableData {
                let decodedData = Base64Converter.decodeToData(base64String: tableData)
                XCTAssertNotNil(decodedData)
                if let decodedData = decodedData {
                    let decodedString = String(data: decodedData, encoding: .utf8)
                    XCTAssertEqual(decodedString, rawTableHTMLOnly)
                }
            }
        }
        
        let pTags = result.tags.filter { $0.tag == "p" }.sorted(by: { $0.startPosition < $1.startPosition })
        XCTAssertEqual(pTags.count, 2)
        if pTags.count == 2 {
            XCTAssertEqual(pTags[0].startPosition, 0)
            XCTAssertEqual(pTags[0].endPosition, "Before table".count)
            
            XCTAssertEqual(pTags[1].startPosition, "Before table".count + "[View table]\n".count)
            XCTAssertEqual(pTags[1].endPosition, expectedDisplayText.count)
        }
    }

    func testTableTagAttributes() {
        // Attributes on the <table> tag itself should be preserved in its `tag.tag` property.
        let rawTableHTMLWithAttributes = "<table border=\"1\" class=\"data\"><tr><td>Cell</td></tr></table>"
        let expectedTableTagName = "table border=\"1\" class=\"data\"" // How parser stores table tag name with attributes
        let expectedDisplayText = "[View table]\n"

        let result = parser.tokenize(htmlString: rawTableHTMLWithAttributes)
        XCTAssertEqual(result.displayText, expectedDisplayText)
        XCTAssertEqual(result.tags.count, 1)

        if let tableTag = result.tags.first {
            XCTAssertEqual(tableTag.tag, expectedTableTagName) // Verify attributes are part of the tag name
            XCTAssertNotNil(tableTag.tableData)
            if let tableData = tableTag.tableData {
                let decodedData = Base64Converter.decodeToData(base64String: tableData)
                XCTAssertNotNil(decodedData)
                if let d = decodedData, let decodedString = String(data: d, encoding: .utf8) {
                    XCTAssertEqual(decodedString, rawTableHTMLWithAttributes)
                }
            }
        }
    }
    
    // Placeholder for more tests to be added in subsequent steps.
    // For example:
    // func testSimpleBoldTag() { ... }
    // func testSimpleItalicTag() { ... }
}
