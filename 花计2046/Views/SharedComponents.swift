import SwiftUI

// MARK: - 通用组件（从各业务 View 中抽取，供多处复用）

/// 带「完成」键盘工具栏的多行文本编辑器
struct KeyboardDoneTextEditor: UIViewRepresentable {
    @Binding var text: String
    var font: UIFont = .systemFont(ofSize: 17)

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.font = font
        view.textColor = UIColor(AppTheme.textPrimary)
        view.backgroundColor = UIColor.white
        view.layer.cornerRadius = 7
        view.layer.borderWidth = 1
        view.layer.borderColor = UIColor(AppTheme.border).cgColor
        view.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        view.isScrollEnabled = true
        view.delegate = context.coordinator
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem(title: "完成", style: .plain, target: view, action: #selector(UIResponder.resignFirstResponder))
        doneBtn.tintColor = UIColor(AppTheme.brandStart)
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneBtn], animated: false)
        view.inputAccessoryView = toolbar
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        view.text = text
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    class Coordinator: NSObject, UITextViewDelegate {
        @Binding var text: String
        init(text: Binding<String>) { _text = text }
        func textViewDidChange(_ textView: UITextView) {
            text = textView.text ?? ""
        }
    }
}

/// 金额输入框（限制两位小数、上限 9999999.99）
struct AmountTextField: UIViewRepresentable {
    @Binding var amount: Double
    @AppStorage("currency_symbol") private var currencySymbol = "¥"
    var font: UIFont = .systemFont(ofSize: 17)
    var textAlignment: NSTextAlignment = .left
    var textColor: UIColor = UIColor(AppTheme.textPrimary)

    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.backgroundColor = UIColor.white
        tf.keyboardType = .decimalPad
        tf.textAlignment = textAlignment
        tf.font = font
        tf.textColor = textColor
        tf.delegate = context.coordinator
        tf.setContentHuggingPriority(.defaultLow, for: .horizontal)
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        let doneBtn = UIBarButtonItem(title: "完成", style: .plain, target: tf, action: #selector(UIResponder.resignFirstResponder))
        doneBtn.tintColor = UIColor(AppTheme.brandStart)
        toolbar.setItems([UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil), doneBtn], animated: false)
        tf.inputAccessoryView = toolbar
        return tf
    }

    func updateUIView(_ tf: UITextField, context: Context) {
        // 颜色不受编辑状态影响，随时更新
        if tf.textColor != textColor { tf.textColor = textColor }
        guard !tf.isFirstResponder else { return }
        let cur = Double(tf.text?.replacingOccurrences(of: currencySymbol, with: "") ?? "") ?? 0
        if abs(cur - amount) > 0.001 {
            tf.text = amount == 0 ? "" : String(format: "%.2f", amount)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(amount: $amount) }

    class Coordinator: NSObject, UITextFieldDelegate {
        @Binding var amount: Double
        init(amount: Binding<Double>) { _amount = amount }
        func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
            let allowed = CharacterSet(charactersIn: "0123456789.")
            let cs = CharacterSet(charactersIn: string)
            if !allowed.isSuperset(of: cs) { return false }
            let current = textField.text ?? ""
            let newStr = (current as NSString).replacingCharacters(in: range, with: string)
            let parts = newStr.components(separatedBy: ".")
            if parts.count > 2 { return false }
            if parts.count == 2 && parts[1].count > 2 { return false }
            // 超出上限直接拒绝
            if let d = Double(newStr), d > 9_999_999.99 { return false }

            if let d = Double(newStr) { amount = d }
            return true
        }
    }
}

/// 原生 UITextView 封装（光标感知 + 占位符）
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

/// 日期滚轮选择器（日期 + 时间）
struct DateWheelPicker: View {
    @Binding var selection: Date
    @State private var tempDate: Date = Date()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: { dismiss() }) { Text("取消").foregroundColor(.white).padding(.horizontal, 14).padding(.vertical, 6).background(Color(hex: "#4B5563")).cornerRadius(6) }
                Spacer()
                Text("选择时间")
                    .font(.system(size: 17).weight(.semibold))
                    .foregroundColor(AppTheme.brandStart)
                Spacer()
                Button(action: { selection = tempDate; dismiss() }) {
                    Text("确定").foregroundColor(.white).padding(.horizontal, 16).padding(.vertical, 6).background(AppTheme.brandStart).cornerRadius(6)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            DatePicker("", selection: $tempDate, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.wheel)
                .environment(\.locale, Locale(identifier: "zh_CN"))
                .labelsHidden()
        }
        .background(.ultraThinMaterial)
        .onAppear { tempDate = selection }
    }
}

/// 白色圆角卡片容器（内容 20pt 内边距 + 水平 20pt 外边距）
struct WhiteCardContainer: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(Color.white)
            .cornerRadius(16)
            .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
            .padding(.horizontal, 20)
    }
}
extension View { func whiteCardContainer() -> some View { modifier(WhiteCardContainer()) } }
