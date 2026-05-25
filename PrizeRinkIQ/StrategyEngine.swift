import Foundation

enum StrategyEngine {
    static func recommend(
        rocks: [HouseRock],
        phase: EndPhase,
        hammer: HammerState,
        scoreDiff: Int,
        shotNumber: Int
    ) -> [StrategyCard] {
        let inHouse = rocks.filter { distance($0.x, $0.y, 0.5, 0.5) < 0.27 }
        let guards = rocks.filter { $0.y < 0.32 }
        let opponentInHouse = inHouse.filter { $0.color == .red }.count
        let ourInHouse = inHouse.filter { $0.color == .yellow }.count
        let crowded = inHouse.count >= 4
        let chasing = scoreDiff < 0
        let protectingLead = scoreDiff > 0
        let hasHammer = hammer == .withHammer

        var cards: [StrategyCard] = []

        if !hasHammer && (phase == .early || phase == .middle) {
            cards.append(StrategyCard(
                title: "Build a center-guard problem",
                summary: "Without hammer, make the scoring path narrow and invite a forced single.",
                call: .guardShot,
                risk: 38,
                why: [
                    "Center guards matter more when you want steals or pressure.",
                    "\(guards.count) guard stone(s) already shape the front.",
                    "Opponent must spend a rock clearing before they can score freely."
                ],
                beginnerTip: "A guard is not trying to score. It protects future scoring stones and blocks easy hits."
            ))
        }

        if opponentInHouse > ourInHouse || crowded {
            cards.append(StrategyCard(
                title: crowded ? "Simplify the house" : "Remove the scoring threat",
                summary: crowded ? "A controlled takeout opens a lane and reduces chaos." : "Take out the best opposing stone before it becomes protected.",
                call: .takeout,
                risk: crowded ? 64 : 52,
                why: [
                    "Opponent has \(opponentInHouse) stone(s) counting or close.",
                    "A hit can turn defense into a manageable blank or single.",
                    "Use normal weight if you want the shooter to stay, peel weight if the front is the issue."
                ],
                beginnerTip: "A takeout is best when the opponent already owns the scoring position."
            ))
        }

        if hasHammer && (phase == .late || phase == .finalStone) && !protectingLead {
            cards.append(StrategyCard(
                title: "Play the draw path",
                summary: "With hammer late, owning the button is often worth more than chasing a low-percentage double.",
                call: .draw,
                risk: 57,
                why: [
                    "Hammer gives you the last correction.",
                    "Shot \(shotNumber) is late enough to prioritize scoring position.",
                    chasing ? "You need points, so stay aggressive but playable." : "A blank is acceptable if the draw lane stays clean."
                ],
                beginnerTip: "A draw is a placement shot. Think destination first, power second."
            ))
        }

        if inHouse.count > 0 && phase != .early {
            cards.append(StrategyCard(
                title: "Freeze to shrink their options",
                summary: "Freezing onto a counting stone can remove easy takeouts and force a precise response.",
                call: .freeze,
                risk: 78,
                why: [
                    "There is a target stone near the rings.",
                    "A good freeze makes the opponent choose between risky weight and giving up control.",
                    "Miss light and you leave a guard; miss heavy and you may open the scoring area."
                ],
                beginnerTip: "A freeze stops touching another stone. It is powerful because the stones become hard to separate."
            ))
        }

        if protectingLead && !hasHammer {
            cards.append(StrategyCard(
                title: "Peel the front, keep it boring",
                summary: "When leading without hammer, removing guards can prevent multi-point ends.",
                call: .peel,
                risk: 45,
                why: [
                    "A lead changes the value of risk.",
                    "Open houses favor the team trying to limit damage.",
                    "Force them to draw for one instead of building a pile."
                ],
                beginnerTip: "A peel is a high-weight takeout, usually used to clear guards and open paths."
            ))
        }

        if cards.isEmpty {
            cards.append(StrategyCard(
                title: "Tap for usable pressure",
                summary: "A soft tap improves position without blowing up stones that are already helping you.",
                call: .tap,
                risk: 61,
                why: [
                    "The board is balanced, so position matters more than force.",
                    "A tap can move your stone into the four-foot or nudge an opponent behind cover.",
                    "It leaves a playable miss if weight is close."
                ],
                beginnerTip: "A tap is a gentle bump. It changes the angles while keeping rocks in play."
            ))
        }

        return cards.sorted { $0.risk < $1.risk }
    }

    static let lessons: [StrategyCard] = [
        StrategyCard(
            title: "Hammer changes everything",
            summary: "The team with the last stone can wait longer before committing to a scoring path.",
            call: .draw,
            risk: 36,
            why: ["With hammer, blanks and controlled singles can be good outcomes.", "Without hammer, guards and freezes create pressure."],
            beginnerTip: "Hammer means last rock in the end. Last rock is leverage."
        ),
        StrategyCard(
            title: "Guard when the front matters",
            summary: "Use guards to protect shot stones, block draw paths, or create steal pressure.",
            call: .guardShot,
            risk: 42,
            why: ["Early guards shape the whole end.", "Late guards can protect a winning stone."],
            beginnerTip: "A guard is useful only if it protects something or blocks a route."
        ),
        StrategyCard(
            title: "Freeze when hitting helps them",
            summary: "If a takeout could spill stones into a better spot for the opponent, freezing may be stronger.",
            call: .freeze,
            risk: 76,
            why: ["Freezes turn one stone into a problem cluster.", "They punish teams that need clean angles."],
            beginnerTip: "Freeze weight is delicate. Close is not always enough."
        ),
        StrategyCard(
            title: "Takeout when scoreboard says control",
            summary: "If you are leading or the house is crowded, removing trouble often beats adding more stones.",
            call: .takeout,
            risk: 50,
            why: ["Open play reduces steals.", "Hits can protect a lead and limit big ends."],
            beginnerTip: "A good takeout is not only a hit. Roll location decides whether it was useful."
        )
    ]

    private static func distance(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> Double {
        sqrt(pow(x1 - x2, 2) + pow(y1 - y2, 2))
    }
}
