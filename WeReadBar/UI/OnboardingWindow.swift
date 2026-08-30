import SwiftUI

/// Standalone-window version of the onboarding flow.
/// Hosted in an AppKit `NSWindow` via `OnboardingWindowController`, NOT a SwiftUI
/// `Window` scene (which has a known "can't reopen after close" bug).
struct OnboardingWindow: View {
    @EnvironmentObject var store: StatsStore

    @State private var input: String = ""
    @State private var submitting: Bool = false
    @State private var inlineError: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.secondary)
                Text("WeRead API Token")
                    .font(.headline)
            }

            Text("Paste the bearer token from i.weread.qq.com. It's stored in the macOS Keychain and only ever read by this app.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            SecureField("wrk-xxxxxxxx", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onChange(of: input) { _, _ in inlineError = nil }
                .onSubmit { Task { await submit() } }

            if let inlineError {
                Text(inlineError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(submitting ? "Saving…" : "Save") {
                    Task { await submit() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(submitting || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 380, minHeight: 200)
        // Auto-focus the input shortly after the window appears.
        .task {
            try? await Task.sleep(nanoseconds: 150_000_000)
            inputFocused = true
        }
        // When the key is saved (needsAPIKey → false), hide this window.
        .onChange(of: store.needsAPIKey) { _, needs in
            if !needs {
                OnboardingWindowController.shared.hide()
                input = ""
            }
        }
    }

    private func submit() async {
        submitting = true
        defer { submitting = false }
        let ok = await store.setAPIKey(input)
        if !ok {
            inlineError = store.lastError ?? "Invalid token"
        }
    }
}
