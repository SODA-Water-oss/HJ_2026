import SwiftUI
 
struct LockScreenView: View {
    let pageName: String
    let mode: String  // "pin" or "pattern"
    let onVerifyPin: (String) -> Bool
    let onVerifyPattern: (String) -> Bool
    let onCancel: () -> Void
    
    @State private var pin = ""
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        if mode == "pattern" {
            ZStack {
                PatternLockView(
                    isVerifyMode: true,
                    onComplete: { pattern in
                        if onVerifyPattern(pattern) {
                        } else {
                            showError = true
                            errorMessage = "图案错误，请重试"
                        }
                    },
                    onCancel: onCancel
                )
                
                if showError {
                    VStack {
                        Spacer()
                        Text(errorMessage)
                            .font(.appSmall)
                            .foregroundColor(AppTheme.brandStart)
                            .padding(.bottom, 80)
                    }
                }
            }
        } else {
            // PIN mode
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
                
                HStack(spacing: 16) {
                    ForEach(0..<4, id: \.self) { i in
                        Circle()
                            .fill(i < pin.count ? AppTheme.brandStart : AppTheme.border)
                            .frame(width: 16, height: 16)
                    }
                }
                .padding(.vertical, 8)
                
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
                
                Spacer()
                
                if showError {
                    Text(errorMessage)
                        .font(.appSmall)
                        .foregroundColor(AppTheme.brandStart)
                }
                
                Button("取消", action: onCancel)
                    .font(.appBody)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.bottom, 32)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(AppTheme.background)
        }
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
            if onVerifyPin(pin) {
                // Verified
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
