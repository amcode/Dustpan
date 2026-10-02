import Foundation
import XCTest
@testable import DustpanCore

/// A scheduler tests can advance by hand.
final class ManualScheduler: Scheduling {
    final class Job: Cancellable {
        let delay: TimeInterval
        let fireAt: Date
        let work: () -> Void
        private(set) var isCancelled = false
        private(set) var fired = false
        init(delay: TimeInterval, fireAt: Date, work: @escaping () -> Void) {
            self.delay = delay; self.fireAt = fireAt; self.work = work
        }
        func cancel() { isCancelled = true }
        func fire() {
            guard !isCancelled, !fired else { return }
            fired = true
            work()
        }
    }

    var currentTime = Date(timeIntervalSince1970: 1_700_000_000)
    private(set) var jobs: [Job] = []
    var pendingJobs: [Job] { jobs.filter { !$0.isCancelled && !$0.fired } }

    func schedule(after seconds: TimeInterval, _ work: @escaping () -> Void) -> Cancellable {
        let job = Job(delay: seconds, fireAt: currentTime.addingTimeInterval(seconds), work: work)
        jobs.append(job)
        return job
    }

    func now() -> Date { currentTime }

    func advance(by seconds: TimeInterval) {
        let target = currentTime.addingTimeInterval(seconds)
        for job in pendingJobs.sorted(by: { $0.fireAt < $1.fireAt }) where job.fireAt <= target {
            currentTime = job.fireAt
            job.fire()
        }
        currentTime = target
    }
}

func makeTestDefaults(_ name: String = #function) -> UserDefaults {
    let suite = "DustpanTests.\(name).\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}
