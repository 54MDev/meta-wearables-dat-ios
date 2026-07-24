import MWDATCore
import SwiftUI

struct StreamView: View {
  @Bindable var viewModel: StreamSessionViewModel
  var wearablesVM: WearablesViewModel

  var body: some View {
    ZStack {
      // Black background for letterboxing/pillarboxing
      Color.black
        .edgesIgnoringSafeArea(.all)

      // Video backdrop — full captured frame, letterboxed rather than cropped
      if let videoFrame = viewModel.currentVideoFrame, viewModel.hasReceivedFirstFrame {
        Image(uiImage: videoFrame)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .edgesIgnoringSafeArea(.all)
      } else {
        ProgressView()
          .scaleEffect(1.5)
          .foregroundStyle(.white)
      }

      // Debug overlay: quality + fps markers
      VStack {
        HStack {
          VStack(alignment: .leading, spacing: 2) {
            Text(viewModel.qualityLabel)
            Text("glasses: \(viewModel.glassesFPS) fps")
            Text("display: \(viewModel.displayFPS) fps")
          }
          .font(.caption.monospaced())
          .foregroundStyle(.white)
          .padding(8)
          .background(.black.opacity(0.5))
          .clipShape(RoundedRectangle(cornerRadius: 6))
          .padding([.top, .leading], 12)
          Spacer()
        }
        Spacer()
      }
      .edgesIgnoringSafeArea(.top)

      // Bottom controls layer
      VStack {
        Spacer()
        CustomButton(
          title: "Stop streaming",
          style: .destructive,
          isDisabled: false
        ) {
          viewModel.stopSession()
        }
      }
      .padding(.all, 24)
    }
    .onDisappear {
      if viewModel.streamingStatus != .stopped {
        viewModel.stopSession()
      }
    }
  }
}
