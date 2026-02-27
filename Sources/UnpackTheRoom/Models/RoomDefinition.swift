import SwiftUI

public enum LightDirection: String, CaseIterable, Sendable {
    case left
    case right
    case top
    case bottom
}

public struct RoomColorPalette: Sendable {
    public var background: Color
    public var accent: Color
    public var shadow: Color

    public init(background: Color, accent: Color, shadow: Color) {
        self.background = background
        self.accent = accent
        self.shadow = shadow
    }
}

/// High-level knobs that control how a room responds to user behavior.
public struct AdaptationProfile: Sendable {
    public var widensOnRearrange: Bool
    public var softensOnIdle: Bool
    public var forgivesImperfectPlacement: Bool
    public var rearrangeThresholds: [Int]
    public var idleSofteningThreshold: TimeInterval

    public init(
        widensOnRearrange: Bool,
        softensOnIdle: Bool,
        forgivesImperfectPlacement: Bool,
        rearrangeThresholds: [Int],
        idleSofteningThreshold: TimeInterval
    ) {
        self.widensOnRearrange = widensOnRearrange
        self.softensOnIdle = softensOnIdle
        self.forgivesImperfectPlacement = forgivesImperfectPlacement
        self.rearrangeThresholds = rearrangeThresholds
        self.idleSofteningThreshold = idleSofteningThreshold
    }
}

/// A soft constraint region within the room, expressed in normalized coordinates.
public struct RoomConstraint: Identifiable, Sendable {
    public enum Kind: Sendable {
        case tightFit
        case visuallyOff
    }

    public let id: UUID
    public var kind: Kind
    /// Normalized rect within the room canvas (0...1).
    public var rect: CGRect
    public var disfavoredKinds: [RoomObjectKind]

    public init(
        id: UUID = UUID(),
        kind: Kind,
        rect: CGRect,
        disfavoredKinds: [RoomObjectKind]
    ) {
        self.id = id
        self.kind = kind
        self.rect = rect
        self.disfavoredKinds = disfavoredKinds
    }
}

/// Static definition of a room; visual parameters that might be adapted at runtime
/// are captured separately in an adaptation state.
public struct RoomDefinition: Identifiable, Sendable {
    public let id: Int
    public var internalName: String

    /// Base padding factors to make rooms feel wider or tighter.
    public var horizontalPaddingFactor: CGFloat
    public var verticalPaddingFactor: CGFloat

    public var basePalette: RoomColorPalette
    public var lightDirection: LightDirection
    public var constraints: [RoomConstraint]
    public var adaptationProfile: AdaptationProfile

    public init(
        id: Int,
        internalName: String,
        horizontalPaddingFactor: CGFloat,
        verticalPaddingFactor: CGFloat,
        basePalette: RoomColorPalette,
        lightDirection: LightDirection,
        constraints: [RoomConstraint],
        adaptationProfile: AdaptationProfile
    ) {
        self.id = id
        self.internalName = internalName
        self.horizontalPaddingFactor = horizontalPaddingFactor
        self.verticalPaddingFactor = verticalPaddingFactor
        self.basePalette = basePalette
        self.lightDirection = lightDirection
        self.constraints = constraints
        self.adaptationProfile = adaptationProfile
    }
}

public extension Array where Element == RoomDefinition {
    static func defaultRooms() -> [RoomDefinition] {
        let neutralPalette = RoomColorPalette(
            background: Color(hue: 0.08, saturation: 0.12, brightness: 0.97),
            accent: Color(hue: 0.08, saturation: 0.25, brightness: 0.8),
            shadow: Color.black.opacity(0.2)
        )

        let coolPalette = RoomColorPalette(
            background: Color(hue: 0.60, saturation: 0.1, brightness: 0.96),
            accent: Color(hue: 0.6, saturation: 0.25, brightness: 0.8),
            shadow: Color.black.opacity(0.25)
        )

        let warmPalette = RoomColorPalette(
            background: Color(hue: 0.05, saturation: 0.25, brightness: 0.96),
            accent: Color(hue: 0.05, saturation: 0.4, brightness: 0.85),
            shadow: Color.black.opacity(0.25)
        )

        let baselineProfile = AdaptationProfile(
            widensOnRearrange: false,
            softensOnIdle: false,
            forgivesImperfectPlacement: true,
            rearrangeThresholds: [],
            idleSofteningThreshold: 0
        )

        let wideningProfile = AdaptationProfile(
            widensOnRearrange: true,
            softensOnIdle: false,
            forgivesImperfectPlacement: true,
            rearrangeThresholds: [3, 7, 12],
            idleSofteningThreshold: 0
        )

        let softeningProfile = AdaptationProfile(
            widensOnRearrange: false,
            softensOnIdle: true,
            forgivesImperfectPlacement: true,
            rearrangeThresholds: [],
            idleSofteningThreshold: 10
        )

        return [
            RoomDefinition(
                id: 0,
                internalName: "Baseline",
                horizontalPaddingFactor: 0.12,
                verticalPaddingFactor: 0.16,
                basePalette: neutralPalette,
                lightDirection: .right,
                constraints: [],
                adaptationProfile: baselineProfile
            ),
            RoomDefinition(
                id: 1,
                internalName: "Tight",
                horizontalPaddingFactor: 0.22,
                verticalPaddingFactor: 0.18,
                basePalette: coolPalette,
                lightDirection: .top,
                constraints: [
                    RoomConstraint(
                        kind: .tightFit,
                        rect: CGRect(x: 0.55, y: 0.05, width: 0.35, height: 0.18),
                        disfavoredKinds: [.chair]
                    )
                ],
                adaptationProfile: baselineProfile
            ),
            RoomDefinition(
                id: 2,
                internalName: "Expanding",
                horizontalPaddingFactor: 0.2,
                verticalPaddingFactor: 0.16,
                basePalette: neutralPalette,
                lightDirection: .left,
                constraints: [],
                adaptationProfile: wideningProfile
            ),
            RoomDefinition(
                id: 3,
                internalName: "SoftLight",
                horizontalPaddingFactor: 0.16,
                verticalPaddingFactor: 0.18,
                basePalette: warmPalette,
                lightDirection: .bottom,
                constraints: [],
                adaptationProfile: softeningProfile
            )
        ]
    }
}

