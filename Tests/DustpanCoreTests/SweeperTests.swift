import XCTest
@testable import DustpanCore

final class SweeperTests: XCTestCase {
    private var defaults: UserDefaults!
    private var settings: Settings!
    private var scheduler: ManualScheduler!
    private var sweeper: Sweeper!
    private var changes: [Sweeper.State] = []

    override func setUp() {
        super.setUp()
        defaults = makeTestDefaults()
        settings = Settings(defaults: defaults)
        scheduler = ManualScheduler()
        changes = []
    }

    private func make() {
        sweeper = Sweeper(settings: settings, scheduler: scheduler)
        sweeper.onStateChange = { [weak self] in self?.changes.append($0) }
    }

    // MARK: Initial state

    func testStartsSweptByDefault() {
        make()
        XCTAssertEqual(sweeper.state, .swept)
        XCTAssertTrue(sweeper.isSwept)
    }

    func testStartsShownWhenSweepAtLaunchOff() {
        settings.sweepAtLaunch = false
        make()
        XCTAssertEqual(sweeper.state, .shown)
    }

    func testInitialStateDoesNotEmit() {
        make()
        XCTAssertTrue(changes.isEmpty)
    }

    func testStartingShownDoesNotStartAutoSweep() {
        settings.sweepAtLaunch = false
        make()
        XCTAssertTrue(scheduler.jobs.isEmpty)
    }

    // MARK: Show

    func testShowChangesStateAndEmits() {
        make()
        sweeper.show()
        XCTAssertEqual(sweeper.state, .shown)
        XCTAssertEqual(changes, [.shown])
    }

    func testShowSchedulesAutoSweepWithConfiguredDelay() {
        settings.autoSweepDelay = 20
        make()
        sweeper.show()
        XCTAssertEqual(scheduler.pendingJobs.count, 1)
        XCTAssertEqual(scheduler.pendingJobs.first?.delay, 20)
    }

    func testAutoSweepFires() {
        make()
        sweeper.show()
        scheduler.advance(by: Settings.defaultDelay)
        XCTAssertEqual(sweeper.state, .swept)
        XCTAssertEqual(changes, [.shown, .swept])
    }

    func testNotSweptBeforeDelay() {
        make()
        sweeper.show()
        scheduler.advance(by: Settings.defaultDelay - 0.5)
        XCTAssertEqual(sweeper.state, .shown)
    }

    func testShowWithAutoSweepOffSchedulesNothing() {
        settings.autoSweep = false
        make()
        sweeper.show()
        XCTAssertTrue(scheduler.jobs.isEmpty)
        scheduler.advance(by: 3600)
        XCTAssertEqual(sweeper.state, .shown)
    }

    func testShowTwiceEmitsOnceButRestartsCountdown() {
        make()
        sweeper.show()
        let first = scheduler.pendingJobs.first
        scheduler.advance(by: 5)
        sweeper.show()
        XCTAssertEqual(changes, [.shown])
        XCTAssertTrue(first?.isCancelled ?? false)
        XCTAssertEqual(scheduler.pendingJobs.count, 1)
        scheduler.advance(by: 6)   // 11s since first show, 6s since second
        XCTAssertEqual(sweeper.state, .shown)
        scheduler.advance(by: 4)
        XCTAssertEqual(sweeper.state, .swept)
    }

    // MARK: Sweep

    func testSweepChangesStateAndEmits() {
        settings.sweepAtLaunch = false
        make()
        sweeper.sweep()
        XCTAssertEqual(sweeper.state, .swept)
        XCTAssertEqual(changes, [.swept])
    }

    func testSweepWhenAlreadySweptDoesNotEmit() {
        make()
        sweeper.sweep()
        XCTAssertTrue(changes.isEmpty)
    }

    func testManualSweepCancelsAutoSweep() {
        make()
        sweeper.show()
        sweeper.sweep()
        XCTAssertTrue(scheduler.pendingJobs.isEmpty)
        scheduler.advance(by: 100)
        XCTAssertEqual(changes, [.shown, .swept], "the cancelled timer must not emit again")
    }

    // MARK: Toggle

    func testToggleFromSweptShows() {
        make()
        sweeper.toggle()
        XCTAssertEqual(sweeper.state, .shown)
        XCTAssertEqual(scheduler.pendingJobs.count, 1)
    }

    func testToggleFromShownSweeps() {
        make()
        sweeper.show()
        sweeper.toggle()
        XCTAssertEqual(sweeper.state, .swept)
        XCTAssertTrue(scheduler.pendingJobs.isEmpty)
    }

    func testToggleTwiceReturnsToStart() {
        make()
        sweeper.toggle(); sweeper.toggle()
        XCTAssertEqual(sweeper.state, .swept)
        XCTAssertEqual(changes, [.shown, .swept])
    }

    // MARK: Touch (user activity extends the countdown)

    func testTouchRestartsCountdown() {
        make()
        sweeper.show()
        scheduler.advance(by: 8)
        sweeper.touch()
        scheduler.advance(by: 8)
        XCTAssertEqual(sweeper.state, .shown)
        scheduler.advance(by: 2)
        XCTAssertEqual(sweeper.state, .swept)
    }

    func testTouchWhileSweptDoesNothing() {
        make()
        sweeper.touch()
        XCTAssertTrue(scheduler.jobs.isEmpty)
        XCTAssertEqual(sweeper.state, .swept)
    }

    func testTouchWithAutoSweepOffDoesNothing() {
        settings.autoSweep = false
        make()
        sweeper.show()
        sweeper.touch()
        XCTAssertTrue(scheduler.jobs.isEmpty)
    }

    // MARK: Settings changes

    func testTurningAutoSweepOffWhileShownCancelsCountdown() {
        make()
        sweeper.show()
        settings.autoSweep = false
        sweeper.settingsDidChange()
        XCTAssertTrue(scheduler.pendingJobs.isEmpty)
        scheduler.advance(by: 3600)
        XCTAssertEqual(sweeper.state, .shown)
    }

    func testTurningAutoSweepOnWhileShownStartsCountdown() {
        settings.autoSweep = false
        make()
        sweeper.show()
        settings.autoSweep = true
        sweeper.settingsDidChange()
        XCTAssertEqual(scheduler.pendingJobs.count, 1)
    }

    func testChangingDelayWhileShownReschedules() {
        make()
        sweeper.show()
        settings.autoSweepDelay = 3
        sweeper.settingsDidChange()
        XCTAssertEqual(scheduler.pendingJobs.first?.delay, 3)
        scheduler.advance(by: 3)
        XCTAssertEqual(sweeper.state, .swept)
    }

    func testSettingsChangeWhileSweptDoesNothing() {
        make()
        sweeper.settingsDidChange()
        XCTAssertTrue(scheduler.jobs.isEmpty)
    }

    // MARK: Memory

    func testTimerClosureDoesNotRetainSweeper() {
        weak var weakSweeper: Sweeper?
        autoreleasepool {
            let s = Sweeper(settings: settings, scheduler: scheduler)
            weakSweeper = s
            s.show()
        }
        XCTAssertNil(weakSweeper)
        scheduler.advance(by: 100)   // must not crash
    }

    // MARK: Every delay option works end to end

    func testEveryDelayOptionSweepsOnTime() {
        for d in Settings.delayOptions {
            let s = ManualScheduler()
            let st = Settings(defaults: makeTestDefaults("delay\(d)"))
            st.autoSweepDelay = d
            let sw = Sweeper(settings: st, scheduler: s)
            sw.show()
            s.advance(by: d - 0.01)
            XCTAssertEqual(sw.state, .shown, "\(d)")
            s.advance(by: 0.01)
            XCTAssertEqual(sw.state, .swept, "\(d)")
        }
    }
}
