import Foundation
import SwiftUI
import Combine
import UIKit
import AVFoundation
import MWDATCore
import MWDATCamera

@MainActor
class CaptureManager: ObservableObject {
    @Published var status = "Ready"
    @Published var isConnected = false
    @Published var capturedPhoto: UIImage?
    @Published var currentFrame: UIImage?  // Live preview
    
    private var streamSession: StreamSession?
    private var photoToken: AnyListenerToken?
    private var stateToken: AnyListenerToken?
    private var frameToken: AnyListenerToken?
    
    private func configureAudio() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
            try session.setActive(true)
        } catch {
            print("Audio config error: \(error)")
        }
    }
    
    func startListening() async {
        status = "Starting..."
        
        // Check camera permission
        do {
            let permStatus = try await Wearables.shared.checkPermissionStatus(.camera)
            
            if permStatus != .granted {
                status = "Requesting camera access..."
                let result = try await Wearables.shared.requestPermission(.camera)
                if result != .granted {
                    status = "Camera permission denied"
                    return
                }
            }
        } catch {
            status = "Permission error: \(error.localizedDescription)"
            return
        }
        
        configureAudio()
        
        status = "Connecting to glasses..."
        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        
        // Medium resolution, moderate frame rate for reliable capture
        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .medium,
            frameRate: 15
        )
        
        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        self.streamSession = session
        
        // Listen for video frames (for preview and capture)
        frameToken = session.videoFramePublisher.listen { [weak self] frame in
            if let image = frame.makeUIImage() {
                Task { @MainActor in
                    self?.currentFrame = image
                }
            }
        }
        
        // Listen for photos captured via glasses button or capturePhoto()
        photoToken = session.photoDataPublisher.listen { [weak self] photoData in
            let data = photoData.data
            if let image = UIImage(data: data) {
                Task { @MainActor in
                    self?.capturedPhoto = image
                    self?.status = "Photo captured!"
                }
            }
        }
        
        // Listen for state changes
        stateToken = session.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                switch state {
                case .streaming:
                    self?.isConnected = true
                    self?.status = "Ready - tap to capture"
                case .stopped:
                    self?.isConnected = false
                    self?.status = "Disconnected"
                case .paused:
                    self?.status = "Paused"
                case .starting:
                    self?.status = "Starting..."
                case .stopping:
                    self?.status = "Stopping..."
                case .waitingForDevice:
                    self?.status = "Waiting for glasses..."
                @unknown default:
                    break
                }
            }
        }
        
        await session.start()
    }
    
    func stopListening() async {
        await streamSession?.stop()
        streamSession = nil
        photoToken = nil
        stateToken = nil
        frameToken = nil
        currentFrame = nil
        isConnected = false
        status = "Ready"
    }
    
    /// Trigger a photo capture - uses latest video frame for reliability
    func capturePhoto() {
        guard isConnected else {
            status = "Not connected"
            return
        }
        
        // Use current video frame directly (more reliable than photo API)
        if let frame = currentFrame {
            capturedPhoto = frame
            status = "Photo captured!"
        } else {
            // Fallback to photo API
            status = "Capturing..."
            streamSession?.capturePhoto(format: .jpeg)
        }
    }
    
    /// Clear the captured photo after saving
    func clearPhoto() {
        capturedPhoto = nil
        if isConnected {
            status = "Ready - tap to capture"
        }
    }
}
