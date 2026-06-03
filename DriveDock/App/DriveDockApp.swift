import SwiftUI

@main
struct DriveDockApp: App {
    @State private var appState = AppState.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear {
                    configureAppearance()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 700)

        MenuBarExtra {
            MenuBarPopoverView()
                .environment(appState)
        } label: {
            MenuBarIcon()
                .environment(appState)
        }
        .menuBarExtraStyle(.window)
    }

    private func configureAppearance() {
        NSWindow.allowsAutomaticWindowTabbing = false
    }
}
