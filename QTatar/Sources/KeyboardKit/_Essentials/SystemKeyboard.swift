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
        style.callout.buttonInset = CGSize(width: insets.leading, height: (insets.top + insets.bottom) * 0.5)
        return style
    }

    private var inputCalloutStyle: Callouts.InputCalloutStyle {
        var style = styleProvider.inputCalloutStyle
        let insets = layoutConfig.buttonInsets
        style.callout.buttonInset = CGSize(width: insets.leading, height: (insets.top + insets.bottom) * 0.5)
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
        return geoContent
            .autocorrectionDisabled(with: autocompleteContext)
            .opacity(shouldShowEmojiKeyboard ? 0 : 1)
            .allowsHitTesting(!shouldShowEmojiKeyboard)
            .overlay(emojiKeyboard(), alignment: .bottom)
            .foregroundColor(styleProvider.foregroundColor)
            .background(renderBackground ? styleProvider.backgroundStyle : nil)
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
        let _ = (keyboardContext.oneHandedMode, keyboardContext.renderVersion)
        let insets = styleProvider.keyboardEdgeInsets
        let height = layout.itemRows.indices.reduce(CGFloat.zero) { $0 + rowHeight(forRowAt: $1) }
            + insets.top + insets.bottom + toolbarHeight()
        return GeometryReader { geometry in
            let _ = updateSwipeEligibility(for: geometry.size)
            bodyContent(for: geometry.size)
        }
        .frame(height: height)
    }

    func updateSwipeEligibility(for size: CGSize) {
        #if os(iOS) || os(macOS) || os(watchOS)
        let isCompactFloatingPad = keyboardContext.deviceType == .pad && size.width > 0 && size.width < 420
        let swipeEligible = (keyboardContext.deviceType == .phone || keyboardContext.isKeyboardFloating || isCompactFloatingPad)
            && !keyboardContext.isKeyboardSplit
            && keyboardContext.keyboardType.isAlphabetic
        if SwipeTypingState.shared.isFormFactorEligible != swipeEligible {
            SwipeTypingState.shared.isFormFactorEligible = swipeEligible
        }
        #endif
    }
    
    func bodyContent(for geo: GeometryProxy) -> some View {
        bodyContent(for: geo.size)
    }
    
    func bodyContent(for size: CGSize) -> some View {
        let mode = keyboardContext.effectiveOneHandedMode
        let isOneHanded = (mode == "left" || mode == "right") && size.width > 0
        let gridWidth = isOneHanded ? round(size.width * 0.82) : size.width
        let gutterWidth = max(0, size.width - gridWidth)
        let gridHeight = max(0, size.height - toolbarHeight())
        let gridSize = CGSize(width: gridWidth, height: size.height)
        return VStack(spacing: 0) {
            toolbar()
                .frame(width: size.width)
            HStack(spacing: 0) {
                if isOneHanded && mode == "right" {
                    oneHandedGutterButton(isLeftMode: false, width: gutterWidth, height: gridHeight)
                        .zIndex(25)
                }
                systemKeyboard(for: gridSize)
                    .frame(width: gridWidth)
                    .zIndex(10)
                if isOneHanded && mode == "left" {
                    oneHandedGutterButton(isLeftMode: true, width: gutterWidth, height: gridHeight)
                        .zIndex(25)
                }
            }
            .id(mode)
            .frame(width: size.width)
            .zIndex(10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func restoreFullWidthFromOneHanded() {
        guard keyboardContext.effectiveOneHandedMode != "off" else { return }
        #if os(iOS) || os(macOS) || os(watchOS)
        SwipeTypingState.shared.clearKeyFrames()
        #endif
        if keyboardContext.oneHandedMode != "off" {
            keyboardContext.oneHandedMode = "off"
        }
        keyboardContext.setOneHandedMode("off")
        keyboardContext.renderVersion &+= 1
        actionHandler.handle(.release, on: .custom(named: "one_handed_off"))
    }

    func oneHandedGutterButton(isLeftMode: Bool, width: CGFloat, height: CGFloat) -> some View {
        Button {
            restoreFullWidthFromOneHanded()
        } label: {
            ZStack {
                Color.white.opacity(0.015)
                Image(systemName: isLeftMode ? "chevron.right" : "chevron.left")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(keyboardContext.hasDarkColorScheme ? Color.white.opacity(0.85) : Color.black.opacity(0.65))
            }
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(width: width, height: height)
        .frame(maxHeight: .infinity)
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onEnded { value in
                    if hypot(value.translation.width, value.translation.height) < 45 {
                        restoreFullWidthFromOneHanded()
                    }
                }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isLeftMode ? "chevron.right" : "chevron.left")
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("oneHanded.restore")
    }
    
    func toolbarHeight() -> CGFloat {
        styleProvider.autocompleteToolbarStyle.height ?? 0
    }

    func systemKeyboard(
        for size: CGSize
    ) -> some View {
        let insets = styleProvider.keyboardEdgeInsets
        let availableTop = toolbarHeight()
        calloutContext.inputContext.topAvailableSpace = availableTop
        calloutContext.actionContext.topAvailableSpace = availableTop
        calloutContext.inputContext.containerWidth = size.width
        calloutContext.actionContext.containerWidth = size.width
        let adjustedSize = CGSize(
            width: max(0, size.width - insets.leading - insets.trailing),
            height: max(0, size.height - insets.top - insets.bottom)
        )
        return VStack(spacing: 0) {
            ForEach(Array(layout.itemRows.enumerated()), id: \.offset) { row in
                let rowHeight = rowHeight(forRowAt: row.offset)
                let rowY = insets.top + (0..<row.offset).reduce(CGFloat(0)) { $0 + self.rowHeight(forRowAt: $1) }
                items(
                    for: adjustedSize,
                    layout: layout,
                    itemRow: row.element,
                    rowHeight: rowHeight,
                    rowY: rowY,
                    leadingInset: insets.leading
                )
            }
        }
        .padding(insets)
        .environment(\.layoutDirection, .leftToRight)
        #if os(iOS) || os(macOS) || os(watchOS)
        .coordinateSpace(name: SwipeTypingState.coordinateSpaceName)
        .overlay(SwipeTrailOverlay(isDark: keyboardContext.hasDarkColorScheme))
        #endif
        .keyboardCalloutContainer(
            calloutContext: calloutContext,
            keyboardContext: keyboardContext
        )
    }
    
    func rowHeight(forRowAt rowIndex: Int) -> CGFloat {
        if let provider = styleProvider as? StandardKeyboardStyleProvider {
            return provider.rowHeight(forRowAt: rowIndex, in: layout)
        }
        return layoutConfig.rowHeight
    }
    
    func computeRowItemFrames(
        for itemRow: KeyboardLayout.ItemRow,
        totalWidth: CGFloat,
        inputWidth: CGFloat,
        rowY: CGFloat,
        rowHeight: CGFloat,
        leadingInset: CGFloat
    ) -> [CGRect] {
        var fixedInnerWidths: [CGFloat?] = []
        fixedInnerWidths.reserveCapacity(itemRow.count)
        var fixedAndPaddingSum: CGFloat = 0
        var flexCount = 0
        for rawItem in itemRow {
            let item = layoutItem(rawItem, rowHeight: rowHeight)
            let hInsets = item.edgeInsets.leading + item.edgeInsets.trailing
            if let w = item.width(forRowWidth: totalWidth, inputWidth: inputWidth), w > 0 {
                let cw = CGFloat(w)
                fixedInnerWidths.append(cw)
                fixedAndPaddingSum += cw + hInsets
            } else {
                fixedInnerWidths.append(nil)
                fixedAndPaddingSum += hInsets
                flexCount += 1
            }
        }
        let flexInnerWidth: CGFloat = flexCount > 0
            ? max(0, (totalWidth - fixedAndPaddingSum) / CGFloat(flexCount))
            : 0
        var currentX: CGFloat = flexCount > 0
            ? leadingInset
            : leadingInset + max(0, (totalWidth - fixedAndPaddingSum) / 2.0)
        var frames: [CGRect] = []
        frames.reserveCapacity(itemRow.count)
        for (idx, rawItem) in itemRow.enumerated() {
            let hInsets = rawItem.edgeInsets.leading + rawItem.edgeInsets.trailing
            let innerW = fixedInnerWidths[idx] ?? flexInnerWidth
            let outerW = innerW + hInsets
            frames.append(CGRect(x: currentX, y: rowY, width: outerW, height: rowHeight))
            currentX += outerW
        }
        return frames
    }
    
    func items(
        for size: CGSize,
        layout: KeyboardLayout,
        itemRow: KeyboardLayout.ItemRow,
        rowHeight: CGFloat,
        rowY: CGFloat = 0,
        leadingInset: CGFloat = 0
    ) -> some View {
        let inputWidth = layout.inputWidth(for: size.width)
        let rowFrames = computeRowItemFrames(
            for: itemRow,
            totalWidth: size.width,
            inputWidth: inputWidth,
            rowY: rowY,
            rowHeight: rowHeight,
            leadingInset: leadingInset
        )
        #if os(iOS) || os(macOS) || os(watchOS)
        if size.width > 0, SwipeTypingState.shared.isFormFactorEligible {
            for (idx, element) in itemRow.enumerated() where idx < rowFrames.count {
                if case .character(let ch) = element.action, !ch.isEmpty {
                    SwipeTypingState.shared.registerKeyFrame(character: ch, frame: rowFrames[idx])
                }
            }
        }
        #endif
        return HStack(spacing: 0) {
            ForEach(Array(itemRow.enumerated()), id: \.offset) {
                buttonView(
                    for: $0.element,
                    totalWidth: size.width,
                    rowHeight: rowHeight,
                    itemFrame: $0.offset < rowFrames.count ? rowFrames[$0.offset] : .zero
                )
            }
            .id("\(keyboardContext.locale.identifier)-\(keyboardContext.hasDarkColorScheme)-\(keyboardContext.interfaceOrientation.rawValue)-\(keyboardContext.renderVersion)")
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
        rowHeight: CGFloat,
        itemFrame: CGRect = .zero
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
                itemFrame: itemFrame,
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
    private var isHoldCalloutTest: Bool {
        CommandLine.arguments.contains("-qt_hold_callout")
            || (UserDefaults(suiteName: "group.crh.key.keyboardplus")?.bool(forKey: "crh.key.test.holdCallout") ?? false)
    }
    private var tailDuration: TimeInterval { isHoldCalloutTest ? 1.80 : 0.36 }
    private var releaseFadeDuration: TimeInterval { isHoldCalloutTest ? 1.80 : 0.15 }
    private let maxCometArcLength: CGFloat = 340.0
    private let maxHeadRadius: CGFloat = 8.25

    private struct TimedVertex {
        let point: CGPoint
        let timestamp: TimeInterval
    }

    var body: some View {
        if !swipeState.activeTrailSamples.isEmpty {
            let isFrozenDemoTrail = swipeState.activeTrailSamples.last.map {
                $0.timestamp > ProcessInfo.processInfo.systemUptime + 0.5
            } ?? false
            TimelineView(.animation(minimumInterval: nil, paused: swipeState.activeTrailSamples.isEmpty || isFrozenDemoTrail)) { timeline in
                let _ = timeline.date
                Canvas { context, _ in
                    let now = ProcessInfo.processInfo.systemUptime
                    let allSamples = swipeState.activeTrailSamples
                    guard allSamples.count >= 2, let head = allSamples.last else { return }

                    let isDemo = head.timestamp > now + 0.5
                    let releaseAnchor = swipeState.lastReleaseTimestamp > 0 ? swipeState.lastReleaseTimestamp : head.timestamp
                    let headAge = (isDemo || swipeState.isSwiping) ? 0.0 : max(0.0, now - releaseAnchor)
                    let t = min(1.0, max(0.0, headAge / releaseFadeDuration))
                    let headFade = CGFloat((1.0 - t) * (1.0 - t))
                    guard headFade > 0.01 else { return }

                    // Freeze sample clock at finger release so control points never pop/step in 18pt jumps during post-lift fade.
                    let sampleClockNow: TimeInterval = (!swipeState.isSwiping && swipeState.lastReleaseTimestamp > 0)
                        ? swipeState.lastReleaseTimestamp
                        : now

                    // 1. Extract live window with continuous tail-tip interpolation at cutoffTime = sampleClockNow - tailDuration
                    //    so the tail tip glides smoothly into the finger without discrete vertex snapping.
                    var windowedPts: [TimedVertex] = []
                    if isDemo {
                        windowedPts = allSamples.map { TimedVertex(point: $0.point, timestamp: $0.timestamp) }
                    } else {
                        let cutoffTime = sampleClockNow - tailDuration
                        if let firstLiveIdx = allSamples.firstIndex(where: { $0.timestamp >= cutoffTime }) {
                            if firstLiveIdx > 0 {
                                let prevSample = allSamples[firstLiveIdx - 1]
                                let currSample = allSamples[firstLiveIdx]
                                let dt = max(0.0001, currSample.timestamp - prevSample.timestamp)
                                let tau = CGFloat(min(1.0, max(0.0, (cutoffTime - prevSample.timestamp) / dt)))
                                let interpTail = CGPoint(
                                    x: prevSample.point.x + (currSample.point.x - prevSample.point.x) * tau,
                                    y: prevSample.point.y + (currSample.point.y - prevSample.point.y) * tau
                                )
                                windowedPts.append(TimedVertex(point: interpTail, timestamp: cutoffTime))
                            }
                            for idx in firstLiveIdx..<allSamples.count {
                                let s = allSamples[idx]
                                windowedPts.append(TimedVertex(point: s.point, timestamp: s.timestamp))
                            }
                            if swipeState.isSwiping, now - head.timestamp > 0.008 {
                                windowedPts.append(TimedVertex(point: head.point, timestamp: now))
                            }
                        }
                    }
                    guard windowedPts.count >= 2 else { return }

                    // 2. Build macro control points anchored backward from the finger head (windowedPts.last!)
                    //    so control vertices remain spatially locked on screen as the tail tip slides forward,
                    //    then apply explicit quadratic Bezier corner filleting on every turn plus Chaikin refinement.
                    var reversedCtrl: [TimedVertex] = [windowedPts.last!]
                    if windowedPts.count >= 3 {
                        for idx in stride(from: windowedPts.count - 2, through: 1, by: -1) {
                            let candidate = windowedPts[idx]
                            let prev = reversedCtrl.last!
                            if hypot(candidate.point.x - prev.point.x, candidate.point.y - prev.point.y) >= 18.0 {
                                reversedCtrl.append(candidate)
                            }
                        }
                    }
                    let tailWindowPt = windowedPts[0]
                    if hypot(tailWindowPt.point.x - reversedCtrl.last!.point.x, tailWindowPt.point.y - reversedCtrl.last!.point.y) >= 2.0 {
                        reversedCtrl.append(tailWindowPt)
                    } else if reversedCtrl.count >= 2 {
                        reversedCtrl[reversedCtrl.count - 1] = tailWindowPt
                    } else {
                        reversedCtrl.append(tailWindowPt)
                    }
                    var macroCtrl = Array(reversedCtrl.reversed())
                    guard macroCtrl.count >= 2 else { return }

                    if macroCtrl.count >= 3 {
                        var filleted: [TimedVertex] = [macroCtrl[0]]
                        for i in 1..<(macroCtrl.count - 1) {
                            let prev = macroCtrl[i - 1]
                            let curr = macroCtrl[i]
                            let next = macroCtrl[i + 1]
                            let vIn = CGPoint(x: prev.point.x - curr.point.x, y: prev.point.y - curr.point.y)
                            let vOut = CGPoint(x: next.point.x - curr.point.x, y: next.point.y - curr.point.y)
                            let lenIn = max(0.001, hypot(vIn.x, vIn.y))
                            let lenOut = max(0.001, hypot(vOut.x, vOut.y))
                            let spanIn = min(0.42 * lenIn, 32.0)
                            let spanOut = min(0.42 * lenOut, 32.0)
                            let entryPt = CGPoint(
                                x: curr.point.x + (vIn.x / lenIn) * spanIn,
                                y: curr.point.y + (vIn.y / lenIn) * spanIn
                            )
                            let exitPt = CGPoint(
                                x: curr.point.x + (vOut.x / lenOut) * spanOut,
                                y: curr.point.y + (vOut.y / lenOut) * spanOut
                            )
                            let entryTs = curr.timestamp + (prev.timestamp - curr.timestamp) * Double(spanIn / lenIn)
                            let exitTs = curr.timestamp + (next.timestamp - curr.timestamp) * Double(spanOut / lenOut)
                            let arcSteps = 6
                            for s in 0...arcSteps {
                                let t = CGFloat(s) / CGFloat(arcSteps)
                                let oneMinusT = 1.0 - t
                                let bx = oneMinusT * oneMinusT * entryPt.x + 2.0 * oneMinusT * t * curr.point.x + t * t * exitPt.x
                                let by = oneMinusT * oneMinusT * entryPt.y + 2.0 * oneMinusT * t * curr.point.y + t * t * exitPt.y
                                let bts = Double(oneMinusT) * entryTs + Double(t) * exitTs
                                filleted.append(TimedVertex(point: CGPoint(x: bx, y: by), timestamp: bts))
                            }
                        }
                        filleted.append(macroCtrl.last!)
                        macroCtrl = filleted
                    }

                    var smoothedPts = macroCtrl
                    if smoothedPts.count >= 3 {
                        for _ in 0..<2 {
                            var nextPass: [TimedVertex] = [smoothedPts[0]]
                            nextPass.reserveCapacity(smoothedPts.count * 2 + 2)
                            for i in 0..<(smoothedPts.count - 1) {
                                let p0 = smoothedPts[i]
                                let p1 = smoothedPts[i + 1]
                                let q = TimedVertex(
                                    point: CGPoint(x: 0.75 * p0.point.x + 0.25 * p1.point.x, y: 0.75 * p0.point.y + 0.25 * p1.point.y),
                                    timestamp: 0.75 * p0.timestamp + 0.25 * p1.timestamp
                                )
                                let r = TimedVertex(
                                    point: CGPoint(x: 0.25 * p0.point.x + 0.75 * p1.point.x, y: 0.25 * p0.point.y + 0.75 * p1.point.y),
                                    timestamp: 0.25 * p0.timestamp + 0.75 * p1.timestamp
                                )
                                nextPass.append(q)
                                nextPass.append(r)
                            }
                            nextPass.append(smoothedPts.last!)
                            smoothedPts = nextPass
                        }
                    }

                    // 3. Resample smoothedPts at ~6.0 pt intervals (max ~56 vertices for <0.35 ms 120 Hz rendering).
                    var rawSpine: [TimedVertex] = [smoothedPts[0]]
                    for i in 1..<smoothedPts.count {
                        let p0 = rawSpine.last!
                        let p1 = smoothedPts[i]
                        let dist = hypot(p1.point.x - p0.point.x, p1.point.y - p0.point.y)
                        let steps = max(1, min(12, Int(ceil(dist / 6.0))))
                        for s in 1...steps {
                            let t = CGFloat(s) / CGFloat(steps)
                            let pt = CGPoint(x: p0.point.x + (p1.point.x - p0.point.x) * t, y: p0.point.y + (p1.point.y - p0.point.y) * t)
                            let ts = p0.timestamp + (p1.timestamp - p0.timestamp) * Double(t)
                            if hypot(pt.x - rawSpine.last!.point.x, pt.y - rawSpine.last!.point.y) >= 3.5 || (i == smoothedPts.count - 1 && s == steps) {
                                rawSpine.append(TimedVertex(point: pt, timestamp: ts))
                            }
                        }
                    }
                    guard rawSpine.count >= 2 else { return }

                    // 4. Trim the tail to maxCometArcLength (340 pt live, or 320 pt for demo trail).
                    let effectiveMaxArcLength: CGFloat = isDemo ? 320.0 : maxCometArcLength
                    var reverseSpine: [TimedVertex] = [rawSpine.last!]
                    var accumulatedLen: CGFloat = 0
                    for idx in stride(from: rawSpine.count - 2, through: 0, by: -1) {
                        let p = rawSpine[idx]
                        let prevP = reverseSpine.last!
                        let d = hypot(prevP.point.x - p.point.x, prevP.point.y - p.point.y)
                        if accumulatedLen + d >= effectiveMaxArcLength {
                            let remain = effectiveMaxArcLength - accumulatedLen
                            if d > 0.001 {
                                let ratio = remain / d
                                let tipPt = CGPoint(
                                    x: prevP.point.x + (p.point.x - prevP.point.x) * ratio,
                                    y: prevP.point.y + (p.point.y - prevP.point.y) * ratio
                                )
                                let tipTs = prevP.timestamp + (p.timestamp - prevP.timestamp) * Double(ratio)
                                reverseSpine.append(TimedVertex(point: tipPt, timestamp: tipTs))
                            }
                            accumulatedLen = effectiveMaxArcLength
                            break
                        }
                        accumulatedLen += d
                        reverseSpine.append(p)
                    }
                    let spine = Array(reverseSpine.reversed())
                    guard spine.count >= 2, accumulatedLen > 1.0 else { return }

                    // 5. Compute cumulative arc-length progress s in [0, 1] and smooth temporal life u_i in [0, 1].
                    let count = spine.count
                    let lastIdx = count - 1
                    var arcProgress = [CGFloat](repeating: 0, count: count)
                    var combinedProgress = [CGFloat](repeating: 0, count: count)
                    var running: CGFloat = 0
                    for i in 1..<count {
                        running += hypot(spine[i].point.x - spine[i - 1].point.x, spine[i].point.y - spine[i - 1].point.y)
                        arcProgress[i] = min(1.0, running / max(1.0, accumulatedLen))
                    }

                    let headRadius = maxHeadRadius * (0.55 + 0.45 * headFade)
                    var radii = [CGFloat](repeating: 0, count: count)
                    for i in 0...lastIdx {
                        let s = arcProgress[i]
                        let p: CGFloat
                        if isDemo {
                            p = s
                        } else {
                            let age = max(0.0, sampleClockNow - spine[i].timestamp)
                            let u = min(1.0, max(0.0, 1.0 - (age / tailDuration)))
                            p = s * CGFloat(pow(u, 0.55))
                        }
                        combinedProgress[i] = p
                        radii[i] = (i == 0) ? 0.35 : max(0.35, headRadius * pow(p, 0.85))
                    }

                    // 6. Construct a 100% fold-free comet silhouette path as the non-zero winding union
                    //    of round-capped capsule segments along the spine (never pinches on 60°-180° turns).
                    var cometSilhouette = Path()
                    for i in 1...lastIdx {
                        var seg = Path()
                        seg.move(to: spine[i - 1].point)
                        seg.addLine(to: spine[i].point)
                        let r = radii[i]
                        cometSilhouette.addPath(
                            seg.strokedPath(
                                StrokeStyle(lineWidth: max(0.7, r * 2.0), lineCap: .round, lineJoin: .round)
                            )
                        )
                    }

                    let baseTone = isDark
                        ? Color(red: 0.86, green: 0.88, blue: 0.92)
                        : Color(red: 0.44, green: 0.46, blue: 0.49)
                    let maxAlpha = (isDark ? 0.50 : 0.48) * headFade

                    // 7. Render inside an isolated layer clipped to cometSilhouette using .copy blendMode
                    //    with slightly oversized round-capped strokes so opacity follows the curve seamlessly
                    //    (even on tight hairpin turns and self-crossing loops) with zero internal joint seams.
                    context.drawLayer { layerCtx in
                        layerCtx.clip(to: cometSilhouette, style: FillStyle(eoFill: false))
                        layerCtx.blendMode = .copy
                        for i in 1...lastIdx {
                            let p = combinedProgress[i]
                            let alpha = maxAlpha * (0.05 + 0.95 * pow(p, 0.72))
                            let r = radii[i]
                            var seg = Path()
                            seg.move(to: spine[i - 1].point)
                            seg.addLine(to: spine[i].point)
                            layerCtx.stroke(
                                seg,
                                with: .color(baseTone.opacity(alpha)),
                                style: StrokeStyle(lineWidth: max(2.4, r * 2.0 + 2.8), lineCap: .round, lineJoin: .round)
                            )
                        }
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
#endif


