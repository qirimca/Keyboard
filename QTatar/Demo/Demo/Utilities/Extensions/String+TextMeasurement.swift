//
//  String+TextMeasurement.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import UIKit

extension String {
    
    func textWidth(
        fontName: String,
        size: CGFloat
    ) -> CGFloat {
        let font = UIFont(name: fontName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .medium)
        return ceil((self as NSString).size(withAttributes: [.font: font]).width)
    }
    
    func textHeight(
        fontName: String,
        size: CGFloat,
        maxWidth: CGFloat,
        maxLines: Int
    ) -> CGFloat {
        let font = UIFont(name: fontName, size: size)
            ?? UIFont.systemFont(ofSize: size, weight: .medium)
        let rect = (self as NSString).boundingRect(
            with: CGSize(width: maxWidth, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font],
            context: nil
        )
        return min(ceil(rect.height), font.lineHeight * CGFloat(maxLines))
    }
    
    static func uniformFontSize(
        for titles: [String],
        maxTextWidth: CGFloat,
        maxTextHeight: CGFloat,
        fontName: String = "GeneralSans-Medium",
        baseSize: CGFloat = 16,
        minSize: CGFloat = 8,
        maxLines: Int = 2
    ) -> CGFloat {
        guard maxTextWidth > 0, maxTextHeight > 0 else { return minSize }
        
        var size = baseSize
        while size > minSize {
            let fits = titles.allSatisfy {
                $0.textHeight(
                    fontName: fontName,
                    size: size,
                    maxWidth: maxTextWidth,
                    maxLines: maxLines
                ) <= maxTextHeight
            }
            if fits { return size }
            size -= 0.5
        }
        return minSize
    }
}
