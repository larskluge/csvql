import Cocoa

final class DocumentController: NSDocument {

    override class var autosavesInPlace: Bool { false }
    override var isDocumentEdited: Bool { false }

    override func makeWindowControllers() {
        let wc = DocumentWindowController()
        addWindowController(wc)
        if let url = fileURL {
            wc.loadCSV(at: url)
        }
    }

    override func read(from url: URL, ofType typeName: String) throws {
    }
}
