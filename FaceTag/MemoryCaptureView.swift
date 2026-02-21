import SwiftUI
import Combine
import AVFoundation
import MWDATCore
import MWDATCamera

@MainActor
class MemoryCaptureManager: ObservableObject {
    @Published var status = "Ready"
    @Published var isConnected = false
    @Published var currentFrame: UIImage?
    @Published var lastCapture: UIImage?
    @Published var isSending = false

    private var streamSession: StreamSession?
    private var frameToken: (any AnyListenerToken)?
    private var stateToken: (any AnyListenerToken)?

    func startCamera() async {
        status = "Starting..."

        do {
            let permStatus = try await Wearables.shared.checkPermissionStatus(.camera)
            if permStatus != .granted {
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

        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.playAndRecord, mode: .default,
                                       options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker])
        try? audioSession.setActive(true)

        status = "Connecting..."
        let selector = AutoDeviceSelector(wearables: Wearables.shared)
        let config = StreamSessionConfig(videoCodec: .raw, resolution: .medium, frameRate: 15)
        let session = StreamSession(streamSessionConfig: config, deviceSelector: selector)
        self.streamSession = session

        frameToken = session.videoFramePublisher.listen { @Sendable [weak self] frame in
            if let image = frame.makeUIImage() {
                Task { @MainActor in
                    self?.currentFrame = image
                }
            }
        }

        stateToken = session.statePublisher.listen { @Sendable [weak self] state in
            Task { @MainActor in
                guard let self else { return }
                switch state {
                case .streaming:
                    self.isConnected = true
                    self.status = "Tap to capture a memory"
                case .stopped:
                    self.isConnected = false
                    self.status = "Disconnected"
                case .waitingForDevice:
                    self.status = "Waiting for glasses..."
                default:
                    break
                }
            }
        }

        await session.start()
    }

    func stopCamera() async {
        await streamSession?.stop()
        streamSession = nil
        frameToken = nil
        stateToken = nil
        currentFrame = nil
        isConnected = false
        status = "Ready"
    }

    func captureAndSend(settings: AppSettings) async {
        guard let image = currentFrame else {
            status = "No frame to capture"
            return
        }

        lastCapture = image
        isSending = true
        status = "Sending to OpenClaw..."

        let client = OpenClawClient(
            baseURL: settings.gatewayURL,
            gatewayPassword: settings.gatewayPassword,
            hooksToken: settings.hooksToken
        )

        let prompt = """
        This image was captured from my Meta Ray-Ban glasses. \
        Process this as an important memory for me. \
        Describe what you see in detail, note the context and setting, \
        and store it as a meaningful moment worth remembering. \
        Include the date and any relevant observations.
        """

        do {
            // Send image to OpenClaw via chat completions (vision)
            let response = try await client.sendMemory(image: image, prompt: prompt)
            status = "Memory processed!"

            // Forward the response to Telegram
            try await client.notify(
                message: "📸 Memory from Ray-Bans:\n\n\(response)",
                channel: "telegram",
                to: settings.telegramChatID
            )
            status = "Memory saved! Check Telegram."
        } catch {
            status = "Error: \(error.localizedDescription)"
        }

        isSending = false
    }
}

struct MemoryCaptureView: View {
    @EnvironmentObject var settings: AppSettings
    @StateObject private var manager = MemoryCaptureManager()

    var body: some View {
        VStack(spacing: 0) {
            // Preview
            ZStack {
                Color.black

                if let frame = manager.currentFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 50))
                            .foregroundStyle(.gray.opacity(0.5))
                        if !manager.isConnected {
                            Text("Tap Start Camera to begin")
                                .font(.subheadline)
                                .foregroundStyle(.gray)
                        }
                    }
                }

                // Live indicator
                if manager.isConnected && manager.currentFrame != nil && !manager.isSending {
                    VStack {
                        HStack {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(.green)
                                    .frame(width: 8, height: 8)
                                Text("LIVE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding(12)
                }

                // Flash overlay on capture
                if manager.isSending {
                    Color.white.opacity(0.3)
                        .ignoresSafeArea()
                }
            }
            .frame(maxHeight: .infinity)

            // Last capture thumbnail
            if let lastCapture = manager.lastCapture {
                HStack {
                    Image(uiImage: lastCapture)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading) {
                        Text("Last memory captured")
                            .font(.caption)
                            .fontWeight(.medium)
                        Text(manager.status)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding()
                .background(.ultraThinMaterial)
            }

            // Controls
            VStack(spacing: 12) {
                if manager.lastCapture == nil {
                    Text(manager.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !settings.isConfigured {
                    Text("Configure OpenClaw settings first")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                if manager.isConnected {
                    Button {
                        Task { await manager.captureAndSend(settings: settings) }
                    } label: {
                        Label(manager.isSending ? "Sending..." : "Capture Memory",
                              systemImage: manager.isSending ? "arrow.up.circle" : "brain.head.profile")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.purple)
                    .controlSize(.large)
                    .disabled(manager.isSending || !settings.isConfigured)

                    Button {
                        Task { await manager.stopCamera() }
                    } label: {
                        Label("Stop Camera", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                } else {
                    Button {
                        Task { await manager.startCamera() }
                    } label: {
                        Label("Start Camera", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .navigationTitle("Memory Capture")
        .navigationBarTitleDisplayMode(.inline)
    }
}
