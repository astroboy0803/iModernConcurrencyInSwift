import Combine
import CoreLocation
import Foundation
import UIKit

class BlabberModel: ObservableObject {
    var username = ""
    var urlSession = URLSession.shared

    init() {}

    @Published var messages: [Message] = []

    func shareLocation() async throws {}

    func countdown(to message: String) async throws {
        guard !message.isEmpty else { return }
        
        var countdown = 3
        let counter: AsyncStream<String> = .init {
            do {
              try await Task.sleep(nanoseconds: 1_000_000_000)
            } catch {
              return nil
            }
            
            defer {
                countdown -= 1
            }
            
            if countdown > 0 {
                return "\(countdown) ..."
            }
            if countdown == 0 {
                return "🎉 " + message
            }
            return nil
        }
        for await countdownMessage in counter {
            try await say(countdownMessage)
        }
    }

    @MainActor
    func chat() async throws {
        guard
            let query = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
            let url = URL(string: "http://localhost:8080/chat/room?\(query)")
        else {
            throw "Invalid username"
        }

        let (stream, response) = try await liveURLSession.bytes(from: url, delegate: nil)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw "The server responded with an error."
        }

        print("Start live updates")

        try await withTaskCancellationHandler {
            print("End live updates")
            messages = []
        } operation: {
            try await readMessages(stream: stream)
        }
    }

    @MainActor
    private func readMessages(stream: URLSession.AsyncBytes) async throws {
        var iterator = stream.lines.makeAsyncIterator()
        guard let first = try await iterator.next() else {
            throw "No response from server"
        }

        let jsonDecoder: JSONDecoder = .init()

        guard let data = first.data(using: .utf8), let status = try? jsonDecoder.decode(ServerStatus.self, from: data) else {
            throw "Invalid response from server"
        }

        messages.append(.init(message: "\(status.activeUsers) active users"))

        for try await line in stream.lines {
            guard let data = line.data(using: .utf8), let update = try? jsonDecoder.decode(Message.self, from: data) else {
                continue
            }
            messages.append(update)
        }
    }

    func say(_ text: String, isSystemMessage: Bool = false) async throws {
        guard
            !text.isEmpty,
            let url = URL(string: "http://localhost:8080/chat/say")
        else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(
            Message(id: UUID(), user: isSystemMessage ? nil : username, message: text, date: Date())
        )

        let (_, response) = try await urlSession.data(for: request, delegate: nil)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw "The server responded with an error."
        }
    }

    private var liveURLSession: URLSession = {
        var configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = .infinity
        return URLSession(configuration: configuration)
    }()
}
