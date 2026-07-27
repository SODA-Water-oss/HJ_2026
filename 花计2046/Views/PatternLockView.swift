import SwiftUI

/// 连线锁视图 — 3×3 点阵，内部处理两轮确认
struct PatternLockView: View {
    let isVerifyMode: Bool
    let onComplete: (String) -> Void
    let onCancel: () -> Void
    
    enum SetupPhase { case firstRound, secondRound }
    
    @State private var phase: SetupPhase = .firstRound
    @State private var firstPattern: String = ""
    @State private var selectedDots: [Int] = []
    @State private var currentDot: Int? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var hasDrawn = false
    @State private var showFirstConfirm = false
    @State private var patternDisplay: String = ""
    @State private var displayDots: [Int] = []
    
    private let dotCount = 9
    private let dotSize: CGFloat = 18
    private let lineWidth: CGFloat = 3
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 36))
                .foregroundColor(AppTheme.brandStart)
                .padding(.bottom, 8)
            
            Text(isVerifyMode ? "绘制图案解锁"
                 : showFirstConfirm ? "确认图案后继续"
                 : phase == .secondRound ? "请再次绘制以确认"
                 : "绘制解锁图案")
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.bottom, 4)
            
            if showError {
                Text(errorMessage)
                    .font(.custom("PingFangSC-Regular", size: 14))
                    .foregroundColor(AppTheme.brandStart)
                    .padding(.bottom, 4)
            }
            
            // 3×3 点阵
            dotGrid
                .frame(width: 240, height: 240)
                .gesture(dragGesture)
            
            if !isVerifyMode && showFirstConfirm {
                HStack(spacing: 20) {
                    Button(action: {
                        showFirstConfirm = false
                        selectedDots = []
                        currentDot = nil
                    }) {
                        Text("重绘")
                            .font(.appBody)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(AppTheme.border.opacity(0.5))
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        firstPattern = patternDisplay
                        phase = .secondRound
                        showFirstConfirm = false
                        selectedDots = []
                        currentDot = nil
                    }) {
                        Text("继续")
                            .font(.appBody)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [AppTheme.brandStart, AppTheme.brandEnd]),
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .cornerRadius(8)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.top, 8)
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
    
    private var dotGrid: some View {
        GeometryReader { geo in
            ZStack {
                // 连线
                if !selectedDots.isEmpty {
                    Path { path in
                        for i in 0..<selectedDots.count {
                            let pos = dotPosition(selectedDots[i], in: geo.size)
                            if i == 0 { path.move(to: pos) }
                            else { path.addLine(to: pos) }
                        }
                        if let cur = currentDot {
                            path.addLine(to: dotPosition(cur, in: geo.size))
                        } else if !selectedDots.isEmpty {
                            path.addLine(to: dotPosition(selectedDots.last!, in: geo.size))
                        }
                    }
                    .stroke(AppTheme.brandStart.opacity(0.6), lineWidth: lineWidth)
                }
                
                // 9 个点
                ForEach(0..<dotCount, id: \.self) { i in
                    let isSelected = selectedDots.contains(i) || currentDot == i
                    Circle()
                        .fill(isSelected ? AppTheme.brandStart : AppTheme.border)
                        .frame(width: isSelected ? dotSize + 6 : dotSize,
                               height: isSelected ? dotSize + 6 : dotSize)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? AppTheme.brandStart : Color.clear, lineWidth: 2)
                        )
                        .position(dotPosition(i, in: geo.size))
                }
            }
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard !showError else { return }
                // 在第一轮确认等待状态，重新开始绘制
                if showFirstConfirm {
                    showFirstConfirm = false
                    selectedDots = []
                    currentDot = nil
                }
                let pos = value.location
                dragLocation = pos
                if let dot = nearestDot(to: pos, in: CGSize(width: 240, height: 240), exclude: selectedDots) {
                    if !selectedDots.contains(dot) {
                        selectedDots.append(dot)
                    }
                    currentDot = dot
                    showError = false
                } else {
                    currentDot = nil
                }
            }
            .onEnded { _ in
                currentDot = nil
                let pattern = selectedDots.map(String.init).joined()
                
                if isVerifyMode {
                    if selectedDots.count < 4 {
                        showError = true
                        errorMessage = "至少连接 4 个点"
                        reset()
                    } else {
                        onComplete(pattern)
                    }
                } else {
                    switch phase {
                    case .firstRound:
                        if selectedDots.count < 4 {
                            showError = true
                            errorMessage = "至少连接 4 个点"
                            reset()
                        } else {
                            patternDisplay = pattern
                            displayDots = selectedDots
                            showFirstConfirm = true
                            hasDrawn = true
                        }
                    case .secondRound:
                        if pattern == firstPattern {
                            withAnimation { showError = false }
                            onComplete(firstPattern)
                        } else if pattern.count >= 4 {
                            showError = true
                            errorMessage = "两次绘制不一致，请重新设置"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                                phase = .firstRound
                                firstPattern = ""
                                hasDrawn = false
                                showFirstConfirm = false
                                showError = false
                                errorMessage = ""
                            }
                            reset()
                        } else {
                            reset()
                        }
                    }
                }
            }
    }
    
    private func reset() {
        selectedDots = []
        currentDot = nil
    }
    
    private func dotPosition(_ index: Int, in size: CGSize) -> CGPoint {
        let row = index / 3
        let col = index % 3
        let spacing = size.width / 3
        return CGPoint(x: spacing * CGFloat(col) + spacing / 2,
                      y: spacing * CGFloat(row) + spacing / 2)
    }
    
    private func nearestDot(to point: CGPoint, in size: CGSize, exclude: [Int]) -> Int? {
        let threshold: CGFloat = 30
        var nearest: (index: Int, distance: CGFloat)? = nil
        
        for i in 0..<dotCount where !exclude.contains(i) {
            let pos = dotPosition(i, in: size)
            let dist = hypot(point.x - pos.x, point.y - pos.y)
            if dist < threshold {
                if nearest == nil || dist < nearest!.distance {
                    nearest = (i, dist)
                }
            }
        }
        return nearest?.index
    }
}
