import SwiftUI
import AudioKit
import AVFoundation



struct ContentView: View {
    @StateObject var chordAnalysis = ChordAnalysis()
    
    var body: some View {
        VStack {
            Text("Detected Chord: \(chordAnalysis.detectedChord)")
                .font(.largeTitle)
                .padding()
            
            Text("Detected Notes: \(chordAnalysis.detectedNotes.joined(separator: ", "))")
                .padding()
            
            Button(chordAnalysis.isRecording ? "Stop Recording" : "Start Recording") {
                if chordAnalysis.isRecording {
                    chordAnalysis.stopRecording()
                } else {
                    chordAnalysis.startRecording()
                }
            }
            .padding()
            
            Button("Analyze Recorded Audio") {
                chordAnalysis.analyzeRecording()
            }
            .disabled(chordAnalysis.isAnalyzing || chordAnalysis.recordedFileURL == nil)
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

