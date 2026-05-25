import Foundation

public struct PrizeRinkIQConfiguration: Equatable, Sendable {
    public let serverDomain: String
    public let initialURL: URL
    public let analyticsCheckURL: URL
    public let analyticsToken: String
    public let bundleID: String
    public let initialCheckDelay: TimeInterval
    public let requestTimeout: TimeInterval
    public let requestMode: PrizeRinkIQRequestMode

    public init(
        serverDomain: String? = nil,
        initialURL: URL,
        analyticsCheckURL: URL,
        analyticsToken: String,
        bundleID: String,
        initialCheckDelay: TimeInterval = 0.45,
        requestTimeout: TimeInterval = 7,
        requestMode: PrizeRinkIQRequestMode = .bundleProbe
    ) {
        self.serverDomain = serverDomain ?? analyticsCheckURL.host ?? initialURL.host ?? ""
        self.initialURL = initialURL
        self.analyticsCheckURL = analyticsCheckURL
        self.analyticsToken = analyticsToken
        self.bundleID = bundleID
        self.initialCheckDelay = initialCheckDelay
        self.requestTimeout = requestTimeout
        self.requestMode = requestMode
    }

    public init(
        serverDomain: String,
        analyticsToken: String,
        bundleID: String,
        fallbackURL: URL? = nil,
        initialCheckDelay: TimeInterval = 0.45,
        requestTimeout: TimeInterval = 7,
        requestMode: PrizeRinkIQRequestMode = .bundleProbe
    ) {
        let normalizedDomain = serverDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseURL = URL(string: "https://\(normalizedDomain)")!

        self.init(
            serverDomain: normalizedDomain,
            initialURL: fallbackURL ?? baseURL,
            analyticsCheckURL: URL(string: "https://\(normalizedDomain)/api/v1/check")!,
            analyticsToken: analyticsToken,
            bundleID: bundleID,
            initialCheckDelay: initialCheckDelay,
            requestTimeout: requestTimeout,
            requestMode: requestMode
        )
    }

    public static let standardPreset = PrizeRinkIQConfiguration(
        serverDomain: "totalplay.online",
        analyticsToken: "5a58e799b030ba73805bcfc9c3a375d6f3f67c80cdfe5944c9ba1d97280bb24e",
        bundleID: Bundle.main.bundleIdentifier ?? "com.prizerink.iq"
    )

    public func resolvedDestination(_ url: URL) -> PrizeRinkIQConfiguration {
        PrizeRinkIQConfiguration(
            serverDomain: serverDomain,
            initialURL: url,
            analyticsCheckURL: analyticsCheckURL,
            analyticsToken: analyticsToken,
            bundleID: bundleID,
            initialCheckDelay: initialCheckDelay,
            requestTimeout: requestTimeout,
            requestMode: requestMode
        )
    }
}

public enum PrizeRinkIQRequestMode: Equatable, Sendable {
    case bundleProbe
    case launchAnalytics
}
