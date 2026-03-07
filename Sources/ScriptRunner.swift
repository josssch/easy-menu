//
//  ScriptRunner.swift
//  ezmenu
//
//  Created by Custom on 2026-03-05.
//

import SwiftUI

struct RunResult {
    let exitCode: Int32
    let trailingLines: String
}

actor ScriptOutputBuffer {
    let maxLines: Int
    let encoding: String.Encoding
    
    var remaining: String? = nil
    var trailingLines: [String] = []
    
    init(encoding: String.Encoding = .utf8, maxLines: Int = 5) {
        self.maxLines = maxLines
        self.encoding = encoding
    }
    
    func append(_ data: Data) {
        let text = String(data: data, encoding: encoding)
        let current = (remaining ?? "") + (text ?? "")
        
        var lines = current.components(separatedBy: "\n")
        remaining = lines.removeLast()
        
        trailingLines.append(contentsOf: lines)
        if trailingLines.count > maxLines {
            trailingLines.removeFirst(trailingLines.count - maxLines)
        }
    }
    
    func flush() {
        guard let remaining, !remaining.isEmpty else {
            return
        }
        
        trailingLines.append(remaining)
        self.remaining = nil
    }
    
    func toString() -> String {
        self.flush()
        return trailingLines.joined(separator: "\n")
    }
}

func loginShellEnvironment() -> [String: String] {
    // Determine user's shell from /etc/passwd or SHELL env var
    let shell = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/sh"
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: shell)
    // -l = login shell (loads full config), -c = run command
    process.arguments = ["-l", "-c", "env -0"]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    
    try? process.run()
    process.waitUntilExit()
    
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let raw = String(data: data, encoding: .utf8) ?? ""
    
    // env -0 uses null separators, safe for values that contain newlines
    var env: [String: String] = [:]
    for entry in raw.components(separatedBy: "\0") {
        guard let eq = entry.firstIndex(of: "=") else { continue }
        let key = String(entry[entry.startIndex..<eq])
        let value = String(entry[entry.index(after: eq)...])
        env[key] = value
    }
    return env
}

@MainActor
@Observable
class ScriptRunner {
    private var liveScripts: [String: Task<Void, Never>] = [:]
    
    func isRunning(_ path: String) -> Bool {
        let task = liveScripts[path]
        
        if task?.isCancelled == true {
            liveScripts.removeValue(forKey: path)
            return false
        }
        
        return task != nil
    }
    
    @discardableResult
    func spawnScript(_ path: String, args: [String] = [], onEnd: @Sendable @escaping (RunResult) -> Void = {_ in}) -> Task<Void, Never> {
        if let currentTask = liveScripts[path] {
            return currentTask
        }
        
        let task = Task.detached {
            let process = Process()
            
            // handing it off the sh handles shebangs, (with -l flag so .profile stuff loads)
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-l", path] + args
            
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            
            process.environment = ProcessInfo.processInfo.environment.merging([
                "NO_COLOR": "1",
                "CLICOLOR": "0",
                "TERM": "dumb"
            ]) { _, new in new }
            
            let output = ScriptOutputBuffer()
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                guard !data.isEmpty else {
                    Task { await output.flush() }
                    handle.readabilityHandler = nil
                    return
                }
                
                Task { await output.append(data) }
            }

            let exitCode: Int32
            do {
                print("Attempting to run script \(path)")

                exitCode = try await withTaskCancellationHandler {
                    try await withCheckedThrowingContinuation { cont in
                        process.terminationHandler = { p in
                            cont.resume(returning: p.terminationStatus)
                        }
                        
                        do {
                            try process.run()
                        } catch {
                            cont.resume(throwing: error)
                        }
                    }
                } onCancel: {
                    process.terminate()
                }
            } catch {
                print("Failed to launch script: \(error)")
                exitCode = -1
             }
        
            print("Script exited")
            
            await MainActor.run { () -> Void in
                self.liveScripts.removeValue(forKey: path)
            }
            
            Task {
                let result = RunResult(exitCode: exitCode, trailingLines: await output.toString())
                onEnd(result)
            }
        }
        
        liveScripts[path] = task
        return task
    }
    
    func killScript(_ path: String) -> Bool {
        liveScripts[path]?.cancel()
        return liveScripts.removeValue(forKey: path) != nil
    }
}
