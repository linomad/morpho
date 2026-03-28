import Foundation

struct MenuBarIconRenderState: Equatable {
    let baseSymbol: String
    let dotScale: CGFloat?
    let dotAlpha: CGFloat
}

struct MenuBarIconStateMachine {
    static let breathingCycleDuration: TimeInterval = 1.25
    static let fadeOutDuration: TimeInterval = 0.15
    private static let baseSymbol = "globe.asia.australia.fill"
    private static let minScale: CGFloat = 0.82
    private static let maxScale: CGFloat = 1.0

    var reduceMotion: Bool = false

    private enum Phase {
        case idle
        case loading(elapsed: TimeInterval)
        case fadingOut(elapsed: TimeInterval, lastScale: CGFloat)
    }

    private var phase: Phase = .idle

    var isLoading: Bool {
        if case .loading = phase { return true }
        return false
    }

    var isFadingOut: Bool {
        if case .fadingOut = phase { return true }
        return false
    }

    var isAnimating: Bool {
        switch phase {
        case .idle: return false
        case .loading, .fadingOut: return true
        }
    }

    var renderState: MenuBarIconRenderState {
        switch phase {
        case .idle:
            return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: nil, dotAlpha: 0.0)
        case .loading(let elapsed):
            if reduceMotion {
                return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: 1.0, dotAlpha: 1.0)
            }
            let scale = Self.breathingScale(at: elapsed)
            let alpha = Self.breathingAlpha(at: elapsed)
            return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: scale, dotAlpha: alpha)
        case .fadingOut(let elapsed, let lastScale):
            let progress = min(elapsed / Self.fadeOutDuration, 1.0)
            let alpha = 1.0 - progress
            return MenuBarIconRenderState(baseSymbol: Self.baseSymbol, dotScale: lastScale, dotAlpha: alpha)
        }
    }

    mutating func beginTranslation() {
        phase = .loading(elapsed: 0)
    }

    mutating func animationTick(deltaSeconds: TimeInterval) {
        switch phase {
        case .idle:
            break
        case .loading(let elapsed):
            phase = .loading(elapsed: elapsed + deltaSeconds)
        case .fadingOut(let elapsed, let lastScale):
            let newElapsed = elapsed + deltaSeconds
            if newElapsed >= Self.fadeOutDuration {
                phase = .idle
            } else {
                phase = .fadingOut(elapsed: newElapsed, lastScale: lastScale)
            }
        }
    }

    mutating func finishTranslation() {
        let currentScale: CGFloat
        if case .loading(let elapsed) = phase {
            currentScale = reduceMotion ? 1.0 : Self.breathingScale(at: elapsed)
        } else {
            currentScale = Self.maxScale
        }
        phase = .fadingOut(elapsed: 0, lastScale: currentScale)
    }

    private static func breathingScale(at elapsed: TimeInterval) -> CGFloat {
        let t = elapsed / breathingCycleDuration
        let sine = sin(t * 2.0 * .pi)
        let normalized = (sine + 1.0) / 2.0
        return minScale + (maxScale - minScale) * normalized
    }

    private static func breathingAlpha(at elapsed: TimeInterval) -> CGFloat {
        let t = elapsed / breathingCycleDuration
        let sine = sin(t * 2.0 * .pi)
        let normalized = (sine + 1.0) / 2.0
        return 0.85 + 0.15 * normalized
    }
}
