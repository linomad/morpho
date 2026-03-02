import Foundation

public final class CompositeStatusReporter: StatusReporting {
    private let reporters: [any StatusReporting]

    public init(reporters: [any StatusReporting]) {
        self.reporters = reporters
    }

    public func publish(_ entry: StatusEntry) {
        reporters.forEach { $0.publish(entry) }
    }
}
