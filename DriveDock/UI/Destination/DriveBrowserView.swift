import SwiftUI

struct DriveBrowserView: View {
    @Environment(AppState.self) private var appState
    @State private var currentFolderID = "root"
    @State private var currentFolderName = "My Drive"
    @State private var breadcrumb: [(id: String, name: String)] = []
    @State private var items: [DriveFile] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var selectedTab: BrowserTab = .myDrive
    @State private var errorMessage: String?
    @State private var selectedItem: DriveFile?

    enum BrowserTab: String, CaseIterable {
        case myDrive, sharedDrives, recent, starred

        var displayName: String {
            switch self {
            case .myDrive: return "My Drive"
            case .sharedDrives: return "Shared Drives"
            case .recent: return "Recent"
            case .starred: return "Starred"
            }
        }

        var systemImage: String {
            switch self {
            case .myDrive: return "folder"
            case .sharedDrives: return "person.2"
            case .recent: return "clock"
            case .starred: return "star"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: $selectedTab) {
                ForEach(BrowserTab.allCases, id: \.self) { tab in
                    Label(tab.displayName, systemImage: tab.systemImage).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            // Breadcrumb
            if !breadcrumb.isEmpty && selectedTab == .myDrive {
                HStack(spacing: 4) {
                    Button("My Drive") {
                        breadcrumb = []
                        Task { await loadFolder(id: "root", name: "My Drive") }
                    }
                    .buttonStyle(.plain)
                    .font(.caption)

                    ForEach(breadcrumb.indices, id: \.self) { index in
                        Image(systemName: "chevron.right")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 8, height: 8)
                            .foregroundStyle(.secondary)
                        Button(breadcrumb[index].name) {
                            let target = breadcrumb[index]
                            breadcrumb = Array(breadcrumb.prefix(index))
                            Task { await loadFolder(id: target.id, name: target.name) }
                        }
                        .buttonStyle(.plain)
                        .font(.caption)
                    }

                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 12, height: 12)
                    .foregroundStyle(.secondary)
                TextField("Search Drive...", text: $searchText)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        Task { await search() }
                    }
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                        Task { await loadFolder(id: currentFolderID, name: currentFolderName) }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)

            Divider()

            // Content
            if isLoading {
                Spacer()
                ProgressView("Loading...")
                Spacer()
            } else if items.isEmpty {
                Spacer()
                ContentUnavailableView {
                    Label("No Items", systemImage: "folder")
                } description: {
                    Text(searchText.isEmpty ? "This folder is empty." : "No results found.")
                }
                Spacer()
            } else {
                List(items, selection: Binding(
                    get: { selectedItem?.id },
                    set: { id in selectedItem = items.first { $0.id == id } }
                )) { item in
                    DriveFileRow(item: item, onNavigate: {
                        if item.isFolder {
                            breadcrumb.append((id: currentFolderID, name: currentFolderName))
                            Task { await loadFolder(id: item.id, name: item.name) }
                        }
                    }, onUpload: {
                        uploadToFolder(item)
                    }, onOpenInBrowser: {
                        if let link = item.webViewLink, let url = URL(string: link) {
                            NSWorkspace.shared.open(url)
                        }
                    })
                    .tag(item.id)
                }
                .listStyle(.inset)
            }

            Divider()

            // Bottom bar
            HStack {
                Button {
                    showCreateFolder = true
                } label: {
                    Label("New Folder", systemImage: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()

                Text("\(items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(8)
        }
        .frame(minWidth: 500, minHeight: 400)
        .task {
            if selectedTab == .myDrive {
                await loadFolder(id: "root", name: "My Drive")
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            Task {
                switch newTab {
                case .myDrive:
                    breadcrumb = []
                    await loadFolder(id: "root", name: "My Drive")
                case .sharedDrives:
                    await loadSharedDrives()
                case .recent:
                    await loadRecentFiles()
                case .starred:
                    await loadStarredFiles()
                }
            }
        }
        .onChange(of: appState.auth.activeAccount?.id) { _, _ in
            Task {
                breadcrumb = []
                items = []
                switch selectedTab {
                case .myDrive:
                    await loadFolder(id: "root", name: "My Drive")
                case .sharedDrives:
                    await loadSharedDrives()
                case .recent:
                    await loadRecentFiles()
                case .starred:
                    await loadStarredFiles()
                }
            }
        }
        .alert("New Folder", isPresented: $showCreateFolder) {
            TextField("Folder name", text: $newFolderName)
            Button("Cancel", role: .cancel) { newFolderName = "" }
            Button("Create") {
                Task { await createFolder() }
            }
        }
    }

    // MARK: - Data Loading

    private func loadFolder(id: String, name: String) async {
        guard let accountID = appState.auth.activeAccount?.id else { return }
        isLoading = true
        errorMessage = nil
        currentFolderID = id
        currentFolderName = name

        do {
            let accessToken = try await appState.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "'\(id)' in parents and trashed = false"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,modifiedTime,webViewLink,parents,iconLink),nextPageToken"),
                URLQueryItem(name: "pageSize", value: "100"),
                URLQueryItem(name: "orderBy", value: "folder,name"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]

            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }

            let listResponse = try JSONDecoder().decode(DriveAPIListResponse.self, from: data)

            items = listResponse.files.map { file in
                DriveFile(
                    id: file.id,
                    name: file.name,
                    mimeType: file.mimeType,
                    size: file.parsedSize,
                    parentID: file.parents?.first,
                    webViewLink: file.webViewLink,
                    createdDate: nil,
                    modifiedDate: nil
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadSharedDrives() async {
        guard let accountID = appState.auth.activeAccount?.id else { return }
        isLoading = true

        do {
            let accessToken = try await appState.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "https://www.googleapis.com/drive/v3/drives")!
            components.queryItems = [
                URLQueryItem(name: "fields", value: "drives(id,name,createdTime)"),
                URLQueryItem(name: "pageSize", value: "100")
            ]

            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }

            struct DrivesResponse: Codable {
                let drives: [DriveItem]
                struct DriveItem: Codable {
                    let id: String
                    let name: String
                    let createdTime: String?
                }
            }

            let drivesResponse = try JSONDecoder().decode(DrivesResponse.self, from: data)
            items = drivesResponse.drives.map { drive in
                DriveFile(
                    id: drive.id,
                    name: drive.name,
                    mimeType: "application/vnd.google-apps.folder",
                    size: nil,
                    parentID: nil,
                    webViewLink: "https://drive.google.com/drive/folders/\(drive.id)",
                    createdDate: nil,
                    modifiedDate: nil
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadRecentFiles() async {
        guard let accountID = appState.auth.activeAccount?.id else { return }
        isLoading = true

        do {
            let accessToken = try await appState.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "trashed = false"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,modifiedTime,webViewLink,parents,iconLink)"),
                URLQueryItem(name: "pageSize", value: "50"),
                URLQueryItem(name: "orderBy", value: "modifiedTime desc"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]

            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }

            let listResponse = try JSONDecoder().decode(DriveAPIListResponse.self, from: data)

            items = listResponse.files.map { file in
                DriveFile(
                    id: file.id,
                    name: file.name,
                    mimeType: file.mimeType,
                    size: file.parsedSize,
                    parentID: file.parents?.first,
                    webViewLink: file.webViewLink,
                    createdDate: nil,
                    modifiedDate: nil
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func loadStarredFiles() async {
        guard let accountID = appState.auth.activeAccount?.id else { return }
        isLoading = true

        do {
            let accessToken = try await appState.auth.getAccessToken(for: accountID)

            var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "starred = true and trashed = false"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,modifiedTime,webViewLink,parents,iconLink)"),
                URLQueryItem(name: "pageSize", value: "50"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]

            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }

            let listResponse = try JSONDecoder().decode(DriveAPIListResponse.self, from: data)

            items = listResponse.files.map { file in
                DriveFile(
                    id: file.id,
                    name: file.name,
                    mimeType: file.mimeType,
                    size: file.parsedSize,
                    parentID: file.parents?.first,
                    webViewLink: file.webViewLink,
                    createdDate: nil,
                    modifiedDate: nil
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func search() async {
        guard !searchText.isEmpty else { return }
        guard let accountID = appState.auth.activeAccount?.id else { return }
        isLoading = true

        do {
            let accessToken = try await appState.auth.getAccessToken(for: accountID)
            let escapedQuery = searchText.replacingOccurrences(of: "'", with: "\\'")

            var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
            components.queryItems = [
                URLQueryItem(name: "q", value: "name contains '\(escapedQuery)' and trashed = false"),
                URLQueryItem(name: "fields", value: "files(id,name,mimeType,size,modifiedTime,webViewLink,parents,iconLink)"),
                URLQueryItem(name: "pageSize", value: "50"),
                URLQueryItem(name: "supportsAllDrives", value: "true"),
                URLQueryItem(name: "includeItemsFromAllDrives", value: "true")
            ]

            guard let url = components.url else { return }

            var request = URLRequest(url: url)
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                isLoading = false
                return
            }

            let listResponse = try JSONDecoder().decode(DriveAPIListResponse.self, from: data)

            items = listResponse.files.map { file in
                DriveFile(
                    id: file.id,
                    name: file.name,
                    mimeType: file.mimeType,
                    size: file.parsedSize,
                    parentID: file.parents?.first,
                    webViewLink: file.webViewLink,
                    createdDate: nil,
                    modifiedDate: nil
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func createFolder() async {
        guard !newFolderName.isEmpty, let accountID = appState.auth.activeAccount?.id else { return }

        do {
            let accessToken = try await appState.auth.getAccessToken(for: accountID)

            guard let url = URL(string: "https://www.googleapis.com/drive/v3/files?supportsAllDrives=true") else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let body: [String: Any] = [
                "name": newFolderName,
                "mimeType": "application/vnd.google-apps.folder",
                "parents": [currentFolderID]
            ]
            request.httpBody = try JSONSerialization.data(withJSONObject: body)

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  (httpResponse.statusCode == 200 || httpResponse.statusCode == 201) else { return }

            let file = try JSONDecoder().decode(DriveAPIListResponse.DriveAPIFile.self, from: data)
            let newFolder = DriveFile(
                id: file.id,
                name: file.name,
                mimeType: file.mimeType,
                size: file.parsedSize,
                parentID: file.parents?.first,
                webViewLink: file.webViewLink,
                createdDate: nil,
                modifiedDate: nil
            )
            items.insert(newFolder, at: 0)
            newFolderName = ""
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func uploadToFolder(_ folder: DriveFile) {
        guard let account = appState.auth.activeAccount else { return }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = true

        if panel.runModal() == .OK {
            let files = FileDropHandler.processDroppedItems(panel.urls)
            if !files.isEmpty {
                _ = appState.engine.addFiles(
                    files: files,
                    destinationFolderID: folder.id,
                    destinationFolderName: folder.name,
                    accountID: account.id
                )
                appState.engine.startProcessing()
            }
        }
    }
}

// MARK: - Drive File Row

struct DriveFileRow: View {
    @Environment(AppState.self) private var appState
    let item: DriveFile
    let onNavigate: () -> Void
    let onUpload: () -> Void
    let onOpenInBrowser: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .foregroundStyle(iconColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    if let size = item.size, size > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if isHovered {
                HStack(spacing: 6) {
                    if item.isFolder {
                        Button("Open") {
                            onNavigate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Upload Here") {
                            onUpload()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button {
                            downloadFolder()
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Download folder")
                    } else {
                        Button {
                            downloadFile()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.down.circle")
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 12, height: 12)
                                Text("Download")
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .help("Download file")
                    }

                    Button {
                        onOpenInBrowser()
                    } label: {
                        Image(systemName: "arrow.up.right.square")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Google Drive")
                }
            }
        }
        .padding(.vertical, 2)
        .onHover { hovering in isHovered = hovering }
        .onTapGesture {
            if item.isFolder {
                onNavigate()
            }
        }
    }

    private func downloadFile() {
        guard let account = appState.auth.activeAccount else { return }
        
        // Use default Downloads folder - no picker needed for simple downloads
        let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        
        appState.downloadEngine.addFile(
            driveFileID: item.id,
            fileName: item.name,
            fileSize: item.size ?? 0,
            localDirectory: downloadsFolder,
            accountID: account.id
        )
        appState.downloadEngine.startProcessing()
        
        // Switch to Downloads view
        appState.selectedSidebarItem = .downloads
    }

    private func downloadFolder() {
        guard let account = appState.auth.activeAccount else { return }
        
        // Use default Downloads folder
        let downloadsFolder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        
        Task {
            await appState.downloadEngine.addFolder(
                driveFolderID: item.id,
                folderName: item.name,
                localDirectory: downloadsFolder,
                accountID: account.id
            )
            appState.downloadEngine.startProcessing()
            
            // Switch to Downloads view
            await MainActor.run {
                appState.selectedSidebarItem = .downloads
            }
        }
    }

    private var icon: String {
        if item.isFolder { return "folder.fill" }
        let mime = item.mimeType
        if mime.hasPrefix("image/") { return "photo" }
        if mime.hasPrefix("video/") { return "video" }
        if mime.hasPrefix("audio/") { return "music.note" }
        if mime.contains("pdf") { return "doc.text" }
        if mime.contains("zip") || mime.contains("archive") { return "archivebox" }
        if mime.contains("spreadsheet") || mime.contains("excel") { return "tablecells" }
        if mime.contains("presentation") || mime.contains("powerpoint") { return "rectangle.on.rectangle" }
        if mime.contains("document") || mime.contains("word") { return "doc.richtext" }
        return "doc"
    }

    private var iconColor: Color {
        if item.isFolder { return .blue }
        let mime = item.mimeType
        if mime.hasPrefix("image/") { return .green }
        if mime.hasPrefix("video/") { return .purple }
        if mime.hasPrefix("audio/") { return .orange }
        if mime.contains("pdf") { return .red }
        return .secondary
    }
}
