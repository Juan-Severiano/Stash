//
//  OnboardingView.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import SwiftUI

struct OnboardingView: View {
    enum Step: Int, CaseIterable, Identifiable {
        case welcome, clipboard, shortcut, screenshots, ready
        var id: Int { rawValue }

        var eyebrow: String {
            switch self {
            case .welcome: "WELCOME TO STASH"
            case .clipboard: "YOUR HISTORY"
            case .shortcut: "QUICK ACCESS"
            case .screenshots: "SCREENSHOTS"
            case .ready: "ALL SET"
            }
        }
    }

    private var services: AppServices { AppServices.shared }
    @Bindable private var settings = AppServices.shared.settings
    @Environment(\.dismiss) private var dismiss
    @State private var step: Step = .welcome

    var body: some View {
        VStack(spacing: 0) {
            header

            ZStack {
                stepContent
                    .id(step)
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.easeInOut(duration: 0.24), value: step)

            progressBar
            navigationBar
        }
        .frame(width: 560, height: 540)
        .background(.background)
        .onAppear {
            if settings.onboardingCompleted {
                NSApp.keyWindow?.close()
                return
            }
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            appIcon(size: 30)

            Text("Stash")
                .font(.headline)

            Spacer()

            Text("\(step.rawValue + 1) of \(Step.allCases.count)")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.bar)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeStep(
                title: "Your clipboard, remembered.",
                body: "Stash quietly keeps what you copy close at hand — text, links, images, files, and more.",
                detail: "Press ⌥V whenever you need something back."
            )
        case .clipboard:
            stickerStep(
                asset: "OnboardingHistory",
                title: "A useful history.",
                body: "Everything you copy is saved automatically and organized by when you used it.",
                detail: "Pinned items always stay at the top."
            )
        case .shortcut:
            actionStep(
                asset: "OnboardingShortcut",
                title: "Open Stash from anywhere.",
                body: "Use the global shortcut to bring your clipboard history forward without leaving your flow."
            ) {
                HotkeyRecorderView(value: $settings.hotkeyOpen) {
                    services.hotkeys.refresh()
                }
                .controlSize(.large)
            }
        case .screenshots:
            actionStep(
                asset: "OnboardingScreenshots",
                title: "Keep screenshots nearby.",
                body: "Optionally add new screenshots to your local history. Nothing is monitored until you enable it."
            ) {
                Button(settings.monitorScreenshots ? "Screenshot Monitoring Enabled" : "Enable Screenshot Monitoring") {
                    settings.monitorScreenshots = true
                    services.screenshotWatcher.start()
                }
                .controlSize(.large)
                .disabled(settings.monitorScreenshots)

                Text("The region screenshot shortcut requests Screen Recording permission only when you use it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .ready:
            stickerStep(
                asset: "OnboardingReady",
                title: "Everything is in its place.",
                body: "Copy something, then press ⌥V to bring it back whenever you need it.",
                detail: "Stash is ready when you are."
            )
        }
    }

    private func welcomeStep(title: String, body: String, detail: String) -> some View {
        VStack(spacing: 18) {
            appIcon(size: 92)
            stepCopy(title: title, body: body)
            Label(detail, systemImage: "sparkle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(.horizontal, 72)
    }

    private func stickerStep(asset: String, title: String, body: String, detail: String) -> some View {
        VStack(spacing: 18) {
            stickerIcon(asset)
            stepCopy(title: title, body: body)
            Label(detail, systemImage: "sparkle")
                .font(.callout)
                .foregroundStyle(.secondary)
                .padding(.top, 6)
        }
        .padding(.horizontal, 72)
    }

    private func actionStep<Content: View>(
        asset: String,
        title: String,
        body: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 18) {
            stickerIcon(asset)
            stepCopy(title: title, body: body)
            VStack(spacing: 10) {
                content()
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 72)
    }

    private func appIcon(size: CGFloat) -> some View {
        Image(nsImage: NSApp.applicationIconImage)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }

    private func stickerIcon(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .interpolation(.high)
            .scaledToFit()
            .frame(width: 94, height: 94)
            .accessibilityHidden(true)
    }

    private func stepCopy(title: String, body: String) -> some View {
        VStack(spacing: 10) {
            Text(step.eyebrow)
                .font(.caption2.weight(.bold))
                .tracking(1.1)
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
            Text(body)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Navigation

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases) { item in
                Capsule()
                    .fill(item.rawValue <= step.rawValue ? Color.accentColor : Color.secondary.opacity(0.18))
                    .frame(height: 4)
                    .animation(.easeInOut(duration: 0.2), value: step)
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var navigationBar: some View {
        HStack {
            if step != .welcome && step != .ready {
                Button("Back") {
                    step = Step(rawValue: step.rawValue - 1) ?? .welcome
                }
                .controlSize(.large)
            }

            Spacer()

            if step == .ready {
                Button("Get Started") {
                    settings.onboardingCompleted = true
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Skip") {
                    settings.onboardingCompleted = true
                    dismiss()
                }
                .controlSize(.large)

                Button("Continue") {
                    step = Step(rawValue: step.rawValue + 1) ?? .ready
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.bar)
    }
}
