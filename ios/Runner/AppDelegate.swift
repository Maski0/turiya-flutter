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
    
    // Set up method channel for audio control
    let controller = window?.rootViewController as! FlutterViewController
    let audioChannel = FlutterMethodChannel(
      name: "com.turiya/audio",
      binaryMessenger: controller.binaryMessenger
    )
    
    audioChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "forceSpeaker" {
        self?.forceSpeakerOutput()
        result(true)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
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
  
  private func forceSpeakerOutput() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      
      // Deactivate first to reset
      try? audioSession.setActive(false)
      
      // Use playAndRecord with speaker options
      try audioSession.setCategory(
        .playAndRecord,
        mode: .voiceChat,
        options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers]
      )
      
      // Force override to speaker
      try audioSession.overrideOutputAudioPort(.speaker)
      
      // Activate with options
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      
      print("✅ Forced speaker output (mode: voiceChat)")
    } catch {
      print("❌ Error forcing speaker: \(error)")
    }
  }
}
