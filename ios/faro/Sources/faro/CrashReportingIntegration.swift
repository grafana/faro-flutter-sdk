import CrashReporter
import Foundation

final class CrashReportingIntegration {
    private let hasPendingCrashReport: () -> Bool
    private let loadPendingCrashReport: () throws -> Data
    private let purgePendingCrashReportHandler: () -> Bool
    private let exportCrashReport: (Data) throws -> [String: Any]

    convenience init() throws {
        guard let cache = FileManager.default.urls(
            for: .cachesDirectory,
            in: .userDomainMask
        ).first else {
            throw CrashReportException(
                description: "Cannot obtain `/Library/Caches/` url."
            )
        }

        let directory = cache.appendingPathComponent(
            "com.rumflutter.crash-reporting",
            isDirectory: true
        )
        let config = PLCrashReporterConfig(
            signalHandlerType: .BSD,
            symbolicationStrategy: [],
            basePath: directory.path
        )
        guard let crashReporter = PLCrashReporter(configuration: config) else {
            throw CrashReportException(
                description: "Could not create an instance of PLCrashReporter."
            )
        }

        self.init(
            hasPendingCrashReport: crashReporter.hasPendingCrashReport,
            loadPendingCrashReport: crashReporter.loadPendingCrashReportDataAndReturnError,
            purgePendingCrashReport: crashReporter.purgePendingCrashReport,
            exportCrashReport: { data in
                let report = try PLCrashReport(data: data)
                var crashReport = try CrashReport(from: report)
                CrashReportMinifier().minify(crashReport: &crashReport)
                return try CrashReportExporter().export(crashReport: crashReport)
            }
        )

        do {
            try crashReporter.enableAndReturnError()
        } catch {
            print("Faro: Could not enable crash reporter: \(error)")
        }
    }

    init(
        hasPendingCrashReport: @escaping () -> Bool,
        loadPendingCrashReport: @escaping () throws -> Data,
        purgePendingCrashReport: @escaping () -> Bool,
        exportCrashReport: @escaping (Data) throws -> [String: Any]
    ) {
        self.hasPendingCrashReport = hasPendingCrashReport
        self.loadPendingCrashReport = loadPendingCrashReport
        self.purgePendingCrashReportHandler = purgePendingCrashReport
        self.exportCrashReport = exportCrashReport
    }

    func takePendingCrashReports() -> [String] {
        guard hasPendingCrashReport() else {
            return []
        }

        do {
            let crash = try exportCrashReport(loadPendingCrashReport())
            guard JSONSerialization.isValidJSONObject(crash) else {
                throw CrashReportException(
                    description: "Pending crash report is not valid JSON."
                )
            }
            let data = try JSONSerialization.data(withJSONObject: crash)
            guard let json = String(data: data, encoding: .utf8) else {
                throw CrashReportException(
                    description: "Could not encode pending crash report as UTF-8."
                )
            }
            return [json]
        } catch {
            // Discard malformed reports so they do not fail every app launch.
            _ = purgePendingCrashReport()
            print(
                "Faro: Failed to load pending crash report; discarding it. " +
                "Error: \(error)"
            )
            return []
        }
    }

    @discardableResult
    func purgePendingCrashReport() -> Bool {
        let purged = purgePendingCrashReportHandler()
        if !purged {
            print("Faro: Could not purge the pending iOS crash report.")
        }
        return purged
    }
}

internal struct RumMeta{
    init(){}
    func asDictionary(){}
}
internal struct RumExceptionFormat{
    let type: String?
    let value: String?
    let stacktrace: Dictionary<String,Any>
    let timestamp: String
    let fatal: Bool
//    let context: Dictionary<String, String>?
    
    var jsonAbbreviation : [String: Any] {
        return [
            "type": type ?? "",
            "value": value ?? "",
            "stacktrace": stacktrace,
            "timestamp": timestamp,
            "fatal": fatal,
//            "context": context ?? ""
        ]
    }
    init(type: String?, value: String?, stacktrace: Dictionary<String, Any>, timestamp: String, fatal: Bool = false) {
        self.type = type
        self.value = value
        self.stacktrace = stacktrace
        self.timestamp = timestamp
        self.fatal = fatal
//        self.context = context
    }
    
}
internal struct CrashReportMinifier{
    
    private let stackFramesLimit: Int
    init(){
        self.stackFramesLimit = 150
    }
        
    func minify(crashReport: inout CrashReport){
        var truncated = false

        if let exceptionStackFrames = crashReport.exceptionInfo?.stackFrames {
            let reducedStackFrames = limit(stackFrames: exceptionStackFrames)
            truncated = truncated || (reducedStackFrames.count != exceptionStackFrames.count)
            crashReport.exceptionInfo?.stackFrames = reducedStackFrames
        }

        // Keep thread stack traces under limit:
        crashReport.threads = crashReport.threads.map { thread in
            var thread = thread
            let reducedStackFrames = limit(stackFrames: thread.stackFrames)
            truncated = truncated || (reducedStackFrames.count != thread.stackFrames.count)
            thread.stackFrames = reducedStackFrames
            return thread
        }

        crashReport.wasTruncated = truncated

        crashReport.binaryImages = remove(
            crashReport: crashReport, binaryImages: crashReport.binaryImages
        )
        
    }
    func limit(stackFrames: [StackFrame]) -> [StackFrame]{
        
        if stackFrames.count > stackFramesLimit {
            var frames = stackFrames

            let numberOfFramesToRemove = stackFrames.count - stackFramesLimit
            let middleFrameIndex = stackFrames.count / 2
            let lowerBound = middleFrameIndex - numberOfFramesToRemove / 2
            let upperBound = lowerBound + numberOfFramesToRemove

            frames.removeSubrange(lowerBound..<upperBound)

            return frames
        }
        return stackFrames
        
    }
    func remove(crashReport: CrashReport, binaryImages: [BinaryImageInfo]) -> [BinaryImageInfo]{
        var imageNamesFromStackFrames: Set<String> = []

                if let exceptionStackFrames = crashReport.exceptionInfo?.stackFrames {
                    imageNamesFromStackFrames.formUnion(exceptionStackFrames.compactMap { $0.libraryName })
                }

                crashReport.threads.forEach { thread in
                    imageNamesFromStackFrames.formUnion(thread.stackFrames.compactMap { $0.libraryName })
                }

                return binaryImages.filter { image in
                    return imageNamesFromStackFrames.contains(image.imageName) // if it's referenced in the stack trace
                }
    }
    
    
}

internal struct CrashReportExporter{
    
    private let unknown = "<unknown>"
    private let signalDescription = [
        "SIGSIGNAL 0": "Signal 0",
        "SIGHUP": "Hangup",
        "SIGINT": "Interrupt",
        "SIGQUIT": "Quit",
        "SIGILL": "Illegal instruction",
        "SIGTRAP": "Trace/BPT trap",
        "SIGABRT": "Abort trap",
        "SIGEMT": "EMT trap",
        "SIGFPE": "Floating point exception",
        "SIGKILL": "Killed",
        "SIGBUS": "Bus error",
        "SIGSEGV": "Segmentation fault",
        "SIGSYS": "Bad system call",
        "SIGPIPE": "Broken pipe",
        "SIGALRM": "Alarm clock",
        "SIGTERM": "Terminated",
        "SIGURG": "Urgent I/O condition",
        "SIGSTOP": "Suspended (signal)",
        "SIGTSTP": "Suspended",
        "SIGCONT": "Continued",
        "SIGCHLD": "Child exited",
        "SIGTTIN": "Stopped (tty input)",
        "SIGTTOU": "Stopped (tty output)",
        "SIGIO": "I/O possible",
        "SIGXCPU": "Cputime limit exceeded",
        "SIGXFSZ": "Filesize limit exceeded",
        "SIGVTALRM": "Virtual timer expired",
        "SIGPROF": "Profiling timer expired",
        "SIGWINCH": "Window size changes",
        "SIGINFO": "Information request",
        "SIGUSR1": "User defined signal 1",
        "SIGUSR2": "User defined signal 2",
    ]
    func export(crashReport: CrashReport) throws -> Dictionary<String,Any>{
        guard let timestamp = crashReport.systemInfo?.timestamp else {
            throw CrashReportException(
                description: "Pending crash report has no timestamp."
            )
        }
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")

        return (RumExceptionFormat(type: formattedType(for: crashReport), value: formattedValue(for: crashReport), stacktrace: ["frames":formattedStack(for: crashReport)],
                           timestamp: dateFormatter.string(from: timestamp),
                           fatal: true
                           // TODO: add context: binaryImages, ThreadInfo,contextData, Meta,truncation
                           //                           context: [
                           //                            "binaryImages": "",
                           //                                "threads": "",
                           //                                "wasTruncated": ""
                           //                           ]
        ).jsonAbbreviation)
        
    }
    
    private func formattedType(for crashReport: CrashReport) -> String {
        return "\(crashReport.signalInfo?.name ?? unknown) (\(crashReport.signalInfo?.code ?? unknown))"
    }
    
    private func formattedValue(for crashReport: CrashReport) -> String {
        if let exception = crashReport.exceptionInfo {
            let exceptionName = exception.name ?? unknown
            let exceptionReason = exception.reason ?? unknown
            return "Terminating app due to uncaught exception '\(exceptionName)', reason: '\(exceptionReason)'."
        } else {
            guard let signalName = crashReport.signalInfo?.name else {
                return "Application crash: \(unknown)"
            }
            
            if let signalDescription = signalDescription[signalName] {
                return "Application crash: \(signalName) (\(signalDescription))"
            } else {
                return "Application crash: \(unknown)"
            }
        }
    }
    
    
    private func formattedStack(for crashReport: CrashReport) -> [Dictionary<String,Any>] {
        let crashedThread = crashReport.threads.first { $0.crashed }
        let exception = crashReport.exceptionInfo
        
        // Consider most meaningful stack trace in this order:
        // - uncaught exception stack trace (if available)
        // - crashed thread stack trace (must be available)
        // - first thread stack trace (sanity fallback)
        let mostMeaningfulStackFrames = exception?.stackFrames
        ?? crashedThread?.stackFrames
        ?? crashReport.threads.first?.stackFrames
        
        guard let stackFrames = mostMeaningfulStackFrames else {
            return []
        }

        return stackFrames.map { stackframe in
            return stackframe.jsonRepresentation
        }
    }
    
    // MARK: - Exporting meta information
    private func formattedMeta(for crashReport: CrashReport) -> String {
        let process = crashReport.processInfo.map { info in
            info.processName.map { "\($0) [\(info.processID)]" } ?? "[\(info.processID)]"
        }
        
        let parentProcess = crashReport.processInfo.map { info in
            info.parentProcessName.map { "\($0) [\(info.parentProcessID)]" } ?? "[\(info.parentProcessID)]"
        }
        
        let anyBinaryImageWithKnownArchitecture = crashReport.binaryImages.first { $0.codeType?.architectureName != nil }
        let cpuArchitecture = anyBinaryImageWithKnownArchitecture?.codeType?.architectureName
        
        return """
                "incidentIdentifier": \(crashReport.incidentIdentifier ?? ""),
                "process": \(process ?? ""),
                "parentProcess": \(parentProcess ?? ""),
                "path": \(crashReport.processInfo?.processPath ?? ""),
                "codeType": \(cpuArchitecture ?? ""),
            """
    }

}
