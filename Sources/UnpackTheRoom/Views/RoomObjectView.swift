import SwiftUI

/// Visual representation of a single symbolic object within a room.
///
/// This view focuses purely on appearance and micro-animations; gesture
/// handling and positioning are driven by `RoomView`.
public struct RoomObjectView: View {
    public let object: RoomObject
    public let palette: RoomColorPalette
    public let shadowStrength: CGFloat
    public let lightDirection: LightDirection
    public let isBeingDragged: Bool

    public init(
        object: RoomObject,
        palette: RoomColorPalette,
        shadowStrength: CGFloat,
        lightDirection: LightDirection,
        isBeingDragged: Bool
    ) {
        self.object = object
        self.palette = palette
        self.shadowStrength = shadowStrength
        self.lightDirection = lightDirection
        self.isBeingDragged = isBeingDragged
    }

    public var body: some View {
        shape
            .scaleEffect(isBeingDragged ? 1.06 : object.scale)
            .rotationEffect(Angle.degrees(object.rotationDegrees))
            .shadow(
                color: palette.shadow.opacity(Double(0.4 * shadowStrength)),
                radius: isBeingDragged ? 18 : 12,
                x: shadowOffset.width,
                y: shadowOffset.height
            )
            .animation(Animation.easeOut(duration: 0.25), value: isBeingDragged)
            .accessibilityLabel(Text(accessibilityLabel))
    }

    private var accessibilityLabel: String {
        switch object.kind {
        case .lamp: return "Lamp"
        case .chair: return "Chair"
        case .plant: return "Plant"
        case .photoFrame: return "Photo frame"
        case .mug: return "Mug"
        case .laptopOrBook: return "Laptop or book"
        }
    }

    private var shadowOffset: CGSize {
        switch lightDirection {
        case .left:
            return CGSize(width: 10, height: 12)
        case .right:
            return CGSize(width: -10, height: 12)
        case .top:
            return CGSize(width: 0, height: 14)
        case .bottom:
            return CGSize(width: 0, height: -6)
        }
    }

    @ViewBuilder
    private var shape: some View {
        switch object.kind {
        case .lamp:
            VStack(spacing: 4) {
                Capsule(style: .continuous)
                    .frame(width: 44, height: 18)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .frame(width: 10, height: 26)
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .frame(width: 34, height: 6)
            }
            .foregroundStyle(palette.accent)
        case .chair:
            VStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .frame(width: 40, height: 20)
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .frame(width: 6, height: 18)
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .frame(width: 6, height: 18)
                }
            }
            .foregroundStyle(palette.accent)
        case .plant:
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .frame(width: 26, height: 20)
                VStack(spacing: -4) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule(style: .continuous)
                            .frame(width: CGFloat(28 + index * 6), height: 12)
                    }
                }
                .offset(y: -18)
            }
            .foregroundStyle(palette.accent)
        case .photoFrame:
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .frame(width: 46, height: 34)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .inset(by: 4)
                        .stroke(palette.background.opacity(0.6), lineWidth: 2)
                )
        case .mug:
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .frame(width: 30, height: 26)
                Capsule(style: .continuous)
                    .frame(width: 14, height: 18)
                    .offset(x: 18)
            }
            .foregroundStyle(palette.accent)
        case .laptopOrBook:
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .frame(width: 52, height: 6)
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .frame(width: 52, height: 26)
            }
            .foregroundStyle(palette.accent)
        }
    }
}

