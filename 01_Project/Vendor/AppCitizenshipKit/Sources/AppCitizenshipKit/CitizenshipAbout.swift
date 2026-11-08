import AppKit

/// Opens the **native** macOS About panel (app icon + name + version come for free from the
/// app's Info.plist) augmented with a centered row of clickable links: Website · Tip Jar · Privacy.
///
/// Using `orderFrontStandardAboutPanel` rather than a bespoke window keeps it one line and
/// automatically correct for icon/version, while still surfacing the support links that the
/// stock panel lacks.
@MainActor
public enum CitizenshipAbout {

    public static func show(_ config: CitizenshipConfig) {
        var options: [NSApplication.AboutPanelOptionKey: Any] = [:]

        let credits = NSMutableAttributedString()
        func appendLink(_ label: String, _ url: URL?) {
            guard let url else { return }
            if credits.length > 0 {
                credits.append(NSAttributedString(string: "    "))
            }
            credits.append(NSAttributedString(string: label, attributes: [
                .link: url,
                .foregroundColor: NSColor.linkColor,
            ]))
        }

        appendLink("Website", config.websiteURL)
        appendLink("Tip Jar", config.donateURL)
        appendLink("Privacy", config.privacyURL)
        if let email = config.supportEmail, let mailto = URL(string: "mailto:\(email)") {
            appendLink("Email", mailto)
        }

        if credits.length > 0 {
            let paragraph = NSMutableParagraphStyle()
            paragraph.alignment = .center
            credits.addAttribute(
                .paragraphStyle,
                value: paragraph,
                range: NSRange(location: 0, length: credits.length)
            )
            options[.credits] = credits
        }

        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
