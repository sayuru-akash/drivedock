import SwiftUI

struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        if appState.isOnboarding {
            OnboardingView()
                .transition(.opacity)
        } else {
            appNavigation
                .sheet(isPresented: $state.showSettings) {
                    SettingsView()
                }
        }
    }

    private var appNavigation: some View {
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
                Button {
                    appState.showSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 16, height: 16)
                }
                .accessibilityLabel("Settings")
                .help("Open Settings")
            }
        }
    }
}
