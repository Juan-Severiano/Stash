//
//  AppDelegate.swift
//  Stash
//
//  Created by Francisco Juan on 11/08/26.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppServices.shared.bootstrap()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
