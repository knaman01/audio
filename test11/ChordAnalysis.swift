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
    @Published var detectedChord: String = "Press Record"
    @Published var recordedFileURL: URL?
    
    private var lastProcessTime: Date = Date()
    private var noteBuffer: [String: Int] = [:]  // Track note occurrences
    
    private var micMixer: Mixer?
    private var pitchTap: PitchTap?
    
    init() {
        setupAudioSession()
        setupAudioEngine()
    }
    
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers])
            try audioSession.setActive(true)
        } catch {
            print("Failed to set up audio session: \(error.localizedDescription)")
        }
    }
    
    private func setupAudioEngine() {
        // Stop existing connections
        pitchTap?.stop()
        engine.stop()
        
        guard let input = engine.input else {
            print("Audio input not available")
            return
        }
        
        // Create mixer and connect input
        micMixer = Mixer(input)
        engine.output = micMixer
        micMixer?.volume = 0.0
        
        // Setup pitch tracking
        pitchTap = PitchTap(input) { pitch, amplitude in
            DispatchQueue.main.async {
                self.processPitch([pitch[0], amplitude[0]])
            }
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
            
            // Start real-time analysis
            try engine.start()
            pitchTap?.start()
            
            isRecording = true
            recordedFileURL = fileURL
            detectedNotes.removeAll()
            detectedChord = "Recording..."
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        pitchTap?.stop()
        engine.stop()
        isRecording = false
        
        if detectedNotes.isEmpty {
            detectedChord = "No notes detected"
        }
        
        loadRecordedFile()
    }
    
    private func processPitch(_ pitch: [Float]) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > 0.1 else { return }
        lastProcessTime = now
        
        guard let freq = pitch.first, freq > 0,
              pitch.count >= 2 else { return }
        
        let amplitude = pitch[1]
        let noiseThreshold: Float = 0.02
        
        if amplitude > noiseThreshold {
            let note = frequencyToNoteName(freq)
            let noteWithoutOctave = String(note.prefix(while: { !$0.isNumber }))
            
            // Add to detected notes if it's not already there
            if !detectedNotes.contains(noteWithoutOctave) {
                detectedNotes.append(noteWithoutOctave)
                
                // Update the detected chord text
                if !detectedNotes.isEmpty {
                    detectedChord = "Notes: \(detectedNotes.joined(separator: ", "))"
                }
                
                print("Detected note: \(noteWithoutOctave) (freq: \(freq)Hz)")
            }
        }
    }
    
    private func loadRecordedFile() {
        guard let fileURL = recordedFileURL else { return }
        
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            audioPlayer = AudioPlayer(file: audioFile)
            
            // Reset the engine before setting up playback
            engine.stop()
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
            
            // Add noise threshold
            let noiseThreshold: Float = 0.01  // Adjust this value as needed
            
            for i in stride(from: 0, to: frameLength, by: samplingRate) {
                let sample = abs(floatData[i])
                
                
                // Only add samples that are above the noise threshold
                if sample > noiseThreshold {
                    samples.append(sample)
                } else {
                    samples.append(0)  // Set noise to zero
                }
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
    
    private func frequencyToNoteName(_ frequency: Float) -> String {

        // A4 = 440Hz, which is 69 semitones above C0
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        
        // Use the formula: n = 12 * log2(f/440) + 69
        // This gives us the MIDI note number
        let midiNoteNumber = 12.0 * log2(Double(frequency) / 440.0) + 69.0
        
        // Round to nearest note
        let roundedNote = Int(round(midiNoteNumber))
        
        // Get the note name (0-11)
        let noteIndex = ((roundedNote % 12) + 12) % 12
        
        // Add octave number for debugging
        let octave = (roundedNote / 12) - 1
        return "\(noteNames[noteIndex])\(octave)"  // Including octave number temporarily
    }
    
    func analyzeRecording() {
        // This method can be removed or kept for analyzing recorded audio
        // Since we're now doing real-time analysis
        guard let player = audioPlayer else {
            print("Audio player not initialized.")
            return
        }
        
        isAnalyzing = true
        detectedNotes.removeAll()
        
        do {
            try engine.start()
            player.play()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                self.engine.stop()
                self.isAnalyzing = false
            }
        } catch {
            print("Audio engine start error: \(error.localizedDescription)")
        }
    }
}
