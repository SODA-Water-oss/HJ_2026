import SwiftUI

// MARK: - AppTheme (Design Spec)
struct AppTheme {
    static let brandStart = Color(hex: "#5B6EF0")
    static let brandEnd = Color(hex: "#A855F7")
    static let brandGradient = LinearGradient(
        gradient: Gradient(colors: [brandStart, brandEnd]),
        startPoint: .leading,
        endPoint: .trailing
    )
    static let background = Color(hex: "#F3F4F6")
    static let cardBackground = Color.white
    static let textPrimary = Color(hex: "#1F2937")
    static let textSecondary = Color(hex: "#6B7280")
    static let textTertiary = Color(hex: "#9CA3AF")
    static let textWhite = Color.white
    static let border = Color(hex: "#E5E7EB")
    static let cardBorder = Color.black.opacity(0.04)
    static let divider = Color(hex: "#E5E7EB")
    static let rowHighlight = Color(hex: "#F9FAFB")
    static let cardShadow = Color.black.opacity(0.06)
    static let brandShadow = Color(hex: "#5B6EF0").opacity(0.3)
    static let cardRadius: CGFloat = 16
    static let elementRadius: CGFloat = 8
    static let listRadius: CGFloat = 12
    static let cardPadding: CGFloat = 28
    static let cardPaddingH: CGFloat = 32
    static let spacing: CGFloat = 20
   static let fontBase: CGFloat = 15
    static let categoryColors: [String: Color] = ["餐饮": Color(hex: "#5B6EF0"), "交通": Color(hex: "#A855F7"), "购物": Color(hex: "#EC4899"), "娱乐": Color(hex: "#F59E0B"), "住房": Color(hex: "#60B8D0"), "日用": Color(hex: "#6B8FE8"), "服饰": Color(hex: "#9A8BC8"), "通讯": Color(hex: "#4F7CD0"), "医疗": Color(hex: "#E06070"), "教育": Color(hex: "#50B8A0"), "其他": Color(hex: "#A09080")]
    static func categoryColor(_ name: String) -> Color {
        categoryColors[name] ?? Color(hex: "#6B7280")
    }
}

extension Font {
    static let appLargeTitle = Font.system(size: 28, weight: .semibold).leading(.tight)
    static let appTitle = Font.system(size: 17, weight: .semibold).leading(.tight)
    static let appBody = Font.system(size: 17, weight: .regular)
    static let appBodyMedium = Font.system(size: 17, weight: .medium)
    static let appSmall = Font.system(size: 15, weight: .regular)
    static let appTiny = Font.system(size: 15, weight: .regular)
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch h.count {
        case 6: (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8: (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(.sRGB, red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255, opacity: Double(a)/255)
    }
}

struct AppPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBodyMedium).foregroundColor(.white)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(AppTheme.brandGradient)
            .cornerRadius(8)
            .shadow(color: AppTheme.brandShadow, radius: 8, x: 0, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct AppSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.appBodyMedium).foregroundColor(AppTheme.brandStart)
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color.white).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.brandStart, lineWidth: 1.5))
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
}

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.appBody).foregroundColor(AppTheme.textPrimary)
            .padding(.horizontal, 16).padding(.vertical, 12)
            .background(Color.white).cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.border, lineWidth: 1))
            .tint(AppTheme.brandStart)
    }
}

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 32).padding(.vertical, 28)
            .background(Color.white).cornerRadius(16)
            .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.cardBorder, lineWidth: 1))
    }
}
extension View { func cardStyle() -> some View { modifier(CardStyle()) } }

struct AppDivider: View {
    var body: some View { Rectangle().fill(AppTheme.divider).frame(height: 1) }
}

extension String {
    func truncatedToBytes(_ maxBytes: Int) -> String {
        guard utf8.count > maxBytes else { return self }
        var bytes = 0
        for (i, ch) in enumerated() {
            let cb = String(ch).utf8.count
            if bytes + cb > maxBytes { return String(prefix(i)) }
            bytes += cb
        }
        return self
    }
}

extension View {
    func byteLimited(_ text: Binding<String>, max: Int) -> some View {
        self.onChange(of: text.wrappedValue) { newVal in
            if newVal.utf8.count > max { text.wrappedValue = newVal.truncatedToBytes(max) }
        }
    }
}
// MARK: - 卡片水印
// MARK: - 卡片水印
struct RecordWatermark: View {
    let expense: Expense
    
    var body: some View {
        let day = Calendar.current.component(.day, from: expense.date)
        let hour = Calendar.current.component(.hour, from: expense.date)
        let minute = Calendar.current.component(.minute, from: expense.date)
        let posSeed = (day * 13 + hour * 7 + minute * 19 + Int(expense.amount * 100) % 89) & 0xFFFF
        let offsetX: CGFloat = CGFloat((posSeed % 101) - 50)
        let offsetY: CGFloat = CGFloat(((posSeed >> 7) % 121) - 10)
        return watermarkContent
            .offset(x: offsetX, y: offsetY)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
    }
    
  private var watermarkContent: some View {
       let icons: [String]
      switch expense.category {
        case "餐饮": icons = ["fork.knife", "cup.and.saucer", "takeoutbag.and.cup.and.straw", "mug", "oven", "refrigerator"]
        case "交通": icons = ["car", "bus", "airplane", "bicycle", "tram", "sailboat"]
        case "购物": icons = ["bag", "cart", "creditcard", "gift", "tag", "dollarsign.circle"]
        case "娱乐": icons = ["star", "play", "music.note", "gamecontroller", "film", "balloon"]
        case "住房": icons = ["house", "building", "bed.double", "key", "lamp.desk", "door.garage"]
        case "日用": icons = ["leaf", "drop", "scissors", "comb", "soap", "lightbulb"]
        case "服饰": icons = ["tshirt", "shoe", "watch", "eyeglasses", "hat.cap", "umbrella"]
        case "通讯": icons = ["message", "phone", "antenna.radiowaves.left.and.right", "envelope", "faxmachine", "mic"]
        case "医疗": icons = ["heart", "cross.case", "bandage", "pills", "stethoscope", "eye"]
        case "教育": icons = ["book", "graduationcap", "pencil", "brain", "calendar.badge.clock", "globe"]
        default: icons = ["circle", "square", "triangle", "star", "hexagon", "octagon"]
       }
       let day = Calendar.current.component(.day, from: expense.date)
        let hour = Calendar.current.component(.hour, from: expense.date)
       let minute = Calendar.current.component(.minute, from: expense.date)
       let seed = (day * 7 + minute * 13 + hour * 3 + Int(expense.amount * 100) % 97) & 0x7FFF
       let name = icons[seed % icons.count]
       let sizeSeed = (day * 11 + hour * 17 + minute * 5 + Int(expense.amount * 100) % 101) & 0xFF
       let size: CGFloat = 55 + CGFloat(sizeSeed % 94)
        let rotSeed = (day * 5 + hour * 19 + minute * 11 + Int(expense.amount * 100) % 103) & 0xFFF
        let angle = Double(rotSeed % 72) * 5 + (expense.isExpense ? 0.0 : 180.0)
       
      let color = AppTheme.categoryColor(expense.category).opacity(0.08)
        
        return Image(systemName: name)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .foregroundColor(color)
            .frame(width: size, height: size)
            .rotationEffect(Angle(degrees: angle))
            .padding(.trailing, 12)
            .padding(.bottom, 6 + CGFloat(hour % 4) * 4)
    }
}
