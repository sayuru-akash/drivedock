import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var currentStep: OnboardingStep = .welcome
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
                        isAuthenticating: appState.auth.isAuthenticating,
                        authError: authError ?? appState.auth.authError,
                        onCancel: { cancelAuth() },
                        onRetry: { startAuth() },
                        onSkip: { completeOnboarding() }
                    )
                    .transition(.opacity)

                case .ready:
                    ReadyStep(onContinue: { completeOnboarding() })
                        .transition(.opacity)
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: currentStep)
        }
        .frame(minWidth: 500, minHeight: 400)
        .onChange(of: appState.auth.accounts.count) { _, newCount in
            if newCount > 0 && currentStep == .connecting {
                currentStep = .ready
            }
        }
    }

    private func startAuth() {
        currentStep = .connecting
        authError = nil

        Task {
            do {
                try await appState.auth.startAuthentication()
                // If we get here, auth completed successfully
                await MainActor.run {
                    currentStep = .ready
                }
            } catch {
                await MainActor.run {
                    if (error as? AuthError) != .userCancelled {
                        authError = error.localizedDescription
                    } else {
                        currentStep = .welcome
                    }
                }
            }
        }
    }

    private func cancelAuth() {
        appState.auth.cancelAuthentication()
        currentStep = .welcome
    }

    private func completeOnboarding() {
        appState.hasCompletedOnboarding = true
    }
}

// MARK: - Welcome Step

struct WelcomeStep: View {
    let onConnect: () -> Void
    let onSkip: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isPulsing = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "arrow.up.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.linearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                    .scaleEffect(isPulsing ? 1.05 : 0.95)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                        value: isPulsing
                    )
                    .onAppear { isPulsing = true }

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
    let onCancel: () -> Void
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

                    Text("Complete the sign-in process in your browser.\nThis window will update automatically.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Cancel") {
                        onCancel()
                    }
                    .buttonStyle(.bordered)
                    .padding(.top, 8)
                }
            } else if let error = authError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(.orange)

                    Text("Connection Failed")
                        .font(.headline)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 64, height: 64)
                    .foregroundStyle(.green)
                    .scaleEffect(isAnimating ? 1.0 : 0.5)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .animation(reduceMotion ? nil : .spring(response: 0.6, dampingFraction: 0.6), value: isAnimating)
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
