import Cocoa

final class DocumentWindowController: NSWindowController {

    convenience init() {
        let contentSize = NSSize(width: 1180, height: 780)
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: contentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "csvql"
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    @objc func setCompact(_ sender: Any?) {
    }

    @objc func setRegular(_ sender: Any?) {
    }

    @objc func setComfortable(_ sender: Any?) {
    }
}
