//
//  SettingsView.swift
//  LifeHub
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

/// App settings: currency, reminder defaults, language, security (PIN /
/// Face ID), categories, and backup & restore.
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var settingsList: [AppSettings]

    @State private var showingChangePIN = false
    @State private var exportDocument: JSONDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var showingRestoreConfirm = false
    @State private var pendingRestoreData: Data?
    @State private var feedback: String?

    /// Every ISO currency, sorted by localized display name.
    private static let currencyOptions: [String] = Locale.commonISOCurrencyCodes.sorted { lhs, rhs in
        currencyDisplayName(lhs).localizedCaseInsensitiveCompare(currencyDisplayName(rhs)) == .orderedAscending
    }

    private static func currencyDisplayName(_ code: String) -> String {
        Locale.current.localizedString(forCurrencyCode: code) ?? code
    }

    var body: some View {
        NavigationStack {
            List {
                if let settings = settingsList.first {
                    generalSection(settings)
                    calendarSyncSection(settings)
                    remindersSection(settings)
                    securitySection(settings)
                }
                categoriesSection
                backupSection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        try? modelContext.save()
                        NotificationScheduler.refreshAll(context: modelContext)
                        SnapshotService.refresh(context: modelContext)
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingChangePIN) {
                ChangePINView()
            }
            .fileExporter(
                isPresented: $showingExporter,
                document: exportDocument,
                contentType: .json,
                defaultFilename: "LifeHub-Backup-\(Date.now.formatted(.iso8601.year().month().day()))"
            ) { result in
                if case .success = result {
                    feedback = String(localized: "Backup exported.")
                    Haptics.shared.success()
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [.json]
            ) { result in
                handleImport(result)
            }
            .confirmationDialog(
                "Restore from backup?",
                isPresented: $showingRestoreConfirm,
                titleVisibility: .visible
            ) {
                Button("Replace Everything", role: .destructive) {
                    performRestore()
                }
            } message: {
                Text("All current data is replaced with the backup's contents. This can't be undone.")
            }
            .alert(feedback ?? "", isPresented: Binding(
                get: { feedback != nil },
                set: { if !$0 { feedback = nil } }
            )) {
                Button("OK") { feedback = nil }
            }
        }
    }

    // MARK: Sections

    private func generalSection(_ settings: AppSettings) -> some View {
        Section("General") {
            Picker("Currency", selection: Binding(
                get: { settings.currencyCode },
                set: { settings.currencyCode = $0 }
            )) {
                ForEach(Self.currencyOptions, id: \.self) { code in
                    Text(verbatim: "\(Self.currencyDisplayName(code)) (\(code))").tag(code)
                }
            }
            .pickerStyle(.navigationLink)
            Picker("Language", selection: Binding(
                get: { settings.languageCode },
                set: { settings.languageCode = $0 }
            )) {
                Text("System").tag("system")
                Text(verbatim: "English").tag("en")
                Text(verbatim: "አማርኛ").tag("am")
            }
        }
    }

    private func calendarSyncSection(_ settings: AppSettings) -> some View {
        Section {
            Toggle(isOn: Binding(
                get: { settings.syncDeviceCalendars },
                set: { newValue in
                    if newValue {
                        Task {
                            let granted = await CalendarSyncService.shared.requestAccess()
                            settings.syncDeviceCalendars = granted
                            try? modelContext.save()
                            if !granted {
                                feedback = String(localized: "Calendar access was denied. You can enable it in iOS Settings → Privacy & Security → Calendars.")
                            } else {
                                Haptics.shared.success()
                            }
                        }
                    } else {
                        settings.syncDeviceCalendars = false
                        try? modelContext.save()
                    }
                }
            )) {
                Label("Sync device & Google calendars", systemImage: "calendar.badge.clock")
            }
        } header: {
            Text("Calendar Sync")
        } footer: {
            Text("Shows meetings from every calendar on this device. To include Google, add your account in iOS Settings → Calendar → Accounts — its events then appear here automatically. LifeHub only reads them; your calendars are never changed.")
        }
    }

    private func remindersSection(_ settings: AppSettings) -> some View {
        Section {
            Picker("Morning reminder time", selection: Binding(
                get: { settings.reminderHour },
                set: { settings.reminderHour = $0 }
            )) {
                ForEach(5...12, id: \.self) { hour in
                    Text(verbatim: String(format: "%02d:00", hour)).tag(hour)
                }
            }
            Stepper(value: Binding(
                get: { settings.rentRemindBeforeDays },
                set: { settings.rentRemindBeforeDays = $0 }
            ), in: 0...14) {
                Text("Rent: \(settings.rentRemindBeforeDays) days before")
            }
            Stepper(value: Binding(
                get: { settings.debtRemindBeforeDays },
                set: { settings.debtRemindBeforeDays = $0 }
            ), in: 0...14) {
                Text("Debts: \(settings.debtRemindBeforeDays) days before")
            }
            Stepper(value: Binding(
                get: { settings.loanRemindBeforeDays },
                set: { settings.loanRemindBeforeDays = $0 }
            ), in: 0...14) {
                Text("Loans: \(settings.loanRemindBeforeDays) days before")
            }
            Toggle("Monthly review summary", isOn: Binding(
                get: { settings.monthlyReviewEnabled },
                set: { settings.monthlyReviewEnabled = $0 }
            ))
            Toggle("Work anniversaries", isOn: Binding(
                get: { settings.anniversaryRemindersEnabled },
                set: { settings.anniversaryRemindersEnabled = $0 }
            ))
        } header: {
            Text("Reminders")
        } footer: {
            Text("Per-bill timing is set on each bill. Notification permission is required for reminders to appear.")
        }
    }

    private func securitySection(_ settings: AppSettings) -> some View {
        Section("Security") {
            Button {
                showingChangePIN = true
            } label: {
                Label("Change PIN", systemImage: "lock.rotation")
            }
            if PINService.biometricsAvailable {
                Toggle(isOn: Binding(
                    get: { settings.useBiometrics },
                    set: { settings.useBiometrics = $0 }
                )) {
                    Label("Unlock with Face ID", systemImage: "faceid")
                }
            }
        }
    }

    private var categoriesSection: some View {
        Section("Spending") {
            NavigationLink {
                CategoriesEditorView()
            } label: {
                Label("Expense Categories", systemImage: "tag.fill")
            }
        }
    }

    private var backupSection: some View {
        Section {
            Button {
                exportBackup()
            } label: {
                Label("Export Backup", systemImage: "square.and.arrow.up")
            }
            Button {
                showingImporter = true
            } label: {
                Label("Restore from Backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Backup")
        } footer: {
            Text("One file contains everything — keep it somewhere safe in case you lose your phone.")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "1.0")
            LabeledContent("Storage") {
                Text("On this device only")
            }
        } footer: {
            Text("LifeHub keeps all data on your phone. No account, no server, no tracking.")
        }
    }

    // MARK: Backup actions

    private func exportBackup() {
        do {
            let data = try BackupService.export(context: modelContext)
            exportDocument = JSONDocument(data: data)
            showingExporter = true
        } catch {
            feedback = String(localized: "Export failed. Please try again.")
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        let needsAccess = url.startAccessingSecurityScopedResource()
        defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else {
            feedback = String(localized: "Couldn't read that file.")
            return
        }
        pendingRestoreData = data
        showingRestoreConfirm = true
    }

    private func performRestore() {
        guard let data = pendingRestoreData else { return }
        do {
            try BackupService.restore(from: data, context: modelContext)
            NotificationScheduler.refreshAll(context: modelContext)
            SnapshotService.refresh(context: modelContext)
            feedback = String(localized: "Backup restored.")
            Haptics.shared.success()
        } catch {
            feedback = error.localizedDescription
            Haptics.shared.warning()
        }
        pendingRestoreData = nil
    }
}

/// Change the PIN: verify the current one, then set a new one.
struct ChangePINView: View {
    @Environment(\.dismiss) private var dismiss

    private enum Step {
        case verify, newPIN, confirm
    }

    @State private var step: Step = .verify
    @State private var pin = ""
    @State private var newPIN = ""
    @State private var errorText: LocalizedStringKey?

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()
                VStack(spacing: 8) {
                    Text(titleKey)
                        .font(.title3.weight(.semibold))
                    if let errorText {
                        Text(errorText)
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                }
                PINPadView(pin: $pin, maxLength: 6)
                if step == .newPIN {
                    Button("Continue") {
                        guard pin.count >= 4 else { return }
                        newPIN = pin
                        pin = ""
                        step = .confirm
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pin.count < 4)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Change PIN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onChange(of: pin) { _, value in
                handleChange(value)
            }
        }
    }

    private var titleKey: LocalizedStringKey {
        switch step {
        case .verify: "Enter current PIN"
        case .newPIN: "Choose a new PIN"
        case .confirm: "Confirm new PIN"
        }
    }

    private func handleChange(_ value: String) {
        switch step {
        case .verify:
            if value.count >= 4, PINService.validate(value) {
                pin = ""
                errorText = nil
                step = .newPIN
            } else if value.count == 6 {
                errorText = "Wrong PIN"
                Haptics.shared.warning()
                pin = ""
            }
        case .newPIN:
            break // Confirmed via the Continue button.
        case .confirm:
            guard value.count == newPIN.count else {
                if value.count > newPIN.count { fail() }
                return
            }
            if value == newPIN {
                PINService.setPIN(value)
                Haptics.shared.success()
                dismiss()
            } else {
                fail()
            }
        }
    }

    private func fail() {
        errorText = "PINs didn't match — try again."
        Haptics.shared.warning()
        pin = ""
        step = .newPIN
    }
}
