import AVFoundation
import Foundation
import Speech

/// 一次录音 + 识别会话。每次按下快捷键创建一个新实例。
final class SpeechSession {
    var onPartial: ((String) -> Void)?
    var onFinish: ((Result<String, Error>) -> Void)?

    private let config: Config
    private let engine = AVAudioEngine()
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var tapInstalled = false
    private var bestText = ""
    private var finished = false
    private var isStopping = false
    private var stopTimeout: DispatchWorkItem?
    private var maxTimer: Timer?

    init(config: Config) {
        self.config = config
    }

    func start() throws {
        guard Permissions.speechGranted else {
            throw VoiceError.message(L("没有语音识别权限，请在系统设置中授权后重试", "Speech recognition is not allowed. Grant access in System Settings and try again."))
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: config.locale)) else {
            throw VoiceError.message(L("系统不支持语言 \(config.locale)", "Language \(config.locale) is not supported by the system"))
        }
        guard recognizer.isAvailable else {
            throw VoiceError.message(L("语音识别服务暂不可用，请稍后再试", "Speech recognition is unavailable right now. Please try again later."))
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        request.contextualStrings = config.contextualStrings
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }
        if config.onDeviceRecognition, recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw VoiceError.message(L("无法访问麦克风，请检查系统权限和输入设备", "Can't access the microphone. Check permissions and the input device."))
        }

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }
        tapInstalled = true

        engine.prepare()
        do {
            try engine.start()
        } catch {
            removeTapIfNeeded()
            throw VoiceError.message(L("启动录音失败：", "Failed to start recording: ") + error.localizedDescription)
        }

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            DispatchQueue.main.async {
                self.handle(result: result, error: error)
            }
        }

        maxTimer = Timer.scheduledTimer(withTimeInterval: config.maxRecordingSeconds, repeats: false) { [weak self] _ in
            self?.stop()
        }

        Log.write("session started locale=\(config.locale) onDevice=\(request.requiresOnDeviceRecognition)")
    }

    func stop() {
        guard !finished, !isStopping else { return }
        isStopping = true
        maxTimer?.invalidate()
        maxTimer = nil

        engine.stop()
        removeTapIfNeeded()
        request?.endAudio()

        // 等最终识别结果；超时后使用最后一次部分结果。
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.finished else { return }
            self.finish(.success(self.bestText))
        }
        stopTimeout = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0, execute: work)
    }

    func cancel() {
        guard !finished else { return }
        finished = true
        stopTimeout?.cancel()
        maxTimer?.invalidate()
        maxTimer = nil
        task?.cancel()
        engine.stop()
        removeTapIfNeeded()
        request?.endAudio()
        request = nil
        task = nil
        Log.write("session cancelled")
    }

    private func handle(result: SFSpeechRecognitionResult?, error: Error?) {
        if let result {
            let text = result.bestTranscription.formattedString
            if !text.isEmpty {
                bestText = text
                onPartial?(text)
            }
            if result.isFinal {
                finish(.success(text.isEmpty ? bestText : text))
                return
            }
        }

        if let error {
            if isStopping {
                // endAudio 之后出现取消类错误是正常现象，交给超时逻辑收尾。
                return
            }
            if finished { return }
            Log.write("recognition error: \(error.localizedDescription)")
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<String, Error>) {
        guard !finished else { return }
        finished = true
        stopTimeout?.cancel()
        maxTimer?.invalidate()
        maxTimer = nil
        engine.stop()
        removeTapIfNeeded()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil

        switch result {
        case .success(let text):
            Log.write("session finished chars=\(text.count)")
        case .failure(let error):
            Log.write("session failed: \(error.localizedDescription)")
        }
        onFinish?(result)
    }

    private func removeTapIfNeeded() {
        guard tapInstalled else { return }
        tapInstalled = false
        engine.inputNode.removeTap(onBus: 0)
    }
}
