import Foundation

extension String: Error {}

class LittleJohnModel: ObservableObject {
    @Published private(set) var tickerSymbols: [Stock] = []

    func startTicker(_ selectedSymbols: [String]) async throws {
//        tickerSymbols = []
        guard let url = URL(string: "http://localhost:8080/littlejohn/ticker?\(selectedSymbols.joined(separator: ","))") else {
            throw "The URL could not be created."
        }
        // 以前做法 URLSession.shared.bytes(from:delegate:)
        // 透過 delegate 做處理
        
        // return asyncquence
        let (stream, response) = try await liveURLSession.bytes(from: url)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw "The server responded with an error."
        }
        
        for try await line in stream.lines {
            let sortedSymbols = try JSONDecoder()
                .decode([Stock].self, from: .init(line.utf8))
                .sorted(by: { $0.name < $1.name })
            await MainActor.run {
                tickerSymbols = sortedSymbols
                print("updated: \(Date())")
            }
        }

        // challenge
        await MainActor.run(body: {
            tickerSymbols = []
            print("(outside)updated: \(Date())")
        })
    }

    private lazy var liveURLSession: URLSession = {
        var configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = .infinity
        return URLSession(configuration: configuration)
    }()

    func availableSymbols() async throws -> [String] {
        guard let url = URL(string: "http://localhost:8080/littlejohn/symbols") else {
            throw "The URL could not be created."
        }
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResp = response as? HTTPURLResponse, httpResp.statusCode == 200 else {
            throw "The server responded with an error."
        }
        return try JSONDecoder().decode([String].self, from: data)
    }
}
