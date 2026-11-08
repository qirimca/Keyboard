//
//  Callouts+InputCallout.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-06.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

public extension Callouts {
    
    /// This callout can show the pressed char in a callout.
    ///
    /// In iOS, this callout is presented when a button with
    /// an input character is pressed.
    struct InputCallout: View {
        
        /// Create a custom input callout.
        ///
        /// - Parameters:
        ///   - calloutContext: The callout context to use.
        ///   - keyboardContext: The keyboard context to use.
        public init(
            calloutContext: Context,
            keyboardContext: KeyboardContext
        ) {
            self._calloutContext = ObservedObject(wrappedValue: calloutContext)
            self._keyboardContext = ObservedObject(wrappedValue: keyboardContext)
            self.initStyle = nil
        }
        
        public typealias Context = CalloutContext.InputContext
        
        @ObservedObject
        private var calloutContext: Context
        
        @ObservedObject
        private var keyboardContext: KeyboardContext
        
        @Environment(\.inputCalloutStyle)
        private var envStyle
        
        public var body: some View {
            ZStack(alignment: .topLeading) {
                Color.clear
                if calloutContext.isActive && buttonSize.width > 0 && buttonSize.height > 0 && buttonFrame.midX > 0 && buttonFrame.midY > 0 {
                    callout
                        .offset(x: calloutOriginX, y: calloutOriginY)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
        }
        
        // MARK: - Deprecated
        
        @available(*, deprecated, message: "Use .inputCalloutStyle to apply the style instead.")
        public init(
            calloutContext: Context,
            keyboardContext: KeyboardContext,
            style: Callouts.InputCalloutStyle = .standard
        ) {
            self._calloutContext = ObservedObject(wrappedValue: calloutContext)
            self._keyboardContext = ObservedObject(wrappedValue: keyboardContext)
            self.initStyle = style
        }
        
        private typealias Style = Callouts.InputCalloutStyle
        private let initStyle: Style?
        private var style: Style { initStyle ?? envStyle }
    }
}

private struct InputCalloutBubbleShape: Shape {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat
    let leftExpand: CGFloat
    let rightExpand: CGFloat
    let topHeight: CGFloat
    let curveHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let w = max(1, rect.width)
        let h = max(1, rect.height)
        let topH = min(max(1, topHeight), h)
        let bottomH = max(0, h - topH)
        let topR = min(topCornerRadius, w / 2, topH / 2)
        let stemMinX = min(max(0, leftExpand), w)
        let stemMaxX = max(stemMinX, w - max(0, rightExpand))
        let stemW = max(1, stemMaxX - stemMinX)
        let bottomR = min(bottomCornerRadius, stemW / 2, max(1, bottomH / 2))
        let neckH = min(max(4, curveHeight), max(4, bottomH * 0.72))

        var p = Path()
        p.move(to: CGPoint(x: topR, y: 0))
        p.addLine(to: CGPoint(x: w - topR, y: 0))
        p.addArc(
            tangent1End: CGPoint(x: w, y: 0),
            tangent2End: CGPoint(x: w, y: topR),
            radius: topR
        )

        if rightExpand > 0.5 && bottomH > 1 {
            let neckStartY = max(topR, topH - neckH * 0.42)
            let neckEndY = min(h - bottomR, topH + neckH * 0.58)
            let neckMidY = (neckStartY + neckEndY) * 0.5
            p.addLine(to: CGPoint(x: w, y: neckStartY))
            p.addCurve(
                to: CGPoint(x: stemMaxX, y: neckEndY),
                control1: CGPoint(x: w, y: neckMidY),
                control2: CGPoint(x: stemMaxX, y: neckMidY)
            )
            p.addLine(to: CGPoint(x: stemMaxX, y: h - bottomR))
        } else {
            p.addLine(to: CGPoint(x: stemMaxX, y: h - bottomR))
        }

        p.addArc(
            tangent1End: CGPoint(x: stemMaxX, y: h),
            tangent2End: CGPoint(x: stemMaxX - bottomR, y: h),
            radius: bottomR
        )
        p.addLine(to: CGPoint(x: stemMinX + bottomR, y: h))
        p.addArc(
            tangent1End: CGPoint(x: stemMinX, y: h),
            tangent2End: CGPoint(x: stemMinX, y: h - bottomR),
            radius: bottomR
        )

        if leftExpand > 0.5 && bottomH > 1 {
            let neckStartY = max(topR, topH - neckH * 0.42)
            let neckEndY = min(h - bottomR, topH + neckH * 0.58)
            let neckMidY = (neckStartY + neckEndY) * 0.5
            p.addLine(to: CGPoint(x: stemMinX, y: neckEndY))
            p.addCurve(
                to: CGPoint(x: 0, y: neckStartY),
                control1: CGPoint(x: stemMinX, y: neckMidY),
                control2: CGPoint(x: 0, y: neckMidY)
            )
            p.addLine(to: CGPoint(x: 0, y: topR))
        } else {
            p.addLine(to: CGPoint(x: 0, y: topR))
        }

        p.addArc(
            tangent1End: CGPoint(x: 0, y: 0),
            tangent2End: CGPoint(x: topR, y: 0),
            radius: topR
        )
        p.closeSubpath()
        return p
    }
}

private extension Callouts.InputCallout {

    var usesModernPillStyle: Bool {
        guard #available(iOS 27.0, *), !keyboardContext.isKeyboardFloating, keyboardContext.deviceType == .phone else { return false }
        return style.callout.curveSize.width <= 0.01 && style.callout.curveSize.height <= 0.01
    }

    @ViewBuilder
    var callout: some View {
        if usesModernPillStyle {
            modernPillCallout
        } else {
            classicBulbCallout
        }
    }

    var modernPillCallout: some View {
        let pillWidth = modernPillWidth
        let pillHeight = modernPillHeight
        return ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(style.callout.backgroundColor)
                .shadow(color: style.callout.shadowColor, radius: style.callout.shadowRadius, x: 0, y: 1.5)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(style.callout.borderColor, lineWidth: 0.5)
                )
            Text(calloutContext.input ?? "")
                .font(isTopConstrained ? .system(size: 30.0, weight: .regular) : style.font.font)
                .foregroundColor(style.callout.textColor)
                .frame(width: pillWidth, height: pillHeight, alignment: .center)
        }
        .frame(width: pillWidth, height: pillHeight)
    }

    var classicBulbCallout: some View {
        let totalWidth = max(1, calloutSize.width)
        let topH = max(1, effectiveCalloutHeight)
        let bottomH = max(1, effectiveButtonHeight)
        let totalH = topH + bottomH
        let bulbShape = InputCalloutBubbleShape(
            topCornerRadius: cornerRadius,
            bottomCornerRadius: style.callout.buttonCornerRadius,
            leftExpand: leftExpand,
            rightExpand: rightExpand,
            topHeight: topH,
            curveHeight: style.callout.curveSize.height
        )
        return ZStack(alignment: .top) {
            bulbShape
                .fill(style.callout.backgroundColor)
                .shadow(color: style.callout.shadowColor, radius: style.callout.shadowRadius, x: 0, y: 1.5)
            bulbShape
                .stroke(style.callout.borderColor, lineWidth: 0.5)
            Text(calloutContext.input ?? "")
                .font(isTopConstrained ? .system(size: 30.0, weight: .regular) : style.font.font)
                .foregroundColor(style.callout.textColor)
                .frame(width: totalWidth, height: topH, alignment: .center)
        }
        .frame(width: totalWidth, height: totalH)
    }
}

private extension Callouts.InputCallout {
    
    var buttonFrame: CGRect {
        let raw = calloutContext.buttonFrame
        guard raw.width > buttonInset.width * 2,
              raw.height > buttonInset.height * 2,
              raw.origin.x.isFinite,
              raw.origin.y.isFinite else {
            return .zero
        }
        return raw.insetBy(
            dx: buttonInset.width,
            dy: buttonInset.height)
    }
    
    var buttonInset: CGSize {
        style.callout.buttonInset
    }
    
    var buttonSize: CGSize {
        CGSize(
            width: max(0, buttonFrame.size.width),
            height: max(0, buttonFrame.size.height)
        )
    }

    var minVisibleY: CGFloat {
        2.0 - calloutContext.topAvailableSpace
    }

    var isTopConstrained: Bool {
        false
    }

    var effectiveCalloutHeight: CGFloat {
        guard isTopConstrained else { return calloutSizeHeight }
        let availableAboveKey = buttonFrame.minY - minVisibleY
        return max(38.0, min(calloutSizeHeight, availableAboveKey))
    }

    var effectiveButtonHeight: CGFloat {
        buttonSize.height
    }
    
    var resolvedContainerWidth: CGFloat {
        if calloutContext.containerWidth > 0 {
            return calloutContext.containerWidth
        }
        #if os(iOS)
        if keyboardContext.screenSize.width > 0 {
            return keyboardContext.screenSize.width
        }
        return UIScreen.main.bounds.width
        #else
        return 0
        #endif
    }

    var edgeThreshold: CGFloat {
        max(buttonSize.width * 0.65, 18)
    }

    var isLeadingEdge: Bool {
        buttonFrame.width > 0 && buttonFrame.minX < edgeThreshold
    }

    var isTrailingEdge: Bool {
        buttonFrame.width > 0 && resolvedContainerWidth > 0 && (resolvedContainerWidth - buttonFrame.maxX) < edgeThreshold
    }

    var baseCurveWidth: CGFloat {
        let minExpand = max(style.callout.curveSize.width, 11.0)
        guard buttonSize.width > 0 else { return minExpand }
        let targetWidth = max(style.calloutSize.width, buttonSize.width + 22.0)
        return max(minExpand, round((targetWidth - buttonSize.width) / 2.0))
    }

    var leftExpand: CGFloat {
        if isLeadingEdge { return 0 }
        if isTrailingEdge { return round(1.85 * baseCurveWidth) }
        return baseCurveWidth
    }

    var rightExpand: CGFloat {
        if isTrailingEdge { return 0 }
        if isLeadingEdge { return round(1.85 * baseCurveWidth) }
        return baseCurveWidth
    }

    var modernPillHorizontalExpand: CGFloat {
        shouldEnforceSmallSize ? 8.0 : (keyboardContext.isKeyboardFloating ? 7.0 : 8.0)
    }

    var modernPillWidth: CGFloat {
        guard buttonSize.width > 0 else { return style.calloutSize.width }
        return max(buttonSize.width + modernPillHorizontalExpand, style.calloutSize.width)
    }

    var modernPillHeight: CGFloat {
        let baseHeight: CGFloat
        if shouldEnforceSmallSize {
            baseHeight = max(buttonSize.height + 10.0, 42.0)
        } else {
            baseHeight = keyboardContext.isKeyboardFloating ? 50.0 : 56.0
        }
        guard buttonFrame.height > 0, calloutContext.topAvailableSpace > 0 else {
            return baseHeight
        }
        let desiredBottomY = buttonFrame.minY - 1.5
        let minTopY = 1.5 - calloutContext.topAvailableSpace
        let availableAboveKey = desiredBottomY - minTopY
        return max(36.0, min(baseHeight, availableAboveKey))
    }
    
    var calloutSize: CGSize {
        CGSize(
            width: calloutSizeWidth,
            height: calloutSizeHeight
        )
    }
    
    var calloutSizeHeight: CGFloat {
        let smallSize = max(buttonSize.height + 12.0, 45.0)
        return shouldEnforceSmallSize ? smallSize : style.calloutSize.height
    }
    
    var calloutSizeWidth: CGFloat {
        guard buttonSize.width > 0 else { return style.calloutSize.width }
        return buttonSize.width + leftExpand + rightExpand
    }
    
    var cornerRadius: CGFloat {
        shouldEnforceSmallSize ? max(11.0, style.callout.cornerRadius) : style.callout.cornerRadius
    }
}

private extension Callouts.InputCallout {

    var shouldEnforceSmallSize: Bool {
        keyboardContext.deviceType == .phone && keyboardContext.interfaceOrientation.isLandscape
    }

    var position: CGPoint {
        CGPoint(x: positionX, y: positionY)
    }

    var calloutOriginX: CGFloat {
        if usesModernPillStyle {
            return positionX - modernPillWidth / 2.0
        }
        return positionX - calloutSize.width / 2.0
    }

    var calloutOriginY: CGFloat {
        if usesModernPillStyle {
            return positionY - modernPillHeight / 2.0
        }
        let isEmoji = calloutContext.action?.isEmojiAction == true
        return buttonFrame.minY - effectiveCalloutHeight + (isEmoji ? 5.0 : 0.0)
    }

    var positionX: CGFloat {
        if usesModernPillStyle {
            let rawCenter = buttonFrame.midX
            let halfPill = modernPillWidth / 2.0
            let minX = max(halfPill + 2.5, buttonFrame.minX + buttonSize.width * 0.35)
            if resolvedContainerWidth > modernPillWidth + 5.0 {
                let maxX = min(resolvedContainerWidth - halfPill - 2.5, buttonFrame.maxX - buttonSize.width * 0.35)
                if minX <= maxX {
                    return min(max(rawCenter, minX), maxX)
                }
                return min(max(rawCenter, halfPill + 2.5), resolvedContainerWidth - halfPill - 2.5)
            }
            return max(rawCenter, halfPill + 2.5)
        }
        let rawBulbCenter = buttonFrame.origin.x + buttonSize.width / 2 + (rightExpand - leftExpand) / 2
        let halfBulb = calloutSize.width / 2.0
        if resolvedContainerWidth > calloutSize.width + 4.0 {
            return min(max(rawBulbCenter, halfBulb + 2.0), resolvedContainerWidth - halfBulb - 2.0)
        }
        return max(rawBulbCenter, halfBulb + 2.0)
    }

    var positionY: CGFloat {
        if usesModernPillStyle {
            let desiredBottomY = buttonFrame.minY - 1.5
            let unclampedY = desiredBottomY - modernPillHeight / 2.0
            let minPillCenterY = (1.5 - calloutContext.topAvailableSpace) + modernPillHeight / 2.0
            return max(minPillCenterY, unclampedY)
        }
        let base = buttonFrame.origin.y + buttonSize.height / 2 - effectiveCalloutHeight / 2
        let isEmoji = calloutContext.action?.isEmojiAction == true
        return isEmoji ? base + 5 : base
    }
    
    var totalCalloutHeight: CGFloat {
        effectiveCalloutHeight + effectiveButtonHeight
    }
}


// MARK: - Previews

#if os(iOS) || os(macOS) || os(watchOS)
#Preview {

    struct Preview: View {

        var style: Callouts.InputCalloutStyle {
            var style = Callouts.InputCalloutStyle.standard
            style.callout.backgroundColor = .blue
            style.callout.textColor = .white
            style.callout.buttonInset = CGSize(width: 3, height: 3)
            return style
        }

        @StateObject
        var context = CalloutContext.InputContext(isEnabled: true)

        func button(for context: CalloutContext.InputContext) -> some View {
            GeometryReader { geo in
                Gestures.GestureButton(
                    pressAction: { showCallout(for: geo) },
                    endAction: context.resetWithDelay,
                    label: { _ in Color.red.cornerRadius(5) }
                )
            }
            .frame(width: 15, height: 15)
            .padding()
            .background(Color.yellow.cornerRadius(6))
        }

        func showCallout(for geo: GeometryProxy) {
            context.updateInput(for: .character("a"), in: geo)
        }

        var buttonStack: some View {
            HStack {
                button(for: context)
                button(for: context)
                button(for: context)
            }
        }

        var body: some View {
            VStack {
                buttonStack
                buttonStack
                Button("Reset") {
                    context.reset()
                }
            }
            .keyboardInputCalloutContainer(
                calloutContext: context,
                keyboardContext: .preview
            )
        }
    }

    return Preview()
        .inputCalloutStyle(.init(
            callout: .init(backgroundColor: .red)
        ))
}
#endif
