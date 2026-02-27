import SwiftUI

/// Quiet closing screen shown after the final room.
public struct EndingView: View {
    @ObservedObject private var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        let palette = viewModel.currentRoom?.basePalette

        ZStack {
            background(using: palette)

            VStack(spacing: 24) {
                Text("You make space wherever you go.")
                    .font(.system(.title2, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Tap or click to gently begin again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.8)) {
                viewModel.restartExperience()
            }
        }
        .accessibilityAddTraits(.isButton)
    }

    private func background(using palette: RoomColorPalette?) -> some View {
        let baseBackground: Color
        let accent: Color

        if let palette {
            baseBackground = palette.background
            accent = palette.accent
        } else {
            baseBackground = Color(hue: 0.08, saturation: 0.1, brightness: 0.97)
            accent = Color(hue: 0.1, saturation: 0.25, brightness: 0.85)
        }

        return LinearGradient(
            colors: [
                baseBackground,
                accent.opacity(0.4),
                baseBackground
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

