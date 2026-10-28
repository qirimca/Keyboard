//
//  Keyboard+NextKeyboardButton.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2020-03-11.
//  Copyright © 2020-2024 Daniel Saidi. All rights reserved.
//

#if os(iOS) || os(tvOS) || os(visionOS)
import SwiftUI
import UIKit

public extension Keyboard {
    
    /**
     This view makes a view behave as a next keyboard button.
     
     The native iOS next keyboard button switches the to the
     next keyboard on tap and opens a switcher menu on press.
     This button applies the same behavior to a content view.
     
     Note that you must provide a `UIInputViewController` in
     the initializer, or set ``NextKeyboardController/shared``
     before you use the view.
     
     This is automatically done by KeyboardKit, so you don't
     have to think about it when using this SDK.
     */
    struct NextKeyboardButton<Content: View>: View {
        
        public init(
            controller: UIInputViewController? = nil,
            throwAssertionForMissingController: Bool = false,
            @ViewBuilder content: @escaping () -> Content
        ) {
            self.overlay = NextKeyboardButtonOverlay(
                controller: controller ?? Keyboard.NextKeyboardController.shared,
                throwAssertionForMissingController: throwAssertionForMissingController
            )
            self.content = content
            self.throwAssertionForMissingController = throwAssertionForMissingController
        }
        
        private let content: () -> Content
        private let overlay: NextKeyboardButtonOverlay
        private let throwAssertionForMissingController: Bool
        
        public var body: some View {
            content().overlay(overlay)
        }
    }
}

#Preview {

    Keyboard.NextKeyboardButton {
        Image.keyboardGlobe.font(.title)
    }
}

/// This overlay sets up a `next keyboard` controller action
/// on a blank `UIKit` button. This can hopefully be removed
/// later, without public changes.
private struct NextKeyboardButtonOverlay: UIViewRepresentable {

    init(
        controller: UIInputViewController?,
        throwAssertionForMissingController: Bool
    ) {
        self.controller = controller
        if controller == nil && throwAssertionForMissingController && !ProcessInfo.isSwiftUIPreview { assertionFailure("Input view controller is nil") }
    }

    weak var controller: UIInputViewController?

    func makeUIView(context: Context) -> UIButton {
        let button = UIButton()
        (controller ?? Keyboard.NextKeyboardController.shared)?.setupNextKeyboardButton(button)
        return button
    }

    func updateUIView(_ uiView: UIButton, context: Context) {
        (controller ?? Keyboard.NextKeyboardController.shared)?.setupNextKeyboardButton(uiView)
    }
}

private extension UIInputViewController {

    func setupNextKeyboardButton(_ button: UIButton) {
        let action = #selector(handleInputModeList(from:with:))
        button.removeTarget(nil, action: action, for: .allTouchEvents)
        button.addTarget(self, action: action, for: .allTouchEvents)
    }
}

private extension ProcessInfo {

    var isSwiftUIPreview: Bool {
        environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    static var isSwiftUIPreview: Bool {
        processInfo.isSwiftUIPreview
    }
}
#endif
