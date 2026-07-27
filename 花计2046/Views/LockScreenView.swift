import SwiftUI

struct LockScreenView: View {
    let pageName: String
    let onVerify: (String) -> Bool
    let onCancel: () -> Void
    
    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.fill")
                .font(.system(size: 48))
                .foregroundColor(AppTheme.brandStart)
            
            Text("\(pageName)已锁定")
                .font(.appTitle)
                .foregroundColor(AppTheme.textPrimary)
            
            Text("请输入密码进入")
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
            
            // PIN 圆点显示
            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { i in
                    Circle()
                        .fill(i < pin.count ? AppTheme.brandStart : AppTheme.border)
                        .frame(width: 16, height: 16)
                }
            }
            .padding(.vertical, 8)
            
            if showError {
                Text(errorMessage)
                    .font(.appSmall)
                    .foregroundColor(.red)
            }
            
            // 数字键盘
            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { row in
                    HStack(spacing: 12) {
                        ForEach(1..<4, id: \.self) { col in
                            let num = row * 3 + col
                            numberButton("\(num)")
                        }
                    }
                }
                HStack(spacing: 12) {
                    Spacer().frame(width: 76)
                    numberButton("0")
                    backspaceButton
                }
            }
            
            Spacer()
            
            Button("取消", action: onCancel)
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
    
    private func numberButton(_ text: String) -> some View {
        Button(action: { tapNumber(text) }) {
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
    
    private func tapNumber(_ num: String) {
        guard pin.count < 4 else { return }
        pin.append(num)
        
        if pin.count == 4 {
            if onVerify(pin) {
                // Verified, dismiss
            } else {
                showError = true
                errorMessage = "密码错误，请重试"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    pin = ""
                }
            }
        }
    }
}
