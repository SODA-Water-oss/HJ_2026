import SwiftUI

/// 连线锁视图 — 3×3 点阵
struct PatternLockView: View {
    let mode: PatternMode
    let onComplete: (String) -> Void
    let onCancel: () -> Void
    
    enum PatternMode {
        case set(first: String?)  // first=nil 第一轮, first=有值 第二轮确认
        case verify
    }
    
    @State private var selectedDots: [Int] = []
    @State private var currentDot: Int? = nil
    @State private var dragLocation: CGPoint = .zero
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var dotFrames: [Int: CGRect] = [:]
    @State private var firstPattern: String = ""
    
    private let dotCount = 9
    private let dotSize: CGFloat = 18
    private let lineWidth: CGFloat = 3
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            Image(systemName: "lock.shield")
                .font(.system(size: 40))
                .foregroundColor(AppTheme.brandStart)
            
            titleText
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
            
            if showError {
                Text(errorMessage)
                    .font(.appSmall)
                    .foregroundColor(.red)
            }
            
            // 3×3 点阵
            dotGrid
                .frame(width: 240, height: 240)
                .gesture(dragGesture)
            
            Spacer()
            
            Button("取消", action: onCancel)
                .font(.appBody)
                .foregroundColor(AppTheme.textSecondary)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppTheme.background)
    }
    
    @ViewBuilder
    private var titleText: some View {
        switch mode {
        case .set(first: nil):
            Text("绘制解锁图案")
        case .set(first: .some(let f)):
            Text(f == selectedDots.map(String.init).joined() ? "图案匹配 ✓" : "请再次绘制以确认")
        case .verify:
            Text("绘制图案解锁")
        }
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
                        } else if let last = selectedDots.last, let loc = dragLocationWithin(geo: geo) {
                            // Currently dragging toward the touch point
                        }
                    }
                    .stroke(AppTheme.brandStart.opacity(0.6), lineWidth: lineWidth)
                }
                
                // 9 个点
                ForEach(0..<dotCount, id: \.self) { i in
                    let isSelected = selectedDots.contains(i) || currentDot == i
                    Circle()
                        .fill(isSelected ? AppTheme.brandStart : AppTheme.border)
                        .frame(width: isSelected ? dotSize + 4 : dotSize, height: isSelected ? dotSize + 4 : dotSize)
                        .overlay(
                            Circle()
                                .stroke(isSelected ? AppTheme.brandStart : Color.clear, lineWidth: 2)
                        )
                        .position(dotPosition(i, in: geo.size))
                        .background(
                            GeometryReader { g in
                                Color.clear.onAppear {
                                    let frame = g.frame(in: .named("dotGrid"))
                                    let idx = frame.hashValue % 1000
                                    // Use the dot's position to set frames
                                }
                            }
                        )
                        .id(i)
                }
            }
            .coordinateSpace(name: "dotGrid")
        }
    }
    
    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let pos = value.location
                dragLocation = pos
                // Find which dot is near the touch point
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
                
                switch mode {
                case .set(first: nil):
                    if selectedDots.count < 4 {
                        showError = true
                        errorMessage = "至少连接 4 个点"
                        reset()
                    } else {
                        // 第一轮完成，进入第二轮确认
                        onComplete("set_first:\(pattern)")
                    }
                case .set(first: let first):
                    if pattern == first {
                        onComplete("set_confirm:\(pattern)")
                    } else {
                        showError = true
                        errorMessage = "两次绘制不一致，请重试"
                        reset()
                    }
                case .verify:
                    onComplete("verify:\(pattern)")
                }
            }
    }
    
    func reset() {
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
    
    private func dragLocationWithin(geo: GeometryProxy) -> CGPoint? {
        let x = min(max(dragLocation.x, 0), geo.size.width)
        let y = min(max(dragLocation.y, 0), geo.size.height)
        return CGPoint(x: x, y: y)
    }
}
