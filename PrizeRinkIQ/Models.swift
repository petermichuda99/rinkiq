import SwiftUI

enum RockColor: String, Codable, CaseIterable, Identifiable {
    case yellow = "White"
    case red = "Purple"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .yellow: return Color.white
        case .red: return Color(red: 0.48, green: 0.0, blue: 1.0)
        }
    }
}

enum ShotType: String, Codable, CaseIterable, Identifiable {
    case guardShot = "Guard"
    case draw = "Draw"
    case takeout = "Takeout"
    case freeze = "Freeze"
    case tap = "Tap"
    case peel = "Peel"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .guardShot: return "shield.lefthalf.filled"
        case .draw: return "scope"
        case .takeout: return "bolt.circle.fill"
        case .freeze: return "snowflake"
        case .tap: return "arrow.up.forward.circle"
        case .peel: return "wind"
        }
    }

    var difficulty: Int {
        switch self {
        case .guardShot: return 46
        case .draw: return 64
        case .takeout: return 58
        case .freeze: return 82
        case .tap: return 72
        case .peel: return 54
        }
    }
}

enum EndPhase: String, Codable, CaseIterable, Identifiable {
    case early = "Early End"
    case middle = "Middle End"
    case late = "Late End"
    case finalStone = "Final Stone"

    var id: String { rawValue }
}

enum HammerState: String, Codable, CaseIterable, Identifiable {
    case withHammer = "We Have Hammer"
    case withoutHammer = "They Have Hammer"

    var id: String { rawValue }
}

enum AppThemeChoice: String, Codable, CaseIterable, Identifiable {
    case prizePurple = "Prize Purple"
    case classicIce = "Classic Ice"

    var id: String { rawValue }
}

struct HouseRock: Identifiable, Codable, Equatable {
    var id = UUID()
    var color: RockColor
    var x: Double
    var y: Double
    var label: String
}

struct PlannedShot: Identifiable, Codable, Equatable {
    var id = UUID()
    var type: ShotType
    var targetX: Double
    var targetY: Double
    var weight: Int
    var curl: Int
}

struct MatchLog: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var title: String
    var opponent: String
    var venue: String
    var sheet: String
    var ourScore: Int
    var theirScore: Int
    var hammerEndsWon: Int
    var steals: Int
    var notes: String
    var endScores: [EndScore]
    var lineup: [LineupNote]
    var shots: [ShotAccuracy]

    var resultLabel: String {
        if ourScore == theirScore { return "Tie" }
        return ourScore > theirScore ? "Win" : "Loss"
    }
}

struct EndScore: Identifiable, Codable, Equatable {
    var id = UUID()
    var end: Int
    var ourScore: Int
    var theirScore: Int
    var weHadHammer: Bool

    var label: String {
        ourScore == theirScore ? "-" : "\(ourScore)-\(theirScore)"
    }
}

struct ShotAccuracy: Identifiable, Codable, Equatable {
    var id = UUID()
    var player: String
    var type: ShotType
    var called: String
    var made: Bool
    var score: Int
    var note: String
}

struct LineupNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var role: String
    var player: String
    var note: String
}

struct StrategyCard: Identifiable, Equatable {
    var id = UUID()
    var title: String
    var summary: String
    var call: ShotType
    var risk: Int
    var why: [String]
    var beginnerTip: String
}

struct RinkAnalytics {
    var matches: Int
    var wins: Int
    var shotMakeRate: Double
    var averageShotScore: Int
    var bestShot: ShotType?
    var weakestShot: ShotType?
    var stealRate: Double
}

struct RinkSettings: Codable, Equatable {
    var teamName: String = "PrizeRink CC"
    var defaultOpponent: String = "Opponent TBD"
    var defaultVenue: String = "Local Curling Club"
    var defaultSheet: String = "Sheet A"
    var defaultEnds: Int = 8
    var weStartWithHammer: Bool = true
    var trackSteals: Bool = true
    var trackHammerConversion: Bool = true
    var trackShotAccuracy: Bool = true
    var showBeginnerTips: Bool = true
    var hapticsEnabled: Bool = true
    var themeChoice: AppThemeChoice = .prizePurple
    var diagnosticsEnabled: Bool = false
}

enum RinkSeed {
    static let rocks: [HouseRock] = [
        HouseRock(color: .yellow, x: 0.50, y: 0.50, label: "1"),
        HouseRock(color: .red, x: 0.43, y: 0.57, label: "2"),
        HouseRock(color: .yellow, x: 0.58, y: 0.63, label: "3"),
        HouseRock(color: .red, x: 0.52, y: 0.33, label: "4"),
        HouseRock(color: .yellow, x: 0.37, y: 0.27, label: "G"),
        HouseRock(color: .red, x: 0.66, y: 0.24, label: "C")
    ]

    static let matches: [MatchLog] = [
        MatchLog(
            date: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
            title: "Tuesday Club League",
            opponent: "North Shore CC",
            venue: "Duluth Curling Club",
            sheet: "Sheet C",
            ourScore: 7,
            theirScore: 5,
            hammerEndsWon: 4,
            steals: 1,
            notes: "Protected shot rock better after the fourth end. Need calmer weight calls on intern draws.",
            endScores: [
                EndScore(end: 1, ourScore: 0, theirScore: 1, weHadHammer: false),
                EndScore(end: 2, ourScore: 2, theirScore: 0, weHadHammer: true),
                EndScore(end: 3, ourScore: 1, theirScore: 0, weHadHammer: false),
                EndScore(end: 4, ourScore: 0, theirScore: 2, weHadHammer: false),
                EndScore(end: 5, ourScore: 2, theirScore: 0, weHadHammer: true),
                EndScore(end: 6, ourScore: 0, theirScore: 1, weHadHammer: false),
                EndScore(end: 7, ourScore: 1, theirScore: 0, weHadHammer: true),
                EndScore(end: 8, ourScore: 1, theirScore: 1, weHadHammer: false)
            ],
            lineup: [
                LineupNote(role: "Lead", player: "Maya", note: "Great corner guards, 9/12 in playable spots."),
                LineupNote(role: "Second", player: "Owen", note: "Peels were strong, missed one runback angle."),
                LineupNote(role: "Third", player: "Nora", note: "Good broom on freezes."),
                LineupNote(role: "Skip", player: "Eli", note: "Aggressive with hammer, conservative without.")
            ],
            shots: [
                ShotAccuracy(player: "Maya", type: .guardShot, called: "Tight center guard", made: true, score: 8, note: "Perfect lane control."),
                ShotAccuracy(player: "Owen", type: .takeout, called: "Hit and roll behind corner", made: false, score: 5, note: "Nosed it."),
                ShotAccuracy(player: "Nora", type: .freeze, called: "Freeze to button stone", made: true, score: 9, note: "Forced one."),
                ShotAccuracy(player: "Eli", type: .draw, called: "Full four-foot draw", made: true, score: 8, note: "Quiet release.")
            ]
        ),
        MatchLog(
            date: Calendar.current.date(byAdding: .day, value: -8, to: .now) ?? .now,
            title: "Friendly Bonspiel",
            opponent: "Lakeview Granite",
            venue: "Winnipeg Granite Club",
            sheet: "Sheet 2",
            ourScore: 4,
            theirScore: 6,
            hammerEndsWon: 2,
            steals: 0,
            notes: "Chased doubles too early. House was cluttered and we did not convert last-rock advantage.",
            endScores: [
                EndScore(end: 1, ourScore: 0, theirScore: 2, weHadHammer: true),
                EndScore(end: 2, ourScore: 1, theirScore: 0, weHadHammer: true),
                EndScore(end: 3, ourScore: 0, theirScore: 1, weHadHammer: false),
                EndScore(end: 4, ourScore: 2, theirScore: 0, weHadHammer: true),
                EndScore(end: 5, ourScore: 0, theirScore: 2, weHadHammer: false),
                EndScore(end: 6, ourScore: 1, theirScore: 0, weHadHammer: true),
                EndScore(end: 7, ourScore: 0, theirScore: 1, weHadHammer: false)
            ],
            lineup: [
                LineupNote(role: "Lead", player: "Maya", note: "Two long guards opened the house."),
                LineupNote(role: "Second", player: "Owen", note: "Takeout weight was heavy."),
                LineupNote(role: "Third", player: "Nora", note: "Reliable tap weight."),
                LineupNote(role: "Skip", player: "Eli", note: "Needed more blank-end discipline.")
            ],
            shots: [
                ShotAccuracy(player: "Maya", type: .guardShot, called: "Corner guard", made: false, score: 4, note: "Too deep."),
                ShotAccuracy(player: "Owen", type: .peel, called: "Peel center guard", made: true, score: 8, note: "Clean."),
                ShotAccuracy(player: "Nora", type: .tap, called: "Tap to back four", made: true, score: 7, note: "Useful miss."),
                ShotAccuracy(player: "Eli", type: .draw, called: "Blank attempt", made: false, score: 5, note: "Overcurled.")
            ]
        )
    ]
}
