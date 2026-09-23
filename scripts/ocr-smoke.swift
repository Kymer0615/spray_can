import Foundation
import Vision
import ImageIO
let url = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "docs/images/elements.png")
guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else { fatalError("Fixture image unavailable") }
let start = ProcessInfo.processInfo.systemUptime
let request = VNRecognizeTextRequest()
request.recognitionLevel = .accurate
request.usesLanguageCorrection = false
try VNImageRequestHandler(cgImage: image).perform([request])
let recognized = (request.results ?? []).compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")
for expected in ["Projects", "Research", "Personal", "Documents"] {
    guard recognized.contains(expected) else { fatalError("Expected fixture text missing: \(expected)") }
}
let count = request.results?.count ?? 0
print("OCR PASS: all 4 expected fixture strings found; \(count) text regions; \(Int((ProcessInfo.processInfo.systemUptime - start) * 1000)) ms")
