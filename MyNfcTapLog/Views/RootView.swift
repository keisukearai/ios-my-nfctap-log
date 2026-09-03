import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context

    @State private var loc = Localizer()
    @State private var scan = ScanCoordinator()

    var body: some View {
        NavigationStack {
            HomeView()
        }
        .tint(Theme.accent)
        .environment(loc)
        .environment(scan)
        .sheet(item: $scan.outcome) { outcome in
            ScanResultSheet(
                outcome: outcome,
                onRegister: { uid in
                    scan.register(uid: uid, context: context)
                    scan.outcome = nil
                },
                onRetry: {
                    scan.outcome = nil
                    Task { await scan.scanToLog(context: context, loc: loc) }
                },
                onClose: { scan.outcome = nil }
            )
            .environment(loc)
        }
        // デザインに暗色パレットが無いため、ライト固定で表示する。
        .preferredColorScheme(.light)
        .task {
#if DEBUG
            if SampleData.isRequested { SampleData.seed(into: context) }
#endif
        }
    }
}
