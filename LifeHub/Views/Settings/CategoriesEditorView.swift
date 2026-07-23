//
//  CategoriesEditorView.swift
//  LifeHub
//

import SwiftUI
import SwiftData

/// Edit the spending categories: rename, recolor, re-icon, reorder, add,
/// and delete (expenses keep existing but become uncategorized).
struct CategoriesEditorView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \ExpenseCategory.sortOrder) private var categories: [ExpenseCategory]

    @State private var editingCategory: ExpenseCategory?
    @State private var showingAdd = false

    var body: some View {
        List {
            Section {
                ForEach(categories) { category in
                    Button {
                        editingCategory = category
                    } label: {
                        HStack {
                            SymbolBadge(symbolName: category.symbolName, color: Color(hex: category.colorHex))
                            Text(category.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { offsets in
                    for offset in offsets {
                        modelContext.delete(categories[offset])
                    }
                    try? modelContext.save()
                }
                .onMove { source, destination in
                    var reordered = categories
                    reordered.move(fromOffsets: source, toOffset: destination)
                    for (index, category) in reordered.enumerated() {
                        category.sortOrder = index
                    }
                    try? modelContext.save()
                }
            } footer: {
                Text("Deleting a category keeps its expenses — they become uncategorized.")
            }
        }
        .navigationTitle("Categories")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAdd = true
                } label: {
                    Label("Add Category", systemImage: "plus")
                }
            }
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
        }
        .sheet(item: $editingCategory) { category in
            CategoryFormSheet(category: category)
        }
        .sheet(isPresented: $showingAdd) {
            CategoryFormSheet(category: nil)
        }
    }
}

/// Add or edit one category: name, symbol, color.
struct CategoryFormSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let category: ExpenseCategory?

    @State private var name = ""
    @State private var symbolName = "tag.fill"
    @State private var colorHex = "#6E7DF6"

    private let symbolOptions = [
        "house.fill", "fork.knife", "bus.fill", "bolt.fill", "iphone",
        "figure.2.and.child.holdinghands", "party.popper.fill", "tag.fill",
        "cart.fill", "cross.case.fill", "book.fill", "airplane",
        "pawprint.fill", "gift.fill", "wrench.and.screwdriver.fill", "drop.fill"
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                }

                Section("Icon") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 48))], spacing: 10) {
                        ForEach(symbolOptions, id: \.self) { symbol in
                            Button {
                                symbolName = symbol
                                Haptics.shared.tap()
                            } label: {
                                Image(systemName: symbol)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        symbolName == symbol ? Color(hex: colorHex).opacity(0.2) : Color(.tertiarySystemFill),
                                        in: .rect(cornerRadius: 10)
                                    )
                                    .foregroundStyle(symbolName == symbol ? Color(hex: colorHex) : .primary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(symbol))
                            .accessibilityAddTraits(symbolName == symbol ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Color") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                        ForEach(PaletteColors.hexes, id: \.self) { hex in
                            Button {
                                colorHex = hex
                                Haptics.shared.tap()
                            } label: {
                                Circle()
                                    .fill(Color(hex: hex).gradient)
                                    .frame(width: 36, height: 36)
                                    .overlay {
                                        if colorHex == hex {
                                            Image(systemName: "checkmark")
                                                .font(.caption.weight(.bold))
                                                .foregroundStyle(.white)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Text(hex))
                            .accessibilityAddTraits(colorHex == hex ? .isSelected : [])
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(category == nil ? "New Category" : "Edit Category")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                if let category {
                    name = category.name
                    symbolName = category.symbolName
                    colorHex = category.colorHex
                }
            }
        }
    }

    private func save() {
        if let category {
            category.name = name.trimmingCharacters(in: .whitespaces)
            category.symbolName = symbolName
            category.colorHex = colorHex
        } else {
            let maxOrder = (try? modelContext.fetch(FetchDescriptor<ExpenseCategory>()))?.map(\.sortOrder).max() ?? 0
            let new = ExpenseCategory(
                name: name.trimmingCharacters(in: .whitespaces),
                symbolName: symbolName,
                colorHex: colorHex,
                sortOrder: maxOrder + 1
            )
            modelContext.insert(new)
        }
        try? modelContext.save()
        Haptics.shared.success()
        dismiss()
    }
}
