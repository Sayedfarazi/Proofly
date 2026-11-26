import ApplicationServices

func axAttribute<T>(_ element: AXUIElement, _ attribute: String) -> T? {
    var value: AnyObject?
    let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
    guard result == .success else { return nil }
    return value as? T
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    axAttribute(element, kAXChildrenAttribute as String) ?? []
}

func axTitle(_ element: AXUIElement) -> String? {
    axAttribute(element, kAXTitleAttribute as String)
}

func axEnabled(_ element: AXUIElement) -> Bool {
    axAttribute(element, kAXEnabledAttribute as String) ?? true
}

func axCmdChar(_ element: AXUIElement) -> String? {
    axAttribute(element, kAXMenuItemCmdCharAttribute as String)
}

func axSubmenu(_ element: AXUIElement) -> AXUIElement? {
    axChildren(element).first { child in
        let role: String? = axAttribute(child, kAXRoleAttribute as String)
        return role == kAXMenuRole as String
    }
}
