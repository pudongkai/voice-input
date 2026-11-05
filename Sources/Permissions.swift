import AVFoundation
import Cocoa
import Speech

enum Permissions {
    static var microphoneGranted: Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    static var speechGranted: Bool {
        SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    static var accessibilityGranted: Bool {
        AXIsProcessTrusted()
    }

    static func requestMicrophone() {
        guard AVCaptureDevice.authorizationStatus(for: .audio) == .notDetermined else { return }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            Log.write("microphone access granted=\(granted)")
        }
    }

    static func requestSpeech() {
        guard SFSpeechRecognizer.authorizationStatus() == .notDetermined else { return }
        SFSpeechRecognizer.requestAuthorization { status in
            Log.write("speech authorization status=\(status.rawValue)")
        }
    }

    static func promptAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openMicrophoneSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")
    }

    static func openSpeechSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition")
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    /// 语音识别要求系统的「听写」或「Siri」至少开启一个，两者的开关都记在这个偏好域里。
    static var dictationEnabled: Bool {
        let defaults = UserDefaults(suiteName: "com.apple.assistant.support")
        return defaults?.bool(forKey: "Dictation Enabled") == true
            || defaults?.bool(forKey: "Assistant Enabled") == true
    }

    /// 系统设置 → 键盘，「听写」开关在这一页。
    static func openDictationSettings() {
        open("x-apple.systempreferences:com.apple.Keyboard-Settings.extension")
    }

    /// 系统「Siri」和「听写」都关闭时，语音识别会直接拒绝请求。
    static func isDictationDisabledError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == "kLSRErrorDomain" && nsError.code == 201 { return true }
        return nsError.localizedDescription.contains("Dictation are disabled")
    }

    private static func open(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}
