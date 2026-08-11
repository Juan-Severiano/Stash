//
//  StashApp.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import SwiftUI

@main
struct StashApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("History", id: "history") {
            HistoryWindowView()
        }

        Window("Welcome to Stash", id: "onboarding") {
            OnboardingView()
        }
        .defaultLaunchBehavior(.presented)

        MenuBarExtra {
            StashMenuBarContent()
        } label: {
            Image("Dock")
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
                .accessibilityLabel("Stash")
        }

        Settings {
            SettingsView()
        }
    }
}
