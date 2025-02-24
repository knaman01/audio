import SwiftUI

struct TuningMeterView: View {
    let cents: Double
    let noteName: String
    let isInTune: Bool
    
    // Threshold for considering a note "in tune" (in cents)
    private let inTuneThreshold: Double = 5.0
    // Maximum cents to show on the meter
    private let maxCents: Double = 50.0
    
    var body: some View {
        VStack {
            // Note name
            Text(noteName)
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(isInTune ? .green : .primary)
            
            // Tuning meter
            HStack {
                // Left meter (for flat notes)
                GeometryReader { geometry in
                    ZStack(alignment: .trailing) {
                        // Background
                        Rectangle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: geometry.size.width)
                        
                        // Filled portion
                        Rectangle()
                            .fill(.red.opacity(0.7))
                            .frame(width: getMeterWidth(cents: cents, isLeft: true))
                    }
                }
                .frame(width: 145, height: 20)
                
                // Center line
                Rectangle()
                    .fill(isInTune ? .green : .gray)
                    .frame(width: 4, height: 40)
                
                // Right meter (for sharp notes)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        Rectangle()
                            .fill(.gray.opacity(0.3))
                            .frame(width: geometry.size.width)
                        
                        // Filled portion
                        Rectangle()
                            .fill(.red.opacity(0.7))
                            .frame(width: getMeterWidth(cents: cents, isLeft: false))
                    }
                }
                .frame(width: 145, height: 20)
            }
            .frame(width: 300)
            
            // Cents display
            if !isInTune {
                Text("\(abs(cents), specifier: "%.1f") cents \(cents < 0 ? "flat" : "sharp")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func getMeterWidth(cents: Double, isLeft: Bool) -> CGFloat {
        let absCents = abs(cents)
        
        // If perfectly in tune, no fill
        if absCents < inTuneThreshold {
            return 0
        }
        
        // If this is the opposite side of the deviation, no fill
        if (isLeft && cents > 0) || (!isLeft && cents < 0) {
            return 0
        }
        
        // Calculate width based on how far the note is from being in tune
        let width = (absCents / maxCents) * 145
        return min(max(width, 0), 145)
    }
    
    // Add this new function to calculate color
    private func getColorForSide(cents: Double, isLeft: Bool) -> Color {
        let absCents = abs(cents)
        
        // If note is perfectly in tune, both sides are grey
        if absCents < inTuneThreshold {
            return .gray.opacity(0.3)
        }
        
        // Calculate opacity based on how far the note is from being in tune
        let opacity = min(max(absCents / maxCents, 0.3), 0.7)
        
        // Return grey if this is the opposite side of the deviation
        if (isLeft && cents > 0) || (!isLeft && cents < 0) {
            return .gray.opacity(0.3)
        }
        
        // Return red with calculated opacity for the side that's out of tune
        return .red.opacity(opacity)
    }
} 