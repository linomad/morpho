import Foundation

struct MenuBarIconStateMachine {
    static let swapInterval: TimeInterval = 0.45
    static let completionHoldDuration: TimeInterval = 3.0

    private enum IconFrame {
        case primary
        case secondary

        var systemImage: String {
            switch self {
            case .primary:
                return "slider.horizontal.below.square.filled.and.square"
            case .secondary:
                return "slider.horizontal.below.square.and.square.filled"
            }
        }

        var toggled: IconFrame {
            switch self {
            case .primary:
                return .secondary
            case .secondary:
                return .primary
            }
        }
    }

    private enum Phase {
        case idle
        case running(nextFrame: IconFrame)
        case completionHolding
    }

    private var phase: Phase = .idle
    private(set) var currentSystemImage: String = IconFrame.primary.systemImage

    var isAnimating: Bool {
        if case .running = phase {
            return true
        }
        return false
    }

    mutating func beginTranslation() -> String {
        phase = .running(nextFrame: .secondary)
        currentSystemImage = IconFrame.primary.systemImage
        return currentSystemImage
    }

    mutating func animationTick() -> String {
        guard case .running(let nextFrame) = phase else {
            return currentSystemImage
        }

        currentSystemImage = nextFrame.systemImage
        phase = .running(nextFrame: nextFrame.toggled)
        return currentSystemImage
    }

    mutating func finishTranslation() -> String {
        phase = .completionHolding
        currentSystemImage = IconFrame.secondary.systemImage
        return currentSystemImage
    }

    mutating func completionHoldTimeout() -> String {
        guard case .completionHolding = phase else {
            return currentSystemImage
        }

        phase = .idle
        currentSystemImage = IconFrame.primary.systemImage
        return currentSystemImage
    }
}
