import Foundation

enum AppUpdateAvailability {
    static func isAvailable(
        currentVersion: String,
        currentBuild: Int,
        manifestVersion: String,
        manifestBuild: Int
    ) -> Bool {
        switch compareVersions(manifestVersion, currentVersion) {
        case .orderedDescending:
            return true
        case .orderedAscending:
            return false
        case .orderedSame:
            return manifestBuild > currentBuild
        }
    }

    static func compareVersions(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let left = versionComponents(lhs)
        let right = versionComponents(rhs)
        let count = max(left.count, right.count)

        for index in 0..<count {
            let leftComponent = index < left.count ? left[index] : 0
            let rightComponent = index < right.count ? right[index] : 0

            if leftComponent < rightComponent {
                return .orderedAscending
            }
            if leftComponent > rightComponent {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func versionComponents(_ version: String) -> [Int] {
        version
            .split(separator: ".")
            .map { part in
                let numericPrefix = part.prefix { $0.isNumber }
                return Int(numericPrefix) ?? 0
            }
    }
}
