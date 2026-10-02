import Foundation

/// Pure presentation logic for the two menu bar items. No AppKit, so it's unit-testable.
public enum MenuBarPresenter {
    public static let appName = "Dustpan"

    /// The divider item: this wide pushes everything left of it off the screen.
    public static let sweptDividerLength: Double = 10_000
    /// The divider when icons are shown: a thin visible line.
    public static let shownDividerLength: Double = 18

    public static func dividerLength(for state: Sweeper.State) -> Double {
        state == .swept ? sweptDividerLength : shownDividerLength
    }

    /// SF Symbol on the always-visible toggle button.
    public static func toggleSymbol(for state: Sweeper.State) -> String {
        state == .swept ? "chevron.compact.left" : "chevron.compact.right"
    }

    /// SF Symbol on the divider while shown (nil = no image while swept).
    public static func dividerSymbol(for state: Sweeper.State) -> String? {
        state == .swept ? nil : "poweron"
    }

    public static func toggleTooltip(for state: Sweeper.State) -> String {
        state == .swept ? "\(appName): click to show hidden icons" : "\(appName): click to sweep icons away"
    }

    public static func dividerTooltip() -> String {
        "⌘-drag menu bar icons to the left of this line to hide them"
    }

    public static func statusLine(for state: Sweeper.State) -> String {
        state == .swept ? "Icons swept away" : "All icons shown"
    }

    public static func toggleMenuTitle(for state: Sweeper.State) -> String {
        state == .swept ? "Show Hidden Icons" : "Sweep Icons Away"
    }

    /// "3 s", "10 s", "1 min".
    public static func delayLabel(_ seconds: TimeInterval) -> String {
        if seconds >= 60, seconds.truncatingRemainder(dividingBy: 60) == 0 {
            let m = Int(seconds / 60)
            return m == 1 ? "1 min" : "\(m) min"
        }
        return seconds == seconds.rounded(.towardZero)
            ? String(format: "%.0f s", seconds)
            : String(format: "%.1f s", seconds)
    }
}
