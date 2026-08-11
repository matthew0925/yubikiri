import SwiftUI
import SwiftData

@main
struct YubikiriApp: App {
    var body: some Scene {
        WindowGroup {
            CaseListView()
        }
        .modelContainer(for: [Case.self, Entry.self])
    }
}
