import Foundation

struct EditingTextLayout {
    private let segments: [String]
    private let separators: [String]

    init(_ text: String) {
        var segments: [String] = []
        var separators: [String] = []
        var current = ""
        for character in text {
            if character.isNewline {
                segments.append(current)
                separators.append(String(character))
                current = ""
            } else {
                current.append(character)
            }
        }
        segments.append(current)
        self.segments = segments
        self.separators = separators
    }

    var passages: [String] {
        segments.map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    func replacingPassages(with revisions: [String]) throws -> String {
        guard revisions.count == passages.count else {
            throw TextEditingError(message: "The writing model returned the wrong number of passages. Your text was not changed.")
        }
        var result = ""
        var revisionIndex = 0
        for (index, segment) in segments.enumerated() {
            if segment.trimmingCharacters(in: .whitespaces).isEmpty {
                result += segment
            } else {
                let revised = revisions[revisionIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                guard !revised.isEmpty, !revised.contains(where: { $0.isNewline }) else {
                    throw TextEditingError(message: "The writing model changed the passage formatting. Your text was not changed. Try again with a shorter selection.")
                }
                let leading = segment.prefix(while: { $0.isWhitespace })
                let trailing = String(segment.reversed().prefix(while: { $0.isWhitespace }).reversed())
                result += String(leading) + revised + trailing
                revisionIndex += 1
            }
            if index < separators.count { result += separators[index] }
        }
        return result
    }
}
