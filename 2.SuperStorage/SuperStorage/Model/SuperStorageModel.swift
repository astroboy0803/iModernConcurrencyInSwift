import Foundation

class SuperStorageModel: ObservableObject {
    @Published var downloads: [DownloadInfo] = []

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
        await addDownload(name: name)
        return Data()
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
        let parts = (0..<total).map { partInfo(index: $0, of: total) }
        return Data()
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
