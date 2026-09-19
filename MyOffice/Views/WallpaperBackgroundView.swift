import SwiftUI
import UIKit

/// One shared background, applied the same way behind every tab: a custom
/// photo if the user picked one, otherwise the selected free wallpaper
/// preset tinted with the current workspace theme's accent color.
struct WallpaperBackgroundView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        Group {
            if let data = app.customWallpaperData, let uiImage = UIImage(data: data) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .overlay(Color.white.opacity(0.45))
                }
            } else {
                app.wallpaper.background(accent: app.theme.accent)
            }
        }
        .ignoresSafeArea()
    }
}
