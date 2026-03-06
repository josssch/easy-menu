//
//  MenuItem.swift
//  ezmenu
//
//  Created by Custom on 2026-03-02.
//

import Foundation
import SwiftData

@Model
class RunInfo {
    var script: ScriptItem?
    var exitCode: Int32
    var lines: String
    
    var createdAt: Date = Date()
    
    init(exitCode: Int32, lines: String = "", script: ScriptItem? = nil) {
        self.exitCode = exitCode
        self.script = script
        self.lines = lines
    }
}

@Model
class ScriptItem {
    var label: String
    var path: String
    var argsString: String
    var order: Int
    
    @Relationship(deleteRule: .noAction, inverse: \RunInfo.script)
    var previousRuns: [RunInfo] = []

    init(label: String = "", script: String = "", args: String = "", order: Int = 0) {
        self.label = label
        self.path = script
        self.argsString = args
        self.order = order
    }

    var args: [String] {
        parseArguments(from: argsString)
    }
    
    var isValid: Bool {
        !label.isEmpty && !path.isEmpty
    }
    
    func latestRun() -> RunInfo? {
        let selfId = self.persistentModelID
        var descriptor = FetchDescriptor<RunInfo>(
            predicate: #Predicate { $0.script?.persistentModelID == selfId },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        
        descriptor.fetchLimit = 1
        
        return try? modelContext?.fetch(descriptor).first
    }
}

func parseArguments(from input: String) -> [String] {
    var args: [String] = []
    var current = ""
    var inSingleQuote = false
    var inDoubleQuote = false
    var i = input.startIndex

    while i < input.endIndex {
        let c = input[i]

        switch c {
        case "\"" where !inSingleQuote:
            inDoubleQuote.toggle()
        case "'" where !inDoubleQuote:
            inSingleQuote.toggle()
        case "\\" where !inSingleQuote: // everything in single quotes are considered literal
            let next = input.index(after: i)
            if next < input.endIndex {
                current.append(input[next])
                i = next
            }
        case " ", "\t":
            if inDoubleQuote || inSingleQuote {
                current.append(c)
            } else if !current.isEmpty {
                args.append(current)
                current = ""
            }
        default:
            current.append(c)
        }

        i = input.index(after: i)
    }

    // don't consider args that are not closed off, as command lines don't parse those well
    if !current.isEmpty && !inSingleQuote && !inDoubleQuote {
        args.append(current)
    }

    return args
}
