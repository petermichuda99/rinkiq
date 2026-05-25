import SwiftUI

#if canImport(UIKit)
public struct PrizeRinkIQLaunchPanel: View {
    public let configuration: PrizeRinkIQConfiguration
    @AppStorage("settings.language") private var preferredLanguage = "en"
    @State private var isLoading = false
    @State private var statusMessage: String?
    @State private var presentedDestination: PrizeRinkIQPresentedDestination?

    public init(configuration: PrizeRinkIQConfiguration) {
        self.configuration = configuration
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("PrizeRink IQ Check", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline)
                .foregroundStyle(PrizeRinkIQKitTheme.accent)

            Text("Sends the PrizeRink IQ launch check and continues with the server-provided destination when available.")
                .font(.subheadline)
                .foregroundStyle(PrizeRinkIQKitTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await loadDestination() }
            } label: {
                HStack {
                    if isLoading {
                        ProgressView()
                            .tint(PrizeRinkIQKitTheme.navy)
                    }
                    Text(isLoading ? "Checking..." : "Check and open")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(PrizeRinkIQKitTheme.accent)
            .foregroundStyle(PrizeRinkIQKitTheme.navy)
            .disabled(isLoading)

            if let statusMessage {
                Text(statusMessage)
                    .font(.footnote)
                    .foregroundStyle(PrizeRinkIQKitTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(PrizeRinkIQKitTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .fullScreenCover(item: $presentedDestination) { destination in
            NavigationStack {
                PrizeRinkIQBrowserScreen(configuration: destination.configuration)
            }
        }
        .prizeRinkIQKeepsAudioAlive()
    }

    @MainActor
    private func loadDestination() async {
        isLoading = true
        statusMessage = nil
        defer { isLoading = false }

        do {
            let client = PrizeRinkIQRequestClient(configuration: configuration)
            let decision = try await client.loadDecision(preferredLanguage: preferredLanguage)

            guard decision.enabled else {
                statusMessage = "Server returned false. Continuing with the local app."
                return
            }

            guard let url = decision.url else {
                statusMessage = "Server returned true but did not include a URL."
                return
            }

            presentedDestination = PrizeRinkIQPresentedDestination(
                configuration: configuration.resolvedDestination(url)
            )
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

public struct PrizeRinkIQPresentedDestination: Identifiable {
    public let id = UUID()
    public let configuration: PrizeRinkIQConfiguration

    public init(configuration: PrizeRinkIQConfiguration) {
        self.configuration = configuration
    }
}
#endif
