import AppKit
import SprayCanCore

/// Debug check for app analysis: `SprayCan --analyze-apps <id,id…> [--try-enhance <id> | --try-relaunch <id>]`.
/// Prints the feasibility table, optionally tries one adaptation, and always turns enhanced mode off again.
enum AnalysisHarness {
    static func run(_ analyzer: AppAnalyzer, boost: AccessibilityBoost) {
        let arguments = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? { arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } }
        // `--watch-launches <seconds>`: stay up so profiles with full accessibility at launch relaunch apps opened meanwhile.
        if let seconds = value("--watch-launches").flatMap(Double.init) {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }; return
        }
        let ids = (value("--analyze-apps") ?? "").split(separator: ",").map(String.init)
        let trial = value("--try-enhance") ?? value("--try-relaunch")
        let advice: AppAdvice = value("--try-relaunch") != nil ? .relaunch : .enhance
        analyzer.analyze(ids)
        wait(analyzer) {
            print("| App | Type | Labels | Text covered | Scan | Suggestions |")
            print("| --- | --- | --- | --- | --- | --- |")
            for id in ids {
                guard let entry = analyzer.entries[id] else { continue }
                guard let a = entry.analysis else { print("| \(entry.name) | – | – | – | – | \(entry.problem ?? "") |"); continue }
                print("| \(entry.name) | \(a.kind.title) | \(a.labels) | \(AppAnalyzer.percent(a.coverage)) (\(a.textLines) lines) | \(a.scanMilliseconds) ms\(a.truncated ? " (cut off)" : "") | \(entry.advice.map(\.rawValue).joined(separator: ", ")) |")
            }
            guard let trial, let pid = NSRunningApplication.runningApplications(withBundleIdentifier: trial).first?.processIdentifier else { NSApp.terminate(nil); return }
            print("Before trial, enhanced: \(AccessibilityBoost.isOn(pid))")
            analyzer.apply(trial, [advice]) {
                print("Outcome: \(analyzer.entries[trial]?.outcome ?? "-")")
                let now = NSRunningApplication.runningApplications(withBundleIdentifier: trial).first?.processIdentifier ?? pid
                print("During, enhanced: \(AccessibilityBoost.isOn(now)); launched with full accessibility: \(AccessibilityRelauncher.hasFlag(now))")
                boost.restoreAll()
                print("After restore, enhanced: \(AccessibilityBoost.isOn(now))")
                NSApp.terminate(nil)
            }
        }
    }
    private static func wait(_ analyzer: AppAnalyzer, then: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { analyzer.busy ? wait(analyzer, then: then) : then() }
    }
}
