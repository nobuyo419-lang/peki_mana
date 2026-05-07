// DogCanvas.swift — SwiftUI Canvas でペキニーズを手描き
import SwiftUI

struct DogCanvas: View {
    @EnvironmentObject var store: DogStore
    var pose: DogPose = .sit
    var excited: Bool = false
    var size: CGFloat = 280

    private let fur       = Color(red: 0.97, green: 0.93, blue: 0.86)
    private let furLight  = Color(red: 1.00, green: 0.99, blue: 0.95)
    private let furShadow = Color(red: 0.83, green: 0.76, blue: 0.66)
    private let dark      = Color(red: 0.10, green: 0.08, blue: 0.08)
    private let nose      = Color(red: 0.18, green: 0.15, blue: 0.15)
    private let tongue    = Color(red: 0.95, green: 0.55, blue: 0.62)
    private let blush     = Color(red: 1.00, green: 0.78, blue: 0.80)
    private let pad       = Color(red: 0.95, green: 0.74, blue: 0.74)

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0/30.0)) { ctx in
            Canvas { gc, sz in
                let t = ctx.date.timeIntervalSinceReferenceDate
                drawDog(in: &gc, size: sz, t: t)
            }
        }
        .frame(width: size, height: size)
    }

    private func drawDog(in gc: inout GraphicsContext, size: CGSize, t: TimeInterval) {
        let scale = min(size.width, size.height) / 280
        let cx = size.width / 2
        let baseY = size.height * 0.62
        let lively = store.dog.liveliness
        let asleep = store.dog.isAsleep
        let blinkPhase = t.truncatingRemainder(dividingBy: 3.4)
        let blink = blinkPhase < 0.13
        let breathe: CGFloat = CGFloat(1 + 0.018 * sin(t * 1.6))
        let tailFreq = excited ? 8.0 : (1.2 + lively * 5.0)
        let tailWag = sin(t * tailFreq) * (0.28 + lively * 0.4)

        // jump/excited offset
        var dy: CGFloat = 0
        if pose == .jump { dy = -CGFloat(abs(sin(t * 3.4)) * 26) * scale }

        // ground shadow (always on ground, even during jump)
        let shadowAlpha: Double = pose == .jump ? 0.18 : 0.30
        let jumpRatio = pose == .jump ? min(1.0, Double(-dy) / Double(26 * scale)) : 0
        let shadowScale = 1.0 - jumpRatio * 0.3
        let shadowW: CGFloat = 170 * scale * CGFloat(shadowScale)
        gc.fill(
            Path(ellipseIn: CGRect(x: cx - shadowW/2,
                                   y: baseY + 80 * scale,
                                   width: shadowW, height: 22 * scale)),
            with: .color(.black.opacity(shadowAlpha))
        )

        // dog drawn with jump offset
        gc.translateBy(x: 0, y: dy)

        // 1. Tail
        drawTail(in: &gc, cx: cx, cy: baseY, scale: scale, wag: tailWag, pose: pose)

        // 2. Back legs (only for sit/stand)
        if pose != .lie && pose != .sleep {
            drawBackLegs(in: &gc, cx: cx, cy: baseY, scale: scale, pose: pose)
        }

        // 3. Body
        drawBody(in: &gc, cx: cx, cy: baseY, scale: scale, breathe: breathe, pose: pose)

        // 4. Front legs
        drawFrontLegs(in: &gc, cx: cx, cy: baseY, scale: scale, pose: pose, t: t, excited: excited)

        // 5. Head + ears + face
        let headBob = pose == .jump ? CGFloat(sin(t * 3.4) * 4) * scale : 0
        drawHead(in: &gc, cx: cx, cy: baseY, scale: scale, pose: pose,
                 headBobY: headBob, blink: blink, asleep: asleep,
                 excited: excited, lively: lively)

        // 6. Particles
        if asleep {
            drawZ(in: &gc, cx: cx + 90 * scale, cy: baseY - 80 * scale, scale: scale, t: t)
        } else if excited || store.dog.stage >= .loving {
            drawHearts(in: &gc, cx: cx + 90 * scale, cy: baseY - 70 * scale, scale: scale, t: t,
                       count: store.dog.stage == .spoiled ? 3 : 1)
        }
    }

    // MARK: - 部位

    private func drawBody(in gc: inout GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat,
                          breathe: CGFloat, pose: DogPose) {
        let bw: CGFloat
        let bh: CGFloat
        let by: CGFloat
        switch pose {
        case .lie, .sleep:
            bw = 175 * scale; bh = 70 * scale * breathe; by = cy + 30 * scale
        case .sit, .beg:
            bw = 130 * scale; bh = 130 * scale * breathe; by = cy + 8 * scale
        default:
            bw = 160 * scale; bh = 95 * scale * breathe; by = cy + 18 * scale
        }
        // shadow layer
        gc.fill(Path(ellipseIn: CGRect(x: cx - bw/2 + 4, y: by - bh/2 + 6,
                                       width: bw, height: bh)),
                with: .color(furShadow))
        // main fluff
        gc.fill(Path(ellipseIn: CGRect(x: cx - bw/2, y: by - bh/2,
                                       width: bw, height: bh)),
                with: .color(fur))
        // fluff puffs around outline
        let puffs: [(CGFloat, CGFloat)] = [
            (-0.95, 0.0), (-0.75, -0.6), (-0.3, -0.9),
            (0.3, -0.9), (0.75, -0.6), (0.95, 0.0),
            (0.7, 0.6), (-0.7, 0.6),
        ]
        for (px, py) in puffs {
            let r = min(bw, bh) * 0.18
            gc.fill(Path(ellipseIn: CGRect(x: cx + px * bw/2 - r,
                                           y: by + py * bh/2 - r,
                                           width: r * 2, height: r * 2)),
                    with: .color(fur))
        }
        // belly highlight
        gc.fill(Path(ellipseIn: CGRect(x: cx - bw/3, y: by - bh/4,
                                       width: bw/1.5, height: bh/1.6)),
                with: .color(furLight.opacity(0.55)))
    }

    private func drawHead(in gc: inout GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat,
                          pose: DogPose, headBobY: CGFloat, blink: Bool, asleep: Bool,
                          excited: Bool, lively: Double) {
        let hx = cx
        let hy: CGFloat
        switch pose {
        case .lie, .sleep:
            hy = cy + 5 * scale
        case .sit, .beg:
            hy = cy - 78 * scale + headBobY
        default:
            hy = cy - 50 * scale + headBobY
        }
        let hr: CGFloat = 88 * scale  // head radius (large for pekingese)

        // ears (drawn first, behind head)
        drawEar(in: &gc, x: hx - hr * 0.78, y: hy - hr * 0.10, w: hr * 0.95, h: hr * 1.15, scale: scale, side: -1)
        drawEar(in: &gc, x: hx + hr * 0.78, y: hy - hr * 0.10, w: hr * 0.95, h: hr * 1.15, scale: scale, side: 1)

        // head shadow
        gc.fill(Path(ellipseIn: CGRect(x: hx - hr + 4, y: hy - hr + 6, width: hr*2, height: hr*2)),
                with: .color(furShadow))
        // head main
        gc.fill(Path(ellipseIn: CGRect(x: hx - hr, y: hy - hr, width: hr*2, height: hr*2)),
                with: .color(fur))
        // forehead fluff puffs
        let foreheadPuffs: [(CGFloat, CGFloat)] = [
            (-0.6, -0.85), (-0.2, -1.0), (0.2, -1.0), (0.6, -0.85),
            (-0.95, -0.4), (0.95, -0.4),
        ]
        for (px, py) in foreheadPuffs {
            let r = hr * 0.22
            gc.fill(Path(ellipseIn: CGRect(x: hx + px*hr - r, y: hy + py*hr - r,
                                           width: r*2, height: r*2)),
                    with: .color(fur))
        }

        // muzzle (slight dark patch around mouth area for flat face)
        let muzzleR: CGFloat = hr * 0.42
        gc.fill(Path(ellipseIn: CGRect(x: hx - muzzleR, y: hy + hr*0.05,
                                       width: muzzleR*2, height: muzzleR*1.5)),
                with: .color(furLight))

        // eyes
        let eyeY = hy - hr * 0.05
        let eyeDX = hr * 0.30
        if asleep {
            // 閉じ目(三日月の弧)
            for sx in [-1.0, 1.0] {
                let cx2 = hx + CGFloat(sx) * eyeDX
                var p = Path()
                p.move(to: CGPoint(x: cx2 - 8*scale, y: eyeY))
                p.addQuadCurve(to: CGPoint(x: cx2 + 8*scale, y: eyeY),
                               control: CGPoint(x: cx2, y: eyeY + 6*scale))
                gc.stroke(p, with: .color(dark), style: StrokeStyle(lineWidth: 2.4*scale, lineCap: .round))
            }
        } else if blink {
            for sx in [-1.0, 1.0] {
                let cx2 = hx + CGFloat(sx) * eyeDX
                var p = Path()
                p.move(to: CGPoint(x: cx2 - 7*scale, y: eyeY))
                p.addLine(to: CGPoint(x: cx2 + 7*scale, y: eyeY))
                gc.stroke(p, with: .color(dark), style: StrokeStyle(lineWidth: 2.5*scale, lineCap: .round))
            }
        } else {
            for sx in [-1.0, 1.0] {
                let cx2 = hx + CGFloat(sx) * eyeDX
                let er: CGFloat = 9 * scale
                gc.fill(Path(ellipseIn: CGRect(x: cx2 - er, y: eyeY - er, width: er*2, height: er*2)),
                        with: .color(dark))
                // shine
                let sr: CGFloat = 3 * scale
                gc.fill(Path(ellipseIn: CGRect(x: cx2 - sr - 1, y: eyeY - sr - 2, width: sr*2, height: sr*2)),
                        with: .color(.white))
                // smaller secondary shine
                gc.fill(Path(ellipseIn: CGRect(x: cx2 + 1, y: eyeY + 2, width: 2*scale, height: 2*scale)),
                        with: .color(.white.opacity(0.7)))
            }
        }

        // nose
        let nx = hx
        let ny = hy + hr * 0.28
        gc.fill(Path(ellipseIn: CGRect(x: nx - 11*scale, y: ny - 8*scale,
                                       width: 22*scale, height: 16*scale)),
                with: .color(nose))
        // nose shine
        gc.fill(Path(ellipseIn: CGRect(x: nx - 4*scale, y: ny - 5*scale,
                                       width: 5*scale, height: 3*scale)),
                with: .color(.white.opacity(0.55)))

        // mouth
        let my = ny + 14 * scale
        var mouthPath = Path()
        mouthPath.move(to: CGPoint(x: nx, y: ny + 7*scale))
        mouthPath.addLine(to: CGPoint(x: nx, y: my))
        gc.stroke(mouthPath, with: .color(dark), style: StrokeStyle(lineWidth: 2*scale))
        var smile = Path()
        smile.move(to: CGPoint(x: nx - 12*scale, y: my))
        smile.addQuadCurve(to: CGPoint(x: nx, y: my + 4*scale), control: CGPoint(x: nx - 6*scale, y: my + 5*scale))
        smile.addQuadCurve(to: CGPoint(x: nx + 12*scale, y: my), control: CGPoint(x: nx + 6*scale, y: my + 5*scale))
        gc.stroke(smile, with: .color(dark), style: StrokeStyle(lineWidth: 2*scale, lineCap: .round))

        // tongue when excited or spoiled
        if excited || (lively > 0.7 && !asleep) {
            var tp = Path()
            tp.addEllipse(in: CGRect(x: nx - 7*scale, y: my + 1*scale,
                                     width: 14*scale, height: 10*scale))
            gc.fill(tp, with: .color(tongue))
            var tl = Path()
            tl.move(to: CGPoint(x: nx, y: my + 1*scale))
            tl.addLine(to: CGPoint(x: nx, y: my + 9*scale))
            gc.stroke(tl, with: .color(tongue.opacity(0.6)), style: StrokeStyle(lineWidth: 1.2*scale))
        }

        // blush at high affection
        if store.dog.stage >= .loving && !asleep {
            for sx in [-1.0, 1.0] {
                let cx2 = hx + CGFloat(sx) * (hr * 0.55)
                gc.fill(Path(ellipseIn: CGRect(x: cx2 - 8*scale, y: ny - 4*scale,
                                               width: 16*scale, height: 8*scale)),
                        with: .color(blush.opacity(0.55)))
            }
        }
    }

    private func drawEar(in gc: inout GraphicsContext, x: CGFloat, y: CGFloat,
                         w: CGFloat, h: CGFloat, scale: CGFloat, side: CGFloat) {
        // floppy fluffy ear
        let rect = CGRect(x: x - w/2, y: y - h/4, width: w, height: h)
        var t = CGAffineTransform.identity
            .translatedBy(x: x, y: y)
            .rotated(by: CGFloat(side) * 0.18)
            .translatedBy(x: -x, y: -y)
        gc.fill(Path(ellipseIn: rect).applying(t), with: .color(furShadow))
        let inner = CGRect(x: x - w/2 + 3, y: y - h/4 + 4, width: w - 6, height: h - 8)
        gc.fill(Path(ellipseIn: inner).applying(t), with: .color(fur))
    }

    private func drawTail(in gc: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                          scale: CGFloat, wag: Double, pose: DogPose) {
        let baseX: CGFloat
        let baseY: CGFloat
        switch pose {
        case .lie, .sleep:
            baseX = cx + 95 * scale; baseY = cy + 25 * scale
        case .sit, .beg:
            baseX = cx + 60 * scale; baseY = cy + 30 * scale
        default:
            baseX = cx + 75 * scale; baseY = cy + 10 * scale
        }
        // 巻き尾(渦巻状)を3つの丸で表現、先端をwagで揺らす
        let dx = CGFloat(cos(wag) * 28) * scale
        let dy = CGFloat(sin(wag) * -36) * scale
        let r1: CGFloat = 30 * scale
        let r2: CGFloat = 24 * scale
        let r3: CGFloat = 20 * scale
        // shadow
        gc.fill(Path(ellipseIn: CGRect(x: baseX - r1/2 + dx*0.2 + 3, y: baseY - r1/2 + dy*0.2 + 3,
                                       width: r1, height: r1)),
                with: .color(furShadow))
        // segments
        gc.fill(Path(ellipseIn: CGRect(x: baseX - r1/2 + dx*0.2, y: baseY - r1/2 + dy*0.2,
                                       width: r1, height: r1)),
                with: .color(fur))
        gc.fill(Path(ellipseIn: CGRect(x: baseX - r2/2 + dx*0.6, y: baseY - r2/2 + dy*0.6,
                                       width: r2, height: r2)),
                with: .color(fur))
        gc.fill(Path(ellipseIn: CGRect(x: baseX - r3/2 + dx, y: baseY - r3/2 + dy,
                                       width: r3, height: r3)),
                with: .color(furLight))
    }

    private func drawFrontLegs(in gc: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                               scale: CGFloat, pose: DogPose, t: TimeInterval, excited: Bool) {
        switch pose {
        case .sleep, .lie:
            // 前足を顔の下にちょこんと
            for sx in [-1.0, 1.0] {
                let x = cx + CGFloat(sx) * 28 * scale
                let y = cy + 50 * scale
                gc.fill(Path(ellipseIn: CGRect(x: x - 14*scale, y: y, width: 28*scale, height: 22*scale)),
                        with: .color(fur))
                gc.fill(Path(ellipseIn: CGRect(x: x - 5*scale, y: y + 14*scale, width: 10*scale, height: 6*scale)),
                        with: .color(pad))
            }
        case .sit:
            for sx in [-1.0, 1.0] {
                let x = cx + CGFloat(sx) * 32 * scale
                let y = cy + 40 * scale
                gc.fill(Path(ellipseIn: CGRect(x: x - 13*scale, y: y, width: 26*scale, height: 50*scale)),
                        with: .color(fur))
                gc.fill(Path(ellipseIn: CGRect(x: x - 6*scale, y: y + 44*scale, width: 12*scale, height: 8*scale)),
                        with: .color(pad))
            }
        case .beg:
            // 立ち上がって前足を上げる
            for sx in [-1.0, 1.0] {
                let lift = CGFloat(sin(t * 4 + sx) * 4) * scale
                let x = cx + CGFloat(sx) * 30 * scale
                let y = cy - 10 * scale + lift
                gc.fill(Path(ellipseIn: CGRect(x: x - 12*scale, y: y, width: 24*scale, height: 35*scale)),
                        with: .color(fur))
            }
        case .jump:
            for sx in [-1.0, 1.0] {
                let x = cx + CGFloat(sx) * 34 * scale
                let y = cy + 30 * scale
                gc.fill(Path(ellipseIn: CGRect(x: x - 12*scale, y: y, width: 24*scale, height: 30*scale)),
                        with: .color(fur))
            }
        default:
            for sx in [-1.0, 1.0] {
                let step = excited ? CGFloat(sin(t * 4 + sx) * 3) * scale : 0
                let x = cx + CGFloat(sx) * 34 * scale + step
                let y = cy + 50 * scale
                gc.fill(Path(ellipseIn: CGRect(x: x - 13*scale, y: y, width: 26*scale, height: 36*scale)),
                        with: .color(fur))
                gc.fill(Path(ellipseIn: CGRect(x: x - 6*scale, y: y + 30*scale, width: 12*scale, height: 8*scale)),
                        with: .color(pad))
            }
        }
    }

    private func drawBackLegs(in gc: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                              scale: CGFloat, pose: DogPose) {
        switch pose {
        case .sit, .beg:
            for sx in [-1.0, 1.0] {
                let x = cx + CGFloat(sx) * 60 * scale
                let y = cy + 60 * scale
                gc.fill(Path(ellipseIn: CGRect(x: x - 20*scale, y: y, width: 40*scale, height: 30*scale)),
                        with: .color(fur))
            }
        default:
            for sx in [-1.0, 1.0] {
                let x = cx + CGFloat(sx) * 56 * scale
                let y = cy + 60 * scale
                gc.fill(Path(ellipseIn: CGRect(x: x - 14*scale, y: y, width: 28*scale, height: 30*scale)),
                        with: .color(fur))
            }
        }
    }

    private func drawZ(in gc: inout GraphicsContext, cx: CGFloat, cy: CGFloat, scale: CGFloat, t: TimeInterval) {
        for i in 0..<3 {
            let phase = (t * 0.6 + Double(i) * 0.6).truncatingRemainder(dividingBy: 2.0)
            let prog = CGFloat(phase / 2.0)
            let x = cx + 12 * scale * sin(prog * 4)
            let y = cy - 30 * scale - prog * 60 * scale
            let alpha = 1.0 - prog
            gc.draw(
                Text("Z").font(.system(size: 18 + Double(i) * 6, weight: .heavy))
                    .foregroundColor(.blue.opacity(Double(alpha))),
                at: CGPoint(x: x, y: y)
            )
        }
    }

    private func drawHearts(in gc: inout GraphicsContext, cx: CGFloat, cy: CGFloat,
                            scale: CGFloat, t: TimeInterval, count: Int) {
        for i in 0..<count {
            let phase = (t * 0.7 + Double(i) * 0.5).truncatingRemainder(dividingBy: 2.0)
            let prog = CGFloat(phase / 2.0)
            let x = cx + 10 * scale * sin(prog * 5 + CGFloat(i))
            let y = cy - prog * 80 * scale
            let alpha = 1.0 - prog
            gc.draw(
                Text("♡").font(.system(size: 22, weight: .bold))
                    .foregroundColor(.pink.opacity(Double(alpha))),
                at: CGPoint(x: x, y: y)
            )
        }
    }
}
