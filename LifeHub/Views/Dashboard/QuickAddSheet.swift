//
//  QuickAddSheet.swift
//  LifeHub
//

import SwiftUI

/// Routes the dashboard's quick-add buttons (and App Intents) to the right
/// form — each reachable in one tap from the home screen.
struct QuickAddSheet: View {
    let kind: AppRouter.QuickAddKind

    var body: some View {
        switch kind {
        case .expense:
            ExpenseFormView()
        case .income:
            IncomeEntryFormView()
        case .task:
            TaskFormView()
        case .note:
            NoteEditorView()
        case .event:
            EventFormView()
        }
    }
}
