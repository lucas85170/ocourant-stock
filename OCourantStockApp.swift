import SwiftUI
import UIKit

@main
struct OCourantStockApp: App {
    var body: some Scene {
        WindowGroup {
            StockHomeView()
                .preferredColorScheme(.light)
        }
    }
}

struct StockItem: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var category: String
    var reference: String
    var quantity: Int
    var unit: String
    var purchasePrice: Double
    var resalePrice: Double
    var notes: String
    var photoData: Data?
}

@MainActor
final class StockStore: ObservableObject {
    @Published var items: [StockItem] = [] {
        didSet { save() }
    }
    private let key = "ocourant.stock.items.v1"

    init() { load() }

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([StockItem].self, from: data) else { return }
        items = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    func upsert(_ item: StockItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        } else {
            items.insert(item, at: 0)
        }
    }

    func delete(_ item: StockItem) {
        items.removeAll { $0.id == item.id }
    }
}

struct StockHomeView: View {
    @StateObject private var store = StockStore()
    @State private var search = ""
    @State private var selectedCategory = "Toutes"
    @State private var showEditor = false
    @State private var editingItem: StockItem?
    @State private var showImport = false
    @State private var exportURL: URL?
    @State private var showExport = false

    private let categories = ["Toutes", "Électricité", "Plomberie", "Chauffage", "Outillage", "Autre"]

    private var filtered: [StockItem] {
        store.items.filter { item in
            (selectedCategory == "Toutes" || item.category == selectedCategory) &&
            (search.isEmpty || item.name.localizedCaseInsensitiveContains(search) ||
             item.reference.localizedCaseInsensitiveContains(search) ||
             item.category.localizedCaseInsensitiveContains(search))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var totalPurchase: Double { store.items.reduce(0) { $0 + Double($1.quantity) * $1.purchasePrice } }
    private var totalResale: Double { store.items.reduce(0) { $0 + Double($1.quantity) * $1.resalePrice } }
    private var totalQuantity: Int { store.items.reduce(0) { $0 + $1.quantity } }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("O’Courant Stock")
                        .font(.largeTitle.bold())
                    Text("Stock de l’entreprise • enregistré sur cet iPhone")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        summaryCard("Articles", value: "\(store.items.count)")
                        summaryCard("Quantités", value: "\(totalQuantity)")
                    }
                    HStack(spacing: 8) {
                        summaryCard("Valeur achat", value: money(totalPurchase))
                        summaryCard("Valeur revente", value: money(totalResale))
                    }
                }
                .padding(.horizontal)

                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Rechercher un article ou une référence", text: $search)
                }
                .padding(11)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(categories, id: \.self) { category in
                            Button(category) { selectedCategory = category }
                                .font(.subheadline.weight(.medium))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(selectedCategory == category ? Color.blue : Color(.secondarySystemBackground))
                                .foregroundStyle(selectedCategory == category ? .white : .primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal)
                }

                if filtered.isEmpty {
                    ContentUnavailableView("Aucun article", systemImage: "shippingbox",
                                           description: Text("Ajoute ton premier produit avec le bouton +."))
                        .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filtered) { item in
                            Button {
                                editingItem = item
                                showEditor = true
                            } label: {
                                StockRow(item: item, onChangeQuantity: { delta in
                                    var updated = item
                                    updated.quantity = max(0, updated.quantity + delta)
                                    store.upsert(updated)
                                })
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button(role: .destructive) { store.delete(item) } label: {
                                    Label("Supprimer", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Exporter une sauvegarde JSON", systemImage: "square.and.arrow.up") {
                            exportBackup()
                        }
                        Button("Importer une sauvegarde JSON", systemImage: "square.and.arrow.down") {
                            showImport = true
                        }
                    } label: {
                        Image(systemName: "externaldrive")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingItem = nil
                        showEditor = true
                    } label: { Image(systemName: "plus.circle.fill").font(.title2) }
                }
            }
            .sheet(isPresented: $showEditor, onDismiss: { editingItem = nil }) {
                StockEditorView(item: editingItem) { store.upsert($0) }
            }
            .fileImporter(isPresented: $showImport, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
                guard case .success(let urls) = result, let url = urls.first else { return }
                let accessed = url.startAccessingSecurityScopedResource()
                defer { if accessed { url.stopAccessingSecurityScopedResource() } }
                if let data = try? Data(contentsOf: url),
                   let imported = try? JSONDecoder().decode([StockItem].self, from: data) {
                    store.items = imported
                }
            }
            .sheet(isPresented: $showExport) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                        .presentationDetents([.medium])
                }
            }
        }
    }

    private func summaryCard(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline)
                .minimumScaleFactor(0.75).lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func money(_ value: Double) -> String {
        value.formatted(.currency(code: "EUR").locale(Locale(identifier: "fr_FR")))
    }

    private func exportBackup() {
        guard let data = try? JSONEncoder().encode(store.items) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("ocourant-stock-sauvegarde.json")
        do {
            try data.write(to: url, options: .atomic)
            exportURL = url
            showExport = true
        } catch { }
    }
}

struct StockRow: View {
    let item: StockItem
    let onChangeQuantity: (Int) -> Void

    var body: some View {
        HStack(spacing: 12) {
            Group {
                if let data = item.photoData, let image = UIImage(data: data) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Image(systemName: "shippingbox").font(.title2).foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.tertiarySystemBackground))
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name).font(.headline).lineLimit(2)
                Text("\(item.category) • \(item.reference.isEmpty ? "Sans référence" : item.reference)")
                    .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                Text("Achat \(item.purchasePrice, format: .currency(code: "EUR")) • Vente \(item.resalePrice, format: .currency(code: "EUR"))")
                    .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                HStack(spacing: 12) {
                    Button { onChangeQuantity(-1) } label: { Image(systemName: "minus.circle") }
                        .disabled(item.quantity == 0)
                    Text("\(item.quantity) \(item.unit)").font(.subheadline.bold())
                    Button { onChangeQuantity(1) } label: { Image(systemName: "plus.circle") }
                }
                .buttonStyle(.borderless)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
    }
}

struct StockEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var category: String
    @State private var reference: String
    @State private var quantity: String
    @State private var unit: String
    @State private var purchasePrice: String
    @State private var resalePrice: String
    @State private var notes: String
    @State private var photoData: Data?
    @State private var selectedPhoto: PhotosPickerItem?

    let item: StockItem?
    let onSave: (StockItem) -> Void
    private let categories = ["Électricité", "Plomberie", "Chauffage", "Outillage", "Autre"]

    init(item: StockItem?, onSave: @escaping (StockItem) -> Void) {
        self.item = item
        self.onSave = onSave
        _name = State(initialValue: item?.name ?? "")
        _category = State(initialValue: item?.category ?? "Plomberie")
        _reference = State(initialValue: item?.reference ?? "")
        _quantity = State(initialValue: String(item?.quantity ?? 1))
        _unit = State(initialValue: item?.unit ?? "pièce(s)")
        _purchasePrice = State(initialValue: item.map { String($0.purchasePrice) } ?? "0")
        _resalePrice = State(initialValue: item.map { String($0.resalePrice) } ?? "0")
        _notes = State(initialValue: item?.notes ?? "")
        _photoData = State(initialValue: item?.photoData)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Photo") {
                    if let photoData, let image = UIImage(data: photoData) {
                        Image(uiImage: image).resizable().scaledToFit().frame(maxHeight: 180).frame(maxWidth: .infinity)
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(photoData == nil ? "Ajouter une photo" : "Changer la photo", systemImage: "photo")
                    }
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            if let data = try? await newValue?.loadTransferable(type: Data.self),
                               let image = UIImage(data: data),
                               let compressed = image.jpegData(compressionQuality: 0.72) {
                                photoData = compressed
                            }
                        }
                    }
                    if photoData != nil {
                        Button("Retirer la photo", role: .destructive) { photoData = nil }
                    }
                }
                Section("Article") {
                    TextField("Nom de l’article *", text: $name)
                    Picker("Catégorie", selection: $category) {
                        ForEach(categories, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Référence fournisseur", text: $reference)
                    TextField("Quantité", text: $quantity).keyboardType(.numberPad)
                    TextField("Unité (pièce, m, boîte…)", text: $unit)
                }
                Section("Prix unitaires") {
                    TextField("Prix d’achat (€)", text: $purchasePrice).keyboardType(.decimalPad)
                    TextField("Prix de revente (€)", text: $resalePrice).keyboardType(.decimalPad)
                    if let p = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")),
                       let r = Double(resalePrice.replacingOccurrences(of: ",", with: ".")) {
                        LabeledContent("Marge unitaire", value: (r - p).formatted(.currency(code: "EUR").locale(Locale(identifier: "fr_FR"))))
                    }
                }
                Section("Notes") {
                    TextField("Notes facultatives", text: $notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(item == nil ? "Nouvel article" : "Modifier l’article")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Annuler") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") {
                        let p = Double(purchasePrice.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let r = Double(resalePrice.replacingOccurrences(of: ",", with: ".")) ?? 0
                        let q = max(0, Int(quantity) ?? 0)
                        onSave(StockItem(id: item?.id ?? UUID(), name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                                         category: category, reference: reference, quantity: q, unit: unit,
                                         purchasePrice: max(0, p), resalePrice: max(0, r), notes: notes, photoData: photoData))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

import PhotosUI
import UniformTypeIdentifiers

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
