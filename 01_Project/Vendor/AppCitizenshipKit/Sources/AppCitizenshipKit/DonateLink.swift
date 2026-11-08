import SwiftUI

/// A reusable "Leave a Tip" link for placing in a Settings footer, About box, or sidebar —
/// anywhere a menu item isn't the right home. Opens the shared tip-jar hub for this app's slug.
///
/// ```swift
/// DonateLink(config)                       // "♥ Leave a Tip"
/// DonateLink(config, label: "Buy me a coffee ☕")
/// ```
public struct DonateLink: View {
    private let config: CitizenshipConfig
    private let label: String?

    public init(_ config: CitizenshipConfig, label: String? = nil) {
        self.config = config
        self.label = label
    }

    public var body: some View {
        Link(label ?? "♥ Leave a Tip", destination: config.donateURL)
    }
}
