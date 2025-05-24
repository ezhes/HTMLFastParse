import Foundation

internal struct Stack<Element> {
    private var storage: [Element] = []
    internal let capacity: Int

    internal init(capacity: Int) {
        self.capacity = capacity
        // It's good practice to reserve capacity if known,
        // though Swift arrays grow dynamically anyway.
        self.storage.reserveCapacity(capacity)
    }

    internal func isFull() -> Bool {
        // Returns true if the stack has reached its capacity.
        return storage.count == capacity
    }

    internal func isEmpty() -> Bool {
        // Returns true if the stack has no elements.
        return storage.isEmpty
    }

    internal mutating func push(_ element: Element) {
        // Pushes an element onto the stack, if it's not full.
        guard !isFull() else {
            // As per requirement, do not add element if stack is full.
            // Optionally, print a warning or handle error.
            // print("Stack overflow: Cannot push element onto a full stack.")
            return
        }
        storage.append(element)
    }

    internal mutating func pop() -> Element? {
        // Pops and returns the top element of the stack.
        // Returns nil if the stack is empty.
        return storage.popLast()
    }

    internal func peek() -> Element? {
        // Returns the top element of the stack without removing it.
        // Returns nil if the stack is empty.
        return storage.last
    }
}
