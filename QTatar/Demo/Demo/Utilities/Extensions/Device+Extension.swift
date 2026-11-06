//
//  Device+Extension.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import UIKit

enum Device {
    static var iPhone: Bool {
        return UIDevice.current.userInterfaceIdiom == .phone
    }
    
    static var iPad: Bool {
        let idiom = UIDevice.current.userInterfaceIdiom
        if #available(iOS 17.0, *) {
            return idiom == .pad || idiom == .vision
        }
        return idiom == .pad
    }
}
