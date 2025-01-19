//
//  BackgroundGrid.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 18.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct BackgroundGrid: View {
    var gridSize: CGFloat = 20
    var dotSize: CGFloat = 2.0
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                ForEach(0..<Int(geometry.size.height / gridSize), id: \.self) { row in
                    HStack(spacing: 0) {
                        ForEach(0..<Int(geometry.size.width / gridSize), id: \.self) { column in
                            Circle()
                                .fill(Color.gray.opacity(0.3)) // Dot color and opacity
                                .frame(width: dotSize, height: dotSize) // Dot size
                                .frame(width: gridSize, height: gridSize) // Center the dot in its grid cell
                        }
                    }
                }
            }
        }.ignoresSafeArea()
    }
}

#Preview {
    BackgroundGrid()
}
