import Foundation
import UIKit

struct OpenClawClient {
    let baseURL: String
    let gatewayPassword: String
    let hooksToken: String

    struct ResponsesResult: Decodable {
        struct Output: Decodable {
            struct Content: Decodable {
                let text: String?
            }
            let content: [Content]?
        }
        let output: [Output]?
    }

    /// Send an image + prompt via /v1/responses (Open Responses API with vision).
    /// Returns the assistant's response text.
    func sendMemory(image: UIImage, prompt: String) async throws -> String {
        guard let url = URL(string: "\(baseURL)/v1/responses") else {
            throw URLError(.badURL)
        }

        guard let jpegData = image.jpegData(compressionQuality: 0.6) else {
            throw NSError(domain: "OpenClaw", code: -1,
                          userInfo: [NSLocalizedDescriptionKey: "Failed to encode image"])
        }
        let base64 = jpegData.base64EncodedString()

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(gatewayPassword)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        let body: [String: Any] = [
            "model": "openclaw:main",
            "input": [
                [
                    "type": "message",
                    "role": "user",
                    "content": [
                        ["type": "input_text", "text": prompt],
                        ["type": "input_image", "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]]
                    ]
                ]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "OpenClaw", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "HTTP \(statusCode)"])
        }

        let result = try JSONDecoder().decode(ResponsesResult.self, from: data)
        let text = result.output?.first?.content?.first?.text
        return text ?? "No response"
    }

    /// Fire-and-forget text message via webhook.
    func notify(message: String, channel: String = "telegram", to: String) async throws {
        guard let url = URL(string: "\(baseURL)/hooks/agent") else {
            throw URLError(.badURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(hooksToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "message": message,
            "name": "FaceTag",
            "deliver": true,
            "channel": channel,
            "to": to
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "OpenClaw", code: statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "Webhook failed: HTTP \(statusCode)"])
        }
    }
}
