import Foundation
import SwiftUI
#if os(iOS)
import UIKit
#endif
import AudioToolbox
import AVFoundation

struct RootAura: Identifiable, Hashable {
    let id: Int
    let name: String
    let pitchClass: Int
    let circleIndex: Int
    let color: Color
}

struct EnemyType: Identifiable, Hashable {
    let id: String
    let label: String
    let circle: String
    let intervalName: String
    let semitoneOffset: Int
    let assetName: String
    let baseDamage: ClosedRange<Int>
}

struct EnemyState: Identifiable, Hashable {
    let id = UUID()
    let type: EnemyType
    var aura: RootAura
    var hp: Int
}

struct SpawnCombo: Hashable {
    let type: EnemyType
    let aura: RootAura

    var statKey: String {
        "\(aura.id)_\(type.id)"
    }
}

struct ComboPerformance: Codable {
    var attempts: Int
    var correct: Int
    var totalResponseTime: Double
    var misses: Int

    var averageResponseTime: Double {
        guard correct > 0 else { return 2.5 }
        return totalResponseTime / Double(correct)
    }

    var difficultyScore: Double {
        // Higher = harder for the player.
        averageResponseTime + Double(misses) * 0.35
    }
}


struct AnswerTimingStat: Codable, Hashable {
    static let initialValue: Double = 4.0
    static let smoothingFactor: Double = 0.5
    static let minimumRecordedResponseTime: Double = 0.5

    var value: Double
    var count: Int

    init(value: Double = AnswerTimingStat.initialValue, count: Int = 0) {
        self.value = value
        self.count = count
    }

    mutating func update(responseTime: Double, correct: Bool) {
        // 早すぎる誤タップは記録に入れない。ミスは+1.0して苦手として残す。
        guard responseTime > AnswerTimingStat.minimumRecordedResponseTime else { return }
        let adjusted = max(0.0, responseTime) + (correct ? 0.0 : 1.0)
        value = value * (1.0 - AnswerTimingStat.smoothingFactor) + adjusted * AnswerTimingStat.smoothingFactor
        count += 1
    }
}

struct WeaknessRecord: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let value: Double
    let count: Int
    let accentIndex: Int
    let imageName: String?
}

enum AppScreen: Equatable {
    case title
    case prologue
    case storyEvent
    case map
    case mapDetail
    case areaDetail
    case customize
    case silentTraining
    case archive
    case battle
}

enum BattleMode: String {
    case training = "稽古"
    case dungeon = "攻略"
    case multi = "複数オーラ"
    case finalNormal = "無音の核"
    case finalTrue = "無音の核・最奥"
}

enum BattleResult: String {
    case ready = "READY"
    case correct = "調律"
    case miss = "MISS"
    case enemyAttack = "被弾"
    case heal = "回復"
    case skill = "技"
    case clear = "CLEAR"
    case defeat = "DEFEAT"
}

struct BattleConfig: Hashable {
    let id: String
    let title: String
    let mode: BattleMode
    let allowedAuraIDs: [Int]
    let targetDefeatCount: Int
    let playerMaxHP: Int
    let playerMaxMP: Int
    let attackDuration: TimeInterval
    let enemyHP: Int
    let training: Bool
    let story: String
    let skillsEnabled: Bool
    let traitsEnabled: Bool
    let enemyAttacks: Bool

    init(
        id: String,
        title: String,
        mode: BattleMode,
        allowedAuraIDs: [Int],
        targetDefeatCount: Int,
        playerMaxHP: Int,
        playerMaxMP: Int,
        attackDuration: TimeInterval,
        enemyHP: Int,
        training: Bool,
        story: String,
        skillsEnabled: Bool = true,
        traitsEnabled: Bool = true,
        enemyAttacks: Bool = true
    ) {
        self.id = id
        self.title = title
        self.mode = mode
        self.allowedAuraIDs = allowedAuraIDs
        self.targetDefeatCount = targetDefeatCount
        self.playerMaxHP = playerMaxHP
        self.playerMaxMP = playerMaxMP
        self.attackDuration = attackDuration
        self.enemyHP = enemyHP
        self.training = training
        self.story = story
        self.skillsEnabled = skillsEnabled
        self.traitsEnabled = traitsEnabled
        self.enemyAttacks = enemyAttacks
    }
}

struct MultiAuraDungeon: Identifiable, Hashable {
    let id: String
    let title: String
    let auraIDs: [Int]
    let tier: Int
    let angleIndex: Double
    let lore: String
}

struct GemSkillSpec: Identifiable, Hashable {
    let id: String
    let dungeonID: String
    let gemName: String
    let skillName: String
    let shortEffect: String
    let upgradeEffect: String
    let category: String
    let colorName: String
    let maxLevel: Int = 5
}

enum SoundPlayer {
    static func play(_ id: SystemSoundID) {
        AudioServicesPlaySystemSound(id)
    }

    static func correct() { play(1057) }
    static func miss() { play(1053) }
    static func attack() {
        TonePlayer.shared.playSoftHit()
        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.prepare()
        generator.impactOccurred(intensity: 0.45)
        #endif
    }
    static func skill() { play(1104) }
    static func heal() { play(1022) }
    static func clear() { play(1025) }
    static func defeat() { play(1024) }
}


final class TonePlayer {
    static let shared = TonePlayer()

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var previewSequenceID = UUID()
    private let sampleRate: Double = 44100.0
    private let format: AVAudioFormat

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func playAura(pitchClass: Int) {
        // C3-B3 range. This is intentionally lower than the keyboard sound.
        play(midiNotes: [48 + pitchClass], duration: 0.38, volume: 0.18)
    }

    func playDyad(rootPitchClass: Int, keyPitchClass: Int) {
        // Root aura = lower octave, tapped key = upper octave.
        play(midiNotes: [48 + rootPitchClass, 60 + keyPitchClass], duration: 0.48, volume: 0.20)
    }

    func playSoftHit() {
        // 控えめだが無音にならない、短い被弾音。低すぎる音は端末スピーカーで消えやすいため少し上に寄せる。
        play(midiNotes: [52, 58], duration: 0.14, volume: 0.115)
    }

    func playArchiveInterval(rootPitchClass: Int, semitoneOffset: Int) {
        let root = normalizedPitchClass(rootPitchClass)
        let target = normalizedPitchClass(rootPitchClass + semitoneOffset)
        previewSequenceID = UUID()
        player.stop()
        play(midiNotes: [48 + root, 60 + target], duration: 0.72, volume: 0.18)
    }

    func playArchiveHarmony(rootPitchClass: Int, offsets: [Int], isScale: Bool) {
        let root = normalizedPitchClass(rootPitchClass)
        let normalizedOffsets = uniqueNormalizedOffsets(offsets)
        previewSequenceID = UUID()
        let sequenceID = previewSequenceID
        player.stop()

        if isScale {
            playArchiveScale(rootPitchClass: root, offsets: normalizedOffsets, sequenceID: sequenceID)
        } else {
            let notes = archiveChordVoicing(rootPitchClass: root, offsets: normalizedOffsets)
            play(midiNotes: notes, duration: 1.08, volume: 0.16)
        }
    }

    private func playArchiveScale(rootPitchClass: Int, offsets: [Int], sequenceID: UUID) {
        let orderedOffsets = offsets.sorted()
        let notes = ([0] + orderedOffsets.filter { $0 != 0 } + [12])
            .map { 60 + rootPitchClass + $0 }

        for (index, midi) in notes.enumerated() {
            let delay = Double(index) * 0.115
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let self, self.previewSequenceID == sequenceID else { return }
                self.play(midiNotes: [midi], duration: 0.18, volume: 0.14)
            }
        }
    }

    private func archiveChordVoicing(rootPitchClass: Int, offsets: [Int]) -> [Int] {
        let bass = 48 + rootPitchClass
        var midis: [Int] = [bass]

        for offset in offsets where offset != 0 {
            let pitchClass = normalizedPitchClass(rootPitchClass + offset)
            let base: Int
            switch offset {
            case 1, 2:
                // ♭9 / 9 are placed high so the tension color is heard on top.
                base = 72
            case 5:
                // 4 is low for sus chords, high when mixed with seventh/altered colors.
                base = offsets.contains(10) || offsets.contains(11) ? 72 : 60
            case 8, 9:
                // ♭13 / 13 are upper colors when a seventh is present.
                base = offsets.contains(10) || offsets.contains(11) ? 72 : 60
            case 6, 10, 11:
                base = 60
            default:
                base = 60
            }

            var midi = base + pitchClass
            while midi <= bass + 4 {
                midi += 12
            }
            midis.append(midi)
        }

        return Array(Set(midis)).sorted()
    }

    private func uniqueNormalizedOffsets(_ offsets: [Int]) -> [Int] {
        var seen: Set<Int> = []
        var result: [Int] = []
        for offset in offsets {
            let normalized = normalizedPitchClass(offset)
            if !seen.contains(normalized) {
                seen.insert(normalized)
                result.append(normalized)
            }
        }
        return result
    }

    private func normalizedPitchClass(_ value: Int) -> Int {
        ((value % 12) + 12) % 12
    }

    private func play(midiNotes: [Int], duration: Double, volume: Float) {
        guard !midiNotes.isEmpty else { return }

        if !engine.isRunning {
            try? engine.start()
        }

        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount

        guard let channel = buffer.floatChannelData?[0] else {
            return
        }

        let fadeFrames = max(1, Int(sampleRate * 0.018))
        let totalFrames = Int(frameCount)
        let twoPi = 2.0 * Double.pi

        for frame in 0..<totalFrames {
            let t = Double(frame) / sampleRate
            var sample = 0.0

            for midi in midiNotes {
                let frequency = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
                sample += sin(twoPi * frequency * t)
            }

            sample /= Double(midiNotes.count)

            let envelope: Double
            if frame < fadeFrames {
                envelope = Double(frame) / Double(fadeFrames)
            } else if totalFrames - frame < fadeFrames {
                envelope = Double(totalFrames - frame) / Double(fadeFrames)
            } else {
                envelope = 1.0
            }

            channel[frame] = Float(sample) * volume * Float(envelope)
        }

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)

        if !player.isPlaying {
            player.play()
        }
    }
}

enum GeneratedBGMMode: Equatable {
    case map
    case event
    case battle
    case silentCore
}

struct GeneratedBGMContext: Equatable {
    let mode: GeneratedBGMMode
    let rootPitchClass: Int
    let tension: Double
    let density: Double
}

/// 音声ファイルを使わず、根へ戻る感覚を邪魔しない小音量の背景音を生成する管理クラス。
/// 2拍・1小節・2小節・4小節・8小節のモチーフ単位を持ち、リズムと高低の形が再帰しやすいように重み付けする。
final class GeneratedBGMManager {
    static let shared = GeneratedBGMManager()

    private struct BGMMotifSlot {
        let bassOffset: Int?
        let firstUpperOffset: Int?
        let secondUpperOffset: Int?
        let restBias: Double
        let lengthRatioBias: Double
    }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate: Double = 44100.0
    private let format: AVAudioFormat
    private var context: GeneratedBGMContext?
    private var previousPitchClass: Int?
    private var previousChordPitchClasses: [Int] = []
    private var previousChordTension: Double = 0.0
    private var generationID = UUID()
    private var nextWorkItem: DispatchWorkItem?
    private let enabledKey = "IntervalRouteMVP.generatedBGMEnabled.v1"
    private var isEnabled: Bool

    private var beatsPerMeasure = 4
    private var beatIndex = 0
    private var measureIndex = 0
    private var motifSlots: [BGMMotifSlot] = []
    private var motifPeriodBeats = 16

    private init() {
        isEnabled = UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true
        format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!

        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        try? engine.start()
    }

    func play(mode: GeneratedBGMMode, rootPitchClass: Int, tension: Double, density: Double) {
        guard isEnabled else { return }

        let newContext = GeneratedBGMContext(
            mode: mode,
            rootPitchClass: normalizedPitchClass(rootPitchClass),
            tension: min(max(tension, 0.0), 1.0),
            density: min(max(density, 0.0), 1.0)
        )

        if context == newContext, player.isPlaying {
            return
        }

        context = newContext
        previousPitchClass = nil
        previousChordPitchClasses = []
        previousChordTension = 0.0
        beatsPerMeasure = chooseMeter(for: newContext)
        beatIndex = 0
        measureIndex = 0
        rebuildMotif(for: newContext)
        generationID = UUID()
        nextWorkItem?.cancel()
        player.stop()

        if !engine.isRunning {
            try? engine.start()
        }

        scheduleNext(after: 0.08, generationID: generationID)
    }

    func stop() {
        context = nil
        previousPitchClass = nil
        previousChordPitchClasses = []
        previousChordTension = 0.0
        motifSlots = []
        generationID = UUID()
        nextWorkItem?.cancel()
        nextWorkItem = nil
        player.stop()
    }

    func setEnabled(_ enabled: Bool) {
        isEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: enabledKey)
        if !enabled {
            stop()
        }
    }

    private func scheduleNext(after delay: TimeInterval, generationID: UUID) {
        nextWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.step(generationID: generationID)
        }
        nextWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
    }

    private func step(generationID: UUID) {
        guard generationID == self.generationID, let context else { return }
        guard isEnabled else { return }

        if motifSlots.isEmpty {
            rebuildMotif(for: context)
        }

        let globalBeat = currentGlobalBeat
        if globalBeat > 0 && globalBeat % max(beatsPerMeasure * 8, motifPeriodBeats) == 0 && beatIndex == 0 {
            rebuildMotif(for: context)
        }

        let motif = motifSlot(forGlobalBeat: globalBeat)
        let beatSeconds = beatLength(for: context)
        let phraseMeasure = measureIndex % 4
        let shouldRest = Double.random(in: 0...1) < restProbability(for: context, beatIndex: beatIndex, phraseMeasure: phraseMeasure, motif: motif)

        if !shouldRest {
            let chord = chooseChord(for: context, beatIndex: beatIndex, phraseMeasure: phraseMeasure, motif: motif)
            previousChordPitchClasses = chord
            previousChordTension = chordTension(chord, root: context.rootPitchClass)
            previousPitchClass = chord.last ?? context.rootPitchClass
            playGeneratedChord(
                pitchClasses: chord,
                duration: beatSeconds * noteLengthRatio(for: context, beatIndex: beatIndex, phraseMeasure: phraseMeasure, motif: motif),
                volume: volume(for: context),
                baseMidi: baseMidi(for: context)
            )
        } else if previousChordTension > 0.55 {
            previousPitchClass = context.rootPitchClass
            previousChordTension *= 0.55
        }

        advanceBeat()
        scheduleNext(after: beatSeconds, generationID: generationID)
    }

    private var currentGlobalBeat: Int {
        measureIndex * beatsPerMeasure + beatIndex
    }

    private func advanceBeat() {
        beatIndex += 1
        if beatIndex >= beatsPerMeasure {
            beatIndex = 0
            measureIndex += 1
        }
    }

    private func chooseMeter(for context: GeneratedBGMContext) -> Int {
        switch context.mode {
        case .event:
            return Double.random(in: 0...1) < 0.38 ? 3 : 4
        case .silentCore:
            return 4
        case .map, .battle:
            return 4
        }
    }

    private func rebuildMotif(for context: GeneratedBGMContext) {
        motifPeriodBeats = chooseMotifPeriodBeats(for: context)
        motifSlots = (0..<motifPeriodBeats).map { index in
            let beat = index % beatsPerMeasure
            let measure = index / beatsPerMeasure
            let strongBeat = beat == 0
            let phraseStart = strongBeat && measure % 4 == 0
            let phraseEnd = strongBeat && measure % 4 == 3

            let bassOffset = chooseMotifBassOffset(for: context, strongBeat: strongBeat, phraseStart: phraseStart, phraseEnd: phraseEnd)
            let upper1 = chooseMotifUpperOffset(for: context, strongBeat: strongBeat, phraseEnd: phraseEnd, slot: 1)
            let upper2 = chooseMotifUpperOffset(for: context, strongBeat: strongBeat, phraseEnd: phraseEnd, slot: 2)

            let baseRest: Double
            switch context.mode {
            case .map:
                baseRest = strongBeat ? 0.02 : 0.18
            case .battle:
                baseRest = strongBeat ? 0.08 : 0.30
            case .event:
                baseRest = strongBeat ? 0.10 : 0.27
            case .silentCore:
                baseRest = strongBeat ? 0.34 : 0.70
            }

            let lengthBias: Double = phraseStart || phraseEnd ? 0.18 : strongBeat ? 0.08 : -0.06

            return BGMMotifSlot(
                bassOffset: bassOffset,
                firstUpperOffset: upper1,
                secondUpperOffset: upper2,
                restBias: baseRest,
                lengthRatioBias: lengthBias
            )
        }
    }

    private func chooseMotifPeriodBeats(for context: GeneratedBGMContext) -> Int {
        let oneMeasure = beatsPerMeasure
        let choices: [(Int, Double)] = [
            (2, context.mode == .battle ? 18 : 10),
            (oneMeasure, 26),
            (oneMeasure * 2, 24),
            (oneMeasure * 4, context.mode == .silentCore ? 16 : 30),
            (oneMeasure * 8, context.mode == .map ? 20 : 12)
        ]
        return weightedRandom(choices, fallback: oneMeasure * 4)
    }

    private func chooseMotifBassOffset(for context: GeneratedBGMContext, strongBeat: Bool, phraseStart: Bool, phraseEnd: Bool) -> Int? {
        var choices: [(Int?, Double)] = []
        func add(_ offset: Int?, _ weight: Double) { choices.append((offset, max(0, weight))) }

        add(0, phraseStart ? 80 : strongBeat ? 54 : 24)
        add(7, phraseEnd ? 54 : strongBeat ? 24 : 18)
        add(5, 12)
        add(2, 10)
        add(9, 8)

        switch context.mode {
        case .map:
            add(4, 8)
        case .battle:
            add(3, 8)
            add(10, 6)
            add(6, context.tension * 4)
        case .event:
            add(3, 12)
            add(10, 10)
            add(1, 4 + context.tension * 6)
            add(6, 4 + context.tension * 8)
        case .silentCore:
            add(nil, 20)
            add(1, 8)
            add(6, 10)
        }

        return weightedRandom(choices, fallback: 0)
    }

    private func chooseMotifUpperOffset(for context: GeneratedBGMContext, strongBeat: Bool, phraseEnd: Bool, slot: Int) -> Int? {
        var choices: [(Int?, Double)] = []
        func add(_ offset: Int?, _ weight: Double) { choices.append((offset, max(0, weight))) }

        let nilWeight = slot == 2 ? 50.0 : 24.0
        add(nil, nilWeight)
        add(7, phraseEnd ? 34 : 22)
        add(0, phraseEnd ? 26 : 12)
        add(5, 12)
        add(2, 14)
        add(9, 10)

        switch context.mode {
        case .map:
            add(4, 12)
            add(3, 6)
            add(10, 5)
        case .battle:
            add(3, 8)
            add(10, 8)
            add(4, 4)
            add(6, context.tension * 4)
        case .event:
            add(3, 12)
            add(10, 12)
            add(1, 4 + context.tension * 5)
            add(6, 5 + context.tension * 7)
        case .silentCore:
            add(nil, 30)
            add(1, 6)
            add(6, 8)
        }

        if strongBeat {
            add(7, 8)
        }

        return weightedRandom(choices, fallback: nil)
    }

    private func motifSlot(forGlobalBeat globalBeat: Int) -> BGMMotifSlot {
        guard !motifSlots.isEmpty else {
            return BGMMotifSlot(bassOffset: 0, firstUpperOffset: nil, secondUpperOffset: nil, restBias: 0.0, lengthRatioBias: 0.0)
        }
        return motifSlots[globalBeat % motifSlots.count]
    }

    private func chooseChord(for context: GeneratedBGMContext, beatIndex: Int, phraseMeasure: Int, motif: BGMMotifSlot) -> [Int] {
        let root = context.rootPitchClass
        let bass = chooseBassPitchClass(for: context, beatIndex: beatIndex, phraseMeasure: phraseMeasure, motif: motif)
        var chord: [Int] = [bass]

        let secondProbability = upperNoteProbability(for: context, beatIndex: beatIndex, phraseMeasure: phraseMeasure, slot: 1, motif: motif)
        let thirdProbability = upperNoteProbability(for: context, beatIndex: beatIndex, phraseMeasure: phraseMeasure, slot: 2, motif: motif)

        if Double.random(in: 0...1) < secondProbability {
            chord.append(chooseUpperPitchClass(for: context, bass: bass, beatIndex: beatIndex, phraseMeasure: phraseMeasure, slot: 1, motif: motif))
        }

        if Double.random(in: 0...1) < thirdProbability {
            let next = chooseUpperPitchClass(for: context, bass: bass, beatIndex: beatIndex, phraseMeasure: phraseMeasure, slot: 2, motif: motif)
            if !chord.contains(next) || Double.random(in: 0...1) < 0.25 {
                chord.append(next)
            }
        }

        if beatIndex == 0 && phraseMeasure == 3 && previousChordTension > 0.42 {
            chord = [root, normalizedPitchClass(root + 7)]
        }

        return Array(chord.prefix(3))
    }

    private func chooseBassPitchClass(for context: GeneratedBGMContext, beatIndex: Int, phraseMeasure: Int, motif: BGMMotifSlot) -> Int {
        let root = context.rootPitchClass
        var weighted: [(Int, Double)] = []

        func add(_ offset: Int, _ weight: Double) {
            weighted.append((normalizedPitchClass(root + offset), max(0.0, weight)))
        }

        let strongBeat = beatIndex == 0
        let phraseStart = strongBeat && phraseMeasure == 0
        let phraseEnd = strongBeat && phraseMeasure == 3

        switch context.mode {
        case .map:
            add(0, phraseStart ? 82 : strongBeat ? 62 : 30)
            add(7, phraseEnd ? 46 : 26)
            add(5, 14)
            add(2, strongBeat ? 10 : 16)
            add(9, 8)
        case .battle:
            add(0, phraseStart ? 86 : strongBeat ? 66 : 32)
            add(7, phraseEnd ? 42 : 24)
            add(5, 10)
            add(3, 8)
            add(10, 7)
            add(6, strongBeat ? 1 + context.tension * 3 : context.tension * 4)
        case .event:
            add(0, phraseStart ? 72 : strongBeat ? 54 : 22)
            add(7, phraseEnd ? 30 : 18)
            add(5, 9)
            add(3, 12)
            add(10, 12)
            add(1, 5 + context.tension * 7)
            add(6, 5 + context.tension * 9)
        case .silentCore:
            add(0, phraseStart ? 72 : 44)
            add(7, phraseEnd ? 18 : 8)
            add(1, 9)
            add(6, 12)
            add(10, 7)
        }

        if let motifOffset = motif.bassOffset {
            add(motifOffset, strongBeat ? 54 : 34)
        }

        if previousChordTension > 0.5 {
            add(0, 42)
            add(7, 18)
        }

        if let previousPitchClass {
            let distance = circleDistance(previousPitchClass, root)
            if distance >= 4 {
                add(0, 28)
                add(7, 12)
            } else if previousPitchClass == root && !strongBeat {
                add(2, 8)
                add(5, 6)
                add(7, 8)
            }
        }

        return weightedRandom(weighted, fallback: root)
    }

    private func chooseUpperPitchClass(for context: GeneratedBGMContext, bass: Int, beatIndex: Int, phraseMeasure: Int, slot: Int, motif: BGMMotifSlot) -> Int {
        let root = context.rootPitchClass
        var weighted: [(Int, Double)] = []

        func add(_ offset: Int, _ weight: Double) {
            weighted.append((normalizedPitchClass(root + offset), max(0.0, weight)))
        }

        let strongBeat = beatIndex == 0
        let phraseEnd = strongBeat && phraseMeasure == 3
        let returnBias = previousChordTension > 0.48 || phraseEnd

        add(0, returnBias ? 40 : strongBeat ? 22 : 12)
        add(7, returnBias ? 30 : 22)
        add(5, 13)
        add(2, 12)
        add(9, 10)

        switch context.mode {
        case .map:
            add(4, 11)
            add(3, 7)
            add(10, 6)
        case .battle:
            add(3, 9)
            add(10, 8)
            add(4, 5)
            add(6, 2 + context.tension * 4)
        case .event:
            add(3, 12)
            add(10, 12)
            add(1, 4 + context.tension * 5)
            add(6, 5 + context.tension * 7)
            add(8, 5)
        case .silentCore:
            add(1, 7)
            add(6, 9)
            add(10, 7)
        }

        if slot == 1, let motifOffset = motif.firstUpperOffset {
            add(motifOffset, strongBeat ? 36 : 26)
        }
        if slot == 2, let motifOffset = motif.secondUpperOffset {
            add(motifOffset, strongBeat ? 28 : 20)
        }

        if slot == 2 {
            add(7, 6)
            add(0, 4)
        }

        let selected = weightedRandom(weighted, fallback: normalizedPitchClass(root + 7))
        if selected == bass && slot == 1 {
            return normalizedPitchClass(root + 7)
        }
        return selected
    }

    private func upperNoteProbability(for context: GeneratedBGMContext, beatIndex: Int, phraseMeasure: Int, slot: Int, motif: BGMMotifSlot) -> Double {
        let strongBeat = beatIndex == 0
        let phraseBoundary = strongBeat && (phraseMeasure == 0 || phraseMeasure == 3)
        let motifHasNote = slot == 1 ? motif.firstUpperOffset != nil : motif.secondUpperOffset != nil
        let motifBoost = motifHasNote ? 0.12 : -0.10

        let base: Double
        switch (context.mode, slot) {
        case (.map, 1):
            base = phraseBoundary ? 0.62 : strongBeat ? 0.52 : 0.28
        case (.map, 2):
            base = phraseBoundary ? 0.24 : 0.12
        case (.battle, 1):
            base = phraseBoundary ? 0.34 : strongBeat ? 0.24 : 0.10
        case (.battle, 2):
            base = phraseBoundary ? 0.10 : 0.04
        case (.event, 1):
            base = phraseBoundary ? 0.48 : strongBeat ? 0.34 : 0.16
        case (.event, 2):
            base = phraseBoundary ? 0.16 : 0.07
        case (.silentCore, 1):
            base = phraseBoundary ? 0.20 : 0.06
        case (.silentCore, 2):
            base = 0.02
        default:
            base = 0.0
        }
        return min(0.95, max(0.0, base + motifBoost))
    }

    private func restProbability(for context: GeneratedBGMContext, beatIndex: Int, phraseMeasure: Int, motif: BGMMotifSlot) -> Double {
        let strongBeat = beatIndex == 0
        let phraseBoundary = strongBeat && (phraseMeasure == 0 || phraseMeasure == 3)
        let densityRest = (1.0 - context.density) * 0.14

        let base: Double
        switch context.mode {
        case .map:
            base = phraseBoundary ? 0.04 : strongBeat ? 0.12 : 0.46 + densityRest
        case .battle:
            base = phraseBoundary ? 0.16 : strongBeat ? 0.26 : 0.70 + context.tension * 0.06
        case .event:
            base = phraseBoundary ? 0.14 : strongBeat ? 0.26 : 0.62 + context.tension * 0.08
        case .silentCore:
            base = phraseBoundary ? 0.54 : 0.92
        }

        return min(0.98, max(0.0, base + motif.restBias * 0.35))
    }

    private func noteLengthRatio(for context: GeneratedBGMContext, beatIndex: Int, phraseMeasure: Int, motif: BGMMotifSlot) -> Double {
        let strongBeat = beatIndex == 0
        let phraseBoundary = strongBeat && (phraseMeasure == 0 || phraseMeasure == 3)

        let base: Double
        switch context.mode {
        case .map:
            base = phraseBoundary ? 0.86 : strongBeat ? 0.76 : 0.58
        case .battle:
            base = phraseBoundary ? 0.66 : strongBeat ? 0.56 : 0.42
        case .event:
            base = phraseBoundary ? 0.82 : strongBeat ? 0.72 : 0.52
        case .silentCore:
            base = phraseBoundary ? 0.90 : 0.55
        }

        return min(0.94, max(0.20, base + motif.lengthRatioBias))
    }

    private func beatLength(for context: GeneratedBGMContext) -> Double {
        switch context.mode {
        case .map:
            return 0.72
        case .battle:
            return 0.66
        case .event:
            return beatsPerMeasure == 3 ? 0.86 : 0.82
        case .silentCore:
            return 1.08
        }
    }

    private func volume(for context: GeneratedBGMContext) -> Float {
        switch context.mode {
        case .map:
            return 0.026
        case .battle:
            return 0.011
        case .event:
            return 0.019
        case .silentCore:
            return 0.008
        }
    }

    private func baseMidi(for context: GeneratedBGMContext) -> Int {
        switch context.mode {
        case .map:
            return 43
        case .battle:
            return 36
        case .event:
            return 38
        case .silentCore:
            return 34
        }
    }

    private func chordTension(_ chord: [Int], root: Int) -> Double {
        var tension = 0.0
        for pitch in chord {
            switch normalizedPitchClass(pitch - root) {
            case 0, 7:
                tension += 0.02
            case 5, 2, 9:
                tension += 0.12
            case 3, 4, 10:
                tension += 0.24
            case 1, 6, 11:
                tension += 0.42
            default:
                tension += 0.20
            }
        }
        return min(1.0, tension / Double(max(1, chord.count)))
    }

    private func playGeneratedChord(pitchClasses: [Int], duration: Double, volume: Float, baseMidi: Int) {
        if !engine.isRunning {
            try? engine.start()
        }

        let normalized = pitchClasses.map { normalizedPitchClass($0) }
        let frameCount = AVAudioFrameCount(sampleRate * max(0.05, duration))
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return
        }

        buffer.frameLength = frameCount
        guard let channel = buffer.floatChannelData?[0] else { return }

        let totalFrames = Int(frameCount)
        let attackFrames = max(1, Int(sampleRate * 0.028))
        let releaseFrames = max(1, Int(sampleRate * 0.16))
        let twoPi = 2.0 * Double.pi
        let midis = midiNotes(for: normalized, baseMidi: baseMidi)
        let count = max(1, midis.count)

        for frame in 0..<totalFrames {
            let t = Double(frame) / sampleRate
            var mixed = 0.0

            for (index, midi) in midis.enumerated() {
                let frequency = 440.0 * pow(2.0, (Double(midi) - 69.0) / 12.0)
                let weight = index == 0 ? 0.82 : 0.42
                let fundamental = sin(twoPi * frequency * t)
                let second = sin(twoPi * frequency * 2.0 * t) * 0.10
                let third = sin(twoPi * frequency * 3.0 * t) * 0.035
                mixed += (fundamental + second + third) * weight
            }

            let attack: Double = frame < attackFrames ? Double(frame) / Double(attackFrames) : 1.0
            let release: Double = totalFrames - frame < releaseFrames ? Double(max(0, totalFrames - frame)) / Double(releaseFrames) : 1.0
            let decay = 0.82 + 0.18 * exp(-t * 1.5)
            let envelope = min(attack, release) * decay
            let gain = Double(volume) / Double(count)

            channel[frame] = Float(mixed * gain * envelope)
        }

        player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        if !player.isPlaying {
            player.play()
        }
    }

    private func midiNotes(for pitchClasses: [Int], baseMidi: Int) -> [Int] {
        guard !pitchClasses.isEmpty else { return [baseMidi] }
        let bass = baseMidi + pitchClasses[0]
        var notes: [Int] = [bass]
        for (index, pitchClass) in pitchClasses.dropFirst().enumerated() {
            var midi = baseMidi + 12 + pitchClass + index * 5
            while midi <= bass + 3 {
                midi += 12
            }
            notes.append(midi)
        }
        return notes
    }

    private func weightedRandom<T>(_ choices: [(T, Double)], fallback: T) -> T {
        let total = choices.reduce(0.0) { $0 + max(0.0, $1.1) }
        guard total > 0 else { return fallback }

        var value = Double.random(in: 0..<total)
        for (item, weight) in choices {
            value -= max(0.0, weight)
            if value <= 0 {
                return item
            }
        }

        return fallback
    }

    private func normalizedPitchClass(_ value: Int) -> Int {
        let result = value % 12
        return result >= 0 ? result : result + 12
    }

    private func circleDistance(_ a: Int, _ b: Int) -> Int {
        let diff = abs(normalizedPitchClass(a) - normalizedPitchClass(b))
        return min(diff, 12 - diff)
    }
}

final class GameModel: ObservableObject {
    let rootAuras: [RootAura] = [
        RootAura(id: 0,  name: "C",  pitchClass: 0,  circleIndex: 0,  color: .red),
        RootAura(id: 7,  name: "G",  pitchClass: 7,  circleIndex: 1,  color: .blue),
        RootAura(id: 2,  name: "D",  pitchClass: 2,  circleIndex: 2,  color: .orange),
        RootAura(id: 9,  name: "A",  pitchClass: 9,  circleIndex: 3,  color: .purple),
        RootAura(id: 4,  name: "E",  pitchClass: 4,  circleIndex: 4,  color: .green),
        RootAura(id: 11, name: "B",  pitchClass: 11, circleIndex: 5,  color: .gray),
        RootAura(id: 6,  name: "G♭", pitchClass: 6,  circleIndex: 6,  color: .cyan),
        RootAura(id: 1,  name: "D♭", pitchClass: 1,  circleIndex: 7,  color: .pink),
        RootAura(id: 8,  name: "A♭", pitchClass: 8,  circleIndex: 8,  color: .indigo),
        RootAura(id: 3,  name: "E♭", pitchClass: 3,  circleIndex: 9,  color: .yellow),
        RootAura(id: 10, name: "B♭", pitchClass: 10, circleIndex: 10, color: .brown),
        RootAura(id: 5,  name: "F",  pitchClass: 5,  circleIndex: 11, color: .mint)
    ]

    let enemyTypes: [EnemyType] = [
        EnemyType(id: "enemy_2_minus", label: "2−", circle: "-5", intervalName: "minor 2nd", semitoneOffset: 1,  assetName: "enemy_2_minus", baseDamage: 14...22),
        EnemyType(id: "enemy_2_plus",  label: "2+", circle: "+2", intervalName: "major 2nd", semitoneOffset: 2,  assetName: "enemy_2_plus", baseDamage: 8...14),
        EnemyType(id: "enemy_3_minus", label: "3−", circle: "-3", intervalName: "minor 3rd", semitoneOffset: 3,  assetName: "enemy_3_minus", baseDamage: 10...16),
        EnemyType(id: "enemy_3_plus",  label: "3+", circle: "+4", intervalName: "major 3rd", semitoneOffset: 4,  assetName: "enemy_3_plus", baseDamage: 8...13),
        EnemyType(id: "enemy_4",       label: "4",  circle: "-1", intervalName: "perfect 4th", semitoneOffset: 5,  assetName: "enemy_4", baseDamage: 7...12),
        EnemyType(id: "enemy_tritone", label: "◆", circle: "±6", intervalName: "tritone", semitoneOffset: 6, assetName: "enemy_tritone", baseDamage: 16...26),
        EnemyType(id: "enemy_5",       label: "5",  circle: "+1", intervalName: "perfect 5th", semitoneOffset: 7,  assetName: "enemy_5", baseDamage: 7...12),
        EnemyType(id: "enemy_6_minus", label: "6−", circle: "-4", intervalName: "minor 6th", semitoneOffset: 8,  assetName: "enemy_6_minus", baseDamage: 10...17),
        EnemyType(id: "enemy_6_plus",  label: "6+", circle: "+3", intervalName: "major 6th", semitoneOffset: 9,  assetName: "enemy_6_plus", baseDamage: 8...14),
        EnemyType(id: "enemy_7_minus", label: "7−", circle: "-2", intervalName: "minor 7th", semitoneOffset: 10, assetName: "enemy_7_minus", baseDamage: 11...18),
        EnemyType(id: "enemy_7_plus",  label: "7+", circle: "+5", intervalName: "major 7th", semitoneOffset: 11, assetName: "enemy_7_plus", baseDamage: 14...22)
]

    func enemyType(forSemitoneOffset offset: Int) -> EnemyType? {
        let normalized = ((offset % 12) + 12) % 12
        guard normalized != 0 else { return nil }
        return enemyTypes.first { ((($0.semitoneOffset % 12) + 12) % 12) == normalized }
    }

    let multiAuraDungeons: [MultiAuraDungeon] = [
        // 2-aura ring: adjacent areas on the circle of fifths
        MultiAuraDungeon(id: "pair_0", title: "二音灯窟 C/G", auraIDs: [0, 7], tier: 2, angleIndex: 0.5, lore: "灯火港の奥、Cの赤い灯がGの青風へ流れ込む浅い洞。二つの根を聞き分ける最初の境目。"),
        MultiAuraDungeon(id: "pair_1", title: "風砂の細道 G/D", auraIDs: [7, 2], tier: 2, angleIndex: 1.5, lore: "風見街の風がDの砂鐘へ抜ける細道。軽い根と乾いた根が交互に揺れる。"),
        MultiAuraDungeon(id: "pair_2", title: "砂雷の裂け目 D/A", auraIDs: [2, 9], tier: 2, angleIndex: 2.5, lore: "砂鐘の台地に紫雷が落ちて開いた裂け目。判断の遅れがそのまま敵の拍になる。"),
        MultiAuraDungeon(id: "pair_3", title: "紫翠の水脈 A/E", auraIDs: [9, 4], tier: 2, angleIndex: 3.5, lore: "紫の稲光が翠の水路に反射する地下水脈。見える色と鳴る根が食い違う。"),
        MultiAuraDungeon(id: "pair_4", title: "翠灰の廃路 E/B", auraIDs: [4, 11], tier: 2, angleIndex: 4.5, lore: "翠庭から灰塔へ続く古い廃路。穏やかな響きの裏で硬いBが待つ。"),
        MultiAuraDungeon(id: "pair_5", title: "灰氷の回廊 B/G♭", auraIDs: [11, 6], tier: 2, angleIndex: 5.5, lore: "灰塔の石壁が氷鏡の冷気に侵された回廊。音の輪郭が鋭く削られる。"),
        MultiAuraDungeon(id: "pair_6", title: "氷霧の鏡穴 G♭/D♭", auraIDs: [6, 1], tier: 2, angleIndex: 6.5, lore: "氷鏡街の奥に沈む鏡穴。G♭とD♭が霧の中で何度も反射する。"),
        MultiAuraDungeon(id: "pair_7", title: "霧影の沈橋 D♭/A♭", auraIDs: [1, 8], tier: 2, angleIndex: 7.5, lore: "霧晶街から夕影街へ沈む古橋。足元の見えない道で根だけを頼りに進む。"),
        MultiAuraDungeon(id: "pair_8", title: "夕黄の庭跡 A♭/E♭", auraIDs: [8, 3], tier: 2, angleIndex: 8.5, lore: "夕影の庭と黄塵の市場跡が重なる場所。柔らかな影の中に濁った響きが混ざる。"),
        MultiAuraDungeon(id: "pair_9", title: "黄土の門 E♭/B♭", auraIDs: [3, 10], tier: 2, angleIndex: 9.5, lore: "黄塵の市場から土輪の要塞へ続く門。重い土の響きが近づいてくる。"),
        MultiAuraDungeon(id: "pair_10", title: "土水の通い路 B♭/F", auraIDs: [10, 5], tier: 2, angleIndex: 10.5, lore: "土輪街の地下水路。B♭の重さとFの流れが交互に足場を変える。"),
        MultiAuraDungeon(id: "pair_11", title: "水灯の帰路 F/C", auraIDs: [5, 0], tier: 2, angleIndex: 11.5, lore: "水響街から灯火港へ戻る帰路。始まりの根へ戻るほど、最初の意味が変わる。"),

        // 4-aura ring: overlapping groups, route selection stays flexible
        MultiAuraDungeon(id: "quad_0", title: "灯風砂雷の郭 C/G/D/A", auraIDs: [0, 7, 2, 9], tier: 4, angleIndex: 1.5, lore: "灯、風、砂、雷の四つが外郭を作る古い防衛区。速さよりも戻る場所を問われる。"),
        MultiAuraDungeon(id: "quad_1", title: "砂雷翠灰の斜坑 D/A/E/B", auraIDs: [2, 9, 4, 11], tier: 4, angleIndex: 3.5, lore: "砂の斜面に雷光と翠の水脈、灰塔の残響が交差する斜坑。"),
        MultiAuraDungeon(id: "quad_2", title: "翠灰氷霧の水殿 E/B/G♭/D♭", auraIDs: [4, 11, 6, 1], tier: 4, angleIndex: 5.5, lore: "水殿の柱に灰と氷と霧がまとわりつく。静かな景色ほど根を見失いやすい。"),
        MultiAuraDungeon(id: "quad_3", title: "氷霧夕黄の鏡庭 G♭/D♭/A♭/E♭", auraIDs: [6, 1, 8, 3], tier: 4, angleIndex: 7.5, lore: "氷と霧の鏡に夕影と黄塵が映る庭。正しい音だけが像を結ぶ。"),
        MultiAuraDungeon(id: "quad_4", title: "夕黄土水の円庭 A♭/E♭/B♭/F", auraIDs: [8, 3, 10, 5], tier: 4, angleIndex: 9.5, lore: "夕影、黄塵、土輪、水響が円を描く庭。中心へ進む覚悟を試す。"),
        MultiAuraDungeon(id: "quad_5", title: "土水灯風の外環塞 B♭/F/C/G", auraIDs: [10, 5, 0, 7], tier: 4, angleIndex: 11.5, lore: "外環の要塞跡。土と水、灯と風が混ざり、港の記憶が別の形で戻ってくる。"),

        // 6-aura inner ring
        MultiAuraDungeon(id: "six_sharp", title: "六重険路・鋭環", auraIDs: [0, 7, 2, 9, 4, 11], tier: 6, angleIndex: 2.5, lore: "灯風砂雷翠灰へ連なる険路。明るい根ほど鋭く、中心へ向かう道を細くする。"),
        MultiAuraDungeon(id: "six_flat", title: "六重険路・深環", auraIDs: [5, 10, 3, 8, 1, 6], tier: 6, angleIndex: 9.5, lore: "水土黄夕霧氷へ連なる険路。深い根ほど重く、中心へ向かう足取りを試す。")
    ]

    let gemSkills: [GemSkillSpec] = [
        GemSkillSpec(id: "distance_check", dungeonID: "aura_0", gemName: "導音の宝玉", skillName: "父の助言", shortEffect: "父の助言が早く届く", upgradeEffect: "宝玉レベルが上がるほど、助言が届くまでの時間が短くなる", category: "助言", colorName: "mint"),
        GemSkillSpec(id: "skill_interval", dungeonID: "aura_7", gemName: "霧刻の宝玉", skillName: "霧刻律", shortEffect: "技のインターバル短縮", upgradeEffect: "技の再使用までの間隔が短くなる", category: "特性", colorName: "teal"),
        GemSkillSpec(id: "slow", dungeonID: "aura_2", gemName: "緩拍の宝玉", skillName: "減速", shortEffect: "敵の拍を遅くする", upgradeEffect: "宝玉レベルが上がるほど持続時間が伸び、消費MPが下がる", category: "技", colorName: "cyan"),
        GemSkillSpec(id: "skill_rewind", dungeonID: "aura_9", gemName: "砂還の宝玉", skillName: "砂還律", shortEffect: "技使用時敵の拍を戻す", upgradeEffect: "技使用時に戻す敵の拍が増える", category: "特性", colorName: "orange"),
        GemSkillSpec(id: "heal_power", dungeonID: "aura_4", gemName: "翠癒の宝玉", skillName: "翠癒律", shortEffect: "回復量上昇", upgradeEffect: "回復技の回復量が増える", category: "特性", colorName: "green"),
        GemSkillSpec(id: "mp_regen", dungeonID: "aura_11", gemName: "泉脈の宝玉", skillName: "泉脈律", shortEffect: "MP自動回復", upgradeEffect: "5秒ごとのMP回復量が増える", category: "特性", colorName: "gray"),
        GemSkillSpec(id: "hp_regen", dungeonID: "aura_6", gemName: "息吹の宝玉", skillName: "息吹律", shortEffect: "HP自動回復", upgradeEffect: "5秒ごとのHP回復量が増える", category: "特性", colorName: "blue"),
        GemSkillSpec(id: "first_guard", dungeonID: "aura_1", gemName: "初守の宝玉", skillName: "初守律", shortEffect: "ミスするまで被ダメージ減", upgradeEffect: "戦闘開始からミスするまで被ダメージを軽減する", category: "特性", colorName: "pink"),
        GemSkillSpec(id: "tune_hp", dungeonID: "aura_8", gemName: "宵雫の宝玉", skillName: "宵雫律", shortEffect: "調律時HP回復", upgradeEffect: "正解時のHP回復量が増える", category: "特性", colorName: "indigo"),
        GemSkillSpec(id: "tune_mp", dungeonID: "aura_3", gemName: "雷脈の宝玉", skillName: "雷脈律", shortEffect: "調律時MP回復", upgradeEffect: "正解時のMP回復量が増える", category: "特性", colorName: "purple"),
        GemSkillSpec(id: "first_slow", dungeonID: "aura_10", gemName: "初拍の宝玉", skillName: "初拍律", shortEffect: "ミス/被弾するまで敵の拍を遅くする", upgradeEffect: "戦闘開始からミスまたは被弾まで敵の拍を鈍らせる", category: "特性", colorName: "brown"),
        GemSkillSpec(id: "quiet_key", dungeonID: "aura_5", gemName: "気配断ちの宝玉", skillName: "隠れる", shortEffect: "敵から隠れる", upgradeEffect: "宝玉レベルが上がるほど隠れられる時間が伸び、消費MPが下がる", category: "技", colorName: "gray"),

        GemSkillSpec(id: "heal", dungeonID: "pair_0", gemName: "癒響の宝玉", skillName: "回復", shortEffect: "HP回復", upgradeEffect: "宝玉レベルが上がるほど回復量が増え、消費MPが下がる", category: "技", colorName: "green"),
        GemSkillSpec(id: "miss_guard", dungeonID: "pair_1", gemName: "防錯の宝玉", skillName: "防錯律", shortEffect: "ミス時のダメージ軽減", upgradeEffect: "ミス時の被害を軽減する", category: "特性", colorName: "orange"),
        GemSkillSpec(id: "damage_guard", dungeonID: "pair_2", gemName: "堅護の宝玉", skillName: "堅護律", shortEffect: "被ダメージ軽減", upgradeEffect: "ミスと被弾の両方の被害を軽減する", category: "特性", colorName: "yellow"),
        GemSkillSpec(id: "hp_bonus", dungeonID: "pair_3", gemName: "堅心の宝玉", skillName: "堅心律", shortEffect: "HP上昇", upgradeEffect: "最大HPが増える", category: "特性", colorName: "green"),
        GemSkillSpec(id: "mp_bonus", dungeonID: "pair_4", gemName: "深奏の宝玉", skillName: "深奏律", shortEffect: "MP上昇", upgradeEffect: "最大MPが増える", category: "特性", colorName: "cyan"),
        GemSkillSpec(id: "global_slow", dungeonID: "pair_5", gemName: "鈍拍の宝玉", skillName: "鈍拍律", shortEffect: "敵の拍を遅くする", upgradeEffect: "敵の拍が常時わずかに遅くなる", category: "特性", colorName: "blue"),
        GemSkillSpec(id: "hit_slow", dungeonID: "pair_6", gemName: "鈍響の宝玉", skillName: "鈍響律", shortEffect: "被弾時その敵の拍を遅くする", upgradeEffect: "被弾時に敵の拍を大きく鈍らせる", category: "特性", colorName: "teal"),
        GemSkillSpec(id: "full_hp_slow", dungeonID: "pair_7", gemName: "澄拍の宝玉", skillName: "澄拍律", shortEffect: "HP99%以上で敵の拍を遅くする", upgradeEffect: "HPがほぼ満タンの時、敵の拍を鈍らせる", category: "特性", colorName: "mint"),
        GemSkillSpec(id: "hp75_slow", dungeonID: "pair_8", gemName: "薄暮の宝玉", skillName: "薄暮律", shortEffect: "HP75%以下で敵の拍を遅くする", upgradeEffect: "低HP時の敵拍減速が強くなる", category: "特性", colorName: "indigo"),
        GemSkillSpec(id: "hp50_slow", dungeonID: "pair_9", gemName: "宵闇の宝玉", skillName: "宵闇律", shortEffect: "HP50%以下で敵の拍を遅くする", upgradeEffect: "低HP時の敵拍減速が強くなる", category: "特性", colorName: "indigo"),
        GemSkillSpec(id: "hp25_slow", dungeonID: "pair_10", gemName: "影息の宝玉", skillName: "影息律", shortEffect: "HP25%以下で敵の拍を遅くする", upgradeEffect: "低HP時の敵拍減速が強くなる", category: "特性", colorName: "indigo"),
        GemSkillSpec(id: "effect_extend", dungeonID: "pair_11", gemName: "延響の宝玉", skillName: "延響律", shortEffect: "技の効果時間を長くする", upgradeEffect: "技の効果時間が延びる", category: "特性", colorName: "indigo"),

        GemSkillSpec(id: "mp_regen_risk", dungeonID: "quad_0", gemName: "荒泉の宝玉", skillName: "荒泉律", shortEffect: "MP自動回復するがミス時被害2倍", upgradeEffect: "3秒ごとのMP回復量が増える。ミス時被害2倍", category: "特性", colorName: "orange"),
        GemSkillSpec(id: "mp_bonus_risk", dungeonID: "quad_1", gemName: "過奏の宝玉", skillName: "過奏律", shortEffect: "MP上昇するがミス時被害2倍", upgradeEffect: "最大MPが大きく増える。ミス時被害2倍", category: "特性", colorName: "cyan"),
        GemSkillSpec(id: "tune_hp_risk", dungeonID: "quad_2", gemName: "血響の宝玉", skillName: "血響律", shortEffect: "調律時HP回復するがミス時被害2倍", upgradeEffect: "正解時のHP回復量が大きく増える。ミス時被害2倍", category: "特性", colorName: "red"),
        GemSkillSpec(id: "hp_bonus_risk", dungeonID: "quad_3", gemName: "剛心の宝玉", skillName: "剛心律", shortEffect: "HP上昇するがミス時被害2倍", upgradeEffect: "最大HPが大きく増える。ミス時被害2倍", category: "特性", colorName: "red"),
        GemSkillSpec(id: "tune_mp_risk", dungeonID: "quad_4", gemName: "魔響の宝玉", skillName: "魔響律", shortEffect: "調律時MP回復するがミス時被害2倍", upgradeEffect: "正解時のMP回復量が大きく増える。ミス時被害2倍", category: "特性", colorName: "purple"),
        GemSkillSpec(id: "hp_regen_risk", dungeonID: "quad_5", gemName: "荒息の宝玉", skillName: "荒息律", shortEffect: "HP自動回復するがミス時被害2倍", upgradeEffect: "3秒ごとのHP回復量が増える。ミス時被害2倍", category: "特性", colorName: "red"),

        GemSkillSpec(id: "half_hpmp_slow", dungeonID: "six_sharp", gemName: "鋭環の宝玉", skillName: "鋭環律", shortEffect: "HP・MPが半分になるが敵の拍を遅くする", upgradeEffect: "敵の拍が大きく遅くなる", category: "特性", colorName: "white"),
        GemSkillSpec(id: "deep_ring", dungeonID: "six_flat", gemName: "深環の宝玉", skillName: "深環律", shortEffect: "被ダメージが2倍になるが敵の拍を遅くする", upgradeEffect: "敵の拍が大きく遅くなる。被ダメージ2倍", category: "特性", colorName: "black")
    ]

    @Published var selectedAuraID: Int = 0
    @Published var unlockedAuraIDs: Set<Int> = [0]
    @Published var clearedDungeonAuraIDs: Set<Int> = []
    @Published var clearedMultiDungeonIDs: Set<String> = []
    var isFinalCoreClearedForView: Bool {
        clearedFinalCore
    }
    @Published var currentBattle: BattleConfig?
    @Published var currentEnemy: EnemyState?
    @Published var defeatedCount: Int = 0
    @Published var playerHP: Int = 100
    @Published var playerMP: Int = 40
    @Published var attackProgress: Double = 0
    @Published var slowUntil: Date = .distantPast
    @Published var hintCandidates: Set<Int> = []
    @Published var hintUntil: Date = .distantPast
    @Published var activeHintCandidateCount: Int?
    @Published var effectTime: Date = Date()
    @Published var slowEffectDuration: TimeInterval = 8.0
    @Published var hintEffectDuration: TimeInterval = 14.0
    @Published var auraHintUntil: Date = .distantPast
    @Published var auraHintDuration: TimeInterval = 14.0
    @Published var auraHintPressesRemaining: Int = 0
    @Published var auraHintMaxPresses: Int = 0
    @Published var distanceHintAvailableAt: Date = .distantFuture
    @Published var distanceHintExpiresAt: Date = .distantPast
    @Published var fatherAdviceIntroPending: Bool = false
    @Published var keyboardStartPitch: Int? = nil
    @Published var lastResult: BattleResult = .ready
    @Published var message: String = "Cの拠点から始めてください。"
    @Published var battleFinished: Bool = false
    @Published var battleWon: Bool = false
    @Published var finalCoreDepthText: String = ""
    @Published var finalCoreSceneText: String = ""
    @Published var finalCoreIntermissionText: String = ""
    @Published var finalCoreIntermissionActive: Bool = false
    @Published var pendingFinalCoreClearStoryEvent: Bool = false
    @Published var playerLevel: Int = 1
    @Published var levelUpText: String = ""
    @Published var levelUpDetailText: String = ""
    @Published var clearResonanceText: String = ""
    @Published var gemRewardText: String = ""
    @Published var gemRewardDetailText: String = ""
    @Published var gemLevels: [String: Int] = [:]
    @Published var equippedSkillIDs: [String] = ["distance_check"]
    @Published var equippedTraitIDs: [String] = []
    @Published var stealthUntil: Date = .distantPast
    @Published var stealthDuration: TimeInterval = 8.0
    @Published var hitSlowUntil: Date = .distantPast
    @Published var hitSlowFactor: Double = 1.0
    @Published var skillCooldownUntil: [String: Date] = [:]
    @Published var rootAnswerTiming: [String: AnswerTimingStat] = [:]
    @Published var intervalAnswerTiming: [String: AnswerTimingStat] = [:]
    @Published var pairAnswerTiming: [String: AnswerTimingStat] = [:]
    @Published var notebookRecordUnlockText: String = ""

    private var autoRegenAccumulator: TimeInterval = 0
    private var riskRegenAccumulator: TimeInterval = 0
    private var battleHadMiss: Bool = false
    private var firstSlowBroken: Bool = false

    private var enemyDeck: [SpawnCombo] = []
    private var currentEnemyStartedAt: Date = Date()
    private var comboPerformance: [String: ComboPerformance] = [:]
    private var battleResponseTotal: TimeInterval = 0
    private var battleResponseCount: Int = 0

    private let unlockedKey = "IntervalRouteMVP.unlockedAuraIDs"
    private let clearedKey = "IntervalRouteMVP.clearedDungeonAuraIDs"
    private let clearedMultiKey = "IntervalRouteMVP.clearedMultiDungeonIDs"
    private let playerLevelKey = "IntervalRouteMVP.playerLevel"
    private let clearedFinalCoreKey = "IntervalRouteMVP.clearedFinalCore"
    private let comboPerformanceKey = "IntervalRouteMVP.comboPerformance.v1"
    private let rootAnswerTimingKey = "IntervalRouteMVP.rootAnswerTiming.v1"
    private let intervalAnswerTimingKey = "IntervalRouteMVP.intervalAnswerTiming.v1"
    private let pairAnswerTimingKey = "IntervalRouteMVP.pairAnswerTiming.v1"
    private let notebookRecordIntroSeenKey = "IntervalRouteMVP.notebookRecordIntroSeen.v1"
    private let gemLevelsKey = "IntervalRouteMVP.gemLevels.v1"
    private let equippedSkillsKey = "IntervalRouteMVP.equippedSkills.v1"
    private let equippedTraitsKey = "IntervalRouteMVP.equippedTraits.v1"
    private let dataVersionKey = "IntervalRouteMVP.dataVersion"
    private let fatherAdviceIntroSeenKey = "IntervalRouteMVP.fatherAdviceIntroSeen.v1"
    private let currentDataVersion = "father_advice_no_root_sight_v1"
    private var clearedFinalCore: Bool = false
    private var notebookRecordIntroSeen: Bool = false

    init() {
        loadProgress()
        loadComboPerformance()
        loadAnswerTimingStats()
    }

    var unlockedGemCount: Int {
        gemLevels.values.filter { $0 > 0 }.count
    }

    func gemSkill(forDungeonID dungeonID: String) -> GemSkillSpec? {
        gemSkills.first { $0.dungeonID == dungeonID }
    }

    func gemLevel(for gemID: String) -> Int {
        gemLevels[gemID] ?? 0
    }

    func skillGemLevel(_ skillID: String) -> Int {
        gemLevel(for: skillID)
    }

    func isSkillUnlocked(_ skillID: String) -> Bool {
        if skillID == "distance_check" { return true }
        return skillGemLevel(skillID) > 0
    }

    private func loc(_ key: String) -> String {
        key.gameLocalized
    }

    private func localizedGemLevel(_ level: Int) -> String {
        switch GameLocalization.languageCode {
        case "en", "ko":
            return "\(loc("宝玉レベル")) \(level)"
        default:
            return "\(loc("宝玉レベル"))\(level)"
        }
    }

    private func localizedSeconds(_ value: Int) -> String {
        GameLocalization.languageCode == "en" ? "\(value)s" : "\(value)\(loc("秒"))"
    }

    func skillLockText(_ skillID: String) -> String {
        if isSkillUnlocked(skillID) { return "" }
        if let spec = skillSpec(byID: skillID) {
            return String(format: loc("%@で解放"), spec.gemName.gameLocalized)
        }
        return loc("宝玉で解放")
    }

    func isSkillEquipped(_ skillID: String) -> Bool {
        equippedSkillIDs.contains(skillID)
    }

    func canEquipSkill(_ skillID: String) -> Bool {
        isActiveBattleSkill(skillID) && isSkillUnlocked(skillID) && !isSkillEquipped(skillID) && equippedSkillIDs.count < 5
    }

    func toggleEquippedSkill(_ skillID: String) {
        guard isActiveBattleSkill(skillID), isSkillUnlocked(skillID) else { return }

        if let index = equippedSkillIDs.firstIndex(of: skillID) {
            equippedSkillIDs.remove(at: index)
        } else {
            guard canEquipSkill(skillID) else { return }
            equippedSkillIDs.append(skillID)
        }

        saveProgress()
    }

    func skillSpec(byID skillID: String) -> GemSkillSpec? {
        gemSkills.first { $0.id == skillID }
    }

    func skillColor(_ skillID: String) -> Color {
        switch skillSpec(byID: skillID)?.colorName ?? "gray" {
        case "amber": return .orange
        case "orange": return .orange
        case "mint": return .mint
        case "green": return .green
        case "cyan": return .cyan
        case "teal": return .teal
        case "blue": return .blue
        case "gray": return .gray
        case "purple": return .purple
        case "indigo": return .indigo
        case "pink": return .pink
        case "red": return .red
        case "black": return .white
        case "white": return .white
        case "yellow": return .yellow
        case "brown": return .orange
        default: return .gray
        }
    }

    func activateEquippedSkill(_ skillID: String) {
        if currentBattle?.skillsEnabled == false && skillID != "distance_check" {
            message = "技は封じられている"
            SoundPlayer.miss()
            return
        }

        guard isSkillEquipped(skillID) else {
            message = "未装着の宝玉です"
            SoundPlayer.miss()
            return
        }

        switch skillID {
        case "slow":
            useSlow()
        case "root_sight":
            useRootSight()
        case "distance_check":
            useDistanceCheck()
        case "quiet_key":
            usePresenceHide()
        case "heal":
            useHeal()
        default:
            message = "この宝玉は特性です"
            SoundPlayer.miss()
        }
    }

    func equippedSkillSpecs() -> [GemSkillSpec] {
        equippedSkillIDs.compactMap { skillSpec(byID: $0) }
    }

    func availableSkillSpecsForCustomize() -> [GemSkillSpec] {
        gemSkills.filter { isSkillUnlocked($0.id) }
    }

    func isActiveBattleSkill(_ skillID: String) -> Bool {
        switch skillID {
        case "distance_check", "slow", "quiet_key", "heal":
            return true
        default:
            return false
        }
    }

    func isTraitGem(_ skillID: String) -> Bool {
        guard skillSpec(byID: skillID) != nil else { return false }
        return !isActiveBattleSkill(skillID)
    }

    func isTraitEquipped(_ skillID: String) -> Bool {
        equippedTraitIDs.contains(skillID)
    }

    let traitEquipCostCapacity: Int = 12

    func traitEquipCost(_ skillID: String) -> Int {
        guard isTraitGem(skillID) else { return 0 }
        let base = baseTraitEquipCost(skillID)
        let level = skillGemLevel(skillID)
        if level >= 5 { return 0 }
        if level >= 4 { return max(0, base - 2) }
        if level >= 3 { return max(0, base - 1) }
        return base
    }

    func traitEquipCostUsed() -> Int {
        equippedTraitIDs.reduce(0) { $0 + traitEquipCost($1) }
    }

    func traitEquipCostRemaining() -> Int {
        max(0, traitEquipCostCapacity - traitEquipCostUsed())
    }

    func baseTraitEquipCost(_ skillID: String) -> Int {
        switch skillID {
        case "skill_rewind", "first_guard", "first_slow": return 1
        case "skill_interval", "heal_power", "hp_bonus", "mp_bonus", "global_slow", "effect_extend", "mp_bonus_risk", "hp_bonus_risk", "miss_guard", "damage_guard": return 2
        case "mp_regen", "hp_regen", "tune_hp", "tune_mp", "hit_slow", "full_hp_slow", "hp75_slow", "hp50_slow", "hp25_slow": return 3
        case "mp_regen_risk", "tune_hp_risk", "tune_mp_risk", "hp_regen_risk": return 4
        case "half_hpmp_slow", "deep_ring": return 6
        default: return 1
        }
    }

    func canEquipTrait(_ skillID: String) -> Bool {
        guard isTraitGem(skillID), skillGemLevel(skillID) > 0, !isTraitEquipped(skillID) else { return false }
        return traitEquipCostUsed() + traitEquipCost(skillID) <= traitEquipCostCapacity
    }

    func toggleEquippedTrait(_ skillID: String) {
        guard isTraitGem(skillID), skillGemLevel(skillID) > 0 else { return }

        if let index = equippedTraitIDs.firstIndex(of: skillID) {
            equippedTraitIDs.remove(at: index)
        } else {
            guard canEquipTrait(skillID) else { return }
            equippedTraitIDs.append(skillID)
        }

        saveProgress()
    }

    private func effectivePotential(_ skillID: String) -> Int {
        if skillID == "root_sight" {
            return max(1, skillGemLevel(skillID))
        }
        return max(1, skillGemLevel(skillID))
    }

    private func valueForPotential(_ skillID: String, _ values: [Int]) -> Int {
        let p = min(5, max(1, effectivePotential(skillID)))
        return values[p - 1]
    }

    private func doubleForPotential(_ skillID: String, _ values: [Double]) -> Double {
        let p = min(5, max(1, effectivePotential(skillID)))
        return values[p - 1]
    }

    func potentialStageText(_ skillID: String) -> String {
        if skillID == "distance_check" {
            let level = skillGemLevel(skillID)
            return level > 0 ? localizedGemLevel(level) : loc("初期")
        }

        let level = skillGemLevel(skillID)
        return level > 0 ? localizedGemLevel(level) : loc("未入手")
    }

    func gemRewardText(for dungeon: MultiAuraDungeon) -> String {
        guard let spec = gemSkill(forDungeonID: dungeon.id) else { return "" }
        return "\(loc("報酬")): \(spec.gemName.gameLocalized) / \(spec.skillName.gameLocalized) — \(spec.shortEffect.gameLocalized)"
    }

    func singleAuraRewardText(for aura: RootAura) -> String {
        guard let spec = gemSkill(forDungeonID: "aura_\(aura.id)") else { return "" }
        return "\(loc("報酬")): \(spec.gemName.gameLocalized) / \(spec.skillName.gameLocalized) — \(spec.shortEffect.gameLocalized)"
    }

    func finalCoreRewardText() -> String {
        ""
    }

    func rewardThresholdText(forDungeonID dungeonID: String) -> String {
        if dungeonID == "final_core" {
            return ""
        }

        guard let spec = gemSkill(forDungeonID: dungeonID) else {
            return [
                loc("宝玉レベル目安"),
                loc("4秒以内 → 宝玉レベル2"),
                loc("2秒以内 → 宝玉レベル3"),
                loc("1秒以内 → 宝玉レベル4"),
                loc("0.8秒以内 → 宝玉レベル5")
            ].joined(separator: "\n")
        }

        let level = gemLevel(for: spec.id)
        let ownedText = level > 0 ? "\(loc("所持")): \(localizedGemLevel(level))" : "\(loc("所持")): \(loc("未入手"))"

        return [
            ownedText,
            "\(loc("効果")): \(spec.shortEffect.gameLocalized)",
            loc("宝玉レベル目安"),
            loc("4秒以内 → 宝玉レベル2"),
            loc("2秒以内 → 宝玉レベル3"),
            loc("1秒以内 → 宝玉レベル4"),
            loc("0.8秒以内 → 宝玉レベル5"),
            "",
            loc("宝玉レベル別効果"),
            levelDetailLines(for: spec)
        ].joined(separator: "\n")
    }

    private func levelDetailLines(for spec: GemSkillSpec) -> String {
        potentialDetailText(spec)
            .replacingOccurrences(of: "。", with: "\n")
            .replacingOccurrences(of: "、", with: "\n")
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    func gemSourceText(_ spec: GemSkillSpec) -> String {
        if spec.id == "distance_check" {
            return "\(loc("入手")): \(loc("初期"))"
        }
        if spec.dungeonID.hasPrefix("aura_"),
           let auraID = Int(spec.dungeonID.replacingOccurrences(of: "aura_", with: "")),
           let aura = rootAuras.first(where: { $0.id == auraID }) {
            return "\(loc("入手")): \(aura.name) \(loc("近郊"))"
        }
        if let dungeon = multiAuraDungeons.first(where: { $0.id == spec.dungeonID }) {
            return "\(loc("入手")): \(dungeon.title.gameLocalized)"
        }
        if spec.dungeonID == "final_core" {
            return "\(loc("強化")): \(loc("無音の核"))"
        }
        return "\(loc("入手")): \(loc("未設定"))"
    }

    func skillOneLineText(_ spec: GemSkillSpec) -> String {
        if isActiveBattleSkill(spec.id) {
            if spec.id == "distance_check" {
                return String(format: loc("父の助言 %.1f秒後 / 消費なし / 回数制限なし"), fatherAdviceDelaySeconds())
            }
            let cost = skillCostDisplay(spec.id)
            let costText = cost == 0 ? loc("消費なし") : "MP\(cost)"
            return "\(spec.shortEffect.gameLocalized) / \(costText) / \(loc("間隔"))\(localizedSeconds(skillIntervalSeconds(spec.id)))"
        }
        return "\(traitOneLineText(spec.id)) / \(loc("コスト"))\(traitEquipCost(spec.id))"
    }

    func skillFunctionText(_ spec: GemSkillSpec) -> String {
        switch spec.id {
        case "slow":
            return "敵の攻撃ゲージ速度を45%に落とす。".gameLocalized
        case "root_sight":
            return "廃止。主人公は音を見る力を持たないため、根を表示する技は使わない。".gameLocalized
        case "distance_check":
            return String(format: loc("押してから%.1f秒後、父の助言として右/左の数え方を表示する。消費MPなし。次に答えるまで残る。"), fatherAdviceDelaySeconds())
        case "quiet_key":
            return "敵の攻撃を受けない。ただし敵の種類とオーラも見えなくなる。鍵盤を押すと解除される。".gameLocalized
        case "heal":
            return "HPを回復する。".gameLocalized
        default:
            return spec.shortEffect.gameLocalized
        }
    }

    func potentialDetailText(_ spec: GemSkillSpec) -> String {
        switch spec.id {
        case "slow":
            return "宝玉レベル1: MP8/8秒、2: MP7/10秒、3: MP6/12秒、4: MP5/14秒、5: MP4/16秒".gameLocalized
        case "root_sight":
            return "廃止".gameLocalized
        case "distance_check":
            return "宝玉レベル1: 2.0秒後、2: 1.8秒後、3: 1.6秒後、4: 1.4秒後、5: 1.2秒後。消費MPなし。次に答えるまで残る".gameLocalized
        case "quiet_key":
            return "宝玉レベル1: MP10/8秒、2: MP9/10秒、3: MP8/12秒、4: MP7/14秒、5: MP6/16秒".gameLocalized
        case "heal":
            return "宝玉レベル1: MP24/HP24〜38、2: MP23/HP30〜44、3: MP22/HP36〜50、4: MP21/HP42〜56、5: MP20/HP48〜62".gameLocalized
        default:
            return traitDetailText(spec.id)
        }
    }

    func traitOneLineText(_ skillID: String) -> String {
        let level = max(1, skillGemLevel(skillID))
        switch skillID {
        case "hp_regen": return "5秒にHP\(regenValue(level))回復".gameLocalized
        case "mp_regen": return "5秒にMP\(regenValue(level))回復".gameLocalized
        case "hp_regen_risk": return "3秒にHP\(regenValue(level))回復 / ミス2倍".gameLocalized
        case "mp_regen_risk": return "3秒にMP\(regenValue(level))回復 / ミス2倍".gameLocalized
        case "hp_bonus": return "最大HP +\(smallPower(level))".gameLocalized
        case "mp_bonus": return "最大MP +\(smallPower(level))".gameLocalized
        case "first_guard": return "ミスまで被害 -\(level)".gameLocalized
        case "first_slow": return "ミス/被弾まで 拍\(Int(hpThresholdSlowFactor(level) * 100))%".gameLocalized
        case "miss_guard": return "ミス時被害 \(Int(missGuardFactor(level) * 100))%".gameLocalized
        case "damage_guard": return "被害 \(Int(damageGuardFactor(level) * 100))%".gameLocalized
        case "full_hp_slow": return "HP99%以上 拍\(Int(hpThresholdSlowFactor(level) * 100))%".gameLocalized
        case "hit_slow": return "被弾時 拍\(Int(hitSlowFactorForLevel(level) * 100))%".gameLocalized
        case "tune_mp": return "調律時MP +\(doublingPower(level))".gameLocalized
        case "tune_hp": return "調律時HP +\(doublingPower(level))".gameLocalized
        case "tune_hp_risk": return "調律時HP +\(largePower(level)) / ミス2倍".gameLocalized
        case "tune_mp_risk": return "調律時MP +\(largePower(level)) / ミス2倍".gameLocalized
        case "heal_power": return "回復量 +\(healingPower(level))".gameLocalized
        case "skill_rewind": return "技使用時 拍-\(skillRewindSeconds(level))秒".gameLocalized
        case "skill_interval": return "技間隔 -\(doublingPower(level))秒".gameLocalized
        case "hp_bonus_risk": return "最大HP +\(riskPower(level)) / ミス2倍".gameLocalized
        case "mp_bonus_risk": return "最大MP +\(riskPower(level)) / ミス2倍".gameLocalized
        case "global_slow": return "敵拍 \(Int(globalSlowFactor(level) * 100))%".gameLocalized
        case "hp75_slow": return "HP75%以下 拍\(Int(hpThresholdSlowFactor(level) * 100))%".gameLocalized
        case "hp50_slow": return "HP50%以下 拍\(Int(hpThresholdSlowFactor(level) * 100))%".gameLocalized
        case "hp25_slow": return "HP25%以下 拍\(Int(hpThresholdSlowFactor(level) * 100))%".gameLocalized
        case "effect_extend": return "技効果 +\(effectExtendSeconds(level))秒".gameLocalized
        case "half_hpmp_slow": return "HP/MP半分 / 敵拍\(Int(sixSlowFactor(level) * 100))%".gameLocalized
        case "deep_ring": return "被害2倍 / 敵拍\(Int(sixSlowFactor(level) * 100))%".gameLocalized
        default: return "補助 +\(level)".gameLocalized
        }
    }

    func traitDetailText(_ skillID: String) -> String {
        switch skillID {
        case "hp_regen": return "宝玉レベル1:5秒にHP1、2:HP2、3:HP4、4:HP8、5:HP16回復".gameLocalized
        case "mp_regen": return "宝玉レベル1:5秒にMP1、2:MP2、3:MP4、4:MP8、5:MP16回復".gameLocalized
        case "hp_regen_risk": return "宝玉レベル1:3秒にHP1、2:HP2、3:HP4、4:HP8、5:HP16回復。ミス時被害2倍".gameLocalized
        case "mp_regen_risk": return "宝玉レベル1:3秒にMP1、2:MP2、3:MP4、4:MP8、5:MP16回復。ミス時被害2倍".gameLocalized
        case "hp_bonus": return "宝玉レベル1:+4、2:+8、3:+16、4:+32、5:+64 HP".gameLocalized
        case "mp_bonus": return "宝玉レベル1:+4、2:+8、3:+16、4:+32、5:+64 MP".gameLocalized
        case "first_guard": return "宝玉レベル1:-1、2:-2、3:-3、4:-4、5:-5。戦闘開始からミスするまで被ダメージを軽減。ミス以降は戦闘終了まで発動しない".gameLocalized
        case "first_slow": return "宝玉レベル1:98%、2:96%、3:92%、4:84%、5:68%。ミスまたは被弾するまで敵の拍を遅くする".gameLocalized
        case "miss_guard": return "宝玉レベル1:95%、2:90%、3:80%、4:60%、5:20%。ミス時ダメージだけを軽減".gameLocalized
        case "damage_guard": return "宝玉レベル1:98%、2:95%、3:90%、4:80%、5:60%。ミス・被弾の両方を軽減".gameLocalized
        case "full_hp_slow": return "宝玉レベル1:98%、2:96%、3:92%、4:84%、5:68%。HP99%以上で敵の拍を遅くする".gameLocalized
        case "hit_slow": return "宝玉レベル1:90%、2:80%、3:70%、4:60%、5:50%。被弾時、その敵の拍を遅くする".gameLocalized
        case "tune_mp": return "宝玉レベル1:+1、2:+2、3:+4、4:+8、5:+16 MP回復".gameLocalized
        case "tune_hp": return "宝玉レベル1:+1、2:+2、3:+4、4:+8、5:+16 HP回復".gameLocalized
        case "tune_hp_risk": return "宝玉レベル1:+4、2:+8、3:+16、4:+32、5:+64 HP回復。ミス時被害2倍".gameLocalized
        case "tune_mp_risk": return "宝玉レベル1:+4、2:+8、3:+16、4:+32、5:+64 MP回復。ミス時被害2倍".gameLocalized
        case "heal_power": return "宝玉レベル1:+2、2:+4、3:+8、4:+16、5:+32 回復量".gameLocalized
        case "skill_rewind": return "宝玉レベル1:0.1秒、2:0.2秒、3:0.4秒、4:0.8秒、5:1.6秒。戻せる量は攻撃猶予時間の100%まで".gameLocalized
        case "skill_interval": return "宝玉レベル1:-1秒、2:-2秒、3:-4秒、4:-8秒、5:-16秒".gameLocalized
        case "hp_bonus_risk": return "宝玉レベル1:+8、2:+16、3:+32、4:+64、5:+128 HP。ミス時被害2倍".gameLocalized
        case "mp_bonus_risk": return "宝玉レベル1:+8、2:+16、3:+32、4:+64、5:+128 MP。ミス時被害2倍".gameLocalized
        case "global_slow": return "宝玉レベル1:99%、2:98%、3:96%、4:92%、5:84%。他と重複".gameLocalized
        case "hp75_slow", "hp50_slow", "hp25_slow": return "宝玉レベル1:98%、2:96%、3:92%、4:84%、5:68%。他と重複".gameLocalized
        case "effect_extend": return "宝玉レベル1:+1秒、2:+2秒、3:+4秒、4:+8秒、5:+16秒".gameLocalized
        case "half_hpmp_slow": return "宝玉レベル1:敵拍90%、2:80%、3:70%、4:60%、5:50%。最大HP・MPが半分になる".gameLocalized
        case "deep_ring": return "宝玉レベル1:敵拍90%、2:80%、3:70%、4:60%、5:50%。被ダメージ2倍".gameLocalized
        default: return "宝玉レベルに応じて補助量が強化される。".gameLocalized
        }
    }

    func traitSummaryLines() -> [String] {
        var lines: [String] = []
        if traitBonusHP() > 0 { lines.append("最大HP +\(traitBonusHP())".gameLocalized) }
        if traitBonusMP() > 0 { lines.append("最大MP +\(traitBonusMP())".gameLocalized) }
        if traitTuningMPRecovery() > 0 { lines.append("調律MP +\(traitTuningMPRecovery())".gameLocalized) }
        if traitTuningHPRecovery() > 0 { lines.append("調律HP +\(traitTuningHPRecovery())".gameLocalized) }
        if traitHealBonus() > 0 { lines.append("回復量 +\(traitHealBonus())".gameLocalized) }
        if traitAutoHPRegen() > 0 { lines.append("5秒HP +\(traitAutoHPRegen())".gameLocalized) }
        if traitAutoMPRegen() > 0 { lines.append("5秒MP +\(traitAutoMPRegen())".gameLocalized) }
        if traitRiskAutoHPRegen() > 0 { lines.append("3秒HP +\(traitRiskAutoHPRegen())".gameLocalized) }
        if traitRiskAutoMPRegen() > 0 { lines.append("3秒MP +\(traitRiskAutoMPRegen())".gameLocalized) }
        if traitSkillIntervalReduction() > 0 { lines.append("技間隔 -\(traitSkillIntervalReduction())秒".gameLocalized) }
        if traitEffectExtensionSeconds() > 0 { lines.append("技効果 +\(traitEffectExtensionSeconds())秒".gameLocalized) }
        if traitMissDamageMultiplier() > 1 { lines.append("ミス被害 ×\(traitMissDamageMultiplier())".gameLocalized) }
        if traitDamageTakenMultiplier() > 1 { lines.append("被害 ×\(traitDamageTakenMultiplier())".gameLocalized) }
        if traitHalvesHPMP() { lines.append("HP/MP 半分".gameLocalized) }
        if traitEquipCostUsed() > 0 || !equippedTraitIDs.isEmpty { lines.append("装備コスト \(traitEquipCostUsed())/\(traitEquipCostCapacity)".gameLocalized) }
        if lines.isEmpty { lines.append("特性なし".gameLocalized) }
        return lines
    }

    func skillCostDisplay(_ skillID: String) -> Int {
        switch skillID {
        case "slow": return valueForPotential(skillID, [8, 7, 6, 5, 4])
        case "root_sight": return valueForPotential(skillID, [12, 11, 10, 9, 8])
        case "distance_check": return 0
        case "quiet_key": return valueForPotential(skillID, [10, 9, 8, 7, 6])
        case "heal": return valueForPotential(skillID, [24, 23, 22, 21, 20])
        default: return 0
        }
    }

    func skillIntervalSeconds(_ skillID: String) -> Int {
        switch skillID {
        case "slow", "quiet_key":
            return 30
        case "heal":
            return 12
        case "distance_check":
            return 0
        default:
            return 25
        }
    }

    func isSkillReady(_ skillID: String) -> Bool {
        skillCooldownUntil[skillID, default: .distantPast].timeIntervalSince(Date()) <= 0
    }

    func skillCooldownRemaining(_ skillID: String) -> Int {
        max(0, Int(ceil(skillCooldownUntil[skillID, default: .distantPast].timeIntervalSince(Date()))))
    }

    private func skillEffectDuration(_ skillID: String) -> TimeInterval {
        let base: Int
        switch skillID {
        case "slow":
            base = valueForPotential(skillID, [8, 10, 12, 14, 16])
        case "root_sight":
            base = valueForPotential(skillID, [14, 16, 18, 20, 22])
        case "quiet_key":
            base = valueForPotential(skillID, [8, 10, 12, 14, 16])
        default:
            base = 0
        }

        guard base > 0 else { return 0 }
        return TimeInterval(base + traitEffectExtensionSeconds())
    }

    private func smallPower(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return [4, 8, 16, 32, 64][min(4, level - 1)]
    }

    private func riskPower(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return [8, 16, 32, 64, 128][min(4, level - 1)]
    }

    private func largePower(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return [4, 8, 16, 32, 64][min(4, level - 1)]
    }

    private func doublingPower(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return [1, 2, 4, 8, 16][min(4, level - 1)]
    }

    private func regenValue(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return [1, 2, 4, 8, 16][min(4, level - 1)]
    }

    private func healingPower(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return [2, 4, 8, 16, 32][min(4, level - 1)]
    }

    private func hitSlowFactorForLevel(_ level: Int) -> Double {
        [0.90, 0.80, 0.70, 0.60, 0.50][min(4, max(0, level - 1))]
    }

    private func globalSlowFactor(_ level: Int) -> Double {
        [0.99, 0.98, 0.96, 0.92, 0.84][min(4, max(0, level - 1))]
    }

    private func hpThresholdSlowFactor(_ level: Int) -> Double {
        [0.98, 0.96, 0.92, 0.84, 0.68][min(4, max(0, level - 1))]
    }

    private func effectExtendSeconds(_ level: Int) -> Int {
        guard level > 0 else { return 0 }
        return [1, 2, 4, 8, 16][min(4, level - 1)]
    }

    private func skillRewindSeconds(_ level: Int) -> Double {
        guard level > 0 else { return 0 }
        return [0.1, 0.2, 0.4, 0.8, 1.6][min(4, level - 1)]
    }

    private func missGuardFactor(_ level: Int) -> Double {
        [0.95, 0.90, 0.80, 0.60, 0.20][min(4, max(0, level - 1))]
    }

    private func damageGuardFactor(_ level: Int) -> Double {
        [0.98, 0.95, 0.90, 0.80, 0.60][min(4, max(0, level - 1))]
    }

    private func sixSlowFactor(_ level: Int) -> Double {
        [0.90, 0.80, 0.70, 0.60, 0.50][min(4, max(0, level - 1))]
    }

    private func traitEffectExtensionSeconds() -> Int {
        effectExtendSeconds(traitPotential("effect_extend"))
    }

    private func traitPotential(_ skillID: String) -> Int {
        guard currentBattle?.traitsEnabled != false else { return 0 }
        guard equippedTraitIDs.contains(skillID) else { return 0 }
        return max(0, skillGemLevel(skillID))
    }

    private func traitBonusHP() -> Int {
        smallPower(traitPotential("hp_bonus")) + riskPower(traitPotential("hp_bonus_risk"))
    }

    private func traitBonusMP() -> Int {
        smallPower(traitPotential("mp_bonus")) + riskPower(traitPotential("mp_bonus_risk"))
    }

    private func traitTuningMPRecovery() -> Int {
        doublingPower(traitPotential("tune_mp")) + largePower(traitPotential("tune_mp_risk"))
    }

    private func traitTuningHPRecovery() -> Int {
        doublingPower(traitPotential("tune_hp")) + largePower(traitPotential("tune_hp_risk"))
    }

    private func traitAutoHPRegen() -> Int {
        regenValue(traitPotential("hp_regen"))
    }

    private func traitAutoMPRegen() -> Int {
        regenValue(traitPotential("mp_regen"))
    }

    private func traitRiskAutoHPRegen() -> Int {
        regenValue(traitPotential("hp_regen_risk"))
    }

    private func traitRiskAutoMPRegen() -> Int {
        regenValue(traitPotential("mp_regen_risk"))
    }

    private func traitHealBonus() -> Int {
        healingPower(traitPotential("heal_power"))
    }

    private func traitSkillUseRewindSeconds() -> Double {
        skillRewindSeconds(traitPotential("skill_rewind"))
    }

    private func traitSkillIntervalReduction() -> Int {
        doublingPower(traitPotential("skill_interval"))
    }

    private func traitMissDamageMultiplier() -> Int {
        let riskIDs = ["mp_regen_risk", "mp_bonus_risk", "tune_hp_risk", "hp_bonus_risk", "tune_mp_risk", "hp_regen_risk"]
        let riskCount = riskIDs.filter { traitPotential($0) > 0 }.count
        return Int(pow(2.0, Double(riskCount)))
    }

    private func traitDamageTakenMultiplier() -> Int {
        traitPotential("deep_ring") > 0 ? 2 : 1
    }

    private func traitHalvesHPMP() -> Bool {
        traitPotential("half_hpmp_slow") > 0
    }

    private func traitAttackSpeedFactor() -> Double {
        var factor = 1.0
        let maxHP = max(currentMaxHP(), 1)
        let ratio = Double(playerHP) / Double(maxHP)

        let globalLevel = traitPotential("global_slow")
        if globalLevel > 0 { factor *= globalSlowFactor(globalLevel) }

        let firstSlowLevel = traitPotential("first_slow")
        if firstSlowLevel > 0 && !firstSlowBroken { factor *= hpThresholdSlowFactor(firstSlowLevel) }

        let fullHPLevel = traitPotential("full_hp_slow")
        if fullHPLevel > 0 && ratio >= 0.99 { factor *= hpThresholdSlowFactor(fullHPLevel) }

        if ratio <= 0.75 {
            let level = traitPotential("hp75_slow")
            if level > 0 { factor *= hpThresholdSlowFactor(level) }
        }
        if ratio <= 0.50 {
            let level = traitPotential("hp50_slow")
            if level > 0 { factor *= hpThresholdSlowFactor(level) }
        }
        if ratio <= 0.25 {
            let level = traitPotential("hp25_slow")
            if level > 0 { factor *= hpThresholdSlowFactor(level) }
        }

        let sharpLevel = traitPotential("half_hpmp_slow")
        if sharpLevel > 0 { factor *= sixSlowFactor(sharpLevel) }

        let deepLevel = traitPotential("deep_ring")
        if deepLevel > 0 { factor *= sixSlowFactor(deepLevel) }

        if hitSlowUntil.timeIntervalSince(effectTime) > 0 {
            factor *= hitSlowFactor
        }

        return max(0.05, factor)
    }


    var selectedAura: RootAura {
        aura(id: selectedAuraID)
    }

    var finalNormalUnlocked: Bool {
        clearedMultiDungeonIDs.contains(where: { id in
            multiAuraDungeons.first(where: { $0.id == id })?.tier == 6
        })
    }

    var finalTrueUnlocked: Bool {
        clearedDungeonAuraIDs.count >= 12
    }

    var clearedPairCount: Int {
        clearedMultiDungeonIDs.filter { id in
            multiAuraDungeons.first(where: { $0.id == id })?.tier == 2
        }.count
    }

    var clearedQuadCount: Int {
        clearedMultiDungeonIDs.filter { id in
            multiAuraDungeons.first(where: { $0.id == id })?.tier == 4
        }.count
    }

    func aura(id: Int) -> RootAura {
        rootAuras.first(where: { $0.id == id }) ?? rootAuras[0]
    }

    func auraColorByIndex(_ index: Int) -> Color {
        aura(id: ((index % 12) + 12) % 12).color
    }

    func isUnlocked(_ aura: RootAura) -> Bool {
        unlockedAuraIDs.contains(aura.id)
    }

    func isCleared(_ aura: RootAura) -> Bool {
        clearedDungeonAuraIDs.contains(aura.id)
    }

    func isMultiCleared(_ dungeon: MultiAuraDungeon) -> Bool {
        clearedMultiDungeonIDs.contains(dungeon.id)
    }

    func isMultiUnlocked(_ dungeon: MultiAuraDungeon) -> Bool {
        switch dungeon.tier {
        case 2:
            if dungeon.auraIDs.contains(where: { clearedDungeonAuraIDs.contains($0) }) {
                return true
            }
            return multiAuraDungeons.contains { other in
                other.tier == 4 &&
                clearedMultiDungeonIDs.contains(other.id) &&
                overlap(other.auraIDs, dungeon.auraIDs) >= 2
            }

        case 4:
            if multiAuraDungeons.contains(where: { other in
                other.tier == 2 &&
                clearedMultiDungeonIDs.contains(other.id) &&
                overlap(other.auraIDs, dungeon.auraIDs) >= 2
            }) {
                return true
            }

            return multiAuraDungeons.contains { other in
                other.tier == 6 &&
                clearedMultiDungeonIDs.contains(other.id) &&
                overlap(other.auraIDs, dungeon.auraIDs) >= 3
            }

        case 6:
            return multiAuraDungeons.contains { other in
                other.tier == 4 &&
                clearedMultiDungeonIDs.contains(other.id) &&
                overlap(other.auraIDs, dungeon.auraIDs) >= 2
            }

        default:
            return false
        }
    }

    private func singleAuraBattleBackgroundAssetName(_ auraID: Int) -> String {
        switch auraID {
        case 0: return "battle_bg_root_c"
        case 7: return "battle_bg_root_g"
        case 2: return "battle_bg_root_d"
        case 9: return "battle_bg_root_a"
        case 4: return "battle_bg_root_e"
        case 11: return "battle_bg_root_b"
        case 6: return "battle_bg_root_gb"
        case 1: return "battle_bg_root_db"
        case 8: return "battle_bg_root_ab"
        case 3: return "battle_bg_root_eb"
        case 10: return "battle_bg_root_bb"
        case 5: return "battle_bg_root_f"
        default: return "battle_bg"
        }
    }

    func battleBackgroundAssetName() -> String {
        guard let config = currentBattle else { return "battle_bg_training" }
        return battleBackgroundAssetName(for: config)
    }

    func battleBackgroundAssetName(for config: BattleConfig) -> String {
        switch config.mode {
        case .training, .dungeon:
            if let auraID = config.allowedAuraIDs.first, config.allowedAuraIDs.count == 1 {
                return singleAuraBattleBackgroundAssetName(auraID)
            }
            return config.mode == .training ? "battle_bg_training" : "battle_bg"
        case .multi:
            let id = config.id.replacingOccurrences(of: "multi_", with: "")
            return "battle_bg_\(id)"
        case .finalNormal, .finalTrue:
            return "battle_bg_final"
        }
    }

    private func overlap(_ a: [Int], _ b: [Int]) -> Int {
        Set(a).intersection(Set(b)).count
    }

    func resetProgress() {
        unlockedAuraIDs = [0]
        clearedDungeonAuraIDs = []
        clearedMultiDungeonIDs = []
        selectedAuraID = 0
        playerLevel = 1
        clearedFinalCore = false
        gemLevels = [:]
        equippedSkillIDs = ["distance_check"]
        equippedTraitIDs = []
        currentBattle = nil
        currentEnemy = nil
        enemyDeck = []
        defeatedCount = 0
        playerHP = currentMaxHP()
        playerMP = currentMaxMP()
        attackProgress = 0
        slowUntil = .distantPast
        hintCandidates = []
        hintUntil = .distantPast
        activeHintCandidateCount = nil
        auraHintUntil = .distantPast
        auraHintPressesRemaining = 0
        auraHintMaxPresses = 0
        distanceHintAvailableAt = .distantFuture
        distanceHintExpiresAt = .distantPast
        fatherAdviceIntroPending = false
        skillCooldownUntil.removeAll()
        autoRegenAccumulator = 0
        riskRegenAccumulator = 0
        battleResponseTotal = 0
        battleResponseCount = 0
        battleHadMiss = false
        firstSlowBroken = false
        battleFinished = false
        battleWon = false
        lastResult = .ready
        rootAnswerTiming = [:]
        intervalAnswerTiming = [:]
        pairAnswerTiming = [:]
        notebookRecordUnlockText = ""
        notebookRecordIntroSeen = false

        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: equippedTraitsKey)
        defaults.removeObject(forKey: equippedSkillsKey)
        defaults.removeObject(forKey: gemLevelsKey)
        defaults.removeObject(forKey: comboPerformanceKey)
        defaults.removeObject(forKey: rootAnswerTimingKey)
        defaults.removeObject(forKey: intervalAnswerTimingKey)
        defaults.removeObject(forKey: pairAnswerTimingKey)
        defaults.removeObject(forKey: notebookRecordIntroSeenKey)
        defaults.removeObject(forKey: "IntervalRouteMVP.seenStoryEvents.v1")
        defaults.removeObject(forKey: fatherAdviceIntroSeenKey)
        saveProgress()
        levelUpText = ""
        levelUpDetailText = ""
        clearResonanceText = ""
        gemRewardText = ""
        gemRewardDetailText = ""
        finalCoreSceneText = ""
        finalCoreIntermissionText = ""
        finalCoreIntermissionActive = false
        pendingFinalCoreClearStoryEvent = false
        finalCoreSceneText = ""
        message = "進行状況をリセットしました。"
    }

    private func loadProgress() {
        let defaults = UserDefaults.standard

        if let unlocked = defaults.array(forKey: unlockedKey) as? [Int], !unlocked.isEmpty {
            unlockedAuraIDs = Set(unlocked)
        } else {
            unlockedAuraIDs = [0]
        }

        if let cleared = defaults.array(forKey: clearedKey) as? [Int] {
            clearedDungeonAuraIDs = Set(cleared)
        }

        if let multi = defaults.array(forKey: clearedMultiKey) as? [String] {
            clearedMultiDungeonIDs = Set(multi)
        }

        let savedLevel = defaults.integer(forKey: playerLevelKey)
        playerLevel = max(1, savedLevel)
        clearedFinalCore = defaults.bool(forKey: clearedFinalCoreKey)
        notebookRecordIntroSeen = defaults.bool(forKey: notebookRecordIntroSeenKey)

        if let storedGemLevels = defaults.dictionary(forKey: gemLevelsKey) as? [String: Int] {
            gemLevels = storedGemLevels
        }

        let validGemIDs = Set(gemSkills.map { $0.id })
        gemLevels = gemLevels.filter { validGemIDs.contains($0.key) }

        let storedVersion = defaults.string(forKey: dataVersionKey)
        if storedVersion != currentDataVersion {
            equippedSkillIDs = ["distance_check"]
            equippedTraitIDs = []
            defaults.set(currentDataVersion, forKey: dataVersionKey)
            defaults.set(equippedSkillIDs, forKey: equippedSkillsKey)
            defaults.set(equippedTraitIDs, forKey: equippedTraitsKey)
        }

        if defaults.string(forKey: dataVersionKey) == currentDataVersion,
           let storedEquipped = defaults.array(forKey: equippedSkillsKey) as? [String] {
            let filtered = storedEquipped.filter { isActiveBattleSkill($0) && isSkillUnlocked($0) }
            equippedSkillIDs = Array(filtered.prefix(5))
            if !equippedSkillIDs.contains("distance_check") {
                equippedSkillIDs.insert("distance_check", at: min(1, equippedSkillIDs.count))
                equippedSkillIDs = Array(equippedSkillIDs.prefix(5))
            }
        } else {
            equippedSkillIDs = ["distance_check"]
        }

        if defaults.string(forKey: dataVersionKey) == currentDataVersion,
           let storedTraits = defaults.array(forKey: equippedTraitsKey) as? [String] {
            let filtered = storedTraits.filter { isTraitGem($0) && skillGemLevel($0) > 0 }
            equippedTraitIDs = Array(filtered.prefix(6))
        } else {
            equippedTraitIDs = []
        }
    }

    private func saveProgress() {
        let defaults = UserDefaults.standard
        defaults.set(Array(unlockedAuraIDs), forKey: unlockedKey)
        defaults.set(Array(clearedDungeonAuraIDs), forKey: clearedKey)
        defaults.set(Array(clearedMultiDungeonIDs), forKey: clearedMultiKey)
        defaults.set(playerLevel, forKey: playerLevelKey)
        defaults.set(clearedFinalCore, forKey: clearedFinalCoreKey)
        defaults.set(notebookRecordIntroSeen, forKey: notebookRecordIntroSeenKey)
        defaults.set(gemLevels, forKey: gemLevelsKey)
        defaults.set(equippedSkillIDs, forKey: equippedSkillsKey)
        defaults.set(equippedTraitIDs, forKey: equippedTraitsKey)
        defaults.set(currentDataVersion, forKey: dataVersionKey)
    }

    private func loadComboPerformance() {
        guard let data = UserDefaults.standard.data(forKey: comboPerformanceKey) else { return }
        if let decoded = try? JSONDecoder().decode([String: ComboPerformance].self, from: data) {
            comboPerformance = decoded
        }
    }

    private func saveComboPerformance() {
        if let data = try? JSONEncoder().encode(comboPerformance) {
            UserDefaults.standard.set(data, forKey: comboPerformanceKey)
        }
    }


    private func loadAnswerTimingStats() {
        let defaults = UserDefaults.standard
        if let data = defaults.data(forKey: rootAnswerTimingKey),
           let decoded = try? JSONDecoder().decode([String: AnswerTimingStat].self, from: data) {
            rootAnswerTiming = decoded
        }
        if let data = defaults.data(forKey: intervalAnswerTimingKey),
           let decoded = try? JSONDecoder().decode([String: AnswerTimingStat].self, from: data) {
            intervalAnswerTiming = decoded
        }
        if let data = defaults.data(forKey: pairAnswerTimingKey),
           let decoded = try? JSONDecoder().decode([String: AnswerTimingStat].self, from: data) {
            pairAnswerTiming = decoded
        }
    }

    private func saveAnswerTimingStats() {
        let defaults = UserDefaults.standard
        if let data = try? JSONEncoder().encode(rootAnswerTiming) {
            defaults.set(data, forKey: rootAnswerTimingKey)
        }
        if let data = try? JSONEncoder().encode(intervalAnswerTiming) {
            defaults.set(data, forKey: intervalAnswerTimingKey)
        }
        if let data = try? JSONEncoder().encode(pairAnswerTiming) {
            defaults.set(data, forKey: pairAnswerTimingKey)
        }
    }

    private func leveledMaxHP(base: Int) -> Int {
        base + max(0, playerLevel - 1) * 6
    }

    private func leveledMaxMP(base: Int) -> Int {
        base + max(0, playerLevel - 1) * 3
    }

    private func auraFlavor(_ aura: RootAura) -> (place: String, training: String, battle: String, short: String) {
        switch aura.id {
        case 0:
            return ("Cの灯火港", "港の灯と潮の音が混じる拠点。古い音鍵で、始まりの根Cへ戻る手順を覚える。", "港外れの灯台跡に、調律を乱された生き物が集まる。Cへ戻り、そこから一音ずつ数える最初の実戦。", "島へ渡る港を抱く、始まりの拠点。")
        case 7:
            return ("Gの風見街", "風車と青旗が揺れる高台の拠点。動く風の中で、Gへ戻る場所を確かめる。", "青い風道が伸びる高原の街道跡。流されても、根へ戻ってから選び直す。", "青風が道標になる宿場。")
        case 2:
            return ("Dの砂鐘街", "砂時計の塔が立つ黄土の拠点。乾いた響きに急かされても、Dへ戻る手順を崩さない。", "砂色の鐘楼跡が残る台地。判断が遅れても、戻る場所を取り直せば続けられる。", "砂鐘の音が響く台地の街。")
        case 9:
            return ("Aの紫苑街", "紫の花と稲光が瞬く丘の拠点。揺れる光に惑わされず、Aを起点に数える。", "紫の花影に雷光が走る回廊。ためらいより先に、根へ戻る癖が試される。", "紫光が棚引く丘の街。")
        case 4:
            return ("Eの翠庭街", "水路と緑庭に囲まれた拠点。Eの根を静かに決め、余分な力みを抜く。", "緑の庭園遺構と水辺が広がる近郊。穏やかな場所ほど、戻る手順を丁寧に保つ。", "翠の庭園が広がる水辺の街。")
        case 11:
            return ("Bの灰塔街", "灰色の塔と静かな工房が並ぶ拠点。硬い空気の中で、Bへ戻る足場を作る。", "灰塔の外壁が続く防衛区画。拍に押されるほど、手元の根へ戻る必要がある。", "灰塔が空を裂く工房街。")
        case 6:
            return ("G♭の氷鏡街", "薄氷と鏡面の水路が光る拠点。冷たい景色の中でG♭の根を確かめる。", "氷鏡の谷へ降りる白い石段。G♭のオーラは冷え切っており、反射で選ぶ力が問われる。", "氷鏡が光る冷たい街。")
        case 1:
            return ("D♭の霧晶街", "霧と結晶が漂う拠点。曖昧な景色の中で、D♭へ戻る位置を確かめる。", "霧晶の林道と結晶洞が絡む近郊。ぼやけるほど、記憶ではなく今の根へ戻る。", "霧晶が漂う静かな街。")
        case 8:
            return ("A♭の夕影街", "夕色の影が長く伸びる拠点。A♭の根を影の揺らぎから聴き分ける。", "夕影の回廊と崩れた庭園が続く近郊。A♭のオーラは柔らかいが、敵は容赦なく迫る。", "夕影が沈む回廊の街。")
        case 3:
            return ("E♭の黄塵街", "黄塵をまとった市場跡の拠点。濁りの中でも、E♭へ戻る場所は消えない。", "黄土の回廊と市場遺構が重なる近郊。迷ったら止まり、根を取り直す。", "黄塵が舞う市場の街。")
        case 10:
            return ("B♭の土輪街", "土の円環と古井戸が残る拠点。B♭の根を大地のうねりとともに確かめる。", "土壁の輪郭が残る近郊要塞。B♭のオーラは深く、地に足のついた調律が求められる。", "土輪の要塞跡に寄り添う街。")
        case 5:
            return ("Fの水響街", "水路と橋がめぐる薄緑の拠点。Fの根を水音とともに拾い、流れを崩さない。", "水響の運河と石橋が交差する近郊。Fのオーラは柔らかく、流れに遅れると一気に崩れる。", "水響が巡る運河の街。")
        default:
            return ("外縁の拠点", "父の仮想敵で十一の響きを整える。", "実体化した響きの獣がいる近郊地帯。", "外縁の拠点。")
        }
    }

    func auraPlaceName(_ aura: RootAura) -> String {
        auraFlavor(aura).place
    }

    func auraMapNote(_ aura: RootAura) -> String {
        auraFlavor(aura).short
    }

    func auraTrainingSummary(_ aura: RootAura) -> String {
        auraFlavor(aura).training
    }

    func auraBattleSummary(_ aura: RootAura) -> String {
        auraFlavor(aura).battle
    }

    func auraDialogue(_ aura: RootAura) -> String {
        switch aura.id {
        case 0:
            return "父「ここが灯火港だ。この音鍵は、まず帰る場所を知るところから始まる。焦らなくていいよ。」\n港の老人「屋久の環と呼ばれた古い島だ。最近、調律を乱された生き物が増えている。」"
        case 7:
            return "父「Gは風みたいに動く。見失いそうなら、Cで覚えた帰る感じを思い出そう。」\n風見台の少年「港の子だろ。こんな早くここまで来るなんて、風より速いな。」"
        case 2:
            return "父「乾いた音は急がせてくる。でも、手は急がなくても届くよ。」\n砂鐘守「砂鐘の音が濁っている。君の音で、もう一度だけ澄ませてくれ。」"
        case 9:
            return "父「光に驚いたら、目を細めるみたいに音も少し絞ろう。根はちゃんと残っている。」\n塔番「父上と同じ構えだな。けれど、音は君自身のものだ。」"
        case 4:
            return "父「水の街では、音がやわらかく揺れる。急がず、ひとつ選べばいい。」\n庭師「水面がまた静かになった。あなたが通った跡だ。」"
        case 11:
            return "父「硬い音に当たっても、怖がらなくていい。少しずつ、少しずつ形になる。」\n工房の職人「その音鍵、ずいぶん古い型だな。普通は扱いづらいはずだが、妙に手に馴染んでいる。」"
        case 6:
            return "父「島の反対側まで来たね。知らないはずの音でも、戻る場所があれば手は落ち着く。怖がらなくていい。」\n氷鏡の番人「港の灯が、こんな遠くまで届くとは思わなかった。」"
        case 1:
            return "父「霧の中では、ゆっくりでいい。外の揺らぎより、戻れる根を信じよう。」\n霧晶の娘「霧の向こうから音がした。あなたの音だったのね。」"
        case 8:
            return "父「夕影は優しいけれど、優しさは迷いにもなる。迷ったら、戻ればいい。」\n夕影の衛士「ここまで来たなら、もう戻るだけの旅ではないな。」"
        case 3:
            return "父「濁った音の中でも、根は消えない。取り直す時間は、ちゃんとある。」\n市場の女主人「あの人は昔から、見える者だけが門をくぐれるのはおかしいと言っていたよ。」"
        case 10:
            return "父「B♭は大地の響きだ。足元の音を信じよう。重くても、支えになる。」\n土輪の門番「遠回りに見えても、ここまで来た音は無駄じゃない。中心へ行くなら、その積み重ねが要る。」"
        case 5:
            return "父「Fの水路は帰り道にも似ている。休むことも、進むための技だよ。」\n水門守「無理に進むな。息を整える技を覚えていけ。長い道になる。」"
        default:
            return "父「この拠点の音を、いっしょに確かめよう。」"
        }
    }

    func multiDungeonDialogue(_ dungeon: MultiAuraDungeon) -> String {
        switch dungeon.id {
        case "pair_0":
            return "父「ここは二つの根が重なる最初の洞だ。Cへ戻る感じを、胸の中に少し残しておこう。」\n洞守「灯と風がぶつかる日は、音鍵を持つ者が頼りだ。」"
        case "pair_1":
            return "父「私は外周の乱れを押さえている。大丈夫、ここは一人で入れる。風が砂に変わる瞬間を、よく聞いておいで。」\n砂鐘守「昔、父上と旅をした男もここで立ち止まった。耳の差で道を分けるな、と怒っていた。」"
        case "pair_2":
            return "父「DとAは近い。近いからこそ、急がなくていい。中で根が決まれば、指は追いつく。」\n裂け目の声「雷が落ちても、砂時計は止まらない。」"
        case "pair_3":
            return "父「色に引かれそうになったら、いちど息をしよう。いま鳴っている根だけでいい。」\n水脈の番人「その音で水面が落ち着いた。次は奥へ行けるはずだ。」"
        case "pair_4":
            return "父「Eは柔らかい。Bは硬い。違いを間違えてもいい。戻って選び直せば、ちゃんと身につく。」\n廃路の職人「灰塔へ続く道を開ける。通るなら、音を濁すな。」"
        case "pair_5":
            return "父「冷えた音ほど輪郭は鋭い。指先を急がせないで、根の形を見てからでいい。」\n灰氷の声「ここまで来たなら、もう外周だけの子ではない。」"
        case "pair_6":
            return "父「島の裏側まで来たね。遠く感じても、鍵盤の上では同じ十二の中にある。」\n氷鏡の番人「港の灯が、こんな底まで届くとは思わなかった。」"
        case "pair_7":
            return "父「霧の中では、足元が少し遅れてくる。先に決めるのは根だ。大丈夫、戻れば進める。」\n沈橋の声「足元が消えても、最初に握った鍵の感触までは消えない。」"
        case "pair_8":
            return "父「夕影は優しい。だから迷いやすい。迷ったら、最初の一音に戻ろう。」\n庭の影「ここまでの旅で、その音は少し静かになった。」"
        case "pair_9":
            return "父「重い音は、押す前の時間をくれる。焦らなくていい。戻ってから選ぼう。」\n門番「遠回りに見える道ほど、中心では役に立つ。」"
        case "pair_10":
            return "父「力を抜くことも戦いだよ。Fの流れに乗れば、B♭の重さも怖くない。」\n水路守「息を整えろ。中心まで、休まず行ける者はいない。」"
        case "pair_11":
            return "父「始まりへ戻る道だ。戻ることは後退じゃない。Cをもう一度、新しく聞こう。」\n帰路の灯「港の灯は、出発だけでなく帰還も照らす。」"
        case "quad_0":
            return "父「四つの根が揺れる。私は外側で道を保っている。自分の速さで進めばいい。」\n郭の碑「速さだけでは抜けられない。戻る根を持つ者だけが通る。」"
        case "quad_1":
            return "父「落ちる感覚に引かれそうなら、手元へ戻ろう。鍵盤はいつも近くにある。」\n斜坑の声「砂、雷、水、灰。四つを覚えるな。今の一つを選べ。」"
        case "quad_2":
            return "父「静かな場所ほど、正解は隠れる。急がなくていい。根を決めてから進もう。」\n水殿の柱「音を急がせる者は沈む。根を決めた者だけが渡る。」"
        case "quad_3":
            return "父「鏡に映るものに惑わされても、覚えた根は消えないよ。」\n鏡庭の声「遠い町から来た音が、ここで静かに形を結ぶ。」"
        case "quad_4":
            return "父「中心の影が近い。怖くなったら、ここまで戻ってきた音を思い出せばいい。」\n庭守「夕、黄、土、水。どれも止めるためではなく、中心へ送るためにある。」"
        case "quad_5":
            return "父「始まりの近くに見えて、もう始まりではない。ここまで積んだ音が、ちゃんと支えている。」\n塞の声「港へ戻る者か、中心へ向かう者か。迷った時の戻り方で分かる。」"
        case "six_sharp":
            return "父「ここからは、本当に自分の道だ。私は外で核の乱れを押さえている。行っておいで。」\n険路の声「鋭い六つを越えよ。見える道ではなく、戻る道を持つ者だけが通る。」"
        case "six_flat":
            return "父「重い六つは足を止める。でも、積んできた音はもう沈まない。ゆっくりでも進める。」\n険路の声「重い六つを越えよ。港から来た子よ、ここまで戻ってきた手順を信じろ。」"
        default:
            return "父「ここから先は、自分の調律で進めばいい。私はここで聴いている。」"
        }
    }

    func finalCoreDialogue() -> String {
        "父「ここから先へ、私は入れない。でも、戻ってきた音は、ここまで残っている。」\n旧友の声「来たか。見えないまま、ここまで。なら見せてみろ。戻る道が、この沈黙に届くのか。」"
    }

    private func joinedNote(_ parts: [String]) -> String {
        parts.filter { !$0.isEmpty }.map { $0.gameLocalized }.joined(separator: "\n\n")
    }

    func auraMapInfo(_ aura: RootAura) -> MapInfo {
        MapInfo(
            title: auraPlaceName(aura),
            status: isUnlocked(aura) ? (isCleared(aura) ? "攻略済み" : "攻略可能") : "未開放",
            reward: singleAuraRewardText(for: aura),
            note: joinedNote([
                auraMapNote(aura),
                auraDialogue(aura),
                isUnlocked(aura) ? "稽古と近郊攻略を選べる。" : "接続するエリアを調律すると道が開く。"
            ]),
            rewardDetail: rewardThresholdText(forDungeonID: "aura_\(aura.id)")
        )
    }

    func dungeonMapInfo(_ dungeon: MultiAuraDungeon) -> MapInfo {
        MapInfo(
            title: dungeon.title,
            status: isMultiUnlocked(dungeon) ? (isMultiCleared(dungeon) ? "攻略済み" : "攻略可能") : "未開放",
            reward: gemRewardText(for: dungeon),
            note: joinedNote([
                dungeon.lore,
                multiDungeonDialogue(dungeon)
            ]),
            rewardDetail: rewardThresholdText(forDungeonID: dungeon.id)
        )
    }

    func finalCoreMapInfo() -> MapInfo {
        MapInfo(
            title: "無音の核",
            status: finalNormalUnlocked ? (isFinalCoreClearedForView ? "攻略済み" : "攻略可能") : "未開放",
            reward: finalCoreRewardText(),
            note: joinedNote([
                finalNormalUnlocked
                    ? "父を封じた旧友が待つ、音環島の中心。ここでは音視も近道も役に立たない。"
                    : "六重険路を越えた者だけが入れる沈黙の中心。旧友はここで、見える者も見えない者も同じ無音へ沈めようとしている。",
                finalCoreDialogue()
            ]),
            rewardDetail: rewardThresholdText(forDungeonID: "final_core")
        )
    }

    var isRecordFeatureUnlocked: Bool {
        clearedDungeonAuraIDs.count >= rootAuras.count
    }

    private func rootTimingKey(_ auraID: Int) -> String { "root_\(auraID)" }
    private func intervalTimingKey(_ enemyID: String) -> String { "interval_\(enemyID)" }
    private func pairTimingKey(auraID: Int, enemyID: String) -> String { "pair_\(auraID)_\(enemyID)" }

    func timingValueForRoot(_ auraID: Int) -> Double {
        rootRecordAverage(auraID: auraID).value
    }

    func timingValueForInterval(_ enemyID: String) -> Double {
        intervalRecordAverage(enemyID: enemyID).value
    }

    func timingValueForPair(auraID: Int, enemyID: String) -> Double {
        pairAnswerTiming[pairTimingKey(auraID: auraID, enemyID: enemyID)]?.value ?? AnswerTimingStat.initialValue
    }

    private func rootRecordAverage(auraID: Int) -> (value: Double, count: Int) {
        let values = enemyTypes.map { enemy -> AnswerTimingStat in
            pairAnswerTiming[pairTimingKey(auraID: auraID, enemyID: enemy.id)] ?? AnswerTimingStat()
        }
        let total = values.reduce(0.0) { $0 + $1.value }
        let count = values.reduce(0) { $0 + $1.count }
        return (total / Double(max(values.count, 1)), count)
    }

    private func intervalRecordAverage(enemyID: String) -> (value: Double, count: Int) {
        let values = rootAuras.map { aura -> AnswerTimingStat in
            pairAnswerTiming[pairTimingKey(auraID: aura.id, enemyID: enemyID)] ?? AnswerTimingStat()
        }
        let total = values.reduce(0.0) { $0 + $1.value }
        let count = values.reduce(0) { $0 + $1.count }
        return (total / Double(max(values.count, 1)), count)
    }

    func rootRecordRows() -> [WeaknessRecord] {
        rootAuras.map { aura in
            let stat = rootRecordAverage(auraID: aura.id)
            return WeaknessRecord(
                id: "root_\(aura.id)",
                title: aura.name,
                detail: auraPlaceName(aura),
                value: stat.value,
                count: stat.count,
                accentIndex: aura.id,
                imageName: nil
            )
        }
    }

    func intervalRecordRows() -> [WeaknessRecord] {
        enemyTypes.map { enemy in
            let stat = intervalRecordAverage(enemyID: enemy.id)
            return WeaknessRecord(
                id: "interval_\(enemy.id)",
                title: enemy.label,
                detail: "距離 \(displayDistanceText(for: enemy)) / 五度環 \(enemy.circle)",
                value: stat.value,
                count: stat.count,
                accentIndex: enemy.semitoneOffset,
                imageName: enemy.assetName
            )
        }
    }

    func pairRecordRows() -> [WeaknessRecord] {
        var rows: [WeaknessRecord] = []
        for enemy in enemyTypes {
            for aura in rootAuras {
                let key = pairTimingKey(auraID: aura.id, enemyID: enemy.id)
                let stat = pairAnswerTiming[key] ?? AnswerTimingStat()
                rows.append(WeaknessRecord(
                    id: key,
                    title: "\(aura.name) × \(enemy.label)",
                    detail: "\(auraPlaceName(aura)) / \(displayDistanceText(for: enemy))",
                    value: stat.value,
                    count: stat.count,
                    accentIndex: aura.id,
                    imageName: enemy.assetName
                ))
            }
        }
        return rows
    }

    func weaknessTrainingConfig() -> BattleConfig {
        BattleConfig(
            id: "weakness_training",
            title: "戻り稽古",
            mode: .training,
            allowedAuraIDs: rootAuras.map { $0.id },
            targetDefeatCount: 24,
            playerMaxHP: 100,
            playerMaxMP: 45,
            attackDuration: 999,
            enemyHP: 1,
            training: false,
            story: "父が手帳の記録から、迷いやすい音の生き物の影を示す。これは戦いではなく、何度でも戻るための稽古。",
            skillsEnabled: true,
            traitsEnabled: true,
            enemyAttacks: false
        )
    }

    func trainingConfig(for aura: RootAura) -> BattleConfig {
        BattleConfig(
            id: "training_\(aura.id)",
            title: "\(auraPlaceName(aura))：稽古",
            mode: .training,
            allowedAuraIDs: [aura.id],
            targetDefeatCount: 11,
            playerMaxHP: 100,
            playerMaxMP: 40,
            attackDuration: 999,
            enemyHP: 1,
            training: true,
            story: auraTrainingSummary(aura)
        )
    }

    func dungeonConfig(for aura: RootAura) -> BattleConfig {
        BattleConfig(
            id: "dungeon_\(aura.id)",
            title: "\(auraPlaceName(aura))：攻略",
            mode: .dungeon,
            allowedAuraIDs: [aura.id],
            targetDefeatCount: 11,
            playerMaxHP: 100,
            playerMaxMP: 45,
            attackDuration: 12.0,
            enemyHP: 1,
            training: false,
            story: auraBattleSummary(aura)
        )
    }

    func multiConfig(for dungeon: MultiAuraDungeon) -> BattleConfig {
        let target = dungeon.auraIDs.count * enemyTypes.count
        let duration: TimeInterval
        switch dungeon.tier {
        case 2:
            duration = 6.0
        case 4:
            duration = 3.0
        case 6:
            duration = 2.0
        default:
            duration = 3.0
        }

        return BattleConfig(
            id: "multi_\(dungeon.id)",
            title: "\(dungeon.title)：攻略",
            mode: .multi,
            allowedAuraIDs: dungeon.auraIDs,
            targetDefeatCount: target,
            playerMaxHP: 110 + dungeon.tier * 6,
            playerMaxMP: 50 + dungeon.tier * 4,
            attackDuration: duration,
            enemyHP: 1,
            training: false,
            story: dungeon.tier == 6
                ? "六つのオーラがぶつかる険路。ここを越えれば、十二の根が沈む無音の核へ届く。"
                : "\(dungeon.tier)つのオーラが混ざる。中心へ近づくほど、根の判断が重要になる。"
        )
    }

    func finalNormalConfig() -> BattleConfig {
        finalCoreConfig()
    }

    func finalTrueConfig() -> BattleConfig {
        finalCoreHardConfig()
    }

    func finalPracticeConfig() -> BattleConfig {
        BattleConfig(
            id: "final_core_practice",
            title: "無音の核：練習",
            mode: .training,
            allowedAuraIDs: rootAuras.map { $0.id },
            targetDefeatCount: rootAuras.count * enemyTypes.count,
            playerMaxHP: 150,
            playerMaxMP: 80,
            attackDuration: 999.0,
            enemyHP: 1,
            training: true,
            story: "敵は攻撃してこない。十二の根と生物の組み合わせを、落ち着いて確かめる。",
            enemyAttacks: false
        )
    }

    func finalCoreHardConfig() -> BattleConfig {
        BattleConfig(
            id: "final_core_hard",
            title: "無音の核：無装",
            mode: .finalTrue,
            allowedAuraIDs: rootAuras.map { $0.id },
            targetDefeatCount: rootAuras.count * enemyTypes.count,
            playerMaxHP: 150,
            playerMaxMP: 80,
            attackDuration: 1.0,
            enemyHP: 1,
            training: false,
            story: "技と特性を封じて、十二の根と生物だけで無音の核へ向き合う。",
            skillsEnabled: false,
            traitsEnabled: false
        )
    }

    func finalCoreConfig() -> BattleConfig {
        BattleConfig(
            id: "final_core",
            title: "無音の核",
            mode: .finalTrue,
            allowedAuraIDs: rootAuras.map { $0.id },
            targetDefeatCount: rootAuras.count * enemyTypes.count,
            playerMaxHP: 150,
            playerMaxMP: 80,
            attackDuration: 1.0,
            enemyHP: 1,
            training: false,
            story: "旧友が待つ無音の核。音視も近道も届かない場所で、見えないまま作ってきた戻る道を確かめる。"
        )
    }

    func startBattle(_ config: BattleConfig) {
        currentBattle = config
        defeatedCount = 0
        playerHP = currentMaxHP()
        playerMP = currentMaxMP()
        attackProgress = 0
        slowUntil = .distantPast
        hintCandidates = []
        hintUntil = .distantPast
        activeHintCandidateCount = nil
        auraHintUntil = .distantPast
        auraHintPressesRemaining = 0
        auraHintMaxPresses = 0
        distanceHintAvailableAt = .distantFuture
        distanceHintExpiresAt = .distantPast
        fatherAdviceIntroPending = false
        lastResult = .ready
        message = config.story
        levelUpText = ""
        levelUpDetailText = ""
        clearResonanceText = ""
        gemRewardText = ""
        gemRewardDetailText = ""
        notebookRecordUnlockText = ""
        skillCooldownUntil.removeAll()
        battleResponseTotal = 0
        battleResponseCount = 0
        autoRegenAccumulator = 0
        riskRegenAccumulator = 0
        battleHadMiss = false
        firstSlowBroken = false
        battleFinished = false
        battleWon = false
        finalCoreDepthText = ""
        keyboardStartPitch = [0, 2, 4, 5, 7, 9, 11].randomElement()
        rebuildEnemyDeck(for: config)
        updateFinalCoreDepthText()
        spawnEnemy()
    }

    func tick(delta: TimeInterval) {
        effectTime = Date()

        guard let config = currentBattle, !battleFinished else { return }
        guard !finalCoreIntermissionActive else { return }

        if config.training == false {
            autoRegenAccumulator += delta
            if autoRegenAccumulator >= 5.0 {
                autoRegenAccumulator = 0
                if traitAutoHPRegen() > 0 {
                    playerHP = min(currentMaxHP(), playerHP + traitAutoHPRegen())
                }
                if traitAutoMPRegen() > 0 {
                    playerMP = min(currentMaxMP(), playerMP + traitAutoMPRegen())
                }
            }

            riskRegenAccumulator += delta
            if riskRegenAccumulator >= 3.0 {
                riskRegenAccumulator = 0
                if traitRiskAutoHPRegen() > 0 {
                    playerHP = min(currentMaxHP(), playerHP + traitRiskAutoHPRegen())
                }
                if traitRiskAutoMPRegen() > 0 {
                    playerMP = min(currentMaxMP(), playerMP + traitRiskAutoMPRegen())
                }
            }
        }

        if let _ = activeHintCandidateCount, Date() > hintUntil {
            activeHintCandidateCount = nil
            hintCandidates = []
        }

        if config.training || !config.enemyAttacks {
            attackProgress = 0
            return
        }

        if isStealthed() {
            return
        }

        let slowFactor = (Date() < slowUntil ? 0.45 : 1.0) * traitAttackSpeedFactor()
        attackProgress += (delta / config.attackDuration) * slowFactor

        if attackProgress >= 1.0 {
            enemyAttack()
        }
    }

    func correctPitchClass() -> Int? {
        guard let enemy = currentEnemy else { return nil }
        return (enemy.aura.pitchClass + enemy.type.semitoneOffset) % 12
    }

    func fatherAdviceText() -> String {
        guard effectTime >= distanceHintAvailableAt,
              effectTime <= distanceHintExpiresAt,
              let enemy = currentEnemy,
              !isStealthed() else { return "" }
        return fatherAdviceLine(for: enemy.type)
    }

    private func fatherAdviceLine(for type: EnemyType) -> String {
        let right = ((type.semitoneOffset % 12) + 12) % 12
        let left = (12 - right) % 12
        let showIntro = fatherAdviceIntroPending

        if right == 0 {
            if !showIntro {
                return "父：動かなくていい。根の音をそのまま選ぼう。".gameLocalized
            }
            return "父：根の音は0。動かない時は、その根の音をそのまま選ぶ。".gameLocalized
        }

        let direction = right <= left ? "右へ\(right)" : "左へ\(left)"
        if !showIntro {
            return "父：根は0。となりを1つ目にして、\(direction)。".gameLocalized
        }
        return "父：根の音は数えない。根は0、となりを1つ目にする。右なら\(right)、左なら\(left)。今回は\(direction)。".gameLocalized
    }

    func currentAuraPitchClass() -> Int? {
        currentEnemy?.aura.pitchClass
    }

    func auraHighlightedPitchClass() -> Int? {
        guard auraHintPressesRemaining > 0 else { return nil }
        return currentAuraPitchClass()
    }

    func enemyDistanceHintText() -> String? {
        nil
    }

    private func distanceText(for type: EnemyType) -> String {
        let right = ((type.semitoneOffset % 12) + 12) % 12
        let left = (12 - right) % 12
        if right == 0 { return "根 / 右0・左0".gameLocalized }
        return "右へ\(right) / 左へ\(left)".gameLocalized
    }

    func displayDistanceText(for type: EnemyType) -> String {
        distanceText(for: type)
    }

    func consumePendingFinalCoreClearStoryEvent() -> Bool {
        guard pendingFinalCoreClearStoryEvent else { return false }
        pendingFinalCoreClearStoryEvent = false
        return true
    }

    func finishFinalCoreClearStoryReturnToTitle() {
        currentBattle = nil
        currentEnemy = nil
        enemyDeck = []
        battleFinished = false
        battleWon = false
        finalCoreIntermissionActive = false
        finalCoreIntermissionText = ""
        finalCoreDepthText = ""
        pendingFinalCoreClearStoryEvent = false
        lastResult = .ready
        message = "港の灯が揺れている。"
    }

    func currentMaxHP() -> Int {
        // Max HP is determined by player level and equipped traits only.
        // It no longer increases just because the player enters a deeper area.
        let raw = leveledMaxHP(base: 100) + traitBonusHP()
        return traitHalvesHPMP() ? max(1, raw / 2) : raw
    }

    func currentMaxMP() -> Int {
        // Max MP is determined by player level and equipped traits only.
        // It no longer increases just because the player enters a deeper area.
        let raw = leveledMaxMP(base: 45) + traitBonusMP()
        return traitHalvesHPMP() ? max(1, raw / 2) : raw
    }

    func tapPitch(_ pitch: Int) {
        guard !finalCoreIntermissionActive else { return }
        if isStealthed() {
            stealthUntil = .distantPast
            message = "気配を解いた"
            return
        }

        guard !battleFinished, let correct = correctPitchClass(), let enemy = currentEnemy else { return }

        TonePlayer.shared.playDyad(rootPitchClass: enemy.aura.pitchClass, keyPitchClass: pitch)
        distanceHintAvailableAt = .distantFuture
        distanceHintExpiresAt = .distantPast
        fatherAdviceIntroPending = false
        registerAuraHintKeyPress()
        let responseTime = max(0.0, Date().timeIntervalSince(currentEnemyStartedAt))

        if pitch == correct {
            recordResponse(for: enemy, responseTime: responseTime, correct: true)
            battleResponseTotal += responseTime
            battleResponseCount += 1
            defeatedCount += 1
            lastResult = .correct
            message = "\(enemy.aura.name) × \(enemy.type.label) を調律"
            recoverMP(traitTuningMPRecovery())
            recoverHP(traitTuningHPRecovery())
            attackProgress = 0
            SoundPlayer.correct()

            updateFinalCoreDepthText()

            if let finalMessage = shouldShowFinalPhaseMessage(afterDefeated: defeatedCount) {
                finalCoreIntermissionText = finalMessage
                finalCoreIntermissionActive = true
                currentEnemy = nil
                attackProgress = 0
                message = "無音の核"
            }

            if let config = currentBattle, defeatedCount >= config.targetDefeatCount {
                clearBattle()
            } else if !finalCoreIntermissionActive {
                spawnEnemy()
            }
        } else {
            recordResponse(for: enemy, responseTime: responseTime, correct: false)
            lastResult = .miss
            message = "MISS"
            SoundPlayer.miss()

            if currentBattle?.training == false {
                damagePlayer(Int.random(in: 2...5), kind: .miss)
                battleHadMiss = true
                firstSlowBroken = true
            }
        }
    }

    private func spawnEnemy() {
        guard let config = currentBattle else { return }

        if enemyDeck.isEmpty {
            rebuildEnemyDeck(for: config)
        }

        guard !enemyDeck.isEmpty else { return }

        let combo = chooseNextCombo(config: config)
        let type = combo.type
        let aura = combo.aura

        currentEnemy = EnemyState(type: type, aura: aura, hp: config.enemyHP)
        currentEnemyStartedAt = Date()
        keyboardStartPitch = [0, 2, 4, 5, 7, 9, 11].randomElement()
        attackProgress = 0
        message = "\(aura.name)のオーラ × \(type.label)"
        TonePlayer.shared.playAura(pitchClass: aura.pitchClass)
        distanceHintAvailableAt = .distantFuture
        distanceHintExpiresAt = .distantPast
        fatherAdviceIntroPending = false
        refreshHintCandidatesIfNeeded()
    }

    func continueFinalCoreBattle() {
        finalCoreIntermissionActive = false
        finalCoreIntermissionText = ""
        if isFinalCoreBattle(currentBattle?.id), !battleFinished {
            spawnEnemy()
        }
    }

    private func finalCorePhase() -> Int {
        guard isFinalCoreBattle(currentBattle?.id) else { return 0 }
        let total = max(1, currentBattle?.targetDefeatCount ?? 132)
        let cleared = defeatedCount
        if cleared < total / 3 { return 1 }
        if cleared < total * 2 / 3 { return 2 }
        return 3
    }

    private func shouldShowFinalPhaseMessage(afterDefeated count: Int) -> String? {
        guard currentBattle?.id == "final_core" else { return nil }
        let total = max(1, currentBattle?.targetDefeatCount ?? 132)

        if count == total / 3 {
            return "旧友は薄く笑った。\n「まだ戻ってくるのか。ここでは音視も近道も役に立たない。見えないまま進むなら、残るのは間違いと反復だけだ。」"
        }

        if count == total * 2 / 3 {
            return "旧友の笑みがわずかに歪む。\n「なぜ止まらない。見えていない者が、なぜここまで戻ってこられる。そんなものは道ではない。ただの反復だ。……なら、俺が沈んだ理由は何だった。」"
        }

        return nil
    }

    private func finalCoreClearScene() -> String {
        "旧友は初めて目を見開いた。\n「見えない者にも、道はあったのか。俺は、戻り方を知らなかっただけか。」\n彼は無音の核へ伸ばしていた手を下ろした。沈黙は世界を覆う力を失った。"
    }

    private func isFinalCoreBattle(_ id: String?) -> Bool {
        id == "final_core" || id == "final_core_hard" || id == "final_core_practice"
    }

    private func chooseNextCombo(config: BattleConfig) -> SpawnCombo {
        if config.id == "weakness_training" {
            return chooseNextWeaknessCombo(config: config)
        }

        if isFinalCoreBattle(config.id) {
            return chooseNextFinalCoreCombo(config: config)
        }

        let hpRatio = Double(playerHP) / Double(max(currentMaxHP(), 1))
        let sortedByDifficulty = enemyDeck.enumerated().sorted { lhs, rhs in
            difficultyScore(for: lhs.element) > difficultyScore(for: rhs.element)
        }
        let poolSize = max(1, Int(ceil(Double(enemyDeck.count) * 0.35)))
        let selectedIndex: Int

        if hpRatio >= 0.70 {
            selectedIndex = sortedByDifficulty.prefix(poolSize).randomElement()?.offset ?? 0
        } else if hpRatio <= 0.30 {
            selectedIndex = sortedByDifficulty.suffix(poolSize).randomElement()?.offset ?? 0
        } else {
            let midStart = max(0, (enemyDeck.count - poolSize) / 2)
            selectedIndex = sortedByDifficulty.dropFirst(midStart).prefix(poolSize).randomElement()?.offset ?? Int.random(in: 0..<enemyDeck.count)
        }

        return enemyDeck.remove(at: selectedIndex)
    }

    private func chooseNextWeaknessCombo(config: BattleConfig) -> SpawnCombo {
        var combos: [SpawnCombo] = []
        for auraID in config.allowedAuraIDs {
            let root = aura(id: auraID)
            for type in enemyTypes {
                combos.append(SpawnCombo(type: type, aura: root))
            }
        }

        guard !combos.isEmpty else {
            return SpawnCombo(type: enemyTypes[0], aura: rootAuras[0])
        }

        let sorted = combos.sorted { lhs, rhs in
            let l = timingValueForPair(auraID: lhs.aura.id, enemyID: lhs.type.id)
            let r = timingValueForPair(auraID: rhs.aura.id, enemyID: rhs.type.id)
            if l == r { return lhs.statKey < rhs.statKey }
            return l > r
        }

        let roll = Double.random(in: 0..<1)
        if roll < 0.35 {
            return sorted[0]
        }
        if roll < 0.60, sorted.count > 1 {
            return sorted[1]
        }
        if roll < 0.75, sorted.count > 2 {
            return sorted[2]
        }
        let fallbackPool = Array(sorted.dropFirst(3).prefix(7))
        return fallbackPool.randomElement() ?? sorted.randomElement() ?? sorted[0]
    }

    private func chooseNextFinalCoreCombo(config: BattleConfig) -> SpawnCombo {
        let phase = finalCorePhase()
        let sorted = enemyDeck.enumerated().sorted { lhs, rhs in
            difficultyScore(for: lhs.element) < difficultyScore(for: rhs.element)
        }

        let count = max(1, enemyDeck.count / 3)
        let easy = Array(sorted.prefix(count))
        let hard = Array(sorted.suffix(count))
        let normalStart = max(0, (sorted.count - count) / 2)
        let normal = Array(sorted.dropFirst(normalStart).prefix(count))

        let roll = Double.random(in: 0...1)
        let pool: [(offset: Int, element: SpawnCombo)]

        switch phase {
        case 1:
            pool = roll < 0.50 ? easy : (roll < 0.85 ? normal : hard)
        case 2:
            pool = roll < 0.25 ? easy : (roll < 0.75 ? normal : hard)
        default:
            pool = roll < 0.10 ? easy : (roll < 0.45 ? normal : hard)
        }

        let selectedIndex = pool.randomElement()?.offset ?? Int.random(in: 0..<enemyDeck.count)
        return enemyDeck.remove(at: selectedIndex)
    }

    private func difficultyScore(for combo: SpawnCombo) -> Double {
        if let performance = comboPerformance[combo.statKey] {
            return performance.difficultyScore
        }

        // 未記録の問題は中程度として扱う。
        switch combo.type.label {
        case "◆":
            return 2.8
        case "2−", "7+":
            return 2.55
        case "6−", "7−":
            return 2.35
        default:
            return 2.10
        }
    }

    private func recordResponse(for enemy: EnemyState, responseTime: TimeInterval, correct: Bool) {
        let key = "\(enemy.aura.id)_\(enemy.type.id)"
        var performance = comboPerformance[key] ?? ComboPerformance(attempts: 0, correct: 0, totalResponseTime: 0, misses: 0)
        performance.attempts += 1

        if correct {
            performance.correct += 1
            performance.totalResponseTime += responseTime
        } else {
            performance.misses += 1
        }

        comboPerformance[key] = performance
        saveComboPerformance()
        recordAnswerTiming(for: enemy, responseTime: responseTime, correct: correct)
    }

    private func recordAnswerTiming(for enemy: EnemyState, responseTime: TimeInterval, correct: Bool) {
        // 基礎記録は「根 × 音の生き物」の132セルだけ。根別・音の生き物別はここから平均算出する。
        let pKey = pairTimingKey(auraID: enemy.aura.id, enemyID: enemy.type.id)
        var pairStat = pairAnswerTiming[pKey] ?? AnswerTimingStat()
        pairStat.update(responseTime: responseTime, correct: correct)
        pairAnswerTiming[pKey] = pairStat

        saveAnswerTimingStats()
    }

    private func rebuildEnemyDeck(for config: BattleConfig) {
        var combos: [SpawnCombo] = []

        for auraID in config.allowedAuraIDs {
            let root = aura(id: auraID)
            for type in enemyTypes {
                combos.append(SpawnCombo(type: type, aura: root))
            }
        }

        enemyDeck = combos.shuffled()
    }

    private enum DamageKind {
        case miss
        case hit
    }

    private func enemyAttack() {
        guard let enemy = currentEnemy else { return }
        let baseDamage = Int.random(in: enemy.type.baseDamage)
        let applied = damagePlayer(baseDamage, kind: .hit)
        attackProgress = 0
        firstSlowBroken = true
        if battleFinished { return }
        lastResult = .enemyAttack
        message = "\(enemy.type.label) の攻撃  -\(applied)"
        SoundPlayer.attack()
    }

    @discardableResult
    private func damagePlayer(_ amount: Int, kind: DamageKind) -> Int {
        var value = Double(max(0, amount))

        if kind == .miss {
            value *= Double(traitMissDamageMultiplier())
            let missGuardLevel = traitPotential("miss_guard")
            if missGuardLevel > 0 { value *= missGuardFactor(missGuardLevel) }
        }

        value *= Double(traitDamageTakenMultiplier())

        let damageGuardLevel = traitPotential("damage_guard")
        if damageGuardLevel > 0 { value *= damageGuardFactor(damageGuardLevel) }

        let firstGuardLevel = traitPotential("first_guard")
        if firstGuardLevel > 0 && !battleHadMiss {
            value -= Double(firstGuardLevel)
        }

        let reduced = max(0, Int(ceil(value)))
        playerHP = max(0, playerHP - reduced)

        if kind == .hit {
            triggerOnHitTraits()
        }

        if playerHP <= 0 {
            battleFinished = true
            battleWon = false
            lastResult = .defeat
            message = "DEFEAT"
            SoundPlayer.defeat()
        }

        return reduced
    }

    private func recoverMP(_ amount: Int) {
        guard amount > 0 else { return }
        playerMP = min(currentMaxMP(), playerMP + amount)
    }

    private func recoverHP(_ amount: Int) {
        guard amount > 0 else { return }
        playerHP = min(currentMaxHP(), playerHP + amount)
    }

    private func triggerOnHitTraits() {
        let slowLevel = traitPotential("hit_slow")
        if slowLevel > 0 {
            hitSlowFactor = hitSlowFactorForLevel(slowLevel)
            hitSlowUntil = Date().addingTimeInterval(8)
        }
    }


    private func rewindAttackBy(seconds: Double) {
        guard seconds > 0, let config = currentBattle else { return }
        let cappedSeconds = min(seconds, config.attackDuration)
        let amount = cappedSeconds / max(config.attackDuration, 0.1)
        attackProgress = max(0, attackProgress - amount)
    }

    func debugClearWithAverage(_ seconds: Double) {
        guard currentBattle != nil else { return }
        battleResponseCount = max(1, maxDefeatedCountForDebug())
        battleResponseTotal = seconds * Double(battleResponseCount)
        clearBattle()
    }

    private func maxDefeatedCountForDebug() -> Int {
        if let config = currentBattle {
            return max(1, config.allowedAuraIDs.count * enemyTypes.count)
        }
        return 1
    }

    private func clearBattle() {
        battleFinished = true
        battleWon = true
        lastResult = .clear
        message = "CLEAR"

        guard let config = currentBattle else { return }

        var firstClear = false
        gemRewardText = ""
        gemRewardDetailText = ""
        if !isFinalCoreBattle(config.id) {
            finalCoreSceneText = ""
        }

        if config.mode == .dungeon {
            for auraID in config.allowedAuraIDs {
                let wasCleared = clearedDungeonAuraIDs.contains(auraID)
                if !wasCleared {
                    firstClear = true
                }
                clearedDungeonAuraIDs.insert(auraID)
                unlockNeighbors(of: auraID)
                applyGemReward(forDungeonID: "aura_\(auraID)", firstClear: !wasCleared)
            }
        }

        if isRecordFeatureUnlocked && !notebookRecordIntroSeen {
            notebookRecordIntroSeen = true
            notebookRecordUnlockText = "父\nここまでの戦いを、手帳に書き足しておいた。\n速く答えられた場所も、時間がかかった場所もある。これは優劣ではなく、戻る場所を探すための記録だ。"
        }

        if config.mode == .multi {
            let rawID = config.id.replacingOccurrences(of: "multi_", with: "")
            let wasCleared = clearedMultiDungeonIDs.contains(rawID)
            if !wasCleared {
                firstClear = true
            }
            clearedMultiDungeonIDs.insert(rawID)
            applyGemReward(forDungeonID: rawID, firstClear: !wasCleared)
        }

        if config.id == "final_core" {
            let wasCleared = clearedFinalCore
            if !wasCleared {
                firstClear = true
                pendingFinalCoreClearStoryEvent = true
            }
            clearedFinalCore = true
            applyGemReward(forDungeonID: "final_core", firstClear: false)
            finalCoreSceneText = finalCoreClearScene()
        } else if config.id == "final_core_hard" {
            firstClear = false
            finalCoreSceneText = "技も特性も使わず、無音の核を越えた。"
        } else if config.id == "final_core_practice" {
            firstClear = false
            finalCoreSceneText = "十二の根と生物の組み合わせを確かめた。"
        }

        clearResonanceText = resonanceTextForClear()

        if firstClear {
            let oldHP = currentMaxHP()
            let oldMP = currentMaxMP()
            playerLevel += 1
            let hpGain = max(0, currentMaxHP() - oldHP)
            let mpGain = max(0, currentMaxMP() - oldMP)
            levelUpText = "LEVEL UP!  Lv \(playerLevel)"
            levelUpDetailText = "最大HP +\(hpGain) / 最大MP +\(mpGain)".gameLocalized
        } else {
            levelUpText = ""
            levelUpDetailText = ""
        }

        saveProgress()
        SoundPlayer.clear()
    }

    private func averageTuningSeconds() -> Double? {
        guard battleResponseCount > 0 else { return nil }
        return battleResponseTotal / Double(battleResponseCount)
    }

    private func resonanceLevelTargetText() -> String {
        guard let average = averageTuningSeconds() else { return "" }
        let sec = String(format: "%.2f", average)
        return "平均調律 \(sec)秒"
    }

    func currentAverageTuningText() -> String {
        guard let average = averageTuningSeconds() else {
            return "残響  --  /  Lv2 4.00秒  Lv3 2.00秒  Lv4 1.00秒  Lv5 0.80秒"
        }

        let sec = String(format: "%.2f", average)
        let next: String
        if average > 4.00 {
            next = "宝玉レベル2まで4.00秒"
        } else if average > 2.00 {
            next = "宝玉レベル3まで2.00秒"
        } else if average > 1.00 {
            next = "宝玉レベル4まで1.00秒"
        } else {
            next = average > 0.80 ? "宝玉レベル4圏内 / Lv5まで0.80秒" : "宝玉レベル5圏内"
        }

        return "残響  平均調律 \(sec)秒  /  \(next)"
    }

    func currentResonanceGaugeProgress() -> Double {
        guard let average = averageTuningSeconds() else { return 0.0 }

        // 4 seconds or slower = near zero, 0.8 seconds or faster = full.
        let progress = (4.0 - average) / 3.2
        return min(1.0, max(0.0, progress))
    }

    private func resonanceTextForClear() -> String {
        resonanceLevelTargetText()
    }

    private func applyGemReward(forDungeonID dungeonID: String, firstClear: Bool) {
        guard let spec = gemSkill(forDungeonID: dungeonID) else { return }

        let currentLevel = gemLevel(for: spec.id)
        let builtIn = spec.id == "root_sight"
        let effectiveCurrentLevel = builtIn ? max(1, currentLevel) : currentLevel

        if !builtIn && (firstClear || currentLevel == 0) {
            let targetLevel = max(1, gemTargetLevelForCurrentClear(currentLevel: 1))
            gemLevels[spec.id] = min(spec.maxLevel, targetLevel)
            if isActiveBattleSkill(spec.id) && !equippedSkillIDs.contains(spec.id) && equippedSkillIDs.count < 5 {
                equippedSkillIDs.append(spec.id)
            }
            let newLevel = gemLevels[spec.id] ?? 1
            gemRewardText = "\(loc("宝玉入手"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(newLevel))"
            gemRewardDetailText = gemRewardDetail(spec: spec, level: newLevel)
            return
        }

        if effectiveCurrentLevel >= spec.maxLevel {
            gemRewardText = "\(loc("宝玉共鳴済"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(effectiveCurrentLevel))"
            gemRewardDetailText = gemRewardDetail(spec: spec, level: effectiveCurrentLevel)
            return
        }

        let targetLevel = gemTargetLevelForCurrentClear(currentLevel: effectiveCurrentLevel)
        let nextLevel = min(spec.maxLevel, max(effectiveCurrentLevel, targetLevel))

        if nextLevel > effectiveCurrentLevel {
            gemLevels[spec.id] = nextLevel
            gemRewardText = gemUpgradeMessage(spec: spec, level: nextLevel)
            gemRewardDetailText = gemRewardDetail(spec: spec, level: nextLevel)
        } else {
            gemRewardText = "\(loc("残響蓄積"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(effectiveCurrentLevel))"
            gemRewardDetailText = gemRewardDetail(spec: spec, level: effectiveCurrentLevel)
        }
    }

    private func gemTargetLevelForCurrentClear(currentLevel: Int) -> Int {
        guard battleResponseCount > 0 else { return currentLevel }

        let average = battleResponseTotal / Double(battleResponseCount)

        if average <= 0.80 {
            return 5
        } else if average <= 1.00 {
            return 4
        } else if average <= 2.00 {
            return 3
        } else if average <= 4.00 {
            return 2
        } else {
            return currentLevel
        }
    }

    private func gemRewardDetail(spec: GemSkillSpec, level: Int) -> String {
        let effect = potentialDetailText(spec)
        return "\(spec.skillName.gameLocalized): \(spec.shortEffect.gameLocalized)\n\(loc("現在Lv"))\(level) / \(skillOneLineText(spec))\n\(effect)"
    }

    private func gemUpgradeMessage(spec: GemSkillSpec, level: Int) -> String {
        switch level {
        case 5:
            return "\(loc("宝玉体得"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(5))"
        case 4:
            return "\(loc("強い共鳴"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(4))"
        case 3:
            return "\(loc("澄んだ共鳴"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(3))"
        case 2:
            return "\(loc("宝玉共鳴"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(2))"
        default:
            return "\(loc("宝玉共鳴"))　\(spec.gemName.gameLocalized) \(localizedGemLevel(level))"
        }
    }

    private func unlockNeighbors(of auraID: Int) {
        guard let aura = rootAuras.first(where: { $0.id == auraID }) else { return }

        let current = aura.circleIndex
        let left = (current + 11) % 12
        let right = (current + 1) % 12

        if let leftAura = rootAuras.first(where: { $0.circleIndex == left }) {
            unlockedAuraIDs.insert(leftAura.id)
        }

        if let rightAura = rootAuras.first(where: { $0.circleIndex == right }) {
            unlockedAuraIDs.insert(rightAura.id)
        }
    }

    private func beginSkillUse(_ skillID: String) -> Bool {
        if currentBattle?.training == true {
            return true
        }

        let remaining = skillCooldownRemaining(skillID)
        if remaining > 0 {
            message = "あと\(remaining)秒".gameLocalized
            SoundPlayer.miss()
            return false
        }

        return true
    }

    private func finishSkillUse(_ skillID: String) {
        guard currentBattle?.training == false else { return }
        guard skillID != "distance_check" else { return }

        let interval = max(1, skillIntervalSeconds(skillID) - traitSkillIntervalReduction())
        skillCooldownUntil[skillID] = Date().addingTimeInterval(TimeInterval(interval))
        rewindAttackBy(seconds: traitSkillUseRewindSeconds())
    }

    func useSlow() {
        guard currentBattle?.training == false else { return }
        guard isSkillUnlocked("slow") else {
            message = skillLockText("slow")
            SoundPlayer.miss()
            return
        }
        guard beginSkillUse("slow") else { return }
        guard spendMP(skillCostDisplay("slow")) else { return }

        slowEffectDuration = skillEffectDuration("slow")
        slowUntil = Date().addingTimeInterval(slowEffectDuration)
        finishSkillUse("slow")
        lastResult = .skill
        message = "減速：敵の拍を遅くした".gameLocalized
        SoundPlayer.skill()
    }

    private func refreshHintCandidatesIfNeeded() {
        guard let count = activeHintCandidateCount,
              Date() <= hintUntil,
              let correct = correctPitchClass()
        else {
            return
        }

        hintCandidates = makeCandidates(count: count, correct: correct)
    }

    func useRootSight() {
        guard isSkillUnlocked("root_sight") else {
            message = skillLockText("root_sight")
            SoundPlayer.miss()
            return
        }
        guard beginSkillUse("root_sight") else { return }
        guard spendMP(skillCostDisplay("root_sight")) else { return }

        auraHintMaxPresses = rootSightPressCapacity()
        auraHintPressesRemaining = auraHintMaxPresses
        auraHintDuration = TimeInterval(max(1, auraHintMaxPresses))
        auraHintUntil = Date().addingTimeInterval(3600)
        finishSkillUse("root_sight")
        lastResult = .skill
        message = "目印：根の鍵を灯した".gameLocalized
        SoundPlayer.skill()
    }

    private func fatherAdviceDelaySeconds() -> TimeInterval {
        switch min(5, max(0, skillGemLevel("distance_check"))) {
        case 5: return 1.2
        case 4: return 1.4
        case 3: return 1.6
        case 2: return 1.8
        default: return 2.0
        }
    }

    func useDistanceCheck() {
        guard isSkillUnlocked("distance_check") else {
            message = skillLockText("distance_check")
            SoundPlayer.miss()
            return
        }

        let introAlreadySeen = UserDefaults.standard.bool(forKey: fatherAdviceIntroSeenKey)
        fatherAdviceIntroPending = !introAlreadySeen
        distanceHintAvailableAt = Date().addingTimeInterval(fatherAdviceDelaySeconds())
        distanceHintExpiresAt = .distantFuture
        lastResult = .skill
        message = "父の助言：少し待つ".gameLocalized
        UserDefaults.standard.set(true, forKey: fatherAdviceIntroSeenKey)
        SoundPlayer.skill()
    }

    private func rootSightPressCapacity() -> Int {
        let base = valueForPotential("root_sight", [5, 6, 7, 8, 9])
        let extended = Int(Double(traitEffectExtensionSeconds()) / 3.0)
        return max(1, base + extended)
    }

    private func registerAuraHintKeyPress() {
        guard auraHintPressesRemaining > 0 else { return }
        auraHintPressesRemaining = max(0, auraHintPressesRemaining - 1)
        if auraHintPressesRemaining == 0 {
            auraHintUntil = .distantPast
            auraHintMaxPresses = 0
        }
    }

    func usePresenceHide() {
        guard currentBattle?.training == false else { return }
        guard isSkillUnlocked("quiet_key") else {
            message = skillLockText("quiet_key")
            SoundPlayer.miss()
            return
        }
        guard beginSkillUse("quiet_key") else { return }
        guard spendMP(skillCostDisplay("quiet_key")) else { return }

        stealthDuration = skillEffectDuration("quiet_key")
        stealthUntil = Date().addingTimeInterval(stealthDuration)
        finishSkillUse("quiet_key")
        lastResult = .skill
        message = "隠れる：敵から隠れた".gameLocalized
        SoundPlayer.skill()
    }

    func isStealthed() -> Bool {
        stealthUntil.timeIntervalSince(effectTime) > 0
    }

    func stealthEffectProgress() -> Double {
        let remaining = stealthUntil.timeIntervalSince(effectTime)
        guard remaining > 0 else { return 0 }
        return min(1.0, max(0.0, remaining / stealthDuration))
    }


    func useHeal() {
        useHealSkill(skillID: "heal", baseMin: 24, baseMax: 38)
    }


    private func useHealSkill(skillID: String, baseMin: Int, baseMax: Int) {
        guard currentBattle?.training == false else { return }
        guard isSkillUnlocked(skillID) else {
            message = skillLockText(skillID)
            SoundPlayer.miss()
            return
        }
        guard beginSkillUse(skillID) else { return }
        guard spendMP(skillCostDisplay(skillID)) else { return }

        let level = max(1, effectivePotential(skillID))
        let bonusPerLevel = 6
        let amount = Int.random(in: (baseMin + bonusPerLevel * (level - 1))...(baseMax + bonusPerLevel * (level - 1))) + traitHealBonus()
        playerHP = min(currentMaxHP(), playerHP + amount)
        finishSkillUse(skillID)
        lastResult = .heal
        message = "\((skillSpec(byID: skillID)?.skillName ?? "回復").gameLocalized) +\(amount)"
        SoundPlayer.heal()
    }

    private func spendMP(_ cost: Int) -> Bool {
        if currentBattle?.training == true {
            return true
        }

        guard playerMP >= cost else {
            message = "MPが足りない".gameLocalized
            SoundPlayer.miss()
            return false
        }

        playerMP -= cost
        return true
    }

    func slowEffectProgress() -> Double {
        let remaining = slowUntil.timeIntervalSince(effectTime)
        guard remaining > 0 else { return 0 }
        return min(1.0, max(0.0, remaining / slowEffectDuration))
    }

    func hintEffectProgress() -> Double {
        guard activeHintCandidateCount != nil else { return 0 }
        let remaining = hintUntil.timeIntervalSince(effectTime)
        guard remaining > 0 else { return 0 }
        return min(1.0, max(0.0, remaining / hintEffectDuration))
    }

    func hintEffectLabel() -> String {
        activeHintCandidateCount == nil ? "" : "候補".gameLocalized
    }

    func auraHintEffectProgress() -> Double {
        guard auraHintPressesRemaining > 0, auraHintMaxPresses > 0 else { return 0 }
        return min(1.0, max(0.0, Double(auraHintPressesRemaining) / Double(auraHintMaxPresses)))
    }

    func auraHintEffectLabel() -> String {
        auraHintPressesRemaining > 0 ? "目印 \(auraHintPressesRemaining)回".gameLocalized : ""
    }

    func finalCoreDepthNumber() -> Int? {
        guard isFinalCoreBattle(currentBattle?.id) else { return nil }
        if defeatedCount < 44 { return 1 }
        if defeatedCount < 88 { return 2 }
        return 3
    }

    func updateFinalCoreDepthText() {
        guard currentBattle?.id == "final_core" else {
            finalCoreDepthText = ""
            return
        }
        let depth = finalCoreDepthNumber() ?? 1
        finalCoreDepthText = "深度 \(depth) / 3".gameLocalized
    }

    private func makeCandidates(count: Int, correct: Int) -> Set<Int> {
        var values: Set<Int> = [correct]

        while values.count < count {
            values.insert(Int.random(in: 0...11))
        }

        return values
    }
}
