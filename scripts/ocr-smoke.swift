import Foundation
import Vision
import ImageIO
// Usage: swift scripts/ocr-smoke.swift [image] [--languages en-US,zh-Hans,...] [--expect a,b,...]
var arguments = Array(CommandLine.arguments.dropFirst())
func option(_ name: String) -> [String]? {
    guard let index = arguments.firstIndex(of: name), index + 1 < arguments.count else { return nil }
    let values = arguments[index + 1].split(separator: ",").map(String.init)
    arguments.removeSubrange(index...index + 1)
    return values
}
let languages = option("--languages") ?? ["en-US"]
let expected = option("--expect") ?? ["Projects", "Research", "Personal", "Documents"]
let url = URL(fileURLWithPath: arguments.first ?? "docs/images/elements.png")
guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Fixture image unavailable") }
let start = ProcessInfo.processInfo.systemUptime
// Mirrors the app: Latin/Cyrillic languages share a pass; other scripts get their own pass with English.
let latin: Set<String> = ["en", "fr", "it", "de", "es", "pt", "ru", "uk", "tr", "id", "cs", "da", "nl", "no", "nn", "nb", "ms", "pl", "ro", "sv"]
let base = { (code: String) in String(code.split(separator: "-")[0]) }
var passes = [languages.filter { latin.contains(base($0)) }].filter { !$0.isEmpty }
passes += languages.filter { !latin.contains(base($0)) }.map { [$0, "en-US"] }
var recognized: [String] = []
for pass in passes {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = false
    request.recognitionLanguages = pass
    try VNImageRequestHandler(cgImage: image).perform([request])
    recognized += (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }
}
let text = recognized.joined(separator: " ")
for string in expected {
    guard text.contains(string) else { fatalError("Expected text missing: \(string)") }
}
print("OCR PASS: all \(expected.count) expected strings found with \(passes.count) pass(es) \(passes); \(recognized.count) text regions; \(Int((ProcessInfo.processInfo.systemUptime - start) * 1000)) ms")
