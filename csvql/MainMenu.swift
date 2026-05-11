import Cocoa

enum MainMenu {

    static func make() -> NSMenu {
        let mainMenu = NSMenu()
        mainMenu.addItem(makeAppMenuItem())
        mainMenu.addItem(makeEditMenuItem())
        mainMenu.addItem(makeViewMenuItem())
        return mainMenu
    }

    private static func makeAppMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "csvql", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "csvql")
        submenu.autoenablesItems = false

        let quit = NSMenuItem(
            title: "Quit",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        quit.target = NSApp
        submenu.addItem(quit)

        item.submenu = submenu
        return item
    }

    private static func makeEditMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Edit", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "Edit")

        let copy = NSMenuItem(
            title: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        submenu.addItem(copy)

        let selectAll = NSMenuItem(
            title: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        submenu.addItem(selectAll)

        item.submenu = submenu
        return item
    }

    private static func makeViewMenuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "View", action: nil, keyEquivalent: "")
        let submenu = NSMenu(title: "View")

        let compact = NSMenuItem(
            title: "Compact",
            action: #selector(DocumentWindowController.setCompact(_:)),
            keyEquivalent: "1"
        )
        submenu.addItem(compact)

        let regular = NSMenuItem(
            title: "Regular",
            action: #selector(DocumentWindowController.setRegular(_:)),
            keyEquivalent: "2"
        )
        submenu.addItem(regular)

        let comfortable = NSMenuItem(
            title: "Comfortable",
            action: #selector(DocumentWindowController.setComfortable(_:)),
            keyEquivalent: "3"
        )
        submenu.addItem(comfortable)

        item.submenu = submenu
        return item
    }
}
