//
//  DemoLayoutProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2022-12-21.
//  Copyright © 2022-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import UIKit

/**
 This demo-specific provider inherits the standard one, then
 adds a rocket and a locale key around the space key.
 */
class DemoLayoutProvider: StandardKeyboardLayoutProvider {

    override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        let layout = super.keyboardLayout(for: context)
        layout.tryInsertRocketButton()
        layout.tryInsertLocaleSwitcher(for: context)
        layout.useNativeReturnKey()
        layout.applyNativeRowInsets()
        
        return layout
    }
}

private extension KeyboardLayout {
    
    func tryInsertLocaleSwitcher(for context: KeyboardContext) {
        guard context.hasMultipleLocales else { return }
        guard let button = tryCreateBottomRowItem(for:  .nextLocale) else { return }
        itemRows.insert(button, after: .space, atRow: bottomRowIndex)
    }
    
    func useNativeReturnKey() {
        let rowIndex = bottomRowIndex
        guard rowIndex >= 0, rowIndex < itemRows.count else { return }
        let row = itemRows[rowIndex]
        for (index, item) in row.enumerated() {
            guard case .primary = item.action else { continue }
            itemRows[rowIndex][index] = .init(
                action: .primary(.newLine),
                size: item.size,
                alignment: item.alignment,
                edgeInsets: item.edgeInsets
            )
        }
    }
    
    func applyNativeRowInsets() {
        let bottomIndex = bottomRowIndex
        guard bottomIndex >= 0 else { return }
        
        for rowIndex in itemRows.indices {
            let vertical: CGFloat = rowIndex == bottomIndex ? 4 : 6
            for index in itemRows[rowIndex].indices {
                var item = itemRows[rowIndex][index]
                guard !item.action.isSpacer else { continue }
                item.edgeInsets = .init(
                    top: vertical,
                    leading: 3,
                    bottom: vertical,
                    trailing: 3
                )
                itemRows[rowIndex][index] = item
            }
        }
    }
    
    func tryInsertRocketButton() {
//        if UIDevice().userInterfaceIdiom == .phone {
//            guard var button = tryCreateBottomRowItem(for: .character("-")) else { return }
//            if var space = itemRows.last?.first(where: { $0.action == .space }) {
//                space.size.width = .percentage(0.3)
//            }
//            itemRows[3][0].size.width = .percentage(0.2)
//            button.size.width = .percentage(0.1)
//            itemRows.insert(button, before: .space, atRow: bottomRowIndex)
//        }
    }
}
