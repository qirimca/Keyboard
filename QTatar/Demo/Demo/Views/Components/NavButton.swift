//
//  NavButton.swift
//  QTatar
//
//  Created by Mustafa Bekirov on 18.01.2025.
//  Copyright © 2025 Daniel Saidi. All rights reserved.
//

import SwiftUI

struct NavButton: View {
    var symbol: String
    var action: () -> Void
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    
    private let size: CGFloat = 34
    
    private var defaultAccessibilityLabel: String {
        switch symbol {
        case "chevron.backward", "chevron.left":
            return Onboarding.onb_back_key.localized
        case "questionmark":
            return Onboarding.onb_settings_key.localized
        case "info", "info.circle":
            return About.about_title_key.localized
        default:
            return symbol
        }
    }
    
    var body: some View {
        Button {
            withAnimation {
                HapticFeedback.playSelection()
                action()
            }
        } label: {
            let buttonShape = RoundedRectangle(cornerRadius: 10, style: .continuous)
            Image(systemName: symbol)
                .font(.system(size: symbol == "questionmark" ? 15 : 14, weight: .semibold))
                .foregroundStyle(Color(.label).opacity(0.88))
                .frame(width: size, height: size)
                .background(Color(.secondarySystemGroupedBackground), in: buttonShape)
                .overlay {
                    buttonShape
                        .strokeBorder(
                            Color.primary.opacity(colorSchemeContrast == .increased ? 0.28 : 0.10),
                            lineWidth: colorSchemeContrast == .increased ? 1.5 : 1
                        )
                }
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(defaultAccessibilityLabel)
        .accessibilityIdentifier(symbol == "info" ? "ab.bento.about" : "nav.\(symbol)")
    }
}

/// Toolbar wrapper that keeps NavButton circular on iOS 26+ toolbars.
struct NavToolbarItem: ToolbarContent {
    var placement: ToolbarItemPlacement
    var symbol: String
    var action: () -> Void
    
    private var needsWindowControlsLeadingClearance: Bool {
        guard UIDevice.current.userInterfaceIdiom == .pad else { return false }
        guard symbol == "chevron.backward" || symbol == "chevron.left" else { return false }
        return HomeView.isIPadNonFullScreenWindow()
    }
    
    var body: some ToolbarContent {
        if #available(iOS 26.0, *) {
            ToolbarItem(placement: placement) {
                NavButton(symbol: symbol, action: action)
                    .padding(.leading, needsWindowControlsLeadingClearance ? 68 : 0)
            }
            .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: placement) {
                NavButton(symbol: symbol, action: action)
                    .padding(.leading, needsWindowControlsLeadingClearance ? 68 : 0)
            }
        }
    }
}

/// Re-enables `UINavigationController.interactivePopGestureRecognizer` when `.navigationBarBackButtonHidden()` is active.
struct InteractivePopGestureEnabler: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> InteractivePopSupportViewController {
        InteractivePopSupportViewController()
    }

    func updateUIViewController(_ uiViewController: InteractivePopSupportViewController, context: Context) {
        uiViewController.enableInteractivePopIfNeeded()
    }

    final class InteractivePopSupportViewController: UIViewController {
        override func didMove(toParent parent: UIViewController?) {
            super.didMove(toParent: parent)
            enableInteractivePopIfNeeded()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            enableInteractivePopIfNeeded()
        }

        func enableInteractivePopIfNeeded() {
            guard let nav = navigationController else { return }
            nav.interactivePopGestureRecognizer?.isEnabled = nav.viewControllers.count > 1
            nav.interactivePopGestureRecognizer?.delegate = nil
            if let popRecognizer = nav.interactivePopGestureRecognizer,
               let rootView = nav.topViewController?.view {
                Self.requireScrollViewsToFail(popRecognizer: popRecognizer, in: rootView)
            }
        }

        private static func requireScrollViewsToFail(popRecognizer: UIGestureRecognizer, in view: UIView) {
            if let scrollView = view as? UIScrollView {
                scrollView.panGestureRecognizer.require(toFail: popRecognizer)
            }
            for subview in view.subviews {
                requireScrollViewsToFail(popRecognizer: popRecognizer, in: subview)
            }
        }
    }
}

extension View {
    /// Enables both native `UINavigationController.interactivePopGestureRecognizer` and a dedicated leading-edge swipe-right gesture
    /// so screens with custom back buttons or horizontal `TabView` pages always exit on left-edge swipe-right.
    func enableInteractivePopAndLeftEdgeSwipe(dismiss: @escaping () -> Void) -> some View {
        self
            .background(InteractivePopGestureEnabler().frame(width: 0, height: 0))
            .overlay(alignment: .leading) {
                Color.clear
                    .frame(width: 28)
                    .frame(maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 14, coordinateSpace: .local)
                            .onEnded { value in
                                if value.translation.width > 45 && abs(value.translation.height) < 60 {
                                    HapticFeedback.playSelection()
                                    dismiss()
                                }
                            }
                    )
                    .accessibilityHidden(true)
            }
    }
}


