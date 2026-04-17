import ActivityKit

struct SolarMatchActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var eventName: String
    var matchName: String
    var matchLabel: String
    var divisionName: String
    var fieldName: String
    var scheduledAt: Int64
    var redAlliance: String
    var blueAlliance: String
    var recentResultTitle: String
    var recentResultScore: String
    var predictedScoreLine: String
    var worldRankLabel: String
    var solarizeRankLabel: String
    var recordLabel: String
  }

  var teamNumber: String
}
