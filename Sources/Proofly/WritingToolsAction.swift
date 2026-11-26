import Carbon.HIToolbox

enum WritingToolsAction: String, CaseIterable {
    case proofread
    case rewrite

    var displayName: String {
        switch self {
        case .proofread: return "Proofread"
        case .rewrite: return "Rewrite"
        }
    }

    var titles: Set<String> {
        switch self {
        case .proofread: return MenuLocaleTable.proofreadTitles
        case .rewrite: return MenuLocaleTable.rewriteTitles
        }
    }

    var defaultCombo: KeyCombo {
        switch self {
        case .proofread:
            return KeyCombo(keyCode: UInt32(kVK_ANSI_P), carbonModifiers: UInt32(cmdKey | optionKey | controlKey))
        case .rewrite:
            return KeyCombo(keyCode: UInt32(kVK_ANSI_R), carbonModifiers: UInt32(cmdKey | optionKey | controlKey))
        }
    }
}
