import SwiftUI

/// High-level entry view for the Unpack the Room experience.
///
/// Hosts an `AppViewModel` and switches between the interactive room
/// sequence and the quiet ending screen.
public struct UnpackTheRoomRootView: View {
    @StateObject private var viewModel: AppViewModel

    public init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            switch viewModel.session.phase {
            case .inRoom:
                RoomView(viewModel: viewModel)
            case .ending:
                EndingView(viewModel: viewModel)
            }
        }
        .animation(.easeInOut(duration: 0.5), value: viewModel.session.phase)
        .background(
            Color.black.opacity(0.02)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Preview

#Preview {
    var demoObjects = [RoomObject].defaultObjects()
    if !demoObjects.isEmpty {
        demoObjects[0].position = RoomObject.NormalizedPosition(x: 0.5, y: 0.8)
        demoObjects[0].isPlaced = true
    }

    let viewModel = AppViewModel(initialObjects: demoObjects)
    return UnpackTheRoomRootView(viewModel: viewModel)
}

