import SwiftUI
import WebKit

enum LegalDocumentType: Identifiable {
    case privacyPolicy
    case termsOfService
    
    var id: String {
        switch self {
        case .privacyPolicy: return "privacyPolicy"
        case .termsOfService: return "termsOfService"
        }
    }
    
    var title: String {
        switch self {
        case .privacyPolicy: return "隐私政策"
        case .termsOfService: return "服务条款"
        }
    }
    
    var fileName: String {
        switch self {
        case .privacyPolicy: return "PrivacyPolicy"
        case .termsOfService: return "TermsOfService"
        }
    }
}

struct LegalDocumentView: View {
    let documentType: LegalDocumentType
    
    var body: some View {
        WebView(fileName: documentType.fileName)
            .navigationTitle(documentType.title)
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct WebView: UIViewRepresentable {
    let fileName: String
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.backgroundColor = UIColor.systemBackground
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        // HTML 资源打包在 App 根目录（同步组拍平子目录），无需指定 subdirectory
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "html") else {
            // 兜底：显示本地找不到文件的提示
            let html = "<html><body style='font-family:sans-serif;padding:20px;color:#666;'>无法加载文档</body></html>"
            webView.loadHTMLString(html, baseURL: nil)
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url)
    }
}

#Preview {
    NavigationView {
        LegalDocumentView(documentType: .privacyPolicy)
    }
}
