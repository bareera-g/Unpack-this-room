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

        ZStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                RoomShellView(
                    room: room,
                    canvasRect: canvasRect,
                    softening: viewModel.idleSofteningProgress
                )
                ForEach($viewModel.objects, id: \.id) { $object in
                    if object.isPlaced {
                        RoomObjectDraggableView(
                            object: $object,
                            room: room,
                            canvasRect: canvasRect,
                            viewModel: viewModel
                        )
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Boxes")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)

                RoomBoxesTrayView(
                    objects: viewModel.objects,
                    palette: room.basePalette,
                    unpackAction: { object in
                        viewModel.unpackFromTray(id: object.id)
                    }
                )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
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
    @Binding var object: RoomObject
    let room: RoomDefinition
    let canvasRect: CGRect
    @ObservedObject var viewModel: AppViewModel

    @GestureState private var isDragging: Bool = false

    var body: some View {
        let point = toCGPoint(object.position, in: canvasRect)

        RoomObjectView(
            object: object,
            palette: room.basePalette,
            shadowStrength: viewModel.shadowStrength,
            lightDirection: room.lightDirection,
            isBeingDragged: isDragging
        )
        .position(point)
        .gesture(
            DragGesture()
                .updating($isDragging) { _, state, _ in
                    state = true
                }
                .onChanged { value in
                    let normalized = normalize(value.location, in: canvasRect)
                    let clamped = viewModel.clampedPosition(normalized)
                    object.position = clamped
                    viewModel.registerInteraction(for: object.id)
                }
                .onEnded { value in
                    let normalized = normalize(value.location, in: canvasRect)
                    let clamped = viewModel.clampedPosition(normalized)
                    let imperfect = viewModel.isImperfectPlacement(for: object, at: clamped)

                    withAnimation(.spring(response: 0.5, dampingFraction: 0.86)) {
                        viewModel.placeObject(
                            id: object.id,
                            at: clamped,
                            isImperfect: imperfect
                        )
                    }
                }
        )
    }

    private func normalize(_ point: CGPoint, in rect: CGRect) -> RoomObject.NormalizedPosition {
        guard rect.width > 0, rect.height > 0 else {
            return .tray
        }

        let x = (point.x - rect.minX) / rect.width
        let y = (point.y - rect.minY) / rect.height

        return RoomObject.NormalizedPosition(
            x: min(max(x, 0), 1),
            y: min(max(y, 0), 1)
        )
    }

    private func toCGPoint(_ pos: RoomObject.NormalizedPosition, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + pos.x * rect.width,
            y: rect.minY + pos.y * rect.height
        )
    }
}

// MARK: - Boxes tray

private struct RoomBoxesTrayView: View {
    let objects: [RoomObject]
    let palette: RoomColorPalette
    let unpackAction: (RoomObject) -> Void

    private var packedObjects: [RoomObject] {
        objects.filter { !$0.isPlaced }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.white.opacity(0.28), lineWidth: 1)
                )
                .shadow(
                    color: Color.black.opacity(0.12),
                    radius: 16,
                    x: 0,
                    y: 8
                )

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(packedObjects) { object in
                        Button {
                            unpackAction(object)
                        } label: {
                            RoomBoxChipView(object: object, palette: palette)
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

private struct RoomBoxChipView: View {
    let object: RoomObject
    let palette: RoomColorPalette

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName(for: object.kind))
                .font(.system(size: 16, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.accent)

            Text(label(for: object.kind))
                .font(.system(.footnote, design: .rounded))
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.24))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.40), lineWidth: 0.6)
        )
    }

    private func symbolName(for kind: RoomObjectKind) -> String {
        switch kind {
        case .lamp:
            return "lamp.table"
        case .chair:
            return "chair.lounge.fill"
        case .plant:
            return "leaf.fill"
        case .photoFrame:
            return "photo.on.rectangle.angled"
        case .mug:
            return "mug.fill"
        case .laptopOrBook:
            return "laptopcomputer"
        }
    }

    private func label(for kind: RoomObjectKind) -> String {
        switch kind {
        case .lamp:
            return "Lamp"
        case .chair:
            return "Chair"
        case .plant:
            return "Plant"
        case .photoFrame:
            return "Photo"
        case .mug:
            return "Mug"
        case .laptopOrBook:
            return "Desk"
        }
    }
}


