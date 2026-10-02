import Foundation

/// The whole app in one object: are the extra icons swept away or shown, and when do they
/// get swept again automatically?
public final class Sweeper {
    public enum State: Equatable {
        case swept       // icons left of the divider are pushed off-screen
        case shown       // everything visible
    }

    private let settings: Settings
    private let scheduler: Scheduling
    private var autoSweep: Cancellable?
    public private(set) var state: State

    /// Called whenever the state changes.
    public var onStateChange: ((State) -> Void)?

    public init(settings: Settings, scheduler: Scheduling) {
        self.settings = settings
        self.scheduler = scheduler
        state = settings.sweepAtLaunch ? .swept : .shown
    }

    public var isSwept: Bool { state == .swept }

    /// Hide the icons.
    public func sweep() {
        cancelAutoSweep()
        set(.swept)
    }

    /// Show the icons. If auto-sweep is on, they get swept again after the configured delay.
    public func show() {
        set(.shown)
        scheduleAutoSweep()
    }

    public func toggle() {
        isSwept ? show() : sweep()
    }

    /// Call when the user interacts with the shown icons: restarts the auto-sweep countdown.
    public func touch() {
        guard state == .shown else { return }
        scheduleAutoSweep()
    }

    /// Call when auto-sweep settings change so a running countdown reflects them.
    public func settingsDidChange() {
        guard state == .shown else { return }
        scheduleAutoSweep()
    }

    // MARK: - Private

    private func set(_ new: State) {
        guard new != state else { return }
        state = new
        onStateChange?(new)
    }

    private func scheduleAutoSweep() {
        cancelAutoSweep()
        guard settings.autoSweep else { return }
        autoSweep = scheduler.schedule(after: settings.autoSweepDelay) { [weak self] in
            self?.autoSweep = nil
            self?.sweep()
        }
    }

    private func cancelAutoSweep() {
        autoSweep?.cancel()
        autoSweep = nil
    }
}
