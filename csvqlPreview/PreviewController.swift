import Cocoa
import QuickLookUI
import Quartz

class PreviewController: NSViewController, QLPreviewingController {

    override func loadView() {
        self.view = NSView()
    }

    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        handler(nil)
    }
}
