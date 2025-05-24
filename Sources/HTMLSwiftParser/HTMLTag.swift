import Foundation // For size_t if needed, though generally not for this struct

internal struct HTMLTag {
    internal var startPosition: UInt32
    internal var endPosition: UInt32
    internal var tag: String?
    internal var tableData: String?

    // It's good practice to provide an initializer
    internal init(startPosition: UInt32, endPosition: UInt32, tag: String?, tableData: String?) {
        self.startPosition = startPosition
        self.endPosition = endPosition
        self.tag = tag
        self.tableData = tableData
    }
}
