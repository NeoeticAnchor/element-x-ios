// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import Foundation
import SwiftSoup

/// A versioned extension on m.text. The ordinary body remains a readable fallback.
nonisolated struct IrisHTMLCard: Codable, Hashable {
    static let contentKey = "art.irisr.html"
    static let composerPrefix = "<!-- iris-static-html-v1 -->"
    static let maximumBytes = 16000
    let version: Int
    let html: String
    let summary: String
    
    static func prepare(_ source: String) -> Self? {
        guard !source.isEmpty, source.utf8.count <= maximumBytes, source.filter({ $0 == "<" }).count <= 1024,
              let document = try? SwiftSoup.parse(source), let body = document.body() else { return nil }
        document.outputSettings().prettyPrint(pretty: false)
        do {
            try document.select("script,iframe,frame,frameset,object,embed,form,input,button,textarea,select,video,audio,svg,math,link,meta,base").remove()
            let styles = try document.select("style").map { try "<style>" + ($0.html()) + "</style>" }.joined()
            let allowedTags: Set = ["body", "style", "div", "span", "p", "br", "hr",
                                    "h1", "h2", "h3", "h4", "h5", "h6", "b", "strong", "i", "em", "u", "s", "del", "small", "sup", "sub",
                                    "pre", "code", "blockquote", "ul", "ol", "li", "table", "thead", "tbody", "tfoot", "tr", "th", "td",
                                    "caption", "section", "article", "header", "footer", "figure", "figcaption", "img"]
            for element in try body.getAllElements().reversed() {
                guard allowedTags.contains(element.tagName()) else {
                    try element.unwrap()
                    continue
                }
                for attribute in element.getAttributes()?.asList() ?? [] {
                    let key = attribute.getKey().lowercased()
                    let allowed = ["style", "class", "id", "colspan", "rowspan", "alt", "dir", "lang"].contains(key)
                    let embeddedImage = element.tagName() == "img" && key == "src" && isRasterDataURL(attribute.getValue())
                    if !allowed, !embeddedImage {
                        try element.removeAttr(attribute.getKey())
                    }
                }
            }
            // Move styles into the body so the payload is a standalone fragment.
            try body.select("style").remove()
            let summary = try String(body.text().prefix(1000))
            let html = try styles + (body.outerHtml())
            guard try !summary.isEmpty || !(body.select("img[src]").isEmpty()), html.utf8.count <= maximumBytes else { return nil }
            let card = Self(version: 1, html: html, summary: summary.isEmpty ? "HTML card" : summary)
            guard try card.extraContentJSON().utf8.count <= 32000 else { return nil }
            return card
        } catch {
            return nil
        }
    }
    
    static func fromEventJSON(_ json: String?) -> Self? {
        guard let json, let data = json.data(using: .utf8),
              let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = event["content"] as? [String: Any] else { return nil }
        let latest = content["m.new_content"] as? [String: Any] ?? content
        guard let payload = latest[contentKey],
              let payloadData = try? JSONSerialization.data(withJSONObject: payload),
              let card = try? JSONDecoder().decode(Self.self, from: payloadData), card.version == 1 else { return nil }
        return prepare(card.html)
    }
    
    func extraContentJSON() throws -> String {
        let data = try JSONEncoder().encode([Self.contentKey: self])
        guard let json = String(bytes: data, encoding: .utf8) else {
            throw EncodingError.invalidValue(self, .init(codingPath: [], debugDescription: "HTML card JSON is not UTF-8"))
        }
        return json
    }
    
    var document: String {
        """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; style-src 'unsafe-inline'; img-src data:;
        font-src 'none'; connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri 'none'; form-action 'none'">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>:root{color-scheme:light dark}body{margin:0;padding:8px;box-sizing:border-box;font:17px -apple-system;overflow-wrap:anywhere}
        img,table{max-width:100%}img{height:auto}table{border-collapse:collapse}td,th{padding:6px;border:1px solid #888}
        pre{white-space:pre-wrap}*{animation:none!important;transition:none!important}</style>
        </head>\(html)</html>
        """
    }
    
    private static func isRasterDataURL(_ value: String) -> Bool {
        ["data:image/png;base64,", "data:image/jpeg;base64,", "data:image/webp;base64,"].contains { value.lowercased().hasPrefix($0) }
    }
}
