import AppKit
import ServiceManagement
import DustpanCore

/// Two status items: a divider and a toggle. Icons the user ⌘-drags to the left of the divider
/// are pushed off-screen when the divider is made enormously wide. No permissions needed.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var toggleItem: NSStatusItem!
    private var dividerItem: NSStatusItem!
    private let settings = Settings()
    private lazy var sweeper = Sweeper(settings: settings, scheduler: TimerScheduler())
    private let hotKey = HotKeyRegistrar()

    private static let toggleAutosave = "dustpan.toggle"
    private static let dividerAutosave = "dustpan.divider"

    // MARK: Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.ensureItemOrder()

        // Created first → sits rightmost. The divider is created second → to its left.
        toggleItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        toggleItem.autosaveName = Self.toggleAutosave
        toggleItem.button?.target = self
        toggleItem.button?.action = #selector(toggleClicked)
        toggleItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        dividerItem = NSStatusBar.system.statusItem(withLength: MenuBarPresenter.shownDividerLength)
        dividerItem.autosaveName = Self.dividerAutosave
        dividerItem.button?.target = self
        dividerItem.button?.action = #selector(dividerClicked)
        dividerItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        sweeper.onStateChange = { [weak self] _ in self?.render() }
        render()
        registerHotKey()
    }

    // MARK: Rendering

    private func render() {
        let state = sweeper.state

        let toggleImage = NSImage(systemSymbolName: MenuBarPresenter.toggleSymbol(for: state),
                                  accessibilityDescription: MenuBarPresenter.toggleTooltip(for: state))
        toggleImage?.isTemplate = true
        toggleItem.button?.image = toggleImage
        toggleItem.button?.toolTip = MenuBarPresenter.toggleTooltip(for: state)

        dividerItem.length = MenuBarPresenter.dividerLength(for: state)
        if let symbol = MenuBarPresenter.dividerSymbol(for: state) {
            let img = NSImage(systemSymbolName: symbol, accessibilityDescription: "divider")
            img?.isTemplate = true
            dividerItem.button?.image = img
            dividerItem.button?.appearsDisabled = true
        } else {
            dividerItem.button?.image = nil
        }
        dividerItem.button?.toolTip = MenuBarPresenter.dividerTooltip()
    }

    // MARK: Clicks — left toggles, right opens the menu

    @objc private func toggleClicked() {
        if isRightClick() { showMenu(on: toggleItem) } else { sweeper.toggle() }
    }

    @objc private func dividerClicked() {
        if isRightClick() { showMenu(on: dividerItem) } else { sweeper.sweep() }
    }

    private func isRightClick() -> Bool {
        guard let e = NSApp.currentEvent else { return false }
        return e.type == .rightMouseUp || e.modifierFlags.contains(.control)
    }

    private func showMenu(on item: NSStatusItem) {
        item.menu = buildMenu()
        item.button?.performClick(nil)
        item.menu = nil
    }

    // MARK: Hot key

    private func registerHotKey() {
        if let hk = settings.hotKey {
            hotKey.register(hk) { [weak self] in self?.sweeper.toggle() }
        } else {
            hotKey.unregister()
        }
    }

    // MARK: Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let status = NSMenuItem(title: MenuBarPresenter.statusLine(for: sweeper.state), action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        let help = NSMenuItem(title: "⌘-drag icons left of the divider to hide them", action: nil, keyEquivalent: "")
        help.isEnabled = false
        menu.addItem(help)
        menu.addItem(.separator())

        let toggle = NSMenuItem(title: MenuBarPresenter.toggleMenuTitle(for: sweeper.state),
                                action: #selector(menuToggle), keyEquivalent: "")
        toggle.target = self
        menu.addItem(toggle)
        menu.addItem(.separator())

        let auto = NSMenuItem(title: "Sweep away automatically", action: #selector(toggleAutoSweep), keyEquivalent: "")
        auto.target = self
        auto.state = settings.autoSweep ? .on : .off
        menu.addItem(auto)

        let delayMenu = NSMenu()
        for d in Settings.delayOptions {
            let item = NSMenuItem(title: MenuBarPresenter.delayLabel(d), action: #selector(setDelay(_:)), keyEquivalent: "")
            item.representedObject = d
            item.target = self
            item.state = d == settings.autoSweepDelay ? .on : .off
            delayMenu.addItem(item)
        }
        let delayItem = NSMenuItem(title: "After", action: nil, keyEquivalent: "")
        delayItem.submenu = delayMenu
        delayItem.isEnabled = settings.autoSweep
        menu.addItem(delayItem)

        let launch = NSMenuItem(title: "Sweep at launch", action: #selector(toggleSweepAtLaunch), keyEquivalent: "")
        launch.target = self
        launch.state = settings.sweepAtLaunch ? .on : .off
        menu.addItem(launch)

        let keyMenu = NSMenu()
        for hk in HotKey.presets {
            let item = NSMenuItem(title: hk.displayName, action: #selector(setHotKey(_:)), keyEquivalent: "")
            item.representedObject = try? JSONEncoder().encode(hk)
            item.target = self
            item.state = hk == settings.hotKey ? .on : .off
            keyMenu.addItem(item)
        }
        keyMenu.addItem(.separator())
        let none = NSMenuItem(title: "None", action: #selector(clearHotKey), keyEquivalent: "")
        none.target = self
        none.state = settings.hotKey == nil ? .on : .off
        keyMenu.addItem(none)
        let keyItem = NSMenuItem(title: "Shortcut", action: nil, keyEquivalent: "")
        keyItem.submenu = keyMenu
        menu.addItem(keyItem)

        let login = NSMenuItem(title: "Launch at login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        login.target = self
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(login)

        menu.addItem(.separator())
        let about = NSMenuItem(title: "About Dustpan", action: #selector(showAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)
        menu.addItem(NSMenuItem(title: "Quit Dustpan", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    // MARK: Actions

    @objc private func menuToggle() { sweeper.toggle() }

    @objc private func toggleAutoSweep() {
        settings.autoSweep.toggle()
        sweeper.settingsDidChange()
    }

    @objc private func setDelay(_ sender: NSMenuItem) {
        if let d = sender.representedObject as? TimeInterval { settings.autoSweepDelay = d }
        sweeper.settingsDidChange()
    }

    @objc private func toggleSweepAtLaunch() { settings.sweepAtLaunch.toggle() }

    @objc private func setHotKey(_ sender: NSMenuItem) {
        guard let data = sender.representedObject as? Data,
              let hk = try? JSONDecoder().decode(HotKey.self, from: data) else { return }
        settings.hotKey = hk
        registerHotKey()
    }

    @objc private func clearHotKey() {
        settings.hotKey = nil
        registerHotKey()
    }

    @objc private func toggleLaunchAtLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login failed: \(error)")
        }
    }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Dustpan"
        alert.informativeText = "Sweeps menu bar icons out of sight.\n\n⌘-drag any icon to the left of the divider to hide it. Click the chevron (or press \(settings.hotKey?.displayName ?? "the shortcut")) to show or sweep."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: Item ordering

    /// macOS remembers each item's position under "NSStatusItem Preferred Position <autosaveName>"
    /// (distance from the right edge). The divider must stay left of the toggle, or nothing
    /// could be hidden; if a drag ever put them the wrong way round, put them back before creating.
    private static func ensureItemOrder() {
        let d = UserDefaults.standard
        let toggleKey = "NSStatusItem Preferred Position \(toggleAutosave)"
        let dividerKey = "NSStatusItem Preferred Position \(dividerAutosave)"
        guard let toggle = d.object(forKey: toggleKey) as? Double,
              let divider = d.object(forKey: dividerKey) as? Double else { return }
        if divider <= toggle {
            d.set(toggle + 24, forKey: dividerKey)
        }
    }
}
