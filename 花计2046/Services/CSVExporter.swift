import Foundation

struct CSVExporter {
    /// Exports records as a UTF-8 CSV file and returns its temporary file URL.
    static func exportCSV(records: [Record]) -> URL {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"

        // BOM so Excel/WPS on Chinese Windows opens UTF-8 correctly
        var csv = "\u{FEFF}日期,类型,类别,名称,金额,备注\n"
        for r in records {
            let dateStr = dateFormatter.string(from: r.date)
            let typeStr = r.type == .expense ? "支出" : "收入"
            let amountStr = String(format: "%.2f", r.amount)
            let noteStr = escapeCSV(r.note ?? "")
            let merchantStr = escapeCSV(r.merchant)
            let categoryStr = escapeCSV(r.category)
            csv += "\(dateStr),\(typeStr),\(categoryStr),\(merchantStr),\(amountStr),\(noteStr)\n"
        }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("huaji_records_\(formatDateForFile(Date())).csv")
        try? csv.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    /// Escapes a field for CSV: wraps in quotes if it contains commas, quotes, or newlines.
    private static func escapeCSV(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }

    private static func formatDateForFile(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd_HHmmss"
        return df.string(from: date)
    }
}
