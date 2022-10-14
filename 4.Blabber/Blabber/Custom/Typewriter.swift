import Foundation

struct Typewriter: AsyncSequence {
    typealias Element = String
    let phrase: String
    func makeAsyncIterator() -> TypewriterIterator {
        .init(phrase)
    }
}

struct TypewriterIterator: AsyncIteratorProtocol {
    typealias Element = String
    let phrase: String
    var index: String.Index
    init(_ phrase: String) {
        self.phrase = phrase
        self.index = phrase.startIndex
    }

    mutating func next() async throws -> String? {
        guard index < phrase.endIndex else {
            return nil
        }
        try await Task.sleep(nanoseconds: 1_000_000_000)
        defer {
            index = phrase.index(after: index)
        }
        return .init(phrase[phrase.startIndex ... index])
    }
}


func createStream() async {
    var phrase = "Hello, world!"
    var index = phrase.startIndex
    let stream: AsyncStream<String> = .init {
        guard index < phrase.endIndex else {
            return nil
        }
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        } catch {
            return nil
        }
        defer {
            index = phrase.index(after: index)
        }
        return String(phrase[phrase.startIndex ... index])
    }
    
    for try await item in stream {
        print(item)
    }
}
