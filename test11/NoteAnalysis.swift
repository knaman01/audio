//
//  NoteAnalysis.swift
//  test11
//
//  Created by Naman Kalkhuria on 21/02/25.
//
import SwiftUI
import AudioKit
import AVFoundation
import AudioKitEX
import SoundpipeAudioKit 



class NoteAnalysis: ObservableObject {
    @Published var waveformSamples: [Float] = []
    @Published var isWaveformReady = false

    let engine = AudioEngine()
    var audioPlayer: AudioPlayer?
    var audioRecorder: AVAudioRecorder?
    var audioSession: AVAudioSession = AVAudioSession.sharedInstance()
    
    @Published var isAnalyzing = false
    @Published var isRecording = false
    @Published var recordedFileURL: URL?
    
    @Published var isUkulele = false
    
    private var lastProcessTime: Date = Date()
    private var noteBuffer: [String: Int] = [:]  // Track note occurrences
    
    private var micMixer: Mixer?
    private var pitchTap: PitchTap?
    
    @Published var tuningData: (cents: Double, noteName: String, isInTune: Bool) = (0, "Press Record", false)
    
    private var oscillator: Oscillator?
    private var oscillatorMixer: Mixer?
    
    private var lastPlaybackTime: Date = Date()
    
    
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
        oscillator?.stop()
        
        guard let input = engine.input else {
            print("Audio input not available")
            return
        }
        
        // Create mixer and connect input
        micMixer = Mixer(input)
        oscillatorMixer = Mixer()
        
        // Create and configure oscillator
        oscillator = Oscillator()
        if let osc = oscillator {
            oscillatorMixer = Mixer(osc)
            oscillatorMixer?.volume = 0.5
        }
        
        // Safely unwrap mixers before creating main mixer
        guard let mic = micMixer, let osc = oscillatorMixer else {
            print("Failed to create mixers")
            return
        }
        
        let mainMixer = Mixer(mic, osc)
        engine.output = mainMixer
        
        micMixer?.volume = 0.0
        
        // Setup pitch tracking
        pitchTap = PitchTap(input) { pitch, amplitude in
            DispatchQueue.main.async {
                self.processPitch([pitch[0], amplitude[0]])
            }
        }
    }
    
    func startRecording() {
        pitchTap?.stop()
        engine.stop()

        // Add a small delay to ensure cleanup
        Thread.sleep(forTimeInterval: 0.1)
        
        // Setup new audio engine
        

        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("recording.m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            print ("starting the recording")
            audioRecorder = try AVAudioRecorder(url: fileURL, settings: settings)
            audioRecorder?.record()
            
            // Start real-time analysis
            try engine.start()
            pitchTap?.start()   
            
            isRecording = true
            recordedFileURL = fileURL
        } catch {
            print("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        pitchTap?.stop()
        engine.stop()
        isRecording = false
        
        loadRecordedFile()
    }
    
    private func processPitch(_ pitch: [Float]) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessTime) > 0.1 else { return }
        lastProcessTime = now
        
        guard let freq = pitch.first, freq > 0,
              pitch.count >= 2 else { return }
        
        let amplitude = pitch[1]
        let noiseThreshold: Float = 0.1
        
        if amplitude > noiseThreshold {
            // Define both instrument tunings
            let guitarStrings = [
                ("E2", 82.41),
                ("A2", 110.0),
                ("D3", 146.83),
                ("G3", 196.0),
                ("B3", 246.94),
                ("E4", 329.63)
            ]
            
            let ukuleleStrings = [
                ("G4", 392.0),
                ("C4", 261.63),
                ("E4", 329.63),
                ("A4", 440.0)
            ]
            
            // Choose the appropriate tuning based on instrument selection
            let instrumentStrings = isUkulele ? ukuleleStrings : guitarStrings
            
            // Find the closest string
            var closestString = instrumentStrings[0]
            var minDifference = abs(freq - Float(instrumentStrings[0].1))
            
            for string in instrumentStrings {
                let difference = abs(freq - Float(string.1))
                if difference < minDifference {
                    minDifference = difference
                    closestString = string
                }
            }
            
            
            
            // Calculate cents difference (100 cents = 1 semitone)
            let cents = 1200 * log2(Double(freq) / closestString.1)
            
            print("Frequency: \(freq)Hz, Closest string: \(closestString.0), Cents off: \(cents)")
            
            // Calculate cents difference
            let isInTune = abs(cents) < 5
            
            if isInTune {
                // Replace the direct playReferenceNote call with debounced version
                if now.timeIntervalSince(lastPlaybackTime) >= 2.0 {
                    playReferenceNote(frequency: closestString.1)
                    lastPlaybackTime = now
                }
            }


            // Update tuning data
            DispatchQueue.main.async {
                self.tuningData = (cents, closestString.0, isInTune)
            }
        }
    }
    
    private func loadRecordedFile() {
        guard let fileURL = recordedFileURL else { return }
        
        do {
            let audioFile = try AVAudioFile(forReading: fileURL)
            audioPlayer = AudioPlayer(file: audioFile)
            
            
            
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
    
    func playReferenceNote(frequency: Double) {
        oscillator?.frequency = AUValue(frequency)
        oscillator?.start()
        
        // Stop the note after 1 second
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.oscillator?.stop()
        }
    }
    
}


