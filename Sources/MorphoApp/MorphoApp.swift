import AppKit
import SwiftUI

@main
struct MorphoApp: App {
    private static let canvasDimension: CGFloat = 18.0
    private static let iconSymbolPointSize: CGFloat = 15.0
    private static let menuBarIconSymbolConfiguration = NSImage.SymbolConfiguration(
        pointSize: iconSymbolPointSize,
        weight: .medium,
        scale: .medium
    )
    private static let dotBaseDiameter: CGFloat = 7.2
    private static let dotInset: CGFloat = 0.25
    private static let dotMaskColor: NSColor = .black

    @StateObject private var model = MorphoAppModel()

    var body: some Scene {
        MenuBarExtra {
            MorphoMenuView(model: model)
                .environment(\.locale, interfaceLocale)
        } label: {
            Image(nsImage: menuBarIcon(for: model.menuBarIconRenderState))
                .accessibilityLabel("Morpho")
        }

        Settings {
            SettingsView(model: model)
                .environment(\.locale, interfaceLocale)
                .frame(width: 760, height: 560)
        }
        .windowResizability(.contentSize)
    }

    private var interfaceLocale: Locale {
        InterfaceLanguageOptions.locale(for: model.interfaceLanguageCode)
    }

    private func menuBarIcon(for state: MenuBarIconRenderState) -> NSImage {
        let canvas = NSSize(width: Self.canvasDimension, height: Self.canvasDimension)
        let image = NSImage(size: canvas, flipped: false) { rect in
            self.drawBaseIcon(state.baseSymbol, in: rect)
            if let dotScale = state.dotScale, state.dotAlpha > 0 {
                self.drawDot(scale: dotScale, alpha: state.dotAlpha, in: rect)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func drawBaseIcon(_ symbolName: String, in rect: NSRect) {
        let base = NSImage(systemSymbolName: symbolName, accessibilityDescription: "Morpho")
            ?? NSImage(systemSymbolName: "m.circle.fill", accessibilityDescription: "Morpho")
            ?? NSImage(systemSymbolName: "textformat.abc", accessibilityDescription: "Morpho")
            ?? NSImage(systemSymbolName: "globe.asia.australia.fill", accessibilityDescription: "Morpho")
            ?? NSImage()
        let configured = base.withSymbolConfiguration(Self.menuBarIconSymbolConfiguration) ?? base
        configured.isTemplate = true
        let iconSize = configured.size
        let origin = NSPoint(
            x: (rect.width - iconSize.width) / 2,
            y: (rect.height - iconSize.height) / 2
        )
        configured.draw(in: NSRect(origin: origin, size: iconSize))
    }

    private func drawDot(scale: CGFloat, alpha: CGFloat, in rect: NSRect) {
        let diameter = Self.dotBaseDiameter * scale
        let x = rect.maxX - Self.dotInset - diameter
        let y = rect.minY + Self.dotInset
        let dotRect = NSRect(x: x, y: y, width: diameter, height: diameter)
        let color = Self.dotMaskColor.withAlphaComponent(alpha)
        color.setFill()
        let path = NSBezierPath(ovalIn: dotRect)
        path.fill()
    }
}
