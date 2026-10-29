import SwiftUI

/// Placeholder content proving the panel shell works before the usage store exists.
struct PlaceholderHUDView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("LLM Usage Status")
                .font(.headline)
            Text("Setup complete — placeholder")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.background.secondary, in: .rect(cornerRadius: 12))
    }
}
