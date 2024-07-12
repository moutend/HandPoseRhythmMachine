import AVFoundation
import SwiftUI
import UIKit

class PreviewView: UIView {
  override class var layerClass: AnyClass {
    AVCaptureVideoPreviewLayer.self
  }

  var previewLayer: AVCaptureVideoPreviewLayer {
    layer as! AVCaptureVideoPreviewLayer
  }

  var session: AVCaptureSession? {
    get { previewLayer.session }
    set { previewLayer.session = newValue }
  }
}

struct CameraView: UIViewRepresentable {
  let session: AVCaptureSession

  func makeUIView(context: Context) -> PreviewView {
    let preview = PreviewView()

    preview.session = self.session
    preview.previewLayer.connection?.videoOrientation = .portrait

    return preview
  }
  func updateUIView(_ uiView: PreviewView, context: Context) {
    // Do nothing.
  }
}

struct ContentView: View {
  @StateObject var cameraController = CameraController()

  var body: some View {
    Group {
      Text(
        "Wrist Confidence: \(self.cameraController.wristConfidence, specifier: "%.2f")"
      )
      Text(
        "Middle Tip Distance: \(self.cameraController.middleTipDistance, specifier: "%.2f")"
      )
      Text(
        "Rock Hand Pose: \(self.cameraController.rockHandPoseMedianDistance, specifier: "%.2f")"
      )
      Text(
        "Paper Hand Pose: \(self.cameraController.paperHandPoseMedianDistance, specifier: "%.2f")"
      )
    }
    CameraView(session: self.cameraController.captureSession)
      .frame(width: UIScreen.main.bounds.size.width)
    if self.cameraController.appState == .waitingRockHandPose {
      Text("Please make your hand the shape of rock.")
    }
    if self.cameraController.appState == .waitingPaperHandPose {
      Text("Please make your hand the shape of paper.")
    }
    if self.cameraController.appState == .capturingRockHandPose
      || self.cameraController.appState == .capturingPaperHandPose
    {
      Text("Scanning")
    }
    if self.cameraController.appState == .detectingHandPoses {
      Text("Detecting hand poses")
        .bold()
        .padding()
      Text("The shape of rock plays shaker sound.")
      Text("The shape of paper plays clap sound.")
    } else {
      Button(action: {
        if self.cameraController.appState == .waitingRockHandPose {
          self.cameraController.appState = .capturingRockHandPose
        }
        if self.cameraController.appState == .waitingPaperHandPose {
          self.cameraController.appState = .capturingPaperHandPose
        }
      }) {
        Text("Start scanning")
          .padding()
          .foregroundColor(Color.white)
          .background(Color.indigo)
      }
      .padding()
      .disabled(
        self.cameraController.appState == .capturingRockHandPose
          || self.cameraController.appState == .capturingPaperHandPose
          || self.cameraController.appState == .detectingHandPoses)
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
