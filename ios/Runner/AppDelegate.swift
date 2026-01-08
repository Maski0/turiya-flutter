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
    
    // Set up method channel for AV merge
    let mergeChannel = FlutterMethodChannel(
      name: "com.turiya/av_merge",
      binaryMessenger: controller.binaryMessenger
    )
    
    mergeChannel.setMethodCallHandler { [weak self] (call, result) in
      if call.method == "mergeAudioVideo" {
        guard let args = call.arguments as? [String: String],
              let audioPath = args["audioPath"],
              let videoPath = args["videoPath"] else {
          result(FlutterError(code: "INVALID_ARGS", message: "Missing audio or video path", details: nil))
          return
        }
        
        self?.mergeAudioVideo(audioPath: audioPath, videoPath: videoPath) { outputPath, error in
          if let error = error {
            result(FlutterError(code: "MERGE_ERROR", message: error.localizedDescription, details: nil))
          } else {
            result(outputPath)
          }
        }
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
  
  /// Merge audio and video files using AVFoundation
  private func mergeAudioVideo(audioPath: String, videoPath: String, completion: @escaping (String?, Error?) -> Void) {
    print("🎬 Starting AV merge: audio=\(audioPath), video=\(videoPath)")
    
    let audioURL = URL(fileURLWithPath: audioPath)
    let videoURL = URL(fileURLWithPath: videoPath)
    
    // Create assets
    let audioAsset = AVURLAsset(url: audioURL)
    let videoAsset = AVURLAsset(url: videoURL)
    
    // Create composition
    let composition = AVMutableComposition()
    
    // Add video track
    guard let videoTrack = videoAsset.tracks(withMediaType: .video).first,
          let compositionVideoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      print("❌ Failed to get video track")
      completion(nil, NSError(domain: "AVMerge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to get video track"]))
      return
    }
    
    do {
      let videoTimeRange = CMTimeRange(start: .zero, duration: videoAsset.duration)
      try compositionVideoTrack.insertTimeRange(videoTimeRange, of: videoTrack, at: .zero)
      compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
      print("✅ Video track added: duration=\(CMTimeGetSeconds(videoAsset.duration))s")
    } catch {
      print("❌ Failed to insert video track: \(error)")
      completion(nil, error)
      return
    }
    
    // Add audio track
    guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first,
          let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
      print("⚠️ No audio track found, returning video only")
      // If no audio track, just export the video
      exportComposition(composition, completion: completion)
      return
    }
    
    do {
      // Use the shorter of video or audio duration to avoid sync issues
      let audioDuration = audioAsset.duration
      let videoDuration = videoAsset.duration
      let useDuration = CMTimeMinimum(audioDuration, videoDuration)
      let audioTimeRange = CMTimeRange(start: .zero, duration: useDuration)
      try compositionAudioTrack.insertTimeRange(audioTimeRange, of: audioTrack, at: .zero)
      print("✅ Audio track added: duration=\(CMTimeGetSeconds(audioDuration))s, using=\(CMTimeGetSeconds(useDuration))s")
    } catch {
      print("❌ Failed to insert audio track: \(error)")
      // Continue without audio
    }
    
    // Export the merged composition
    exportComposition(composition, completion: completion)
  }
  
  /// Export the composition to a file
  private func exportComposition(_ composition: AVMutableComposition, completion: @escaping (String?, Error?) -> Void) {
    // Create output path
    let timestamp = Int(Date().timeIntervalSince1970 * 1000)
    let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
    let outputPath = "\(documentsPath)/merged_recording_\(timestamp).mp4"
    let outputURL = URL(fileURLWithPath: outputPath)
    
    // Remove existing file if any
    try? FileManager.default.removeItem(at: outputURL)
    
    // Create export session
    guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
      print("❌ Failed to create export session")
      completion(nil, NSError(domain: "AVMerge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create export session"]))
      return
    }
    
    exportSession.outputURL = outputURL
    exportSession.outputFileType = .mp4
    exportSession.shouldOptimizeForNetworkUse = true
    
    print("🎬 Exporting merged video to: \(outputPath)")
    
    exportSession.exportAsynchronously {
      DispatchQueue.main.async {
        switch exportSession.status {
        case .completed:
          print("✅ Export completed: \(outputPath)")
          completion(outputPath, nil)
        case .failed:
          print("❌ Export failed: \(exportSession.error?.localizedDescription ?? "Unknown error")")
          completion(nil, exportSession.error)
        case .cancelled:
          print("⚠️ Export cancelled")
          completion(nil, NSError(domain: "AVMerge", code: 3, userInfo: [NSLocalizedDescriptionKey: "Export cancelled"]))
        default:
          print("⚠️ Export status: \(exportSession.status.rawValue)")
          completion(nil, NSError(domain: "AVMerge", code: 4, userInfo: [NSLocalizedDescriptionKey: "Unknown export status"]))
        }
      }
    }
  }
}
