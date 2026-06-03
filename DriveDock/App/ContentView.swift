import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        if appState.isOnboarding {
            OnboardingView()
                .transition(.opacity)
        } else {
            NavigationSplitView {
                SidebarView()
            } detail: {
                DetailView()
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    AccountSelectorButton()
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 8) {
                        Button {
                            appState.showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                        .help("Open Settings")

                        Button {
                            appState.showInspector.toggle()
                        } label: {
                            Image(systemName: appState.showInspector ? "sidebar.right" : "sidebar.right")
                        }
                        .accessibilityLabel(appState.showInspector ? "Hide Inspector" : "Show Inspector")
                        .help(appState.showInspector ? "Hide Inspector" : "Show Inspector")
                    }
                }
            }
            .sheet(isPresented: $state.showSettings) {
                SettingsView()
            }
        }
    }
}
