import SwiftUI
import AudioKit
import AVFoundation

struct WaveformView: View {
    let samples: [Float]
    let color: Color
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let middle = height / 2
                
                // Start at the left edge
                path.move(to: CGPoint(x: 0, y: middle))
                
                // Draw a point for each sample
                for (index, sample) in samples.enumerated() {
                    let x = width * CGFloat(index) / CGFloat(samples.count - 1)
                    let y = middle - (CGFloat(sample) * middle)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                // Mirror the waveform to the bottom
                for (index, sample) in samples.enumerated().reversed() {
                    let x = width * CGFloat(index) / CGFloat(samples.count - 1)
                    let y = middle + (CGFloat(sample) * middle)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                
                path.closeSubpath()
            }
            .fill(color)
        }
    }
}



struct ContentView: View {
    @StateObject private var chordAnalysis = ChordAnalysis()
    
    var body: some View {
        VStack {
            if chordAnalysis.isWaveformReady {
                WaveformView(samples: chordAnalysis.waveformSamples, color: .blue)
                    .frame(height: 100)
                    .padding()
            }
            
            TuningMeterView(
                cents: chordAnalysis.tuningData.cents,
                noteName: chordAnalysis.tuningData.noteName,
                isInTune: chordAnalysis.tuningData.isInTune
            )
            .padding()
            
            Button(action: {
                if chordAnalysis.isRecording {
                    chordAnalysis.stopRecording()
                } else {
                    chordAnalysis.startRecording()
                }
            }) {
                Text(chordAnalysis.isRecording ? "Stop Recording" : "Start Recording")
                    .padding()
                    .background(chordAnalysis.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

struct ChordDetectorApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

