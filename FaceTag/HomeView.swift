import SwiftUI
import MWDATCore

struct Tool: Identifiable {
    let id: String
    let name: String
    let icon: String
    let color: Color
    let description: String
}

let tools: [Tool] = [
    Tool(id: "facetag", name: "FaceTag", icon: "person.crop.rectangle", color: .blue,
         description: "Capture photos and tag contacts"),
    Tool(id: "video", name: "Video Recorder", icon: "video.fill", color: .red,
         description: "Record video clips from glasses"),
    Tool(id: "memory", name: "Memory Capture", icon: "brain.head.profile", color: .purple,
         description: "Snap a moment and send to OpenClaw"),
]

struct HomeView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var isRegistered = false
    @State private var hasChecked = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Connection banner
                HStack(spacing: 8) {
                    Circle()
                        .fill(isRegistered ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(isRegistered ? "Glasses connected" : "No glasses paired")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !isRegistered && hasChecked {
                        Button("Pair") {
                            Task { try? await Wearables.shared.startRegistration() }
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                // Tools grid
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 16),
                        GridItem(.flexible(), spacing: 16)
                    ], spacing: 16) {
                        ForEach(tools) { tool in
                            NavigationLink(value: tool.id) {
                                ToolCard(tool: tool)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Ray-Ban Playground")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .navigationDestination(for: String.self) { toolId in
                switch toolId {
                case "facetag":
                    FaceTagView()
                case "video":
                    VideoRecorderView()
                case "memory":
                    MemoryCaptureView()
                default:
                    Text("Unknown tool")
                }
            }
            .task {
                for await devices in Wearables.shared.devicesStream() {
                    isRegistered = !devices.isEmpty
                    hasChecked = true
                    break
                }
            }
            .onOpenURL { url in
                Task {
                    try? await Wearables.shared.handleUrl(url)
                    isRegistered = true
                }
            }
        }
    }
}

struct ToolCard: View {
    let tool: Tool

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: tool.icon)
                .font(.system(size: 36))
                .foregroundStyle(tool.color)
                .frame(height: 44)

            Text(tool.name)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(tool.description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
