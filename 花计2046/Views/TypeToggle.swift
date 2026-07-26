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
                    .foregroundColor(type == .expense ? .white : AppTheme.brandStart)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(type == .expense ? AppTheme.brandStart : Color.white)
                    .cornerRadius(7)
            }
        }
        .background(AppTheme.background)
        .cornerRadius(8)
    }
}
