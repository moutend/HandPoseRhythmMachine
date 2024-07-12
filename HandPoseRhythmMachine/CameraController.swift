import AVFoundation
import AudioToolbox
import CoreImage
import SwiftUI
import Vision

enum ConfigurationError: Error {
  case cameraUnavailable
  case requiredFormatUnavailable
}

enum AppState {
  case waitingRockHandPose
  case capturingRockHandPose
  case waitingPaperHandPose
  case capturingPaperHandPose
  case detectingHandPoses
}

class CameraController: NSObject, ObservableObject {
  private let soundEffectsManager = SoundEffectsManager()
  private let maxCapturingCount = 5
  private let preferredWidthResolution = 1920
  private let videoQueue = DispatchQueue(
    label: "com.example.HandPoseRhythmMachine.VideoQueue", qos: .userInteractive)

  @Published var appState: AppState = .waitingRockHandPose
  @Published var wristConfidence: Float = 0.0
  @Published var middleTipDistance: Double = 0.0
  @Published var rockHandPoseMedianDistance = 0.0
  @Published var paperHandPoseMedianDistance = 0.0

  private var rockHandPoseDistances: [Double] = []
  private var paperHandPoseDistances: [Double] = []
  private var lastCapturedTime = CFAbsoluteTimeGetCurrent()

  private var videoDataOutput: AVCaptureVideoDataOutput!

  var captureSession: AVCaptureSession!

  override init() {
    super.init()

    do {
      try setupSession()
    } catch {
      fatalError("Unable to configure the video stream session: \(error)")
    }
  }
  private func setupSession() throws {
    self.captureSession = AVCaptureSession()
    self.captureSession.sessionPreset = .inputPriority
    self.captureSession.beginConfiguration()

    try setupCaptureDevice()

    self.captureSession.commitConfiguration()
    self.captureSession.startRunning()
  }
  private func setupCaptureDevice() throws {
    guard
      let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
    else {
      throw ConfigurationError.cameraUnavailable
    }
    guard
      let format =
        (device.formats.last { format in
          format.formatDescription.dimensions.width == preferredWidthResolution
            && format.formatDescription.mediaSubType.rawValue
              == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
            && !format.isVideoBinned
        })
    else {
      throw ConfigurationError.requiredFormatUnavailable
    }

    try device.lockForConfiguration()
    device.activeFormat = format
    device.unlockForConfiguration()

    let deviceInput = try AVCaptureDeviceInput(device: device)

    self.videoDataOutput = AVCaptureVideoDataOutput()
    self.videoDataOutput.setSampleBufferDelegate(self, queue: self.videoQueue)
    self.videoDataOutput.alwaysDiscardsLateVideoFrames = true

    self.captureSession.addInput(deviceInput)
    self.captureSession.addOutput(self.videoDataOutput)
  }
}

extension CameraController: AVCaptureVideoDataOutputSampleBufferDelegate {
  func captureOutput(
    _ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer,
    from connection: AVCaptureConnection
  ) {

    let capturedTime = CFAbsoluteTimeGetCurrent()
    let duration = capturedTime - self.lastCapturedTime

    if duration < 0.5 {
      return
    }

    self.lastCapturedTime = capturedTime

    guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
      return
    }

    processImage(cvPixelBuffer: imageBuffer)
  }
  private func processImage(cvPixelBuffer: CVPixelBuffer) {
    let handPoseRequest = VNDetectHumanHandPoseRequest()
    let handler = VNImageRequestHandler(
      cvPixelBuffer: cvPixelBuffer, orientation: .right, options: [:])

    do {
      try handler.perform([handPoseRequest])
    } catch {
      fatalError("Failed to perform hand pose detection: \(error)")
    }

    processHandPose(request: handPoseRequest)
  }
  private func processHandPose(request: VNDetectHumanHandPoseRequest) {
    guard let observations = request.results else {
      return
    }
    for observation in observations {
      guard let landmarks = try? observation.recognizedPoints(.all) else {
        continue
      }

      let wrist = landmarks[.wrist]!

      // 0.75 is an arbitrarily chosen value, so if wrist recognition is not working well, try a smaller value.
      if wrist.confidence < 0.75 {
        continue
      }

      let middleTip = landmarks[.middleTip]!
      let distance = wrist.distance(middleTip)

      DispatchQueue.main.async {
        // Updateing values on the main thread because of SwiftUI thread safety.
        self.wristConfidence = wrist.confidence
        self.middleTipDistance = distance
      }
      switch self.appState {
      case .waitingRockHandPose, .waitingPaperHandPose:
        continue
      case .capturingRockHandPose:
        captureRockHandPose(distance)
      case .capturingPaperHandPose:
        capturePaperHandPose(distance)
      case .detectingHandPoses:
        processHandPoseDetection(distance)
      }
    }
  }
  private func captureRockHandPose(_ distance: Double) {
    if self.rockHandPoseDistances.count >= self.maxCapturingCount {
      return
    }

    self.rockHandPoseDistances.append(distance)

    AudioServicesPlaySystemSound(1000)

    if self.rockHandPoseDistances.count < self.maxCapturingCount {
      return
    }

    let sorted = self.rockHandPoseDistances.sorted()

    DispatchQueue.main.async {
      // Updateing values on the main thread because of SwiftUI thread safety.
      self.rockHandPoseMedianDistance = sorted[sorted.count / 2]
      self.appState = .waitingPaperHandPose
    }
  }
  private func capturePaperHandPose(_ distance: Double) {
    if self.paperHandPoseDistances.count >= self.maxCapturingCount {
      return
    }

    self.paperHandPoseDistances.append(distance)

    AudioServicesPlaySystemSound(1016)

    if self.paperHandPoseDistances.count < self.maxCapturingCount {
      return
    }

    let sorted = self.paperHandPoseDistances.sorted()

    DispatchQueue.main.async {
      // Updateing values on the main thread because of SwiftUI thread safety.
      self.paperHandPoseMedianDistance = sorted[sorted.count / 2]
      self.appState = .detectingHandPoses
    }
  }
  private func processHandPoseDetection(_ distance: Double) {
    let midPoint = (self.paperHandPoseMedianDistance - self.rockHandPoseMedianDistance) / 2.0

    if distance > self.rockHandPoseMedianDistance + midPoint {
      // Process when the hand shape is the shape of "rock" in rock-paper-scissors.
      self.soundEffectsManager.playClap()
    } else {
      // Process when the hand shape is the shape of "paper" in rock-paper-scissors.
      self.soundEffectsManager.playShaker()
    }
  }
}
