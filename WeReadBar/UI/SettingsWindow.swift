import AppKit
import SwiftUI
import UserNotifications
import os.log

private let settingsLog = Logger(subsystem: "com.local.wereadbar", category: "settings")

/// Unified account and reminder configuration surface. New preferences belong
/// here instead of becoming separate menu actions or windows.
struct SettingsWindow: View {
    @EnvironmentObject var store: StatsStore
    let reminderCoordinator: ReminderCoordinator

    @State private var token: String = ""
    @State private var tokenVisible = false
    @State private var isSavingToken = false
    @State private var tokenError: String?
    @State private var reminderEnabled = ReminderSettings.isEnabled
    @State private var thresholdDays = ReminderSettings.thresholdDays
    @State private var authorizationStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            GroupBox(String(localized: "settings.account")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(String(localized: "settings.tokenDescription"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Button(String(localized: "onboarding.getToken")) {
                        NSWorkspace.shared.open(WeReadURL.tokenHelp)
                    }
                    .buttonStyle(.link)

                    HStack(spacing: 6) {
                        Group {
                            if tokenVisible {
                                TextField("wrk-xxxxxxxx", text: $token)
                            } else {
                                SecureField("wrk-xxxxxxxx", text: $token)
                            }
                        }
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: token) { _, _ in tokenError = nil }
                        .onSubmit { Task { await saveToken() } }

                        Button {
                            tokenVisible.toggle()
                        } label: {
                            Image(systemName: tokenVisible ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(String(localized: tokenVisible ? "onboarding.hideToken" : "onboarding.showToken"))
                    }

                    if let tokenError {
                        Text(tokenError)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Spacer()
                        Button(isSavingToken ? String(localized: "onboarding.saving") : String(localized: "onboarding.save")) {
                            Task { await saveToken() }
                        }
                        .disabled(isSavingToken || token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(.top, 4)
            }

            GroupBox(String(localized: "settings.reminder")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(String(localized: "settings.reminderEnabled"), isOn: $reminderEnabled)
                        .onChange(of: reminderEnabled) { _, enabled in
                            ReminderSettings.isEnabled = enabled
                            if enabled { Task { await requestNotificationPermission() } }
                        }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(String(localized: "settings.reminderDaysDescription"))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            TextField("", value: $thresholdDays, format: .number)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 44)
                                .multilineTextAlignment(.center)
                                .disabled(!reminderEnabled)
                                .onChange(of: thresholdDays) { _, newValue in
                                    thresholdDays = max(1, min(30, newValue))
                                    ReminderSettings.thresholdDays = thresholdDays
                                }

                            Stepper("", value: $thresholdDays, in: 1...30)
                                .disabled(!reminderEnabled)

                            Text(String(localized: "settings.reminderDaysUnit"))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(String(localized: "settings.reminderDescription"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Text(authorizationDescription)
                        .font(.footnote)
                        .foregroundStyle(authorizationStatus == .authorized ? Color.secondary : Color.orange)

                    if authorizationStatus == .denied {
                        Button(String(localized: "settings.openNotificationSettings")) {
                            openNotificationSettings()
                        }
                        .buttonStyle(.link)
                    } else if authorizationStatus == .notDetermined {
                        // LSUIElement apps cannot trigger the system notification permission dialog,
                        // so we guide the user to open System Settings directly.
                        Button(String(localized: "settings.openNotificationSettings")) {
                            openNotificationSettings()
                        }
                        .buttonStyle(.link)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
        .frame(minWidth: 460, minHeight: 390)
        .task {
            token = TokenStore.load() ?? ""
            authorizationStatus = await reminderCoordinator.notificationAuthorizationStatus()
        }
    }

    private var authorizationDescription: String {
        switch authorizationStatus {
        case .authorized:
            return String(localized: "settings.notificationsAllowed")
        case .denied:
            return String(localized: "settings.notificationsDenied")
        case .notDetermined:
            return String(localized: "settings.notificationsNotDetermined")
        case .provisional:
            return String(localized: "settings.notificationsProvisional")
        case .ephemeral:
            return String(localized: "settings.notificationsEphemeral")
        @unknown default:
            return String(localized: "settings.notificationsUnknown")
        }
    }

    private func requestNotificationPermission() {
        settingsLog.info("requestNotificationPermission called")
        Task {
            await reminderCoordinator.requestAuthorizationIfNeeded()
            authorizationStatus = await reminderCoordinator.notificationAuthorizationStatus()
        }
    }

    private func saveToken() async {
        isSavingToken = true
        defer { isSavingToken = false }
        guard await store.setAPIKey(token) else {
            tokenError = store.lastError ?? String(localized: "onboarding.invalidToken")
            return
        }
        tokenError = nil
    }

    private func openNotificationSettings() {
        // Opens System Settings. User can click "Notifications" in the sidebar.
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:Notifications")!)
    }
}
