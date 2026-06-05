import Foundation

@MainActor
final class AppSettings: ObservableObject {
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: Keys.language)
        }
    }

    @Published var defaultMode: EditorMode {
        didSet {
            defaults.set(defaultMode.rawValue, forKey: Keys.defaultMode)
        }
    }

    @Published var showsOutlineByDefault: Bool {
        didSet {
            defaults.set(showsOutlineByDefault, forKey: Keys.showsOutlineByDefault)
        }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let languageValue = defaults.string(forKey: Keys.language) ?? AppLanguage.system.rawValue
        language = AppLanguage(rawValue: languageValue) ?? .system

        let modeValue = defaults.string(forKey: Keys.defaultMode) ?? EditorMode.write.rawValue
        defaultMode = EditorMode(rawValue: modeValue) ?? .write

        if defaults.object(forKey: Keys.showsOutlineByDefault) == nil {
            showsOutlineByDefault = true
        } else {
            showsOutlineByDefault = defaults.bool(forKey: Keys.showsOutlineByDefault)
        }
    }

    var effectiveLanguage: AppLanguage {
        if language != .system {
            return language
        }

        let preferred = Locale.preferredLanguages.first?.lowercased() ?? ""
        return preferred.hasPrefix("zh") ? .zhHans : .english
    }

    func text(_ key: L10nKey) -> String {
        L10n.text(key, language: effectiveLanguage)
    }
}

private enum Keys {
    static let language = "MD2.Language"
    static let defaultMode = "MD2.DefaultMode"
    static let showsOutlineByDefault = "MD2.ShowsOutlineByDefault"
}

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case english
    case zhHans

    var id: String {
        rawValue
    }
}

enum L10nKey: String {
    case new
    case open
    case save
    case saveAs
    case outline
    case noHeadings
    case hideOutline
    case showOutline
    case mode
    case write
    case read
    case writeOrRead
    case words
    case chars
    case lines
    case minRead
    case ok
    case settingsTitle
    case language
    case followSystem
    case english
    case chineseSimplified
    case defaultOpenMode
    case showOutlineByDefault
    case general
    case preferences
    case unsavedChangesTitle
    case unsavedChangesMessage
    case cancel
    case dontSave
}

enum L10n {
    static func text(_ key: L10nKey, language: AppLanguage) -> String {
        switch language {
        case .zhHans:
            zhHans[key] ?? english[key] ?? key.rawValue
        case .system, .english:
            english[key] ?? key.rawValue
        }
    }

    private static let english: [L10nKey: String] = [
        .new: "New",
        .open: "Open...",
        .save: "Save",
        .saveAs: "Save As...",
        .outline: "Outline",
        .noHeadings: "No headings",
        .hideOutline: "Hide outline",
        .showOutline: "Show outline",
        .mode: "Mode",
        .write: "Edit",
        .read: "Preview",
        .writeOrRead: "Edit or preview",
        .words: "words",
        .chars: "chars",
        .lines: "lines",
        .minRead: "min read",
        .ok: "OK",
        .settingsTitle: "Markdown2 Settings",
        .language: "Language",
        .followSystem: "Follow System",
        .english: "English",
        .chineseSimplified: "Simplified Chinese",
        .defaultOpenMode: "Default Open Mode",
        .showOutlineByDefault: "Show Outline by Default",
        .general: "General",
        .preferences: "Settings",
        .unsavedChangesTitle: "Save changes before closing?",
        .unsavedChangesMessage: "This document has unsaved changes.",
        .cancel: "Cancel",
        .dontSave: "Don't Save"
    ]

    private static let zhHans: [L10nKey: String] = [
        .new: "新建",
        .open: "打开...",
        .save: "保存",
        .saveAs: "另存为...",
        .outline: "大纲",
        .noHeadings: "没有标题",
        .hideOutline: "隐藏大纲",
        .showOutline: "显示大纲",
        .mode: "模式",
        .write: "编辑",
        .read: "预览",
        .writeOrRead: "编辑或预览",
        .words: "词",
        .chars: "字符",
        .lines: "行",
        .minRead: "分钟阅读",
        .ok: "好",
        .settingsTitle: "Markdown2 设置",
        .language: "语言",
        .followSystem: "跟随系统",
        .english: "英语",
        .chineseSimplified: "简体中文",
        .defaultOpenMode: "默认打开模式",
        .showOutlineByDefault: "默认显示大纲",
        .general: "通用",
        .preferences: "设置",
        .unsavedChangesTitle: "关闭前保存更改？",
        .unsavedChangesMessage: "当前文档还有未保存的更改。",
        .cancel: "取消",
        .dontSave: "不保存"
    ]
}
