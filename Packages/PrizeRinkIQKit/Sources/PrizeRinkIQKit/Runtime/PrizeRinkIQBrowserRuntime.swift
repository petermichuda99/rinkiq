import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif
import WebKit
#if canImport(UIKit)
import UIKit
#endif

public enum PrizeRinkIQBrowserRuntime {
    public static func makeConfiguration() -> WKWebViewConfiguration {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        #if os(iOS)
        configuration.allowsInlineMediaPlayback = true
        configuration.allowsAirPlayForMediaPlayback = true
        configuration.allowsPictureInPictureMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        installAudioUnlockScript(into: configuration)
        activatePlaybackAudioSession()
        #endif

        if #available(iOS 14.0, macOS 11.0, *) {
            configuration.defaultWebpagePreferences.allowsContentJavaScript = true
            #if os(iOS)
            if UIDevice.current.userInterfaceIdiom == .pad {
                configuration.defaultWebpagePreferences.preferredContentMode = .desktop
            }
            #endif
        } else {
            configuration.preferences.javaScriptEnabled = true
        }

        return configuration
    }

    public static func prewarm(url: URL, timeout: TimeInterval = 8) {
        let webView = WKWebView(frame: .zero, configuration: makeConfiguration())
        webView.load(URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: timeout))
    }

    #if canImport(AVFoundation) && os(iOS)
    public static func activateGameAudio() {
        activatePlaybackAudioSession()
        PrizeRinkIQAudioKeeper.shared.start()
    }

    public static func activatePlaybackAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()

        do {
            try audioSession.setCategory(.playback, mode: .default, options: [])
            try audioSession.setActive(true, options: [])
        } catch {
            #if DEBUG
            print("PrizeRinkIQBrowserRuntime audio session activation failed: \(error)")
            #endif
        }
    }

    private static func installAudioUnlockScript(into configuration: WKWebViewConfiguration) {
        let script = WKUserScript(
            source: audioUnlockScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        configuration.userContentController.addUserScript(script)
    }

    private static let audioUnlockScript = """
    (function () {
      if (window.__prizeRinkIQAudioUnlockInstalled) {
        return;
      }
      window.__prizeRinkIQAudioUnlockInstalled = true;

      var unlocked = false;
      var keepAliveAudio = null;

      function ensureKeepAliveAudio() {
        if (keepAliveAudio) {
          return keepAliveAudio;
        }

        try {
          var audio = document.createElement("audio");
          audio.setAttribute("playsinline", "true");
          audio.setAttribute("webkit-playsinline", "true");
          audio.preload = "auto";
          audio.loop = true;
          audio.volume = 0.0001;
          audio.src = "data:audio/mp3;base64,//uQxAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAAFAAAGhgBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU=";
          audio.style.display = "none";
          document.documentElement.appendChild(audio);
          keepAliveAudio = audio;
        } catch (error) {}

        return keepAliveAudio;
      }

      function ensureMediaChannelOpen() {
        try {
          var audio = ensureKeepAliveAudio();
          if (!audio) {
            return;
          }

          var playPromise = audio.play();
          if (playPromise && playPromise.catch) {
            playPromise.catch(function () {});
          }
        } catch (error) {}
      }

      function unlockAudio() {
        if (unlocked) {
          return;
        }
        unlocked = true;

        try {
          var AudioContextRef = window.AudioContext || window.webkitAudioContext;
          if (AudioContextRef) {
            var context = window.__prizeRinkIQAudioContext;
            if (!context) {
              context = new AudioContextRef();
              window.__prizeRinkIQAudioContext = context;
            }

            if (context.state === "suspended" && context.resume) {
              context.resume().catch(function () {});
            }

            var buffer = context.createBuffer(1, 1, 22050);
            var source = context.createBufferSource();
            source.buffer = buffer;
            source.connect(context.destination);
            if (source.start) {
              source.start(0);
            } else if (source.noteOn) {
              source.noteOn(0);
            }
          }
        } catch (error) {}

        ensureMediaChannelOpen();

        window.removeEventListener("touchstart", unlockAudio, true);
        window.removeEventListener("touchend", unlockAudio, true);
        window.removeEventListener("pointerdown", unlockAudio, true);
        window.removeEventListener("mousedown", unlockAudio, true);
        window.removeEventListener("click", unlockAudio, true);
      }

      document.addEventListener("visibilitychange", function () {
        if (!document.hidden) {
          ensureMediaChannelOpen();

          try {
            var context = window.__prizeRinkIQAudioContext;
            if (context && context.state === "suspended" && context.resume) {
              context.resume().catch(function () {});
            }
          } catch (error) {}
        }
      }, true);

      window.addEventListener("touchstart", unlockAudio, true);
      window.addEventListener("touchend", unlockAudio, true);
      window.addEventListener("pointerdown", unlockAudio, true);
      window.addEventListener("mousedown", unlockAudio, true);
      window.addEventListener("click", unlockAudio, true);
    })();
    """
    #endif
}

#if canImport(AVFoundation) && os(iOS)
public final class PrizeRinkIQAudioKeeper {
    public static let shared = PrizeRinkIQAudioKeeper()

    private var player: AVAudioPlayer?

    private init() {}

    public func start() {
        guard player?.isPlaying != true else { return }

        PrizeRinkIQBrowserRuntime.activatePlaybackAudioSession()

        do {
            if player == nil {
                player = try AVAudioPlayer(data: keepAliveAudioData())
                player?.numberOfLoops = -1
                player?.volume = 0.001
                player?.prepareToPlay()
            }

            player?.play()
        } catch {
            #if DEBUG
            print("PrizeRinkIQAudioKeeper failed to start: \(error)")
            #endif
        }
    }

    public func stop() {
        player?.stop()
    }

    private func keepAliveAudioData() throws -> Data {
        let base64 = "//uQxAAAAAAAAAAAAAAAAAAAAAAASW5mbwAAAA8AAAAFAAAGhgBVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVVU="

        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "PrizeRinkIQAudioKeeper", code: -1)
        }

        return data
    }
}
#endif
