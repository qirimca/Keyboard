//
//  SystemKeyboard.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2020-12-02.
//  Copyright © 2020-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

/**
 This keyboard can be used to create alphabetic, numeric and
 symbolic keyboards that mimic the native iOS keyboard.
 
 KeyboardKit will by default use a standard ``SystemKeyboard``
 if you don't provide a custom view. So, if you just want to
 use such a standard keyboard, you don't have to do anything.
 
 If you want to customize the system keyboard, just override
 ``KeyboardInputViewController/viewWillSetupKeyboard()`` and
 call any of the `setup(with:)` functions with a custom view.
 
 For more information on how to customize this view, as well
 as code examples, see <doc:Essentials>.
 */
public struct SystemKeyboard<
    ButtonContent: View,
    ButtonView: View,
    EmojiKeyboard: View,
    Toolbar: View>: View {
    
    /**
     Create a system keyboard based on state and services.
     
     - Parameters:
       - state: The value to fetch observable state from.
       - services: The value to fetch keyboard services from.
       - renderBackground: Whether or not to render the background, by default `true`.
       - buttonContent: The content view to use for buttons.
       - buttonView: The button view to use for an buttons.
       - emojiKeyboard: The emoji keyboard to use for an ``Keyboard/KeyboardType/emojis`` keyboard.
       - toolbar: The toolbar view to add above the keyboard.
     */
    public init(
        state: Keyboard.KeyboardState,
        services: Keyboard.KeyboardServices,
        renderBackground: Bool = true,
        @ViewBuilder buttonContent: @escaping ButtonContentBuilder,
        @ViewBuilder buttonView: @escaping ButtonViewBuilder,
        @ViewBuilder emojiKeyboard: @escaping EmojiKeyboardBuilder,
        @ViewBuilder toolbar: @escaping ToolbarBuilder
    ) {
        self.init(
            layout: services.layoutProvider.keyboardLayout(for: state.keyboardContext),
            actionHandler: services.actionHandler,
            styleProvider: services.styleProvider,
            keyboardContext: state.keyboardContext,
            autocompleteContext: state.autocompleteContext,
            calloutContext: state.calloutContext,
            renderBackground: renderBackground,
            buttonContent: buttonContent,
            buttonView: buttonView,
            emojiKeyboard: emojiKeyboard,
            toolbar: toolbar
        )
    }
    
    /**
     Create a system keyboard based on raw properties.
     
     - Parameters:
       - layout: The layout to use.
       - actionHandler: The action handler to use.
       - styleProvider: The style provider to use.
       - keyboardContext: The keyboard context to use.
       - autocompleteContext: The autocomplete context to use.
       - calloutContext: The callout context to use.
       - renderBackground: Whether or not to render the background, by default `true`.
       - buttonContent: The content view to use for buttons.
       - buttonView: The button view to use for an buttons.
       - emojiKeyboard: The emoji keyboard to use for an ``Keyboard/KeyboardType/emojis`` keyboard.
       - toolbar: The toolbar view to add above the keyboard.
     */
    public init(
        layout: KeyboardLayout,
        actionHandler: KeyboardActionHandler,
        styleProvider: KeyboardStyleProvider,
        keyboardContext: KeyboardContext,
        autocompleteContext: AutocompleteContext,
        calloutContext: CalloutContext?,
        renderBackground: Bool = true,
        @ViewBuilder buttonContent: @escaping ButtonContentBuilder,
        @ViewBuilder buttonView: @escaping ButtonViewBuilder,
        @ViewBuilder emojiKeyboard: @escaping EmojiKeyboardBuilder,
        @ViewBuilder toolbar: @escaping ToolbarBuilder
    ) {
        self.layout = layout
        self.layoutConfig = (styleProvider as? StandardKeyboardStyleProvider)?
            .keyboardLayoutConfiguration
            ?? .standard(for: keyboardContext)
        self.actionHandler = actionHandler
        self.styleProvider = styleProvider
        self.renderBackground = renderBackground
        self.buttonContentBuilder = buttonContent
        self.buttonViewBuilder = buttonView
        self.emojiKeyboardBuilder = emojiKeyboard
        self.toolbarBuilder = toolbar
        _autocompleteContext = ObservedObject(wrappedValue: autocompleteContext)
        _calloutContext = ObservedObject(wrappedValue: calloutContext ?? .disabled)
        _keyboardContext = ObservedObject(wrappedValue: keyboardContext)
    }


    /// This typealias defines a button content builder.
    public typealias ButtonContentBuilder = (ButtonContentParams) -> ButtonContent
    
    /// This typealias defines button content builder params.
    public typealias ButtonContentParams = (
        item: KeyboardLayout.Item,
        view: StandardButtonContent)
    
    /// The standard button content view type.
    public typealias StandardButtonContent = Keyboard.ButtonContent
    
    
    /// This typealias defines a button view builder.
    public typealias ButtonViewBuilder = (ButtonViewParams) -> ButtonView
    
    /// This typealias defines button view builder params.
    public typealias ButtonViewParams = (
        item: KeyboardLayout.Item,
        view: StandardButtonView)
    
    /// The standard button view type.
    public typealias StandardButtonView = SystemKeyboardItem<ButtonContent>
    
    
    /// This typealias defines a emoji keyboard builder.
    public typealias EmojiKeyboardBuilder = (EmojiKeyboardParams) -> EmojiKeyboard
    
    /// This typealias defines emoji keyboard builder params.
    public typealias EmojiKeyboardParams = (
        style: EmojiKeyboardStyle,
        view: StandardEmojiKeyboard)
    
    /// The standard emoji keyboard view type.
    public typealias StandardEmojiKeyboard = Emoji.KeyboardWrapper
    

    /// This typealias defines a toolbar builder.
    public typealias ToolbarBuilder = (ToolbarParams) -> Toolbar

    /// This typealias defines toolbar builder params.
    public typealias ToolbarParams = (
        autocompleteAction: (Autocomplete.Suggestion) -> Void,
        style: Autocomplete.ToolbarStyle,
        view: StandardToolbarView)

    /// The standard toolbar view type.
    public typealias StandardToolbarView = Autocomplete.Toolbar<Autocomplete.ToolbarItem, Autocomplete.ToolbarSeparator>

    
    private let actionHandler: KeyboardActionHandler
    private let layout: KeyboardLayout
    private let layoutConfig: KeyboardLayout.Configuration
    private let styleProvider: KeyboardStyleProvider
    private let renderBackground: Bool
    
    private let buttonContentBuilder: ButtonContentBuilder
    private let buttonViewBuilder: ButtonViewBuilder
    private let emojiKeyboardBuilder: EmojiKeyboardBuilder
    private let toolbarBuilder: ToolbarBuilder

    public typealias AutocompleteToolbarAction = (Autocomplete.Suggestion) -> Void
    
    private var actionCalloutStyle: Callouts.ActionCalloutStyle {
        var style = styleProvider.actionCalloutStyle
        if keyboardContext.isKeyboardFloating { style.verticalOffset = 0 }
        let insets = layoutConfig.buttonInsets
        style.callout.buttonInset = CGSize(width: insets.leading, height: insets.top)
        return style
    }

    private var inputCalloutStyle: Callouts.InputCalloutStyle {
        var style = styleProvider.inputCalloutStyle
        let insets = layoutConfig.buttonInsets
        style.callout.buttonInset = CGSize(width: insets.leading, height: insets.top)
        return style
    }

    @ObservedObject
    private var autocompleteContext: AutocompleteContext

    @ObservedObject
    private var calloutContext: CalloutContext

    @ObservedObject
    private var keyboardContext: KeyboardContext

    public var body: some View {
        StandardKeyboardStyleProvider.iPadProRenderingModeActive = layout.ipadProLayout
        #if os(iOS) || os(macOS) || os(watchOS)
        let swipeEligible = (keyboardContext.deviceType == .phone || keyboardContext.isKeyboardFloating)
            && !keyboardContext.isKeyboardSplit
            && keyboardContext.keyboardType.isAlphabetic
        if SwipeTypingState.shared.isFormFactorEligible != swipeEligible {
            SwipeTypingState.shared.isFormFactorEligible = swipeEligible
        }
        #endif
        return geoContent
            .autocorrectionDisabled(with: autocompleteContext)
            .opacity(shouldShowEmojiKeyboard ? 0 : 1)
            .overlay(emojiKeyboard(), alignment: .bottom)
            .foregroundColor(styleProvider.foregroundColor)
            .background(renderBackground ? styleProvider.backgroundStyle : nil)
            .keyboardCalloutContainer(
                calloutContext: calloutContext,
                keyboardContext: keyboardContext
            )
            .actionCalloutStyle(actionCalloutStyle)
            .inputCalloutStyle(inputCalloutStyle)
    }
}

private extension SystemKeyboard {
    
    @ViewBuilder
    var keyboardChromeBackground: some View {
        if renderBackground {
            Color.clear
        }
    }
    
    var shouldShowEmojiKeyboard: Bool {
        switch keyboardContext.keyboardType {
        case .emojis: return true
        default: return false
        }
    }
}

private extension SystemKeyboard {
    
    var geoContent: some View {
        let insets = styleProvider.keyboardEdgeInsets
        let height = layout.itemRows.indices.reduce(CGFloat.zero) { $0 + rowHeight(forRowAt: $1) }
            + insets.top + insets.bottom + toolbarHeight()
        return GeometryReader { geometry in
            bodyContent(for: geometry.size)
        }
        .frame(height: height)
    }
    
    func bodyContent(for geo: GeometryProxy) -> some View {
        bodyContent(for: geo.size)
    }
    
    func bodyContent(for size: CGSize) -> some View {
        return VStack(spacing: 0) {
            toolbar()
                .frame(width: size.width)
            systemKeyboard(for: size)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipShape(RoundedRectangle(cornerRadius: keyboardContext.isKeyboardFloating ? 13 : 0, style: .continuous))
    }
    
    func toolbarHeight() -> CGFloat {
        styleProvider.autocompleteToolbarStyle.height ?? 0
    }

    func systemKeyboard(
        for size: CGSize
    ) -> some View {
        let insets = styleProvider.keyboardEdgeInsets
        let adjustedSize = CGSize(
            width: max(0, size.width - insets.leading - insets.trailing),
            height: max(0, size.height - insets.top - insets.bottom)
        )
        return VStack(spacing: 0) {
            ForEach(Array(layout.itemRows.enumerated()), id: \.offset) { row in
                let rowHeight = rowHeight(forRowAt: row.offset)
                items(
                    for: adjustedSize,
                    layout: layout,
                    itemRow: row.element,
                    rowHeight: rowHeight
                )
            }
        }
        .padding(insets)
        .environment(\.layoutDirection, .leftToRight)
        #if os(iOS) || os(macOS) || os(watchOS)
        .coordinateSpace(name: SwipeTypingState.coordinateSpaceName)
        .overlay(SwipeTrailOverlay(isDark: keyboardContext.hasDarkColorScheme))
        #endif
    }
    
    func rowHeight(forRowAt rowIndex: Int) -> CGFloat {
        if let provider = styleProvider as? StandardKeyboardStyleProvider {
            return provider.rowHeight(forRowAt: rowIndex, in: layout)
        }
        return layoutConfig.rowHeight
    }
    
    func items(
        for size: CGSize,
        layout: KeyboardLayout,
        itemRow: KeyboardLayout.ItemRow,
        rowHeight: CGFloat
    ) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(itemRow.enumerated()), id: \.offset) {
                buttonView(
                    for: $0.element,
                    totalWidth: size.width,
                    rowHeight: rowHeight
                )
            }
            .id(keyboardContext.locale.identifier)
        }
        .frame(height: rowHeight)
    }
    
    func layoutItem(
        _ item: KeyboardLayout.Item,
        rowHeight: CGFloat
    ) -> KeyboardLayout.Item {
        var item = item
        item.size = .init(width: item.size.width, height: rowHeight)
        return item
    }
}

private extension SystemKeyboard {
    
    func buttonContent(
        for item: KeyboardLayout.Item
    ) -> ButtonContent {
        buttonContentBuilder((
            item: item,
            view: Keyboard.ButtonContent(
                action: item.action,
                styleProvider: styleProvider,
                keyboardContext: keyboardContext
            )
        ))
    }
    
    func buttonView(
        for item: KeyboardLayout.Item,
        totalWidth width: CGFloat,
        rowHeight: CGFloat
    ) -> ButtonView {
        let item = layoutItem(item, rowHeight: rowHeight)
        return buttonViewBuilder((
            item: item,
            view: SystemKeyboardItem(
                item: item,
                actionHandler: actionHandler,
                styleProvider: styleProvider,
                keyboardContext: keyboardContext,
                calloutContext: calloutContext,
                keyboardWidth: width,
                inputWidth: layout.inputWidth(for: width),
                content: buttonContent(for: item)
            )
        ))
    }
    
    @ViewBuilder
    func emojiKeyboard() -> some View {
        if shouldShowEmojiKeyboard {
            emojiKeyboardBuilder((
                style: EmojiKeyboardStyle.standard(for: keyboardContext),
                view: Emoji.KeyboardWrapper(
                    actionHandler: actionHandler,
                    keyboardContext: keyboardContext,
                    calloutContext: calloutContext,
                    styleProvider: styleProvider
                )
            ))
        }
    }
    
    func toolbar() -> some View {
        toolbarBuilder((
            autocompleteAction: actionHandler.handle(_:),
            style: styleProvider.autocompleteToolbarStyle,
            view: Autocomplete.Toolbar(
                suggestions: autocompleteContext.suggestions,
                locale: keyboardContext.locale,
                style: styleProvider.autocompleteToolbarStyle,
                suggestionAction: actionHandler.handle(_:)
            )
        ))
        .frame(height: toolbarHeight())
    }
}


#if os(iOS) || os(macOS) || os(watchOS)
private struct SwipeTrailOverlay: View {
    let isDark: Bool
    @ObservedObject private var swipeState = SwipeTypingState.shared

    var body: some View {
        let points = swipeState.activeTrailPoints
        if points.count >= 2 {
            Path { path in
                path.move(to: points[0])
                for pt in points.dropFirst() {
                    path.addLine(to: pt)
                }
            }
            .stroke(
                (isDark ? Color.white : Color(white: 0.25)).opacity(0.46),
                style: StrokeStyle(lineWidth: 6.5, lineCap: .round, lineJoin: .round)
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
#endif


