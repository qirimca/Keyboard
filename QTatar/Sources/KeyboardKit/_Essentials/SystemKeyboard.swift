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
        return geoContent
            .autocorrectionDisabled(with: autocompleteContext)
            .opacity(shouldShowEmojiKeyboard ? 0 : 1)
            .allowsHitTesting(!shouldShowEmojiKeyboard)
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
            .id("\(keyboardContext.locale.identifier)-\(keyboardContext.hasDarkColorScheme)")
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
    private let tailDuration: TimeInterval = 0.20
    private let maxCometArcLength: CGFloat = 175.0
    private let maxHeadRadius: CGFloat = 8.5

    var body: some View {
        if !swipeState.activeTrailSamples.isEmpty {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: swipeState.activeTrailSamples.isEmpty)) { timeline in
                let _ = timeline.date
                Canvas { context, _ in
                    let now = ProcessInfo.processInfo.systemUptime
                    let live = swipeState.activeTrailSamples.filter { now - $0.timestamp <= tailDuration }
                    guard live.count >= 2, let head = live.last else { return }

                    let headAge = max(0, now - head.timestamp)
                    let headFade = max(0, min(1, 1.0 - (headAge / tailDuration)))
                    guard headFade > 0.01 else { return }

                    // 1. Build a dense quadratic-smoothed spine from live samples.
                    var rawSpine: [CGPoint] = [live[0].point]
                    if live.count == 2 {
                        let p0 = live[0].point
                        let p1 = live[1].point
                        let dist = hypot(p1.x - p0.x, p1.y - p0.y)
                        let steps = max(1, Int(ceil(dist / 2.0)))
                        for s in 1...steps {
                            let t = CGFloat(s) / CGFloat(steps)
                            rawSpine.append(CGPoint(x: p0.x + (p1.x - p0.x) * t, y: p0.y + (p1.y - p0.y) * t))
                        }
                    } else {
                        var prev = live[0].point
                        for i in 1..<(live.count - 1) {
                            let ctrl = live[i].point
                            let next = live[i + 1].point
                            let end = CGPoint(x: (ctrl.x + next.x) * 0.5, y: (ctrl.y + next.y) * 0.5)
                            let segEst = hypot(ctrl.x - prev.x, ctrl.y - prev.y) + hypot(end.x - ctrl.x, end.y - ctrl.y)
                            let steps = max(2, min(12, Int(ceil(segEst / 2.0))))
                            for step in 1...steps {
                                let t = CGFloat(step) / CGFloat(steps)
                                let omt = 1.0 - t
                                let px = omt * omt * prev.x + 2 * omt * t * ctrl.x + t * t * end.x
                                let py = omt * omt * prev.y + 2 * omt * t * ctrl.y + t * t * end.y
                                let pt = CGPoint(x: px, y: py)
                                if hypot(pt.x - rawSpine.last!.x, pt.y - rawSpine.last!.y) >= 1.2 {
                                    rawSpine.append(pt)
                                }
                            }
                            prev = end
                        }
                        let endDist = hypot(head.point.x - prev.x, head.point.y - prev.y)
                        let endSteps = max(1, min(10, Int(ceil(endDist / 2.0))))
                        for step in 1...endSteps {
                            let t = CGFloat(step) / CGFloat(endSteps)
                            let pt = CGPoint(x: prev.x + (head.point.x - prev.x) * t, y: prev.y + (head.point.y - prev.y) * t)
                            if hypot(pt.x - rawSpine.last!.x, pt.y - rawSpine.last!.y) >= 0.8 {
                                rawSpine.append(pt)
                            }
                        }
                    }
                    guard rawSpine.count >= 2 else { return }

                    // 2. Trim the tail to maxCometArcLength so the comet never stretches into a long worm.
                    var reverseSpine: [CGPoint] = [rawSpine.last!]
                    var accumulatedLen: CGFloat = 0
                    for idx in stride(from: rawSpine.count - 2, through: 0, by: -1) {
                        let p = rawSpine[idx]
                        let prevP = reverseSpine.last!
                        let d = hypot(prevP.x - p.x, prevP.y - p.y)
                        if accumulatedLen + d >= maxCometArcLength {
                            let remain = maxCometArcLength - accumulatedLen
                            if d > 0.001 {
                                let ratio = remain / d
                                let tip = CGPoint(x: prevP.x + (p.x - prevP.x) * ratio, y: prevP.y + (p.y - prevP.y) * ratio)
                                reverseSpine.append(tip)
                            }
                            accumulatedLen = maxCometArcLength
                            break
                        }
                        accumulatedLen += d
                        reverseSpine.append(p)
                    }
                    let spine = Array(reverseSpine.reversed())
                    guard spine.count >= 2, accumulatedLen > 1.0 else { return }

                    // 3. Compute cumulative arc-length progress s in [0, 1] and comet normal offsets.
                    let count = spine.count
                    var arcProgress = [CGFloat](repeating: 0, count: count)
                    var running: CGFloat = 0
                    for i in 1..<count {
                        running += hypot(spine[i].x - spine[i - 1].x, spine[i].y - spine[i - 1].y)
                        arcProgress[i] = min(1.0, running / max(1.0, accumulatedLen))
                    }

                    let headRadius = maxHeadRadius * (0.45 + 0.55 * headFade)
                    var leftSide = [CGPoint](repeating: spine[0], count: count)
                    var rightSide = [CGPoint](repeating: spine[0], count: count)
                    var radii = [CGFloat](repeating: 0, count: count)

                    let lastIdx = count - 1
                    for i in 0...lastIdx {
                        let s = arcProgress[i]
                        // Razor-sharp 0.0 pt tail tip flaring with pow(s, 1.45) into a 17 pt rounded comet head.
                        let r = (i == 0) ? 0.0 : (headRadius * pow(s, 1.45))
                        radii[i] = r
                        let pPrev = spine[max(0, i - 1)]
                        let pNext = spine[min(lastIdx, i + 1)]
                        let dx = pNext.x - pPrev.x
                        let dy = pNext.y - pPrev.y
                        let len = max(0.001, hypot(dx, dy))
                        let nx = -dy / len
                        let ny = dx / len
                        let p = spine[i]
                        leftSide[i] = CGPoint(x: p.x + nx * r, y: p.y + ny * r)
                        rightSide[i] = CGPoint(x: p.x - nx * r, y: p.y - ny * r)
                    }

                    // 4. Construct a single unified comet silhouette path (0 pt tip -> flared body -> forward semicircular head).
                    var cometPath = Path()
                    cometPath.move(to: spine[0])
                    for i in 1...lastIdx {
                        cometPath.addLine(to: leftSide[i])
                    }
                    let headPt = spine[lastIdx]
                    let prevPt = spine[max(0, lastIdx - 1)]
                    let hdx = headPt.x - prevPt.x
                    let hdy = headPt.y - prevPt.y
                    let hLen = max(0.001, hypot(hdx, hdy))
                    let htx = hdx / hLen
                    let hty = hdy / hLen
                    let hnx = -hty
                    let hny = htx
                    let capSteps = 16
                    for step in 1...capSteps {
                        let phi = (.pi / 2.0) - (.pi * CGFloat(step) / CGFloat(capSteps))
                        let c = cos(phi)
                        let s = sin(phi)
                        let px = headPt.x + headRadius * (c * htx + s * hnx)
                        let py = headPt.y + headRadius * (c * hty + s * hny)
                        cometPath.addLine(to: CGPoint(x: px, y: py))
                    }
                    for i in stride(from: lastIdx, through: 1, by: -1) {
                        cometPath.addLine(to: rightSide[i])
                    }
                    cometPath.closeSubpath()

                    let baseTone = isDark
                        ? Color(red: 0.86, green: 0.88, blue: 0.92)
                        : Color(red: 0.44, green: 0.46, blue: 0.49)
                    let maxAlpha = (isDark ? 0.48 : 0.46) * headFade

                    // 5. Render inside an isolated layer clipped to cometPath using .copy blendMode so
                    //    opacity follows the curve (even on loops) with zero internal rings or joint seams.
                    context.drawLayer { layerCtx in
                        layerCtx.clip(to: cometPath)
                        layerCtx.blendMode = .copy
                        for i in 1...lastIdx {
                            let s = arcProgress[i]
                            let alpha = maxAlpha * (0.04 + 0.96 * pow(s, 1.30))
                            let p0 = spine[i - 1]
                            let p1 = spine[i]
                            let dx = p1.x - p0.x
                            let dy = p1.y - p0.y
                            let segLen = max(0.001, hypot(dx, dy))
                            let tx = (dx / segLen) * 0.9
                            let ty = (dy / segLen) * 0.9

                            var quad = Path()
                            quad.move(to: CGPoint(x: leftSide[i - 1].x - tx, y: leftSide[i - 1].y - ty))
                            quad.addLine(to: CGPoint(x: leftSide[i].x + tx, y: leftSide[i].y + ty))
                            quad.addLine(to: CGPoint(x: rightSide[i].x + tx, y: rightSide[i].y + ty))
                            quad.addLine(to: CGPoint(x: rightSide[i - 1].x - tx, y: rightSide[i - 1].y - ty))
                            quad.closeSubpath()
                            layerCtx.fill(quad, with: .color(baseTone.opacity(alpha)))
                        }
                        let capR = headRadius + 0.5
                        let backOverlap: CGFloat = 0.6
                        var headCap = Path()
                        headCap.move(to: CGPoint(
                            x: headPt.x - htx * backOverlap + hnx * capR,
                            y: headPt.y - hty * backOverlap + hny * capR
                        ))
                        for step in 0...capSteps {
                            let phi = (.pi / 2.0) - (.pi * CGFloat(step) / CGFloat(capSteps))
                            let c = cos(phi)
                            let s = sin(phi)
                            let px = headPt.x + capR * (c * htx + s * hnx)
                            let py = headPt.y + capR * (c * hty + s * hny)
                            headCap.addLine(to: CGPoint(x: px, y: py))
                        }
                        headCap.addLine(to: CGPoint(
                            x: headPt.x - htx * backOverlap - hnx * capR,
                            y: headPt.y - hty * backOverlap - hny * capR
                        ))
                        headCap.closeSubpath()
                        layerCtx.fill(headCap, with: .color(baseTone.opacity(maxAlpha)))
                    }
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
#endif


