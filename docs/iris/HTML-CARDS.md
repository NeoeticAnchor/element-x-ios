# Static HTML cards

In an empty chat composer, choose **+ → HTML card**, paste HTML, select **Preview
card**, then Send. The recipient sees the card inside the timeline bubble without
opening a document or a browser. The preview is required before sending; changing
the source invalidates it. Existing text drafts, replies, and edits keep their
ordinary composer workflow.

## Supported content

Static HTML and inline CSS support headings, tables, lists, code, colours, and
layout. Embedded PNG/JPEG/WebP data images work within the document size limit.
External images, Matrix media URLs inside HTML, fonts, links, JavaScript, forms,
SVG, frames, and other embedded applications are not enabled in this first version.
Use normal encrypted image messages for large images. No HTML resources are
fetched from a third party or from Iris.

The source and sanitised fragment are limited to 16,000 UTF-8 bytes; encoded
extension JSON is limited to 32,000 bytes to leave room for the ordinary message
body and Matrix encryption overhead. Long cards scroll inside the bubble after
reaching 1,800 points. Invalid/unknown card payloads retain the standard message
body. A WebKit rendering failure explicitly shows an error and the message summary.

## Wire format

Cards are ordinary `m.room.message` events with `msgtype: m.text` and a readable
`body`, plus this versioned extension in the event content:

```json
{
  "msgtype": "m.text",
  "body": "Report: Ready",
  "art.irisr.html": {
    "version": 1,
    "html": "<h2>Report</h2><p>Ready</p>",
    "summary": "Report: Ready"
  }
}
```

The existing Rust SDK send queue handles delivery and room encryption through
`sendWithExtraContent`. There is no separate upload, public hosting URL, or server
change. The timeline reads the extension from the SDK's latest event JSON and
sanitises again before rendering. Until a remote echo arrives, the SDK does not
expose that JSON, so the sender's local echo shows the ordinary summary. Unmodified
clients also show the summary. The fork disables ordinary text editing of cards;
forwarding through clients that discard extension fields may retain only the
summary. Reply quotations remain text summaries.

## Containment

The renderer is a dedicated nonpersistent WKWebView. Page JavaScript is disabled;
there are no script message bridges or injected scripts. A fixed CSP blocks
connections, frames, fonts, scripts, external styles and external images. Only
inline CSS and embedded image data are permitted. Navigation is limited to the
locally loaded `about:blank` document; link previews and data detectors are off.
HTML tags and attributes are separately allowlisted. The view is confined to its
message bubble and the web view is stopped when removed.

Tests cover payload round trips, latest edits, sanitisation, size limits, the
message factory and composer handoff, WebKit script/resource containment, and the
real room's inline card/editor preview UI. These tests use local fixtures; a
real-account encrypted send/receive and device network capture remain deployment
validation tasks.

![Static HTML table inside an Iris message bubble](images/html-card.png)

Validation environment: Xcode 26.6 / iOS 26.5 simulator. The selected unit and
WebKit containment suites pass (93 tests), including the unchanged English
message assertions with an explicit locale fixture. SwiftFormat and SwiftLint
pass for the changed sources.
The inline-room-card and composer-preview UI regression also passes on the final
build (1 test).
