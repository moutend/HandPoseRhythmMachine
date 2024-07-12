import AVFoundation

class SoundEffectsManager {
  private let clap: AVAudioPlayer
  private let shaker: AVAudioPlayer

  init() {
    guard
      let clapPath = Bundle.main.path(
        forResource: "Clap", ofType: "wav")
    else {
      fatalError("Clap.wav is not found")
    }
    do {
      self.clap = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: clapPath))
    } catch {
      fatalError("Failed to initialize AVAudioPlayer: \(error)")
    }
    guard
      let shakerPath = Bundle.main.path(
        forResource: "Shaker", ofType: "wav")
    else {
      fatalError("Shaker.wav is not found")
    }
    do {
      self.shaker = try AVAudioPlayer(contentsOf: URL(fileURLWithPath: shakerPath))
    } catch {
      fatalError("Failed to initialize AVAudioPlayer: \(error)")
    }
  }
  func playClap() {
    self.clap.stop()
    self.clap.currentTime = 0.0
    self.clap.play()
  }
  func playShaker() {
    self.shaker.stop()
    self.shaker.currentTime = 0.0
    self.shaker.play()
  }
}
