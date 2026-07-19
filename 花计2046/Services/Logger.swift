import Foundation
import OSLog

enum LogLevel: String {
    case debug = "🔍"
    case info  = "ℹ️"
    case warn  = "⚠️"
    case error = "❌"
}

struct Log {
    static let logFile: URL = {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("huaji_debug.log")
    }()
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm:ss.SSS"
        return f
    }()
    
    private static let logger = OSLog(subsystem: "com.huaji.2046", category: "app")
    
    static func debug(_ msg: String, file: String = #file, line: Int = #line) {
        log(.debug, msg, file: file, line: line)
    }
    
    static func info(_ msg: String, file: String = #file, line: Int = #line) {
        log(.info, msg, file: file, line: line)
    }
    
    static func warn(_ msg: String, file: String = #file, line: Int = #line) {
        log(.warn, msg, file: file, line: line)
    }
    
    static func error(_ msg: String, file: String = #file, line: Int = #line) {
        log(.error, msg, file: file, line: line)
    }
    
    private static func log(_ level: LogLevel, _ msg: String, file: String, line: Int) {
        let filename = URL(fileURLWithPath: file).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let timestamp = dateFormatter.string(from: Date())
        let formatted = "[\(timestamp)] \(level.rawValue) [\(filename):\(line)] \(msg)"
        
        // Console
        print(formatted)
        
        // OSLog (visible in Console.app)
        os_log("%{public}@", log: logger, type: .debug, formatted)
        
        // File persistence (async, last 1000 lines only)
        appendToFile(formatted)
    }
    
    private static func appendToFile(_ text: String) {
        DispatchQueue.global(qos: .utility).async {
            var lines: [String] = []
            if let existing = try? String(contentsOf: logFile, encoding: .utf8) {
                lines = existing.components(separatedBy: "\n")
            }
            lines.append(text)
            // Keep last 500 lines
            if lines.count > 500 {
                lines = Array(lines.suffix(500))
            }
            try? lines.joined(separator: "\n").write(to: logFile, atomically: true, encoding: .utf8)
        }
    }
    
    static func readLogFile() -> String {
        (try? String(contentsOf: logFile, encoding: .utf8)) ?? "暂无日志"
    }
}
