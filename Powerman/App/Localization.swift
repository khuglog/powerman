import Foundation
import SwiftUI

enum L10n {
    private static let tableName = "Localizable"

    private final class BundleCache: @unchecked Sendable {
        private let lock = NSLock()
        private var cache: [String: Bundle] = [:]

        func bundle(for locale: Locale) -> Bundle {
            let identifier = locale.identifier.isEmpty ? "en" : locale.identifier
            lock.lock()
            if let cached = cache[identifier] {
                lock.unlock()
                return cached
            }
            lock.unlock()

            let matchedCode = Bundle.preferredLocalizations(
                from: Bundle.main.localizations,
                forPreferences: [identifier]
            ).first ?? "en"

            let resolved: Bundle
            if let path = Bundle.main.path(forResource: matchedCode, ofType: "lproj"),
               let lprojBundle = Bundle(path: path) {
                resolved = lprojBundle
            } else {
                resolved = .main
            }

            lock.lock()
            cache[identifier] = resolved
            lock.unlock()
            return resolved
        }
    }

    private static let bundleCache = BundleCache()

    static func string(_ key: String, locale: Locale) -> String {
        let bundle = bundleCache.bundle(for: locale)
        let value = bundle.localizedString(forKey: key, value: nil, table: tableName)
        if value != key || locale.language.languageCode?.identifier == "en" {
            return value
        }
        return String(
            localized: String.LocalizationValue(key),
            table: tableName,
            bundle: bundle,
            locale: locale,
            comment: ""
        )
    }

    static func format(_ key: String, locale: Locale, _ arguments: CVarArg...) -> String {
        let template = string(key, locale: locale)
        return String(format: template, locale: locale, arguments: arguments)
    }

    static func string(_ key: String, language: AppLanguageOption) -> String {
        string(key, locale: language.effectiveLocalizationLocale)
    }

    static func format(_ key: String, language: AppLanguageOption, _ arguments: CVarArg...) -> String {
        let locale = language.effectiveLocalizationLocale
        let template = string(key, locale: locale)
        return String(format: template, locale: locale, arguments: arguments)
    }
}

private struct AppLocaleKey: EnvironmentKey {
    static let defaultValue: Locale = Locale(identifier: "en")
}

extension EnvironmentValues {
    var appLocale: Locale {
        get { self[AppLocaleKey.self] }
        set { self[AppLocaleKey.self] = newValue }
    }
}
