import Foundation

public protocol CloudHTTPClient {
    func send(_ request: URLRequest) async throws -> (Data, HTTPURLResponse)
}
