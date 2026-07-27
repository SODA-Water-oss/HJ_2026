import SwiftUI

struct UserSettingsView: View {
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    
    @EnvironmentObject var supabaseService: SupabaseService
    @EnvironmentObject var authManager: AuthManager
    @State private var showLogoutAlert = false
    @State private var showCurrencyPicker = false
    
    private let currencyOptions: [(name: String, symbol: String)] = [("人民币", "¥"), ("美元", "$"), ("欧元", "€"), ("英镑", "£")]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    Color.clear.frame(height: 4)
                    
                    // MARK: - 分类设置
                    NavigationLink(destination: CategoryView()) {
                        HStack {
                            Image(systemName: "tag")
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.brandStart)
                                .frame(width: 24)
                            Text("分类设置")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 13))
                                .foregroundColor(AppTheme.textTertiary)
                        }
                        .padding(16)
                    }
                    .frame(minHeight: 52)
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
                            Text("货币设置")
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                           Spacer()
                            Button(action: { showCurrencyPicker = true }) {
                                HStack(spacing: 8) {
                                    if let current = currencyOptions.first(where: { $0.symbol == currencySymbol }) {
                                        Text(current.name + " " + current.symbol)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(AppTheme.brandStart)
                                    } else {
                                        Text(currencySymbol)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(AppTheme.brandStart)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(AppTheme.background)
                                .cornerRadius(8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(16)
                    }
                    .frame(minHeight: 52)
                    .background(Color.white)
                    .cornerRadius(12)
                    .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
                    .padding(.horizontal, 16)
                    .confirmationDialog("选择货币", isPresented: $showCurrencyPicker, titleVisibility: .visible) {
                        ForEach(currencyOptions, id: \.symbol) { option in
                            Button(option.name + " (" + option.symbol + ")") {
                                currencySymbol = option.symbol
                            }
                        }
                        Button("取消", role: .cancel) { }
                    }
                    
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
                                    .foregroundColor(AppTheme.brandStart)
                                    .frame(width: 24)
                                Text("退出登录")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.brandStart)
                                Spacer()
                            }
                            .padding(16)
                        }
                    }
                    .frame(minHeight: 52)
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
                        desc: "在「我的」页面可以为账本和分析页单独设置4位数字密码锁。开启后每次进入需输入密码。"
                    )
                    
                    helpCard(
                        icon: "square.and.arrow.up",
                        title: "导出数据",
                        desc: "在账本页右上角菜单选择「导出当前账本」，导出筛选后的记录为CSV文件。"
                    )
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
