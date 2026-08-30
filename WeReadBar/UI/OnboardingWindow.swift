import SwiftUI

/// Standalone-window version of the onboarding flow.
/// Hosted in an AppKit `NSWindow` via `OnboardingWindowController`, NOT a SwiftUI
/// `Window` scene (which has a known "can't reopen after close" bug).
struct OnboardingWindow: View {
    @EnvironmentObject var store: StatsStore

    @State private var input: String = ""
    @State private var submitting: Bool = false
    @State private var inlineError: String?
    @State private var isVisible: Bool = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .foregroundStyle(.secondary)
                Text(String(localized: "onboarding.title"))
                    .font(.headline)
            }

            Text(String(localized: "onboarding.description"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            // Toggle between SecureField (default, hidden) and TextField (plain).
            // The eye button on the right flips `isVisible`.
            HStack(spacing: 6) {
                Group {
                    if isVisible {
                        TextField("wrk-xxxxxxxx", text: $input)
                    } else {
                        SecureField("wrk-xxxxxxxx", text: $input)
                    }
                }
                .textFieldStyle(.roundedBorder)
                .focused($inputFocused)
                .onChange(of: input) { _, _ in inlineError = nil }
                .onSubmit { Task { await submit() } }

                Button {
                    isVisible.toggle()
                    // Re-focus the field after toggling so the user can keep typing.
                    inputFocused = true
                } label: {
                    Image(systemName: isVisible ? "eye.slash" : "eye")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.borderless)
                .help(isVisible ? String(localized: "onboarding.hideToken") : String(localized: "onboarding.showToken"))
                .accessibilityLabel(isVisible ? String(localized: "onboarding.hideToken") : String(localized: "onboarding.showToken"))
            }

            if let inlineError {
                Text(inlineError)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()
                Button(submitting ? String(localized: "onboarding.saving") : String(localized: "onboarding.save")) {
                    Task { await submit() }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(submitting || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(minWidth: 380, minHeight: 200)
        // Pre-fill with the currently stored token (only when the input is
        // empty — preserves any draft the user may have left from a
        // previous session). Then auto-focus the field.
        .task {
            if input.isEmpty {
                input = Keychain.load() ?? ""
            }
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
            inlineError = store.lastError ?? String(localized: "onboarding.invalidToken")
        }
    }
}
