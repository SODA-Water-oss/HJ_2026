import SwiftUI

struct AgentConfigSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var manager = AgentConfigManager.shared

    @State private var selectedProviderID: String
    @State private var model: String
    @State private var apiKey: String
    @State private var baseURL: String
    @State private var isVerifying = false
    @State private var errorMessage = ""
    @State private var successMessage = ""
    @State private var showKey = false
    @State private var showClearConfirm = false

    init() {
        let current = AgentConfigManager.shared.config
        let provider = current?.provider ?? AgentProvider.all.first
        _selectedProviderID = State(initialValue: current?.providerID ?? provider?.id ?? "")
        _model = State(initialValue: current?.model ?? provider?.defaultModel ?? "")
        _apiKey = State(initialValue: current?.apiKey ?? "")
        _baseURL = State(initialValue: current?.baseURL ?? provider?.baseURL ?? "")
    }

    private var selectedProvider: AgentProvider? {
        AgentProvider.find(id: selectedProviderID)
    }

    private var modelOptions: [String] {
        AgentProvider.modelOptions[selectedProviderID] ?? []
    }

    private var canSave: Bool {
        !selectedProviderID.isEmpty &&
        !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !isVerifying
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    // 当前状态
                    HStack(spacing: 10) {
                        Image(systemName: manager.hasCustomAgent ? "checkmark.circle.fill" : "circle.dashed")
                            .font(.system(size: 20))
                            .foregroundColor(manager.hasCustomAgent ? Color(hex: "#10B981") : AppTheme.textTertiary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(manager.hasCustomAgent ? "已配置自己的智能体" : "未配置，使用默认智能体")
                                .font(.appBodyMedium)
                                .foregroundColor(AppTheme.textPrimary)
                            if let config = manager.config {
                                Text(config.displayName)
                                    .font(.appSmall)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(AppTheme.background)
                    .cornerRadius(10)

                    Text("配置后，AI 解析、语音入账和最近收支评价会优先使用你的智能体；如果配置异常，会临时使用默认智能体并提示你重新配置。")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineSpacing(3)

                    // 服务商
                    VStack(alignment: .leading, spacing: 8) {
                        Text("智能体模型")
                            .font(.appBodyMedium)
                            .foregroundColor(AppTheme.textPrimary)

                        Menu {
                            ForEach(AgentProvider.all) { provider in
                                Button {
                                    changeProvider(provider)
                                } label: {
                                    if provider.id == selectedProviderID {
                                        Label(provider.name, systemImage: "checkmark")
                                    } else {
                                        Text(provider.name)
                                    }
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedProvider?.name ?? "请选择智能体")
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                        }

                        HStack(spacing: 10) {
                            Menu {
                                ForEach(modelOptions, id: \.self) { option in
                                    Button {
                                        model = option
                                        errorMessage = ""
                                    } label: {
                                        if option == model {
                                            Label(option, systemImage: "checkmark")
                                        } else {
                                            Text(option)
                                        }
                                    }
                                }
                            } label: {
                                HStack {
                                    Text(model.isEmpty ? "选择模型" : model)
                                        .font(.appBody)
                                        .foregroundColor(model.isEmpty ? AppTheme.textTertiary : AppTheme.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.up.chevron.down")
                                        .font(.system(size: 12))
                                        .foregroundColor(AppTheme.textTertiary)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                            }

                            TextField("自定义模型", text: $model)
                                .font(.appBody)
                                .foregroundColor(AppTheme.textPrimary)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(Color.white)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                        }
                    }

                    // API Key
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.appBodyMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        HStack(spacing: 10) {
                            if showKey {
                                TextField("输入你的 API Key", text: $apiKey)
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            } else {
                                SecureField("输入你的 API Key", text: $apiKey)
                                    .font(.appBody)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                            }
                            Button(action: { showKey.toggle() }) {
                                Image(systemName: showKey ? "eye.slash.fill" : "eye.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(AppTheme.textTertiary)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(Color.white)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                        Text("Key 只保存在本机钥匙串中，不会上传到云端。")
                            .font(.appTiny)
                            .foregroundColor(AppTheme.textTertiary)
                    }

                    // 接口地址
                    VStack(alignment: .leading, spacing: 8) {
                        Text("接口地址")
                            .font(.appBodyMedium)
                            .foregroundColor(AppTheme.textPrimary)
                        TextField("https://.../chat/completions", text: $baseURL)
                            .font(.appBody)
                            .foregroundColor(AppTheme.textPrimary)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color.white)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppTheme.border, lineWidth: 1))
                    }

                    if !errorMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15))
                            Text(errorMessage)
                                .font(.system(size: 15))
                        }
                        .foregroundColor(Color(hex: "#EF4444"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#FEF2F2"))
                        .cornerRadius(8)
                    }

                    if !successMessage.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                            Text(successMessage)
                                .font(.system(size: 15))
                        }
                        .foregroundColor(Color(hex: "#10B981"))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#ECFDF5"))
                        .cornerRadius(8)
                    }

                    Button(action: saveAndVerify) {
                        Text(isVerifying ? "验证中..." : "保存并验证")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppPrimaryButtonStyle())
                    .disabled(!canSave)
                    .opacity(canSave ? 1.0 : 0.5)

                    if manager.hasCustomAgent {
                        Button(action: { showClearConfirm = true }) {
                            Text("清除智能体配置")
                                .font(.appBody)
                                .foregroundColor(Color(hex: "#EF4444"))
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("智能体配置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Text("关闭")
                            .foregroundColor(AppTheme.brandStart)
                    }
                    .buttonStyle(.plain)
                }
            }
            .alert("清除智能体配置", isPresented: $showClearConfirm) {
                Button("取消", role: .cancel) { }
                Button("确认清除", role: .destructive) {
                    manager.clear()
                    errorMessage = ""
                    successMessage = "已恢复为默认智能体"
                }
            } message: {
                Text("清除后将恢复使用 App 默认智能体，需要重新配置才能继续使用自己的智能体。")
            }
        }
    }

    private func changeProvider(_ provider: AgentProvider) {
        selectedProviderID = provider.id
        baseURL = provider.baseURL
        model = provider.defaultModel
        errorMessage = ""
        successMessage = ""
    }

    private func saveAndVerify() {
        guard canSave else { return }
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        let draft = AgentConfig(
            providerID: selectedProviderID,
            model: trimmedModel,
            apiKey: trimmedKey,
            baseURL: trimmedURL,
            updatedAt: Date()
        )

        isVerifying = true
        errorMessage = ""
        successMessage = ""

        Task {
            do {
                try await AgentConfigManager.shared.verify(draft)
                AgentConfigManager.shared.save(draft)
                await MainActor.run {
                    isVerifying = false
                    successMessage = "配置验证通过，已保存"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    isVerifying = false
                    errorMessage = (error as? AgentConfigError)?.errorDescription ?? error.localizedDescription
                }
            }
        }
    }
}
