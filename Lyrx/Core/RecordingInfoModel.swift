import Foundation
import Observation

/// Per-window recording details. Only metadata is cached, and only until the next search.
@MainActor @Observable
final class RecordingInfoModel {
    var isPresented = false
    private(set) var match: LyricMatch?
    private(set) var isLoading = false
    private(set) var error: String?
    private var cache: [LyricMatch.ID: LyricMatch] = [:]
    @ObservationIgnored private let service: any LyricSearching
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()

    init(service: any LyricSearching) { self.service = service }

    isolated deinit { operation?.cancel() }

    /// Returning the owned operation lets callers await this request even after it is replaced.
    @discardableResult
    func open(_ requested: LyricMatch, access: ProviderAccess) -> Task<Void, Never>? {
        cancel()
        var record = enriched(requested)
        record.lyrics = nil
        match = record
        isPresented = true
        error = nil
        guard !record.detailsComplete else { return nil }
        guard access.searchable.contains(record.provider) else {
            error = LyricServiceError.providerNotConfigured.localizedDescription
            return nil
        }
        isLoading = true
        let token = generation
        let snapshot = record
        let task = Task { [weak self, service] in
            do {
                var details = try await service.details(for: snapshot, access: access)
                guard let self, self.generation == token, !Task.isCancelled else { return }
                details.lyrics = nil
                self.match = details
                self.cache[details.id] = details
                self.isLoading = false
            } catch {
                guard let self, self.generation == token, !Task.isCancelled else { return }
                self.error = ProviderClient.message(for: error)
                self.isLoading = false
            }
        }
        operation = task
        return task
    }

    /// Keep the reader's identity and lyric text while sharing any fetched credits.
    func enriched(_ original: LyricMatch) -> LyricMatch {
        guard let details = cache[original.id] else { return original }
        var result = original
        result.metadata = details.metadata
        result.detailsComplete = details.detailsComplete
        return result
    }

    func cancel() {
        operation?.cancel()
        operation = nil
        generation = UUID()
        isLoading = false
    }

    func close() {
        cancel()
        isPresented = false
    }

    func reset() {
        close()
        match = nil
        error = nil
        cache.removeAll()
    }

    func providersChanged(_ enabled: Set<LyricProviderID>) {
        cancel()
        if let match, !match.detailsComplete, !enabled.contains(match.provider) {
            error = LyricServiceError.providerNotConfigured.localizedDescription
        }
    }
}
