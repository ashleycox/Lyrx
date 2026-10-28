import SwiftUI

/// Shows available public metadata without exposing raw lyric markup or the user's contact address.
struct AdditionalInfoView: View {
    let model: ReaderModel
    let settings: AppSettings

    var body: some View {
        NavigationStack {
            Form {
                if let match = model.info.match {
                    Section("Recording") {
                        LabeledContent("Title", value: match.title)
                        LabeledContent("Artist") {
                            RelatedSearchButton(field: .artist, match: match, model: model, settings: settings)
                        }
                        if !match.album.isEmpty {
                            LabeledContent("Album") {
                                RelatedSearchButton(field: .album, match: match, model: model, settings: settings)
                            }
                        }
                        LabeledContent("Provider ID", value: match.providerID)
                        Link("Metadata from \(match.provider.name)", destination: match.sourceURL)
                    }
                    if model.info.isLoading { ProgressView("Loading additional information…") }
                    if let error = model.info.error { Text(error).foregroundStyle(.secondary) }
                    Section("Provider Metadata") {
                        if match.metadata.isEmpty && !model.info.isLoading {
                            Text("This service did not return additional metadata for this match.").foregroundStyle(
                                .secondary)
                        }
                        ForEach(match.metadata) { field in
                            LabeledContent {
                                if let link = field.link {
                                    Link(field.value, destination: link).fixedSize(horizontal: false, vertical: true)
                                } else {
                                    Text(field.value).textSelection(.enabled).fixedSize(
                                        horizontal: false, vertical: true)
                                }
                            } label: {
                                Text(field.label)
                            }
                        }
                    }
                }
            }
            .formStyle(.grouped).navigationTitle("Additional Info")
            .accessibilityIdentifier("additionalInfo")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { model.info.close() }.keyboardShortcut(.cancelAction)
                }
            }
        }
        #if os(macOS)
            .frame(minWidth: 520, idealWidth: 620, minHeight: 480, idealHeight: 620)
        #endif
    }
}
