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
    
    private var streamSession: StreamSession?
    private var photoToken: AnyListenerToken?
    private var stateToken: AnyListenerToken?
    
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
        
        configureAudio()
        
        status = "Connecting..."
        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        
        // We still need a stream session to receive photos
        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .high,  // High res for better contact photos
            frameRate: 2        // Minimal frame rate since we only want photos
        )
        
        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        self.streamSession = session
        
        // Listen for photos captured via glasses button
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
                    self?.status = "Ready - tap glasses to capture"
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
        isConnected = false
        status = "Ready"
    }
    
    /// Trigger a photo capture programmatically (backup option)
    func capturePhoto() {
        streamSession?.capturePhoto(format: .jpeg)
    }
    
    /// Clear the captured photo after saving
    func clearPhoto() {
        capturedPhoto = nil
        status = "Ready - tap glasses to capture"
    }
}
