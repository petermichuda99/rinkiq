import Foundation

final class RinkStore: ObservableObject {
    @Published var rocks: [HouseRock] = RinkSeed.rocks {
        didSet { save(rocks, key: StorageKey.rocks) }
    }
    @Published var plannedShots: [PlannedShot] = [
        PlannedShot(type: .freeze, targetX: 0.47, targetY: 0.52, weight: 42, curl: 7),
        PlannedShot(type: .guardShot, targetX: 0.50, targetY: 0.18, weight: 28, curl: 5)
    ] {
        didSet { save(plannedShots, key: StorageKey.plannedShots) }
    }
    @Published var matches: [MatchLog] = RinkSeed.matches {
        didSet { save(matches, key: StorageKey.matches) }
    }
    @Published var settings = RinkSettings() {
        didSet { save(settings, key: StorageKey.settings) }
    }

    init() {
        rocks = load([HouseRock].self, key: StorageKey.rocks) ?? RinkSeed.rocks
        plannedShots = load([PlannedShot].self, key: StorageKey.plannedShots) ?? [
            PlannedShot(type: .freeze, targetX: 0.47, targetY: 0.52, weight: 42, curl: 7),
            PlannedShot(type: .guardShot, targetX: 0.50, targetY: 0.18, weight: 28, curl: 5)
        ]
        matches = load([MatchLog].self, key: StorageKey.matches) ?? RinkSeed.matches
        settings = load(RinkSettings.self, key: StorageKey.settings) ?? RinkSettings()
    }

    var analytics: RinkAnalytics {
        let allShots = matches.flatMap(\.shots)
        let made = allShots.filter(\.made).count
        let score = allShots.isEmpty ? 0 : allShots.map(\.score).reduce(0, +) / allShots.count
        let grouped = Dictionary(grouping: allShots, by: \.type)
        let best = grouped.max { lhs, rhs in
            averageScore(lhs.value) < averageScore(rhs.value)
        }?.key
        let weakest = grouped.min { lhs, rhs in
            averageScore(lhs.value) < averageScore(rhs.value)
        }?.key

        return RinkAnalytics(
            matches: matches.count,
            wins: matches.filter { $0.ourScore > $0.theirScore }.count,
            shotMakeRate: allShots.isEmpty ? 0 : Double(made) / Double(allShots.count),
            averageShotScore: score,
            bestShot: best,
            weakestShot: weakest,
            stealRate: matches.isEmpty ? 0 : Double(matches.map(\.steals).reduce(0, +)) / Double(matches.count)
        )
    }

    var sortedMatches: [MatchLog] {
        matches.sorted { $0.date > $1.date }
    }

    func addRock(color: RockColor, at point: CGPoint) {
        rocks.append(HouseRock(color: color, x: point.x, y: point.y, label: "\(rocks.count + 1)"))
    }

    func resetBoard() {
        rocks = RinkSeed.rocks
        plannedShots = [
            PlannedShot(type: .freeze, targetX: 0.47, targetY: 0.52, weight: 42, curl: 7),
            PlannedShot(type: .guardShot, targetX: 0.50, targetY: 0.18, weight: 28, curl: 5)
        ]
    }

    func updateRock(_ rock: HouseRock, x: Double, y: Double) {
        guard let index = rocks.firstIndex(where: { $0.id == rock.id }) else { return }
        rocks[index].x = min(max(x, 0.08), 0.92)
        rocks[index].y = min(max(y, 0.05), 0.95)
    }

    func addPlannedShot(_ shot: PlannedShot) {
        plannedShots.insert(shot, at: 0)
    }

    func defaultEndScores() -> [EndScore] {
        (1...settings.defaultEnds).map { end in
            EndScore(end: end, ourScore: 0, theirScore: 0, weHadHammer: settings.weStartWithHammer ? end % 2 == 1 : end % 2 == 0)
        }
    }

    func saveMatch(
        title: String,
        opponent: String,
        venue: String,
        sheet: String,
        date: Date,
        notes: String,
        endScores: [EndScore]
    ) {
        let activeEnds = endScores.filter { $0.ourScore > 0 || $0.theirScore > 0 }
        let ourScore = activeEnds.map(\.ourScore).reduce(0, +)
        let theirScore = activeEnds.map(\.theirScore).reduce(0, +)
        let hammerEndsWon = activeEnds.filter { $0.weHadHammer && $0.ourScore > $0.theirScore }.count
        let steals = activeEnds.filter { !$0.weHadHammer && $0.ourScore > $0.theirScore }.count

        let match = MatchLog(
            date: date,
            title: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Club Match" : title,
            opponent: opponent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Opponent TBD" : opponent,
            venue: venue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Curling Club" : venue,
            sheet: sheet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Sheet TBD" : sheet,
            ourScore: ourScore,
            theirScore: theirScore,
            hammerEndsWon: hammerEndsWon,
            steals: steals,
            notes: notes,
            endScores: activeEnds,
            lineup: [],
            shots: []
        )
        matches.insert(match, at: 0)
    }

    func clearMatches() {
        matches.removeAll()
    }

    func restoreSampleData() {
        matches = RinkSeed.matches
    }

    func resetSettings() {
        settings = RinkSettings()
    }

    var exportSummary: String {
        var lines: [String] = ["PrizeRink IQ Match Export", "Matches: \(matches.count)", ""]
        for match in sortedMatches {
            lines.append("\(match.title), \(match.opponent), \(match.venue), \(match.sheet), \(match.ourScore)-\(match.theirScore)")
            if !match.endScores.isEmpty {
                let ends = match.endScores.map { "E\($0.end):\($0.ourScore)-\($0.theirScore)\($0.weHadHammer ? "H" : "")" }.joined(separator: " | ")
                lines.append(ends)
            }
            if !match.notes.isEmpty {
                lines.append("Notes: \(match.notes)")
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    func addSampleMatch() {
        let next = MatchLog(
            date: .now,
            title: "Practice Match",
            opponent: "Frostline Club",
            venue: "Community Sheet B",
            sheet: "Sheet B",
            ourScore: 6,
            theirScore: 6,
            hammerEndsWon: 3,
            steals: 1,
            notes: "Practice log: testing freeze-first calls and more patient guard timing.",
            endScores: [
                EndScore(end: 1, ourScore: 1, theirScore: 0, weHadHammer: false),
                EndScore(end: 2, ourScore: 0, theirScore: 2, weHadHammer: true),
                EndScore(end: 3, ourScore: 2, theirScore: 0, weHadHammer: true),
                EndScore(end: 4, ourScore: 0, theirScore: 1, weHadHammer: false),
                EndScore(end: 5, ourScore: 3, theirScore: 0, weHadHammer: true),
                EndScore(end: 6, ourScore: 0, theirScore: 3, weHadHammer: false)
            ],
            lineup: [
                LineupNote(role: "Lead", player: "Alex", note: "Owns center guard placement."),
                LineupNote(role: "Second", player: "Sam", note: "Can throw board weight both turns."),
                LineupNote(role: "Third", player: "Riley", note: "Best communicator on sweeping calls."),
                LineupNote(role: "Skip", player: "Jordan", note: "Prefers draw game with hammer.")
            ],
            shots: [
                ShotAccuracy(player: "Alex", type: .guardShot, called: "Center guard", made: true, score: 8, note: "Good line."),
                ShotAccuracy(player: "Sam", type: .takeout, called: "Open hit", made: true, score: 7, note: "Shooter stayed."),
                ShotAccuracy(player: "Riley", type: .freeze, called: "Freeze on shot rock", made: false, score: 6, note: "Slight bump."),
                ShotAccuracy(player: "Jordan", type: .draw, called: "Button draw", made: true, score: 9, note: "Game saver.")
            ]
        )
        matches.insert(next, at: 0)
    }

    private func averageScore(_ shots: [ShotAccuracy]) -> Double {
        guard !shots.isEmpty else { return 0 }
        return Double(shots.map(\.score).reduce(0, +)) / Double(shots.count)
    }

    private func save<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    private enum StorageKey {
        static let rocks = "PrizeRinkIQ.rocks"
        static let plannedShots = "PrizeRinkIQ.plannedShots"
        static let matches = "PrizeRinkIQ.matches"
        static let settings = "PrizeRinkIQ.settings"
    }
}
