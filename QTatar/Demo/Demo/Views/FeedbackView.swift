//
//  FeedbackView.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 17.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI
import StoreKit

struct FeedbackView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.requestReview) var requestReview
    
    var body: some View {
        ZStack {
            VStack {
                navBarSection
                Button {
                    withAnimation(.snappy) {
                        HapticFeedback.playSelection()
                        requestReview()
                    }
                } label: {
                    Text("Rate Us")
                }
                
                ShareLink(item: URL(string: "https://apps.apple.com/app/id\(Configurations.appID)?action=write-review")!) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
            }
        }
    }
}

private extension FeedbackView {
    var navBarSection: some View {
        HStack {
            NavButton(symbol: "chevron.backward") {
                dismiss()
            }
            Spacer()
            Text("General").titleText()
            Spacer()
            
            NavButton(symbol: "chevron.backward") {
                dismiss()
            }
        }
    }
}
