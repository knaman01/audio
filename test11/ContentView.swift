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
    @StateObject private var noteAnalysis = NoteAnalysis()
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: "guitars")
                    .font(.system(size: 24))
                    .foregroundColor(noteAnalysis.isUkulele ? .blue : .gray)
                
                Toggle("Ukulele Mode", isOn: $noteAnalysis.isUkulele)
                    .toggleStyle(SwitchToggleStyle(tint: .blue))
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .shadow(color: .gray.opacity(0.2), radius: 5, x: 0, y: 2)
            )
            .padding(.horizontal)
            
            if noteAnalysis.isWaveformReady {
                WaveformView(samples: noteAnalysis.waveformSamples, color: .blue)
                    .frame(height: 100)
                    .padding()
            }
            
            TuningMeterView(
                cents: noteAnalysis.tuningData.cents,
                noteName: noteAnalysis.tuningData.noteName,
                isInTune: noteAnalysis.tuningData.isInTune
            )
            .padding()
            
            Button(action: {
                if noteAnalysis.isRecording {
                    noteAnalysis.stopRecording()
                } else {
                    noteAnalysis.startRecording()
                }
            }) {
                Text(noteAnalysis.isRecording ? "Stop Recording" : "Start Recording")
                    .padding()
                    .background(noteAnalysis.isRecording ? Color.red : Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}

