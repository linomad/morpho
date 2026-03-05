import Foundation

struct MenuBarIconStateMachine {
    static let swapInterval: TimeInterval = 0.45
    static let completionHoldDuration: TimeInterval = 3.0
    private static let idleSystemImage = "globe.asia.australia.fill"
    private static let runningCycleSystemImages = [
        "globe.central.south.asia.fill",
        "globe.central.south.asia.fill",
        "globe.americas.fill",
    ]

    private enum Phase {
        case idle
        case running(nextCycleIndex: Int)
        case completionHolding
    }

    private var phase: Phase = .idle
    private(set) var currentSystemImage: String = Self.idleSystemImage

    var isAnimating: Bool {
        if case .running = phase {
            return true
        }
        return false
    }

    mutating func beginTranslation() -> String {
        let firstCycleIndex = 0
        let nextCycleIndex = Self.runningCycleSystemImages.index(after: firstCycleIndex)
        phase = .running(nextCycleIndex: nextCycleIndex % Self.runningCycleSystemImages.count)
        currentSystemImage = Self.runningCycleSystemImages[firstCycleIndex]
        return currentSystemImage
    }

    mutating func animationTick() -> String {
        guard case .running(let nextCycleIndex) = phase else {
            return currentSystemImage
        }

        currentSystemImage = Self.runningCycleSystemImages[nextCycleIndex]
        let followingIndex = Self.runningCycleSystemImages.index(after: nextCycleIndex)
        phase = .running(nextCycleIndex: followingIndex % Self.runningCycleSystemImages.count)
        return currentSystemImage
    }

    mutating func finishTranslation() -> String {
        phase = .completionHolding
        currentSystemImage = Self.runningCycleSystemImages.last ?? Self.idleSystemImage
        return currentSystemImage
    }

    mutating func completionHoldTimeout() -> String {
        guard case .completionHolding = phase else {
            return currentSystemImage
        }

        phase = .idle
        currentSystemImage = Self.idleSystemImage
        return currentSystemImage
    }
}
