import SwiftUI

/// The feedback sheet. Present it from a `.sheet(isPresented:)`, or use `FeedbackCommands` to add
/// a "Send Feedback…" item to the Help menu that presents it for you.
public struct FeedbackView: View {
    let config: FeedbackConfig
    let environment: FeedbackEnvironment
    let onClose: (() -> Void)?

    @State private var draft = FeedbackDraft()
    @State private var phase: Phase = .editing
    @Environment(\.dismiss) private var dismiss

    private enum Phase: Equatable {
        case editing
        case sending
        case sent
        case failed(String)
    }

    public init(config: FeedbackConfig,
                environment: FeedbackEnvironment = .init(),
                onClose: (() -> Void)? = nil) {
        self.config = config
        self.environment = environment
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            switch phase {
            case .sent: sentState
            default:    form
            }
        }
        .frame(width: 460, height: 540)
        .tint(config.accent)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text("Send Feedback")
                .font(.headline)
            Spacer()
            Text("v\(environment.appVersionField) · macOS \(environment.osVersion)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    // MARK: - Form

    private var form: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("Type", selection: $draft.type) {
                ForEach(FeedbackType.allCases) { t in
                    Label(t.label, systemImage: t.symbol).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            field("Title") {
                TextField("A short summary", text: $draft.title)
                    .textFieldStyle(.roundedBorder)
            }

            field("Description") {
                TextEditor(text: $draft.body)
                    .font(.body)
                    .frame(minHeight: 130)
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.quaternary))
            }

            HStack(spacing: 10) {
                field("Name (optional)") {
                    TextField("Anonymous", text: $draft.reporter)
                        .textFieldStyle(.roundedBorder)
                }
                field("Email (optional)") {
                    TextField("so I can reply", text: $draft.email)
                        .textFieldStyle(.roundedBorder)
                }
            }

            if config.logProvider != nil {
                Toggle("Attach recent diagnostic log", isOn: $draft.attachLog)
                    .onChange(of: draft.attachLog) { _, on in
                        draft.attachedLog = on ? config.logProvider?() : nil
                    }
            }

            Toggle("This may be listed publicly on the feedback board.", isOn: $draft.consent)
                .font(.callout)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(config.accent.opacity(consentIsOnlyBlocker ? 0.12 : 0))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(config.accent.opacity(consentIsOnlyBlocker ? 0.55 : 0))
                )
                .animation(.easeInOut(duration: 0.15), value: consentIsOnlyBlocker)

            footer
        }
        .padding(16)
    }

    private var footer: some View {
        HStack {
            if case .failed(let msg) = phase {
                Label(msg, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .lineLimit(2)
            } else if let reason = draft.validationError {
                Label(reason, systemImage: "exclamationmark.circle.fill")
                    .font(.caption)
                    .foregroundStyle(consentIsOnlyBlocker ? config.accent : Color.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button("Cancel") { close() }
                .keyboardShortcut(.cancelAction)
            Button(phase == .sending ? "Sending…" : "Send") { Task { await send() } }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid || phase == .sending)
        }
    }

    // MARK: - Sent

    private var sentState: some View {
        VStack(spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 44))
                .foregroundStyle(config.accent)
            Text("Thanks — your \(draft.type.label.lowercased()) was sent.")
                .font(.title3)
            Button("Done") { close() }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Helpers

    @ViewBuilder
    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            content()
        }
    }

    /// Dismisses the sheet. When presented imperatively (via `FeedbackCommands` → `FeedbackPresenter`)
    /// the host injects `onClose` to tear down its own AppKit window; otherwise fall back to the
    /// SwiftUI environment `dismiss` for apps that present `FeedbackView` from their own `.sheet`.
    private func close() {
        if let onClose { onClose() } else { dismiss() }
    }

    /// True when the consent checkbox is the *only* thing left blocking submission. A fully-filled
    /// report with an unticked consent box otherwise looks "stuck" (Send disabled, reason easy to
    /// miss), so this drives the accent highlight on the consent row and its hint.
    private var consentIsOnlyBlocker: Bool {
        guard !draft.consent else { return false }
        var withConsent = draft
        withConsent.consent = true
        return withConsent.isValid
    }

    private func send() async {
        phase = .sending
        do {
            try await FeedbackSubmitter(config: config, environment: environment).submit(draft)
            phase = .sent
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }
}
