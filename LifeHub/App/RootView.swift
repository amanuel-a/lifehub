//
//  RootView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// The app's root: seeds defaults on first launch, applies the PIN lock,
/// injects the currency environment, and hosts the tab bar.
struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @Query private var settingsList: [AppSettings]
    @State private var router = AppRouter.shared
    @State private var isLocked = PINService.isPINSet
    @State private var didSeed = false

    private var settings: AppSettings? { settingsList.first }

    var body: some View {
        ZStack {
            if PINService.isPINSet, isLocked {
                LockView(useBiometrics: settings?.useBiometrics ?? true) {
                    withAnimation(.spring(duration: 0.35)) { isLocked = false }
                }
                .transition(.opacity)
            } else if !PINService.isPINSet {
                OnboardingView {
                    isLocked = false
                }
            } else {
                mainTabs
                    .transition(.opacity)
            }
        }
        .environment(\.currencyCode, settings?.currencyCode ?? "USD")
        .environment(\.locale, preferredLocale)
        .environment(router)
        .task { seedIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                if PINService.isPINSet { isLocked = true }
                refreshAuxiliaryState()
            case .active:
                refreshAuxiliaryState()
            default:
                break
            }
        }
    }

    private var mainTabs: some View {
        TabView(selection: $router.selectedTab) {
            Tab(value: AppTab.dashboard) {
                DashboardView()
            } label: {
                Label("Home", systemImage: "house.fill")
            }

            Tab(value: AppTab.money) {
                MoneyHomeView()
            } label: {
                Label("Money", systemImage: "banknote.fill")
            }

            Tab(value: AppTab.projects) {
                ProjectsView()
            } label: {
                Label("Projects", systemImage: "square.stack.3d.up.fill")
            }

            Tab(value: AppTab.calendar) {
                CalendarScreen()
            } label: {
                Label("Calendar", systemImage: "calendar")
            }

            Tab(value: AppTab.tasks) {
                TasksView()
            } label: {
                Label("Tasks", systemImage: "checkmark.circle.fill")
            }

            Tab(value: AppTab.notes) {
                NotesView()
            } label: {
                Label("Notes", systemImage: "note.text")
            }
        }
        .sheet(item: $router.pendingQuickAdd) { kind in
            QuickAddSheet(kind: kind)
        }
    }

    /// The locale override when the owner picks an explicit language.
    private var preferredLocale: Locale {
        switch settings?.languageCode {
        case "en": Locale(identifier: "en")
        case "am": Locale(identifier: "am")
        default: Locale.current
        }
    }

    private func seedIfNeeded() {
        guard !didSeed else { return }
        didSeed = true

        _ = AppSettings.fetchOrCreate(in: modelContext)

        let categoryCount = (try? modelContext.fetchCount(FetchDescriptor<ExpenseCategory>())) ?? 0
        if categoryCount == 0 {
            for category in ExpenseCategory.defaultCategories() {
                modelContext.insert(category)
            }
        }
        let groupCount = (try? modelContext.fetchCount(FetchDescriptor<TaskGroup>())) ?? 0
        if groupCount == 0 {
            for group in TaskGroup.defaultGroups() {
                modelContext.insert(group)
            }
        }
        try? modelContext.save()
        refreshAuxiliaryState()
    }

    /// Reschedules notifications and refreshes widget data.
    private func refreshAuxiliaryState() {
        NotificationScheduler.refreshAll(context: modelContext)
        SnapshotService.refresh(context: modelContext)
    }
}

#Preview {
    RootView()
        .modelContainer(ModelContainerFactory.preview())
}
