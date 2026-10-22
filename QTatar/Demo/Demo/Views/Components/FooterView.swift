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
            TaraqTamgaLogoBadge(size: 36, cornerRadius: 12)
                .saturation(0)
                .layoutPriority(0)

            Text("\(About.about_rights_key.localized) • v\(BuildInfo.fullVersion)")
                .regularText(color: Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .layoutPriority(1)
        } //: VSTACK
        .padding(.bottom, Device.iPhone ? 12 : 20)
    }
}
