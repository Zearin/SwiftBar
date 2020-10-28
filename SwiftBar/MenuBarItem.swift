import Cocoa
import Combine

class MenubarItem {
    var plugin: Plugin?
    let barItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    let statusBarMenu = NSMenu(title: "SwiftBar Menu")
    var cancellable: AnyCancellable? = nil

    init(title: String, plugin: Plugin? = nil) {
        barItem.button?.title = title
        barItem.menu = statusBarMenu
        self.plugin = plugin
        updateMenu()
        cancellable = (plugin as? ExecutablePlugin)?.refreshPublisher
            .sink {[weak self] _ in
                DispatchQueue.main.async { [weak self] in
                    self?.updateMenu()
                }
            }
    }

    func show() {
        barItem.isVisible = true
    }

    func hide() {
        barItem.isVisible = false
    }
}

// Standard status bar menu
extension MenubarItem {
    func buildStandardMenu() {
        let firstLevel = (plugin == nil)
        let menu = firstLevel ? statusBarMenu:NSMenu(title: "Preferences")

        let refreshAllItem = NSMenuItem(title: "Refresh All", action: #selector(refreshPlugins), keyEquivalent: "r")
        let changePluginFolderItem = NSMenuItem(title: "Change Plugin Folder...", action: #selector(changePluginFolder), keyEquivalent: "")
        let openPluginFolderItem = NSMenuItem(title: "Open Plugin Folder...", action: #selector(openPluginFolder), keyEquivalent: "")
        let getPluginsItem = NSMenuItem(title: "Get Plugins...", action: #selector(getPlugins), keyEquivalent: "")
        let aboutItem = NSMenuItem(title: "About", action: #selector(about), keyEquivalent: "")
        let quitItem = NSMenuItem(title: "Quit SwiftBar", action: #selector(quit), keyEquivalent: "q")
        let runInTerminalItem = NSMenuItem(title: "Run in Terminal...", action: #selector(runInTerminal), keyEquivalent: "")
        let disablePluginItem = NSMenuItem(title: "Disable Plugin", action: #selector(disablePlugin), keyEquivalent: "")

        [refreshAllItem,changePluginFolderItem,openPluginFolderItem,getPluginsItem,quitItem,disablePluginItem,aboutItem,runInTerminalItem].forEach{$0.target = self}

        menu.addItem(refreshAllItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(changePluginFolderItem)
        menu.addItem(openPluginFolderItem)
        menu.addItem(getPluginsItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(aboutItem)
        menu.addItem(quitItem)

        if !firstLevel {
            statusBarMenu.addItem(NSMenuItem.separator())

            // put swiftbar menu as submenu
            let item = NSMenuItem(title: "SwiftBar", action: nil, keyEquivalent: "")
            item.submenu = menu
            statusBarMenu.addItem(item)

            // default plugin menu items
            statusBarMenu.addItem(NSMenuItem.separator())
            statusBarMenu.addItem(runInTerminalItem)
            statusBarMenu.addItem(disablePluginItem)
        }
    }

    @objc func refreshPlugins() {
        App.refreshPlugins()
    }

    @objc func openPluginFolder() {
        App.openPluginFolder()
    }

    @objc func changePluginFolder() {
        App.changePluginFolder()
    }

    @objc func getPlugins() {
        App.getPlugins()
    }

    @objc func quit() {
        NSApp.terminate(self)
    }

    @objc func runInTerminal() {
        plugin?.refresh()
    }

    @objc func disablePlugin() {
        guard let plugin = plugin else {return}
        PluginManager.shared.disablePlugin(plugin: plugin)
    }

    @objc func about() {
        if let plugin = plugin {
            print(plugin.description)
        }
    }
}


extension MenubarItem {
    static func defaultBarItem() -> MenubarItem {
        let item = MenubarItem(title: "SwiftBar")
        return item
    }
}

//parse script output
extension MenubarItem {
    func splitScriptOutput(scriptOutput: String) -> (header: [String], body: [String]){
        guard let index = scriptOutput.range(of: "---") else {
            return (scriptOutput.components(separatedBy: CharacterSet.newlines).filter{!$0.isEmpty},[])
        }
        let header = String(scriptOutput[...index.lowerBound])
            .components(separatedBy: CharacterSet.newlines)
            .dropLast()
            .filter{!$0.isEmpty}
        let body = String(scriptOutput[index.upperBound...])
            .components(separatedBy: CharacterSet.newlines)
            .dropFirst()
            .filter{!$0.isEmpty}
        return (header,body)
    }

    func updateMenu() {
        statusBarMenu.removeAllItems()
        guard let scriptOutput = plugin?.content, scriptOutput.count > 0 else {
            barItem.button?.title = "⚠️"
            buildStandardMenu()
            return
        }
        let parts = splitScriptOutput(scriptOutput: scriptOutput)
        updateMenuTitle(titleLines: parts.header)

        if !parts.body.isEmpty {
            statusBarMenu.addItem(NSMenuItem.separator())
        }

        parts.body.forEach { line in
            addMenuItem(from: line)
        }
        buildStandardMenu()
    }

    func addMenuItem(from line: String) {
        if let item = buildMenuItem(params: MenuLineParameters(line: line)) {
            item.target = self
            statusBarMenu.addItem(item)
        }
    }

    func updateMenuTitle(titleLines: [String]) {
        barItem.button?.title = titleLines.first ?? "⚠️"
        guard titleLines.count > 1 else {return}

        titleLines.forEach{ line in
            addMenuItem(from: line)
        }
    }

    func buildMenuItem(params: MenuLineParameters) -> NSMenuItem? {
        guard params.dropdown else {return nil}
        var title = params.title
        if params.trim {
            title = title.trimmingCharacters(in: .whitespaces)
        }
        return NSMenuItem(title: title,
                          action: params.href != nil ? #selector(performMenuItemHREFAction):
                          params.bash != nil ? #selector(performMenuItemBashAction):
                          params.refresh ? #selector(performMenuItemRefreshAction): nil,
                          keyEquivalent: "")
    }

    @objc func performMenuItemHREFAction() {

    }

    @objc func performMenuItemBashAction() {

    }

    @objc func performMenuItemRefreshAction() {

    }

}