//
//  Callouts+ButtonArea.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-09-30.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

public extension Callouts {
    
    /// This view is used to cover the part of a button that
    /// was tapped or pressed to trigger the callout.
    struct ButtonArea: View {
        
        /// Create a callout button area.
        ///
        /// - Parameters:
        ///   - frame: The button area frame.
        public init(
            frame: CGRect,
            leftCurveWidth: CGFloat? = nil,
            rightCurveWidth: CGFloat? = nil
        ) {
            self.frame = frame
            self.leftCurveWidth = leftCurveWidth
            self.rightCurveWidth = rightCurveWidth
            self.initStyle = nil
        }
        
        private let frame: CGRect
        private let leftCurveWidth: CGFloat?
        private let rightCurveWidth: CGFloat?
        
        @Environment(\.calloutStyle)
        private var envStyle
        
        public var body: some View {
            HStack(alignment: .top, spacing: 0) {
                if resolvedLeftCurveWidth > 0 {
                    leftCalloutCurve.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                }
                buttonBody
                if resolvedRightCurveWidth > 0 {
                    rightCalloutCurve
                }
            }
        }
        
        // MARK: - Deprecated
        
        @available(*, deprecated, message: "Use .calloutStyle to apply the style instead.")
        public init(
            frame: CGRect,
            style: Callouts.CalloutStyle = .standard
        ) {
            self.frame = frame
            self.leftCurveWidth = nil
            self.rightCurveWidth = nil
            self.initStyle = style
        }
        
        private typealias Style = Callouts.CalloutStyle
        private let initStyle: Style?
        private var style: Style { initStyle ?? envStyle }
    }
}

private extension Callouts.ButtonArea {
    
    var backgroundColor: Color { style.backgroundColor }
    var cornerRadius: CGFloat { style.buttonCornerRadius }
    var curveSize: CGSize { style.curveSize }
    var resolvedLeftCurveWidth: CGFloat { max(0, leftCurveWidth ?? curveSize.width) }
    var resolvedRightCurveWidth: CGFloat { max(0, rightCurveWidth ?? curveSize.width) }
    
    var buttonBody: some View {
        CustomRoundedRectangle(bottomLeft: cornerRadius, bottomRight: cornerRadius)
            .foregroundColor(backgroundColor)
            .frame(width: frame.size.width, height: frame.size.height)
    }
    
    var leftCalloutCurve: some View {
        Callouts.Curve()
            .frame(width: resolvedLeftCurveWidth, height: curveSize.height)
            .foregroundColor(backgroundColor)
    }

    var rightCalloutCurve: some View {
        Callouts.Curve()
            .frame(width: resolvedRightCurveWidth, height: curveSize.height)
            .foregroundColor(backgroundColor)
    }
}

#Preview {
    
    Callouts.ButtonArea(
        frame: CGRect(x: 0, y: 0, width: 50, height: 50)
    )
    .padding(30)
    .background(Color.gray)
    .cornerRadius(20)
    .calloutStyle(.preview1)
}
