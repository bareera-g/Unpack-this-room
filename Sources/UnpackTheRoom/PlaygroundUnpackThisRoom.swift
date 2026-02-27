import SwiftUI
#if os(iOS)
import UIKit
#endif

// MARK: - Models (Playground)

enum PlaygroundRoomMood: String, CaseIterable {
    case neutral
    case cool
    case warm
    case soft
}

struct PlaygroundRoomConfig: Identifiable {
    let id: Int
    let title: String
    let subtitle: String
    let mood: PlaygroundRoomMood

    let wallTop: Color
    let wallBottom: Color
    let floor: Color
    let floorShadow: Color
    let ambientColor: Color
    let baseAmbientOpacity: Double

    let baseHorizontalInsetFraction: CGFloat
    let baseVerticalInsetFraction: CGFloat

    let isTight: Bool
    let isAdaptiveBreathing: Bool
}

extension PlaygroundRoomConfig {
    static let rooms: [PlaygroundRoomConfig] = [
        PlaygroundRoomConfig(
            id: 0,
            title: "Room 1",
            subtitle: "Orientation",
            mood: .neutral,
            wallTop: Color(hue: 0.09, saturation: 0.10, brightness: 0.98),
            wallBottom: Color(hue: 0.09, saturation: 0.18, brightness: 0.93),
            floor: Color(hue: 0.08, saturation: 0.20, brightness: 0.86),
            floorShadow: Color.black.opacity(0.25),
            ambientColor: Color(hue: 0.10, saturation: 0.22, brightness: 0.95),
            baseAmbientOpacity: 0.22,
            baseHorizontalInsetFraction: 0.10,
            baseVerticalInsetFraction: 0.12,
            isTight: false,
            isAdaptiveBreathing: false
        ),
        PlaygroundRoomConfig(
            id: 1,
            title: "Room 2",
            subtitle: "Friction",
            mood: .cool,
            wallTop: Color(hue: 0.60, saturation: 0.12, brightness: 0.98),
            wallBottom: Color(hue: 0.60, saturation: 0.20, brightness: 0.92),
            floor: Color(hue: 0.60, saturation: 0.25, brightness: 0.80),
            floorShadow: Color.black.opacity(0.28),
            ambientColor: Color(hue: 0.58, saturation: 0.35, brightness: 0.90),
            baseAmbientOpacity: 0.26,
            baseHorizontalInsetFraction: 0.14,
            baseVerticalInsetFraction: 0.14,
            isTight: true,
            isAdaptiveBreathing: false
        ),
        PlaygroundRoomConfig(
            id: 2,
            title: "Room 3",
            subtitle: "Response",
            mood: .warm,
            wallTop: Color(hue: 0.06, saturation: 0.18, brightness: 0.98),
            wallBottom: Color(hue: 0.06, saturation: 0.30, brightness: 0.92),
            floor: Color(hue: 0.05, saturation: 0.32, brightness: 0.85),
            floorShadow: Color.black.opacity(0.26),
            ambientColor: Color(hue: 0.05, saturation: 0.45, brightness: 0.92),
            baseAmbientOpacity: 0.28,
            baseHorizontalInsetFraction: 0.13,
            baseVerticalInsetFraction: 0.12,
            isTight: false,
            isAdaptiveBreathing: true
        ),
        PlaygroundRoomConfig(
            id: 3,
            title: "Room 4",
            subtitle: "Acceptance",
            mood: .soft,
            wallTop: Color(hue: 0.11, saturation: 0.08, brightness: 0.99),
            wallBottom: Color(hue: 0.11, saturation: 0.15, brightness: 0.94),
            floor: Color(hue: 0.10, saturation: 0.18, brightness: 0.88),
            floorShadow: Color.black.opacity(0.20),
            ambientColor: Color(hue: 0.12, saturation: 0.20, brightness: 0.96),
            baseAmbientOpacity: 0.30,
            baseHorizontalInsetFraction: 0.11,
            baseVerticalInsetFraction: 0.12,
            isTight: false,
            isAdaptiveBreathing: false
        )
    ]
}

struct PlaygroundItemKind: Identifiable {
    let id: String
    let name: String
    let symbolName: String
    let color: Color
}

extension PlaygroundItemKind {
    static let all: [PlaygroundItemKind] = [
        PlaygroundItemKind(id: "lamp",   name: "Lamp",   symbolName: "lamp.table",     color: .yellow),
        PlaygroundItemKind(id: "plant",  name: "Plant",  symbolName: "leaf.fill",      color: .green),
        PlaygroundItemKind(id: "mug",    name: "Mug",    symbolName: "mug.fill",       color: .orange),
        PlaygroundItemKind(id: "photo",  name: "Photo",  symbolName: "photo.on.rectangle.angled", color: .blue),
        PlaygroundItemKind(id: "book",   name: "Book",   symbolName: "book.closed.fill", color: .purple)
    ]
}

struct PlaygroundRoomItemState: Identifiable {
    let id: UUID
    let kind: PlaygroundItemKind
    let roomIndex: Int
    var isInTray: Bool
    var normalizedPosition: CGPoint?
}

enum PlaygroundGamePhase {
    case inRooms
    case ended
}

// MARK: - Haptics (Playground)

enum PlaygroundHaptics {
    static func unpack() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .soft)
        generator.impactOccurred(intensity: 0.6)
        #endif
    }

    static func drop() {
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.5)
        #endif
    }
}

// MARK: - Game State (Playground)

final class PlaygroundGameState: ObservableObject {
    @Published var rooms: [PlaygroundRoomConfig]
    @Published var items: [PlaygroundRoomItemState]
    @Published var currentRoomIndex: Int = 0
    @Published var phase: PlaygroundGamePhase = .inRooms

    @Published private(set) var rearrangementCount: Int = 0
    @Published private(set) var idleSeconds: TimeInterval = 0

    @Published var showPlacementDebugOutline: Bool = false

    private var lastInteractionDate: Date = Date()

    let idleTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        let configs = PlaygroundRoomConfig.rooms
        self.rooms = configs

        var allItems: [PlaygroundRoomItemState] = []

        for roomIndex in configs.indices {
            for kind in PlaygroundItemKind.all {
                allItems.append(
                    PlaygroundRoomItemState(
                        id: UUID(),
                        kind: kind,
                        roomIndex: roomIndex,
                        isInTray: true,
                        normalizedPosition: nil
                    )
                )
            }
        }

        self.items = allItems
    }

    var currentRoom: PlaygroundRoomConfig {
        rooms[currentRoomIndex]
    }

    var trayItems: [PlaygroundRoomItemState] {
        items.filter { $0.roomIndex == currentRoomIndex && $0.isInTray }
    }

    var placedItems: [PlaygroundRoomItemState] {
        items.filter { $0.roomIndex == currentRoomIndex && !$0.isInTray && $0.normalizedPosition != nil }
    }

    var isLastRoom: Bool {
        currentRoomIndex >= rooms.count - 1
    }

    var ambientSofteningProgress: Double {
        let room = currentRoom
        let idleFactor = min(1.0, idleSeconds / 12.0)
        let rearrangeFactor = min(1.0, Double(rearrangementCount) / 10.0)

        var value = room.baseAmbientOpacity
        value += 0.25 * idleFactor

        if room.isAdaptiveBreathing {
            value += 0.30 * rearrangeFactor
        }

        return min(1.0, value)
    }

    var allowedInsetMultiplier: CGFloat {
        let room = currentRoom
        var multiplier: CGFloat = 1.0

        if room.isTight {
            multiplier *= 1.10
        }

        if room.isAdaptiveBreathing {
            let steps = min(3, rearrangementCount / 2)
            let breathingFactor = 1.0 - 0.08 * CGFloat(steps)
            multiplier *= max(0.72, breathingFactor)
        }

        return multiplier
    }

    func registerInteraction() {
        lastInteractionDate = Date()
        idleSeconds = 0
    }

    func tickIdle() {
        idleSeconds = Date().timeIntervalSince(lastInteractionDate)
    }

    func unpack(item: PlaygroundRoomItemState) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        registerInteraction()
        items[index].isInTray = false
        items[index].normalizedPosition = CGPoint(x: 0.5, y: 0.82)
        PlaygroundHaptics.unpack()
    }

    func updatePosition(for itemID: UUID, to normalized: CGPoint) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        registerInteraction()

        let previous = items[index].normalizedPosition
        items[index].normalizedPosition = normalized

        if let prev = previous {
            let dx = prev.x - normalized.x
            let dy = prev.y - normalized.y
            let distance = sqrt(dx * dx + dy * dy)
            if distance > 0.04 {
                rearrangementCount += 1
            }
        }

        PlaygroundHaptics.drop()
    }

    func advanceRoom() {
        registerInteraction()
        if isLastRoom {
            phase = .ended
        } else {
            currentRoomIndex += 1
            rearrangementCount = 0
            idleSeconds = 0

            for idx in items.indices where items[idx].roomIndex == currentRoomIndex {
                items[idx].isInTray = true
                items[idx].normalizedPosition = nil
            }
        }
    }

    func restart() {
        phase = .inRooms
        currentRoomIndex = 0
        rearrangementCount = 0
        idleSeconds = 0
        lastInteractionDate = Date()

        for idx in items.indices {
            items[idx].isInTray = items[idx].roomIndex == 0
            items[idx].normalizedPosition = nil
        }
    }

    func allowedRect(in size: CGSize) -> CGRect {
        let room = currentRoom

        let horizontalInset = size.width
            * room.baseHorizontalInsetFraction
            * allowedInsetMultiplier
        let verticalInset = size.height
            * room.baseVerticalInsetFraction
            * allowedInsetMultiplier

        let floorHeight = max(120, size.height * 0.25)

        let left = horizontalInset
        let right = size.width - horizontalInset
        let top = verticalInset + size.height * 0.10
        let bottom = size.height - floorHeight - verticalInset

        return CGRect(
            x: left,
            y: top,
            width: max(0, right - left),
            height: max(0, bottom - top)
        )
    }
}

// MARK: - Root View (Playground)

public struct PlaygroundRootView: View {
    @StateObject private var state = PlaygroundGameState()

    public init() {}

    public var body: some View {
        Group {
            switch state.phase {
            case .inRooms:
                PlaygroundRoomView(state: state)
            case .ended:
                PlaygroundEndView(onRestart: {
                    withAnimation(.easeInOut(duration: 0.8)) {
                        state.restart()
                    }
                })
            }
        }
        .animation(.easeInOut(duration: 0.45), value: state.phase)
    }
}

// MARK: - Room View (Playground)

struct PlaygroundRoomView: View {
    @ObservedObject var state: PlaygroundGameState

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let room = state.currentRoom
            let allowedRect = state.allowedRect(in: size)

            ZStack {
                PlaygroundRoomBackground(
                    room: room,
                    allowedRect: allowedRect,
                    ambientOpacity: state.ambientSofteningProgress,
                    showDebugBounds: state.showPlacementDebugOutline
                )
                .ignoresSafeArea()

                ZStack {
                    ForEach(state.placedItems) { item in
                        PlaygroundDraggablePlacedItemView(
                            item: item,
                            room: room,
                            allowedRect: allowedRect,
                            state: state
                        )
                    }
                }

                VStack(spacing: 0) {
                    topBar(room: room)
                        .padding(.horizontal, 20)
                        .padding(.top, 16)

                    Spacer(minLength: 0)

                    PlaygroundBoxTrayView(
                        items: state.trayItems,
                        room: room,
                        onTapItem: { tapped in
                            state.unpack(item: tapped)
                        }
                    )
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20 + proxy.safeAreaInsets.bottom)
                }
            }
            .onReceive(state.idleTimer) { _ in
                state.tickIdle()
            }
        }
    }

    private func topBar(room: PlaygroundRoomConfig) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(room.title)
                    .font(.system(.headline, design: .rounded))
                Text(room.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.5)) {
                    state.advanceRoom()
                }
            }) {
                Text(state.isLastRoom ? "End" : "Next")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.white.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Draggable placed item (Playground)

private struct PlaygroundDraggablePlacedItemView: View {
    let item: PlaygroundRoomItemState
    let room: PlaygroundRoomConfig
    let allowedRect: CGRect
    @ObservedObject var state: PlaygroundGameState

    @GestureState private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        let basePoint = point(for: item.normalizedPosition ?? CGPoint(x: 0.5, y: 0.82))

        PlaygroundItemView(
            title: item.kind.name,
            symbolName: item.kind.symbolName,
            accentColor: item.kind.color,
            context: .room,
            isLifted: isDragging
        )
        .position(
            x: basePoint.x + dragOffset.width,
            y: basePoint.y + dragOffset.height
        )
        .shadow(
            color: Color.black.opacity(isDragging ? 0.18 : 0.12),
            radius: isDragging ? 14 : 8,
            x: 0,
            y: 6
        )
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .gesture(
            DragGesture()
                .updating($isDragging) { _, stateGesture, _ in
                    stateGesture = true
                }
                .onChanged { value in
                    dragOffset = value.translation
                    state.registerInteraction()
                }
                .onEnded { value in
                    let finalPoint = CGPoint(
                        x: basePoint.x + value.translation.width,
                        y: basePoint.y + value.translation.height
                    )
                    let normalized = normalizedPosition(for: finalPoint)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        state.updatePosition(for: item.id, to: normalized)
                        dragOffset = .zero
                    }
                }
        )
    }

    private func point(for normalized: CGPoint) -> CGPoint {
        CGPoint(
            x: allowedRect.minX + allowedRect.width * normalized.x,
            y: allowedRect.minY + allowedRect.height * normalized.y
        )
    }

    private func normalizedPosition(for point: CGPoint) -> CGPoint {
        guard allowedRect.width > 0, allowedRect.height > 0 else {
            return CGPoint(x: 0.5, y: 0.5)
        }

        let clampedX = min(max(point.x, allowedRect.minX), allowedRect.maxX)
        let clampedY = min(max(point.y, allowedRect.minY), allowedRect.maxY)

        return CGPoint(
            x: (clampedX - allowedRect.minX) / allowedRect.width,
            y: (clampedY - allowedRect.minY) / allowedRect.height
        )
    }
}

// MARK: - Box Tray (Playground)

struct PlaygroundBoxTrayView: View {
    let items: [PlaygroundRoomItemState]
    let room: PlaygroundRoomConfig
    let onTapItem: (PlaygroundRoomItemState) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Boxes")
                .font(.caption)
                .foregroundStyle(.secondary)

            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .stroke(Color.white.opacity(0.25), lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.12),
                        radius: 16,
                        x: 0,
                        y: 8
                    )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(items) { item in
                            Button {
                                onTapItem(item)
                            } label: {
                                PlaygroundItemView(
                                    title: item.kind.name,
                                    symbolName: item.kind.symbolName,
                                    accentColor: item.kind.color,
                                    context: .tray,
                                    isLifted: false
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                }
            }
        }
    }
}

// MARK: - Item View (Playground)

struct PlaygroundItemView: View {
    enum Context {
        case tray
        case room
    }

    let title: String
    let symbolName: String
    let accentColor: Color
    let context: Context
    let isLifted: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: context == .tray ? 20 : 22, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(accentColor)

            if context == .tray {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .padding(.horizontal, context == .tray ? 14 : 12)
        .padding(.vertical, context == .tray ? 10 : 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    context == .tray
                    ? Color.white.opacity(isLifted ? 0.30 : 0.22)
                    : Color.white.opacity(isLifted ? 0.32 : 0.26)
                )
                .shadow(
                    color: Color.black.opacity(isLifted ? 0.15 : 0.08),
                    radius: isLifted ? 10 : 6,
                    x: 0,
                    y: isLifted ? 6 : 3
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.40), lineWidth: 0.6)
        )
        .animation(.easeInOut(duration: 0.2), value: isLifted)
    }
}

// MARK: - Room Background (Playground)

struct PlaygroundRoomBackground: View {
    let room: PlaygroundRoomConfig
    let allowedRect: CGRect
    let ambientOpacity: Double
    let showDebugBounds: Bool

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [room.wallTop, room.wallBottom],
                startPoint: .top,
                endPoint: .bottom
            )

            GeometryReader { proxy in
                let size = proxy.size
                let floorHeight = max(120, size.height * 0.25)

                Rectangle()
                    .fill(room.floor)
                    .frame(height: floorHeight)
                    .frame(maxHeight: .infinity, alignment: .bottom)
                    .shadow(
                        color: room.floorShadow,
                        radius: 22,
                        x: 0,
                        y: -4
                    )
            }

            RoundedRectangle(cornerRadius: 80, style: .continuous)
                .fill(room.ambientColor.opacity(ambientOpacity))
                .blur(radius: 60)
                .scaleEffect(1.25)
                .offset(y: -60)
        }
        .overlay(
            Group {
                if showDebugBounds {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(
                            Color.white.opacity(0.35),
                            style: StrokeStyle(lineWidth: 1, dash: [6, 4])
                        )
                        .frame(width: allowedRect.width, height: allowedRect.height)
                        .position(
                            x: allowedRect.midX,
                            y: allowedRect.midY
                        )
                }
            }
        )
    }
}

// MARK: - End View (Playground)

struct PlaygroundEndView: View {
    let onRestart: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hue: 0.10, saturation: 0.06, brightness: 0.99),
                    Color(hue: 0.11, saturation: 0.10, brightness: 0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Text("You make space wherever you go.")
                    .font(.system(.title2, design: .serif))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text("Tap to gently begin again.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onRestart()
        }
    }
}

