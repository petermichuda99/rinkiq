import SwiftUI

struct ContentView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                BoardView()
                    .navigationTitle("PrizeRink IQ")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Board", systemImage: "circle.grid.cross") }
            .tag(0)

            NavigationStack {
                SimulatorView()
                    .navigationTitle("End Simulator")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Simulator", systemImage: "play.circle.fill") }
            .tag(1)

            NavigationStack {
                MatchTrackerView()
                    .navigationTitle("Live Match")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Match", systemImage: "list.number") }
            .tag(2)

            NavigationStack {
                JournalView()
                    .navigationTitle("Match Journal")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("Journal", systemImage: "book.pages.fill") }
            .tag(3)

            NavigationStack {
                MoreView()
                    .navigationTitle("More")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .tabItem { Label("More", systemImage: "ellipsis") }
            .tag(4)
        }
        .tint(RinkTheme.prizePurple)
        .preferredColorScheme(.dark)
    }
}

private struct BoardView: View {
    @EnvironmentObject private var store: RinkStore
    @State private var selectedColor: RockColor = .yellow
    @State private var phase: EndPhase = .middle
    @State private var hammer: HammerState = .withHammer
    @State private var scoreDiff = 0
    @State private var shotNumber = 10

    private var recommendations: [StrategyCard] {
        StrategyEngine.recommend(
            rocks: store.rocks,
            phase: phase,
            hammer: hammer,
            scoreDiff: scoreDiff,
            shotNumber: shotNumber
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                boardPanel
                controls
                recommendationsPanel
            }
            .padding(16)
        }
        .background(RinkTheme.background.ignoresSafeArea())
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("House board")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Drag stones, set the scoreboard context, and read the next call.")
                    .font(.subheadline)
                    .foregroundStyle(RinkTheme.muted)
            }

            Spacer()

            Button {
                store.resetBoard()
            } label: {
                Image(systemName: "arrow.counterclockwise")
                    .font(.title3.weight(.bold))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .background(RinkTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel("Reset board")
        }
    }

    private var boardPanel: some View {
        VStack(spacing: 14) {
            RinkBoardView(
                rocks: store.rocks,
                plannedShots: store.plannedShots,
                selectedColor: selectedColor,
                onMove: store.updateRock,
                onTap: { point in store.addRock(color: selectedColor, at: point) }
            )
            .frame(height: 480)

            HStack(spacing: 10) {
                ForEach(RockColor.allCases) { color in
                    Button {
                        selectedColor = color
                    } label: {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color.color)
                                .frame(width: 14, height: 14)
                            Text(color.rawValue)
                                .font(.subheadline.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 11)
                    .background(selectedColor == color ? color.color.opacity(0.24) : RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedColor == color ? color.color : Color.white.opacity(0.08), lineWidth: 1)
                    )
                }
            }
        }
        .panelStyle()
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "End Context", icon: "slider.horizontal.3")

            Picker("Phase", selection: $phase) {
                ForEach(EndPhase.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Picker("Hammer", selection: $hammer) {
                ForEach(HammerState.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Stepper("Score differential: \(scoreDiff > 0 ? "+" : "")\(scoreDiff)", value: $scoreDiff, in: -6...6)
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Shot number")
                    Spacer()
                    Text("\(shotNumber)/16")
                        .foregroundStyle(RinkTheme.iceBlue)
                }
                .font(.subheadline.weight(.semibold))
                Slider(value: Binding(get: { Double(shotNumber) }, set: { shotNumber = Int($0.rounded()) }), in: 1...16, step: 1)
            }
        }
        .panelStyle()
    }

    private var recommendationsPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "IQ Recommendations", icon: "brain.head.profile")

            ForEach(recommendations.prefix(3)) { card in
                StrategyCardView(card: card)
            }
        }
        .panelStyle()
    }
}

private struct SimulatorView: View {
    @EnvironmentObject private var store: RinkStore
    @State private var shotType: ShotType = .freeze
    @State private var targetX = 0.50
    @State private var targetY = 0.50
    @State private var weight = 48
    @State private var curl = 6
    @State private var hasRunSimulation = false

    private var accuracy: Int {
        let weightFit = max(0, 100 - abs(weight - idealWeight) * 2)
        let curlFit = max(0, 100 - abs(curl - 6) * 9)
        let targetFit = Int((1.0 - min(0.55, hypot(targetX - 0.5, targetY - 0.5))) * 100)
        return max(12, min(98, (weightFit + curlFit + targetFit - shotType.difficulty / 3) / 3))
    }

    private var simulation: ShotSimulation {
        ShotSimulation.make(
            shotType: shotType,
            targetX: targetX,
            targetY: targetY,
            weight: weight,
            curl: curl,
            idealWeight: idealWeight,
            accuracy: accuracy,
            rocks: store.rocks
        )
    }

    private var boardRocks: [HouseRock] {
        guard hasRunSimulation else { return store.rocks }
        return store.rocks + [
            HouseRock(
                color: .yellow,
                x: simulation.landingX,
                y: simulation.landingY,
                label: "S"
            )
        ]
    }

    private var idealWeight: Int {
        switch shotType {
        case .guardShot: return 30
        case .draw: return 44
        case .takeout: return 72
        case .freeze: return 38
        case .tap: return 50
        case .peel: return 86
        }
    }

    private var verdict: String {
        if accuracy >= 78 { return "High-percentage call if line is clean." }
        if accuracy >= 55 { return "Playable, but miss tolerance matters." }
        return "Low margin. Consider a simpler call."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Move simulator")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Tune target, weight, and curl to preview risk before calling the shot.")
                            .font(.subheadline)
                            .foregroundStyle(RinkTheme.muted)
                    }
                    Spacer()
                }

                VStack(spacing: 14) {
                    RinkBoardView(
                        rocks: boardRocks,
                        plannedShots: [PlannedShot(type: shotType, targetX: targetX, targetY: targetY, weight: weight, curl: curl)],
                        selectedColor: .yellow,
                        onMove: { _, _, _ in },
                        onTap: { point in
                            targetX = point.x
                            targetY = point.y
                            hasRunSimulation = false
                        }
                    )
                    .frame(height: 420)

                    HStack(spacing: 10) {
                        Button {
                            hasRunSimulation = true
                        } label: {
                            Label("Run Shot", systemImage: "play.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(RinkTheme.prizePurple)
                        .foregroundStyle(RinkTheme.white)

                        Button {
                            store.addPlannedShot(PlannedShot(type: shotType, targetX: targetX, targetY: targetY, weight: weight, curl: curl))
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.headline)
                                .frame(width: 52, height: 44)
                        }
                        .buttonStyle(.plain)
                        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
                        .accessibilityLabel("Add to shot plan")
                    }
                }
                .panelStyle()

                VStack(alignment: .leading, spacing: 14) {
                    SectionHeader(title: "Shot Builder", icon: "target")

                    Picker("Shot", selection: $shotType) {
                        ForEach(ShotType.allCases) { shot in
                            Label(shot.rawValue, systemImage: shot.symbol).tag(shot)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlStyle()

                    ControlSlider(title: "Target line", value: targetXBinding, range: 8...92, suffix: "%")
                    ControlSlider(title: "Target depth", value: targetYBinding, range: 5...95, suffix: "%")
                    ControlSlider(title: "Weight", value: $weight, range: 15...95, suffix: "%")
                    ControlSlider(title: "Curl", value: $curl, range: 1...10, suffix: "/10")

                    simulationPanel
                }
                .panelStyle()
            }
            .padding(16)
        }
        .background(RinkTheme.background.ignoresSafeArea())
    }

    private var targetXBinding: Binding<Int> {
        Binding(
            get: { Int((targetX * 100).rounded()) },
            set: {
                targetX = Double($0) / 100.0
                hasRunSimulation = false
            }
        )
    }

    private var targetYBinding: Binding<Int> {
        Binding(
            get: { Int((targetY * 100).rounded()) },
            set: {
                targetY = Double($0) / 100.0
                hasRunSimulation = false
            }
        )
    }

    private var simulationPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Gauge(value: Double(accuracy), in: 0...100) {
                    Text("Accuracy")
                } currentValueLabel: {
                    Text("\(accuracy)")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(accuracy >= 75 ? RinkTheme.white : accuracy >= 55 ? RinkTheme.prizePurpleLight : RinkTheme.red)

                VStack(alignment: .leading, spacing: 6) {
                    Text(hasRunSimulation ? simulation.title : verdict)
                        .font(.headline)
                    Text("Difficulty \(shotType.difficulty)/100. Ideal weight estimate: \(idealWeight)%.")
                        .font(.caption)
                        .foregroundStyle(RinkTheme.muted)
                }
            }

            if hasRunSimulation {
                VStack(alignment: .leading, spacing: 8) {
                    Label(simulation.outcome, systemImage: simulation.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(simulation.tint)
                    Text(simulation.detail)
                        .font(.caption)
                        .foregroundStyle(RinkTheme.muted)
                    Text(simulation.coachNote)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RinkTheme.prizePurpleLight)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Tap the sheet or move target sliders, then run the shot to place the simulated stone marked S.")
                    .font(.caption)
                    .foregroundStyle(RinkTheme.muted)
            }
        }
        .padding(12)
        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ShotSimulation {
    var title: String
    var outcome: String
    var detail: String
    var coachNote: String
    var icon: String
    var tint: Color
    var landingX: Double
    var landingY: Double

    static func make(
        shotType: ShotType,
        targetX: Double,
        targetY: Double,
        weight: Int,
        curl: Int,
        idealWeight: Int,
        accuracy: Int,
        rocks: [HouseRock]
    ) -> ShotSimulation {
        let weightError = Double(weight - idealWeight) / 100.0
        let curlError = Double(curl - 6) / 100.0
        let landingX = clamp(targetX + curlError * 1.8, 0.08, 0.92)
        let landingY = clamp(targetY + weightError * 1.35, 0.05, 0.95)
        let nearest = rocks.min { lhs, rhs in
            distance(lhs.x, lhs.y, landingX, landingY) < distance(rhs.x, rhs.y, landingX, landingY)
        }
        let contactDistance = nearest.map { distance($0.x, $0.y, landingX, landingY) } ?? 1
        let isHeavy = weight > idealWeight + 8
        let isLight = weight < idealWeight - 8
        let isWide = abs(curl - 6) >= 3
        let made = accuracy >= 74 || contactDistance < 0.075

        let title: String
        let outcome: String
        let detail: String
        let coachNote: String
        let icon: String
        let tint: Color

        if made {
            title = "Shot is playable"
            outcome = "\(shotType.rawValue) lands in the scoring plan."
            detail = "Projected landing: line \(Int(landingX * 100))%, depth \(Int(landingY * 100))%. Contact window: \(contactDistance < 0.075 ? "stone-to-stone" : "open ice")."
            coachNote = "Call it if sweepers can hold line. Keep the same broom and focus on release speed."
            icon = "checkmark.seal.fill"
            tint = RinkTheme.white
        } else if isHeavy {
            title = "Heavy miss"
            outcome = "The stone likely slides too deep."
            detail = "Weight is \(weight - idealWeight)% above the model's ideal for this shot. It may roll through or open a backing stone."
            coachNote = shotType == .takeout || shotType == .peel ? "Heavy is acceptable only if removal matters more than shooter position." : "Take weight off before changing line."
            icon = "arrow.down.to.line.compact"
            tint = RinkTheme.red
        } else if isLight {
            title = "Light miss"
            outcome = "The stone likely comes up short."
            detail = "Weight is \(idealWeight - weight)% below ideal. This can leave a guard, but it may fail if you needed button pressure."
            coachNote = shotType == .guardShot ? "For a guard, light can still be useful. For a draw or freeze, add weight first." : "Add weight before asking for more curl."
            icon = "arrow.up.to.line.compact"
            tint = RinkTheme.prizePurpleLight
        } else if isWide {
            title = "Line miss"
            outcome = "Curl setting sends it outside the intended path."
            detail = "Curl \(curl)/10 moves the landing line to \(Int(landingX * 100))%. It can miss the contact angle even with good weight."
            coachNote = "Move the broom first. Do not solve a line problem by throwing harder."
            icon = "arrow.left.and.right"
            tint = RinkTheme.prizePurpleLight
        } else {
            title = "Low-margin call"
            outcome = "The shot is possible, but the miss is not friendly."
            detail = "Accuracy is \(accuracy)/100 with projected landing at line \(Int(landingX * 100))%, depth \(Int(landingY * 100))%."
            coachNote = "Choose this only if the scoreboard needs pressure. Otherwise play the simpler shot."
            icon = "exclamationmark.triangle.fill"
            tint = RinkTheme.red
        }

        return ShotSimulation(
            title: title,
            outcome: outcome,
            detail: detail,
            coachNote: coachNote,
            icon: icon,
            tint: tint,
            landingX: landingX,
            landingY: landingY
        )
    }

    private static func clamp(_ value: Double, _ lower: Double, _ upper: Double) -> Double {
        min(max(value, lower), upper)
    }

    private static func distance(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        hypot(x1 - x2, y1 - y2)
    }
}

private struct MatchTrackerView: View {
    @EnvironmentObject private var store: RinkStore
    @State private var title = "Club League Night"
    @State private var opponent = "North End Curling"
    @State private var venue = "Local Curling Club"
    @State private var sheet = "Sheet A"
    @State private var date = Date()
    @State private var notes = "Track hammer control, blank attempts, and how often we forced one."
    @State private var endScores: [EndScore] = (1...10).map {
        EndScore(end: $0, ourScore: 0, theirScore: 0, weHadHammer: $0 % 2 == 1)
    }
    @State private var savedBanner = false
    @State private var loadedDefaults = false

    private var activeEnds: [EndScore] {
        endScores.filter { $0.ourScore > 0 || $0.theirScore > 0 }
    }

    private var ourTotal: Int {
        activeEnds.map(\.ourScore).reduce(0, +)
    }

    private var theirTotal: Int {
        activeEnds.map(\.theirScore).reduce(0, +)
    }

    private var hammerEndsWon: Int {
        activeEnds.filter { $0.weHadHammer && $0.ourScore > $0.theirScore }.count
    }

    private var steals: Int {
        activeEnds.filter { !$0.weHadHammer && $0.ourScore > $0.theirScore }.count
    }

    private var scoreline: String {
        "\(ourTotal)-\(theirTotal)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                matchDetails
                liveScore
                endTable
                notesPanel
                savePanel
            }
            .padding(16)
        }
        .background(RinkTheme.background.ignoresSafeArea())
        .onAppear {
            guard !loadedDefaults else { return }
            title = "\(store.settings.teamName) Match"
            opponent = store.settings.defaultOpponent
            venue = store.settings.defaultVenue
            sheet = store.settings.defaultSheet
            endScores = store.defaultEndScores()
            loadedDefaults = true
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Match tracker")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                Text("Set the match details, keep score by end, then save it to the journal.")
                    .font(.subheadline)
                    .foregroundStyle(RinkTheme.muted)
            }

            Spacer()

            Text(scoreline)
                .font(.title2.monospacedDigit().weight(.black))
                .foregroundStyle(RinkTheme.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RinkTheme.prizePurple, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var matchDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Match Details", icon: "square.and.pencil")

            TextField("Match name", text: $title)
                .textInputAutocapitalization(.words)
                .inputFieldStyle()

            TextField("Opponent", text: $opponent)
                .textInputAutocapitalization(.words)
                .inputFieldStyle()

            HStack(spacing: 10) {
                TextField("Club / venue", text: $venue)
                    .textInputAutocapitalization(.words)
                    .inputFieldStyle()

                TextField("Sheet", text: $sheet)
                    .textInputAutocapitalization(.words)
                    .frame(width: 116)
                    .inputFieldStyle()
            }

            DatePicker("Date", selection: $date, displayedComponents: [.date])
                .font(.subheadline.weight(.semibold))
        }
        .panelStyle()
    }

    private var liveScore: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Live Score", icon: "list.number")

            HStack(spacing: 10) {
                ScoreBox(title: "Us", value: "\(ourTotal)", highlight: ourTotal >= theirTotal)
                ScoreBox(title: "Them", value: "\(theirTotal)", highlight: theirTotal > ourTotal)
            }

            HStack(spacing: 10) {
                SmallStat(title: "Ends Played", value: "\(activeEnds.count)")
                if store.settings.trackHammerConversion {
                    SmallStat(title: "Hammer Wins", value: "\(hammerEndsWon)")
                }
                if store.settings.trackSteals {
                    SmallStat(title: "Steals", value: "\(steals)")
                }
            }
        }
        .panelStyle()
    }

    private var endTable: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "End By End", icon: "tablecells.fill")

            ForEach($endScores) { $end in
                EndScoreRow(end: $end)
            }
        }
        .panelStyle()
    }

    private var notesPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Match Notes", icon: "note.text")
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(4...7)
                .inputFieldStyle()
        }
        .panelStyle()
    }

    private var savePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                store.saveMatch(
                    title: title,
                    opponent: opponent,
                    venue: venue,
                    sheet: sheet,
                    date: date,
                    notes: notes,
                    endScores: endScores
                )
                savedBanner = true
            } label: {
                Label("Save Match to Journal", systemImage: "tray.and.arrow.down.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(RinkTheme.prizePurple)
            .foregroundStyle(RinkTheme.white)

            if savedBanner {
                Label("Saved. Open Journal to review the match log.", systemImage: "checkmark.seal.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RinkTheme.white)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct EndScoreRow: View {
    @Binding var end: EndScore

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("End \(end.end)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 62, alignment: .leading)

                Toggle(isOn: $end.weHadHammer) {
                    Image(systemName: end.weHadHammer ? "hammer.fill" : "hammer")
                        .foregroundStyle(end.weHadHammer ? RinkTheme.prizePurpleLight : RinkTheme.muted)
                }
                .labelsHidden()
                .toggleStyle(.button)

                Spacer()

                Text(end.label)
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(RinkTheme.white)
                    .frame(width: 54, alignment: .trailing)
            }

            HStack(spacing: 12) {
                Stepper("Us \(end.ourScore)", value: $end.ourScore, in: 0...8)
                    .font(.caption.weight(.bold))

                Stepper("Them \(end.theirScore)", value: $end.theirScore, in: 0...8)
                    .font(.caption.weight(.bold))
            }
        }
        .padding(12)
        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ScoreBox: View {
    var title: String
    var value: String
    var highlight: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(RinkTheme.muted)
            Text(value)
                .font(.system(size: 44, weight: .black, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(RinkTheme.white)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(highlight ? RinkTheme.prizePurple.opacity(0.68) : RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(highlight ? RinkTheme.prizePurpleLight : Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

private struct JournalView: View {
    @EnvironmentObject private var store: RinkStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                dashboard

                Button {
                    store.addSampleMatch()
                } label: {
                    Label("Add Practice Match", systemImage: "square.and.pencil")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(RinkTheme.prizePurple)
                .foregroundStyle(RinkTheme.darkInk)

                ForEach(store.sortedMatches) { match in
                    MatchCard(match: match)
                }
            }
            .padding(16)
        }
        .background(RinkTheme.background.ignoresSafeArea())
    }

    private var dashboard: some View {
        let analytics = store.analytics
        return VStack(alignment: .leading, spacing: 14) {
            SectionHeader(title: "Team Snapshot", icon: "chart.bar.fill")
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricTile(title: "Matches", value: "\(analytics.matches)", icon: "calendar")
                MetricTile(title: "Wins", value: "\(analytics.wins)", icon: "checkmark.seal.fill")
                if store.settings.trackShotAccuracy {
                    MetricTile(title: "Shot Make", value: analytics.shotMakeRate.formatted(.percent.precision(.fractionLength(0))), icon: "scope")
                }
                MetricTile(title: "Avg Score", value: "\(analytics.averageShotScore)/10", icon: "star.fill")
                if store.settings.trackShotAccuracy {
                    MetricTile(title: "Best Shot", value: analytics.bestShot?.rawValue ?? "Learning", icon: "arrow.up.circle.fill")
                    MetricTile(title: "Work On", value: analytics.weakestShot?.rawValue ?? "Learning", icon: "wrench.adjustable.fill")
                }
                if store.settings.trackSteals {
                    MetricTile(title: "Steal Rate", value: analytics.stealRate.formatted(.number.precision(.fractionLength(1))), icon: "arrow.trianglehead.2.clockwise")
                }
            }
        }
        .panelStyle()
    }
}

private struct MoreView: View {
    var body: some View {
        VStack(spacing: 0) {
            NavigationLink {
                LearnView()
                    .navigationTitle("Strategy Lab")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                MoreRow(title: "Learn", icon: "graduationcap.fill")
            }

            Divider()
                .overlay(Color.white.opacity(0.14))
                .padding(.leading, 72)

            NavigationLink {
                SettingsView()
                    .navigationTitle("Settings")
                    .navigationBarTitleDisplayMode(.inline)
            } label: {
                MoreRow(title: "Settings", icon: "gearshape.fill")
            }

            Divider()
                .overlay(Color.white.opacity(0.14))
                .padding(.leading, 72)

            Spacer()
        }
        .padding(.top, 22)
        .background(RinkTheme.background.ignoresSafeArea())
    }
}

private struct MoreRow: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 18) {
            Image(systemName: icon)
                .font(.title2.weight(.bold))
                .foregroundStyle(RinkTheme.prizePurple)
                .frame(width: 36)

            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(RinkTheme.white)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.bold))
                .foregroundStyle(RinkTheme.muted)
        }
        .padding(.horizontal, 22)
        .frame(height: 92)
        .contentShape(Rectangle())
    }
}

private struct LearnView: View {
    @State private var selected: ShotType = .guardShot

    private var cards: [StrategyCard] {
        StrategyEngine.lessons.filter { $0.call == selected || selected == .guardShot && $0.call == .guardShot }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Strategy for new curlers")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    Text("Plain-language explanations for when to guard, draw, take out, freeze, tap, or peel.")
                        .font(.subheadline)
                        .foregroundStyle(RinkTheme.muted)
                }

                curlingInfo

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(ShotType.allCases) { shot in
                        Button {
                            selected = shot
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: shot.symbol)
                                    .font(.title2)
                                Text(shot.rawValue)
                                    .font(.caption.weight(.bold))
                            }
                            .frame(maxWidth: .infinity, minHeight: 78)
                        }
                        .buttonStyle(.plain)
                        .background(selected == shot ? RinkTheme.iceBlue.opacity(0.24) : RinkTheme.panel, in: RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selected == shot ? RinkTheme.iceBlue : Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                }

                explanation(for: selected)

                ForEach(StrategyEngine.lessons) { card in
                    StrategyCardView(card: card)
                }
            }
            .padding(16)
        }
        .background(RinkTheme.background.ignoresSafeArea())
    }

    private var curlingInfo: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Curling 101", icon: "info.circle.fill")

            InfoBlock(
                title: "What kind of game is this?",
                icon: "circle.grid.cross",
                text: "Curling is an ice strategy sport. Two teams slide granite stones toward the house, then sweep to control speed and curl. The goal is to finish an end with your stones closer to the button than the opponent's stones."
            )

            InfoBlock(
                title: "How an end works",
                icon: "list.number",
                text: "Teams alternate stones. Each player throws two, for 8 stones per team. The team with last stone has hammer. After all stones stop, only stones in the house can score."
            )

            InfoBlock(
                title: "Team roles",
                icon: "person.3.fill",
                text: "Lead sets guards and draw weight. Second often clears guards and hits. Third manages angles and setup shots. Skip calls strategy, reads ice, and usually throws last stones."
            )

            InfoBlock(
                title: "Clubs and leagues",
                icon: "building.columns.fill",
                text: "Most clubs run learn-to-curl nights, social leagues, competitive leagues, bonspiels, juniors, doubles, and corporate events. In the US and Canada, curling clubs are often community-run and beginner-friendly."
            )

            InfoBlock(
                title: "First night checklist",
                icon: "checklist.checked",
                text: "Wear warm flexible clothes, clean flat rubber-soled shoes, and gloves. Clubs usually provide brooms, sliders, stabilizers, and stones. Start with draw weight, safe sweeping, and basic line calls."
            )
        }
        .panelStyle()
    }

    private func explanation(for shot: ShotType) -> some View {
        let text: String
        switch shot {
        case .guardShot:
            text = "Guard when you need cover. It is strongest early without hammer or late when you already own shot rock."
        case .draw:
            text = "Draw when placement is the goal. With hammer, a calm draw can beat a flashy double because it controls the final score."
        case .takeout:
            text = "Takeout when the other team owns the house or when your lead asks for less clutter."
        case .freeze:
            text = "Freeze when a normal hit gives the opponent too many good rolls. It is difficult, but it can trap a scoring stone."
        case .tap:
            text = "Tap when you want to improve position gently. It is useful when blasting the house would help the opponent."
        case .peel:
            text = "Peel when front guards are the main danger. The goal is usually to remove the guard, not keep the shooter."
        }

        return VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "\(shot.rawValue) Read", icon: shot.symbol)
            Text(text)
                .font(.body)
                .foregroundStyle(RinkTheme.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .panelStyle()
    }
}

private struct SettingsView: View {
    @EnvironmentObject private var store: RinkStore
    @State private var showExport = false
    @State private var showClearConfirm = false
    @State private var showResetConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                matchDefaults
                statsPreferences
                privacyPanel
                appPreferences
                aboutPanel
            }
            .padding(16)
        }
        .background(RinkTheme.background.ignoresSafeArea())
        .confirmationDialog("Clear all saved matches?", isPresented: $showClearConfirm, titleVisibility: .visible) {
            Button("Clear Match Data", role: .destructive) {
                store.clearMatches()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every match from the in-app journal.")
        }
        .confirmationDialog("Reset settings?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset Settings", role: .destructive) {
                store.resetSettings()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(isPresented: $showExport) {
            ExportSheet(text: store.exportSummary)
                .preferredColorScheme(.dark)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Settings")
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
            Text("Set match defaults, choose what stats matter, and control local data.")
                .font(.subheadline)
                .foregroundStyle(RinkTheme.muted)
        }
    }

    private var matchDefaults: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Match Defaults", icon: "slider.horizontal.3")

            TextField("Team name", text: $store.settings.teamName)
                .textInputAutocapitalization(.words)
                .inputFieldStyle()

            TextField("Default opponent", text: $store.settings.defaultOpponent)
                .textInputAutocapitalization(.words)
                .inputFieldStyle()

            TextField("Default club / venue", text: $store.settings.defaultVenue)
                .textInputAutocapitalization(.words)
                .inputFieldStyle()

            HStack(spacing: 10) {
                TextField("Default sheet", text: $store.settings.defaultSheet)
                    .textInputAutocapitalization(.words)
                    .inputFieldStyle()

                Picker("Ends", selection: $store.settings.defaultEnds) {
                    Text("6").tag(6)
                    Text("8").tag(8)
                    Text("10").tag(10)
                }
                .pickerStyle(.segmented)
                .frame(width: 146)
            }

            Toggle("We start with hammer", isOn: $store.settings.weStartWithHammer)
                .toggleStyle(.switch)
        }
        .panelStyle()
    }

    private var statsPreferences: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Stats", icon: "chart.bar.fill")
            Toggle("Track steals", isOn: $store.settings.trackSteals)
            Toggle("Track hammer conversion", isOn: $store.settings.trackHammerConversion)
            Toggle("Track shot accuracy", isOn: $store.settings.trackShotAccuracy)
            Text("These settings control which metrics appear in the journal dashboard and saved match summaries.")
                .font(.caption)
                .foregroundStyle(RinkTheme.muted)
        }
        .panelStyle()
    }

    private var privacyPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Privacy & Data", icon: "hand.raised.fill")

            InfoBlock(
                title: "Local by default",
                icon: "lock.shield.fill",
                text: "PrizeRink IQ stores match notes, scores, and settings on this device in app memory for this build. There are no accounts, ads, or third-party sharing."
            )

            Toggle("Diagnostics placeholder", isOn: $store.settings.diagnosticsEnabled)

            Button {
                showExport = true
            } label: {
                Label("Preview Export", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(RinkTheme.prizePurpleLight)

            HStack(spacing: 10) {
                Button {
                    store.restoreSampleData()
                } label: {
                    Label("Restore Samples", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(RinkTheme.prizePurpleLight)

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label("Clear Data", systemImage: "trash.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .panelStyle()
    }

    private var appPreferences: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "App Preferences", icon: "gearshape.fill")

            Picker("Theme", selection: $store.settings.themeChoice) {
                ForEach(AppThemeChoice.allCases) { theme in
                    Text(theme.rawValue).tag(theme)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Haptics", isOn: $store.settings.hapticsEnabled)
            Toggle("Beginner tips", isOn: $store.settings.showBeginnerTips)

            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                Label("Reset Settings", systemImage: "arrow.trianglehead.2.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .panelStyle()
    }

    private var aboutPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "About", icon: "info.circle.fill")
            InfoBlock(
                title: "PrizeRink IQ",
                icon: "circle.grid.cross",
                text: "A curling strategy board, shot simulator, live match tracker, and team journal for club players and fans."
            )
            HStack {
                Text("Version")
                    .foregroundStyle(RinkTheme.muted)
                Spacer()
                Text("1.0")
                    .font(.subheadline.weight(.bold))
            }
            .font(.subheadline)
        }
        .panelStyle()
    }
}

private struct ExportSheet: View {
    @Environment(\.dismiss) private var dismiss
    var text: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(text.isEmpty ? "No match data yet." : text)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(RinkTheme.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }
            .background(RinkTheme.background.ignoresSafeArea())
            .navigationTitle("Export Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

private struct RinkBoardView: View {
    var rocks: [HouseRock]
    var plannedShots: [PlannedShot]
    var selectedColor: RockColor
    var onMove: (HouseRock, Double, Double) -> Void
    var onTap: (CGPoint) -> Void

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [RinkTheme.sheetTop, RinkTheme.sheetBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                sheetLines(size: size)
                house(size: size)
                plannedLayer(size: size)
                rocksLayer(size: size)
            }
            .contentShape(Rectangle())
            .coordinateSpace(name: "rinkBoard")
            .gesture(
                SpatialTapGesture()
                    .onEnded { value in
                        onTap(normalize(value.location, in: size))
                    }
            )
        }
    }

    private func sheetLines(size: CGSize) -> some View {
        ZStack {
            Path { path in
                path.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.12))
                path.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.12))
                path.move(to: CGPoint(x: size.width * 0.08, y: size.height * 0.84))
                path.addLine(to: CGPoint(x: size.width * 0.92, y: size.height * 0.84))
                path.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.08))
                path.addLine(to: CGPoint(x: size.width * 0.5, y: size.height * 0.92))
            }
            .stroke(Color.white.opacity(0.36), style: StrokeStyle(lineWidth: 2, dash: [7, 8]))

            ForEach([0.22, 0.78], id: \.self) { x in
                Rectangle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 1)
                    .position(x: size.width * x, y: size.height * 0.48)
            }
        }
    }

    private func house(size: CGSize) -> some View {
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.58)
        let radius = min(size.width, size.height) * 0.34
        return ZStack {
            Circle()
                .fill(RinkTheme.prizePurple.opacity(0.92))
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .fill(Color.white.opacity(0.94))
                .frame(width: radius * 1.45, height: radius * 1.45)
            Circle()
                .fill(RinkTheme.prizePurpleLight.opacity(0.88))
                .frame(width: radius * 0.92, height: radius * 0.92)
            Circle()
                .fill(Color.white.opacity(0.96))
                .frame(width: radius * 0.42, height: radius * 0.42)
            Circle()
                .fill(RinkTheme.prizePurple)
                .frame(width: radius * 0.18, height: radius * 0.18)
            Rectangle()
                .fill(Color.white.opacity(0.75))
                .frame(width: radius * 2.18, height: 2)
            Rectangle()
                .fill(Color.white.opacity(0.75))
                .frame(width: 2, height: radius * 2.18)
        }
        .position(center)
    }

    private func plannedLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(plannedShots) { shot in
                Path { path in
                    path.move(to: CGPoint(x: size.width * 0.5, y: size.height * 0.03))
                    path.addQuadCurve(
                        to: denormalize(CGPoint(x: shot.targetX, y: shot.targetY), in: size),
                        control: CGPoint(x: size.width * (0.5 + Double(shot.curl) * 0.018), y: size.height * 0.35)
                    )
                }
                .stroke(RinkTheme.prizePurpleLight.opacity(0.82), style: StrokeStyle(lineWidth: 3, lineCap: .round, dash: [8, 6]))

                ZStack {
                    Circle()
                        .fill(RinkTheme.prizePurple.opacity(0.34))
                    Image(systemName: shot.type.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(RinkTheme.white)
                }
                .frame(width: 38, height: 38)
                .position(denormalize(CGPoint(x: shot.targetX, y: shot.targetY), in: size))
            }
        }
    }

    private func rocksLayer(size: CGSize) -> some View {
        ZStack {
            ForEach(rocks) { rock in
                RockView(rock: rock)
                    .frame(width: 42, height: 42)
                    .position(denormalize(CGPoint(x: rock.x, y: rock.y), in: size))
                    .gesture(
                        DragGesture(coordinateSpace: .named("rinkBoard"))
                            .onChanged { value in
                                let point = normalize(value.location, in: size)
                                onMove(rock, point.x, point.y)
                            }
                    )
            }
        }
    }

    private func normalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: min(max(point.x / max(size.width, 1), 0), 1), y: min(max(point.y / max(size.height, 1), 0), 1))
    }

    private func denormalize(_ point: CGPoint, in size: CGSize) -> CGPoint {
        CGPoint(x: point.x * size.width, y: point.y * size.height)
    }
}

private struct RockView: View {
    var rock: HouseRock

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.28))
                .offset(y: 3)
            Circle()
                .fill(rock.color.color)
                .overlay(Circle().stroke(Color.white.opacity(0.72), lineWidth: 2))
            Capsule()
                .fill(RinkTheme.darkInk.opacity(0.72))
                .frame(width: 24, height: 9)
                .offset(y: -7)
            Text(rock.label)
                .font(.caption2.weight(.black))
                .foregroundStyle(rock.color == .yellow ? RinkTheme.darkInk : .white)
                .offset(y: 7)
        }
    }
}

private struct StrategyCardView: View {
    var card: StrategyCard

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: card.call.symbol)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(RinkTheme.darkInk)
                    .frame(width: 42, height: 42)
                    .background(RinkTheme.iceBlue, in: RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text(card.title)
                        .font(.headline)
                    Text(card.summary)
                        .font(.subheadline)
                        .foregroundStyle(RinkTheme.muted)
                }
                Spacer()
                Text("\(card.risk)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(card.risk > 70 ? RinkTheme.red : card.risk > 55 ? RinkTheme.prizePurpleLight : RinkTheme.white)
            }

            ForEach(card.why, id: \.self) { reason in
                Label(reason, systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(RinkTheme.primary)
            }

            Text(card.beginnerTip)
                .font(.caption.weight(.semibold))
                .foregroundStyle(RinkTheme.iceBlue)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RinkTheme.iceBlue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
        .padding(12)
        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MatchCard: View {
    @EnvironmentObject private var store: RinkStore
    var match: MatchLog

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(match.title)
                        .font(.headline)
                    Text("\(match.opponent) - \(match.venue), \(match.sheet)")
                        .font(.caption)
                        .foregroundStyle(RinkTheme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(match.ourScore)-\(match.theirScore)")
                        .font(.title3.monospacedDigit().weight(.bold))
                    Text(match.resultLabel)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(match.ourScore >= match.theirScore ? RinkTheme.white : RinkTheme.red)
                }
            }

            Text(match.notes)
                .font(.subheadline)
                .foregroundStyle(RinkTheme.primary)

            HStack(spacing: 10) {
                if store.settings.trackHammerConversion {
                    SmallStat(title: "Hammer Ends", value: "\(match.hammerEndsWon)")
                }
                if store.settings.trackSteals {
                    SmallStat(title: "Steals", value: "\(match.steals)")
                }
                SmallStat(title: "Ends", value: "\(match.endScores.count)")
            }

            if !match.endScores.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Score By End")
                        .font(.subheadline.weight(.bold))
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(match.endScores) { end in
                                VStack(spacing: 5) {
                                    Text("\(end.end)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(RinkTheme.muted)
                                    Text(end.label)
                                        .font(.caption.monospacedDigit().weight(.black))
                                    Image(systemName: end.weHadHammer ? "hammer.fill" : "minus")
                                        .font(.caption2)
                                        .foregroundStyle(end.weHadHammer ? RinkTheme.prizePurpleLight : RinkTheme.muted)
                                }
                                .frame(width: 52, height: 58)
                                .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                    }
                }
            }

            if !match.lineup.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Lineup Notes")
                        .font(.subheadline.weight(.bold))
                    ForEach(match.lineup) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Text(note.role)
                                .font(.caption.weight(.black))
                                .foregroundStyle(RinkTheme.darkInk)
                                .frame(width: 56)
                                .padding(.vertical, 5)
                                .background(RinkTheme.white, in: RoundedRectangle(cornerRadius: 6))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(note.player)
                                    .font(.caption.weight(.bold))
                                Text(note.note)
                                    .font(.caption)
                                    .foregroundStyle(RinkTheme.muted)
                            }
                        }
                    }
                }
            }

            if !match.shots.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Shot Accuracy")
                        .font(.subheadline.weight(.bold))
                    ForEach(match.shots) { shot in
                        HStack(spacing: 10) {
                            Image(systemName: shot.type.symbol)
                                .foregroundStyle(shot.made ? RinkTheme.white : RinkTheme.red)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(shot.player) - \(shot.called)")
                                    .font(.caption.weight(.bold))
                                Text(shot.note)
                                    .font(.caption2)
                                    .foregroundStyle(RinkTheme.muted)
                            }
                            Spacer()
                            Text("\(shot.score)/10")
                                .font(.caption.monospacedDigit().weight(.bold))
                        }
                        .padding(10)
                        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
        }
        .panelStyle()
    }
}

private struct InfoBlock: View {
    var title: String
    var icon: String
    var text: String

    var bodyView: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(RinkTheme.white)
                .frame(width: 34, height: 34)
                .background(RinkTheme.prizePurple, in: RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                Text(text)
                    .font(.caption)
                    .foregroundStyle(RinkTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
    }

    var body: some View {
        bodyView
    }
}

private struct SectionHeader: View {
    var title: String
    var icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(RinkTheme.iceBlue)
            Text(title)
                .font(.headline)
            Spacer()
        }
    }
}

private struct MetricTile: View {
    var title: String
    var value: String
    var icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(RinkTheme.iceBlue)
            Text(value)
                .font(.title3.monospacedDigit().weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption)
                .foregroundStyle(RinkTheme.muted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SmallStat: View {
    var title: String
    var value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline.monospacedDigit())
            Text(title)
                .font(.caption2)
                .foregroundStyle(RinkTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ControlSlider: View {
    var title: String
    @Binding var value: Int
    var range: ClosedRange<Int>
    var suffix: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value)\(suffix)")
                    .foregroundStyle(RinkTheme.iceBlue)
            }
            .font(.subheadline.weight(.semibold))
            Slider(value: Binding(get: { Double(value) }, set: { value = Int($0.rounded()) }), in: Double(range.lowerBound)...Double(range.upperBound), step: 1)
        }
    }
}

private enum RinkTheme {
    static let darkInk = Color(red: 0.06, green: 0.06, blue: 0.12)
    static let background = Color(red: 0.07, green: 0.07, blue: 0.13)
    static let panel = Color(red: 0.10, green: 0.09, blue: 0.17)
    static let row = Color.white.opacity(0.075)
    static let primary = Color.white.opacity(0.94)
    static let muted = Color.white.opacity(0.62)
    static let white = Color(red: 0.98, green: 0.97, blue: 0.99)
    static let prizePurple = Color(red: 0.48, green: 0.0, blue: 1.0)
    static let prizePurpleLight = Color(red: 0.67, green: 0.18, blue: 1.0)
    static let iceBlue = prizePurple
    static let blue = prizePurple
    static let red = Color(red: 1.0, green: 0.18, blue: 0.42)
    static let gold = prizePurpleLight
    static let green = white
    static let sheetTop = Color(red: 0.15, green: 0.13, blue: 0.25)
    static let sheetBottom = Color(red: 0.08, green: 0.07, blue: 0.15)
}

private extension View {
    func panelStyle() -> some View {
        self
            .padding(14)
            .background(RinkTheme.panel, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }

    func controlStyle() -> some View {
        self
            .padding(10)
            .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
    }

    func inputFieldStyle() -> some View {
        self
            .padding(12)
            .background(RinkTheme.row, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
    }
}
