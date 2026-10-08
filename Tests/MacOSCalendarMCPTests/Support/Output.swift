import Foundation

final class Output: @unchecked Sendable {
    private let lock = NSLock()
    private var outLines: [String] = []
    private var errLines: [String] = []

    var text: String { lock.withLock { outLines.joined() } }
    var errors: [String] { lock.withLock { errLines } }

    func out(_ line: String) { lock.withLock { outLines.append(line) } }
    func err(_ line: String) { lock.withLock { errLines.append(line) } }
}
