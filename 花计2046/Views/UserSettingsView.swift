import SwiftUI

struct UserSettingsView: View {
    @AppStorage("default_category") private var defaultCategory = "餐饮"
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    @AppStorage("show_daily_parse_count") private var showDailyParseCount = true
    
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutAlert = false
    
    private let expenseCategories = ["餐饮", "交通", "购物", "娱乐", "住房", "日用", "服饰", "通讯", "医疗", "教育", "其他"]
    private let currencyOptions = ["¥", "$", "€", "£"]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)
                    
                    // MARK: - 默认分类
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "tag")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("默认分类")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $defaultCategory) {
                                ForEach(expenseCategories, id: \.self) { cat in
                                    Text(cat).tag(cat)
                                }
                            }
                            .pickerStyle(.menu)
                            .tint(AppTheme.textSecondary)
                        }
                        .padding(16)
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    // MARK: - 货币符号
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "dollarsign.circle")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("货币符号")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Picker("", selection: $currencySymbol) {
                                ForEach(currencyOptions, id: \.self) { sym in
                                    Text(sym).tag(sym)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 160)
                        }
                        .padding(16)
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    // MARK: - 每日解析次数显示
                    VStack(spacing: 0) {
                        HStack {
                            Image(systemName: "number")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("每日解析次数显示")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Toggle("", isOn: $showDailyParseCount)
                                .toggleStyle(.switch)
                                .tint(AppTheme.brandStart)
                        }
                        .padding(16)
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    // MARK: - 使用帮助
                    VStack(spacing: 0) {
                        NavigationLink(destination: HelpView()) {
                            HStack {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 17))
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 24)
                                Text("使用帮助")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(16)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    // MARK: - 退出登录
                    VStack(spacing: 0) {
                        Button(action: { showLogoutAlert = true }) {
                            HStack {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 17))
                                    .foregroundColor(.red)
                                    .frame(width: 24)
                                Text("退出登录")
                                    .font(.appBody)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    
                    Spacer(minLength: 32)
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("用户设置")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
        .alert("退出登录", isPresented: $showLogoutAlert) {
            Button("取消", role: .cancel) { }
            Button("确认退出", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("是否确定退出当前登录？")
        }
    }
}

// MARK: - 使用帮助页
struct HelpView: View {
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    Color.clear.frame(height: 4)
                    
                    helpCard(
                        icon: "rectangle.and.pencil.and.ellipsis",
                        title: "录入与解析",
                        desc: "在录入页面输入文字，点击「解析内容」即可自动识别每笔收支。\n支持连续输入多条，例如：星巴克35 地铁4 超市68.5"
                    )
                    
                    helpCard(
                        icon: "mic",
                        title: "语音录入",
                        desc: "按住「按住报账」按钮说话，松手后自动识别文字并解析。需要麦克风权限。"
                    )
                    
                    helpCard(
                        icon: "iphone.radiowaves.left.and.right",
                        title: "摇一摇清除",
                        desc: "录入页面摇动手机可快速清除输入内容。第一次摇动显示提示，第二次直接清除。"
                    )
                    
                    helpCard(
                        icon: "lock.shield",
                        title: "页面锁",
                        desc: "在「我的」页面可以为账本页和分析页单独设置4位数字密码锁。开启后每次进入需输入密码。"
                    )
                    
                    helpCard(
                        icon: "square.and.arrow.up",
                        title: "导出数据",
                        desc: "在账本页右上角菜单选择「导出当前账本」，导出筛选后的记录为CSV文件。"
                    )
                    
                    helpCard(
                        icon: "number",
                        title: "每日解析次数",
                        desc: "每个账户每天可免费解析30次。解析成功并「进账」后消耗次数，放弃解析不计次数。次日自动恢复。"
                    )
                }
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.brandStart)
                        Text("使用帮助")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(AppTheme.textPrimary)
                    }
                }
            }
        }
    }
    
    private func helpCard(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundColor(AppTheme.brandStart)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.appBodyMedium)
                    .foregroundColor(AppTheme.textPrimary)
                Text(desc)
                    .font(.appSmall)
                    .foregroundColor(AppTheme.textSecondary)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }
}
