import SwiftUI

struct TypeToggle: View {
    let type: RecordType
    let onSelect: (RecordType) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: { onSelect(.income) }) {
                Text("收入")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(type == .income ? .white : .green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(type == .income ? Color.green : Color.white)
                    .cornerRadius(7)
            }
            Button(action: { onSelect(.expense) }) {
                Text("支出")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppTheme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(type == .expense ? AppTheme.textSecondary.opacity(0.22) : Color.white)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke(type == .expense ? AppTheme.textSecondary.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .cornerRadius(7)
            }
        }
        .background(AppTheme.background)
        .cornerRadius(8)
    }
}
