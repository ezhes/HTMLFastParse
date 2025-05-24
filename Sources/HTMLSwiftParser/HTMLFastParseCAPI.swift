import Foundation // For UnsafePointer, String, etc.
// Ensure other necessary types from the module are available if not implicitly imported.
// Assuming HTMLParser, HTMLAttributedStringConverter are available via `import HTMLFastParse` 
// or directly if this file is part of the same module.
// Since this CAPI file is part of the HTMLFastParse module, internal types are accessible.

@_cdecl("fuzz_swift_parser_from_data")
public func fuzz_swift_parser_from_data(data: UnsafePointer<UInt8>?, length: Int) -> Int32 {
    guard let validData = data, length > 0 else {
        // Or handle empty input if the parser should accept it
        return 0 // Indicate success for empty/nil input, as it didn't crash
    }

    // Create a Swift String from the C data.
    // Important: The C fuzzer provides a buffer that might not be null-terminated
    // and might contain invalid UTF-8 sequences.
    // We need to handle this gracefully.
    let bufferPointer = UnsafeBufferPointer(start: validData, count: length)
    let htmlString = String(bytes: bufferPointer, encoding: .utf8) ?? "" 
    // If htmlString is empty due to invalid UTF-8, the parser will process an empty string.

    // Initialize the parser (it's internal, accessible within the module)
    let parser = HTMLParser() // Assuming HTMLParser is in the same module
    
    // Call the parsing logic
    // We don't need to use HTMLAttributedStringConverter here, just the core parser.
    let tokenizationResult = parser.tokenize(htmlString: htmlString)
    _ = parser.linearizeAttributes(tags: tokenizationResult.tags, displayText: tokenizationResult.displayText)

    // The fuzzer's main job is to detect crashes.
    // If we've reached here without crashing, it's a "success" from the API's perspective.
    // The original C fuzzer harness freed the results of tokenizeHTML and makeAttributesLinear.
    // Swift's ARC will handle memory for tokenizationResult and the linearized attributes.
    return 0 // Return 0 for success
}
