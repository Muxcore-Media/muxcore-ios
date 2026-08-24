import Foundation

struct VTTCue: Equatable {
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

enum WebVTTParser {
    static func parse(_ content: String) -> [VTTCue] {
        var cues: [VTTCue] = []
        var block: [String] = []

        func flush() {
            guard !block.isEmpty else { return }
            defer { block.removeAll(keepingCapacity: true) }
            guard let timing = block.first, let range = parseTimingLine(timing) else { return }
            let text = block.dropFirst().joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            cues.append(VTTCue(start: range.start, end: range.end, text: text))
        }

        for raw in content.components(separatedBy: .newlines) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.isEmpty {
                flush()
                continue
            }
            if line == "WEBVTT" || line.hasPrefix("NOTE") || line.hasPrefix("STYLE") {
                continue
            }
            block.append(line)
        }
        flush()
        return cues.sorted { $0.start < $1.start }
    }

    static func activeCue(at time: TimeInterval, cues: [VTTCue]) -> String? {
        cues.first { time >= $0.start && time < $0.end }?.text
    }

    private static func parseTimingLine(_ line: String) -> (start: TimeInterval, end: TimeInterval)? {
        let parts = line.components(separatedBy: "-->")
        guard parts.count == 2,
              let start = parseTimestamp(parts[0].trimmingCharacters(in: .whitespaces)),
              let end = parseTimestamp(parts[1].trimmingCharacters(in: .whitespaces).split(separator: " ").first.map(String.init) ?? "")
        else { return nil }
        return (start, end)
    }

    private static func parseTimestamp(_ raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let chunks = trimmed.split(separator: ":")
        guard chunks.count >= 2 else { return nil }
        let secondsChunk = chunks[chunks.count - 1].replacingOccurrences(of: ",", with: ".")
        guard let seconds = Double(secondsChunk) else { return nil }
        if chunks.count == 2 {
            guard let minutes = Double(chunks[0]) else { return nil }
            return minutes * 60 + seconds
        }
        guard let hours = Double(chunks[0]), let minutes = Double(chunks[1]) else { return nil }
        return hours * 3600 + minutes * 60 + seconds
    }
}
