import Foundation
import Testing

@testable import LyrxCore

/// A native view can detach or refuse focus between scheduling and the actual attempt.
@MainActor private final class FocusTarget {
    var pending: UUID? = UUID()
    var attached = false
    var acceptsFocus = false
    var attempts: [UUID] = []
    var accepted: [UUID] = []

    @discardableResult
    func update(_ scheduler: FocusRequestScheduler) -> Task<Void, Never>? {
        let request = pending
        return scheduler.schedule(request, isAttached: attached) {
            guard let request, self.attached, self.pending == request else { return false }
            self.attempts.append(request)
            return self.acceptsFocus
        } accepted: {
            guard let request, self.pending == request else { return }
            self.pending = nil
            self.accepted.append(request)
        }
    }
}

@MainActor struct FocusRequestTests {
    @Test func attachmentAndRefusedFocusKeepTheRequestPendingUntilAccepted() async {
        let scheduler = FocusRequestScheduler()
        let target = FocusTarget()
        let request = target.pending
        #expect(target.update(scheduler) == nil)
        #expect(target.pending == request)
        target.attached = true
        await target.update(scheduler)?.value
        #expect(target.pending == request)
        #expect(target.accepted.isEmpty)
        target.acceptsFocus = true
        await target.update(scheduler)?.value
        #expect(target.pending == nil)
        #expect(target.accepted == [request!])
        #expect(target.update(scheduler) == nil)
        #expect(target.attempts.count == 2)
    }

    @Test func onlyTheLatestRequestCanTakeFocus() async {
        let scheduler = FocusRequestScheduler()
        let target = FocusTarget()
        target.attached = true
        target.acceptsFocus = true
        let old = target.update(scheduler)
        target.pending = UUID()
        let newestID = target.pending!
        let newest = target.update(scheduler)
        // A redraw during the scheduled attempt must not create another attempt.
        let redraw = target.update(scheduler)
        await old?.value
        await newest?.value
        await redraw?.value
        #expect(target.attempts == [newestID])
        #expect(target.accepted == [newestID])
    }

    @Test func detachingBeforeTheAttemptDoesNotConsumeFocus() async {
        let scheduler = FocusRequestScheduler()
        let target = FocusTarget()
        target.attached = true
        target.acceptsFocus = true
        let operation = target.update(scheduler)
        target.attached = false
        await operation?.value
        #expect(target.pending != nil)
        #expect(target.accepted.isEmpty)
        target.attached = true
        await target.update(scheduler)?.value
        #expect(target.accepted.count == 1)
    }

    @Test func cancellationPreventsFocusWithoutCancellingTheReplacement() async {
        let scheduler = FocusRequestScheduler()
        let target = FocusTarget()
        target.attached = true
        target.acceptsFocus = true
        let cancelled = target.update(scheduler)
        scheduler.cancel()
        let replacement = target.update(scheduler)
        await cancelled?.value
        await replacement?.value
        #expect(target.attempts.count == 1)
        #expect(target.accepted.count == 1)
    }

    @Test func teardownCancelsTheScheduledAttempt() async {
        var scheduler: FocusRequestScheduler? = FocusRequestScheduler()
        weak var released = scheduler
        let target = FocusTarget()
        target.attached = true
        target.acceptsFocus = true
        let operation = target.update(scheduler!)
        scheduler = nil
        await operation?.value
        #expect(released == nil)
        #expect(target.attempts.isEmpty)
        #expect(target.pending != nil)
    }
}
