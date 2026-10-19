import AppKit
import SprayCanCore

/// Debug check for app analysis: `SprayCan --analyze-apps <id,id…> [--try-enhance <id>]`. Prints the
/// feasibility table, optionally tries enhanced accessibility on one app, and always restores it.
enum AnalysisHarness {
    static func run(_ analyzer: AppAnalyzer, boost: AccessibilityBoost) {
        let arguments = ProcessInfo.processInfo.arguments
        func value(_ flag: String) -> String? { arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } }
        let ids = (value("--analyze-apps") ?? "").split(separator: ",").map(String.init)
        let trial = value("--try-enhance")
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
            analyzer.apply(trial, [.enhance]) {
                print("Outcome: \(analyzer.entries[trial]?.outcome ?? "-")")
                print("During, enhanced: \(AccessibilityBoost.isOn(pid))")
                boost.restoreAll()
                print("After restore, enhanced: \(AccessibilityBoost.isOn(pid))")
                NSApp.terminate(nil)
            }
        }
    }
    private static func wait(_ analyzer: AppAnalyzer, then: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { analyzer.busy ? wait(analyzer, then: then) : then() }
    }
}
