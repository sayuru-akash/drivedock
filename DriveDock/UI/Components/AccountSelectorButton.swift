import SwiftUI

struct AccountSelectorButton: View {
    @Environment(AppState.self) private var appState
    @State private var showAccountPopover = false

    var body: some View {
        Button {
            showAccountPopover = true
        } label: {
            HStack(spacing: 6) {
                if let account = appState.auth.activeAccount {
                    if let avatarURL = account.avatarURL {
                        AsyncImage(url: avatarURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Image(systemName: "person.circle.fill")
                        }
                        .frame(width: 20, height: 20)
                        .clipShape(Circle())
                    } else {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 16))
                    }

                    Text(account.email)
                        .font(.caption)
                        .lineLimit(1)
                } else {
                    Image(systemName: "person.circle")
                        .font(.system(size: 16))
                    Text("No Account")
                        .font(.caption)
                }

                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showAccountPopover) {
            AccountPopover()
                .frame(width: 250)
        }
    }
}

struct AccountPopover: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Accounts")
                .font(.headline)
                .padding(.bottom, 4)

            ForEach(appState.auth.accounts) { account in
                Button {
                    appState.auth.setActiveAccount(account)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: account.tokenStatus.systemImage)
                            .foregroundStyle(account.tokenStatus == .valid ? .green : .orange)
                            .font(.system(size: 12))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(account.displayName)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(account.email)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        if appState.auth.activeAccount?.id == account.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.accentColor)
                                .font(.system(size: 12))
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            Divider()

            Button {
                Task {
                    _ = try? await appState.auth.startAuthentication()
                }
            } label: {
                Label("Add Account", systemImage: "plus.circle")
                    .font(.subheadline)
            }
            .buttonStyle(.plain)
        }
        .padding()
    }
}
