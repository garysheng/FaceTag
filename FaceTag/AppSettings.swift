import Foundation
import Combine

class AppSettings: ObservableObject {
    @Published var gatewayURL: String {
        didSet { UserDefaults.standard.set(gatewayURL, forKey: "gatewayURL") }
    }
    @Published var gatewayPassword: String {
        didSet { UserDefaults.standard.set(gatewayPassword, forKey: "gatewayPassword") }
    }
    @Published var hooksToken: String {
        didSet { UserDefaults.standard.set(hooksToken, forKey: "hooksToken") }
    }
    @Published var telegramChatID: String {
        didSet { UserDefaults.standard.set(telegramChatID, forKey: "telegramChatID") }
    }

    var isConfigured: Bool {
        !gatewayURL.isEmpty && !gatewayPassword.isEmpty && !hooksToken.isEmpty && !telegramChatID.isEmpty
    }

    init() {
        let savedURL = UserDefaults.standard.string(forKey: "gatewayURL") ?? ""
        let savedPwd = UserDefaults.standard.string(forKey: "gatewayPassword") ?? ""
        let savedToken = UserDefaults.standard.string(forKey: "hooksToken") ?? ""
        let savedChat = UserDefaults.standard.string(forKey: "telegramChatID") ?? ""

        self.gatewayURL = savedURL.isEmpty ? "https://garys-macbook-pro-2.taila359c0.ts.net" : savedURL
        self.gatewayPassword = savedPwd.isEmpty ? "2ad15dff5042f524d839a7e3f8387f8b1a139eeb92241317" : savedPwd
        self.hooksToken = savedToken.isEmpty ? "wh_openclaw_2ad15dff5042" : savedToken
        self.telegramChatID = savedChat.isEmpty ? "-5215134818" : savedChat
    }
}
