import SwiftUI
import UIKit

/// Shared circular avatar used everywhere a person's photo can appear. Falls
/// back to a neutral gray silhouette placeholder — not colored initials —
/// when no photo has been set yet, matching a typical "empty contact photo".
struct AvatarView: View {
    let photoData: Data?
    var diameter: CGFloat = 38
    var ringColor: Color? = nil

    var body: some View {
        ZStack {
            if let photoData, let uiImage = UIImage(data: photoData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
            } else {
                Circle().fill(Color(white: 0.6))
                Image(systemName: "person.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(white: 0.88))
                    .padding(diameter * 0.22)
            }
        }
        .frame(width: diameter, height: diameter)
        .clipShape(Circle())
        .overlay(
            Circle().stroke(ringColor ?? Color.black.opacity(0.1), lineWidth: ringColor != nil ? 2 : 1)
        )
    }
}
