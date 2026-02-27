import SwiftUI

/// Main interactive room canvas showing the current room and its objects.
public struct RoomView: View {
    @ObservedObject private var viewModel: AppViewModel

    public init(viewModel: AppViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        GeometryReader { outerProxy in
            ZStack {
                if let room = viewModel.currentRoom {
                    roomBackground(for: room, in: outerProxy.size)

                    canvas(for: room, in: outerProxy.size)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Room shell & canvas

    private func roomBackground(for room: RoomDefinition, in size: CGSize) -> some View {
        let palette = room.basePalette
        let softening = viewModel.idleSofteningProgress

        return LinearGradient(
            colors: [
                palette.background,
                palette.background
                    .opacity(Double(max(0.7, 1.0 - 0.2 * softening)))
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .overlay(
            LinearGradient(
                colors: [
                    palette.accent.opacity(0.12 * Double(softening)),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func canvas(for room: RoomDefinition, in size: CGSize) -> some View {
        let canvasRect = computeCanvasRect(for: room, in: size)

        ZStack(alignment: .topLeading) {
            RoomShellView(
                room: room,
                canvasRect: canvasRect,
                softening: viewModel.idleSofteningProgress
            )
            ForEach(viewModel.objects) { object in
                RoomObjectDraggableView(
                    object: object,
                    room: room,
                    canvasRect: canvasRect,
                    viewModel: viewModel
                )
            }
        }
        .animation(.spring(response: 0.7, dampingFraction: 0.9), value: viewModel.widthScale)
    }

    private func computeCanvasRect(for room: RoomDefinition, in size: CGSize) -> CGRect {
        let baseHorizontalPadding = size.width * room.horizontalPaddingFactor
        let widenedPaddingFactor = 1.0 / max(1.0, viewModel.widthScale)
        let horizontalPadding = max(size.width * 0.04, baseHorizontalPadding * widenedPaddingFactor)

        let verticalPadding = size.height * room.verticalPaddingFactor
        let trayHeight: CGFloat = 80

        let width = size.width - horizontalPadding * 2
        let height = size.height - verticalPadding * 2 - trayHeight

        return CGRect(
            x: horizontalPadding,
            y: verticalPadding,
            width: max(0, width),
            height: max(0, height)
        )
    }
}

// MARK: - Shell

private struct RoomShellView: View {
    let room: RoomDefinition
    let canvasRect: CGRect
    let softening: CGFloat

    var body: some View {
        let cornerRadius: CGFloat = 24

        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(room.basePalette.background)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        room.basePalette.shadow.opacity(Double(0.25 * (1.0 - softening))),
                        lineWidth: 1.0
                    )
            )
            .shadow(
                color: room.basePalette.shadow.opacity(Double(0.30 * (1.0 - softening))),
                radius: 18,
                x: 0,
                y: 14
            )
            .overlay(lightGradient)
            .frame(width: canvasRect.width, height: canvasRect.height)
            .position(
                x: canvasRect.midX,
                y: canvasRect.midY
            )
    }

    private var lightGradient: some View {
        let accent = room.basePalette.accent
        let opacity = Double(0.10 * (1.0 - softening))

        let gradient: LinearGradient
        switch room.lightDirection {
        case .left:
            gradient = LinearGradient(
                colors: [accent.opacity(opacity), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .right:
            gradient = LinearGradient(
                colors: [.clear, accent.opacity(opacity)],
                startPoint: .leading,
                endPoint: .trailing
            )
        case .top:
            gradient = LinearGradient(
                colors: [accent.opacity(opacity), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
        case .bottom:
            gradient = LinearGradient(
                colors: [.clear, accent.opacity(opacity)],
                startPoint: .top,
                endPoint: .bottom
            )
        }

        return gradient
            .blendMode(.softLight)
    }
}

// MARK: - Draggable objects

private struct RoomObjectDraggableView: View {
    let object: RoomObject
    let room: RoomDefinition
    let canvasRect: CGRect
    @ObservedObject var viewModel: AppViewModel

    @GestureState private var isDragging: Bool = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        let basePoint = point(for: object.position)

        RoomObjectView(
            object: object,
            palette: room.basePalette,
            shadowStrength: viewModel.shadowStrength,
            lightDirection: room.lightDirection,
            isBeingDragged: isDragging
        )
        .position(
            x: basePoint.x + dragOffset.width,
            y: basePoint.y + dragOffset.height
        )
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    dragOffset = value.translation
                    viewModel.registerInteraction(for: object.id)
                }
                .onEnded { value in
                    let finalPoint = CGPoint(
                        x: basePoint.x + value.translation.width,
                        y: basePoint.y + value.translation.height
                    )

                    let normalized = normalizedPosition(for: finalPoint)
                    let clamped = viewModel.clampedPosition(normalized)
                    let imperfect = viewModel.isImperfectPlacement(for: object, at: clamped)

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        viewModel.placeObject(
                            id: object.id,
                            at: clamped,
                            isImperfect: imperfect
                        )
                        dragOffset = .zero
                    }
                }
        )
    }

    private func point(for position: RoomObject.NormalizedPosition) -> CGPoint {
        CGPoint(
            x: canvasRect.minX + canvasRect.width * position.x,
            y: canvasRect.minY + canvasRect.height * position.y
        )
    }

    private func normalizedPosition(for point: CGPoint) -> RoomObject.NormalizedPosition {
        guard canvasRect.width > 0, canvasRect.height > 0 else {
            return .tray
        }

        let x = (point.x - canvasRect.minX) / canvasRect.width
        let y = (point.y - canvasRect.minY) / canvasRect.height

        return RoomObject.NormalizedPosition(x: x, y: y)
    }
}

