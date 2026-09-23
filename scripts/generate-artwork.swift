import AppKit
import Foundation
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Resources/Assets.xcassets")
func writeJSON(_ object: Any, _ path: URL) { try! JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]).write(to: path) }
let info: [String: Any] = ["author":"xcode", "version":1]
writeJSON(["info":info], assets.appendingPathComponent("Contents.json"))
func can(_ r: CGRect, filled: Bool) {
    let body = NSBezierPath(roundedRect: CGRect(x: r.minX+r.width*0.22, y:r.minY+r.height*0.05, width:r.width*0.56, height:r.height*0.65), xRadius:r.width*0.10, yRadius:r.width*0.10)
    body.lineWidth = r.width * 0.07
    if filled { body.fill() } else { body.stroke() }
    let shoulder = NSBezierPath(roundedRect: CGRect(x:r.minX+r.width*0.32,y:r.minY+r.height*0.70,width:r.width*0.36,height:r.height*0.10),xRadius:r.width*0.035,yRadius:r.width*0.035)
    shoulder.lineWidth = r.width*0.055; shoulder.stroke()
    let nozzle = NSBezierPath(roundedRect:CGRect(x:r.minX+r.width*0.43,y:r.minY+r.height*0.80,width:r.width*0.20,height:r.height*0.15),xRadius:r.width*0.025,yRadius:r.width*0.025)
    nozzle.lineWidth = r.width*0.05; nozzle.stroke()
    if !filled {
        let bands = NSBezierPath(); bands.lineWidth = r.width*0.04
        for y in [0.21,0.56] { bands.move(to:CGPoint(x:r.minX+r.width*0.23,y:r.minY+r.height*y)); bands.line(to:CGPoint(x:r.minX+r.width*0.77,y:r.minY+r.height*y)) }; bands.stroke()
    }
    let spray = NSBezierPath(); spray.lineWidth = r.width*0.045; spray.lineCapStyle = .round
    spray.move(to:CGPoint(x:r.minX+r.width*0.76,y:r.minY+r.height*0.87)); spray.line(to:CGPoint(x:r.minX+r.width*0.94,y:r.minY+r.height*0.93)); spray.stroke()
}
final class MarkView: NSView {
    var filled = false
    override func draw(_ rect: NSRect) { NSColor.black.set(); can(bounds.insetBy(dx:2,dy:1), filled:filled) }
}
for filled in [false,true] {
    let name = filled ? "MenuActive" : "MenuIdle"
    let view = MarkView(frame: CGRect(x:0,y:0,width:18,height:18)); view.filled = filled
    try! view.dataWithPDF(inside:view.bounds).write(to: assets.appendingPathComponent("\(name).imageset/\(name).pdf"))
    writeJSON(["images":[["filename":"\(name).pdf","idiom":"universal"]],"info":info,"properties":["preserves-vector-representation":true,"template-rendering-intent":"template"]],assets.appendingPathComponent("\(name).imageset/Contents.json"))
}
var images: [[String:String]] = []
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size*scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:pixels,pixelsHigh:pixels,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep:bitmap)
        let context = NSGraphicsContext.current!.cgContext; context.scaleBy(x:CGFloat(pixels)/1024,y:CGFloat(pixels)/1024)
        let tile = NSBezierPath(roundedRect:CGRect(x:60,y:60,width:904,height:904),xRadius:205,yRadius:205)
        NSGradient(colors:[NSColor(calibratedRed:0.02,green:0.26,blue:0.29,alpha:1),NSColor(calibratedRed:0.25,green:0.76,blue:0.69,alpha:1)])!.draw(in:tile,angle:60)
        NSColor.white.withAlphaComponent(0.25).setStroke(); tile.lineWidth=3; tile.stroke()
        let glow=NSBezierPath(ovalIn:CGRect(x:170,y:420,width:600,height:400)); NSColor.white.withAlphaComponent(0.08).setFill(); glow.fill()
        NSColor.white.withAlphaComponent(0.95).set(); can(CGRect(x:225,y:135,width:550,height:740),filled:false)
        NSGraphicsContext.restoreGraphicsState()
        let filename="icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try! bitmap.representation(using:.png,properties:[:])!.write(to:assets.appendingPathComponent("AppIcon.appiconset/\(filename)"))
        images.append(["filename":filename,"idiom":"mac","scale":"\(scale)x","size":"\(size)x\(size)"])
    }
}
writeJSON(["images":images,"info":info],assets.appendingPathComponent("AppIcon.appiconset/Contents.json"))
print("Generated original app icon and vector PDF menu icons.")
