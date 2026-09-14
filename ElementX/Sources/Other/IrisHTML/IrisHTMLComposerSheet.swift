// Copyright 2026 NeoeticAnchor.
// SPDX-License-Identifier: AGPL-3.0-only OR LicenseRef-Element-Commercial

import Compound
import SwiftUI

struct IrisHTMLComposerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var source = ""
    @State private var preview: IrisHTMLCard?
    let send: (String) -> Void
    
    var body: some View {
        ElementNavigationStack {
            Form {
                Section {
                    TextEditor(text: $source)
                        .font(.compound.bodyMD)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .frame(minHeight: 160)
                        .accessibilityLabel(UntranslatedL10n.irisHtmlSource)
                        .accessibilityIdentifier("irisHTMLSource")
                        .onChange(of: source) { _, _ in preview = nil }
                } header: {
                    Text(UntranslatedL10n.irisHtmlSource)
                } footer: {
                    Text(UntranslatedL10n.irisHtmlDescription)
                }
                Section {
                    ListRow(label: .plain(title: UntranslatedL10n.irisHtmlPreview), kind: .button {
                        preview = IrisHTMLCard.prepare(source)
                    })
                    .disabled(IrisHTMLCard.prepare(source) == nil)
                    if let preview {
                        IrisHTMLCardView(card: preview)
                    } else if !source.isEmpty, IrisHTMLCard.prepare(source) == nil {
                        Text(UntranslatedL10n.irisHtmlInvalid)
                            .foregroundStyle(Color.compound.textCriticalPrimary)
                    }
                }
            }
            .compoundList()
            .navigationTitle(UntranslatedL10n.irisHtmlCard)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.actionCancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.actionSend) {
                        send(source)
                        dismiss()
                    }
                    .accessibilityIdentifier("irisHTMLSend")
                    .disabled(preview == nil)
                }
            }
        }
    }
}

struct IrisHTMLComposerSheet_Previews: PreviewProvider {
    static var previews: some View {
        IrisHTMLComposerSheet { _ in }
    }
}
