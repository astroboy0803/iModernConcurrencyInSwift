import Foundation

class SuperStorageModel: ObservableObject {
    @Published var downloads: [DownloadInfo] = []
    @TaskLocal static var supportsPartialDownloads = false

    func download(file: DownloadFile) async throws -> Data {
        let url = try getURL(string: "http://localhost:8080/files/download?\(file.name)")

        await addDownload(name: file.name)
        let data = try await fetchData(url: url)
        await updateDownload(name: file.name, progress: 1.0)

        return data
    }

    func downloadWithProgress(file: DownloadFile) async throws -> Data {
        return try await downloadWithProgress(fileName: file.name, name: file.name, size: file.size)
    }

    private func downloadWithProgress(fileName: String, name: String, size: Int, offset: Int? = nil) async throws -> Data {
        guard let url = URL(string: "http://localhost:8080/files/download?\(fileName)") else {
            throw "Could not create the URL."
        }

        let result: (downloadStream: URLSession.AsyncBytes, response: URLResponse)
        let statusCode: Int
        if let offset = offset {
            let request: URLRequest = .init(url: url, offset: offset, length: size)
            result = try await URLSession.shared.bytes(for: request, delegate: nil)
            statusCode = 206
        } else {
            result = try await URLSession.shared.bytes(from: url, delegate: nil)
            statusCode = 200
        }
        guard (result.response as? HTTPURLResponse)?.statusCode == statusCode else {
            throw "The server responded with an error."
        }
        await addDownload(name: name)

        var asyncDownloadIterator = result.downloadStream.makeAsyncIterator()
        let accumulator: ByteAccumulator = .init(name: name, size: size)
        while !stopDownloads, !accumulator.checkCompleted() {
            while !accumulator.isBatchCompleted,
                  let byte = try await asyncDownloadIterator.next()
            {
                accumulator.append(byte)
            }
            let progress = accumulator.progress
            Task.detached(priority: .medium) {
                await self.updateDownload(name: name, progress: progress)
            }
            print(accumulator.description)
        }
        if stopDownloads, !Self.supportsPartialDownloads {
            throw CancellationError()
        }
        return accumulator.data
    }

    func multiDownloadWithProgress(file: DownloadFile) async throws -> Data {
        func partInfo(index: Int, of count: Int) -> (offset: Int, size: Int, name: String) {
            let standardPartSize = Int((Double(file.size) / Double(count)).rounded(.up))
            let partOffset = index * standardPartSize
            let partSize = min(standardPartSize, file.size - partOffset)
            let partName = "\(file.name) (part \(index + 1))"
            return (offset: partOffset, size: partSize, name: partName)
        }
        let total = 4
        let parts = (0 ..< total)
            .map { partInfo(index: $0, of: total) }

        async let task1 = downloadWithProgress(fileName: file.name, name: parts[0].name, size: parts[0].size, offset: parts[0].offset)

        async let task2 = downloadWithProgress(fileName: file.name, name: parts[1].name, size: parts[1].size, offset: parts[1].offset)

        async let task3 = downloadWithProgress(fileName: file.name, name: parts[2].name, size: parts[2].size, offset: parts[2].offset)

        async let task4 = downloadWithProgress(fileName: file.name, name: parts[3].name, size: parts[3].size, offset: parts[3].offset)

        return try await [task1, task2, task3, task4]
            .reduce(Data(), +)
    }

    var stopDownloads = false

    func reset() {
        stopDownloads = false
        downloads.removeAll()
    }

    func availableFiles() async throws -> [DownloadFile] {
        let url = try getURL(string: "http://localhost:8080/files/list")
        let data = try await fetchData(url: url)
        guard let list = try? JSONDecoder().decode([DownloadFile].self, from: data) else {
            throw "The server response was not recognized."
        }
        return list
    }

    func status() async throws -> String {
        let url = try getURL(string: "http://localhost:8080/files/status")
        let data = try await fetchData(url: url)
        return String(decoding: data, as: UTF8.self)
    }

    private func getURL(string: String) throws -> URL {
        guard let url = URL(string: string) else {
            throw "Could not create the URL."
        }
        return url
    }

    private func fetchData(url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url, delegate: nil)
        guard let resp = response as? HTTPURLResponse, resp.statusCode == 200 else {
            throw "The server responded with an error."
        }
        return data
    }
}

extension SuperStorageModel {
    @MainActor func addDownload(name: String) {
        let downloadInfo = DownloadInfo(id: UUID(), name: name, progress: 0.0)
        downloads.append(downloadInfo)
    }

    @MainActor func updateDownload(name: String, progress: Double) {
        if let index = downloads.firstIndex(where: { $0.name == name }) {
            var info = downloads[index]
            info.progress = progress
            downloads[index] = info
        }
    }
}
