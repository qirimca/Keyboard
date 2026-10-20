//
//  FooterView.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 19.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct FooterView: View {

    var body: some View {
        VStack(alignment: .center, spacing: 10) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.75)
                }
                .layoutPriority(0)

            Text("\(About.about_rights_key.localized) • v\(BuildInfo.fullVersion)")
                .regularText(color: Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .layoutPriority(1)
        } //: VSTACK
        .padding(.bottom, Device.iPhone ? 12 : 20)
    }
}
