import UIKit
import Flutter
import AVFoundation

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure audio session for playback (ignores silent switch)
    configureAudioSession()
    
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup method channel for audio session control
    setupAudioMethodChannel()
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func setupAudioMethodChannel() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }
    
    let channel = FlutterMethodChannel(name: "com.turiya/audio_session", binaryMessenger: controller.binaryMessenger)
    
    channel.setMethodCallHandler { [weak self] (call, result) in
      switch call.method {
      case "forcePlaybackMode":
        self?.forcePlaybackAudioSession()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
  
  /// Force audio session to playback mode (ignores silent switch)
  private func forcePlaybackAudioSession() {
    do {
      let audioSession = AVAudioSession.sharedInstance()
      
      // Use playback category - this IGNORES the silent switch
      try audioSession.setCategory(
        .playback,
        mode: .default,
        options: [.mixWithOthers, .defaultToSpeaker]
      )
      
      try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
      
      print("✅ Audio session forced to playback mode (silent switch ignored)")
    } catch {
      print("❌ Force playback error: \(error)")
    }
  }
  
  private func configureAudioSession() {
    forcePlaybackAudioSession()
  }
}
