import Foundation

/// Per-room behavior metrics that drive adaptation.
public struct BehaviorMetrics: Sendable {
    public var rearrangementCount: Int
    public var objectsTouched: Set<UUID>
    public var idleDuration: TimeInterval
    public var hasLeftImperfect: Bool
    public var placementAttempts: Int

    public init(
        rearrangementCount: Int = 0,
        objectsTouched: Set<UUID> = [],
        idleDuration: TimeInterval = 0,
        hasLeftImperfect: Bool = false,
        placementAttempts: Int = 0
    ) {
        self.rearrangementCount = rearrangementCount
        self.objectsTouched = objectsTouched
        self.idleDuration = idleDuration
        self.hasLeftImperfect = hasLeftImperfect
        self.placementAttempts = placementAttempts
    }

    public var objectsTouchedCount: Int {
        objectsTouched.count
    }
}

