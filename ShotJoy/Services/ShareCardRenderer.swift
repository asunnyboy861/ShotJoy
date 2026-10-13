import SwiftUI

struct VictoryCardView: View {
    let weekNumber: Int
    let streak: Int
    let totalLossLB: Double?
    let compoundName: String

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(AppTheme.mint)
                Text("Shot Day ✅")
                    .font(.title.bold())
                Spacer()
                Text("ShotJoy")
                    .font(.headline)
                    .foregroundStyle(AppTheme.coral)
            }
            Spacer()
            VStack(spacing: 10) {
                Text("Week \(weekNumber)")
                    .font(.system(size: 56, weight: .heavy))
                    .foregroundStyle(.white)
                if let loss = totalLossLB, loss > 0 {
                    Text("-\(String(format: "%.0f", loss)) lb")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(AppTheme.mint)
                }
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(AppTheme.coral)
                    Text("streak \(streak)")
                        .font(.title3.bold())
                }
                Text(compoundName)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.8))
            }
            Spacer()
            Text("#ShotDayDone · Every shot, a win.")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(28)
        .frame(width: 340, height: 520)
        .background(
            LinearGradient(colors: [AppTheme.coral.opacity(0.85), Color(red: 0.16, green: 0.17, blue: 0.23)], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 32)
        )
    }
}

enum ShareCardRenderer {
    @MainActor
    static func render(weekNumber: Int, streak: Int, totalLossLB: Double?, compoundName: String) -> UIImage? {
        let view = VictoryCardView(weekNumber: weekNumber, streak: streak, totalLossLB: totalLossLB, compoundName: compoundName)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}

struct ConfettiView: View {
    @State private var animate = false

    private struct Piece: Identifiable {
        let id: Int
        let x: CGFloat
        let delay: Double
        let color: Color
        let rotation: Double
        let size: CGFloat
    }

    private var pieces: [Piece] {
        let colors: [Color] = [AppTheme.coral, AppTheme.mint, .yellow, .orange, .pink]
        return (0..<42).map { i in
            Piece(id: i,
                  x: CGFloat.random(in: 10...370),
                  delay: Double.random(in: 0...0.3),
                  color: colors[i % colors.count],
                  rotation: Double.random(in: 0...360),
                  size: CGFloat.random(in: 6...12))
        }
    }

    var body: some View {
        ZStack {
            ForEach(pieces) { p in
                RoundedRectangle(cornerRadius: 2)
                    .fill(p.color)
                    .frame(width: p.size, height: p.size * 1.6)
                    .rotationEffect(.degrees(animate ? p.rotation : p.rotation + 180))
                    .offset(y: animate ? 620 : -80)
                    .position(x: p.x, y: 200)
                    .opacity(animate ? 0 : 1)
                    .animation(.easeIn(duration: 0.8).delay(p.delay), value: animate)
            }
        }
        .allowsHitTesting(false)
        .onAppear { animate = true }
    }
}
