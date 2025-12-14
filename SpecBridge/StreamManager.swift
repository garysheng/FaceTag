import Foundation
import SwiftUI
import Combine
import UIKit
import AVFoundation
import MWDATCore
import MWDATCamera

@MainActor
class StreamManager: ObservableObject {
    @Published var currentFrame: UIImage?
    @Published var status = "Ready"
    @Published var isStreaming = false
    
    private var streamSession: StreamSession?
    private var token: AnyListenerToken?
    
    private func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            // Sets iOS to allow Bluetooth audio (prevents "Video Paused" error)
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
            print("Audio session configured successfully")
        } catch {
            print("Failed to configure audio session: \(error)")
        }
    }
    
    func startStreaming() async {
        status = "Checking permissions..."
        
        let currentStatus = try? await Wearables.shared.checkPermissionStatus(.camera)
        if currentStatus != .granted {
            status = "Requesting permission..."
            let requestResult = try? await Wearables.shared.requestPermission(.camera)
            if requestResult != .granted {
                status = "Permission denied. Check Meta AI app."
                return
            }
        }
        
        status = "Configuring..."
        configureAudio()
        
        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        
        // Medium resolution for better photo quality
        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .medium,
            frameRate: 24
        )
        
        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        self.streamSession = session
        
        token = session.videoFramePublisher.listen { [weak self] frame in
            if let image = frame.makeUIImage() {
                Task { @MainActor in
                    self?.currentFrame = image
                    self?.status = "Connected"
                    self?.isStreaming = true
                }
            }
        }
        
        status = "Connecting..."
        await session.start()
    }
    
    func stopStreaming() async {
        status = "Stopping..."
        await streamSession?.stop()
        status = "Ready"
        isStreaming = false
        currentFrame = nil
    }
    
    /// Capture the current frame as a photo
    func capturePhoto() -> UIImage? {
        return currentFrame
    }
}
