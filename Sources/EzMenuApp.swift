import SwiftUI
import SwiftData

@main
struct EzMenuApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([ScriptItem.self])
        
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appending(path: Bundle.main.bundleIdentifier!)
        try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        
        let storeURL = appFolder.appending(path: "default.store")
        let modelConfiguration = ModelConfiguration(schema: schema, url: storeURL)
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    @State var windowManager: WindowManager
    @State var scriptRunner = ScriptRunner()
    
    init() {
        windowManager = WindowManager(modelContainer: sharedModelContainer)
        
        // just making it so command + q closes the window instead of exiting
        // because my monkey brain just associates CMD + Q with "window go away"
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command),
               event.charactersIgnoringModifiers == "q" {
                NSApplication.shared.keyWindow?.close()
                return nil
            }
            
            return event
        }
    }
    
    var body: some Scene {
        MenuBarExtra {
            ScriptRunnerMenu()
                .modelContainer(sharedModelContainer)
                .environment(windowManager)
                .environment(scriptRunner)
        } label: {
            Image(systemName: "function")
                .imageScale(.large)
                .scaledToFit()
        }
    }
}
