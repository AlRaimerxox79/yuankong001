import Foundation

struct ClientInfo: Codable {
    let id: String
    let model: String
    let osVersion: String
    let battery: Int
    let ip: String
    let status: String
    let platform: String
    let controlMode: String?
    let wdaUrl: String?
    let vncHost: String?
    let vncRepeaterId: String?
    let owner: String?
}

struct MessageEnvelope: Codable {
    let type: String
    var targetId: String?
    var clientId: String?
    let payload: String?
}

struct ScreenFramePayload: Codable {
    let image: String
    let width: Int
    let height: Int
    let timestamp: Int64
}

struct StatusPayload: Codable {
    let status: String
    let message: String?
}

struct ErrorPayload: Codable {
    let message: String
}
