//
//  WindowManager.swift
//  ezmenu
//
//  Created by Custom on 2026-03-02.
//

import SwiftUI
import SwiftData

nonisolated enum WindowType: Hashable {
    case newScript
    case editScript(scriptItem: PersistentIdentifier)
}

@Observable
class WindowManager {
    private var windows: [WindowType: NSWindow] = [:]
    private var observers: [WindowType: NSObjectProtocol] = [:]
    private var modelContainer: ModelContainer

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.accessory)
        }
    }
    
    func open(_ windowId: WindowType) {
        switch windowId {
        case .newScript:
            present(id: windowId, view: ScriptEditorView(container: modelContainer), title: "New Script")
        case .editScript(let scriptItem):
            present(id: windowId, view: ScriptEditorView(container: modelContainer, scriptItem: scriptItem), title: "Editing Script")
        }
    }
    
    private func present(id: WindowType, view: some View, title: String) {
        if let existing = windows[id] {
            self.activate(existing)
            return
        }
        
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        // otherwise we get illegal access violations on re-activations
        window.isReleasedWhenClosed = false

        window.title = title
        
        window.contentView = NSHostingView(rootView: view.modelContainer(self.modelContainer))
        window.setContentSize(NSSize(width: 480, height: 300))
        window.minSize = NSSize(width: 300, height: 200)
        
        self.activate(window)
        window.center()
        
        windows[id] = window
        
        let token = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.windows[id] = nil
            self?.observers[id] = nil
            
            if self?.windows.isEmpty == true {
                NSApp.setActivationPolicy(.accessory)
            }
        }

        observers[id] = token
    }
    
    private func activate(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
