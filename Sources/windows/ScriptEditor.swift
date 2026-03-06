//
//  ScriptEditor.swift
//  ezmenu
//
//  Created by Custom on 2026-03-02.
//

import SwiftData
import SwiftUI
internal import UniformTypeIdentifiers

//let scriptTypes: [UTType] = [.plainText, .text, .script, .executable, .shellScript]

struct VerticalLabeledContentStyle: LabeledContentStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            configuration.label
                .font(.body)
            configuration.content
        }
    }
}

extension LabeledContentStyle where Self == VerticalLabeledContentStyle {
    static var vertical: VerticalLabeledContentStyle { .init() }
}

struct ScriptEditorView: View {
    private var modelContext: ModelContext
    
    @Environment(\.dismissWindow) private var dismissWindow

    let isNew: Bool
    @State var scriptItem: ScriptItem = ScriptItem()

    @State var showFilePicker = false
    @State var showDeleteConfirmation = false
    @State var shouldDismiss = false

    @State var args: String

    init(container: ModelContainer, scriptItem scriptId: PersistentIdentifier? = nil) {
        modelContext = ModelContext(container)
        modelContext.autosaveEnabled = false

        if let id = scriptId, let scriptItem = modelContext.model(for: id) as? ScriptItem {
            self.scriptItem = scriptItem
            self.args = scriptItem.argsString
            self.isNew = false
            return
        }
        
        self.isNew = true
        self.args = ""
    }

    var body: some View {
        VStack(spacing: 24) {
            Grid(alignment: .leading, verticalSpacing: 4) {
               GridRow {
                   Text("Label")
                   Text("Position")
               }
               
               GridRow {
                   TextField("", text: $scriptItem.label)
                   HStack(spacing: 4) {
                       TextField("", value: $scriptItem.order, format: .number)
                       Stepper("", value: $scriptItem.order)
                   }.frame(maxWidth: 72)
               }
               .labelsHidden()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Script Path")
                HStack {
                    TextField("Script Path", text: .constant(scriptItem.path))
                        .disabled(true)
                        .labelsHidden()  // this hides the second "Script Path", but for a11y I'd like to keep it there
                        .truncationMode(.middle)

                    Button("Choose...") { showFilePicker = true }
                    Button("New", action: promptAndCreateScript)
                }
                .padding(.bottom, 4)
                
                Text("Arguments")
                VStack(alignment: .leading) {
                    TextField("", text: $args)
                        .labelsHidden()
                        .font(.system(size: 13).monospaced())
                        .onChange(of: args) {
                            scriptItem.argsString = $1
                        }
                    
                    Text("\(scriptItem.args.count) argument\(scriptItem.args.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            HStack {
                if !isNew {
                    Button("Delete", role: .destructive) {
                        showDeleteConfirmation = true
                    }
                    .foregroundStyle(.red)
                }
                
                Spacer()
                
                Button("Cancel", role: .cancel) {
                    dismissWindow()
                }

                Button("Save", role: .confirm) {
                    save()
                    dismissWindow()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!scriptItem.isValid)
            }
        }
        .frame(maxWidth: 480)
        .padding(20)
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: [.item]) { result in
            guard case .success(let url) = result else {
                return
            }

            scriptItem.path = url.path()
        }
        .confirmationDialog(
            "Are you sure you want to delete this script?", isPresented: $showDeleteConfirmation
        ) {
            Button("Yes", role: .destructive) {
                modelContext.delete(scriptItem)
                try? modelContext.save()

                // have to do it this way because the normal dismissWindow() call (nor any workarounds I've tried)
                // have been working
                NSApp.keyWindow?.sheetParent?.close()
            }
        }
        .onKeyPress(.escape) {
            dismissWindow()
            return .handled
        }
    }

    func promptAndCreateScript() {
        let panel = NSSavePanel()
        panel.title = "New Script"
        panel.nameFieldStringValue = "script.sh"
        
        guard panel.runModal() == .OK, let url = panel.url else { return }
        
        FileManager.default.createFile(atPath: url.path, contents: nil, attributes: [
            .posixPermissions: [0o755] // make it executable by default
        ])
        NSWorkspace.shared.open(url)
        
        scriptItem.path = url.path()
    }
    
    private func save() {
        if isNew {
            modelContext.insert(scriptItem)
        }
        
        try? modelContext.save()
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ScriptItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    
    let scriptItem = ScriptItem(
        label: "Preview", script: "/Users/Preview/test.sh", args: "test test2"
    )
    
    container.mainContext.insert(scriptItem)
    try? container.mainContext.save()
    
    return ScriptEditorView(
        container: container,
        scriptItem: scriptItem.persistentModelID
    )
    .modelContainer(container)
}
