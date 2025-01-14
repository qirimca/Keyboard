//
//  DemoCalloutActionProvider.swift
//  Keyboard
//
//  Created by Daniel Saidi on 2021-02-11.
//  Copyright © 2021-2024 Daniel Saidi. All rights reserved.
//

import KeyboardKit
import UIKit

/**
 This demo-specific callout action provider adds a couple of
 dummy callouts when typing.
 */
class DemoCalloutActionProvider: BaseCalloutActionProvider {
    
    override func calloutActionString(for char: String) -> String {
        switch char {
        case "ь": "ъь"
        case "Ь": "ЪЬ"
        case "е": "ёе"
        case "Е": "ЁЕ"
        case "о": "өо"
        case "н": "ңн"
        case "у": "үу"
        case "О": "ӨО"
        case "Н": "ҢН"
        case "У": "ҮҮ"
        case "ж": "җЖ"
        case "Ж": "ҖЖ"
        case "э": "әэ"
        case "Э": "ӘЭ"
        default: super.calloutActionString(for: char)
        }
    }
}
