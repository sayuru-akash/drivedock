import SwiftUI

struct AccountSelectorButton: View {
    @Environment(AppState.self) private var appState
    @State private var showAccountPopover = false
    @State private var showSwitchConfirmation = false
    @State private var pendingAccount: DriveAccount?

    var body: some View {
        Button {
            showAccountPopover = true
        } label: {
            HStack(spacing: 8) {
                if let account = appState.auth.activeAccount {
                    if let avatarURL = account.avatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        Text(account.displayName)
                            .font(.caption.weight(.medium))
                            .lineLimit(1)
                        Text(account.email)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .frame(maxWidth: 120)
                } else {
                    Image(systemName: "person.circle")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("No Account")
                        .font(.caption)
                }

                Image(systemName: "chevron.down")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 8, height: 8)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Account selector")
        .accessibilityHint("Choose a Google account for uploads")
        .popover(isPresented: $showAccountPopover) {
            AccountPopover(
                onSelectAccount: { account in
                    handleAccountSwitch(account)
                },
                onAddAccount: {
                    showAccountPopover = false
                    Task {
                        try? await appState.auth.startAuthentication()
                    }
                }
            )
            .frame(width: 280)
        }
        .alert("Switch Account?", isPresented: $showSwitchConfirmation) {
            Button("Cancel", role: .cancel) {
                pendingAccount = nil
            }
            Button("Switch") {
                if let account = pendingAccount {
                    performAccountSwitch(account)
                }
                pendingAccount = nil
            }
        } message: {
            let activeUploads = appState.engine.activeUploadCount
            let activeDownloads = appState.downloadEngine.activeDownloadCount
            if activeUploads > 0 || activeDownloads > 0 {
                Text("There are \(activeUploads) active uploads and \(activeDownloads) active downloads. Switching accounts will not affect ongoing transfers.")
            } else {
                Text("Switch to \(pendingAccount?.email ?? "")?")
            }
        }
    }

    private func handleAccountSwitch(_ account: DriveAccount) {
        guard account.id != appState.auth.activeAccount?.id else {
            showAccountPopover = false
            return
        }

        let activeUploads = appState.engine.activeUploadCount
        let activeDownloads = appState.downloadEngine.activeDownloadCount

        if activeUploads > 0 || activeDownloads > 0 {
            pendingAccount = account
            showAccountPopover = false
            showSwitchConfirmation = true
        } else {
            showAccountPopover = false
            performAccountSwitch(account)
        }
    }

    private func performAccountSwitch(_ account: DriveAccount) {
        appState.auth.setActiveAccount(account)
    }
}

struct AccountPopover: View {
    @Environment(AppState.self) private var appState
    let onSelectAccount: (DriveAccount) -> Void
    let onAddAccount: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accounts")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(appState.auth.accounts) { account in
                Button {
                    onSelectAccount(account)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: account.tokenStatus.systemImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 14, height: 14)
                            .foregroundStyle(account.tokenStatus == .valid ? .green : .orange)
                            .accessibilityHidden(true)

                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(account.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        Spacer()

                        if appState.auth.activeAccount?.id == account.id {
                            Image(systemName: "checkmark.circle.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 14, height: 14)
                                .foregroundStyle(Color.accentColor)
                                .accessibilityLabel("Currently selected")
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(account.displayName), \(account.email)")
                .accessibilityAddTraits(appState.auth.activeAccount?.id == account.id ? .isSelected : [])
            }

            Divider()

            Button {
                onAddAccount()
            } label: {
                Label("Add Account", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add a new Google account")
        }
        .padding()
    }
}
