//
//  Callouts+ActionCallout.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2021-01-06.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

public extension Callouts {
    
    /// This callout can show secondary actions in a callout.
    ///
    /// In iOS, this callout is presented when a button with
    /// secondary actions is long pressed.
    struct ActionCallout: View {
        
        /// Create an action callout.
        ///
        /// - Parameters:
        ///   - calloutContext: The callout context to use.
        ///   - keyboardContext: The keyboard context to use.
        ///   - emojiStyle: The emoji style to apply to the view, by default the standard style for the provided context.
        public init(
            calloutContext: CalloutContext.ActionContext,
            keyboardContext: KeyboardContext,
            emojiStyle: EmojiStyle? = nil
        ) {
            self._calloutContext = ObservedObject(wrappedValue: calloutContext)
            self._keyboardContext = ObservedObject(wrappedValue: keyboardContext)
            self.initStyle = nil
            self.emojiStyle = emojiStyle ?? EmojiStyle.standard(for: keyboardContext)
        }
        
        public typealias Context = CalloutContext.ActionContext
        public typealias EmojiStyle = EmojiKeyboardStyle
        
        @ObservedObject
        private var calloutContext: Context
        
        @ObservedObject
        private var keyboardContext: KeyboardContext
        
        private let emojiStyle: EmojiStyle
        
        @Environment(\.actionCalloutStyle)
        private var envStyle
        
        public var body: some View {
            Button(action: calloutContext.endDragGesture) {
                VStack(alignment: calloutContext.alignment, spacing: 0) {
                    callout
                    buttonArea
                }
            }
            .buttonStyle(.plain)
            .font(style.font.font)
            .compositingGroup()
            .opacity(calloutContext.isActive ? 1 : 0)
            .keyboardCalloutShadow(style: calloutStyle)
            .position(x: positionX, y: positionY)
            .offset(y: style.verticalOffset)
        }
        
        // MARK: - Deprecated
        
        @available(*, deprecated, message: "Use .actionCalloutStyle to apply the style instead.")
        public init(
            calloutContext: CalloutContext.ActionContext,
            keyboardContext: KeyboardContext,
            style: Callouts.ActionCalloutStyle,
            emojiStyle: EmojiKeyboardStyle? = nil
        ) {
            self._calloutContext = ObservedObject(wrappedValue: calloutContext)
            self._keyboardContext = ObservedObject(wrappedValue: keyboardContext)
            self.initStyle = style
            self.emojiStyle = emojiStyle ?? EmojiKeyboardStyle.standard(for: keyboardContext)
        }
        
        private typealias Style = Callouts.ActionCalloutStyle
        private let initStyle: Style?
        private var style: Style { initStyle ?? envStyle }
    }
}


// MARK: - Private Properties

private extension Callouts.ActionCallout {
    
    var backgroundColor: Color { calloutStyle.backgroundColor }
    var buttonFrame: CGRect { isEmojiCallout ? buttonFrameForEmojis : buttonFrameForCharacters }
    var buttonFrameSize: CGSize { buttonFrame.size }
    var buttonFrameForCharacters: CGRect { calloutContext.buttonFrame.insetBy(dx: buttonInset.width, dy: buttonInset.height) }
    var buttonFrameForEmojis: CGRect { calloutContext.buttonFrame }
    var buttonInset: CGSize { calloutStyle.buttonInset }
    var calloutActions: [KeyboardAction] { calloutContext.actions }
    var isFloatingMenuCallout: Bool {
        calloutActions.contains {
            if case .custom(let name) = $0 {
                return name == "floating_keyboard" || name == "split_keyboard" || name == "merge_keyboard"
            }
            return false
        }
    }
    var calloutButtonSize: CGSize {
        let frameSize = buttonFrame.size
        if isFloatingMenuCallout {
            return CGSize(width: max(frameSize.width * 1.8, 156), height: max(frameSize.height, 44))
        }
        let widthScale = (calloutActions.count == 1) ? 1.2 : 1
        let buttonSize = CGSize(width: frameSize.width * widthScale, height: frameSize.height)
        return buttonSize.limited(to: style.maxButtonSize)
    }
    var calloutStyle: Callouts.CalloutStyle { style.callout }
    var cornerRadius: CGFloat { calloutStyle.cornerRadius }
    var curveSize: CGSize { calloutStyle.curveSize }
    var isLeading: Bool { calloutContext.isLeading }
    var isTrailing: Bool { calloutContext.isTrailing }
    
    var buttonArea: some View {
        Callouts.ButtonArea(
            frame: buttonFrame
        )
        .opacity(isPad ? 0 : 1)
        .calloutStyle(calloutStyle)
    }
    
    @ViewBuilder
    var callout: some View {
        if isFloatingMenuCallout {
            let reversedItems = Array(calloutActions.enumerated().reversed())
            VStack(spacing: 0) {
                ForEach(Array(reversedItems.enumerated()), id: \.element.offset) { rowIdx, item in
                    calloutView(for: item.element)
                        .frame(width: calloutButtonSize.width, height: calloutButtonSize.height)
                        .background(isSelected(item.offset) ? style.selectedBackgroundColor : .clear)
                        .foregroundColor(isSelected(item.offset) ? style.selectedForegroundColor : style.callout.textColor)
                        .cornerRadius(cornerRadius)
                        .padding(.vertical, style.verticalTextPadding)
                    if rowIdx < reversedItems.count - 1 {
                        Color.secondary.opacity(0.28)
                            .frame(width: max(calloutButtonSize.width - 16, 40), height: 0.5)
                    }
                }
            }
            .padding(.horizontal, curveSize.width)
            .background(calloutBackground)
        } else {
            HStack(spacing: 0) {
                ForEach(Array(calloutActions.enumerated()), id: \.offset) {
                    calloutView(for: $0.element)
                        .frame(width: calloutButtonSize.width, height: calloutButtonSize.height)
                        .background(isSelected($0.offset) ? style.selectedBackgroundColor : .clear)
                        .foregroundColor(isSelected($0.offset) ? style.selectedForegroundColor : style.callout.textColor)
                        .cornerRadius(cornerRadius)
                        .padding(.vertical, style.verticalTextPadding)
                }
            }
            .padding(.horizontal, curveSize.width)
            .background(calloutBackground)
        }
    }
    
    var calloutBackground: some View {
        CustomRoundedRectangle(
            topLeft: cornerRadius,
            topRight: cornerRadius,
            bottomLeft: !isPad && isLeading ? 2 : cornerRadius,
            bottomRight: !isPad && isTrailing ? 2 : cornerRadius
        )
        .foregroundColor(backgroundColor)
    }

    @ViewBuilder
    func calloutView(for action: KeyboardAction) -> some View {
        switch action {
        case .character(let char): calloutView(for: char)
        case .emoji(let emoji): calloutView(for: emoji)
        case .custom(let name) where name == "floating_keyboard":
            Text(floatingKeyboardTitle)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("callout.floating_keyboard")
        case .custom(let name) where name == "split_keyboard":
            Text(splitKeyboardTitle)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("callout.split_keyboard")
        case .custom(let name) where name == "merge_keyboard":
            Text(mergeKeyboardTitle)
                .font(.system(size: 16, weight: .medium))
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityIdentifier("callout.merge_keyboard")
        default: EmptyView()
        }
    }

    private var resolvedInterfaceLanguage: String {
        let suite = UserDefaults(suiteName: "group.crh.key.keyboardplus")
        return suite?.string(forKey: "crh.key.interfaceLanguage")
            ?? suite?.string(forKey: "crh.key.language")
            ?? Locale.preferredLanguages.first
            ?? "crh"
    }

    var floatingKeyboardTitle: String {
        if keyboardContext.locale.identifier.contains("Cyrl") {
            return "Юзюджи"
        }
        let preferred = resolvedInterfaceLanguage
        if preferred.hasPrefix("uk") {
            return "Плаваюча"
        } else if preferred.hasPrefix("en") {
            return "Floating"
        }
        return "Yüzüci"
    }

    var splitKeyboardTitle: String {
        if keyboardContext.locale.identifier.contains("Cyrl") {
            return "Болюнген"
        }
        let preferred = resolvedInterfaceLanguage
        if preferred.hasPrefix("uk") {
            return "Розділити"
        } else if preferred.hasPrefix("en") {
            return "Split"
        }
        return "Bölüngen"
    }

    var mergeKeyboardTitle: String {
        if keyboardContext.locale.identifier.contains("Cyrl") {
            return "Бирлештир"
        }
        let preferred = resolvedInterfaceLanguage
        if preferred.hasPrefix("uk") {
            return "Об’єднати"
        } else if preferred.hasPrefix("en") {
            return "Dock & Merge"
        }
        return "Birleştir"
    }

    func calloutView(for character: String) -> some View {
        Text(character)
    }

    func calloutView(for emoji: Emoji) -> some View {
        Text(emoji.char)
            .font(emojiStyle.itemFont)
    }
    
    var positionX: CGFloat {
        let buttonWidth = calloutButtonSize.width
        let horizontalCount = isFloatingMenuCallout ? 1 : calloutActions.count
        let adjustment = (CGFloat(horizontalCount) * buttonWidth)/2
        let widthDiff = buttonWidth - buttonFrameSize.width
        let signedAdjustment = isTrailing ? -adjustment + buttonWidth - widthDiff : adjustment
        return buttonFrame.origin.x + signedAdjustment
    }
    
    var positionY: CGFloat {
        let ideal = buttonFrame.maxY - totalCalloutHeight / 2
        let minCenterY = totalCalloutHeight / 2 + Self.topEdgeInset
        return max(ideal, minCenterY)
    }
    
    var totalCalloutHeight: CGFloat {
        let verticalCount = isFloatingMenuCallout ? CGFloat(calloutActions.count) : 1
        let bubbleHeight = verticalCount * (calloutButtonSize.height + 2 * style.verticalTextPadding)
        return bubbleHeight + buttonFrameSize.height
    }
    
    static let topEdgeInset: CGFloat = 4
}


// MARK: - Private Functions

private extension Callouts.ActionCallout {
    
    var isPad: Bool { keyboardContext.deviceType == .pad && !keyboardContext.isKeyboardFloating }

    var isEmojiCallout: Bool {
        calloutActions.first?.isEmojiAction ?? false
    }

    func isSelected(_ offset: Int) -> Bool {
        calloutContext.selectedIndex == offset
    }
}

private extension KeyboardAction {
    
    var input: String? {
        switch self {
        case .character(let char): return char
        default: return nil
        }
    }
}

#Preview {

    let actionContext1 = Callouts.ActionCallout.Context(
        actionProvider: .preview,
        tapAction: { _ in }
    )

    let actionContext2 = Callouts.ActionCallout.Context(
        actionProvider: .preview,
        tapAction: { _ in }
    )

    @MainActor
    func previewGroup<ButtonView: View>(
        view: ButtonView,
        actionContext: CalloutContext.ActionContext,
        alignment: HorizontalAlignment
    ) -> some View {
        view.overlay(
            GeometryReader { geo in
                Color.clear.onAppear {
                    actionContext.updateInputs(
                        for: .character("a"),
                        in: geo,
                        alignment: alignment
                    )
                }
            }
        )
        .keyboardActionCalloutContainer(
            calloutContext: actionContext,
            keyboardContext: .preview
        )
    }
    
    return VStack {
        previewGroup(
            view: Color.red.frame(width: 40, height: 50),
            actionContext: actionContext1,
            alignment: .leading
        )
        previewGroup(
            view: Color.yellow.frame(width: 40, height: 50),
            actionContext: actionContext2,
            alignment: .trailing
        )
    }
    .actionCalloutStyle(.init(
        callout: .preview2,
        selectedBackgroundColor: .purple
    ))
}
