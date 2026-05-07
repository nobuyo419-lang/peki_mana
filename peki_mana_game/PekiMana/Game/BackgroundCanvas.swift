// BackgroundCanvas.swift — 季節と時間帯で変わる背景
import SwiftUI

struct BackgroundCanvas: View {
    let season: Season
    let timeOfDay: TimeOfDay

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/24.0)) { ctx in
            Canvas { gc, sz in
                let t = ctx.date.timeIntervalSinceReferenceDate
                draw(gc: &gc, size: sz, t: t)
            }
        }
        .ignoresSafeArea()
    }

    private func draw(gc: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let (top, bot) = skyColors()
        let groundColor = adjustedGround()

        // sky gradient
        let sky = Path(CGRect(x: 0, y: 0, width: size.width, height: size.height * 0.7))
        gc.fill(sky, with: .linearGradient(
            Gradient(colors: [top, bot]),
            startPoint: .zero,
            endPoint: CGPoint(x: 0, y: size.height * 0.7)
        ))

        // sun / moon
        if timeOfDay == .night {
            gc.fill(Path(ellipseIn: CGRect(x: size.width * 0.78, y: size.height * 0.10,
                                           width: 60, height: 60)),
                    with: .color(.white.opacity(0.95)))
            for i in 0..<25 {
                let x = (sin(Double(i) * 3.7) + 1) * Double(size.width) / 2
                let y = (cos(Double(i) * 5.1) + 1) * Double(size.height) * 0.30
                let twinkle = 0.4 + 0.5 * abs(sin(t * 1.5 + Double(i)))
                gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.5, height: 2.5)),
                        with: .color(.white.opacity(twinkle)))
            }
        } else {
            gc.fill(Path(ellipseIn: CGRect(x: size.width * 0.78, y: size.height * 0.08,
                                           width: 70, height: 70)),
                    with: .color(.yellow.opacity(timeOfDay == .evening ? 0.85 : 0.9)))
            gc.fill(Path(ellipseIn: CGRect(x: size.width * 0.78 - 10, y: size.height * 0.08 - 10,
                                           width: 90, height: 90)),
                    with: .color(.yellow.opacity(0.18)))
        }

        // distant clouds
        for i in 0..<3 {
            let cx = (CGFloat(i) * size.width / 3 + CGFloat(t * 5).truncatingRemainder(dividingBy: size.width))
                .truncatingRemainder(dividingBy: size.width + 100) - 50
            let cy = size.height * (0.15 + 0.05 * CGFloat(i % 2))
            cloud(in: &gc, x: cx, y: cy, scale: 1.0 + CGFloat(i) * 0.1)
        }

        // ground band
        let groundY = size.height * 0.7
        let groundRect = CGRect(x: 0, y: groundY, width: size.width, height: size.height - groundY)
        gc.fill(Path(groundRect), with: .color(groundColor))

        // cobblestone / asphalt pattern hint
        switch season {
        case .spring, .summer:
            // 草地に花や葉
            for i in 0..<28 {
                let x = sin(Double(i) * 1.7) * Double(size.width) / 2 + Double(size.width) / 2
                let y = groundY + 8 + Double(i % 5) * 18
                gc.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)),
                        with: .color(season == .spring ? .pink.opacity(0.55) : .yellow.opacity(0.4)))
            }
        case .autumn:
            for i in 0..<24 {
                let x = sin(Double(i) * 2.3) * Double(size.width) / 2 + Double(size.width) / 2
                let y = groundY + 6 + Double(i % 6) * 16
                gc.fill(Path(ellipseIn: CGRect(x: x - 4, y: y - 3, width: 8, height: 6)),
                        with: .color(.orange.opacity(0.55)))
            }
            // 落ち葉が舞う
            for i in 0..<8 {
                let prog = CGFloat((t * 0.15 + Double(i) * 0.18).truncatingRemainder(dividingBy: 1))
                let x = CGFloat(sin(t * 0.6 + Double(i))) * 80 + size.width * (CGFloat(i) / 8)
                let y = prog * size.height
                gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 6, height: 4)),
                        with: .color(.orange.opacity(0.7)))
            }
        case .winter:
            // 雪のテクスチャ
            for i in 0..<40 {
                let prog = CGFloat((t * 0.08 + Double(i) * 0.05).truncatingRemainder(dividingBy: 1))
                let x = CGFloat(sin(Double(i) * 1.13 + t * 0.3)) * 30 +
                    size.width * (CGFloat(i) / 40)
                let y = prog * size.height
                gc.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 4, height: 4)),
                        with: .color(.white.opacity(0.85)))
            }
        }

        // 夜は全体に少し暗いオーバーレイ
        if timeOfDay == .night {
            gc.fill(Path(CGRect(origin: .zero, size: size)),
                    with: .color(.black.opacity(0.18)))
        } else if timeOfDay == .evening {
            gc.fill(Path(CGRect(origin: .zero, size: size)),
                    with: .color(.orange.opacity(0.10)))
        }
    }

    private func cloud(in gc: inout GraphicsContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        let alpha = 0.8
        for (dx, r) in [(0.0, 18.0), (16.0, 22.0), (32.0, 18.0), (10.0, 26.0), (24.0, 24.0)] {
            let dx = CGFloat(dx) * scale
            let r = CGFloat(r) * scale
            gc.fill(Path(ellipseIn: CGRect(x: x + dx - r/2, y: y - r/2, width: r, height: r)),
                    with: .color(.white.opacity(alpha)))
        }
    }

    private func skyColors() -> (Color, Color) {
        switch timeOfDay {
        case .night:
            return (Color(red: 0.10, green: 0.12, blue: 0.30),
                    Color(red: 0.20, green: 0.20, blue: 0.40))
        case .evening:
            return (Color(red: 1.0, green: 0.65, blue: 0.55),
                    Color(red: 1.0, green: 0.85, blue: 0.70))
        default:
            return (season.skyTop, season.skyBottom)
        }
    }

    private func adjustedGround() -> Color {
        switch timeOfDay {
        case .night:
            let g = season.groundColor
            return g.opacity(0.7)
        default:
            return season.groundColor
        }
    }
}
