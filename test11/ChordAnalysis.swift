//
//  ChordAnalysis.swift
//  test11
//
//  Created by Naman Kalkhuria on 21/02/25.
//
import SwiftUI
import AudioKit
import AVFoundation




class ChordAnalysis: ObservableObject {
    @Published var waveformSamples: [Float] = []
    @Published var isWaveformReady = false

    let engine = AudioEngine()
    var audioPlayer: AudioPlayer?
    var audioRecorder: AVAudioRecorder?
    var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    @Published var isAnalyzing = false
    @Published var isRecording = false
    @Published var detectedNotes: [String] = []
    @Published var detectedChord: String = "Press Analyze"
    @Published var recordedFileURL: URL?
    
    private func loadRecordedFile() {
        guard let fileURL = recordedFileURL else { return }
        
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            audioPlayer = AudioPlayer(file: audioFile)
            engine.output = audioPlayer
            
            // Add waveform processing
            processWaveform(audioFile)
        } catch {
            print("Error loading recorded file: \(error.localizedDescription)")
        }
    }

    private func processWaveform(_ audioFile: AVAudioFile) {
        let format = audioFile.processingFormat
        let frameCount = UInt32(audioFile.length)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return }
        
        do {
            try audioFile.read(into: buffer)
            
            // Get the raw audio data
            guard let floatData = buffer.floatChannelData?[0] else { return }
            let frameLength = Int(buffer.frameLength)
            
            // We'll sample the audio data to get 100 points for the waveform
            let samplingRate = max(frameLength / 100, 1)
            var samples: [Float] = []
            
            for i in stride(from: 0, to: frameLength, by: samplingRate) {
                let sample = abs(floatData[i])
                samples.append(sample)
            }
            
            // Normalize samples to range 0...1
            if let maxSample = samples.max(), maxSample > 0 {
                samples = samples.map { $0 / maxSample }
            }
            
            DispatchQueue.main.async {
                self.waveformSamples = samples
                self.isWaveformReady = true
            }
            
        } catch {
            print("Error processing waveform: \(error.localizedDescription)")
        }
    }


    init() {
        setupAudioSession()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: .defaultToSpeaker)
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    func startRecording() {
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            isRecording = true
            recordedFileURL = fileURL
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        loadRecordedFile()
    }
    

    func analyzeRecording() {
        guard let player = audioPlayer else {
            print("Audio player not initialized.")
            return
        }
        
        isAnalyzing = true
        detectedNotes.removeAll()
        
        let tracker = PitchTap(player) { pitch, _ in
            DispatchQueue.main.async {
                self.processPitch(pitch)
            }
        }
        
        do {
            try engine.start()
            tracker.start()
            player.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                tracker.stop()
                self.engine.stop()
                self.detectedChord = self.identifyChord(from: self.detectedNotes)
                self.isAnalyzing = false
            }
        } catch {
            print("Audio engine start error: \(error.localizedDescription)")
        }
    }
    
    private func processPitch(_ pitch: [Float]) {
        guard let freq = pitch.first, freq > 0 else { return }
        
        let note = frequencyToNoteName(freq)
        
        if !detectedNotes.contains(note) {
            detectedNotes.append(note)
        }
    }
    
    private func frequencyToNoteName(_ frequency: Float) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let noteNumber = round(12 * log2(Double(frequency) / 440.0) + 69)
        let noteIndex = Int(noteNumber) % 12
        return noteNames[noteIndex]
    }
    
    private func identifyChord(from notes: [String]) -> String {
        let knownChords: [String: Set<String>] = [
            "C Major": ["C", "E", "G"],
            "G Major": ["G", "B", "D"],
            "D Major": ["D", "F#", "A"],
            "A Minor": ["A", "C", "E"]
        ]
        
        for (chord, chordNotes) in knownChords {
            if chordNotes.isSubset(of: Set(notes)) {
                return chord
            }
        }
        return "Unknown Chord"
    }
}
