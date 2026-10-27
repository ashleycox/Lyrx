import Foundation

/// Contact-bearing requests must not forward the user's address to another origin.
final class ContactRedirectPolicy: NSObject, URLSessionTaskDelegate {
    static func permits(from original: URL?, to destination: URL?) -> Bool {
        guard let original, let destination else { return false }
        return original.scheme == "https" && destination.scheme == "https"
            && original.host == "lrc.red" && destination.host == original.host
            && (destination.port ?? 443) == (original.port ?? 443)
            && destination.user == nil && destination.password == nil
    }

    func urlSession(
        _ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        completionHandler(Self.permits(from: task.originalRequest?.url, to: request.url) ? request : nil)
    }
}
