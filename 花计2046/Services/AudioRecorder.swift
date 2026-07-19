import Foundation
import Combine
import AVFoundation
import Speech

class AudioRecorder: NSObject, ObservableObject, SFSpeechRecognizerDelegate {
    private var audioEngine: AVAudioEngine?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh-CN"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    @Published var isRecording = false
    @Published var recordingURL: URL?
    @Published var transcribedText = ""

    override init() {
        super.init()
        speechRecognizer.delegate = self
        Log.info("AudioRecorder 初始化 locale=zh-CN available=\(speechRecognizer.isAvailable)")
    }

    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                Log.info("语音权限状态: \(status.rawValue)")
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Log.info("麦克风权限: \(granted)")
                    continuation.resume(returning: granted && status == .authorized)
                }
            }
        }
    }

    func startRecording() {
        transcribedText = ""
        Log.info("开始录音...")

        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try session.setActive(true)
            Log.info("AudioSession 激活成功")

            audioEngine = AVAudioEngine()
            guard let inputNode = audioEngine?.inputNode else {
                Log.error("无法获取音频输入节点")
                return
            }
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            Log.info("录音格式: \(recordingFormat)")

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else {
                Log.error("无法创建识别请求")
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.taskHint = .dictation

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                if let error = error {
                    Log.error("语音识别错误: \(error.localizedDescription)")
                    return
                }
                if let result = result {
                    // 使用 segments 重建文本以保留原始数字精度
                    // formattedString 可能会对数字进行四舍五入（如42.58→42.5）
                    let text = self?.buildFullPrecisionText(from: result) ?? result.bestTranscription.formattedString
                    DispatchQueue.main.async {
                        self?.transcribedText = text
                    }
                    Log.debug("语音识别中间结果: \"\(text.prefix(60))\"")
                }
            }

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine?.prepare()
            try audioEngine?.start()
            Log.info("音频引擎启动成功")

            DispatchQueue.main.async {
                self.isRecording = true
                self.recordingURL = nil
            }
        } catch {
            Log.error("录音启动失败: \(error.localizedDescription)")
        }
    }

    func stopRecording() {
        Log.info("停止录音")
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        try? AVAudioSession.sharedInstance().setActive(false)

        DispatchQueue.main.async {
            self.isRecording = false
        }
    }

    /// 使用 segments 拼接文本，保留原始数字精度（不四舍五入）
    private func buildFullPrecisionText(from result: SFSpeechRecognitionResult) -> String {
        let segments = result.bestTranscription.segments
        // 用所有 segment 的 substring 拼接，保留原始语音识别的完整文字
        let fullText = segments.map { $0.substring }.joined()
        return fullText
    }
}
