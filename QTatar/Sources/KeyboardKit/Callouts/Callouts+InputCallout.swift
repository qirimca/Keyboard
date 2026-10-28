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
            callout
                .transition(.opacity)
                .opacity(calloutContext.isActive ? 1 : 0)
                .keyboardCalloutShadow(style: style.callout)
                .position(position)
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

private extension Callouts.InputCallout {

    var usesModernPillStyle: Bool {
        style.callout.curveSize.width <= 0.01 && style.callout.curveSize.height <= 0.01
    }

    @ViewBuilder
    var callout: some View {
        if usesModernPillStyle {
            modernPillCallout
        } else {
            VStack(spacing: 0) {
                calloutBubble.offset(y: 1)
                calloutButton
            }
            .compositingGroup()
        }
    }

    var modernPillCallout: some View {
        let pillWidth = modernPillWidth
        let pillHeight = modernPillHeight
        return ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(style.callout.backgroundColor)
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
        .compositingGroup()
    }

    var calloutBubble: some View {
        Text(calloutContext.input ?? "")
            .font(isTopConstrained ? .system(size: 30.0, weight: .regular) : style.font.font)
            .frame(width: calloutSize.width, height: effectiveCalloutHeight * 0.96)
            .frame(width: calloutSize.width, height: effectiveCalloutHeight, alignment: .top)
            .foregroundColor(style.callout.textColor)
            .background(
                CustomRoundedRectangle(
                    topLeft: cornerRadius,
                    topRight: cornerRadius,
                    bottomLeft: 0,
                    bottomRight: 0
                )
                .foregroundColor(style.callout.backgroundColor)
            )
    }
    
    var calloutButton: some View {
        Callouts.ButtonArea(
            frame: CGRect(origin: buttonFrame.origin, size: CGSize(width: buttonSize.width, height: effectiveButtonHeight)),
            leftCurveWidth: leftExpand,
            rightCurveWidth: rightExpand
        )
        .calloutStyle(style.callout)
    }
}

private extension Callouts.InputCallout {
    
    var buttonFrame: CGRect {
        calloutContext.buttonFrame.insetBy(
            dx: buttonInset.width,
            dy: buttonInset.height)
    }
    
    var buttonInset: CGSize {
        style.callout.buttonInset
    }
    
    var buttonSize: CGSize {
        buttonFrame.size
    }

    var minVisibleY: CGFloat {
        -calloutContext.topAvailableSpace + 1.0
    }

    var isTopConstrained: Bool {
        buttonSize.height > 0 && (buttonFrame.minY - calloutSizeHeight) < minVisibleY - 4.0
    }

    var effectiveCalloutHeight: CGFloat {
        guard isTopConstrained else { return calloutSizeHeight }
        let maxBottomY = buttonFrame.maxY + 4.0
        let totalAvailable = max(36.0, maxBottomY - minVisibleY)
        return max(28.0, totalAvailable - effectiveButtonHeight)
    }

    var effectiveButtonHeight: CGFloat {
        guard isTopConstrained else { return buttonSize.height }
        let maxBottomY = buttonFrame.maxY + 4.0
        let totalAvailable = max(36.0, maxBottomY - minVisibleY)
        return min(buttonSize.height, max(16.0, totalAvailable * 0.34))
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
        style.callout.curveSize.width
    }

    var leftExpand: CGFloat {
        if isLeadingEdge { return 0 }
        if isTrailingEdge { return round(1.35 * baseCurveWidth) }
        return baseCurveWidth
    }

    var rightExpand: CGFloat {
        if isTrailingEdge { return 0 }
        if isLeadingEdge { return round(1.35 * baseCurveWidth) }
        return baseCurveWidth
    }

    var modernPillHorizontalExpand: CGFloat {
        shouldEnforceSmallSize ? 8.0 : (keyboardContext.isKeyboardFloating ? 12.0 : 16.0)
    }

    var modernPillWidth: CGFloat {
        guard buttonSize.width > 0 else { return style.calloutSize.width }
        return max(buttonSize.width + modernPillHorizontalExpand, style.calloutSize.width)
    }

    var modernPillHeight: CGFloat {
        if shouldEnforceSmallSize {
            return max(buttonSize.height + 6.0, 40.0)
        }
        if isTopConstrained {
            return max(buttonSize.height + 6.0, 48.0)
        }
        return keyboardContext.isKeyboardFloating ? 52.0 : 60.0
    }
    
    var calloutSize: CGSize {
        CGSize(
            width: calloutSizeWidth,
            height: calloutSizeHeight
        )
    }
    
    var calloutSizeHeight: CGFloat {
        let smallSize = buttonSize.height
        return shouldEnforceSmallSize ? smallSize : style.calloutSize.height
    }
    
    var calloutSizeWidth: CGFloat {
        guard buttonSize.width > 0 else { return style.calloutSize.width }
        return buttonSize.width + leftExpand + rightExpand
    }
    
    var cornerRadius: CGFloat {
        shouldEnforceSmallSize ? style.callout.buttonCornerRadius : style.callout.cornerRadius
    }
}

private extension Callouts.InputCallout {

    var shouldEnforceSmallSize: Bool {
        keyboardContext.deviceType == .phone && keyboardContext.interfaceOrientation.isLandscape
    }

    var position: CGPoint {
        CGPoint(x: positionX, y: positionY)
    }

    var positionX: CGFloat {
        if usesModernPillStyle {
            let rawCenter = buttonFrame.midX
            let halfW = modernPillWidth / 2
            let minX = halfW + 3
            if resolvedContainerWidth > modernPillWidth + 6 {
                let maxX = resolvedContainerWidth - halfW - 3
                return min(max(rawCenter, minX), maxX)
            }
            return max(rawCenter, minX)
        }
        return buttonFrame.origin.x + buttonSize.width / 2 + (rightExpand - leftExpand) / 2
    }

    var positionY: CGFloat {
        if usesModernPillStyle {
            let desiredBottomY = buttonFrame.minY + 1.0
            let rawCenterY = desiredBottomY - modernPillHeight / 2.0
            let clampedTopY = minVisibleY + modernPillHeight / 2.0
            return max(rawCenterY, clampedTopY)
        }
        if isTopConstrained {
            return minVisibleY + totalCalloutHeight / 2
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
