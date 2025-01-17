//
//  FeedbackView.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI
import StoreKit

@available(iOS 16.0, *)
struct FeedbackView: View {
    @Environment(\.requestReview) var requestReview
    
    var body: some View {
        VStack {
            Button {
                requestReview()
            } label: {
                Text("Rate Us")
            }
            ShareLink(item: URL(string: "https://apps.apple.com/app/id6739430313?action=write-review")!) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        }
    }
}
