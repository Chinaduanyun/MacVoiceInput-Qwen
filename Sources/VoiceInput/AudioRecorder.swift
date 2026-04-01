import AVFoundation

protocol AudioRecorderDelegate: AnyObject {
    func audioRecorder(_ recorder: AudioRecorder, didReceiveAudio pcm16Data: Data, rms: Float)
}

final class AudioRecorder: NSObject {
    weak var delegate: AudioRecorderDelegate?

    private var audioEngine: AVAudioEngine?

    func startRecording() {
        // Stop any previous engine first
        stopRecording()

        let engine = AVAudioEngine()
        audioEngine = engine

        let inputNode = engine.inputNode
        let hwFormat = inputNode.outputFormat(forBus: 0)
        let hwRate = hwFormat.sampleRate

        print("[AudioRecorder] Hardware format: \(hwRate) Hz, channels: \(hwFormat.channelCount)")

        // Validate format
        guard hwRate > 0, hwFormat.channelCount > 0 else {
            print("[AudioRecorder] ERROR: Invalid audio format (sampleRate=\(hwRate)). Microphone permission may be denied.")
            return
        }

        let decimationFactor = max(1, Int(hwRate / 16000.0))  // e.g. 48000/16000 = 3
        print("[AudioRecorder] Decimation factor: \(decimationFactor)")

        // Remove any stale tap before installing new one
        inputNode.removeTap(onBus: 0)

        // Tap at the hardware's native format — no resampling in the engine
        inputNode.installTap(onBus: 0, bufferSize: 4800, format: hwFormat) { [weak self] buffer, _ in
            guard let self = self else { return }
            guard let channelData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            guard frameLength > 0 else { return }

            // Downsample by picking every Nth sample (48000→16000 = every 3rd)
            let outLength = frameLength / decimationFactor
            guard outLength > 0 else { return }

            var rmsSum: Float = 0
            var int16Buffer = [Int16](repeating: 0, count: outLength)

            for i in 0..<outLength {
                let sample = channelData[i * decimationFactor]
                rmsSum += sample * sample
                let clamped = max(-1.0, min(1.0, sample))
                int16Buffer[i] = Int16(clamped * 32767.0)
            }

            let rms = sqrt(rmsSum / Float(outLength))
            let pcmData = Data(bytes: int16Buffer, count: outLength * 2)
            self.delegate?.audioRecorder(self, didReceiveAudio: pcmData, rms: rms)
        }

        do {
            try engine.start()
            print("[AudioRecorder] Engine started successfully")
        } catch {
            print("[AudioRecorder] Failed to start audio engine: \(error)")
        }
    }

    func stopRecording() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        print("[AudioRecorder] Stopped")
    }
}
