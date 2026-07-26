import SwiftUI

// MARK: - 年份滚轮选择器
struct YearWheelPicker: View {
    @Binding var selection: String; let options: [String]; @State private var tempSelection: String = ""; @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }.foregroundColor(AppTheme.textSecondary); Spacer()
                Text("选择年份").font(.appBody.weight(.semibold)).foregroundColor(AppTheme.textPrimary); Spacer()
                Button("确定") { selection = (tempSelection == "全部") ? "" : tempSelection; dismiss() }.foregroundStyle(AppTheme.brandGradient).fontWeight(.semibold)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            Picker("年份", selection: $tempSelection) {
                ForEach(options, id: \.self) { yr in Text(yr == "全部" ? "全部年份" : yr).font(.system(size: 21, weight: .medium)).tag(yr) }
            }.pickerStyle(.wheel)
        }.background(.ultraThinMaterial).onAppear { tempSelection = selection.isEmpty ? (options.first ?? "") : selection }
    }
}

// MARK: - 月份滚轮选择器
struct MonthWheelPicker: View {
    @Binding var selection: String; let options: [String]; @State private var tempSelection: String = ""; @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }.foregroundColor(AppTheme.textSecondary); Spacer()
                Text("选择月份").font(.appBody.weight(.semibold)).foregroundColor(AppTheme.textPrimary); Spacer()
                Button("确定") { selection = (tempSelection == "全部") ? "" : tempSelection; dismiss() }.foregroundStyle(AppTheme.brandGradient).fontWeight(.semibold)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            Picker("月份", selection: $tempSelection) {
                ForEach(options, id: \.self) { m in Text(m == "全部" ? "全部月份" : m).font(.system(size: 21, weight: .medium)).tag(m) }
            }.pickerStyle(.wheel)
        }.background(.ultraThinMaterial).onAppear { tempSelection = selection.isEmpty ? (options.first ?? "") : selection }
    }
}

// MARK: - 分类滚轮选择器
struct CategoryWheelPicker: View {
    @Binding var selection: String; let options: [String]; @State private var tempSelection: String = ""; @Environment(\.dismiss) private var dismiss
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("取消") { dismiss() }.foregroundColor(AppTheme.textSecondary); Spacer()
                Text("选择类型").font(.appBody.weight(.semibold)).foregroundColor(AppTheme.textPrimary); Spacer()
                Button("确定") { selection = (tempSelection == "全部") ? "" : tempSelection; dismiss() }.foregroundStyle(AppTheme.brandGradient).fontWeight(.semibold)
            }.padding(.horizontal, 16).padding(.vertical, 12)
            Divider()
            Picker("分类", selection: $tempSelection) {
                ForEach(options, id: \.self) { cat in Text(cat == "全部" ? "全部类别" : cat).font(.system(size: 21, weight: .medium)).tag(cat) }
            }.pickerStyle(.wheel)
        }.background(.ultraThinMaterial).onAppear { tempSelection = selection.isEmpty ? (options.first ?? "") : selection }
    }
}
