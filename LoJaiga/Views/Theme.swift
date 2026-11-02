import SwiftUI

enum LJ {
    static let currency = "CAD"
    static let bg = Color(red: 11/255, green: 18/255, blue: 22/255)
    static let panel = Color(red: 29/255, green: 43/255, blue: 48/255)
    static let panel2 = Color(red: 40/255, green: 58/255, blue: 64/255)
    static let mint = Color(red: 142/255, green: 215/255, blue: 173/255)
    static let teal = Color(red: 101/255, green: 201/255, blue: 189/255)
    static let gold = Color(red: 229/255, green: 189/255, blue: 104/255)
    static let coral = Color(red: 218/255, green: 147/255, blue: 133/255)
    static let secondary = Color(red: 177/255, green: 193/255, blue: 189/255)
}

struct Surface<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LJ.panel, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct MatchRing: View {
    let score: Int
    let color: Color
    var body: some View {
        ZStack {
            Circle().stroke(LJ.panel2, lineWidth: 11)
            Circle()
                .trim(from: 0, to: CGFloat(min(max(score, 0), 100)) / 100)
                .stroke(color, style: StrokeStyle(lineWidth: 11, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: 0) {
                Text("\(score)").font(.system(size: 32, weight: .bold, design: .rounded))
                Text("match").font(.caption2).foregroundStyle(LJ.secondary)
            }
        }
        .frame(width: 100, height: 100)
    }
}

struct Chip: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10).padding(.vertical, 4)
            .foregroundStyle(color)
            .background(color.opacity(0.16), in: Capsule())
    }
}

struct NumberRow: View {
    let title: String
    @Binding var value: Double
    var body: some View {
        HStack {
            Text(title).foregroundStyle(LJ.secondary)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 110)
        }
    }
}

func dismissKeyboard() {
    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
}
