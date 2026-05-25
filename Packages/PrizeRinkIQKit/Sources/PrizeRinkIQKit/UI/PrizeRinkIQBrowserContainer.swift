import SwiftUI

#if canImport(UIKit)
import UIKit
import UniformTypeIdentifiers
import WebKit

public struct PrizeRinkIQBrowserContainer: UIViewRepresentable {
    public let configuration: PrizeRinkIQConfiguration
    @ObservedObject public var session: PrizeRinkIQBrowserSessionModel

    public init(configuration: PrizeRinkIQConfiguration, session: PrizeRinkIQBrowserSessionModel) {
        self.configuration = configuration
        self.session = session
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(session: session)
    }

    public func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: PrizeRinkIQBrowserRuntime.makeConfiguration())
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.scrollView.keyboardDismissMode = .interactive
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        PrizeRinkIQBrowserRuntime.activateGameAudio()
        session.webView = webView

        webView.load(URLRequest(
            url: configuration.initialURL,
            cachePolicy: .returnCacheDataElseLoad,
            timeoutInterval: configuration.requestTimeout
        ))
        return webView
    }

    public func updateUIView(_ webView: WKWebView, context: Context) {
        if session.webView !== webView {
            session.webView = webView
        }
    }

    public static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        coordinator.session.webView = nil
    }

    public final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, UIDocumentPickerDelegate {
        fileprivate let session: PrizeRinkIQBrowserSessionModel
        private var fileSelectionHandler: (([URL]?) -> Void)?

        init(session: PrizeRinkIQBrowserSessionModel) {
            self.session = session
        }

        public func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                session.isLoading = true
                session.errorMessage = nil
                session.refreshNavigationState()
            }
        }

        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            Task { @MainActor in
                session.errorMessage = nil
                session.refreshNavigationState()
                PrizeRinkIQBrowserRuntime.activateGameAudio()
            }
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                session.isLoading = false
                session.refreshNavigationState()
                PrizeRinkIQBrowserRuntime.activateGameAudio()
            }
        }

        public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            Task { @MainActor in
                session.isLoading = false
                session.errorMessage = "The page was interrupted and has been refreshed. If something still looks wrong, try again."
                session.refreshNavigationState()
                webView.reload()
                PrizeRinkIQBrowserRuntime.activateGameAudio()
            }
        }

        public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                session.isLoading = false
                session.errorMessage = error.localizedDescription
                session.refreshNavigationState()
            }
        }

        public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                session.isLoading = false
                session.errorMessage = error.localizedDescription
                session.refreshNavigationState()
            }
        }

        public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else {
                return .cancel
            }

            if url.scheme?.lowercased() == "about" {
                return .allow
            }

            if shouldOpenExternally(url) {
                await openExternally(url)
                return .cancel
            }

            return .allow
        }

        public func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil {
                if let url = navigationAction.request.url, shouldOpenExternally(url) {
                    Task { @MainActor in
                        UIApplication.shared.open(url)
                    }
                    return nil
                }
                webView.load(navigationAction.request)
            }
            return nil
        }

        @available(iOS 18.4, *)
        public func webView(
            _ webView: WKWebView,
            runOpenPanelWith parameters: WKOpenPanelParameters,
            initiatedByFrame frame: WKFrameInfo,
            completionHandler: @escaping ([URL]?) -> Void
        ) {
            fileSelectionHandler?(nil)
            fileSelectionHandler = completionHandler

            let picker = makeDocumentPicker(parameters: parameters)
            picker.delegate = self
            picker.allowsMultipleSelection = parameters.allowsMultipleSelection
            picker.modalPresentationStyle = .formSheet

            guard let presenter = webView.prizeRinkIQTopPresenter() else {
                fileSelectionHandler = nil
                completionHandler(nil)
                return
            }

            presenter.present(picker, animated: true)
        }

        public func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            fileSelectionHandler?(nil)
            fileSelectionHandler = nil
        }

        public func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            let copiedURLs = urls.compactMap(copyToTemporaryUploadDirectory)
            fileSelectionHandler?(copiedURLs.isEmpty ? nil : copiedURLs)
            fileSelectionHandler = nil
        }

        @available(iOS 18.4, *)
        private func makeDocumentPicker(parameters: WKOpenPanelParameters) -> UIDocumentPickerViewController {
            let contentTypes: [UTType]
            if parameters.allowsDirectories {
                contentTypes = [.item, .folder]
            } else {
                contentTypes = [.item]
            }

            return UIDocumentPickerViewController(forOpeningContentTypes: contentTypes, asCopy: true)
        }

        private func copyToTemporaryUploadDirectory(_ sourceURL: URL) -> URL? {
            let startedAccess = sourceURL.startAccessingSecurityScopedResource()
            defer {
                if startedAccess {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }

            let directoryURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("prizerinkiq-file-uploads", isDirectory: true)

            do {
                try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)

                let destinationURL = directoryURL
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(sourceURL.pathExtension)

                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
                return destinationURL
            } catch {
                return nil
            }
        }

        private func shouldOpenExternally(_ url: URL) -> Bool {
            guard let scheme = url.scheme?.lowercased() else { return false }
            return !["http", "https", "file", "about"].contains(scheme)
        }

        @MainActor
        private func openExternally(_ url: URL) {
            guard UIApplication.shared.canOpenURL(url) else { return }
            UIApplication.shared.open(url)
        }
    }
}

private extension WKWebView {
    func prizeRinkIQTopPresenter() -> UIViewController? {
        var controller = window?.rootViewController

        while let presented = controller?.presentedViewController {
            controller = presented
        }

        return controller
    }
}

@MainActor
public final class PrizeRinkIQBrowserSessionModel: ObservableObject {
    @Published public var isLoading = false
    @Published public var canGoBack = false
    @Published public var canGoForward = false
    @Published public var errorMessage: String?

    public weak var webView: WKWebView?

    public init() {}

    public func goBack() {
        guard webView?.canGoBack == true else { return }
        webView?.goBack()
        refreshNavigationState()
    }

    public func goForward() {
        guard webView?.canGoForward == true else { return }
        webView?.goForward()
        refreshNavigationState()
    }

    public func reload() {
        errorMessage = nil
        PrizeRinkIQBrowserRuntime.activateGameAudio()
        webView?.reload()
    }

    public func refreshNavigationState() {
        canGoBack = webView?.canGoBack ?? false
        canGoForward = webView?.canGoForward ?? false
    }
}
#endif
