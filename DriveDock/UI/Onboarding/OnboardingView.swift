import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var currentStep: OnboardingStep = .welcome
    @State private var isAuthenticating = false
    @State private var authError: String?

    enum OnboardingStep {
        case welcome
        case connecting
        case ready
    }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                switch currentStep {
                case .welcome:
                    WelcomeStep(
                        onConnect: { startAuth() },
                        onSkip: { completeOnboarding() }
                    )
                    .transition(.opacity)

                case .connecting:
                    ConnectingStep(
                        isAuthenticating: isAuthenticating,
                        authError: authError,
                        onRetry: { startAuth() },
                        onSkip: { completeOnboarding() }
                    )
                    .transition(.opacity)

                case .ready:
                    ReadyStep(onContinue: { completeOnboarding() })
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: currentStep)
        }
        .frame(minWidth: 500, minHeight: 400)
    }

    private func startAuth() {
        currentStep = .connecting
        isAuthenticating = true
        authError = nil

        Task {
            do {
                let url = try await appState.auth.startAuthentication()
                NSWorkspace.shared.open(url)

                // Wait for callback - in a real app, this is handled by the URL scheme
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                isAuthenticating = false

                // If auth succeeds, move to ready
                if !appState.auth.accounts.isEmpty {
                    currentStep = .ready
                }
            } catch {
                isAuthenticating = false
                authError = error.localizedDescription
            }
        }
    }

    private func completeOnboarding() {
        appState.hasCompletedOnboarding = true
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    let onConnect: () -> Void
    let onSkip: () -> Void

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .symbolEffect(.pulse, options: .repeating)

                Text("DriveDock")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text("Upload files and folders to Google Drive\nwith speed, clarity, and control.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            VStack(spacing: 12) {
                Button(action: onConnect) {
                    HStack(spacing: 8) {
                        Image(systemName: "person.crop.circle.badge.plus")
                        Text("Connect Google Drive")
                    }
                    .font(.headline)
                    .frame(maxWidth: 280)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)

                Button("Explore without account") {
                    onSkip()
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.bottom, 40)
        }
        .padding(40)
    }
}

// MARK: - Connecting Step

struct ConnectingStep: View {
    let isAuthenticating: Bool
    let authError: String?
    let onRetry: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            if isAuthenticating {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)

                    Text("Waiting for Google authorization...")
                        .font(.headline)

                    Text("Complete the sign-in process in your browser.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else if let error = authError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)

                    Text("Connection Failed")
                        .font(.headline)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 12) {
                        Button("Try Again") {
                            onRetry()
                        }
                        .buttonStyle(.borderedProminent)

                        Button("Skip for Now") {
                            onSkip()
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }

            Spacer()
        }
        .padding(40)
    }
}

// MARK: - Ready Step

struct ReadyStep: View {
    let onContinue: () -> Void
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                    .symbolEffect(.bounce, value: isAnimating)
                    .onAppear { isAnimating = true }

                Text("You're All Set!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Drop files onto DriveDock to start uploading.\nYour uploads will continue safely in the background.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            Button("Start Using DriveDock") {
                onContinue()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)
            .padding(.bottom, 40)
        }
        .padding(40)
    }
}
