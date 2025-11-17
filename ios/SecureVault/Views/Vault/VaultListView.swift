//
//  VaultListView.swift
//  SecureVault
//

import SwiftUI

struct VaultListView: View {
    @EnvironmentObject var vaultManager: VaultManager
    @State private var searchText = ""
    @State private var selectedCategory: VaultEntry.Category?
    @State private var showAddSheet = false
    @State private var showingEntry: VaultEntry?

    var filteredEntries: [VaultEntry] {
        var entries = vaultManager.entries

        if !searchText.isEmpty {
            entries = vaultManager.searchEntries(query: searchText)
        }

        if let category = selectedCategory {
            entries = entries.filter { $0.category == category }
        }

        return entries.sorted { $0.modifiedAt > $1.modifiedAt }
    }

    var body: some View {
        NavigationView {
            List {
                if !vaultManager.favoriteEntries.isEmpty {
                    Section("Favorites") {
                        ForEach(vaultManager.favoriteEntries) { entry in
                            EntryRow(entry: entry)
                                .onTapGesture {
                                    showingEntry = entry
                                }
                        }
                    }
                }

                Section {
                    ForEach(filteredEntries) { entry in
                        EntryRow(entry: entry)
                            .onTapGesture {
                                showingEntry = entry
                            }
                    }
                    .onDelete { indexSet in
                        Task {
                            try? await vaultManager.deleteEntries(at: indexSet)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search passwords")
            .navigationTitle("Vault")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Menu {
                        Button(action: { selectedCategory = nil }) {
                            Label("All Items", systemImage: "square.grid.2x2")
                        }

                        ForEach(VaultEntry.Category.allCases, id: \.self) { category in
                            Button(action: { selectedCategory = category }) {
                                Label(category.rawValue, systemImage: category.icon)
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                AddEditEntryView()
            }
            .sheet(item: $showingEntry) { entry in
                EntryDetailView(entry: entry)
            }
        }
    }
}

struct EntryRow: View {
    let entry: VaultEntry

    var body: some View {
        HStack {
            Image(systemName: entry.category.icon)
                .font(.title2)
                .foregroundColor(entry.category.color)
                .frame(width: 40, height: 40)
                .background(entry.category.color.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(entry.name)
                        .font(.headline)

                    if entry.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }

                    if entry.hasTOTP {
                        Image(systemName: "timer")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }

                if !entry.username.isEmpty {
                    Text(entry.username)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                if let domain = entry.domain {
                    Text(domain)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
    }
}
