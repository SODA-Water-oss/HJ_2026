import SwiftUI

struct PinSetupView: View {
    @Binding var newPin: String
    var onConfirm: () -> Void
    var onCancel: () -> Void
    
    @State private var pin = ""
    @State private var confirmPin = ""
    @State private var isFirstRound = true
    @State private var showError = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "#7C3AED"))
            
            Text(isFirstRound ? "设置页面锁密码" : "请再次输入密码")
                .font(.appTitle)
                .foregroundColor(AppTheme.textPrimary)
            
            Text(isFirstRound ? "请设置4位数字密码" : "请再次输入以确认")
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
            
            // 4位圆点
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < (isFirstRound ? pin.count : confirmPin.count) && !isFirstRound ? Color.green : (i < pin.count ? Color(hex: "#7C3AED") : AppTheme.border))
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.vertical, 8)
            
            if showError {
                Text(showError ? "两次密码不一致，请重新输入" : "")
                    .font(.appSmall)
                    .foregroundColor(Color(hex: "#7C3AED"))
            }
            
            // 数字键盘
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(1..<4, id: \.self) { col in
                            numberButton("\(row * 3 + col)")
                        }
                    }
                }
                HStack(spacing: 12) {
                    Spacer().frame(width: 76)
                    numberButton("0")
                    backspaceButton
                }
            }
            
            if !isFirstRound {
                Button(action: {
                    pin = ""
                    confirmPin = ""
                    isFirstRound = true
                    showError = false
                }) {
                    Text("重新设置")
                        .font(.appSmall)
                        .foregroundColor(AppTheme.textSecondary)
                }
            }
            
            Spacer().frame(height: 16)
            
            Button("取消", action: onCancel)
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
        .onChange(of: pin) { _, newValue in
            if newValue.count == 4 {
                if isFirstRound {
                    confirmPin = pin
                    pin = ""
                    isFirstRound = false
                    showError = false
                } else if pin == confirmPin {
                    newPin = pin
                    onConfirm()
                } else {
                    showError = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                        pin = ""
                        confirmPin = ""
                        isFirstRound = true
                        showError = false
                    }
                }
            }
        }

    }
    
    private func numberButton(_ text: String) -> some View {
        Button(action: {
            guard pin.count < 4 else { return }
            pin.append(text)
            showError = false
        }) {
            Text(text)
                .font(.system(size: 28, weight: .medium))
                .foregroundColor(AppTheme.textPrimary)
                .frame(width: 76, height: 56)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        }
    }
    
    private var backspaceButton: some View {
        Button(action: { if !pin.isEmpty { pin.removeLast() } }) {
            Image(systemName: "delete.left")
                .font(.system(size: 24))
                .foregroundColor(AppTheme.textSecondary)
                .frame(width: 76, height: 56)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        }
    }
}
