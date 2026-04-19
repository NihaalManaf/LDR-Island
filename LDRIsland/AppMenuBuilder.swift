import AppKit

enum AppMenuBuilder {
    static func install(appName: String) {
        let mainMenu = NSMenu(title: appName)
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu(title: appName)

        appMenu.addItem(
            withTitle: "Quit \(appName)",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        NSApp.mainMenu = mainMenu
    }
}
