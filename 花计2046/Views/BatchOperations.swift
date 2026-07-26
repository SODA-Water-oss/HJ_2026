import SwiftUI


struct BatchOperationSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    let selectedCount: Int

    @Binding var batchNoteText: String
    @Binding var batchNoteMode: NoteMode
    var onNoteConfirm: () -> Void
    var onDeleteConfirm: () -> Void
    var onDateConfirm: (Date) -> Void
    var onCategoryConfirm: (String) -> Void
    var onCancel: () -> Void
    var batchCategories: [String] = ["餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]

    @State private var showNoteSheet = false
    @State private var showDeleteAlert = false
    @State private var didProcess = false
    @State private var showDateSheet = false
    @State private var showCategorySheet = false
    private var isProcessing: Bool { supabaseService.batchProgress != nil }

    var body: some View {
        VStack(spacing: 20) {
            Text("批量操作").font(.title2.weight(.semibold)).foregroundColor(.white).padding(.top, 32)

            Text("已选 \(selectedCount) 条记录")
                .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(AppTheme.brandStart.opacity(0.08))
                .cornerRadius(8)

            // ── 操作列表 ──
            VStack(spacing: 10) {
                BatchOperationRow(icon: "pencil.and.list.clipboard", title: "修改备注") { if !isProcessing { showNoteSheet = true } }
                BatchOperationRow(icon: "calendar", title: "修改时间") { if !isProcessing { showDateSheet = true } }
                BatchOperationRow(icon: "tag", title: "修改类别") { if !isProcessing { showCategorySheet = true } }
                BatchOperationRow(icon: "trash", title: "批量删除", tint: .red) { if !isProcessing { showDeleteAlert = true } }
            }.padding(.horizontal)
            .opacity(isProcessing ? 0.5 : 1.0)
            .disabled(isProcessing)

            Spacer()

            if let bp = supabaseService.batchProgress, bp.1 > 0 {
                PawPrintProgress(current: bp.0, total: bp.1)
                    .padding(.horizontal)
            }

            Button(action: { if !isProcessing { onCancel() } }) {
                Text("关闭操作")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(isProcessing ? AnyShapeStyle(Color.gray.opacity(0.5)) : AnyShapeStyle(AppTheme.brandGradient))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .padding(.horizontal, 20)
                    .background(Color.clear)
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? Color.gray.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
            }
            .disabled(isProcessing)
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .background(.ultraThinMaterial)
        
        .sheet(isPresented: $showNoteSheet) {
            BatchNoteSheet(selectedCount: selectedCount, batchNoteText: $batchNoteText, batchNoteMode: $batchNoteMode, onConfirm: onNoteConfirm, onCancel: { showNoteSheet = false })
        }
        .sheet(isPresented: $showCategorySheet) {
            BatchCategorySheet(selectedCount: selectedCount, categories: batchCategories, onConfirm: { cat in onCategoryConfirm(cat) }, onCancel: { showCategorySheet = false })
        }
        .sheet(isPresented: $showDateSheet) {
            BatchDatePickerSheet(selectedCount: selectedCount, onConfirm: { date in onDateConfirm(date) }, onCancel: { showDateSheet = false })
        }
        .alert("批量删除", isPresented: $showDeleteAlert) {
            Button("取消", role: .cancel) {}
            Button("确认删除", role: .destructive) { didProcess = true; onDeleteConfirm() }
        } message: {
            Text("是否确定删除已选的 \(selectedCount) 条记录？")
        }
        .onChange(of: isProcessing) { processing in if processing { didProcess = true } else if didProcess { onCancel(); didProcess = false } }
        .onChange(of: showNoteSheet) { showing in if !showing && didProcess { onCancel(); didProcess = false } }
        .onChange(of: showDateSheet) { showing in if !showing && didProcess { onCancel(); didProcess = false } }
        .onChange(of: showCategorySheet) { showing in if !showing && didProcess { onCancel(); didProcess = false } }
    }
}

// MARK: - 批量操作菜单行
struct BatchOperationRow: View {
    let icon: String
    let title: String
    var tint: Color = AppTheme.brandStart
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon).font(.system(size: 17)).foregroundColor(.white).frame(width: 24)
                Text(title).font(.system(size: 17, weight: .medium)).foregroundColor(.white)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 17, weight: .semibold)).foregroundColor(.white.opacity(0.7))
            }
            .padding(.vertical, 14).padding(.horizontal, 16)
            .background(AppTheme.brandGradient).cornerRadius(12)
            .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
        }
    }
}

// MARK: - 批量修改备注子 Sheet
struct BatchNoteSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int


    @Binding var batchNoteText: String
    @Binding var batchNoteMode: NoteMode
    var onConfirm: () -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改备注").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)

                    TextEditor(text: $batchNoteText)
                        .byteLimited($batchNoteText, max: 200)
                        .font(.system(size: 18))
                        .frame(minHeight: 60)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).stroke(Color(hex: "#666666"), lineWidth: 1))
                        .padding(.horizontal)

                    HStack {
                        if batchNoteText.utf8.count > 200 {
                            Text("您的输入已超上限!")
                                .font(.system(size: 12))
                                .foregroundStyle(AppTheme.brandGradient)
                        }
                        Spacer()
                        Text("\(batchNoteText.utf8.count)/200")
                            .font(.system(size: 12))
                            .foregroundStyle(batchNoteText.utf8.count > 200 ? AnyShapeStyle(AppTheme.brandGradient) : AnyShapeStyle(Color(hex: "#888888")))
                    }
                    .padding(.horizontal)

                    Picker("模式", selection: $batchNoteMode) {
                        Text("替换").tag(NoteMode.replace)
                        Text("追加").tag(NoteMode.append)
                    }.pickerStyle(.segmented).padding(.horizontal)

                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }
                        .disabled(isProcessing)
                        Button(action: { isProcessing = true; onConfirm() }) {
                            Text(isProcessing ? "处理中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }
                        .disabled(batchNoteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isProcessing)
                    }.padding(.horizontal)
                    .task(id: supabaseService.batchProgress?.0) {
                        if supabaseService.batchProgress == nil && isProcessing { dismiss() }
                    }

                    Spacer()
                }
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)

                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
            
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { dismissKeyboard() }
                        .foregroundStyle(AppTheme.brandGradient)
                }
            }
        }
    }
}

// MARK: - 批量修改月份 Sheet
// MARK: - 批量修改时间 Sheet
struct BatchDatePickerSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int
    var onConfirm: (Date) -> Void
    var onCancel: () -> Void

    @State private var selectedDate = Date()

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改时间").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)
                    Spacer()

                    Text(selectedDate, format: .dateTime.weekday(.abbreviated))
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppTheme.textTertiary)
                        .frame(maxWidth: .infinity, alignment: .center)

                    VStack(spacing: 4) {
                        HStack {
                            Text("日期").font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.textSecondary).frame(width: 36, alignment: .leading)
                            DatePicker("", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN"))
                                .disabled(isProcessing)
                        }
                        HStack {
                            Text("时间").font(.system(size: 14, weight: .medium)).foregroundColor(AppTheme.textSecondary).frame(width: 36, alignment: .leading)
                            DatePicker("", selection: $selectedDate, displayedComponents: .hourAndMinute)
                                .datePickerStyle(.wheel).labelsHidden().environment(\.locale, Locale(identifier: "zh_CN"))
                                .disabled(isProcessing)
                        }
                    }
                    .padding(.horizontal, 8)

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }
                        .disabled(isProcessing)
                        Button(action: { isProcessing = true; onConfirm(selectedDate) }) {
                            Text(isProcessing ? "修改中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }
                        .disabled(isProcessing)
                    }.padding(.horizontal, 20)
                }
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)
                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
            .presentationDetents([.height(520)])
            .task(id: supabaseService.batchProgress?.0) {
                if supabaseService.batchProgress == nil && isProcessing { dismiss() }
            }
        }
    }
}

struct BatchMonthSheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int
    var onConfirm: (String) -> Void
    var onCancel: () -> Void

    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())

    private let years: [Int] = Array(2024...Calendar.current.component(.year, from: Date()))
    private let months: [Int] = Array(1...12)

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改月份").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundStyle(AppTheme.brandGradient)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)

                    HStack(spacing: 0) {
                        Picker("年", selection: $selectedYear) {
                            ForEach(years, id: \.self) { y in
                                Text("\(String(y))年").font(.system(size: 21, weight: .medium)).tag(y)
                            }
                        }.pickerStyle(.wheel).frame(width: 120)
                        Picker("月", selection: $selectedMonth) {
                            ForEach(months, id: \.self) { m in
                                Text(String(format: "%02d月", m)).font(.system(size: 21, weight: .medium)).tag(m)
                            }
                        }.pickerStyle(.wheel).frame(width: 120)
                    }

                    Spacer()

                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }
                        .disabled(isProcessing)
                        Button(action: { isProcessing = true
                            let monthStr = "\(String(selectedYear))年\(String(format: "%02d月", selectedMonth))"
                            onConfirm(monthStr)
                        }) {
                            Text(isProcessing ? "处理中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }
                        .disabled(isProcessing)
                    }.padding(.horizontal)
                    .task(id: supabaseService.batchProgress?.0) {
                        if supabaseService.batchProgress == nil && isProcessing { dismiss() }
                    }
                }
                .frame(maxHeight: .infinity)
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)

                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
            .presentationDetents([.height(620)])
        }
    }
}


// MARK: - 批量修改类别 Sheet
struct BatchCategorySheet: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @Environment(\.dismiss) var dismiss
    @State private var isProcessing = false
    let selectedCount: Int
    let categories: [String]
    var onConfirm: (String) -> Void
    var onCancel: () -> Void

    @State private var selectedCategory: String = "餐饮"

    var body: some View {
        NavigationView {
            ZStack {
                VStack(spacing: 20) {
                    Text("修改类别").font(.title2.weight(.semibold)).padding(.top, 32)
                    Text("已选 \(selectedCount) 条记录")
                        .font(.subheadline).foregroundColor(AppTheme.brandStart)
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(AppTheme.brandStart.opacity(0.08))
                        .cornerRadius(8)
                    Spacer()
                    Picker("类别", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).font(.system(size: 21, weight: .medium)).tag(cat)
                        }
                    }.pickerStyle(.wheel).frame(height: 520)
                    Spacer()
                    HStack(spacing: 16) {
                        Button(action: { if !isProcessing { onCancel() } }) {
                            Text("取消修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(isProcessing ? AppTheme.textTertiary : AppTheme.brandStart)
                                .frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(Color.clear).cornerRadius(8)
                                .overlay(RoundedRectangle(cornerRadius: 8).stroke(isProcessing ? AppTheme.textTertiary.opacity(0.3) : AppTheme.brandStart.opacity(0.5), lineWidth: 1.5))
                        }.disabled(isProcessing)
                        Button(action: { isProcessing = true; onConfirm(selectedCategory) }) {
                            Text(isProcessing ? "处理中..." : "确认修改").font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white).frame(maxWidth: .infinity).padding(.vertical, 12)
                                .background(AppTheme.brandGradient).cornerRadius(8)
                                .shadow(color: AppTheme.brandShadow, radius: 6, x: 0, y: 3)
                        }.disabled(isProcessing)
                    }.padding(.horizontal)
                     .task(id: supabaseService.batchProgress?.0) {
                         if supabaseService.batchProgress == nil && isProcessing { dismiss() }
                     }
                }
                .opacity(isProcessing ? 0.4 : 1.0)
                .disabled(isProcessing)
                if isProcessing {
                    VStack(spacing: 12) {
                        if let bp = supabaseService.batchProgress, bp.1 > 0 {
                            PawPrintProgress(current: bp.0, total: bp.1)
                        }
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .cornerRadius(16)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

struct PawPrintProgress: View {
    let current: Int
    let total: Int
    private let pawCount = 9

    private func pawColor(at index: Int) -> Color {
        let fraction = CGFloat(index) / CGFloat(max(pawCount - 1, 1))
        let startColor = UIColor(red: 0.357, green: 0.431, blue: 0.941, alpha: 1.0)
        let endColor = UIColor(red: 0.659, green: 0.333, blue: 0.969, alpha: 1.0)
        var sH: CGFloat = 0, sS: CGFloat = 0, sB: CGFloat = 0, sA: CGFloat = 0
        var eH: CGFloat = 0, eS: CGFloat = 0, eB: CGFloat = 0, eA: CGFloat = 0
        startColor.getHue(&sH, saturation: &sS, brightness: &sB, alpha: &sA)
        endColor.getHue(&eH, saturation: &eS, brightness: &eB, alpha: &eA)
        let h = sH + (eH - sH) * fraction
        let s = sS + (eS - sS) * fraction
        let b = sB + (eB - sB) * fraction
        return Color(hue: Double(h), saturation: Double(s), brightness: Double(b))
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<pawCount, id: \.self) { i in
                    let threshold = (i + 1) * total / pawCount
                    PawIcon(
                        filled: current >= threshold,
                        active: current > i * total / pawCount && current < threshold,
                        gradientColor: pawColor(at: i)
                    )
                }
            }
            Text("正在处理 \(current)/\(total) 条记录...")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.brandGradient)
        }
    }
}

struct PawIcon: View {
    let filled: Bool
    let active: Bool
    let gradientColor: Color
    @State private var pulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            Ellipse().frame(width: 9, height: 6.5).offset(y: 3.5)
            Circle().frame(width: 4.5, height: 4.5).offset(x: -4.5, y: -1.5)
            Circle().frame(width: 4.5, height: 4.5).offset(y: -3.2)
            Circle().frame(width: 4.5, height: 4.5).offset(x: 4.5, y: -1.5)
        }
        .foregroundColor(filled ? gradientColor : gradientColor.opacity(0.15))
        .shadow(color: filled ? gradientColor.opacity(0.35) : .clear, radius: 3, x: 0, y: 1.5)
        .scaleEffect(active ? pulse : 1.0)
        .rotationEffect(.degrees(90))
        .offset(y: active ? -3 : 0)
        .onAppear { if active { withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { pulse = 1.35 } } }
    }
}


