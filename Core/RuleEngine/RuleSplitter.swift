import Foundation

struct SplitRule {
    let type: RuleKind
    let rule: String
    let replace: (pattern: String, replacement: String, group: Int?)?
}

enum RuleOperator {
    case and
    case or
    case format
    case replace
}

class RuleSplitter {
    static func split(_ ruleString: String) -> [SplitRule] {
        let trimmed = ruleString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let operators = parseOperators(trimmed)
        let segments: [String]

        if let orSegments = operators.first(where: { $0.operator == .or })?.segments {
            segments = orSegments
        } else if let andSegments = operators.first(where: { $0.operator == .and })?.segments {
            segments = andSegments
        } else {
            segments = [trimmed]
        }

        return segments.compactMap { parseSegment($0) }
    }

    static func parseOperators(_ ruleString: String) -> [(operator: RuleOperator, segments: [String])] {
        let trimmed = ruleString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var parsed: [(operator: RuleOperator, segments: [String])] = []

        if let segments = splitIfContains(trimmed, token: "&&") {
            parsed.append((.and, segments))
        }
        if let segments = splitIfContains(trimmed, token: "||") {
            parsed.append((.or, segments))
        }
        if let segments = splitIfContains(trimmed, token: "%%") {
            parsed.append((.format, segments))
        }
        if let segments = splitIfContains(trimmed, token: "##") {
            parsed.append((.replace, segments))
        }

        return parsed
    }

    private static func parseSegment(_ segment: String) -> SplitRule? {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let (rulePart, replacePart) = parseReplace(trimmed)
        let (type, rule) = parseTypeAndRule(rulePart)

        return SplitRule(type: type, rule: rule, replace: replacePart)
    }

    private static func parseTypeAndRule(_ rawRule: String) -> (RuleKind, String) {
        let trimmed = rawRule.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()

        let prefixedKinds: [(prefix: String, kind: RuleKind)] = [
            ("@css:", .css),
            ("@xpath:", .xpath),
            ("@json:", .jsonPath),
            ("@js:", .js),
            ("@regex:", .regex)
        ]

        for item in prefixedKinds where lowercased.hasPrefix(item.prefix) {
            let content = String(trimmed.dropFirst(item.prefix.count))
            return (item.kind, content)
        }

        if trimmed.hasPrefix("//") {
            return (.xpath, trimmed)
        }
        if trimmed.hasPrefix("$.") {
            return (.jsonPath, trimmed)
        }
        if lowercased.hasPrefix("regex:") || lowercased.contains("{{regex") {
            return (.regex, trimmed)
        }
        if lowercased.contains("{{js") || lowercased.contains("<js>") {
            return (.js, trimmed)
        }

        return (.css, trimmed)
    }

    private static func parseReplace(_ rule: String) -> (
        rule: String,
        replace: (pattern: String, replacement: String, group: Int?)?
    ) {
        let parts = rule.components(separatedBy: "##")
        guard parts.count >= 3 else {
            return (rule, nil)
        }

        let targetRule = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = parts[1]
        let payload = Array(parts.dropFirst(2))

        if payload.count == 1 {
            let token = payload[0]
            if let group = Int(token) {
                return (targetRule, (pattern: pattern, replacement: "$\(group)", group: group))
            }
            return (targetRule, (pattern: pattern, replacement: token, group: nil))
        }

        if let last = payload.last, let group = Int(last) {
            let replacementParts = payload.dropLast()
            let replacement = replacementParts.joined(separator: "##")
            let resolvedReplacement = replacement.isEmpty ? "$\(group)" : replacement
            return (targetRule, (pattern: pattern, replacement: resolvedReplacement, group: group))
        }

        return (targetRule, (pattern: pattern, replacement: payload.joined(separator: "##"), group: nil))
    }

    private static func splitIfContains(_ input: String, token: String) -> [String]? {
        guard input.contains(token) else { return nil }
        let segments = input
            .components(separatedBy: token)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return segments.isEmpty ? nil : segments
    }
}
