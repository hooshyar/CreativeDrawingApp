//
//  SoundManager.swift
//  CreativeDrawing
//
//  Manages sound effects and audio feedback for a delightful experience
//

import AVFoundation
import UIKit

class SoundManager {

    static let shared = SoundManager()

    private var audioPlayers: [String: AVAudioPlayer] = [:]
    private var isSoundEnabled: Bool = true

    /// Sound effect types
    enum SoundEffect: String {
        case tap = "tap"
        case draw = "draw"
        case colorSelect = "color_select"
        case brushSelect = "brush_select"
        case undo = "undo"
        case redo = "redo"
        case clear = "clear"
        case save = "save"
        case success = "success"
        case celebration = "celebration"
        case sparkle = "sparkle"
        case pop = "pop"
    }

    private init() {
        setupAudioSession()
    }

    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to setup audio session: \(error)")
        }
    }

    /// Play a sound effect
    func play(_ effect: SoundEffect) {
        guard isSoundEnabled else { return }

        // For now, use system sounds as placeholders
        // In production, load custom sound files
        playSystemSound(for: effect)
    }

    private func playSystemSound(for effect: SoundEffect) {
        // Map effects to system sounds
        let soundID: SystemSoundID

        switch effect {
        case .tap, .colorSelect, .brushSelect:
            soundID = 1104 // Tap sound
        case .draw:
            return // No sound during drawing
        case .undo, .redo:
            soundID = 1155 // Swoosh
        case .clear:
            soundID = 1156 // Trash
        case .save, .success:
            soundID = 1057 // Success
        case .celebration:
            soundID = 1025 // Fanfare-ish
        case .sparkle:
            soundID = 1103 // Sparkle-ish
        case .pop:
            soundID = 1104 // Pop
        }

        AudioServicesPlaySystemSound(soundID)
    }

    /// Toggle sound on/off
    func toggleSound() -> Bool {
        isSoundEnabled.toggle()
        return isSoundEnabled
    }

    /// Check if sound is enabled
    var soundEnabled: Bool {
        return isSoundEnabled
    }

    /// Play haptic feedback
    func playHaptic(_ style: HapticStyle) {
        switch style {
        case .light:
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        case .medium:
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.impactOccurred()
        case .heavy:
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
        case .success:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        case .warning:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.warning)
        case .error:
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.error)
        case .selection:
            let generator = UISelectionFeedbackGenerator()
            generator.selectionChanged()
        }
    }

    enum HapticStyle {
        case light
        case medium
        case heavy
        case success
        case warning
        case error
        case selection
    }
}
