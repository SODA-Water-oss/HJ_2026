import SwiftUI
import Speech

// MARK: - 原生 UITextView 封装 (光标感知)
struct MatrixTextView: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = ""
    @Binding var cursorOffset: Int
    var onCursorChange: ((Int) -> Void)?

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = UIColor.white
        view.textColor = UIColor(AppTheme.textPrimary)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        view.typingAttributes = [.font: UIFont.systemFont(ofSize: 18), .paragraphStyle: paragraphStyle]
        view.font = .systemFont(ofSize: 18)
        view.layer.cornerRadius = 8
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(AppTheme.border).cgColor
        view.isScrollEnabled = true
        view.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        view.delegate = context.coordinator
        view.returnKeyType = .default
        view.autocorrectionType = .no
        view.smartQuotesType = .no
        view.tintColor = UIColor(AppTheme.brandStart)
        // 键盘工具栏「完成」按钮（UIKit 原生 UITextView 不继承 SwiftUI toolbar）
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem(title: "完成", style: .plain, target: view, action: #selector(UIResponder.resignFirstResponder))
        doneBtn.tintColor = UIColor(AppTheme.brandStart)
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 17), .foregroundColor: UIColor(AppTheme.brandStart)]
        doneBtn.setTitleTextAttributes(attrs, for: .normal)
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneBtn], animated: false)
        view.inputAccessoryView = toolbar
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        if !context.coordinator.isInternalUpdate, view.text != text {
            view.text = text
        }
        if text.isEmpty, !view.isFirstResponder {
            view.text = placeholder
            view.textColor = UIColor(Color(hex: "#B0B0B0"))
        } else if !text.isEmpty {
            view.textColor = UIColor(AppTheme.textPrimary)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UITextViewDelegate {
        var parent: MatrixTextView
        var isInternalUpdate = false
        init(_ parent: MatrixTextView) { self.parent = parent }

        func textViewDidBeginEditing(_ textView: UITextView) {
            if textView.text == parent.placeholder {
                isInternalUpdate = true
                textView.text = ""
                textView.textColor = UIColor(AppTheme.textPrimary)
                isInternalUpdate = false
            }
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            if textView.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                isInternalUpdate = true
                textView.text = parent.placeholder
                textView.textColor = UIColor(Color(hex: "#B0B0B0"))
                isInternalUpdate = false
            }
        }

        func textViewDidChange(_ textView: UITextView) {
            let content = textView.text ?? ""
            if content != parent.placeholder {
                isInternalUpdate = true
                parent.text = content
                isInternalUpdate = false
            }
        }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            let current = textView.text ?? ""
            guard let r = Range(range, in: current) else { return false }
            let newText = current.replacingCharacters(in: r, with: text)
            if newText.count > 500 && text != parent.placeholder {
                return false
            }
            return true
        }

        func textViewDidChangeSelection(_ textView: UITextView) {
            parent.onCursorChange?(textView.selectedRange.location)
        }
    }
}

// MARK: - 录音动画
struct RecordingBorder: View {
    @State private var opacity: Double = 0.3
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .stroke(AppTheme.brandGradient, lineWidth: 2.5).opacity(opacity)
            .onAppear { withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) { opacity = 1.0 } }
    }
}

struct PulsingDot: View {
    @State private var scale: CGFloat = 0.6
    var body: some View {
        Circle().fill(AppTheme.brandGradient).frame(width: 10, height: 10)
            .scaleEffect(scale).opacity(scale)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: scale)
            .onAppear { withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { scale = 1.0 } }
    }
}

struct BlinkingCursor: View {
    @State private var visible = true
    var body: some View {
        Rectangle()
            .fill(AppTheme.brandStart)
            .frame(width: 2, height: 18)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    visible.toggle()
                }
            }
    }
}

// MARK: - 旋转动画修饰符
struct SpinningIcon: ViewModifier {
    @State private var rotation: Double = 0
    
    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

struct SpinningIconCCW: ViewModifier {
    @State private var rotation: Double = 0
    func body(content: Content) -> some View {
        content
            .rotation3DEffect(.degrees(rotation), axis: (x: 0, y: 0, z: -1))
            .onAppear {
                withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}

extension View {
    func spinning() -> some View {
        modifier(SpinningIcon())
    }

    func spinningCCW() -> some View {
        modifier(SpinningIconCCW())
    }
}

// MARK: - 呼吸透明度动效修饰符
struct BreathingOpacity: ViewModifier {
    @State private var opacity: Double = 0.4
    
    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    opacity = 1.0
                }
            }
    }
}

extension View {
    func breathing() -> some View {
        modifier(BreathingOpacity())
    }
}

// MARK: - 内容录入主视图
struct AddExpenseView: View {
    @EnvironmentObject var supabaseService: SupabaseService
    @StateObject private var audioRecorder = AudioRecorder()

    @State private var inputText: String = ""
    @State private var isProcessing = false
    @State private var statusMsg = "等待录入......"
    @State private var cursorPos: Int = 0
    @State private var showPremiumAlert = false
    @State private var showManualEntry = false
    @State private var manualEntryRows: [ManualEntryRow] = [ManualEntryRow()]
    @State private var parsedItems: [GeminiService.ParsedExpense]?
    @State private var showAIConfirm = false
    @State private var lastParsedInput: String = ""

    // 语音状态跟踪
    @State private var isPressingVoice = false
    @State private var voicePressStartTime: Date?
    @State private var voicePreviewText: String = ""  // 实时语音预览
    
    // 飞入动画状态
    @State private var flyingText: String = ""          // 正在飞入的文本
    @State private var flyingProgress: CGFloat = 0      // 0=在顶部, 1=到达输入框
    @State private var flyingTextOpacity: Double = 0    // 飞入文本透明度

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                Color.clear.frame(height: 4)
                // 状态栏
                statusBar


                // 语音实时预览
                voicePreview

                inputArea
                    .overlay(
                        // 飞入动画层
                        !flyingText.isEmpty ? AnyView(flyingTextOverlay) : AnyView(EmptyView())
                    )

                Spacer()
            }
            .background(AppTheme.background)
            .onTapGesture { dismissKeyboard() }
            .onAppear {
            }
            .onDisappear {
            }
            .onReceive(audioRecorder.$transcribedText) { text in
                if audioRecorder.isRecording {
                    voicePreviewText = text
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) { HStack(spacing: 6) { Image(systemName: "square.and.pencil").font(.system(size: 17, weight: .semibold)).foregroundColor(AppTheme.brandStart); Text("录入").font(.appTitle).foregroundColor(AppTheme.textPrimary) } }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("完成") { dismissKeyboard() }
                        .foregroundColor(AppTheme.brandStart)
                }
            }
            .alert(isPresented: $showPremiumAlert) {
                Alert(title: Text("访问拒绝"), message: Text("语音录入需要高级版权限。请升级系统后使用。"), dismissButton: .default(Text("确认")))
            }
            .sheet(isPresented: $showManualEntry) {
                ManualEntryView(
                    rows: $manualEntryRows,
                    onDiscard: { manualEntryRows = [ManualEntryRow()]; showManualEntry = false },
                    onSuccess: { manualEntryRows = [ManualEntryRow()]; showManualEntry = false }
                )
            }
            .sheet(isPresented: $showAIConfirm) {
                AIConfirmView(
                    parsedItems: Binding(
                        get: { parsedItems ?? [] },
                        set: { parsedItems = $0 }
                    ),
                    onDiscard: { inputText = ""; parsedItems = nil; showAIConfirm = false },
                    onSuccess: { inputText = ""; parsedItems = nil; showAIConfirm = false }
                )
            }
        }
        .navigationViewStyle(.stack)
    }

    // MARK: - UI Subviews

    @ViewBuilder
    private var statusBar: some View {
       HStack(spacing: 8) {
            Group {
            if statusMsg == "等待录入......" {
                Image(systemName: "hourglass.circle").font(.system(size: 17))
                    .foregroundStyle(AppTheme.brandGradient)
                    .spinningCCW()
            } else if audioRecorder.isRecording {
                PulsingDot().frame(width: 24, height: 24)
            } else if statusMsg == "请录入解析内容......" {
                Image(systemName: "pencil.and.outline")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.brandGradient)
                    .breathing()
            } else if statusMsg == "解析中......" {
                Image(systemName: "arrow.clockwise.circle")
                    .font(.system(size: 17))
                    .foregroundStyle(AppTheme.brandGradient)
                    .spinning()
            } else if statusMsg.hasPrefix("未解析出有效") {
               Image(systemName: "xmark.circle")
                   .font(.system(size: 17))
                   .foregroundStyle(AppTheme.brandGradient)
            } else if statusMsg.hasPrefix("解析失败") || statusMsg.hasPrefix("错误") {
                Rectangle()
                    .fill(AppTheme.brandGradient)
                    .frame(width: 16, height: 16)
                    .cornerRadius(3)
            }
            }
            .frame(width: 24, height: 24)
            Text(statusMsg)
                .font(.system(size: 17))
                .foregroundColor(statusTextColor)
        }
        .padding(.leading, 38).padding(.trailing, 16).padding(.vertical, 16).frame(maxWidth: .infinity, alignment: .leading)
        .background(AppTheme.brandGradient.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: AppTheme.cardShadow, radius: 4, x: 0, y: 2)
        .padding(.horizontal, 16)
    }

    private var statusTextColor: Color {
        if statusMsg == "请录入解析内容......" { return AppTheme.brandEnd }
        if statusMsg.hasPrefix("未解析出有效") { return AppTheme.brandEnd }
        if statusMsg == "等待录入......" { return AppTheme.brandEnd }
        if isProcessing { return AppTheme.brandEnd }
        if statusMsg == "收音中......" { return AppTheme.brandEnd }
        if audioRecorder.isRecording { return AppTheme.brandEnd }
        return AppTheme.textSecondary
    }


    // MARK: - 语音实时预览
    @ViewBuilder
    private var voicePreview: some View {
        if audioRecorder.isRecording {
            HStack(spacing: 8) {
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        HStack(spacing: 0) {
                            Text(voicePreviewText)
                                .font(.system(size: 17))
                                .foregroundColor(AppTheme.textPrimary)
                            BlinkingCursor()
                                .id("voiceEnd")
                        }
                        .onChange(of: voicePreviewText) { _ in
                            withAnimation { proxy.scrollTo("voiceEnd", anchor: .trailing) }
                        }
                    }
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .shadow(color: AppTheme.brandStart.opacity(0.15), radius: 6, x: 0, y: 2)
            )
            .overlay(
                Group {
                    if audioRecorder.isRecording {
                        RecordingBorder()
                    }
                }
            )
            .padding(.horizontal, 16)
            .transition(.asymmetric(
                insertion: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92, anchor: .top)),
                removal: .move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.92, anchor: .top))
            ))
            .animation(.interpolatingSpring(mass: 0.7, stiffness: 160, damping: 13), value: audioRecorder.isRecording)
        }
    }

    // MARK: - 输入区域（带弹簧动画配合预览条）
    @ViewBuilder
    private var inputArea: some View {
        VStack(spacing: 16) {
            MatrixTextView(
                text: $inputText,
                placeholder: "内容录入区......",
                cursorOffset: $cursorPos,
                onCursorChange: { cursorPos = $0 }
            )
            .frame(minHeight: audioRecorder.isRecording ? 80 : 250)
            .animation(.interpolatingSpring(mass: 0.8, stiffness: 180, damping: 16), value: audioRecorder.isRecording)
            HStack {
                if inputText.count > 500 { Text("您的输入已超上限!").font(.system(size: 15)).foregroundColor(AppTheme.brandStart) }
                Spacer()
                Text("\(inputText.count)/500").font(.system(size: 13)).foregroundColor(inputText.count > 500 ? AppTheme.brandStart : AppTheme.textTertiary)
            }.padding(.horizontal, 4)

            // 按钮行
            // 手动记账按钮
            Button(action: { showManualEntry = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                    Text("手动记账")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppSecondaryButtonStyle())
            .disabled(isProcessing || audioRecorder.isRecording)
            .opacity((isProcessing || audioRecorder.isRecording) ? 0.5 : 1.0)
            .padding(.bottom, 4)

            let hasContent = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            HStack(spacing: 12) {
                if hasContent {
                    parseButton
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .leading).combined(with: .opacity)
                        ))
                }
                voiceButton
            }
            .animation(.interpolatingSpring(mass: 0.7, stiffness: 160, damping: 13), value: hasContent)
        }
        .padding(20).background(Color.white).cornerRadius(16)
        .shadow(color: AppTheme.cardShadow, radius: 8, x: 0, y: 4)
        .padding(.horizontal, 16)
        .animation(.interpolatingSpring(mass: 0.8, stiffness: 180, damping: 16), value: audioRecorder.isRecording)
    }

    // MARK: - 飞入文本动画层
    @ViewBuilder
    private var flyingTextOverlay: some View {
        GeometryReader { geometry in
            Text(flyingText)
                .font(.system(size: 17, weight: .medium))
                .foregroundColor(AppTheme.brandStart)
                .lineLimit(1)
                .offset(y: -geometry.size.height * flyingProgress)
                .opacity(flyingTextOpacity)
                .scaleEffect(1.0 - flyingProgress * 0.4, anchor: .topLeading)
                .position(x: geometry.size.width / 2, y: 8)
        }
        .allowsHitTesting(false)
        .transition(.opacity.animation(.easeOut(duration: 0.2)))
    }

    @ViewBuilder
    private var parseButton: some View {
        Button(action: {
            let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !t.isEmpty, t == lastParsedInput.trimmingCharacters(in: .whitespacesAndNewlines), parsedItems != nil, parsedItems?.isEmpty == false {
                showAIConfirm = true
            } else {
                doParse()
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "text.cursor")
                Text("解析内容")
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppPrimaryButtonStyle())
        .disabled(isProcessing || audioRecorder.isRecording)
        .opacity((isProcessing || audioRecorder.isRecording) ? 0.5 : 1.0)
    }

    @ViewBuilder
    private var voiceButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "mic.fill").foregroundColor(.white)
            Text("按住报账").foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .font(.appBodyMedium)
        .padding(.horizontal, 20).padding(.vertical, 12)
        .background(audioRecorder.isRecording ? AppTheme.brandGradient : AppTheme.brandGradient)
        .cornerRadius(10)
        .opacity(audioRecorder.isRecording ? 0.7 : (isProcessing ? 0.5 : 1.0))
        .disabled(isProcessing || inputText.count > 500)
        .overlay(
            audioRecorder.isRecording
                ? RoundedRectangle(cornerRadius: 10).stroke(AppTheme.brandGradient, lineWidth: 2).opacity(0.7)
                : nil
        )
        .gesture(voicePressGesture)
        .allowsHitTesting(!isProcessing)
    }

    // MARK: - 语音手势 (按住0.5秒触发，松开停止)
    private var voicePressGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { _ in
                // 手指按下，开始计时
                if !isPressingVoice && !audioRecorder.isRecording && !isProcessing {
                    isPressingVoice = true
                    voicePressStartTime = Date()
                    // 启动 Timer 检查是否达到 0.3 秒
                    Task { await self.voiceHoldTimer() }
                }
            }
            .onEnded { _ in
                // 手指松开
                isPressingVoice = false
                if audioRecorder.isRecording {
                    stopRecording()
                }
            }
    }

    // MARK: - 按住计时器
    private func voiceHoldTimer() async {
        // 等待 0.3 秒
        try? await Task.sleep(nanoseconds: 300_000_000)
        // 如果用户仍然按着且没有开始录音，启动录音
        if isPressingVoice, !audioRecorder.isRecording, !isProcessing {
            startRecording()
        }
    }

    // MARK: - 解析文本
    func doParse() {
        let t = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else {
            statusMsg = "请录入解析内容......"
            return
        }

        isProcessing = true
        statusMsg = "解析中......"
        dismissKeyboard()

        let capturedInput = t

        Task {
            let items: [GeminiService.ParsedExpense]
            do {
                items = try await GeminiService.shared.parseExpense(input: capturedInput)
            } catch {
                await MainActor.run {
                    statusMsg = "解析失败: \(error.localizedDescription)"
                    isProcessing = false
                }
                return
            }

            await MainActor.run {
                isProcessing = false
                if items.isEmpty {
                    statusMsg = "未解析出有效支出~"
                } else {
                    lastParsedInput = inputText
                    parsedItems = items
                    showAIConfirm = true
                    statusMsg = "等待录入......"
                }
            }
        }
    }

    // MARK: - 录音
    func startRecording() {
        guard supabaseService.userProfile?.isPremium == true else {
            showPremiumAlert = true
            return
        }
        guard !audioRecorder.isRecording else { return }

        voicePreviewText = ""
        let sp = SFSpeechRecognizer.authorizationStatus()
        let rp = AVAudioSession.sharedInstance().recordPermission
        if sp == .authorized && rp == .granted {
            audioRecorder.startRecording()
            statusMsg = "收音中......"
        } else {
            Task {
                if await audioRecorder.requestPermission() {
                    isPressingVoice = false
                    statusMsg = "请录入解析内容......"
                } else {
                    statusMsg = "错误：麦克风权限被拒绝"
                }
            }
        }
    }

    func stopRecording() {
        guard audioRecorder.isRecording else { return }

        let rawText = audioRecorder.transcribedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let elapsed = voicePressStartTime.map { Date().timeIntervalSince($0) } ?? 0

        audioRecorder.stopRecording()

        // 按住时间不足 0.3 秒的录音不录入内容
        if elapsed >= 0.3, !rawText.isEmpty {
            // 触发飞入动画：预览条文本从顶部飞向输入框
            flyingText = rawText
            flyingProgress = 0
            flyingTextOpacity = 1.0
            voicePreviewText = ""  // 预览条立即消失
            
            // 第一阶段：飞入
            withAnimation(.interpolatingSpring(mass: 0.5, stiffness: 120, damping: 10)) {
                flyingProgress = 0.85
            }
            
            // 第二阶段：淡出并写入输入框
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                let text = flyingText
                let pos = min(max(cursorPos, 0), inputText.count)
                let idx = inputText.index(inputText.startIndex, offsetBy: pos)
                inputText.insert(contentsOf: text, at: idx)
                cursorPos = pos + text.count
                
                withAnimation(.easeOut(duration: 0.15)) {
                    flyingTextOpacity = 0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    flyingText = ""
                    flyingProgress = 0
                }
            }
        } else {
            voicePreviewText = ""
        }
        voicePressStartTime = nil
        statusMsg = "等待录入......"
    }
}

// MARK: - 键盘关闭工具
extension View {
    func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
