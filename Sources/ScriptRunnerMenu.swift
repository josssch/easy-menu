//
//  Menu.swift
//  ezmenu
//
//  Created by Custom on 2026-02-28.
//

import SwiftUI
import SwiftData
internal import Combine

struct ScriptRunnerMenu: View {
    @Environment(\.modelContext) private var modelContext

    @Environment(WindowManager.self) private var windowManager
    @Environment(ScriptRunner.self) private var scriptRunner
    
    @Query(sort: \ScriptItem.order) private var items: [ScriptItem]
    
    private let timer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()
    @State private var tick = Date()
    
    var body: some View {
        ForEach(items) { item in
            ScriptMenuItem(
                item: item,
                isRunning: scriptRunner.isRunning(item.path),
                tick: tick,
                onRun: { runScript(item) },
                onEdit: { openScriptEditor(item) },
                onStop: { let _ = scriptRunner.killScript(item.path) }
            )
        }
        .onReceive(timer) { tick = $0 }
        
        Divider()
        
        Button("New Script...", systemImage: "plus") {
            windowManager.open(.newScript)
        }
        
        Button("Quit", systemImage: "xmark.rectangle") {
            NSApplication.shared.terminate(nil)
        }
    }
    
    private func openScriptEditor(_ script: ScriptItem) {
        windowManager.open(.editScript(scriptItem: script.persistentModelID))
    }
    
    private func runScript(_ script: ScriptItem) {
        scriptRunner.spawnScript(script.path, args: script.args) { result in
            Task { @MainActor in
                modelContext.insert(RunInfo(exitCode: result.exitCode, lines: result.trailingLines, script: script))
            }
        }
    }
}

struct ScriptMenuItem: View {
    let item: ScriptItem

    let isRunning: Bool
    let tick: Date
    
    let onRun: () -> Void
    let onEdit: () -> Void
    let onStop: () -> Void

    var body: some View {
        let lastRun = item.latestRun()
        
        Menu {
            Section {
                Button("Run", systemImage: "play.fill", action: onRun)
                Button("Edit Script...", systemImage: "square.and.pencil", action: onEdit)
            }
            .disabled(isRunning)
            
            if isRunning {
                Section("Currently running...") {
                    Button("Stop", systemImage: "stop.fill", action: onStop)
                }
            } else if let lastRun {
                Section("Finished \((lastRun.createdAt - 1).formatted(.relative(presentation: .numeric)))") {
                    let lines = lastRun.lines.components(separatedBy: "\n")
                    ForEach(lines.indices, id: \.self) { i in
                        let raw = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                        let line = raw.count > 45 ? raw.prefix(42) + "..." : raw
                        
                        Text(line)
                            .font(.system(size: 11).monospaced())
                    }

                    Text("Status: \(lastRun.exitCode == 0 ? "OK" : lastRun.exitCode.formatted())")
                        .font(.headline)
                }
                
                // allow the relative last run time to update
                .id("\(item.persistentModelID)-\(tick)")
            }
        } label: {
            let icon: String = {
                guard !isRunning else { return "slowmo" }
                guard let run = lastRun, run.createdAt.distance(to: tick) < 120 else { return "play.fill" }
                return run.exitCode == 0 ? "checkmark" : "xmark"
            }()
            
            Label(item.label, systemImage: icon)
        } primaryAction: {
            if isRunning { return }
            
            if NSEvent.modifierFlags.contains(.command) {
                onEdit()
                return
            }
            
            onRun()
        }
    }
}
