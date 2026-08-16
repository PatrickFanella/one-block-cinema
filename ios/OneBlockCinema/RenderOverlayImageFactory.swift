import CoreGraphics
import CoreText
import Foundation

nonisolated enum RenderOverlayImageFactory {
    static func make(
        size: CGSize,
        backgroundColor: CGColor,
        backgroundRect: CGRect? = nil,
        cornerRadius: CGFloat = 0,
        text: String? = nil,
        textColor: CGColor = CGColor(gray: 1, alpha: 1),
        fontSize: CGFloat = 48,
        textRect: CGRect? = nil
    ) -> CGImage? {
        let width = Int(size.width.rounded(.up))
        let height = Int(size.height.rounded(.up))
        guard width > 0, height > 0,
              let context = CGContext(
                  data: nil,
                  width: width,
                  height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              )
        else { return nil }

        context.setFillColor(backgroundColor)
        let fillRect = backgroundRect ?? CGRect(origin: .zero, size: size)
        if cornerRadius > 0 {
            context.addPath(
                CGPath(
                    roundedRect: fillRect,
                    cornerWidth: cornerRadius,
                    cornerHeight: cornerRadius,
                    transform: nil
                )
            )
            context.fillPath()
        } else {
            context.fill(fillRect)
        }

        if let text, !text.isEmpty, let textRect {
            draw(text, color: textColor, fontSize: fontSize, in: textRect, context: context)
        }

        return context.makeImage()
    }

    private static func draw(
        _ text: String,
        color: CGColor,
        fontSize: CGFloat,
        in textRect: CGRect,
        context: CGContext
    ) {
        let font = CTFontCreateWithName("HelveticaNeue-Medium" as CFString, fontSize, nil)
        var alignment = CTTextAlignment.center
        let paragraphStyle = withUnsafePointer(to: &alignment) { pointer in
            var setting = CTParagraphStyleSetting(
                spec: .alignment,
                valueSize: MemoryLayout<CTTextAlignment>.size,
                value: pointer
            )
            return CTParagraphStyleCreate(&setting, 1)
        }
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color,
            NSAttributedString.Key(kCTParagraphStyleAttributeName as String): paragraphStyle
        ]
        let attributedText = NSAttributedString(string: text, attributes: attributes)
        let framesetter = CTFramesetterCreateWithAttributedString(attributedText)
        let suggestedSize = CTFramesetterSuggestFrameSizeWithConstraints(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            nil,
            CGSize(width: textRect.width, height: .greatestFiniteMagnitude),
            nil
        )
        let textHeight = min(suggestedSize.height, textRect.height)
        let verticallyCenteredRect = CGRect(
            x: textRect.minX,
            y: textRect.midY - textHeight / 2,
            width: textRect.width,
            height: textHeight
        )
        let path = CGPath(rect: verticallyCenteredRect, transform: nil)
        let textFrame = CTFramesetterCreateFrame(
            framesetter,
            CFRange(location: 0, length: attributedText.length),
            path,
            nil
        )
        CTFrameDraw(textFrame, context)
    }
}
