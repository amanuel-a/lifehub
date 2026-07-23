//
//  ExpenseFormView.swift
//  LifeHub
//

import SwiftUI
import SwiftData
import PhotosUI

/// Log an expense in seconds: big amount field, category grid, date,
/// optional note and receipt photo. Also used for editing.
struct ExpenseFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var expense: Expense?

    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var amountText = ""
    @State private var selectedCategory: ExpenseCategory?
    @State private var date = Date.now
    @State private var note = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var receiptData: Data?
    @FocusState private var amountFocused: Bool

    private var amount: Decimal? { Decimal.fromUserInput(amountText) }
    private var isEditing: Bool { expense != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CurrencyField(titleKey: "0", text: $amountText, prominent: true)
                        .focused($amountFocused)
                        .listRowBackground(Color.clear)
                }

                Section("Category") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                        ForEach(categories) { category in
                            CategoryChip(
                                category: category,
                                isSelected: selectedCategory?.uuid == category.uuid
                            ) {
                                Haptics.shared.tap()
                                selectedCategory = category
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                }

                Section("Receipt") {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(
                            receiptData == nil ? "Add Receipt Photo" : "Change Receipt Photo",
                            systemImage: "camera.fill"
                        )
                    }
                    if let receiptData, let image = UIImage(data: receiptData) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(.rect(cornerRadius: 12))
                            .contextMenu {
                                Button(role: .destructive) {
                                    self.receiptData = nil
                                    photoItem = nil
                                } label: {
                                    Label("Remove Photo", systemImage: "trash")
                                }
                            }
                            .accessibilityLabel(Text("Receipt photo"))
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Expense" : "New Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!(amount?.isPositive ?? false))
                }
            }
            .onAppear(perform: populate)
            .task(id: photoItem) {
                guard let photoItem else { return }
                receiptData = try? await photoItem.loadTransferable(type: Data.self)
            }
        }
    }

    private func populate() {
        if let expense {
            amountText = "\(expense.amount)"
            selectedCategory = expense.category
            date = expense.date
            note = expense.note
            receiptData = expense.receiptImageData
        } else {
            amountFocused = true
        }
    }

    private func save() {
        guard let amount else { return }
        if let expense {
            expense.amount = amount
            expense.category = selectedCategory
            expense.date = date
            expense.note = note
            expense.receiptImageData = receiptData
        } else {
            let new = Expense(amount: amount, date: date, note: note, category: selectedCategory, receiptImageData: receiptData)
            modelContext.insert(new)
        }
        try? modelContext.save()
        Haptics.shared.success()
        warnIfOverBudget()
        SnapshotService.refresh(context: modelContext)
        dismiss()
    }

    /// Budget warning when this category is approaching or past its limit.
    private func warnIfOverBudget() {
        guard let category = selectedCategory, category.monthlyBudget != nil else { return }
        let summary = StatsService.summary(forMonthContaining: date, context: modelContext)
        if let usage = summary.categoryTotals.first(where: { $0.id == category.uuid })?.budgetUsage,
           usage >= 0.9 {
            Haptics.shared.warning()
        }
    }
}

/// A tappable category chip for the picker grid.
struct CategoryChip: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                SymbolBadge(symbolName: category.symbolName, color: Color(hex: category.colorHex), size: 40)
                Text(category.name)
                    .font(.caption2.weight(.medium))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(
                isSelected ? Color(hex: category.colorHex).opacity(0.15) : Color.clear,
                in: .rect(cornerRadius: 12)
            )
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(Color(hex: category.colorHex), lineWidth: 1.5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(category.name))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
