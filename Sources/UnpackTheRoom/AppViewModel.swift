import SwiftUI
import Combine

/// Central observable state for the Unpack the Room experience.
///
/// Owns the current session, per-room objects, behavior metrics, and adaptation
/// parameters that drive how the room responds visually.
public final class AppViewModel: ObservableObject {
    // MARK: - Published state

    @Published public private(set) var session: SessionState
    @Published public var objects: [RoomObject]
    @Published public private(set) var behaviorMetrics: BehaviorMetrics

    /// Horizontal widening factor for the current room.
    /// 1.0 is the baseline; values > 1.0 gently widen the space.
    @Published public private(set) var widthScale: CGFloat

    /// 0...1 progress that controls how soft the lighting and contrasts feel
    /// based on idle behavior.
    @Published public private(set) var idleSofteningProgress: CGFloat

    /// Multiplier applied to the room's base shadow strength.
    /// 1.0 = base shadow, lower values = softer, lighter shadows.
    @Published public private(set) var shadowStrength: CGFloat

    // MARK: - Private state

    /// Stable set of objects shared across rooms. We reset their positions
    /// when entering a new room but keep identities so the objects feel
    /// familiar as the environment changes.
    private var baseObjects: [RoomObject]

    private var idleTimer: Timer?

    // MARK: - Init

    public init(
        rooms: [RoomDefinition] = .defaultRooms(),
        initialObjects: [RoomObject]? = nil
    ) {
        let session = SessionState(rooms: rooms)
        self.session = session

        let objects = initialObjects ?? .defaultObjects()
        self.baseObjects = objects
        self.objects = objects

        self.behaviorMetrics = BehaviorMetrics()
        self.widthScale = 1.0
        self.idleSofteningProgress = 0
        self.shadowStrength = 1.0

        startIdleTimer()
        applyAdaptation()
    }

    deinit {
        idleTimer?.invalidate()
    }

    // MARK: - Derived accessors

    public var currentRoom: RoomDefinition? {
        session.currentRoom
    }

    // MARK: - Interaction entry points

    /// Call while an object is being dragged or interacted with to reset idle
    /// timers and gently record that the object was touched.
    public func registerInteraction(for objectID: UUID) {
        behaviorMetrics.idleDuration = 0
        behaviorMetrics.objectsTouched.insert(objectID)
        applyAdaptation()
    }

    /// Call when a drag gesture finishes and an object is placed at a final
    /// normalized position.
    public func placeObject(
        id: UUID,
        at normalizedPosition: RoomObject.NormalizedPosition,
        isImperfect: Bool
    ) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }

        var object = objects[index]
        let wasPlacedBefore = object.isPlaced

        object.position = normalizedPosition
        object.isPlaced = true
        object.zIndex = (objects.map(\.zIndex).max() ?? 0) + 1

        objects[index] = object

        behaviorMetrics.placementAttempts += 1
        behaviorMetrics.objectsTouched.insert(id)
        behaviorMetrics.idleDuration = 0

        if wasPlacedBefore {
            behaviorMetrics.rearrangementCount += 1
        }

        if isImperfect {
            behaviorMetrics.hasLeftImperfect = true
        }

        applyAdaptation()
        maybeAdvanceRoomIfNeeded()
    }

    /// Convenience helper for converting a free-form normalized position into
    /// a lightly clamped one so objects cannot escape too far from the room,
    /// while allowing a little bit of overlap and edge flirting.
    public func clampedPosition(_ position: RoomObject.NormalizedPosition) -> RoomObject.NormalizedPosition {
        RoomObject.NormalizedPosition(
            x: max(-0.05, min(1.05, position.x)),
            y: max(-0.05, min(1.10, position.y))
        )
    }

    /// Heuristic to decide whether a placement is "imperfect" in a forgiving
    /// sense: near edges or in a disfavored constraint region.
    public func isImperfectPlacement(for object: RoomObject, at position: RoomObject.NormalizedPosition) -> Bool {
        guard let room = currentRoom else { return false }

        let nearEdge = position.x < 0.08 || position.x > 0.92 ||
            position.y < 0.08 || position.y > 0.92

        let point = CGPoint(x: position.x, y: position.y)

        let inDisfavoredRegion = room.constraints.contains { constraint in
            constraint.rect.contains(point) && constraint.disfavoredKinds.contains(object.kind)
        }

        return nearEdge || inDisfavoredRegion
    }

    /// Unpacks an object from the tray into the room at a gentle spawn position.
    public func unpackFromTray(id: UUID) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }

        var object = objects[index]
        guard !object.isPlaced else { return }

        let spawnPosition = clampedPosition(
            RoomObject.NormalizedPosition(x: 0.5, y: 0.9)
        )

        object.position = spawnPosition
        object.isPlaced = true
        object.zIndex = (objects.map(\.zIndex).max() ?? 0) + 1

        objects[index] = object

        behaviorMetrics.placementAttempts += 1
        behaviorMetrics.objectsTouched.insert(id)
        behaviorMetrics.idleDuration = 0

        applyAdaptation()
        maybeAdvanceRoomIfNeeded()
    }

    // MARK: - Session control

    public func restartExperience() {
        session = SessionState(
            rooms: session.rooms,
            currentRoomIndex: 0,
            phase: .inRoom(index: 0)
        )
        behaviorMetrics = BehaviorMetrics()
        resetObjectsForCurrentRoom()
        widthScale = 1.0
        idleSofteningProgress = 0
        shadowStrength = 1.0
    }

    // MARK: - Progression

    private func maybeAdvanceRoomIfNeeded() {
        guard case .inRoom = session.phase else { return }

        let placedCount = objects.filter(\.isPlaced).count
        let mostObjectsPlaced = placedCount >= max(3, objects.count - 1)
        let enoughIdle = behaviorMetrics.idleDuration >= 8
        let allTouched = behaviorMetrics.objectsTouchedCount == objects.count

        if session.isLastRoom {
            if mostObjectsPlaced && (enoughIdle || allTouched || behaviorMetrics.hasLeftImperfect) {
                withAnimation(.easeInOut(duration: 1.0)) {
                    session.phase = .ending
                }
            }
        } else {
            if mostObjectsPlaced && (enoughIdle || allTouched || behaviorMetrics.rearrangementCount >= 2) {
                advanceToNextRoom()
            }
        }
    }

    public func advanceToNextRoom() {
        guard !session.isLastRoom else {
            withAnimation(.easeInOut(duration: 1.0)) {
                session.phase = .ending
            }
            return
        }

        let nextIndex = session.currentRoomIndex + 1

        withAnimation(.easeInOut(duration: 0.8)) {
            session.currentRoomIndex = nextIndex
            session.phase = .inRoom(index: nextIndex)
        }

        behaviorMetrics = BehaviorMetrics()
        resetObjectsForCurrentRoom()
        applyAdaptation()
    }

    private func resetObjectsForCurrentRoom() {
        baseObjects = baseObjects.map { base in
            var copy = base
            copy.position = .tray
            copy.isPlaced = false
            copy.scale = 1.0
            copy.rotationDegrees = 0
            return copy
        }
        objects = baseObjects
    }

    // MARK: - Adaptation & idle handling

    private func startIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.handleIdleTick()
        }
    }

    private func handleIdleTick() {
        guard case .inRoom = session.phase else { return }

        DispatchQueue.main.async {
            self.behaviorMetrics.idleDuration += 1
            self.applyAdaptation()
            self.maybeAdvanceRoomIfNeeded()
        }
    }

    private func applyAdaptation() {
        guard let room = currentRoom else { return }
        let profile = room.adaptationProfile

        // Widens on rearrange.
        var newWidthScale: CGFloat = 1.0
        if profile.widensOnRearrange, !profile.rearrangeThresholds.isEmpty {
            let count = behaviorMetrics.rearrangementCount
            let thresholdsCrossed = profile.rearrangeThresholds.filter { count >= $0 }.count
            if thresholdsCrossed > 0 {
                newWidthScale = 1.0 + CGFloat(thresholdsCrossed) * 0.08
            }
        }

        // Softens on idle.
        var softeningProgress: CGFloat = 0
        if profile.softensOnIdle, profile.idleSofteningThreshold > 0 {
            let extraIdle = max(0, behaviorMetrics.idleDuration - profile.idleSofteningThreshold)
            let clampedExtra = min(extraIdle, 10)
            softeningProgress = CGFloat(clampedExtra / 10)
        }

        withAnimation(.easeInOut(duration: 0.6)) {
            widthScale = newWidthScale
            idleSofteningProgress = softeningProgress

            let baseShadow: CGFloat = 1.0
            let softenedShadow = baseShadow * (1.0 - 0.4 * softeningProgress)
            shadowStrength = softenedShadow
        }
    }
}

