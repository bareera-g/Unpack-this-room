import SwiftUI

public enum RoomObjectKind: String, CaseIterable, Identifiable, Sendable {
    case lamp
    case chair
    case plant
    case photoFrame
    case mug
    case laptopOrBook

    public var id: String { rawValue }
}

/// A single symbolic object that can be placed within a room.
public struct RoomObject: Identifiable, Equatable, Sendable {
    public struct NormalizedPosition: Equatable, Sendable {
        /// X and Y are expected to be in the 0...1 range within the room canvas.
        public var x: CGFloat
        public var y: CGFloat

        public init(x: CGFloat, y: CGFloat) {
            self.x = x
            self.y = y
        }

        public static let tray = NormalizedPosition(x: 0.5, y: 1.05)
    }

    public let id: UUID
    public var kind: RoomObjectKind
    public var position: NormalizedPosition
    public var isPlaced: Bool
    public var scale: CGFloat
    public var rotationDegrees: Double
    public var zIndex: Double

    public init(
        id: UUID = UUID(),
        kind: RoomObjectKind,
        position: NormalizedPosition = .tray,
        isPlaced: Bool = false,
        scale: CGFloat = 1.0,
        rotationDegrees: Double = 0,
        zIndex: Double = 0
    ) {
        self.id = id
        self.kind = kind
        self.position = position
        self.isPlaced = isPlaced
        self.scale = scale
        self.rotationDegrees = rotationDegrees
        self.zIndex = zIndex
    }
}

public extension Array where Element == RoomObject {
    static func defaultObjects() -> [RoomObject] {
        RoomObjectKind.allCases.enumerated().map { index, kind in
            RoomObject(
                kind: kind,
                position: .tray,
                isPlaced: false,
                scale: 1.0,
                rotationDegrees: 0,
                zIndex: Double(index)
            )
        }
    }
}

