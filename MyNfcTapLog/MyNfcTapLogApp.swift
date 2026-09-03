import SwiftData
import SwiftUI

@main
struct MyNfcTapLogApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [TagItem.self, LogEntry.self])
    }
}
