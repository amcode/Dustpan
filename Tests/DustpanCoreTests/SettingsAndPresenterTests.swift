import XCTest
@testable import DustpanCore

final class SettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: Settings!

    override func setUp() {
        super.setUp()
        defaults = makeTestDefaults()
        settings = Settings(defaults: defaults)
    }

    // MARK: Defaults

    func testDefaults() {
        XCTAssertTrue(settings.autoSweep)
        XCTAssertEqual(settings.autoSweepDelay, 10)
        XCTAssertTrue(settings.sweepAtLaunch)
        XCTAssertEqual(settings.hotKey, HotKey.presets[0])
    }

    func testDefaultDelayIsAnOption() {
        XCTAssertTrue(Settings.delayOptions.contains(Settings.defaultDelay))
    }

    func testDelayOptionsAscendingAndPositive() {
        XCTAssertEqual(Settings.delayOptions, Settings.delayOptions.sorted())
        XCTAssertTrue(Settings.delayOptions.allSatisfy { $0 > 0 })
    }

    // MARK: Persistence

    func testAutoSweepRoundTrips() {
        settings.autoSweep = false
        XCTAssertFalse(Settings(defaults: defaults).autoSweep)
    }

    func testDelayRoundTrips() {
        settings.autoSweepDelay = 30
        XCTAssertEqual(Settings(defaults: defaults).autoSweepDelay, 30)
    }

    func testSweepAtLaunchRoundTrips() {
        settings.sweepAtLaunch = false
        XCTAssertFalse(Settings(defaults: defaults).sweepAtLaunch)
    }

    func testHotKeyRoundTrips() {
        settings.hotKey = HotKey.presets[2]
        XCTAssertEqual(Settings(defaults: defaults).hotKey, HotKey.presets[2])
    }

    func testHotKeyNilDisablesAndPersists() {
        settings.hotKey = nil
        XCTAssertNil(settings.hotKey)
        XCTAssertNil(Settings(defaults: defaults).hotKey)
    }

    func testReenablingHotKeyRestoresPreviousChoice() {
        settings.hotKey = HotKey.presets[3]
        settings.hotKey = nil
        settings.hotKey = HotKey.presets[3]
        XCTAssertEqual(settings.hotKey, HotKey.presets[3])
    }

    // MARK: Validation

    func testZeroDelayClampedToMinimum() {
        settings.autoSweepDelay = 0
        XCTAssertGreaterThanOrEqual(settings.autoSweepDelay, 1)
    }

    func testNegativeDelayClampedToMinimum() {
        settings.autoSweepDelay = -5
        XCTAssertGreaterThanOrEqual(settings.autoSweepDelay, 1)
    }

    func testCorruptDelayFallsBackToDefault() {
        defaults.set(-1.0, forKey: Settings.Key.autoSweepDelay)
        XCTAssertEqual(settings.autoSweepDelay, Settings.defaultDelay)
    }

    func testCorruptHotKeyFallsBackToFirstPreset() {
        defaults.set(Data([0xFF]), forKey: Settings.Key.hotKey)
        XCTAssertEqual(settings.hotKey, HotKey.presets[0])
    }

    func testSuitesAreIsolated() {
        let other = Settings(defaults: makeTestDefaults("other"))
        settings.autoSweep = false
        XCTAssertTrue(other.autoSweep)
    }
}

final class HotKeyTests: XCTestCase {
    func testPresetsAreUnique() {
        let names = HotKey.presets.map(\.displayName)
        XCTAssertEqual(Set(names).count, names.count)
    }

    func testDisplayNames() {
        XCTAssertEqual(HotKey(keyCode: HotKey.keyH, modifiers: [.control, .option]).displayName, "⌃ ⌥ H")
        XCTAssertEqual(HotKey(keyCode: HotKey.keyH, modifiers: [.command, .shift]).displayName, "⇧ ⌘ H")
        XCTAssertEqual(HotKey(keyCode: HotKey.keyD, modifiers: [.control, .option]).displayName, "⌃ ⌥ D")
        XCTAssertEqual(HotKey(keyCode: HotKey.keyM, modifiers: [.control, .option]).displayName, "⌃ ⌥ M")
    }

    func testModifierOrderMatchesMacOS() {
        let hk = HotKey(keyCode: HotKey.keyH, modifiers: [.command, .shift, .option, .control])
        XCTAssertEqual(hk.displayName, "⌃ ⌥ ⇧ ⌘ H")
    }

    func testUnknownKeyCodeShowsNumber() {
        XCTAssertEqual(HotKey(keyCode: 99, modifiers: []).displayName, "Key 99")
    }

    func testSpaceName() {
        XCTAssertEqual(HotKey(keyCode: 49, modifiers: [.option]).displayName, "⌥ Space")
    }

    func testEveryPresetHasAModifier() {
        for hk in HotKey.presets { XCTAssertFalse(hk.modifiers.isEmpty, hk.displayName) }
    }

    func testCodableRoundTrip() throws {
        for hk in HotKey.presets {
            let data = try JSONEncoder().encode(hk)
            XCTAssertEqual(try JSONDecoder().decode(HotKey.self, from: data), hk)
        }
    }
}

final class MenuBarPresenterTests: XCTestCase {
    func testDividerLengths() {
        XCTAssertEqual(MenuBarPresenter.dividerLength(for: .swept), MenuBarPresenter.sweptDividerLength)
        XCTAssertEqual(MenuBarPresenter.dividerLength(for: .shown), MenuBarPresenter.shownDividerLength)
        XCTAssertGreaterThan(MenuBarPresenter.sweptDividerLength, 5000, "must exceed any screen width")
        XCTAssertLessThan(MenuBarPresenter.shownDividerLength, 40)
    }

    func testToggleSymbolsDiffer() {
        XCTAssertNotEqual(MenuBarPresenter.toggleSymbol(for: .swept), MenuBarPresenter.toggleSymbol(for: .shown))
    }

    func testDividerHasNoImageWhileSwept() {
        XCTAssertNil(MenuBarPresenter.dividerSymbol(for: .swept))
        XCTAssertNotNil(MenuBarPresenter.dividerSymbol(for: .shown))
    }

    func testTooltipsMentionAppName() {
        XCTAssertTrue(MenuBarPresenter.toggleTooltip(for: .swept).contains("Dustpan"))
        XCTAssertTrue(MenuBarPresenter.toggleTooltip(for: .shown).contains("Dustpan"))
    }

    func testTooltipsDiffer() {
        XCTAssertNotEqual(MenuBarPresenter.toggleTooltip(for: .swept), MenuBarPresenter.toggleTooltip(for: .shown))
    }

    func testDividerTooltipExplainsCommandDrag() {
        XCTAssertTrue(MenuBarPresenter.dividerTooltip().contains("⌘"))
    }

    func testStatusLines() {
        XCTAssertEqual(MenuBarPresenter.statusLine(for: .swept), "Icons swept away")
        XCTAssertEqual(MenuBarPresenter.statusLine(for: .shown), "All icons shown")
    }

    func testMenuTitlesDescribeTheAction() {
        XCTAssertEqual(MenuBarPresenter.toggleMenuTitle(for: .swept), "Show Hidden Icons")
        XCTAssertEqual(MenuBarPresenter.toggleMenuTitle(for: .shown), "Sweep Icons Away")
    }

    func testDelayLabels() {
        XCTAssertEqual(MenuBarPresenter.delayLabel(3), "3 s")
        XCTAssertEqual(MenuBarPresenter.delayLabel(10), "10 s")
        XCTAssertEqual(MenuBarPresenter.delayLabel(60), "1 min")
        XCTAssertEqual(MenuBarPresenter.delayLabel(120), "2 min")
        XCTAssertEqual(MenuBarPresenter.delayLabel(2.5), "2.5 s")
        XCTAssertEqual(MenuBarPresenter.delayLabel(90), "90 s")
    }

    func testEveryDelayOptionHasUniqueLabel() {
        let labels = Settings.delayOptions.map(MenuBarPresenter.delayLabel)
        XCTAssertEqual(Set(labels).count, labels.count)
        XCTAssertEqual(labels, ["3 s", "5 s", "10 s", "20 s", "30 s", "1 min"])
    }
}

final class TimerSchedulerTests: XCTestCase {
    func testWorkRunsAfterDelay() {
        let done = expectation(description: "fired")
        _ = TimerScheduler().schedule(after: 0.05) { done.fulfill() }
        wait(for: [done], timeout: 1)
    }

    func testCancelPreventsWork() {
        let notFired = expectation(description: "not fired")
        notFired.isInverted = true
        let token = TimerScheduler().schedule(after: 0.05) { notFired.fulfill() }
        token.cancel()
        wait(for: [notFired], timeout: 0.3)
    }

    func testWorkRunsOnlyOnce() {
        let fired = expectation(description: "fired")
        var count = 0
        _ = TimerScheduler().schedule(after: 0.05) { count += 1; fired.fulfill() }
        wait(for: [fired], timeout: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(count, 1)
    }
}
