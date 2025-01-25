//
//  Text+Extension.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

typealias TextFonts = Text

extension TextFonts {
    
    func titleText(size: CGFloat = 18) -> some View {
        return self
            .font(.custom("GeneralSans-Semibold", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(.black)
    }
    
    func mediumText(size: CGFloat = 16, color: Color = .black) -> some View {
        return self
            .font(.custom("GeneralSans-Medium", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(color)
    }
    
    func regularText(size: CGFloat = 12, color: Color = .black) -> some View {
        return self
            .font(.custom("GeneralSans-Regular", size: Device.iPad ? size + 4 : size))
            .foregroundStyle(color)
    }
}
