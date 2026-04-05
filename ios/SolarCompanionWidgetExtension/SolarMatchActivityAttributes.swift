import ActivityKit

struct SolarMatchActivityAttributes: ActivityAttributes {
  public struct ContentState: Codable, Hashable {
    var eventName: String
    var matchName: String
    var divisionName: String
    var fieldName: String
    var scheduledAt: Int64
    var redAlliance: String
    var blueAlliance: String
  }

  var teamNumber: String
}
