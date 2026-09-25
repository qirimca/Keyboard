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
        Canvas { context, size in
            let dotRadius = dotSize / 2
            let dotColor = Color.gray.opacity(0.3)
            let columns = Int(size.width / gridSize)
            let rows = Int(size.height / gridSize)
            for row in 0..<rows {
                let y = CGFloat(row) * gridSize + gridSize / 2
                for col in 0..<columns {
                    let x = CGFloat(col) * gridSize + gridSize / 2
                    let rect = CGRect(x: x - dotRadius, y: y - dotRadius, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(dotColor))
                }
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    BackgroundGrid()
}
