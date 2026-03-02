import Combine
import Foundation

public final class StatusCenter: ObservableObject, StatusReporting, @unchecked Sendable {
    @Published public private(set) var lastEntry: StatusEntry?

    public init() {}

    public func publish(_ entry: StatusEntry) {
        DispatchQueue.main.async { [weak self] in
            self?.lastEntry = entry
        }
    }
}
