//
//  MarkdownHTML.swift
//  ScarlettKit
//
//  A small Markdown → HTML converter for the in-app user guide.
//  Supports what docs/user-guide.md uses: headings (with GitHub-style anchor ids),
//  paragraphs, bullet and numbered lists, tables, fenced code blocks, and inline
//  **bold**, *italic*, `code` and [links](url).
//

import Foundation

public enum MarkdownHTML {

    /// Converts Markdown to an HTML fragment (no <html>/<body>).
    public static func convert(_ markdown: String) -> String {
        var html: [String] = []
        let lines = markdown.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n")
        var i = 0
        var paragraph: [String] = []

        func flushParagraph() {
            if !paragraph.isEmpty {
                html.append("<p>" + inline(paragraph.joined(separator: " ")) + "</p>")
                paragraph = []
            }
        }

        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if trimmed.hasPrefix("```") {
                flushParagraph()
                var code: [String] = []
                i += 1
                while i < lines.count, !lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("```") {
                    code.append(escape(lines[i])); i += 1
                }
                html.append("<pre><code>" + code.joined(separator: "\n") + "</code></pre>")
                i += 1; continue
            }

            // Heading
            if let level = headingLevel(trimmed) {
                flushParagraph()
                let text = String(trimmed.dropFirst(level)).trimmingCharacters(in: .whitespaces)
                html.append("<h\(level) id=\"\(slug(text))\">\(inline(text))</h\(level)>")
                i += 1; continue
            }

            // Table: header row, separator row, body rows
            if trimmed.hasPrefix("|"), i + 1 < lines.count, isTableSeparator(lines[i + 1]) {
                flushParagraph()
                var out = "<table><thead><tr>" + cells(trimmed).map { "<th>\(inline($0))</th>" }.joined() + "</tr></thead><tbody>"
                i += 2
                while i < lines.count, lines[i].trimmingCharacters(in: .whitespaces).hasPrefix("|") {
                    out += "<tr>" + cells(lines[i]).map { "<td>\(inline($0))</td>" }.joined() + "</tr>"
                    i += 1
                }
                html.append(out + "</tbody></table>")
                continue
            }

            // Lists (bullet or numbered), with simple indented sub-items
            if isBullet(trimmed) || isNumbered(trimmed) {
                flushParagraph()
                let ordered = isNumbered(trimmed)
                var out = ordered ? "<ol>" : "<ul>"
                while i < lines.count {
                    let t = lines[i].trimmingCharacters(in: .whitespaces)
                    guard isBullet(t) || isNumbered(t) else { break }
                    let indented = lines[i].hasPrefix("  ") || lines[i].hasPrefix("\t")
                    let item = isBullet(t) ? String(t.dropFirst(2)) : String(t.drop(while: { $0 != " " }).dropFirst())
                    out += indented ? "<li class=\"sub\">\(inline(item))</li>" : "<li>\(inline(item))</li>"
                    i += 1
                }
                html.append(out + (ordered ? "</ol>" : "</ul>"))
                continue
            }

            if trimmed.isEmpty { flushParagraph() } else { paragraph.append(trimmed) }
            i += 1
        }
        flushParagraph()
        return html.joined(separator: "\n")
    }

    /// GitHub-style heading anchor: lowercase, spaces → '-', punctuation removed.
    public static func slug(_ text: String) -> String {
        let plain = text.replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
        var out = ""
        for ch in plain.lowercased() {
            if ch.isLetter || ch.isNumber || ch == "-" || ch == "_" { out.append(ch) }
            else if ch == " " { out.append("-") }
        }
        return out
    }

    // MARK: Helpers

    private static func headingLevel(_ s: String) -> Int? {
        let hashes = s.prefix(while: { $0 == "#" }).count
        return (1...6).contains(hashes) && s.dropFirst(hashes).first == " " ? hashes : nil
    }

    private static func isTableSeparator(_ s: String) -> Bool {
        let t = s.trimmingCharacters(in: .whitespaces)
        return t.hasPrefix("|") && t.allSatisfy { "|-: ".contains($0) } && t.contains("-")
    }

    private static func cells(_ row: String) -> [String] {
        var t = row.trimmingCharacters(in: .whitespaces)
        if t.hasPrefix("|") { t.removeFirst() }
        if t.hasSuffix("|") { t.removeLast() }
        // Split on | not escaped as \|
        var result: [String] = [], current = "", prev: Character = " "
        for ch in t {
            if ch == "|" && prev != "\\" { result.append(current); current = "" } else { current.append(ch) }
            prev = ch
        }
        result.append(current)
        return result.map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\\|", with: "|") }
    }

    private static func isBullet(_ s: String) -> Bool { s.hasPrefix("- ") || s.hasPrefix("* ") }

    private static func isNumbered(_ s: String) -> Bool {
        let digits = s.prefix(while: { $0.isNumber })
        return !digits.isEmpty && s.dropFirst(digits.count).hasPrefix(". ")
    }

    static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: ">", with: "&gt;")
    }

    /// Inline formatting: `code` first (contents untouched), then links, bold, italic.
    static func inline(_ text: String) -> String {
        var out = "", rest = Substring(text)
        while let tick = rest.firstIndex(of: "`") {
            out += inlineNoCode(String(rest[..<tick]))
            let after = rest[rest.index(after: tick)...]
            guard let close = after.firstIndex(of: "`") else { out += inlineNoCode(String(rest[tick...])); rest = ""; break }
            out += "<code>" + escape(String(after[..<close])) + "</code>"
            rest = after[after.index(after: close)...]
        }
        return out + inlineNoCode(String(rest))
    }

    private static func inlineNoCode(_ text: String) -> String {
        var s = escape(text)
        s = s.replacingOccurrences(of: #"\[([^\]]+)\]\(([^)\s]+)\)"#, with: "<a href=\"$2\">$1</a>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"\*\*([^*]+)\*\*"#, with: "<strong>$1</strong>", options: .regularExpression)
        s = s.replacingOccurrences(of: #"(?<![\w*])\*([^*\s][^*]*)\*(?![\w*])"#, with: "<em>$1</em>", options: .regularExpression)
        return s
    }
}
