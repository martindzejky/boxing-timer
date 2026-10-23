// Run from the repository root: swift scripts/render-icon.swift
// Rasterizes the editable glove SVG with the system WebKit SVG renderer.
import AppKit
import WebKit

@MainActor
final class IconRenderer: NSObject, WKNavigationDelegate {
  let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1024, height: 1024))
  let destination: URL

  init(destination: URL) {
    self.destination = destination
    super.init()
    webView.navigationDelegate = self
  }

  func render(svg: String) {
    webView.loadHTMLString(
      """
      <html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head>
      <body style="margin:0;width:1024px;height:1024px;background:#020c14;display:flex;align-items:center;justify-content:center">
      <div style="width:650px;height:650px">\(svg)</div></body></html>
      """, baseURL: nil)
  }

  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let config = WKSnapshotConfiguration()
    config.rect = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    config.snapshotWidth = 1024
    webView.takeSnapshot(with: config) { image, error in
      guard let image,
        let source = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
        let canvas = CGContext(
          data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 4096,
          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
      else { fatalError("Icon render failed: \(String(describing: error))") }
      canvas.draw(source, in: CGRect(x: 0, y: 0, width: 1024, height: 1024))
      guard let result = canvas.makeImage(),
        let data = NSBitmapImageRep(cgImage: result).representation(using: .png, properties: [:])
      else { fatalError("PNG encoding failed") }
      do { try data.write(to: self.destination) } catch { fatalError("\(error)") }
      exit(0)
    }
  }
}
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let svg = try String(
  contentsOf: root.appendingPathComponent("Design/boxing-glove.svg"), encoding: .utf8)
MainActor.assumeIsolated {
  let renderer = IconRenderer(
    destination: root.appendingPathComponent(
      "BoxingTimer/Assets.xcassets/AppIcon.appiconset/AppIcon.png"))
  renderer.render(svg: svg)
  RunLoop.main.run()
}
