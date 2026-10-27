import Foundation

/// Immutable request configuration. Never put the user's contact address in a match or a log.
struct ProviderAccess: Equatable, Sendable {
    var enabled: Set<LyricProviderID>
    var lrcRedEmail = ""

    var contactEmail: String? {
        let email = lrcRedEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        // Practical unquoted email syntax also excludes header injection and User-Agent delimiters.
        guard email.utf8.count <= 254,
            email.range(
                of:
                    #"^[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+(?:\.[A-Za-z0-9!#$%&'*+/=?^_`{|}~-]+)*@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$"#,
                options: .regularExpression) != nil
        else { return nil }
        return email
    }

    var searchable: Set<LyricProviderID> {
        contactEmail == nil ? enabled.subtracting([.lrcRed]) : enabled
    }

    func restricted(to provider: LyricProviderID?) -> Self {
        guard let provider else { return self }
        return Self(enabled: enabled.intersection([provider]), lrcRedEmail: lrcRedEmail)
    }
}
