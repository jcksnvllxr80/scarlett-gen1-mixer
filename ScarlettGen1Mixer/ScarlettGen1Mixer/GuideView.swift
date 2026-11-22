//
//  GuideView.swift
//  ScarlettGen1Mixer
//
//  Help ▸ User Guide: renders the bundled Help/user-guide.md in the app's theme.
//

import SwiftUI
import WebKit
import ScarlettKit

struct GuideView: View {
    var body: some View {
        GuideWebView(html: Self.page())
            .frame(minWidth: 700, minHeight: 500)
            .background(Theme.bg)
    }

    static func page() -> String {
        let md = Bundle.main.url(forResource: "user-guide", withExtension: "md")
            .flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? "# User guide\n\nThe guide is missing from this build."
        return """
        <!doctype html><html><head><meta charset="utf-8"><style>
        :root { color-scheme: dark; }
        body { background:#0b0d0e; color:#d6e0e3; font:14px/1.55 -apple-system, system-ui, sans-serif; max-width:880px; margin:28px auto; padding:0 28px; }
        h1,h2,h3 { color:#2dd4bf; font-weight:700; } h1 { font-size:26px; } h2 { font-size:20px; margin-top:34px; border-bottom:1px solid #23292c; padding-bottom:6px; } h3 { font-size:16px; color:#8ce9de; }
        a { color:#8ce9de; } strong { color:#f2f5f6; }
        code { font:12.5px ui-monospace, SFMono-Regular, monospace; background:#171b1d; padding:1px 5px; border-radius:4px; }
        pre { background:#121517; border:1px solid #23292c; border-radius:8px; padding:12px 14px; overflow-x:auto; }
        pre code { background:none; padding:0; line-height:1.35; }
        table { border-collapse:collapse; margin:12px 0; width:100%; }
        th, td { border:1px solid #23292c; padding:6px 10px; text-align:left; vertical-align:top; }
        th { background:#171b1d; color:#9fb0b5; font-weight:600; }
        li.sub { margin-left:22px; list-style-type:circle; }
        </style></head><body>
        \(MarkdownHTML.convert(md))
        </body></html>
        """
    }
}

/// WKWebView wrapper: anchor links scroll in place; http(s) links open in the default browser.
struct GuideWebView: NSViewRepresentable {
    let html: String

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let view = WKWebView()
        view.navigationDelegate = context.coordinator
        view.setValue(false, forKey: "drawsBackground")
        view.loadHTMLString(html, baseURL: nil)
        return view
    }

    func updateNSView(_ view: WKWebView, context: Context) {}

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            if action.navigationType == .linkActivated, let url = action.request.url, let scheme = url.scheme,
               scheme.hasPrefix("http") {
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }
    }
}
