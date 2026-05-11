import AppKit
import WebKit

guard CommandLine.arguments.count >= 2 else {
    fputs("Usage: csvql-screenshot <input.csv> [output.png]\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath: String
if CommandLine.arguments.count >= 3 {
    outputPath = CommandLine.arguments[2]
} else {
    let name = URL(fileURLWithPath: inputPath).deletingPathExtension().lastPathComponent
    outputPath = NSTemporaryDirectory() + name + ".png"
}

let url = URL(fileURLWithPath: inputPath)
guard FileManager.default.fileExists(atPath: url.path) else {
    fputs("Error: file not found: \(inputPath)\n", stderr)
    exit(1)
}

let csvData: CSVData
do {
    csvData = try CSVData.load(from: url)
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}

let html = CSVRenderer.render(data: csvData, interactive: false)
let size = CSVRenderer.previewSize

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let config = WKWebViewConfiguration()
let webView = WKWebView(frame: NSRect(origin: .zero, size: size), configuration: config)

let window = NSWindow(
    contentRect: NSRect(origin: NSPoint(x: -10000, y: -10000), size: size),
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
)
window.contentView = webView
window.orderBack(nil)

webView.loadHTMLString(html, baseURL: URL(string: "about:blank"))

func pollAndCapture(attempts: Int) {
    guard attempts > 0 else {
        fputs("Error: timed out waiting for render\n", stderr)
        NSApp.terminate(nil)
        return
    }
    webView.evaluateJavaScript("document.readyState") { result, _ in
        if let state = result as? String, state == "complete" {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                let snapConfig = WKSnapshotConfiguration()
                snapConfig.snapshotWidth = NSNumber(value: Int(size.width))
                webView.takeSnapshot(with: snapConfig) { image, error in
                    guard let image = image,
                          let tiff = image.tiffRepresentation,
                          let bitmap = NSBitmapImageRep(data: tiff),
                          let png = bitmap.representation(using: .png, properties: [:]) else {
                        fputs("Error: \(error?.localizedDescription ?? "failed to encode")\n", stderr)
                        NSApp.terminate(nil)
                        return
                    }
                    do {
                        try png.write(to: URL(fileURLWithPath: outputPath))
                        print(outputPath)
                    } catch {
                        fputs("Error: \(error.localizedDescription)\n", stderr)
                    }
                    NSApp.terminate(nil)
                }
            }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                pollAndCapture(attempts: attempts - 1)
            }
        }
    }
}

DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
    pollAndCapture(attempts: 50)
}

app.run()
