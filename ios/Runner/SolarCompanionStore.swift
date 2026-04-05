import Foundation

struct SolarUpcomingPayload: Codable {
  let id: Int
  let eventName: String
  let divisionName: String
  let matchName: String
  let fieldName: String
  let scheduledAt: Int64?
  let redAlliance: String
  let blueAlliance: String
}

struct SolarRecentResultPayload: Codable {
  let id: Int
  let eventName: String
  let divisionName: String
  let matchName: String
  let fieldName: String
  let completedAt: Int64?
  let allianceColor: String
  let allianceScore: Int
  let opponentScore: Int
  let redAlliance: String
  let blueAlliance: String
}

struct SolarCompanionPayload: Codable {
  let teamNumber: String
  let upcoming: SolarUpcomingPayload?
  let recentResults: [SolarRecentResultPayload]
  let updatedAt: Int64?
}

enum SolarCompanionStore {
  static let appGroupIdentifier = "group.dev.minzhang.solarV6.shared"
  static let payloadKey = "solar_companion_payload"
  static let announcedResultsKey = "solar_companion_announced_result_ids"

  static func sharedDefaults() -> UserDefaults {
    UserDefaults(suiteName: appGroupIdentifier) ?? .standard
  }
}
