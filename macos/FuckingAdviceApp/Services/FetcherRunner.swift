import Foundation

struct FetcherRunner: Sendable {
    enum RunnerError: LocalizedError {
        case missingHelper, timedOut, failed(String), invalidOutput
        var errorDescription: String? {
            switch self {
            case .missingHelper: return "Bundled advice-fetcher is missing. Rebuild the application."
            case .timedOut: return "The advice request timed out."
            case .failed(let detail): return detail
            case .invalidOutput: return "The helper returned invalid data."
            }
        }
    }

    private struct Output: Decodable { let id: Int64; let text: String; let fetchedAt: String }

    func fetch() async throws -> AdviceRecord {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do { continuation.resume(returning: try runSynchronously()) }
                catch { continuation.resume(throwing: error) }
            }
        }
    }

    private func runSynchronously() throws -> AdviceRecord {
        let conventional = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/advice-fetcher")
        let url = Bundle.main.url(forAuxiliaryExecutable: "advice-fetcher") ?? conventional
        guard FileManager.default.isExecutableFile(atPath: url.path) else { throw RunnerError.missingHelper }
            let process = Process(); let stdout = Pipe(); let stderr = Pipe()
            process.executableURL = url; process.arguments = ["fetch", "--timeout=8s"]
            process.standardOutput = stdout; process.standardError = stderr
        let finished = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in finished.signal() }
        try process.run()
        guard finished.wait(timeout: .now() + 10) == .success else { process.terminate(); throw RunnerError.timedOut }
        let output = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        guard output.count <= 64 * 1024, errorData.count <= 64 * 1024 else { throw RunnerError.invalidOutput }
        guard process.terminationStatus == 0 else {
            let detail = String(data: errorData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw RunnerError.failed(detail?.isEmpty == false ? detail! : "Advice request failed.")
        }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        guard let decoded = try? decoder.decode(Output.self, from: output), !decoded.text.isEmpty,
              let date = ISO8601DateFormatter().date(from: decoded.fetchedAt) else { throw RunnerError.invalidOutput }
        return AdviceRecord(id: decoded.id, text: decoded.text, fetchedAt: date)
    }
}
