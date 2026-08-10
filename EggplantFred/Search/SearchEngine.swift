import Foundation

enum SearchEngine {
    static func search(query: String, in apps: [AppEntry], limit: Int = 9) -> [AppEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let needle = trimmed.lowercased()

        struct Scored {
            let app: AppEntry
            let score: Int
        }

        var scored: [Scored] = []
        scored.reserveCapacity(min(apps.count, 64))

        for app in apps {
            if let score = score(app: app, needle: needle) {
                scored.append(Scored(app: app, score: score))
            }
        }

        return scored
            .sorted {
                if $0.score != $1.score { return $0.score > $1.score }
                return $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending
            }
            .prefix(limit)
            .map(\.app)
    }

    private static func score(app: AppEntry, needle: String) -> Int? {
        let name = app.name
        let fileName = app.url.deletingPathExtension().lastPathComponent
        var best: Int?

        for text in [name, fileName] {
            if let value = score(text: text, needle: needle) {
                best = max(best ?? Int.min, value)
            }
        }
        return best
    }

    private static func score(text: String, needle: String) -> Int? {
        let lowered = text.lowercased()

        if lowered == needle {
            return 1000
        }
        if lowered.hasPrefix(needle) {
            return 900 - lowered.count
        }

        let tokenList = tokens(in: text)
        if let tokenIndex = tokenList.firstIndex(where: { $0.hasPrefix(needle) }) {
            // "St" → Studio in "LM Studio" / "Visual Studio Code" / "WebStorm"
            return 800 - tokenIndex * 20 - (tokenList[tokenIndex].count - needle.count)
        }

        if lowered.contains(needle) {
            return 600 - (lowered.distance(of: needle) ?? 0) * 5
        }

        let acronym = tokenList.map { String($0.prefix(1)) }.joined()
        if acronym.hasPrefix(needle) || acronym.contains(needle) {
            return 450
        }

        if fuzzyMatch(needle, in: lowered) {
            return 200 - lowered.count
        }

        return nil
    }

    /// Split "Visual Studio Code", "WebStorm", "VSCode", "HuaStudio" into tokens.
    private static func tokens(in text: String) -> [String] {
        var result: [String] = []
        var current = ""

        func flush() {
            guard !current.isEmpty else { return }
            result.append(current.lowercased())
            current = ""
        }

        let separators = CharacterSet.alphanumerics.inverted
        for scalar in text.unicodeScalars {
            if separators.contains(scalar) {
                flush()
                continue
            }

            let char = Character(scalar)

            if char.isUppercase, let last = current.last, last.isLowercase {
                flush()
            } else if char.isLowercase,
                      current.count >= 2,
                      current.dropLast().allSatisfy(\.isUppercase),
                      current.last?.isUppercase == true {
                // "VSCode" → "VS" + "Code"
                let acronym = String(current.dropLast())
                let lead = String(current.last!)
                result.append(acronym.lowercased())
                current = lead
            }

            current.append(char)
        }
        flush()
        return result
    }

    private static func fuzzyMatch(_ needle: String, in haystack: String) -> Bool {
        var iterator = haystack.makeIterator()
        for char in needle {
            var found = false
            while let next = iterator.next() {
                if next == char {
                    found = true
                    break
                }
            }
            if !found { return false }
        }
        return true
    }
}

private extension String {
    func distance(of substring: String) -> Int? {
        guard let range = range(of: substring) else { return nil }
        return distance(from: startIndex, to: range.lowerBound)
    }
}
