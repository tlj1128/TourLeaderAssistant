import SwiftUI
import SwiftData

// MARK: - 零用金類型管理

struct FundTypeManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomFundType.sortOrder) private var customTypes: [CustomFundType]
    @State private var newName = ""
    @State private var showAdd = false

    var body: some View {
        List {
            Section("預設類型") {
                ForEach(DefaultFundType.all, id: \.name) { t in
                    Label(t.name, systemImage: t.iconName)
                        .foregroundStyle(.primary)
                }
                Label(DefaultFundType.otherName, systemImage: DefaultFundType.otherIcon)
                    .foregroundStyle(.secondary)
            }

            Section("自訂類型") {
                ForEach(customTypes) { t in
                    Label(t.name, systemImage: t.iconName)
                }
                .onDelete(perform: deleteTypes)
                .onMove(perform: moveTypes)
            }
        }
        .navigationTitle("零用金類型")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarLeading) {
                Button("新增") { showAdd = true }
            }
        }
        .alert("新增零用金類型", isPresented: $showAdd) {
            TextField("類型名稱", text: $newName)
            Button("新增") { addType() }
            Button("取消", role: .cancel) { newName = "" }
        }
    }

    private func addType() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let t = CustomFundType(name: trimmed, sortOrder: customTypes.count)
        modelContext.insert(t)
        try? modelContext.save()
        newName = ""
    }

    private func deleteTypes(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(customTypes[i]) }
    }

    private func moveTypes(from source: IndexSet, to destination: Int) {
        var arr = customTypes
        arr.move(fromOffsets: source, toOffset: destination)
        for (i, t) in arr.enumerated() { t.sortOrder = i }
    }
}

// MARK: - 收入類型管理

struct IncomeTypeManageView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomIncomeType.sortOrder) private var customTypes: [CustomIncomeType]
    @State private var newName = ""
    @State private var showAdd = false

    var body: some View {
        List {
            Section("預設類型") {
                ForEach(DefaultIncomeType.all, id: \.name) { t in
                    Label(t.name, systemImage: t.iconName)
                        .foregroundStyle(.primary)
                }
                Label(DefaultIncomeType.otherName, systemImage: DefaultIncomeType.otherIcon)
                    .foregroundStyle(.secondary)
            }

            Section("自訂類型") {
                ForEach(customTypes) { t in
                    Label(t.name, systemImage: t.iconName)
                }
                .onDelete(perform: deleteTypes)
                .onMove(perform: moveTypes)
            }
        }
        .navigationTitle("收入類型")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { EditButton() }
            ToolbarItem(placement: .topBarLeading) {
                Button("新增") { showAdd = true }
            }
        }
        .alert("新增收入類型", isPresented: $showAdd) {
            TextField("類型名稱", text: $newName)
            Button("新增") { addType() }
            Button("取消", role: .cancel) { newName = "" }
        }
    }

    private func addType() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let t = CustomIncomeType(name: trimmed, sortOrder: customTypes.count)
        modelContext.insert(t)
        try? modelContext.save()
        newName = ""
    }

    private func deleteTypes(at offsets: IndexSet) {
        for i in offsets { modelContext.delete(customTypes[i]) }
    }

    private func moveTypes(from source: IndexSet, to destination: Int) {
        var arr = customTypes
        arr.move(fromOffsets: source, toOffset: destination)
        for (i, t) in arr.enumerated() { t.sortOrder = i }
    }
}
