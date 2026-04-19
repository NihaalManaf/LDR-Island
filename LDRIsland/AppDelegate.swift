import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var islandWindowController: IslandWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = AppConfiguration.current

        NSApp.setActivationPolicy(configuration.showsDockIcon ? .regular : .accessory)
        AppMenuBuilder.install(appName: "LDRIsland")

        let controller = IslandWindowController(configuration: configuration)
        islandWindowController = controller
        controller.show()

        if configuration.showsDockIcon {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
