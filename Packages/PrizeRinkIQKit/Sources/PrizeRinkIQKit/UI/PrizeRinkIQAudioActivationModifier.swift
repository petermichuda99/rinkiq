import SwiftUI

#if canImport(UIKit)
import UIKit

private struct PrizeRinkIQAudioActivationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                PrizeRinkIQBrowserRuntime.activateGameAudio()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                PrizeRinkIQBrowserRuntime.activateGameAudio()
            }
    }
}

extension View {
    func prizeRinkIQKeepsAudioAlive() -> some View {
        modifier(PrizeRinkIQAudioActivationModifier())
    }
}
#endif
