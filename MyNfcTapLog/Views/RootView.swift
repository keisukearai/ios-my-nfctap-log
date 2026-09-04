import SwiftData
import SwiftUI

struct RootView: View {
    @Environment(\.modelContext) private var context

    @State private var loc = Localizer()
    @State private var scan = ScanCoordinator()
    @State private var registerText = ""

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
                    // シートを閉じてから名前入力アラートに渡す。設定からの登録と同じ流れに揃えるため。
                    scan.outcome = nil
                    scan.pendingRegistration = uid
                },
                onRetry: {
                    scan.outcome = nil
                    Task { await scan.scanToLog(context: context, loc: loc) }
                },
                onClose: { scan.outcome = nil }
            )
            .environment(loc)
        }
        .alert(loc.t("register.title"), isPresented: registerBinding) {
            TextField(loc.t("rename.placeholder"), text: $registerText)
            Button(loc.t("common.cancel"), role: .cancel) { scan.pendingRegistration = nil }
            Button(loc.t("common.register")) {
                scan.outcome = scan.commitRegistration(label: registerText, context: context)
            }
        } message: {
            // アラートのメッセージは入力欄の上に1つしか置けないため、UID と注記もここにまとめる。
            Text("\(loc.t("register.body"))\n\(scan.pendingRegistration ?? "")\n\(loc.t("register.note"))")
        }
        // 前のタグに付けた名前が入力欄に残らないよう、アラートを出すたびに空に戻す。
        .onChange(of: scan.pendingRegistration) { _, uid in
            if uid != nil { registerText = "" }
        }
        // デザインに暗色パレットが無いため、ライト固定で表示する。
        .preferredColorScheme(.light)
        // layoutDirection は端末の言語設定に従うため、アプリ内の言語切り替えに合わせて上書きする。
        .environment(\.layoutDirection, loc.language.isRightToLeft ? .rightToLeft : .leftToRight)
        .task {
#if DEBUG
            if SampleData.isRequested { SampleData.seed(into: context) }
#endif
        }
    }

    private var registerBinding: Binding<Bool> {
        Binding(
            get: { scan.pendingRegistration != nil },
            set: { if !$0 { scan.pendingRegistration = nil } }
        )
    }
}
