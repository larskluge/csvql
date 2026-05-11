import Foundation
#if canImport(AppKit)
import AppKit
#endif

struct CSVRenderer {
    #if canImport(AppKit)
    static let previewSize = NSSize(width: 1180, height: 780)
    #endif
}

private class BundleAnchor {}
