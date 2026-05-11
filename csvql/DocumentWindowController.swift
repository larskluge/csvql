import Cocoa
import WebKit

final class DocumentWindowController: NSWindowController, WKScriptMessageHandler {

    private var webView: WKWebView!
    private var loadedURL: URL?

    convenience init() {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(
            frame: NSRect(origin: .zero, size: CSVRenderer.previewSize),
            configuration: config
        )

        let window = CSVWindow(
            contentRect: NSRect(origin: .zero, size: CSVRenderer.previewSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.backgroundColor = NSColor(red: 0.102, green: 0.102, blue: 0.102, alpha: 1.0)

        self.init(window: window)
        self.webView = webView

        config.userContentController.add(self, name: "csvql")

        webView.autoresizingMask = [.width, .height]
        window.contentView = webView

        if let screen = NSScreen.main {
            let visibleFrame = screen.visibleFrame
            let width = min(max(visibleFrame.width * 0.74, 860), 1280)
            let height = min(max(visibleFrame.height * 0.86, 700), 900)
            let size = NSSize(width: width, height: height)
            let origin = NSPoint(
                x: visibleFrame.midX - size.width / 2,
                y: visibleFrame.midY - size.height / 2
            )
            window.setFrame(NSRect(origin: origin, size: size), display: false)
        }
    }

    deinit {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "csvql")
    }

    func loadCSV(at url: URL) {
        do {
            let data = try CSVData.load(from: url)
            let html = CSVRenderer.render(data: data, interactive: true)
            webView.loadHTMLString(html, baseURL: nil)
            loadedURL = url
            window?.title = url.lastPathComponent
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let action = body["action"] as? String else { return }

        if action == "close" {
            window?.performClose(nil)
        }
    }

    // MARK: - Density

    private func setDensity(_ density: String) {
        webView.evaluateJavaScript("setDensity('\(density)')", completionHandler: nil)
    }

    @objc func setCompact(_ sender: Any?) { setDensity("compact") }
    @objc func setRegular(_ sender: Any?) { setDensity("regular") }
    @objc func setComfortable(_ sender: Any?) { setDensity("comfortable") }
}

private final class CSVWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }

        switch key {
        case "w":
            performClose(nil)
            return true
        case "q":
            NSApp.terminate(nil)
            return true
        default:
            return super.performKeyEquivalent(with: event)
        }
    }
}
