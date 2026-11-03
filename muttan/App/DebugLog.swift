import Foundation
import OSLog

enum DebugLog {
    private static let logger = Logger(subsystem: "com.muttan.app", category: "diagnostics")

    static func record(_ event: String, details: [String: String] = [:], level: OSLogType = .info) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let fields = details.map { "\($0.key)=\($0.value)" }.sorted().joined(separator: " ")
        let line = "\(timestamp) [muttan] \(event) \(fields)\n"

        logger.log(level: level, "\(event, privacy: .public) \(fields, privacy: .public)")

#if DEBUG
        if let data = line.data(using: .utf8) {
            try? FileHandle.standardError.write(contentsOf: data)
        }
#endif
    }
}
