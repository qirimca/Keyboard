//
//  Keyboard+RootView.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2022-02-04.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import SwiftUI

extension Keyboard {
    
    /// This view is used as a wrapper view, to make sure it
    /// binds to state that affects your layout.
    struct RootView<ViewType: View>: View {
        
        init(@ViewBuilder _ view: @escaping () -> ViewType) {
            self.view = view
        }
        
        var view: () -> ViewType
        
        @EnvironmentObject
        private var autocompleteContext: AutocompleteContext
        
        @EnvironmentObject
        private var calloutContext: CalloutContext
        
        @EnvironmentObject
        private var keyboardContext: KeyboardContext
        
        var body: some View {
            let _ = (
                keyboardContext.renderVersion,
                keyboardContext.oneHandedMode,
                keyboardContext.locale.identifier,
                keyboardContext.keyboardType,
                keyboardContext.isKeyboardFloating,
                keyboardContext.isKeyboardSplit,
                keyboardContext.traitCollection.userInterfaceStyle,
                keyboardContext.interfaceOrientation
            )
            if keyboardContext.isKeyboardFloating {
                view()
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                view()
            }
        }
    }
}
