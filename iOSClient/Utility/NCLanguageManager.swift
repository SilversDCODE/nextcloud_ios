// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-FileCopyrightText: 2026 Nextcloud contributors
// SPDX-License-Identifier: GPL-3.0-or-later

import Foundation
import UIKit

extension Bundle {
    private static var isSwizzled = false

    static func swizzleLocalization() {
        guard !isSwizzled else { return }
        isSwizzled = true

        let originalSelector = #selector(Bundle.localizedString(forKey:value:table:))
        let swizzledSelector = #selector(Bundle.nc_localizedString(forKey:value:table:))

        guard let originalMethod = class_getInstanceMethod(Bundle.self, originalSelector),
              let swizzledMethod = class_getInstanceMethod(Bundle.self, swizzledSelector) else {
            return
        }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }

    @objc func nc_localizedString(forKey key: String, value: String?, table tableName: String?) -> String {
        if self == Bundle.main, let currentBundle = NCLanguageManager.shared.currentBundle {
            let str = currentBundle.nc_localizedString(forKey: key, value: value, table: tableName)
            if str != key {
                return str
            }
        }
        return self.nc_localizedString(forKey: key, value: value, table: tableName)
    }
}

final class NCLanguageManager: @unchecked Sendable {
    static let shared = NCLanguageManager()

    static let notificationLanguageChanged = Notification.Name("NCLanguageDidChangeNotification")
    private let languageKey = "selected_app_language"

    private var groupDefaults: UserDefaults? {
        UserDefaults(suiteName: NCBrandOptions.shared.capabilitiesGroup)
    }

    var currentBundle: Bundle?

    private init() {
        Bundle.swizzleLocalization()
        applyLanguage()
    }

    var currentLanguageCode: String {
        get {
            if let saved = UserDefaults.standard.string(forKey: languageKey), !saved.isEmpty {
                return saved
            }
            if let groupSaved = groupDefaults?.string(forKey: languageKey), !groupSaved.isEmpty {
                return groupSaved
            }
            return ""
        }
        set {
            if newValue.isEmpty {
                UserDefaults.standard.removeObject(forKey: languageKey)
                UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                groupDefaults?.removeObject(forKey: languageKey)
                groupDefaults?.removeObject(forKey: "AppleLanguages")
            } else {
                UserDefaults.standard.set(newValue, forKey: languageKey)
                UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                groupDefaults?.set(newValue, forKey: languageKey)
                groupDefaults?.set([newValue], forKey: "AppleLanguages")
            }
            UserDefaults.standard.synchronize()
            groupDefaults?.synchronize()

            applyLanguage()
            NotificationCenter.default.post(name: Self.notificationLanguageChanged, object: nil)
        }
    }

    func applyLanguage() {
        Bundle.swizzleLocalization()
        let code = currentLanguageCode
        if !code.isEmpty {
            if let path = Bundle.main.path(forResource: code, ofType: "lproj") {
                currentBundle = Bundle(path: path)
            } else if let url = Bundle.main.url(forResource: code, withExtension: "lproj") {
                currentBundle = Bundle(url: url)
            } else {
                currentBundle = nil
            }
        } else {
            currentBundle = nil
        }
    }

    var currentLanguageDisplayName: String {
        switch currentLanguageCode {
        case "lo":
            return "ພາສາລາວ"
        case "en":
            return "English"
        default:
            return NSLocalizedString("_system_default_", comment: "System default language")
        }
    }
}
