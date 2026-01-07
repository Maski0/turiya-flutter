import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure audio session for playback with mixing
    configureAudioSession()
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func configureAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      
      // Use playback category with mixing - simpler config
      try audioSession.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers, .defaultToSpeaker]
      )
      
      // Activate the session
      try audioSession.setActive(true)
      
      print("✅ Audio session configured")
    } catch {
      print("❌ Audio session error: \(error)")
    }
  }
}
