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
    
    init() {
        let baseProvider = InputSetBasedKeyboardLayoutProvider()
        baseProvider.iPadProvider = CrimeanTatarIPadKeyboardLayoutProvider(
            alphabeticInputSet: baseProvider.alphabeticInputSet,
            numericInputSet: baseProvider.numericInputSet,
            symbolicInputSet: baseProvider.symbolicInputSet
        )
        super.init(baseProvider: baseProvider)
    }

    override func keyboardLayout(for context: KeyboardContext) -> KeyboardLayout {
        let layout = super.keyboardLayout(for: context)
        layout.tryInsertRocketButton()
        layout.tryInsertLocaleSwitcher(for: context)
        layout.useNativeReturnKey()
        layout.applyNativeRowInsets(for: context)
        layout.applyIPadTrailingGutter(for: context)
        
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
    
    func applyNativeRowInsets(for context: KeyboardContext) {
        let bottomIndex = bottomRowIndex
        guard bottomIndex >= 0 else { return }
        
        let isPhone = context.deviceType == .phone
        let padConfig = KeyboardLayout.Configuration.standard(for: context)
        let horizontal = isPhone ? CGFloat(3) : padConfig.buttonInsets.leading
        let letterVertical = isPhone ? CGFloat(3) : padConfig.buttonInsets.top
        let bottomVertical = isPhone ? CGFloat(2) : padConfig.buttonInsets.top
        
        for rowIndex in itemRows.indices {
            let vertical = rowIndex == bottomIndex ? bottomVertical : letterVertical
            let lastIndex = itemRows[rowIndex].count - 1
            
            for index in itemRows[rowIndex].indices {
                var item = itemRows[rowIndex][index]
                guard !item.action.isSpacer else { continue }
                
                let isFirst = index == 0
                let isLast = index == lastIndex
                let outerHorizontal = isPhone ? horizontal : horizontal * 1.5
                
                item.edgeInsets = .init(
                    top: vertical,
                    leading: isFirst ? outerHorizontal : horizontal,
                    bottom: vertical,
                    trailing: isLast ? outerHorizontal : horizontal
                )
                itemRows[rowIndex][index] = item
            }
        }
    }
    
    /// Adds a fixed trailing gutter on iPad letter rows.
    func applyIPadTrailingGutter(for context: KeyboardContext) {
        guard context.deviceType == .pad else { return }
        
        let gutter = KeyboardLayout.Item(
            action: .none,
            size: .init(
                width: .inputPercentage(0.45),
                height: idealItemHeight
            ),
            edgeInsets: .init()
        )
        
        for rowIndex in 0..<bottomRowIndex {
            itemRows[rowIndex].append(gutter)
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
