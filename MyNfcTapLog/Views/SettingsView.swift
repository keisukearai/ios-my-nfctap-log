import SwiftData
import SwiftUI

struct SettingsView: View {
    @Environment(Localizer.self) private var loc
    @Environment(ScanCoordinator.self) private var scan
    @Environment(\.modelContext) private var context

    /// 設定は編集画面なので、ホームの「古い順」ではなく登録順で固定して並べる。
    @Query(sort: \TagItem.createdAt, order: .forward) private var tags: [TagItem]

    @State private var expandedTag: TagItem?
    @State private var renameTarget: TagItem?
    @State private var renameText = ""
    @State private var deleteTarget: TagItem?

    var body: some View {
        @Bindable var loc = loc

        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                registeredSection
                addSection
                languageSection
                aboutSection
            }
            .padding(.bottom, 24)
        }
        .background(Theme.groupedBackground)
        .safeAreaInset(edge: .top, spacing: 0) {
            Text(loc.t("settings.title"))
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 16)
                .background(Theme.groupedBackground)
        }
        .navigationBarTitleDisplayMode(.inline)
        .alert(loc.t("rename.title"), isPresented: renameBinding) {
            TextField(loc.t("rename.placeholder"), text: $renameText)
            Button(loc.t("common.cancel"), role: .cancel) { renameTarget = nil }
            Button(loc.t("common.save")) { commitRename() }
        } message: {
            Text(loc.t("rename.body"))
        }
        .confirmationDialog(
            deleteTarget.map { loc.t("delete.confirmTitle", displayName($0)) } ?? "",
            isPresented: deleteBinding,
            titleVisibility: .visible
        ) {
            Button(loc.t("tag.deleteTag"), role: .destructive) { commitDelete() }
            Button(loc.t("common.cancel"), role: .cancel) { deleteTarget = nil }
        } message: {
            Text(loc.t("tag.deleteNote"))
        }
    }

    // MARK: - 登録済みのタグ

    private var registeredSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(loc.t("settings.registeredTags"))

            VStack(spacing: 0) {
                ForEach(tags) { tag in
                    tagRow(tag)
                    Divider().overlay(Theme.dividerLight)
                }
            }
            .background(Theme.card)
            .overlay(alignment: .top) { Divider().overlay(Theme.divider) }

            note(loc.t("settings.registeredNote"))
            note(loc.t("settings.unnamedNote"))
        }
    }

    private func tagRow(_ tag: TagItem) -> some View {
        let isExpanded = expandedTag?.persistentModelID == tag.persistentModelID

        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.16)) {
                    expandedTag = isExpanded ? nil : tag
                }
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(displayName(tag))
                            .font(.system(size: 16))
                            .foregroundStyle(tag.isUnnamed ? Theme.unnamedLabel : Theme.textBody)
                        Text(tag.uid)
                            .font(Theme.mono(11))
                            .kerning(0.4)
                            .foregroundStyle(Theme.uid)
                    }

                    Spacer(minLength: 12)

                    Text(loc.t(ThresholdOption.matching(tag.thresholdHours).key))
                        .font(.system(size: 12))
                        .foregroundStyle(tag.thresholdHours > 0 ? Theme.textFaint : Theme.thresholdOff)

                    Text("›")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.chevron)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                editPanel(tag)
            }
        }
    }

    private func editPanel(_ tag: TagItem) -> some View {
        VStack(spacing: 0) {
            Menu {
                ForEach(ThresholdOption.allCases) { option in
                    Button {
                        tag.thresholdHours = option.rawValue
                        try? context.save()
                    } label: {
                        if tag.thresholdHours == option.rawValue {
                            Label(loc.t(option.key), systemImage: "checkmark")
                        } else {
                            Text(loc.t(option.key))
                        }
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Text(loc.t("tag.threshold"))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textElapsed)
                    Spacer()
                    Text(loc.t(ThresholdOption.matching(tag.thresholdHours).key))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.textCaption)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.uid)
                }
                .padding(.leading, 32)
                .padding(.trailing, 20)
                .padding(.vertical, 14)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }

            Divider().overlay(Theme.dividerLight)

            Button {
                renameText = tag.label
                renameTarget = tag
            } label: {
                HStack {
                    Text(loc.t("tag.rename"))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.accent)
                    Spacer()
                    Text("›")
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.chevron)
                }
                .padding(.leading, 32)
                .padding(.trailing, 20)
                .padding(.vertical, 13)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider().overlay(Theme.dividerLight)

            Button {
                deleteTarget = tag
            } label: {
                HStack {
                    Text(loc.t("tag.deleteTag"))
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.danger)
                    Spacer()
                }
                .padding(.leading, 32)
                .padding(.trailing, 20)
                .padding(.vertical, 13)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(Theme.accordion)
        .overlay(alignment: .top) { Divider().overlay(Theme.dividerLight) }
    }

    // MARK: - タグの追加

    private var addSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(loc.t("settings.addTag"))

            Button {
                Task { await scan.scanToRegister(context: context, loc: loc) }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                        .frame(width: 22, height: 22)
                        .overlay { Circle().strokeBorder(Theme.accent, lineWidth: 1.5) }
                    Text(loc.t("settings.scanToRegister"))
                        .font(.system(size: 16))
                    Spacer()
                }
                .foregroundStyle(Theme.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .frame(minHeight: 56)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(scan.isScanning)
            .background(Theme.card)
            .overlay(alignment: .top) { Divider().overlay(Theme.divider) }
            .overlay(alignment: .bottom) { Divider().overlay(Theme.divider) }

            note(loc.t("settings.addNote"))
            note(loc.t("settings.thresholdNote"))
        }
    }

    // MARK: - 言語

    /// 追従中は解決後の言語も添える。どの言語で動いているかが行だけで分かるようにするため。
    private var languageValue: String {
        loc.selection == nil
            ? loc.t("settings.systemDefaultWith", loc.language.displayName)
            : loc.language.displayName
    }

    private var languageSection: some View {
        Menu {
            Button {
                loc.selection = nil
            } label: {
                if loc.selection == nil {
                    Label(loc.t("settings.systemDefault"), systemImage: "checkmark")
                } else {
                    Text(loc.t("settings.systemDefault"))
                }
            }
            Divider()
            ForEach(AppLanguage.allCases) { language in
                Button {
                    loc.selection = language
                } label: {
                    if loc.selection == language {
                        Label(language.displayName, systemImage: "checkmark")
                    } else {
                        Text(language.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 7) {
                Text(loc.t("settings.language"))
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.textBody)
                Spacer()
                Text(languageValue)
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.textCaption)
                    .lineLimit(1)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.uid)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .background(Theme.card)
        .overlay(alignment: .top) { Divider().overlay(Theme.divider) }
        .overlay(alignment: .bottom) { Divider().overlay(Theme.divider) }
    }

    // MARK: - このアプリについて

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionLabel(loc.t("settings.about"))

            VStack(spacing: 0) {
                aboutRow(loc.t("about.appName"), "MyNfcTapLog", mono: false)
                Divider().overlay(Theme.dividerLight)
                aboutRow(loc.t("about.supported"), "NTAG213 / NTAG215")
                Divider().overlay(Theme.dividerLight)
                aboutRow(loc.t("about.readMethod"), "UID")
                Divider().overlay(Theme.dividerLight)
                aboutRow(loc.t("about.version"), appVersion)
            }
            .background(Theme.card)
            .overlay(alignment: .top) { Divider().overlay(Theme.divider) }
            .overlay(alignment: .bottom) { Divider().overlay(Theme.divider) }

            note(loc.t("settings.uidNote"))
        }
    }

    private func aboutRow(_ title: String, _ value: String, mono: Bool = true) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 16))
                .foregroundStyle(Theme.textBody)
            Spacer()
            Text(value)
                .font(mono ? Theme.mono(13) : .system(size: 14))
                .foregroundStyle(Theme.textCaption)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .frame(minHeight: 52)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    // MARK: - 共通パーツ

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12))
            .foregroundStyle(Theme.textCaption)
            .padding(.horizontal, 20)
    }

    private func note(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11))
            .lineSpacing(5)
            .foregroundStyle(Theme.textCaption)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
    }

    private func displayName(_ tag: TagItem) -> String {
        tag.isUnnamed ? loc.t("tag.unnamed") : tag.label
    }

    // MARK: - 編集の確定

    private var renameBinding: Binding<Bool> {
        Binding(get: { renameTarget != nil }, set: { if !$0 { renameTarget = nil } })
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { deleteTarget != nil }, set: { if !$0 { deleteTarget = nil } })
    }

    /// 空のまま保存したら無名に戻す（デザインの rename.body の説明どおり）。
    private func commitRename() {
        guard let tag = renameTarget else { return }
        tag.label = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        try? context.save()
        renameTarget = nil
    }

    /// 紐づく LogEntry は TagItem のリレーションが cascade なので一緒に消える。
    private func commitDelete() {
        guard let tag = deleteTarget else { return }
        if expandedTag?.persistentModelID == tag.persistentModelID { expandedTag = nil }
        context.delete(tag)
        try? context.save()
        deleteTarget = nil
    }
}
