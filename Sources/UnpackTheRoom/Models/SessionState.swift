import Foundation

public enum ExperiencePhase: Equatable, Sendable {
    case inRoom(index: Int)
    case ending
}

/// Stateless snapshot of where we are in the experience.
public struct SessionState: Sendable {
    public var rooms: [RoomDefinition]
    public var currentRoomIndex: Int
    public var phase: ExperiencePhase

    public init(
        rooms: [RoomDefinition],
        currentRoomIndex: Int = 0,
        phase: ExperiencePhase = .inRoom(index: 0)
    ) {
        self.rooms = rooms
        self.currentRoomIndex = currentRoomIndex
        self.phase = phase
    }

    public var currentRoom: RoomDefinition? {
        guard rooms.indices.contains(currentRoomIndex) else { return nil }
        return rooms[currentRoomIndex]
    }

    public var isLastRoom: Bool {
        currentRoomIndex >= rooms.count - 1
    }
}

