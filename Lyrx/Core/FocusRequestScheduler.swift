import Foundation

/// Defers native focus until after view updates. Failed attempts stay pending in the owning model;
/// attachment or a later update can try again without replaying an accepted request.
@MainActor
final class FocusRequestScheduler {
    private var scheduledID: UUID?
    private var operation: Task<Void, Never>?

    isolated deinit { operation?.cancel() }

    @discardableResult
    func schedule(
        _ requestID: UUID?, isAttached: Bool,
        attempt: @escaping @MainActor () -> Bool,
        accepted: @escaping @MainActor () -> Void
    ) -> Task<Void, Never>? {
        guard let requestID, isAttached else {
            cancel()
            return nil
        }
        if scheduledID == requestID { return operation }
        cancel()
        scheduledID = requestID
        let task = Task { [weak self] in
            await Task.yield()
            guard !Task.isCancelled, let self else { return }
            // Clear before entering native callbacks, which can synchronously change focus state.
            self.scheduledID = nil
            self.operation = nil
            if attempt() { accepted() }
        }
        operation = task
        return task
    }

    func cancel() {
        operation?.cancel()
        operation = nil
        scheduledID = nil
    }
}
