import SwiftUI

// MARK: - 批量扫描滚动驱动
final class SweepScrollDriver: NSObject {
    weak var scrollView: UIScrollView?
    var onTick: (() -> Void)?
    var speed: CGFloat = 185
    private var displayLink: CADisplayLink?
    private var wasScrollEnabled = true

    func attach(to scrollView: UIScrollView) {
        self.scrollView = scrollView
    }

    func start(onTick: @escaping () -> Void) {
        self.onTick = onTick
        wasScrollEnabled = scrollView?.isScrollEnabled ?? true
        scrollView?.isScrollEnabled = false
        displayLink?.invalidate()
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.add(to: .main, forMode: .common)
    }

    var isActive = true

    @objc private func tick() {
        guard isActive, let sv = scrollView else { return }
        sv.contentOffset.y += speed / 60.0
        onTick?()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        scrollView?.isScrollEnabled = wasScrollEnabled
        isActive = true
        onTick = nil
    }
}

// MARK: - 捕获 ScrollView 的底层 UIScrollView
struct ScrollViewAccessor: UIViewRepresentable {
    let onScrollView: (UIScrollView) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.isHidden = true
        view.backgroundColor = .clear
        DispatchQueue.main.async {
            var current: UIView? = view
            while current != nil {
                if let sv = current as? UIScrollView {
                    onScrollView(sv)
                    break
                }
                current = current?.superview
            }
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            var current: UIView? = uiView
            while current != nil {
                if let sv = current as? UIScrollView {
                    onScrollView(sv)
                    break
                }
                current = current?.superview
            }
        }
    }
}
