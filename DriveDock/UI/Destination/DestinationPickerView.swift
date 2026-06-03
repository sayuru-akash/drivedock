import SwiftUI

struct DestinationPickerView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let accountID: String
    let onSelect: (DriveFolder) -> Void

    @State private var currentFolderID = "root"
    @State private var currentFolderName = "My Drive"
    @State private var breadcrumb: [(id: String, name: String)] = []
    @State private var folders: [DriveFolder] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var selectedTab: DestinationTab = .browse
    @State private var errorMessage: String?

    enum DestinationTab: String, CaseIterable {
        case browse, recent, starred, sharedDrives

        var displayName: String {
            switch self {
            case .browse: return "Browse"
            case .recent: return "Recent"
            case .starred: return "Starred"
            case .sharedDrives: return "Shared Drives"
            }
        }

        var systemImage: String {
            switch self {
            case .browse: return "folder"
            case .recent: return "clock"
            case .starred: return "star"
            case .sharedDrives: return "person.2"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Choose Destination")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Cancel destination selection")
            }
            .padding()

            // Tab bar
            Picker("", selection: $selectedTab) {
                ForEach(DestinationTab.allCases, id: \.self) { tab in
                    Label(tab.displayName, systemImage: tab.systemImage)
                        .tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.bottom, 8)

            switch selectedTab {
            case .browse:
                browseView
            case .recent:
                recentView
            case .starred:
                starredView
            case .sharedDrives:
                sharedDrivesView
            }

            // Footer
            HStack {
                Button("Use Current Folder") {
                    let folder = DriveFolder(
                        id: currentFolderID,
                        name: currentFolderName,
                        parentID: nil,
                        isSharedDrive: false,
                        sharedDriveID: nil,
                        ownerEmail: nil,
                        modifiedDate: nil,
                        childCount: nil
                    )
                    onSelect(folder)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .accessibilityLabel("Use \(currentFolderName) as destination")
            }
            .padding()
        }
        .frame(width: 500, height: 450)
        .task {
            await loadFolder(id: currentFolderID, name: currentFolderName)
        }
    }

    // MARK: - Browse View

    private var browseView: some View {
        VStack(spacing: 0) {
            // Breadcrumb
            if !breadcrumb.isEmpty {
                HStack(spacing: 4) {
                    Button("My Drive") {
                        Task { await loadFolder(id: "root", name: "My Drive") }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .accessibilityLabel("Navigate to My Drive")

                    ForEach(breadcrumb.indices, id: \.self) { index in
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Button(breadcrumb[index].name) {
                            let target = breadcrumb[index]
                            breadcrumb = Array(breadcrumb.prefix(index))
                            Task { await loadFolder(id: target.id, name: target.name) }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                        .accessibilityLabel("Navigate to \(breadcrumb[index].name)")
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
            }

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                TextField("Search folders...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await searchFolders() }
                    }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal)
            .padding(.bottom, 8)

            // Folder list
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if folders.isEmpty {
                ContentUnavailableView {
                    Label("No Folders", systemImage: "folder")
                } description: {
                    Text("This folder is empty.")
                }
            } else {
                List(folders) { folder in
                    HStack {
                        Image(systemName: folder.isSharedDrive ? "person.2.fill" : "folder.fill")
                            .foregroundStyle(folder.isSharedDrive ? .purple : .accentColor)
                            .accessibilityHidden(true)

                        Text(folder.name)
                            .lineLimit(1)

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .accessibilityHidden(true)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        breadcrumb.append((id: currentFolderID, name: currentFolderName))
                        Task { await loadFolder(id: folder.id, name: folder.name) }
                    }
                    .accessibilityLabel(folder.name)
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Open this folder")
                }
            }

            // New folder button
            HStack {
                Button {
                    showCreateFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Create a new folder")

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .alert("New Folder", isPresented: $showCreateFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                Task { await createFolder() }
            }
        }
    }

    // MARK: - Recent View

    private var recentView: some View {
        let recents = appState.persistence.loadRecentDestinations()

        return Group {
            if recents.isEmpty {
                ContentUnavailableView {
                    Label("No Recent Destinations", systemImage: "clock")
                }
            } else {
                List(recents) { recent in
                    HStack {
                        Image(systemName: recent.isSharedDrive ? "person.2.fill" : "folder.fill")
                            .foregroundStyle(recent.isSharedDrive ? .purple : .accentColor)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading) {
                            Text(recent.folderName)
                            Text(recent.lastUsedDate.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let folder = DriveFolder(
                            id: recent.folderID,
                            name: recent.folderName,
                            parentID: nil,
                            isSharedDrive: recent.isSharedDrive,
                            sharedDriveID: nil,
                            ownerEmail: nil,
                            modifiedDate: nil,
                            childCount: nil
                        )
                        onSelect(folder)
                        dismiss()
                    }
                    .accessibilityLabel("\(recent.folderName), used \(recent.lastUsedDate.formatted(date: .abbreviated, time: .shortened))")
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    // MARK: - Starred View

    private var starredView: some View {
        let starred = appState.persistence.loadStarredDestinations()

        return Group {
            if starred.isEmpty {
                ContentUnavailableView {
                    Label("No Starred Destinations", systemImage: "star")
                } description: {
                    Text("Star destinations for quick access.")
                }
            } else {
                List(starred) { star in
                    HStack {
                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .accessibilityHidden(true)

                        Text(star.folderName)

                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let folder = DriveFolder(
                            id: star.folderID,
                            name: star.folderName,
                            parentID: nil,
                            isSharedDrive: star.isSharedDrive,
                            sharedDriveID: nil,
                            ownerEmail: nil,
                            modifiedDate: nil,
                            childCount: nil
                        )
                        onSelect(folder)
                        dismiss()
                    }
                    .accessibilityLabel(star.folderName)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
    }

    // MARK: - Shared Drives View

    private var sharedDrivesView: some View {
        SharedDrivesListView(accountID: accountID) { folder in
            onSelect(folder)
            dismiss()
        }
    }

    // MARK: - Actions

    private func loadFolder(id: String, name: String) async {
        isLoading = true
        errorMessage = nil
        currentFolderID = id
        currentFolderName = name

        do {
            let result = try await DriveAPIService.shared.listFolder(
                folderID: id,
                accountID: accountID
            )
            folders = result.folders
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func searchFolders() async {
        guard !searchText.isEmpty else {
            await loadFolder(id: currentFolderID, name: currentFolderName)
            return
        }

        isLoading = true
        do {
            let result = try await DriveAPIService.shared.searchFolders(
                query: searchText,
                accountID: accountID
            )
            folders = result.folders
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func createFolder() async {
        guard !newFolderName.isEmpty else { return }
        do {
            let folder = try await DriveAPIService.shared.createFolder(
                name: newFolderName,
                parentID: currentFolderID,
                accountID: accountID
            )
            folders.insert(folder, at: 0)
            newFolderName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared Drives List

struct SharedDrivesListView: View {
    let accountID: String
    let onSelect: (DriveFolder) -> Void

    @State private var sharedDrives: [SharedDrive] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if sharedDrives.isEmpty {
                ContentUnavailableView {
                    Label("No Shared Drives", systemImage: "person.2")
                } description: {
                    Text("Shared Drives you have access to will appear here.")
                }
            } else {
                List(sharedDrives) { drive in
                    HStack {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(.purple)
                            .accessibilityHidden(true)
                        Text(drive.name)
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        let folder = DriveFolder(
                            id: drive.id,
                            name: drive.name,
                            parentID: nil,
                            isSharedDrive: true,
                            sharedDriveID: drive.id,
                            ownerEmail: nil,
                            modifiedDate: drive.createdDate,
                            childCount: nil
                        )
                        onSelect(folder)
                    }
                    .accessibilityLabel(drive.name)
                    .accessibilityAddTraits(.isButton)
                }
            }
        }
        .task {
            await loadSharedDrives()
        }
    }

    private func loadSharedDrives() async {
        isLoading = true
        do {
            sharedDrives = try await DriveAPIService.shared.listSharedDrives(accountID: accountID)
        } catch {
            // Silently fail
        }
        isLoading = false
    }
}
