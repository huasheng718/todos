import Foundation

enum CredentialImportParser {
    static func draft(fromLooseText text: String) -> CredentialDraft? {
        let lines = text
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !lines.isEmpty else { return nil }

        var draft = CredentialDraft()
        var noteLines: [String] = []

        for line in lines {
            if let (key, value) = labeledValue(from: line) {
                assign(value: value, for: key, to: &draft, notes: &noteLines)
                continue
            }

            if draft.title.isEmpty, !looksLikeURL(line) {
                draft.title = line
            } else if draft.serviceURL.isEmpty, looksLikeURL(line) {
                draft.serviceURL = line
            } else {
                noteLines.append(line)
            }
        }

        if draft.title.isEmpty {
            draft.title = hostTitle(from: draft.serviceURL)
        }
        if draft.notes.isEmpty, !noteLines.isEmpty {
            draft.notes = noteLines.joined(separator: "\n")
        }
        if !draft.serviceURL.isEmpty {
            draft.type = .website
        }

        return draft.cleanedTitle.isEmpty ? nil : draft
    }

    static func drafts(fromLooseText text: String) -> [CredentialDraft] {
        paragraphs(in: text).compactMap(draft(fromLooseText:))
    }

    static func drafts(fromFileText text: String) -> [CredentialDraft] {
        let csvDrafts = drafts(fromChromeCSV: text)
        if !csvDrafts.isEmpty {
            return csvDrafts
        }
        return drafts(fromLooseText: text)
    }

    static func drafts(fromChromeCSV text: String) -> [CredentialDraft] {
        let rows = parseCSV(text)
        guard let header = rows.first?.map(normalizedHeader), !header.isEmpty else { return [] }

        let nameIndex = index(in: header, candidates: ["name", "title", "名称", "标题"])
        let urlIndex = index(in: header, candidates: ["url", "origin_url", "action_url", "website", "网址"])
        let usernameIndex = index(in: header, candidates: ["username", "username_value", "login", "account", "账号", "用户名"])
        let passwordIndex = index(in: header, candidates: ["password", "password_value", "密码"])
        let noteIndex = index(in: header, candidates: ["note", "notes", "备注"])

        guard passwordIndex != nil || usernameIndex != nil || urlIndex != nil else {
            return []
        }

        return rows.dropFirst().compactMap { row in
            var draft = CredentialDraft()
            draft.title = value(at: nameIndex, in: row)
            draft.serviceURL = value(at: urlIndex, in: row)
            draft.username = value(at: usernameIndex, in: row)
            draft.secretValue = value(at: passwordIndex, in: row)
            draft.notes = value(at: noteIndex, in: row)
            draft.type = draft.serviceURL.isEmpty ? .other : .website
            if draft.title.isEmpty {
                draft.title = hostTitle(from: draft.serviceURL)
            }
            return draft.cleanedTitle.isEmpty ? nil : draft
        }
    }

    private static func labeledValue(from line: String) -> (String, String)? {
        if looksLikeURL(line) {
            return nil
        }

        let separators = ["：", ":"]
        for separator in separators {
            guard let range = line.range(of: separator) else { continue }
            let key = String(line[..<range.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(line[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !value.isEmpty else { return nil }
            return (key, value)
        }
        return nil
    }

    private static func assign(value: String, for rawKey: String, to draft: inout CredentialDraft, notes: inout [String]) {
        let key = rawKey.lowercased()
        if ["账号", "账户", "用户名", "user", "username", "login", "email"].contains(where: { key.contains($0) }) {
            draft.username = value
        } else if ["密码", "password", "pass", "token", "key", "密钥"].contains(where: { key.contains($0) }) {
            draft.secretValue = value
        } else if ["网址", "链接", "url", "地址", "网站"].contains(where: { key.contains($0) }) {
            draft.serviceURL = value
        } else if ["名称", "标题", "name", "title"].contains(where: { key.contains($0) }) {
            draft.title = value
        } else if ["备注", "note", "说明"].contains(where: { key.contains($0) }) {
            draft.notes = value
        } else {
            notes.append("\(rawKey)：\(value)")
        }
    }

    private static func looksLikeURL(_ value: String) -> Bool {
        value.hasPrefix("http://") || value.hasPrefix("https://") || value.contains("://")
    }

    private static func hostTitle(from urlText: String) -> String {
        guard let url = URL(string: urlText), let host = url.host, !host.isEmpty else {
            return urlText
        }
        return host
    }

    private static func normalizedHeader(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: " ", with: "_")
    }

    private static func index(in header: [String], candidates: [String]) -> Int? {
        header.firstIndex { column in
            candidates.contains(column)
        }
    }

    private static func value(at index: Int?, in row: [String]) -> String {
        guard let index, row.indices.contains(index) else { return "" }
        return row[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var isQuoted = false
        var iterator = text.makeIterator()

        while let character = iterator.next() {
            if character == "\"" {
                if isQuoted {
                    if let next = iterator.next() {
                        if next == "\"" {
                            field.append("\"")
                        } else {
                            isQuoted = false
                            if next == "," {
                                row.append(field)
                                field = ""
                            } else if next == "\n" {
                                row.append(field)
                                rows.append(row)
                                row = []
                                field = ""
                            } else if next != "\r" {
                                field.append(next)
                            }
                        }
                    } else {
                        isQuoted = false
                    }
                } else if field.isEmpty {
                    isQuoted = true
                } else {
                    field.append(character)
                }
            } else if character == ",", !isQuoted {
                row.append(field)
                field = ""
            } else if character == "\n", !isQuoted {
                row.append(field)
                rows.append(row)
                row = []
                field = ""
            } else if character != "\r" {
                field.append(character)
            }
        }

        if !field.isEmpty || !row.isEmpty {
            row.append(field)
            rows.append(row)
        }

        return rows.filter { row in
            row.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    private static func paragraphs(in text: String) -> [String] {
        var result: [String] = []
        var current: [String] = []

        for line in text.components(separatedBy: .newlines) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty {
                    result.append(current.joined(separator: "\n"))
                    current = []
                }
            } else {
                current.append(line)
            }
        }

        if !current.isEmpty {
            result.append(current.joined(separator: "\n"))
        }

        return result
    }
}
