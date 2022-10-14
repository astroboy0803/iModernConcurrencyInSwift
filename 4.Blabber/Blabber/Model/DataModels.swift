import Foundation

struct ServerStatus: Codable {
    let activeUsers: Int
}

struct Message: Codable, Identifiable, Hashable {
    let id: UUID
    let user: String?
    let message: String
    var date: Date
}

extension Message {
    init(message: String) {
        self.id = .init()
        self.date = .init()
        self.user = nil
        self.message = message
    }
}
