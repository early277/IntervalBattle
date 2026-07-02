import SwiftUI
import Darwin
#if os(iOS)
import UIKit
#endif

private enum StoryEventDestination {
    case mapDetail
    case title
}

struct ContentView: View {
    @StateObject private var game = GameModel()
    @State private var screen: AppScreen = .title
    @State private var lastTick = Date()
    @State private var mapScrollOffset: CGPoint = .zero
    @State private var selectedDetailInfo: MapInfo?
    @State private var selectedDetailBattleConfig: BattleConfig?
    @State private var activeStoryEvent: StoryEvent?
    @State private var pendingStoryInfo: MapInfo?
    @State private var pendingStoryBattleConfig: BattleConfig?
    @State private var storyEventDestination: StoryEventDestination = .mapDetail
    @AppStorage("IntervalRouteMVP.lastMapFocusID") private var lastMapFocusID: String = "aura_0"
    @AppStorage("IntervalRouteMVP.seenStoryEvents.v1") private var seenStoryEventsRaw: String = ""

    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            BackgroundView()

            switch screen {
            case .title:
                TitleView {
                    screen = .prologue
                }

            case .prologue:
                PrologueView {
                    screen = .map
                }

            case .storyEvent:
                if let activeStoryEvent {
                    StoryEventPagerView(
                        title: activeStoryEvent.title,
                        backgroundName: activeStoryEvent.backgroundName,
                        pages: activeStoryEvent.pages,
                        finishTitle: (storyEventDestination == .title ? "タイトルへ" : "戦闘前へ").gameLocalized,
                        skipTitle: (storyEventDestination == .title ? "タイトルへ" : "イベントを飛ばす").gameLocalized,
                        finish: finishStoryEvent
                    )
                } else {
                    MapViewFallback(back: { screen = .map })
                }

            case .map:
                MapView(
                    game: game,
                    lastMapFocusID: $lastMapFocusID,
                    mapScrollOffset: $mapScrollOffset,
                    selectAura: { aura in
                        lastMapFocusID = "aura_\(aura.id)"
                        game.selectedAuraID = aura.id
                        screen = .areaDetail
                    },
                    startBattle: { config in
                        if config.id == "final_core" {
                            lastMapFocusID = "final_core"
                        } else if config.id.hasPrefix("multi_") {
                            lastMapFocusID = "dungeon_\(config.id.replacingOccurrences(of: "multi_", with: ""))"
                        }
                        game.startBattle(config)
                        screen = .battle
                    },
                    openCustomize: {
                        screen = .customize
                    },
                    openSilentTraining: {
                        screen = .silentTraining
                    },
                    openArchive: {
                        screen = .archive
                    },
                    openMapDetail: { info, config in
                        openMapDetailWithStory(info: info, config: config)
                    }
                )

            case .mapDetail:
                if let info = selectedDetailInfo {
                    MapDetailView(
                        game: game,
                        info: info,
                        battleConfig: selectedDetailBattleConfig,
                        back: {
                            selectedDetailInfo = nil
                            selectedDetailBattleConfig = nil
                            screen = .map
                        },
                        start: { config in
                            selectedDetailInfo = nil
                            selectedDetailBattleConfig = nil
                            game.startBattle(config)
                            screen = .battle
                        }
                    )
                } else {
                    MapViewFallback(back: { screen = .map })
                }

            case .areaDetail:
                AreaDetailView(
                    game: game,
                    back: { screen = .map },
                    start: { config in
                        game.startBattle(config)
                        screen = .battle
                    }
                )

            case .customize:
                WeaponCustomizeView(
                    game: game,
                    back: { screen = .map }
                )

            case .silentTraining:
                SilentTrainingInfoView(
                    game: game,
                    back: { screen = .map }
                )

            case .archive:
                ArchiveInfoView(
                    game: game,
                    back: { screen = .map },
                    startBattle: { config in
                        game.startBattle(config)
                        screen = .battle
                    }
                )

            case .battle:
                BattleView(game: game) {
                    finishBattleFlow()
                }
                .onReceive(timer) { now in
                    let delta = now.timeIntervalSince(lastTick)
                    lastTick = now
                    game.tick(delta: delta)
                }
                .onAppear {
                    lastTick = Date()
                }
            }
        }
        .onAppear {
            GeneratedBGMManager.shared.stop()
        }
        .onChange(of: screen) { _, _ in
            GeneratedBGMManager.shared.stop()
        }
        .onDisappear {
            GeneratedBGMManager.shared.stop()
        }
    }


    private func applyGeneratedBGM(for screen: AppScreen) {
        GeneratedBGMManager.shared.stop()
    }


    private func selectedAuraPitchClass() -> Int {
        pitchClass(forAuraID: game.selectedAuraID) ?? 0
    }

    private func bgmRootPitchClass(for config: BattleConfig?) -> Int? {
        guard let auraID = config?.allowedAuraIDs.first else { return nil }
        return pitchClass(forAuraID: auraID)
    }

    private func pitchClass(forAuraID auraID: Int) -> Int? {
        game.rootAuras.first(where: { $0.id == auraID })?.pitchClass
    }

    private func bgmTension(for config: BattleConfig?) -> Double {
        guard let config else { return 0.20 }

        switch config.mode {
        case .training:
            return 0.12
        case .dungeon:
            return 0.24
        case .multi:
            let dungeonID = config.id.replacingOccurrences(of: "multi_", with: "")
            let tier = game.multiAuraDungeons.first(where: { $0.id == dungeonID })?.tier ?? config.allowedAuraIDs.count
            return min(0.85, 0.25 + Double(tier) * 0.10)
        case .finalNormal, .finalTrue:
            return 1.0
        }
    }

    private func openMapDetailWithStory(info: MapInfo, config: BattleConfig?) {
        guard let config else {
            selectedDetailInfo = info
            selectedDetailBattleConfig = nil
            screen = .mapDetail
            return
        }

        if let event = oldFriendStoryEvent(for: config), !hasSeenStoryEvent(event.id) {
            pendingStoryInfo = info
            pendingStoryBattleConfig = config
            storyEventDestination = .mapDetail
            activeStoryEvent = event
            screen = .storyEvent
            return
        }

        selectedDetailInfo = info
        selectedDetailBattleConfig = config
        screen = .mapDetail
    }

    private func finishStoryEvent() {
        if let activeStoryEvent {
            markStoryEventSeen(activeStoryEvent.id)
        }

        activeStoryEvent = nil

        switch storyEventDestination {
        case .mapDetail:
            selectedDetailInfo = pendingStoryInfo
            selectedDetailBattleConfig = pendingStoryBattleConfig
            pendingStoryInfo = nil
            pendingStoryBattleConfig = nil
            screen = selectedDetailInfo == nil ? .map : .mapDetail

        case .title:
            selectedDetailInfo = nil
            selectedDetailBattleConfig = nil
            pendingStoryInfo = nil
            pendingStoryBattleConfig = nil
            storyEventDestination = .mapDetail
            game.finishFinalCoreClearStoryReturnToTitle()
            screen = .title
        }
    }

    private func finishBattleFlow() {
        if game.consumePendingFinalCoreClearStoryEvent() {
            activeStoryEvent = StoryEvent.finalCoreClearEvent(backgroundName: "battle_bg_final")
            pendingStoryInfo = nil
            pendingStoryBattleConfig = nil
            selectedDetailInfo = nil
            selectedDetailBattleConfig = nil
            storyEventDestination = .title
            screen = .storyEvent
        } else {
            screen = .map
        }
    }

    private func hasSeenStoryEvent(_ id: StoryEventID) -> Bool {
        seenStoryEventsRaw
            .split(separator: ",")
            .map(String.init)
            .contains(id.rawValue)
    }

    private func markStoryEventSeen(_ id: StoryEventID) {
        var ids = Set(seenStoryEventsRaw.split(separator: ",").map(String.init))
        ids.insert(id.rawValue)
        seenStoryEventsRaw = ids.sorted().joined(separator: ",")
    }

    private func oldFriendStoryEvent(for config: BattleConfig) -> StoryEvent? {
        if config.id == "final_core" {
            return StoryEvent.oldFriendEvent(
                id: .oldFriendAbandonedPath,
                backgroundName: game.battleBackgroundAssetName(for: config)
            )
        }

        guard config.id.hasPrefix("multi_") else {
            return nil
        }

        let dungeonID = config.id.replacingOccurrences(of: "multi_", with: "")
        guard let dungeon = game.multiAuraDungeons.first(where: { $0.id == dungeonID }) else {
            return nil
        }

        switch dungeon.tier {
        case 2:
            return StoryEvent.oldFriendEvent(
                id: .oldFriendFirstContact,
                backgroundName: game.battleBackgroundAssetName(for: config)
            )
        case 4:
            return StoryEvent.oldFriendEvent(
                id: .oldFriendNotSeeing,
                backgroundName: game.battleBackgroundAssetName(for: config)
            )
        case 6:
            return StoryEvent.oldFriendEvent(
                id: .oldFriendRepetition,
                backgroundName: game.battleBackgroundAssetName(for: config)
            )
        default:
            return nil
        }
    }

}

struct BackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.black,
                Color(red: 0.04, green: 0.04, blue: 0.09),
                Color(red: 0.02, green: 0.02, blue: 0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

struct TitleView: View {
    let start: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let contentWidth = max(260, min(proxy.size.width - 44, 420))

            ZStack {
                Image("field_map_bg")
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
                    .opacity(0.46)
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [Color.black.opacity(0.62), Color.black.opacity(0.34), Color.black.opacity(0.72)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 20) {
                    Spacer()

                    Text("音環島の調律".gameLocalized)
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                        .frame(width: contentWidth)

                    Text("見えないまま、戻りながら進む".gameLocalized)
                        .font(.headline)
                        .foregroundStyle(.white.opacity(0.82))
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)
                        .frame(width: contentWidth)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("港の灯が揺れている。".gameLocalized)
                            .font(.body.bold())
                            .foregroundStyle(.white)
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Text("父は古い音鍵を差し出し、答えではなく、戻る場所を忘れないようにと言った。".gameLocalized)
                            .foregroundStyle(.white.opacity(0.86))
                            .lineLimit(nil)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(18)
                    .frame(width: contentWidth, alignment: .leading)
                    .background(Color.black.opacity(0.50))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .clipShape(RoundedRectangle(cornerRadius: 18))

                    Button {
                        start()
                    } label: {
                        Text("はじめる".gameLocalized)
                            .font(.title3.bold())
                            .frame(width: min(300, contentWidth), height: 52)
                    }
                    .buttonStyle(.borderedProminent)

                    Spacer()
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .padding(.vertical, 20)
            }
        }
    }
}

struct ProloguePage: Identifiable {
    let id = UUID()
    let scene: String
    let speaker: String
    let text: String
    let accent: Color
}

enum StoryEventID: String, CaseIterable {
    case oldFriendFirstContact
    case oldFriendNotSeeing
    case oldFriendRepetition
    case oldFriendAbandonedPath
    case finalCoreClear
}

struct StoryEvent: Identifiable {
    let id: StoryEventID
    let title: String
    let backgroundName: String
    let pages: [ProloguePage]

    static func finalCoreClearEvent(backgroundName: String) -> StoryEvent {
        StoryEvent(
            id: .finalCoreClear,
            title: "無音の核：戻るたびに作った道",
            backgroundName: backgroundName,
            pages: [
                ProloguePage(scene: "無音の核", speaker: "父の旧友", text: "見えない者にも、道はあったのか。俺は、戻り方を知らなかっただけか。", accent: .purple),
                ProloguePage(scene: "無音の核", speaker: "父", text: "……やり遂げたんだな。", accent: .orange),
                ProloguePage(scene: "無音の核", speaker: "父", text: "本当は、心のどこかで怖れていた。見えない者が、自由に音へ手を伸ばすことはできないのではないかと。", accent: .orange),
                ProloguePage(scene: "無音の核", speaker: "父", text: "私は方法を信じているつもりだった。でも、本当は最後まで信じきれていなかった。情けない父親だ。", accent: .orange),
                ProloguePage(scene: "無音の核", speaker: "父", text: "それでも、戻り、数え、選び直して、ここまで進んでくれた。", accent: .orange),
                ProloguePage(scene: "無音の核", speaker: "父", text: "最初から道があったわけじゃない。戻るたびに、道にしてきたんだ。", accent: .orange),
                ProloguePage(scene: "無音の核", speaker: "父", text: "その手で奏でる音を聞かせてほしい。惨めに見えた一歩も、迷って戻った時間も、もう自分の音だ。", accent: .orange),
                ProloguePage(scene: "無音の核", speaker: "父", text: "見えないままでいい。もう、選べる場所に立っている。思うままに、鳴らしていい。", accent: .orange)
            ]
        )
    }

    static func oldFriendEvent(id: StoryEventID, backgroundName: String) -> StoryEvent {
        switch id {
        case .finalCoreClear:
            return finalCoreClearEvent(backgroundName: backgroundName)

        case .oldFriendFirstContact:
            return StoryEvent(
                id: id,
                title: "旧友の声：見える者か",
                backgroundName: backgroundName,
                pages: [
                    ProloguePage(scene: "中心へ続く洞", speaker: "父の旧友", text: "そこまで来たか。", accent: .purple),
                    ProloguePage(scene: "中心へ続く洞", speaker: "父の旧友", text: "また音視の子を連れてきたのか。あいつも変わらない。", accent: .purple),
                    ProloguePage(scene: "中心へ続く洞", speaker: "父", text: "この子は、答えを見て進んでいるわけじゃない。", accent: .orange),
                    ProloguePage(scene: "中心へ続く洞", speaker: "父の旧友", text: "なら、なおさら残酷だ。見えない者に、見える者の道を歩かせるのか。", accent: .purple),
                    ProloguePage(scene: "中心へ続く洞", speaker: "父", text: "見える者の道にするつもりはない。戻る道を作っている。", accent: .orange)
                ]
            )

        case .oldFriendNotSeeing:
            return StoryEvent(
                id: id,
                title: "旧友の声：見えていないのか",
                backgroundName: backgroundName,
                pages: [
                    ProloguePage(scene: "四つの根の境目", speaker: "父の旧友", text: "おかしい。", accent: .purple),
                    ProloguePage(scene: "四つの根の境目", speaker: "父の旧友", text: "今の揺れで、見える者なら迷わず抜ける。見えない者なら、そこで止まる。", accent: .purple),
                    ProloguePage(scene: "四つの根の境目", speaker: "父の旧友", text: "お前……見えていないのか。", accent: .purple),
                    ProloguePage(scene: "四つの根の境目", speaker: "父", text: "見えていなくていい。戻る場所を覚えてきた。", accent: .orange),
                    ProloguePage(scene: "四つの根の境目", speaker: "父の旧友", text: "覚えた？　数えた？　そんなものが道になるわけがない。", accent: .purple)
                ]
            )

        case .oldFriendRepetition:
            return StoryEvent(
                id: id,
                title: "旧友の声：ただの反復だ",
                backgroundName: backgroundName,
                pages: [
                    ProloguePage(scene: "六重険路", speaker: "父の旧友", text: "やめろ。", accent: .purple),
                    ProloguePage(scene: "六重険路", speaker: "父の旧友", text: "見えないまま進むな。", accent: .purple),
                    ProloguePage(scene: "六重険路", speaker: "父の旧友", text: "それは道じゃない。ただの反復だ。ただ間違えて、戻って、また間違えるだけだ。", accent: .purple),
                    ProloguePage(scene: "六重険路", speaker: "父", text: "戻れたなら、そこで終わりじゃない。", accent: .orange),
                    ProloguePage(scene: "六重険路", speaker: "父の旧友", text: "なら、俺が沈んだ理由は何だった。", accent: .purple),
                    ProloguePage(scene: "六重険路", speaker: "父の旧友", text: "見えない者が進めるなら、俺が捨てたものは何だった。", accent: .purple)
                ]
            )

        case .oldFriendAbandonedPath:
            return StoryEvent(
                id: id,
                title: "旧友の声：俺が捨てた道",
                backgroundName: backgroundName,
                pages: [
                    ProloguePage(scene: "無音の核の前", speaker: "父の旧友", text: "ここから先に、音視は届かない。", accent: .purple),
                    ProloguePage(scene: "無音の核の前", speaker: "父の旧友", text: "見える者も、見えない者も、同じ沈黙に沈む。", accent: .purple),
                    ProloguePage(scene: "無音の核の前", speaker: "父の旧友", text: "それでようやく、誰も裁かれずに済む。", accent: .purple),
                    ProloguePage(scene: "無音の核の前", speaker: "父", text: "沈黙は休む場所にはなる。でも、すべてを止める場所じゃない。", accent: .orange),
                    ProloguePage(scene: "無音の核の前", speaker: "父の旧友", text: "黙れ。", accent: .purple),
                    ProloguePage(scene: "無音の核の前", speaker: "父の旧友", text: "お前は、俺が捨てた道を歩いてきたのか。", accent: .purple)
                ]
            )
        }
    }
}

struct StoryEventPagerView: View {
    let title: String
    let backgroundName: String
    let pages: [ProloguePage]
    let finishTitle: String
    let skipTitle: String
    let finish: () -> Void

    @State private var index = 0

    private var page: ProloguePage {
        pages[min(index, max(0, pages.count - 1))]
    }

    private var speakerAccent: Color {
        StoryEventPagerView.accentColor(for: page.speaker)
    }

    private static func accentColor(for speaker: String) -> Color {
        if speaker.contains("旧友") {
            return Color(red: 0.48, green: 0.38, blue: 0.86)
        }
        return Color(red: 0.86, green: 0.50, blue: 0.18)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Image(backgroundName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    header
                        .padding(.top, 20)
                        .padding(.horizontal, 18)

                    Spacer(minLength: 12)

                    dialoguePanel(maxWidth: min(660, max(260, geometry.size.width - 36)))
                        .padding(.horizontal, 18)
                        .onTapGesture {
                            advance()
                        }

                    Spacer(minLength: 12)

                    footerButtons
                        .padding(.horizontal, 18)
                        .padding(.bottom, 10)
                }
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title.gameLocalized)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.82))
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)

                Text(page.scene.gameLocalized)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Text("\(index + 1)/\(pages.count)")
                .font(.caption.bold().monospaced())
                .foregroundStyle(.white.opacity(0.62))

            Button(skipTitle.gameLocalized) {
                finish()
            }
            .font(.caption.bold())
            .buttonStyle(.bordered)
            .controlSize(.regular)
        }
    }

    private func dialoguePanel(maxWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(page.speaker.gameLocalized)
                .font(.headline.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(speakerAccent.opacity(0.62))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.leading, 18)
                .padding(.bottom, -2)
                .zIndex(1)

            VStack(alignment: .leading, spacing: 18) {
                Text(page.text.gameLocalized)
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.leading)
                    .lineLimit(nil)
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 24)
            .frame(width: maxWidth, alignment: .leading)
            .background(
                LinearGradient(
                    colors: [speakerAccent.opacity(0.30), Color.black.opacity(0.43)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(speakerAccent.opacity(0.48), lineWidth: 1.2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .frame(width: maxWidth, alignment: .leading)
        .shadow(color: .black.opacity(0.28), radius: 12, x: 0, y: 6)
    }

    private var footerButtons: some View {
        VStack(spacing: 10) {
            Button((index == pages.count - 1 ? finishTitle : "次へ進む").gameLocalized) {
                advance()
            }
            .font(.title3.bold())
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .frame(height: 58)

            HStack(spacing: 12) {
                Button("戻る".gameLocalized) {
                    index = max(0, index - 1)
                }
                .font(.headline.bold())
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(index == 0)
                .frame(maxWidth: .infinity)
                .frame(height: 52)

                Button(skipTitle.gameLocalized) {
                    finish()
                }
                .font(.headline.bold())
                .buttonStyle(.bordered)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
        }
    }

    private func advance() {
        if index == pages.count - 1 {
            finish()
        } else {
            index += 1
        }
    }
}

struct PrologueView: View {
    let finish: () -> Void

    private let pages: [ProloguePage] = [
        ProloguePage(
            scene: "灯火港",
            speaker: "父",
            text: "この音鍵は、答えを教える道具じゃない。",
            accent: .orange
        ),
        ProloguePage(
            scene: "灯火港",
            speaker: "父",
            text: "見えなくても、帰る場所さえあれば選び直せる。まずはCへ戻るところから始めよう。",
            accent: .orange
        ),
        ProloguePage(
            scene: "古い音鍵",
            speaker: "父の旧友",
            text: "またそれを持たせるのか。見える者の道具を、見えない者に握らせて何になる。",
            accent: .purple
        ),
        ProloguePage(
            scene: "古い音鍵",
            speaker: "父",
            text: "同じ使い方はしない。見えなくても、一音ずつ戻る道は作れる。",
            accent: .orange
        ),
        ProloguePage(
            scene: "すれ違い",
            speaker: "父の旧友",
            text: "見えない者が数え続けても、誰も待たなかった。外せば、足りないのは心だと言われた。",
            accent: .purple
        ),
        ProloguePage(
            scene: "すれ違い",
            speaker: "父",
            text: "だから、急がせたくない。戻って選び直す時間を残したいんだ。",
            accent: .orange
        ),
        ProloguePage(
            scene: "中心へ向かう影",
            speaker: "父の旧友",
            text: "俺は中心へ行く。見える者も、見えない者も、同じ沈黙に沈める。音がなければ、もう誰も裁かれない。",
            accent: .purple
        ),
        ProloguePage(
            scene: "中心へ向かう影",
            speaker: "父",
            text: "それは救いじゃない。音を止めれば、選び直す場所まで消えてしまう。",
            accent: .orange
        ),
        ProloguePage(
            scene: "封じられた音",
            speaker: "父の旧友",
            text: "お前の調律は、もういらない。そこで見ていろ。音が残る限り、また誰かが裁かれる。",
            accent: .purple
        ),
        ProloguePage(
            scene: "封じられた音",
            speaker: "父",
            text: "……調律の音が出ない。根へ戻すための音まで、封じられたか。",
            accent: .orange
        ),
        ProloguePage(
            scene: "出発",
            speaker: "父",
            text: "あの人は中心へ向かった。音環島を沈黙で覆うつもりだ。私はこの音では進めない。港から順に、一音ずつ確かめよう。迷ったら、戻ればいい。戻ることは、後退じゃない。",
            accent: .orange
        ),
        ProloguePage(
            scene: "父の手帳",
            speaker: "父",
            text: "最後に、これを持っていってほしい。古い書物に、音の生き物の姿は載っていなかった。書かれていたのは、根の音、音の距離、響きの型。今では忘れられかけた、音の扱い方だ。",
            accent: .orange
        ),
        ProloguePage(
            scene: "父の手帳",
            speaker: "父",
            text: "それを、島にいる音の生き物たちの姿と照らし合わせてきた。どの姿が、根からどれだけ離れた音なのか。少しずつ書き留めた。",
            accent: .orange
        ),
        ProloguePage(
            scene: "父の手帳",
            speaker: "父",
            text: "これは答えを先に教えるものではない。迷ったとき、戻る場所を思い出すための手帳だ。",
            accent: .orange
        )
    ]

    var body: some View {
        StoryEventPagerView(
            title: "プロローグ",
            backgroundName: "battle_bg_root_c",
            pages: pages,
            finishTitle: "出発する",
            skipTitle: "すぐ地図へ",
            finish: finish
        )
    }
}

struct SilentTrainingRecord: Codable, Hashable {
    var attempts: Int = 0
    var correct: Int = 0
    var totalResponseTime: Double = 0
    var misses: Int = 0

    var averageResponseTime: Double {
        guard correct > 0 else { return 0 }
        return totalResponseTime / Double(correct)
    }

    var accuracy: Double {
        guard attempts > 0 else { return 0 }
        return Double(correct) / Double(attempts)
    }
}

struct SilentTrainingInfoView: View {
    @ObservedObject var game: GameModel
    let back: () -> Void

    @State private var selectedAuraID: Int = 0
    @State private var currentEnemyID: String = "enemy_5"
    @State private var startedAt: Date = Date()
    @State private var message: String = "音を選ぶと、次の問いへ進みます。"
    @State private var records: [String: SilentTrainingRecord] = [:]
    @State private var showAnswer: Bool = false
    @State private var lastResponseSeconds: Double?

    private let storageKey = "IntervalRouteMVP.silentTraining.records.v1"

    private var selectedAura: RootAura {
        game.rootAuras.first { $0.id == selectedAuraID } ?? game.rootAuras[0]
    }

    private var currentEnemy: EnemyType {
        game.enemyTypes.first { $0.id == currentEnemyID } ?? game.enemyTypes[0]
    }

    private var correctPitch: Int {
        (selectedAura.pitchClass + currentEnemy.semitoneOffset) % 12
    }

    private var selectedAuraRecords: [SilentTrainingRecord] {
        game.enemyTypes.map { records[recordKey(auraID: selectedAura.id, enemyID: $0.id)] ?? SilentTrainingRecord() }
    }

    private var totalAttempts: Int {
        selectedAuraRecords.reduce(0) { $0 + $1.attempts }
    }

    private var totalCorrect: Int {
        selectedAuraRecords.reduce(0) { $0 + $1.correct }
    }

    private var averageSeconds: Double {
        let totalTime = selectedAuraRecords.reduce(0.0) { $0 + $1.totalResponseTime }
        guard totalCorrect > 0 else { return 0 }
        return totalTime / Double(totalCorrect)
    }

    private var accuracy: Double {
        guard totalAttempts > 0 else { return 0 }
        return Double(totalCorrect) / Double(totalAttempts)
    }

    private var returnScore: Double {
        guard averageSeconds > 0 else { return 0 }
        return 100.0 * (1.0 / averageSeconds) * accuracy
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("地図へ".gameLocalized) { back() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Spacer()

                Text("無音稽古".gameLocalized)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Spacer()

                Button("記録消去".gameLocalized) {
                    records = [:]
                    saveRecords()
                    message = "稽古記録を消しました。"
                    lastResponseSeconds = nil
                    nextQuestion()
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding(.top, 26)

            Text("父の助言、技、HP、MP、敗北なし。見えないまま戻る力だけを測る稽古。".gameLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)

            AuraTrainingSelector(game: game, selectedAuraID: $selectedAuraID) {
                nextQuestion()
            }

            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    StatPill(title: "稽古", value: "\(totalAttempts)")
                    StatPill(title: "正答率", value: totalAttempts == 0 ? "--" : String(format: "%.0f%%", accuracy * 100))
                    StatPill(title: "平均", value: averageSeconds == 0 ? "--" : String(format: "%.2fs", averageSeconds))
                    StatPill(title: "帰還度", value: returnScore == 0 ? "--" : String(format: "%.0f", returnScore))
                }

                VStack(spacing: 12) {
                    Text("\(selectedAura.name) から".gameLocalized)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(currentEnemy.label)
                        .font(.system(size: 62, weight: .black, design: .monospaced))
                        .foregroundStyle(.white)
                        .shadow(color: selectedAura.color.opacity(0.7), radius: 16)

                    Text("五度環距離 \(currentEnemy.circle)　/　答えを自分で選ぶ".gameLocalized)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Text(message.gameLocalized)
                        .font(.headline.bold())
                        .foregroundStyle(showAnswer ? .mint : .white.opacity(0.90))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .frame(minHeight: 44)

                    if let lastResponseSeconds {
                        Text(GameLocalization.format("直前: %.2f秒", lastResponseSeconds))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(18)
                .background(Color.black.opacity(0.34))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(selectedAura.color.opacity(0.30), lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 20))
            }

            OneOctaveKeyboardView(
                candidates: showAnswer ? [correctPitch] : [],
                auraPitchClass: selectedAura.pitchClass,
                keyboardStartPitch: nil,
                onTap: { pitch in
                    answer(pitch)
                }
            )
            .frame(height: 160)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .onAppear {
            loadRecords()
            selectedAuraID = game.rootAuras.first?.id ?? 0
            nextQuestion()
        }
        .onChange(of: selectedAuraID) { _, _ in
            message = "音を選ぶと、次の問いへ進みます。"
            lastResponseSeconds = nil
            nextQuestion()
        }
    }

    private func answer(_ pitch: Int) {
        guard !showAnswer else { return }

        let seconds = max(0.0, Date().timeIntervalSince(startedAt))
        lastResponseSeconds = seconds
        TonePlayer.shared.playDyad(rootPitchClass: selectedAura.pitchClass, keyPitchClass: pitch)

        let key = recordKey(auraID: selectedAura.id, enemyID: currentEnemy.id)
        var record = records[key] ?? SilentTrainingRecord()
        record.attempts += 1

        if pitch == correctPitch {
            record.correct += 1
            record.totalResponseTime += seconds
            message = "正解。\(selectedAura.name)へ戻って、次へ。"
            SoundPlayer.correct()
        } else {
            record.misses += 1
            message = "違う音。答えは \(pitchName(correctPitch))。戻って選び直す。"
            SoundPlayer.miss()
        }

        records[key] = record
        saveRecords()
        showAnswer = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            nextQuestion()
        }
    }

    private func nextQuestion() {
        guard !game.enemyTypes.isEmpty else { return }

        let sorted = game.enemyTypes.sorted { left, right in
            weaknessScore(left) > weaknessScore(right)
        }
        let candidates = Array(sorted.prefix(min(4, sorted.count)))
        currentEnemyID = candidates.randomElement()?.id ?? game.enemyTypes[0].id
        startedAt = Date()
        showAnswer = false
    }

    private func weaknessScore(_ enemy: EnemyType) -> Double {
        let r = records[recordKey(auraID: selectedAura.id, enemyID: enemy.id)] ?? SilentTrainingRecord()
        if r.attempts == 0 { return 1000 }
        let missRate = 1.0 - r.accuracy
        let avg = r.averageResponseTime == 0 ? 3.0 : r.averageResponseTime
        let lowCountBonus = max(0.0, 6.0 - Double(r.attempts)) * 0.25
        return avg + missRate * 2.0 + lowCountBonus
    }

    private func recordKey(auraID: Int, enemyID: String) -> String {
        "\(auraID)_\(enemyID)"
    }

    private func loadRecords() {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: SilentTrainingRecord].self, from: data) else {
            records = [:]
            return
        }
        records = decoded
    }

    private func saveRecords() {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func pitchName(_ pitch: Int) -> String {
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][((pitch % 12) + 12) % 12]
    }
}

struct AuraTrainingSelector: View {
    @ObservedObject var game: GameModel
    @Binding var selectedAuraID: Int
    let changed: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(game.rootAuras) { aura in
                    Button {
                        selectedAuraID = aura.id
                        changed()
                    } label: {
                        Text(aura.name)
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 34)
                            .background(selectedAuraID == aura.id ? aura.color.opacity(0.82) : Color.white.opacity(0.10))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
        }
    }
}

struct StatPill: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title.gameLocalized)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.bold().monospaced())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct ArchiveInfoView: View {
    @ObservedObject var game: GameModel
    let back: () -> Void
    let startBattle: (BattleConfig) -> Void

    @State private var tab: ArchiveTab = .handbook
    @State private var selectedAuraID: Int = 0

    private enum ArchiveTab: String, CaseIterable {
        case handbook = "使い方"
        case creatures = "生物録"
        case harmony = "響き"
        case records = "記録"
    }

    private var selectedAura: RootAura {
        game.rootAuras.first { $0.id == selectedAuraID } ?? game.rootAuras[0]
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button("地図へ".gameLocalized) { back() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                Spacer()

                Text("父の手帳".gameLocalized)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Spacer()

                Text("手帳".gameLocalized)
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(.mint)
            }
            .padding(.top, 26)

            Picker("表示".gameLocalized, selection: $tab) {
                ForEach(ArchiveTab.allCases, id: \.self) { item in
                    Text(item.rawValue.gameLocalized).tag(item)
                }
            }
            .pickerStyle(.segmented)

            AuraTrainingSelector(game: game, selectedAuraID: $selectedAuraID) {}

            ScrollView {
                VStack(spacing: 12) {
                    switch tab {
                    case .handbook:
                        HandbookSection(game: game)
                    case .creatures:
                        CreatureArchiveSection(game: game, aura: selectedAura)
                    case .harmony:
                        HarmonyArchiveSection(game: game, aura: selectedAura)
                    case .records:
                        RecordArchiveSection(game: game, startBattle: startBattle)
                    }
                }
                .padding(.bottom, 18)
            }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 8)
        .onAppear {
            selectedAuraID = game.rootAuras.first?.id ?? 0
        }
    }
}

struct HandbookSection: View {
    @ObservedObject var game: GameModel

    var body: some View {
        VStack(spacing: 12) {
            ArchiveCard(
                title: "この手帳について",
                subtitle: "古い書物と島の音をつなぐための覚え書き",
                text: "私は古い書物を読み解き、その中に残っていた根の音、音の距離、響きの型を、島の音の生き物たちと照らし合わせて書き留めた。古い書物に生き物の姿はない。だが、戻るための手がかりは確かに残っていた。迷ったときは、答えを探すより先に、この頁へ戻ってほしい。",
                accent: .mint
            )

            ArchiveCard(
                title: "助言と手立て",
                subtitle: "迷ったときに戻るための備え",
                text: "助言：迷ったときに呼びなさい。すぐには言わず、二拍ほど待ってから、根から右へいくつ・左へいくつかを言葉にする。\n減速：敵の拍をゆるめ、考える間を作る。\n隠れる：攻めをやり過ごし、立て直す。\n回復：傷を浅いうちに戻す。MPを整えておけば、これらも使いやすくなる。",
                accent: .cyan
            )

            ArchiveCard(
                title: "宝玉と特性",
                subtitle: "抱える宝玉で身のこなしが変わる",
                text: "宝玉は、戦い方の癖を少しずつ変えるためのものだ。特性には重さがあり、抱えすぎると身のこなしが鈍る。強く働く宝玉ほど扱いは難しいが、噛み合えば心強い支えになる。",
                accent: .orange
            )

            ArchiveCard(
                title: "鍵盤の見方",
                subtitle: "端はつながっている",
                text: "鍵盤は端で切れているように見えても、実際にはひと回りしてつながっている。右端に同じ音を置いてあるのは、その戻り方を見失わないためだ。黒鍵の二つ並び、三つ並びも、今どこにいるかを知る目印として使うといい。",
                accent: .yellow
            )
        }
    }
}


func intervalFlavorText(for enemy: EnemyType) -> String {
    switch ((enemy.semitoneOffset % 12) + 12) % 12 {
    case 1:
        return "根にごく近い影が生まれ、強くぶつかる音。"
    case 2:
        return "根のすぐ先へ進む、軽く開いた音。"
    case 3:
        return "根に影を添える、少し沈んだ音。"
    case 4:
        return "根を明るく照らす、はっきりした音。"
    case 5:
        return "根を少し浮かせる、待っているような音。"
    case 6:
        return "根から最も遠く張りつめる、不安定な音。"
    case 7:
        return "根を広く支える、安定した音。"
    case 8:
        return "根から遠く沈む、濃い影を持つ音。"
    case 9:
        return "根から広がる、柔らかく明るい音。"
    case 10:
        return "根から少し外へ流れる、落ち着いた緊張の音。"
    case 11:
        return "根のすぐ手前で張りつめる、遠い光のような音。"
    default:
        return "根そのものとして響く音。"
    }
}

struct CreatureArchiveSection: View {
    @ObservedObject var game: GameModel
    let aura: RootAura

    var body: some View {
        ForEach(game.enemyTypes) { enemy in
            let answer = pitchName((aura.pitchClass + enemy.semitoneOffset) % 12)
            HStack(spacing: 12) {
                CreatureIcon(enemy: enemy, accent: aura.color)
                    .frame(width: 74, height: 74)

                VStack(alignment: .leading, spacing: 5) {
                    Text(enemy.label.gameLocalized)
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                    Text("距離 \(game.displayDistanceText(for: enemy)) / 五度環 \(enemy.circle)".gameLocalized)
                        .font(.caption.bold())
                        .foregroundStyle(aura.color)
                    Text("\(aura.name.gameLocalized) と \(answer) を一緒に鳴らすと、\(intervalFlavorText(for: enemy).gameLocalized)".gameLocalized)
                        .font(.callout)
                        .foregroundStyle(.white.opacity(0.86))
                        .lineSpacing(3)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(Color.black.opacity(0.34))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(aura.color.opacity(0.24), lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                TonePlayer.shared.playArchiveInterval(
                    rootPitchClass: aura.pitchClass,
                    semitoneOffset: enemy.semitoneOffset
                )
            }
        }
    }

    private func pitchName(_ pitch: Int) -> String {
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][((pitch % 12) + 12) % 12]
    }
}

struct HarmonyArchiveSection: View {
    @ObservedObject var game: GameModel
    let aura: RootAura
    @State private var filterMinus: Int? = nil
    @State private var filterPlus: Int? = nil
    @State private var displayMode: ArchiveDisplayMode = .compact
    @State private var toneOrder: HarmonyToneOrder = .circle
    @State private var keyFilterPitchClass: Int? = nil
    @State private var allowedOutOfKeyCount: Int = 0
    @State private var searchAllRoots: Bool = false

    private var canSearchAllRoots: Bool {
        keyFilterPitchClass != nil
    }

    private var effectiveSearchAllRoots: Bool {
        canSearchAllRoots && searchAllRoots
    }

    private enum ArchiveDisplayMode: String, CaseIterable {
        case compact = "簡易"
        case detail = "詳細"
        case list = "一覧"
    }

    private enum HarmonyToneOrder: String, CaseIterable {
        case circle = "種類順"
        case pitch = "高さ順"
    }

    private struct HarmonyExample: Identifiable {
        let id = UUID()
        let name: String
        let reading: String
        let notationTemplates: [String]
        let offsets: [Int]
        let note: String
        let chordRootOffset: Int

        init(
            name: String,
            reading: String,
            notationTemplates: [String],
            offsets: [Int],
            note: String,
            chordRootOffset: Int = 0
        ) {
            self.name = name
            self.reading = reading
            self.notationTemplates = notationTemplates
            self.offsets = offsets
            self.note = note
            self.chordRootOffset = chordRootOffset
        }
    }

    private struct ClassificationSpan {
        let minus: Int
        let plus: Int
    }

    private struct HarmonyDisplayTone: Identifiable {
        let id: String
        let offset: Int
        let circle: Int
    }

    private struct HarmonySearchItem: Identifiable {
        let id: String
        let example: HarmonyExample
        let aura: RootAura
    }

    private let examples: [HarmonyExample] = [
        // Chords: triads and basic colors
        HarmonyExample(name: "メジャー", reading: "メジャー", notationTemplates: ["{R}", "{R}maj", "{R}M"], offsets: [0, 4, 7], note: "明るく安定した三つのまとまり。"),
        HarmonyExample(name: "マイナー", reading: "マイナー", notationTemplates: ["{R}m", "{R}min", "{R}-"], offsets: [0, 3, 7], note: "暗く沈むが、根へ戻る力は残る。"),
        HarmonyExample(name: "パワーコード", reading: "パワーコード", notationTemplates: ["{R}5", "{R}(no3)"], offsets: [0, 7], note: "根と五度だけの骨格。三度を置かない。"),
        HarmonyExample(name: "サス2", reading: "サスツー", notationTemplates: ["{R}sus2", "{R}2"], offsets: [0, 2, 7], note: "三度を置かず、開いた響きにする。"),
        HarmonyExample(name: "サス4", reading: "サスフォー", notationTemplates: ["{R}sus4", "{R}4"], offsets: [0, 5, 7], note: "四度で浮かせ、解決を待つ響き。"),
        HarmonyExample(name: "ディミニッシュ", reading: "ディミニッシュ", notationTemplates: ["{R}dim", "{R}°"], offsets: [0, 3, 6], note: "狭く緊張した三つのまとまり。"),
        HarmonyExample(name: "オーギュメント", reading: "オーギュメント", notationTemplates: ["{R}aug", "{R}+"], offsets: [0, 4, 8], note: "広がり続ける不安定な響き。"),
        HarmonyExample(name: "6", reading: "シックス", notationTemplates: ["{R}6"], offsets: [0, 4, 7, 9], note: "メジャーに六度を足した柔らかい響き。"),
        HarmonyExample(name: "m6", reading: "マイナーシックス", notationTemplates: ["{R}m6", "{R}min6"], offsets: [0, 3, 7, 9], note: "マイナーに六度を足した影のある響き。"),
        HarmonyExample(name: "add9", reading: "アドナイン", notationTemplates: ["{R}add9", "{R}add2"], offsets: [0, 2, 4, 7], note: "メジャーに二度の光を足す。"),
        HarmonyExample(name: "m add9", reading: "マイナーアドナイン", notationTemplates: ["{R}m(add9)", "{R}madd9", "{R}min(add9)"], offsets: [0, 2, 3, 7], note: "マイナーに二度の余韻を足す。"),
        HarmonyExample(name: "6/9", reading: "シックスナイン", notationTemplates: ["{R}6/9", "{R}69"], offsets: [0, 2, 4, 7, 9], note: "六度と二度を足した広いメジャーの響き。"),
        HarmonyExample(name: "m6/9", reading: "マイナーシックスナイン", notationTemplates: ["{R}m6/9", "{R}min6/9"], offsets: [0, 2, 3, 7, 9], note: "短三度に六度と二度を加える。"),

        // Chords: sevenths
        HarmonyExample(name: "メジャー7", reading: "メジャーセブン", notationTemplates: ["{R}maj7", "{R}M7", "{R}△7"], offsets: [0, 4, 7, 11], note: "明るさの上に遠い七度を置く。"),
        HarmonyExample(name: "マイナー7", reading: "マイナーセブン", notationTemplates: ["{R}m7", "{R}min7", "{R}-7"], offsets: [0, 3, 7, 10], note: "沈んだ三度と柔らかい七度。"),
        HarmonyExample(name: "7", reading: "セブン", notationTemplates: ["{R}7", "{R}dom7"], offsets: [0, 4, 7, 10], note: "外へ進もうとする力を持つ響き。"),
        HarmonyExample(name: "mMaj7", reading: "マイナーメジャーセブン", notationTemplates: ["{R}mMaj7", "{R}mM7", "{R}minMaj7"], offsets: [0, 3, 7, 11], note: "暗さと遠い七度が同居する響き。"),
        HarmonyExample(name: "m7♭5", reading: "マイナーセブンフラットファイブ", notationTemplates: ["{R}m7♭5", "{R}ø", "{R}half-dim"], offsets: [0, 3, 6, 10], note: "不安定な五度を含む細い道。"),
        HarmonyExample(name: "dim7", reading: "ディミニッシュセブン", notationTemplates: ["{R}dim7", "{R}°7"], offsets: [0, 3, 6, 9], note: "等間隔に沈む緊張した響き。"),
        HarmonyExample(name: "7sus4", reading: "セブンサスフォー", notationTemplates: ["{R}7sus4", "{R}sus7"], offsets: [0, 5, 7, 10], note: "七度を持ったまま四度で浮かせる。"),
        HarmonyExample(name: "7sus2", reading: "セブンサスツー", notationTemplates: ["{R}7sus2"], offsets: [0, 2, 7, 10], note: "七度と二度で開いた緊張を作る。"),
        HarmonyExample(name: "7♭5", reading: "セブンフラットファイブ", notationTemplates: ["{R}7♭5", "{R}7-5"], offsets: [0, 4, 6, 10], note: "五度を狭めた不安定な七度。"),
        HarmonyExample(name: "7♯5", reading: "セブンシャープファイブ", notationTemplates: ["{R}7♯5", "{R}7+5", "{R}aug7"], offsets: [0, 4, 8, 10], note: "五度を広げ、解決感を強くする。"),
        HarmonyExample(name: "Maj7♯5", reading: "メジャーセブンシャープファイブ", notationTemplates: ["{R}maj7♯5", "{R}M7+5"], offsets: [0, 4, 8, 11], note: "増五度と長七度が浮遊感を作る。"),

        // On chords / inversions. Offsets are measured from the bass note selected below.
        HarmonyExample(name: "メジャー/3", reading: "メジャー・サンドベース", notationTemplates: ["{CR}/{R}", "{CR}maj/{R}", "{CR}M/{R}"], offsets: [0, 3, 8], note: "三度を低く置き、根の明るさを少し浮かせる。", chordRootOffset: 8),
        HarmonyExample(name: "メジャー/5", reading: "メジャー・ゴドベース", notationTemplates: ["{CR}/{R}", "{CR}maj/{R}", "{CR}M/{R}"], offsets: [0, 5, 9], note: "五度を低く置き、安定感を強める。", chordRootOffset: 5),
        HarmonyExample(name: "マイナー/♭3", reading: "マイナー・サンドベース", notationTemplates: ["{CR}m/{R}", "{CR}min/{R}", "{CR}-/{R}"], offsets: [0, 4, 9], note: "短三度を低く置いたマイナーの転回。", chordRootOffset: 9),
        HarmonyExample(name: "マイナー/5", reading: "マイナー・ゴドベース", notationTemplates: ["{CR}m/{R}", "{CR}min/{R}"], offsets: [0, 5, 8], note: "五度を低く置いたマイナーの転回。", chordRootOffset: 5),
        HarmonyExample(name: "7/3", reading: "セブン・サンドベース", notationTemplates: ["{CR}7/{R}", "{CR}dom7/{R}"], offsets: [0, 3, 6, 8], note: "三度を低く置き、七度の進行感を強める。", chordRootOffset: 8),
        HarmonyExample(name: "7/5", reading: "セブン・ゴドベース", notationTemplates: ["{CR}7/{R}", "{CR}dom7/{R}"], offsets: [0, 3, 5, 9], note: "五度を低く置いたセブンスの転回。", chordRootOffset: 5),
        HarmonyExample(name: "7/♭7", reading: "セブン・ナナドベース", notationTemplates: ["{CR}7/{R}", "{CR}dom7/{R}"], offsets: [0, 2, 6, 9], note: "七度を低く置き、解決へ向かう力を強める。", chordRootOffset: 2),
        HarmonyExample(name: "Maj7/3", reading: "メジャーセブン・サンドベース", notationTemplates: ["{CR}maj7/{R}", "{CR}M7/{R}", "{CR}△7/{R}"], offsets: [0, 3, 7, 8], note: "三度を低く置いたメジャーセブン。", chordRootOffset: 8),
        HarmonyExample(name: "Maj7/5", reading: "メジャーセブン・ゴドベース", notationTemplates: ["{CR}maj7/{R}", "{CR}M7/{R}", "{CR}△7/{R}"], offsets: [0, 4, 5, 9], note: "五度を低く置いたメジャーセブン。", chordRootOffset: 5),
        HarmonyExample(name: "Maj7/7", reading: "メジャーセブン・ナナドベース", notationTemplates: ["{CR}maj7/{R}", "{CR}M7/{R}", "{CR}△7/{R}"], offsets: [0, 1, 5, 8], note: "長七度を低く置いた、浮遊感の強い転回。", chordRootOffset: 1),
        HarmonyExample(name: "m7/♭3", reading: "マイナーセブン・サンドベース", notationTemplates: ["{CR}m7/{R}", "{CR}min7/{R}"], offsets: [0, 4, 7, 9], note: "短三度を低く置いたマイナーセブン。", chordRootOffset: 9),
        HarmonyExample(name: "m7/5", reading: "マイナーセブン・ゴドベース", notationTemplates: ["{CR}m7/{R}", "{CR}min7/{R}"], offsets: [0, 3, 5, 8], note: "五度を低く置いたマイナーセブン。", chordRootOffset: 5),
        HarmonyExample(name: "m7/♭7", reading: "マイナーセブン・ナナドベース", notationTemplates: ["{CR}m7/{R}", "{CR}min7/{R}"], offsets: [0, 2, 5, 9], note: "短七度を低く置いた、柔らかいマイナーの転回。", chordRootOffset: 2),
        HarmonyExample(name: "sus4/5", reading: "サスフォー・ゴドベース", notationTemplates: ["{CR}sus4/{R}", "{CR}4/{R}"], offsets: [0, 5, 10], note: "五度を低く置き、四度の浮遊感を支える。", chordRootOffset: 5),
        HarmonyExample(name: "add9/3", reading: "アドナイン・サンドベース", notationTemplates: ["{CR}add9/{R}", "{CR}add2/{R}"], offsets: [0, 3, 8, 10], note: "三度を低く置き、二度の余韻を広げる。", chordRootOffset: 8),
        HarmonyExample(name: "dim/♭5", reading: "ディミニッシュ・ゴドベース", notationTemplates: ["{CR}dim/{R}", "{CR}°/{R}"], offsets: [0, 6, 9], note: "不安定な五度を下に置き、緊張を強める。", chordRootOffset: 6),

        // On chords: classification coverage for rare filter spans.
        HarmonyExample(name: "5/♭7", reading: "ファイブ・ナナドベース", notationTemplates: ["{CR}5/{R}", "{CR}(no3)/{R}"], offsets: [0, 2, 9], note: "根の下に柔らかい七度を置く、開いたオンコード。", chordRootOffset: 2),
        HarmonyExample(name: "7sus4/4", reading: "セブンサスフォー・ヨンドベース", notationTemplates: ["{CR}7sus4/{R}", "{CR}sus7/{R}"], offsets: [0, 2, 5, 7], note: "四度を低く置き、浮いた響きを下から支える。", chordRootOffset: 7),
        HarmonyExample(name: "7♯9/♭7", reading: "セブンシャープナイン・ナナドベース", notationTemplates: ["{CR}7♯9/{R}", "{CR}7(#9)/{R}"], offsets: [0, 2, 5, 6, 9], note: "鋭い九度を含む強い色を、低い七度で支える。", chordRootOffset: 2),
        HarmonyExample(name: "m add9/4", reading: "マイナーアドナイン・ヨンドベース", notationTemplates: ["{CR}m(add9)/{R}", "{CR}madd9/{R}"], offsets: [0, 2, 7, 9, 10], note: "短い影と二度の余韻を、四度下から見た響き。", chordRootOffset: 7),
        HarmonyExample(name: "5/6", reading: "ファイブ・ロクドベース", notationTemplates: ["{CR}5/{R}", "{CR}(no3)/{R}"], offsets: [0, 3, 10], note: "六度を低く置き、少ない音で影を作るオンコード。", chordRootOffset: 3),
        HarmonyExample(name: "7/♭2", reading: "セブン・ニドベース", notationTemplates: ["{CR}7/{R}", "{CR}dom7/{R}"], offsets: [0, 3, 6, 9, 11], note: "近い根を低く置き、強い解決感を作る。", chordRootOffset: 11),
        HarmonyExample(name: "7♯9/5", reading: "セブンシャープナイン・ゴドベース", notationTemplates: ["{CR}7♯9/{R}", "{CR}7(#9)/{R}"], offsets: [0, 3, 5, 8, 9], note: "五度を低く置き、変化した九度の色を前に出す。", chordRootOffset: 5),
        HarmonyExample(name: "m6/♭2", reading: "マイナーシックス・ニドベース", notationTemplates: ["{CR}m6/{R}", "{CR}min6/{R}"], offsets: [0, 2, 6, 8, 11], note: "近い根を低く置いた、沈み込みの強いマイナーシックス。", chordRootOffset: 11),
        HarmonyExample(name: "7♯9/2", reading: "セブンシャープナイン・ニドベース", notationTemplates: ["{CR}7♯9/{R}", "{CR}7(#9)/{R}"], offsets: [0, 1, 2, 5, 8, 10], note: "二度を低く置き、近い影と鋭い九度を重ねる。", chordRootOffset: 10),
        HarmonyExample(name: "aug/7", reading: "オーギュメント・ナナドベース", notationTemplates: ["{CR}aug/{R}", "{CR}+/{R}"], offsets: [0, 1, 5, 9], note: "七度を低く置き、広がり続ける響きを浮かせる。", chordRootOffset: 1),
        HarmonyExample(name: "6/♭3", reading: "シックス・サンドベース", notationTemplates: ["{CR}6/{R}"], offsets: [0, 1, 4, 6, 9], note: "三度を低く置き、明るさに濁りを混ぜる。", chordRootOffset: 9),
        HarmonyExample(name: "mMaj7/6", reading: "マイナーメジャーセブン・ロクドベース", notationTemplates: ["{CR}mMaj7/{R}", "{CR}mM7/{R}"], offsets: [0, 2, 3, 6, 10], note: "六度を低く置き、暗さと遠い七度を張り詰めさせる。", chordRootOffset: 3),
        HarmonyExample(name: "m6/♭5", reading: "マイナーシックス・ゴドベース", notationTemplates: ["{CR}m6/{R}", "{CR}min6/{R}"], offsets: [0, 1, 3, 6, 9], note: "不安定な五度を低く置いた、硬いマイナーシックス。", chordRootOffset: 6),
        HarmonyExample(name: "6/♭2", reading: "シックス・ニドベース", notationTemplates: ["{CR}6/{R}"], offsets: [0, 3, 6, 8, 11], note: "近い根を低く置き、六度の明るさを遠くに置く。", chordRootOffset: 11),

        // Chords: tensions
        HarmonyExample(name: "9", reading: "ナイン", notationTemplates: ["{R}9", "{R}7(9)"], offsets: [0, 2, 4, 7, 10], note: "7に二度を重ねた広い響き。"),
        HarmonyExample(name: "Maj9", reading: "メジャーナイン", notationTemplates: ["{R}maj9", "{R}M9", "{R}△9"], offsets: [0, 2, 4, 7, 11], note: "メジャー7に二度を重ねた澄んだ響き。"),
        HarmonyExample(name: "m9", reading: "マイナーナイン", notationTemplates: ["{R}m9", "{R}min9", "{R}-9"], offsets: [0, 2, 3, 7, 10], note: "マイナー7に二度を重ねる。"),
        HarmonyExample(name: "7♭9", reading: "セブンフラットナイン", notationTemplates: ["{R}7♭9", "{R}7(b9)"], offsets: [0, 1, 4, 7, 10], note: "根のすぐ隣に強い緊張を置く。"),
        HarmonyExample(name: "7♯9", reading: "セブンシャープナイン", notationTemplates: ["{R}7♯9", "{R}7(#9)"], offsets: [0, 3, 4, 7, 10], note: "長三度と鋭い九度がぶつかる響き。"),
        HarmonyExample(name: "9sus4", reading: "ナインサスフォー", notationTemplates: ["{R}9sus4", "{R}11sus"], offsets: [0, 2, 5, 7, 10], note: "二度、四度、七度で浮かせる。"),
        HarmonyExample(name: "11", reading: "イレブン", notationTemplates: ["{R}11", "{R}7(11)"], offsets: [0, 4, 5, 7, 10], note: "7に四度の浮遊感を足す。"),
        HarmonyExample(name: "m11", reading: "マイナーイレブン", notationTemplates: ["{R}m11", "{R}min11"], offsets: [0, 2, 3, 5, 7, 10], note: "短三度を保ったまま二度と四度を加える。"),
        HarmonyExample(name: "13", reading: "サーティーン", notationTemplates: ["{R}13", "{R}7(13)"], offsets: [0, 4, 7, 9, 10], note: "7に六度の色を足す。"),
        HarmonyExample(name: "Maj13", reading: "メジャーサーティーン", notationTemplates: ["{R}maj13", "{R}M13", "{R}△13"], offsets: [0, 2, 4, 7, 9, 11], note: "メジャー7に広い色を重ねる。"),
        HarmonyExample(name: "m13", reading: "マイナーサーティーン", notationTemplates: ["{R}m13", "{R}min13"], offsets: [0, 2, 3, 7, 9, 10], note: "マイナーに六度の明るさを混ぜる。"),
        HarmonyExample(name: "7♭13", reading: "セブンフラットサーティーン", notationTemplates: ["{R}7♭13", "{R}7(b13)"], offsets: [0, 4, 7, 8, 10], note: "七度に暗い六度を重ねる。"),
        HarmonyExample(name: "Maj7♯11", reading: "メジャーセブンシャープイレブン", notationTemplates: ["{R}maj7♯11", "{R}M7(#11)"], offsets: [0, 4, 6, 7, 11], note: "明るさの中に浮いた四度を置く。"),
        HarmonyExample(name: "7♯11", reading: "セブンシャープイレブン", notationTemplates: ["{R}7♯11", "{R}7(#11)"], offsets: [0, 4, 6, 7, 10], note: "7に浮いた四度を足す。"),
        HarmonyExample(name: "オルタード7", reading: "オルタードセブン", notationTemplates: ["{R}7alt", "{R}7 altered"], offsets: [0, 1, 3, 4, 6, 8, 10], note: "変化した音を多く含む、強く解決したい響き。"),

        // Scales: core and modes
        HarmonyExample(name: "メジャースケール", reading: "メジャースケール", notationTemplates: ["{R} major", "{R} Ionian", "{R}メジャー"], offsets: [0, 2, 4, 5, 7, 9, 11], note: "七つの足場を持つ広い道。"),
        HarmonyExample(name: "ナチュラルマイナー", reading: "ナチュラルマイナー", notationTemplates: ["{R} natural minor", "{R} Aeolian", "{R}m scale"], offsets: [0, 2, 3, 5, 7, 8, 10], note: "自然な短調の道。"),
        HarmonyExample(name: "ハーモニックマイナー", reading: "ハーモニックマイナー", notationTemplates: ["{R} harmonic minor", "{R} HM"], offsets: [0, 2, 3, 5, 7, 8, 11], note: "短調に強い導きを作る。"),
        HarmonyExample(name: "メロディックマイナー", reading: "メロディックマイナー", notationTemplates: ["{R} melodic minor", "{R} MM"], offsets: [0, 2, 3, 5, 7, 9, 11], note: "短三度を持ちながら上へ伸びる道。"),
        HarmonyExample(name: "ドリアン", reading: "ドリアン", notationTemplates: ["{R} Dorian", "{R}ドリアン"], offsets: [0, 2, 3, 5, 7, 9, 10], note: "短調に明るい六度が残る道。"),
        HarmonyExample(name: "フリジアン", reading: "フリジアン", notationTemplates: ["{R} Phrygian", "{R}フリジアン"], offsets: [0, 1, 3, 5, 7, 8, 10], note: "根のすぐ隣に影を置く道。"),
        HarmonyExample(name: "リディアン", reading: "リディアン", notationTemplates: ["{R} Lydian", "{R}リディアン"], offsets: [0, 2, 4, 6, 7, 9, 11], note: "四度を持ち上げ、浮いた明るさを作る。"),
        HarmonyExample(name: "ミクソリディアン", reading: "ミクソリディアン", notationTemplates: ["{R} Mixolydian", "{R}ミクソリディアン"], offsets: [0, 2, 4, 5, 7, 9, 10], note: "メジャーに柔らかい七度を置く。"),
        HarmonyExample(name: "ロクリアン", reading: "ロクリアン", notationTemplates: ["{R} Locrian", "{R}ロクリアン"], offsets: [0, 1, 3, 5, 6, 8, 10], note: "不安定な五度を含む細い道。"),
        HarmonyExample(name: "リディアン・ドミナント", reading: "リディアン・ドミナント", notationTemplates: ["{R} Lydian dominant", "{R} Mixolydian #11"], offsets: [0, 2, 4, 6, 7, 9, 10], note: "浮いた四度と柔らかい七度を併せ持つ。"),
        HarmonyExample(name: "フリジアン・ドミナント", reading: "フリジアン・ドミナント", notationTemplates: ["{R} Phrygian dominant", "{R} Spanish Phrygian"], offsets: [0, 1, 4, 5, 7, 8, 10], note: "近い影と長三度が強い色を作る。"),

        // Scales: pentatonic/blues/symmetric/other
        HarmonyExample(name: "メジャーペンタ", reading: "メジャーペンタ", notationTemplates: ["{R} major pentatonic", "{R} pentatonic major"], offsets: [0, 2, 4, 7, 9], note: "五つの足場で明るく動く。"),
        HarmonyExample(name: "マイナーペンタ", reading: "マイナーペンタ", notationTemplates: ["{R} minor pentatonic", "{R} pentatonic minor"], offsets: [0, 3, 5, 7, 10], note: "五つの足場で沈んだ動きを作る。"),
        HarmonyExample(name: "メジャーブルース", reading: "メジャーブルース", notationTemplates: ["{R} major blues"], offsets: [0, 2, 3, 4, 7, 9], note: "メジャーペンタに揺らぎを足す。"),
        HarmonyExample(name: "マイナーブルース", reading: "マイナーブルース", notationTemplates: ["{R} blues", "{R} minor blues"], offsets: [0, 3, 5, 6, 7, 10], note: "マイナーペンタに揺らぎを加える。"),
        HarmonyExample(name: "ホールトーン", reading: "ホールトーン", notationTemplates: ["{R} whole tone", "{R} WT"], offsets: [0, 2, 4, 6, 8, 10], note: "全て同じ幅で進む浮遊した道。"),
        HarmonyExample(name: "コンビネーション・ディミニッシュ", reading: "コンビネーション・ディミニッシュ", notationTemplates: ["{R} H-W diminished", "{R} half-whole diminished", "{R}コンディミ"], offsets: [0, 1, 3, 4, 6, 7, 9, 10], note: "半音と全音が交互に現れる緊張した道。"),
        HarmonyExample(name: "ディミニッシュスケール", reading: "ディミニッシュスケール", notationTemplates: ["{R} W-H diminished", "{R} whole-half diminished"], offsets: [0, 2, 3, 5, 6, 8, 9, 11], note: "全音と半音が交互に現れる対称的な道。"),
        HarmonyExample(name: "オルタード", reading: "オルタード", notationTemplates: ["{R} altered", "{R} super Locrian"], offsets: [0, 1, 3, 4, 6, 8, 10], note: "変化音が多く、強い解決を求める道。"),
        HarmonyExample(name: "ビバップ・ドミナント", reading: "ビバップ・ドミナント", notationTemplates: ["{R} bebop dominant"], offsets: [0, 2, 4, 5, 7, 9, 10, 11], note: "ミクソリディアンに通過音を加えた道。"),
        HarmonyExample(name: "ビバップ・メジャー", reading: "ビバップ・メジャー", notationTemplates: ["{R} bebop major"], offsets: [0, 2, 4, 5, 7, 8, 9, 11], note: "メジャーに通過音を加えた道。"),
        HarmonyExample(name: "ハーモニックメジャー", reading: "ハーモニックメジャー", notationTemplates: ["{R} harmonic major"], offsets: [0, 2, 4, 5, 7, 8, 11], note: "メジャーの中に暗い六度を置く。"),
        HarmonyExample(name: "ダブルハーモニック", reading: "ダブルハーモニック", notationTemplates: ["{R} double harmonic", "{R} Byzantine"], offsets: [0, 1, 4, 5, 7, 8, 11], note: "近い影と長三度、遠い七度を持つ強い色。"),
        HarmonyExample(name: "インセン", reading: "インセン", notationTemplates: ["{R} in-sen", "{R} Insen"], offsets: [0, 1, 5, 7, 10], note: "狭い二度と四度を持つ静かな五音。"),
        HarmonyExample(name: "ヨナ抜き長音階", reading: "ヨナヌキチョウオンカイ", notationTemplates: ["{R} major pentatonic", "{R}ヨナ抜き長音階"], offsets: [0, 2, 4, 7, 9], note: "四度と七度を抜いた明るい五音。"),
        HarmonyExample(name: "ヨナ抜き短音階", reading: "ヨナヌキタンオンカイ", notationTemplates: ["{R} minor pentatonic", "{R}ヨナ抜き短音階"], offsets: [0, 3, 5, 7, 10], note: "二度と六度を抜いた暗い五音。"),
        HarmonyExample(name: "クロマティック", reading: "クロマティック", notationTemplates: ["{R} chromatic", "{R}半音階"], offsets: [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11], note: "十二の全てを並べた道。")
    ]

    var body: some View {
        VStack(spacing: 8) {
            classificationSearchControls

            if filteredItems.isEmpty {
                Text("この分類に一致する項目はありません".gameLocalized)
                    .font(.callout.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.black.opacity(0.28))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            ForEach(filteredItems) { item in
                let span = classificationSpan(for: item.example.offsets)
                switch displayMode {
                case .compact:
                    compactCard(for: item.example, span: span, itemAura: item.aura)
                case .detail:
                    detailCard(for: item.example, span: span, itemAura: item.aura)
                case .list:
                    listRow(for: item.example, itemAura: item.aura)
                }
            }
        }
    }

    private func listRow(for example: HarmonyExample, itemAura: RootAura) -> some View {
        let tonesByCircle = fixedCircleTonesByColumn(for: example)

        return HStack(alignment: .center, spacing: 3) {
            Text(primaryNotationText(for: example, rootAura: itemAura))
                .font(.caption.bold().monospaced())
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.50)
                .frame(width: 82, alignment: .leading)

            HStack(spacing: 1) {
                ForEach(fixedCircleColumns, id: \.self) { circle in
                    HarmonyCreatureColumnCell(
                        isPresent: tonesByCircle[circle] != nil,
                        isRoot: tonesByCircle[circle]?.offset == 0,
                        enemy: tonesByCircle[circle].flatMap { game.enemyType(forSemitoneOffset: $0.offset) },
                        accent: itemAura.color
                    )
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(itemAura.color.opacity(0.18), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            playExample(example, rootPitchClass: itemAura.pitchClass)
        }
    }

    private func compactCard(for example: HarmonyExample, span: ClassificationSpan, itemAura: RootAura) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(notationText(for: example, rootAura: itemAura))
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                Spacer(minLength: 4)
                Text(example.reading.gameLocalized)
                    .font(.caption2.bold())
                    .foregroundStyle(itemAura.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }

            ClassificationGaugeView(minus: span.minus, plus: span.plus, compact: true)
                .frame(height: 24)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 4)], spacing: 4) {
                ForEach(displayTones(for: example)) { tone in
                    HarmonyCreatureCell(
                        noteName: pitchName((itemAura.pitchClass + tone.offset) % 12),
                        enemy: game.enemyType(forSemitoneOffset: tone.offset),
                        distance: distanceLabel(offset: tone.offset),
                        accent: itemAura.color,
                        compact: true
                    )
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(itemAura.color.opacity(0.20), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            playExample(example, rootPitchClass: itemAura.pitchClass)
        }
    }

    private func detailCard(for example: HarmonyExample, span: ClassificationSpan, itemAura: RootAura) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(notationText(for: example, rootAura: itemAura))
                    .font(.headline.bold())
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.70)
                Text("読み：\(example.reading.gameLocalized)".gameLocalized)
                    .font(.caption.bold())
                    .foregroundStyle(itemAura.color)
            }

            ClassificationGaugeView(minus: span.minus, plus: span.plus)
                .frame(height: 32)
                .padding(.top, 2)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 66), spacing: 6)], spacing: 6) {
                ForEach(displayTones(for: example)) { tone in
                    HarmonyCreatureCell(
                        noteName: pitchName((itemAura.pitchClass + tone.offset) % 12),
                        enemy: game.enemyType(forSemitoneOffset: tone.offset),
                        distance: distanceLabel(offset: tone.offset),
                        accent: itemAura.color
                    )
                }
            }

            Text(example.note.gameLocalized)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.84))
        }
        .padding(10)
        .background(Color.black.opacity(0.34))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(itemAura.color.opacity(0.24), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            playExample(example, rootPitchClass: itemAura.pitchClass)
        }
    }

    private func playExample(_ example: HarmonyExample, rootPitchClass: Int) {
        TonePlayer.shared.playArchiveHarmony(
            rootPitchClass: rootPitchClass,
            offsets: example.offsets,
            isScale: isScaleExample(example)
        )
    }

    private func isScaleExample(_ example: HarmonyExample) -> Bool {
        let scaleNames: Set<String> = [
            "メジャースケール", "ナチュラルマイナー", "ハーモニックマイナー", "メロディックマイナー",
            "ドリアン", "フリジアン", "リディアン", "ミクソリディアン", "ロクリアン",
            "リディアン・ドミナント", "フリジアン・ドミナント",
            "メジャーペンタ", "マイナーペンタ", "メジャーブルース", "マイナーブルース",
            "ホールトーン", "コンビネーション・ディミニッシュ", "ディミニッシュスケール",
            "オルタード", "ビバップ・ドミナント", "ビバップ・メジャー",
            "ハーモニックメジャー", "ダブルハーモニック", "インセン",
            "ヨナ抜き長音階", "ヨナ抜き短音階", "クロマティック"
        ]
        return scaleNames.contains(example.name)
    }

    private let maxDisplayedHarmonyItems = 300

    private var matchingItems: [HarmonySearchItem] {
        let targetAuras = effectiveSearchAllRoots ? game.rootAuras : [aura]
        return targetAuras.flatMap { itemAura in
            examples.compactMap { example in
                let span = classificationSpan(for: example.offsets)
                let minusOK = filterMinus.map { span.minus == $0 } ?? true
                let plusOK = filterPlus.map { span.plus == $0 } ?? true
                let keyOK = keyFilterPitchClass.map { keyPitch in
                    outOfKeyCount(for: example, rootPitchClass: itemAura.pitchClass, keyPitchClass: keyPitch) <= allowedOutOfKeyCount
                } ?? true
                guard minusOK && plusOK && keyOK else { return nil }
                return HarmonySearchItem(
                    id: "\(itemAura.id)-\(example.id.uuidString)",
                    example: example,
                    aura: itemAura
                )
            }
        }
    }

    private var filteredItems: [HarmonySearchItem] {
        Array(matchingItems.prefix(maxDisplayedHarmonyItems))
    }

    private var totalHarmonyItemCount: Int {
        matchingItems.count
    }

    private var classificationSearchControls: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Picker("表示".gameLocalized, selection: $displayMode) {
                    ForEach(ArchiveDisplayMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue.gameLocalized).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 156)

                Picker("並び".gameLocalized, selection: displayMode == .list ? .constant(HarmonyToneOrder.circle) : $toneOrder) {
                    ForEach(HarmonyToneOrder.allCases, id: \.self) { order in
                        Text(order.rawValue.gameLocalized).tag(order)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 132)
                .disabled(displayMode == .list)
                .opacity(displayMode == .list ? 0.55 : 1.0)

                Button("全て".gameLocalized) {
                    filterMinus = nil
                    filterPlus = nil
                    keyFilterPitchClass = nil
                    allowedOutOfKeyCount = 0
                    searchAllRoots = false
                }
                .font(.caption.bold())
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack(spacing: 8) {
                if canSearchAllRoots {
                    Button((searchAllRoots ? "すべての根" : "この根だけ").gameLocalized) {
                        searchAllRoots.toggle()
                    }
                    .font(.caption.bold())
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Menu {
                    Button("調指定なし".gameLocalized) {
                        keyFilterPitchClass = nil
                        searchAllRoots = false
                    }
                    ForEach(0..<12, id: \.self) { pitch in
                        Button("\(pitchName(pitch))調".gameLocalized) {
                            keyFilterPitchClass = pitch
                        }
                    }
                } label: {
                    Label(keyFilterText, systemImage: "music.note.list")
                        .font(.caption.bold())
                        .lineLimit(1)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Stepper("調外 \(allowedOutOfKeyCount)音まで".gameLocalized, value: $allowedOutOfKeyCount, in: 0...7)
                    .font(.caption2.bold())
                    .foregroundStyle(keyFilterPitchClass == nil ? .secondary : aura.color)
                    .disabled(keyFilterPitchClass == nil)

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Text("分類 \(filterMinusText.gameLocalized) / \(filterPlusText.gameLocalized)".gameLocalized)
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(aura.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Spacer(minLength: 0)

                Text((totalHarmonyItemCount > maxDisplayedHarmonyItems ? "表示 \(filteredItems.count)/\(totalHarmonyItemCount) 上限" : "表示 \(filteredItems.count)/\(totalHarmonyItemCount)").gameLocalized)
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(totalHarmonyItemCount > maxDisplayedHarmonyItems ? .orange : .secondary)
            }

            DualClassificationFilterBar(
                minus: $filterMinus,
                plus: $filterPlus,
                accent: aura.color
            )
            .frame(height: 46)
        }
        .padding(9)
        .background(Color.black.opacity(0.30))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(aura.color.opacity(0.20), lineWidth: 1))
    }

    private var filterMinusText: String {
        filterMinus.map { $0 == 0 ? "0" : "-\($0)" } ?? "全て".gameLocalized
    }

    private var filterPlusText: String {
        filterPlus.map { $0 == 0 ? "0" : "+\($0)" } ?? "全て".gameLocalized
    }

    private var keyFilterText: String {
        guard let keyFilterPitchClass else { return "調指定なし".gameLocalized }
        return "\(pitchName(keyFilterPitchClass))調".gameLocalized
    }

    private func sliderIndex(for value: Int?) -> Int {
        guard let value else { return 0 }
        return min(7, max(1, value + 1))
    }

    private func filterValue(fromSliderIndex index: Int) -> Int? {
        let clamped = min(7, max(0, index))
        if clamped == 0 { return nil }
        return clamped - 1
    }

    private var fixedCircleColumns: [Int] {
        Array(-6...6)
    }

    private func fixedCircleTonesByColumn(for example: HarmonyExample) -> [Int: HarmonyDisplayTone] {
        var tonesByColumn: [Int: HarmonyDisplayTone] = [:]
        let tritoneCircles = tritoneDisplayCircles(for: example.offsets)

        for (index, offset) in example.offsets.enumerated() {
            let normalized = normalizedOffset(offset)
            if normalized == 6 {
                for circle in tritoneCircles {
                    tonesByColumn[circle] = HarmonyDisplayTone(id: "list-\(index)-\(circle)", offset: offset, circle: circle)
                }
            } else {
                let circle = circleValue(for: normalized)
                tonesByColumn[circle] = HarmonyDisplayTone(id: "list-\(index)-\(circle)", offset: offset, circle: circle)
            }
        }

        return tonesByColumn
    }

    private func primaryNotationText(for example: HarmonyExample, rootAura: RootAura) -> String {
        guard let template = example.notationTemplates.first else { return "" }
        return notationText(from: template, for: example, rootAura: rootAura)
    }

    private func notationText(for example: HarmonyExample, rootAura: RootAura) -> String {
        example.notationTemplates
            .map { notationText(from: $0, for: example, rootAura: rootAura) }
            .joined(separator: " / ")
    }

    private func notationText(from template: String, for example: HarmonyExample, rootAura: RootAura) -> String {
        var text = template
            .replacingOccurrences(of: "{CR}", with: pitchName(rootAura.pitchClass + example.chordRootOffset))
            .replacingOccurrences(of: "{R}", with: rootAura.name)
        let replacements: [String: Int] = [
            "{b2}": 1, "{2}": 2, "{m3}": 3, "{3}": 4,
            "{4}": 5, "{b5}": 6, "{#4}": 6, "{5}": 7,
            "{#5}": 8, "{b6}": 8, "{6}": 9, "{b7}": 10, "{7}": 11
        ]
        for (key, offset) in replacements {
            text = text.replacingOccurrences(of: key, with: pitchName(rootAura.pitchClass + offset))
        }
        return text
    }

    private func displayTones(for example: HarmonyExample) -> [HarmonyDisplayTone] {
        var tones: [HarmonyDisplayTone] = []
        let tritoneCircles = toneOrder == .circle ? tritoneDisplayCircles(for: example.offsets) : [6]

        for (index, offset) in example.offsets.enumerated() {
            let normalized = ((offset % 12) + 12) % 12
            if normalized == 6 && toneOrder == .circle {
                for circle in tritoneCircles {
                    tones.append(HarmonyDisplayTone(id: "\(index)-\(circle)", offset: offset, circle: circle))
                }
            } else {
                tones.append(HarmonyDisplayTone(id: "\(index)-\(normalized)", offset: offset, circle: circleValue(for: normalized)))
            }
        }

        switch toneOrder {
        case .circle:
            return tones.sorted { lhs, rhs in
                if lhs.circle == rhs.circle {
                    return normalizedOffset(lhs.offset) < normalizedOffset(rhs.offset)
                }
                return lhs.circle < rhs.circle
            }
        case .pitch:
            return tones.sorted { lhs, rhs in
                if normalizedOffset(lhs.offset) == normalizedOffset(rhs.offset) {
                    return lhs.circle < rhs.circle
                }
                return normalizedOffset(lhs.offset) < normalizedOffset(rhs.offset)
            }
        }
    }

    private func tritoneDisplayCircles(for offsets: [Int]) -> [Int] {
        let normalized = offsets.map { ((($0 % 12) + 12) % 12) }
        guard normalized.contains(6) else { return [6] }

        let nonTritoneValues = normalized
            .filter { $0 != 6 }
            .map { circleValue(for: $0) }

        let plusCount = nonTritoneValues.filter { $0 > 0 }.count
        let minusCount = nonTritoneValues.filter { $0 < 0 }.count

        if plusCount > minusCount {
            return [6]
        } else if minusCount > plusCount {
            return [-6]
        } else {
            return [-6, 6]
        }
    }

    private func distanceLabel(offset: Int) -> String {
        guard let enemy = game.enemyType(forSemitoneOffset: offset) else { return "根 / 右0・左0".gameLocalized }
        return game.displayDistanceText(for: enemy)
    }

    private func classificationSpan(for offsets: [Int]) -> ClassificationSpan {
        let normalized = offsets.map { ((($0 % 12) + 12) % 12) }
        var circleValues = normalized.map { circleValue(for: $0) }

        let hasTritone = normalized.contains(6)
        if hasTritone {
            circleValues.removeAll { $0 == 6 }
            let plusCount = circleValues.filter { $0 > 0 }.count
            let minusCount = circleValues.filter { $0 < 0 }.count
            if plusCount > minusCount {
                circleValues.append(6)
            } else if minusCount > plusCount {
                circleValues.append(-6)
            } else {
                circleValues.append(6)
                circleValues.append(-6)
            }
        }

        let plus = circleValues.filter { $0 > 0 }.max() ?? 0
        let minus = abs(circleValues.filter { $0 < 0 }.min() ?? 0)
        return ClassificationSpan(minus: minus, plus: plus)
    }

    private func outOfKeyCount(for example: HarmonyExample, rootPitchClass: Int, keyPitchClass: Int) -> Int {
        let keyPitches = Set([0, 2, 4, 5, 7, 9, 11].map { normalizedOffset(keyPitchClass + $0) })
        let chordPitches = Set(example.offsets.map { normalizedOffset(rootPitchClass + $0) })
        return chordPitches.filter { !keyPitches.contains($0) }.count
    }

    private func normalizedOffset(_ value: Int) -> Int {
        let result = value % 12
        return result >= 0 ? result : result + 12
    }

    private func circleValue(for offset: Int) -> Int {
        switch ((offset % 12) + 12) % 12 {
        case 0: return 0
        case 1: return -5
        case 2: return 2
        case 3: return -3
        case 4: return 4
        case 5: return -1
        case 6: return 6
        case 7: return 1
        case 8: return -4
        case 9: return 3
        case 10: return -2
        case 11: return 5
        default: return 0
        }
    }

    private func pitchName(_ pitch: Int) -> String {
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][((pitch % 12) + 12) % 12]
    }
}

struct DualClassificationFilterBar: View {
    @Binding var minus: Int?
    @Binding var plus: Int?
    let accent: Color

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let half = max(width / 2.0, 1)
            let minusValue = min(max(minus ?? 0, 0), 6)
            let plusValue = min(max(plus ?? 0, 0), 6)
            let minusX = half - (CGFloat(minusValue) / 6.0 * half)
            let plusX = half + (CGFloat(plusValue) / 6.0 * half)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 9)
                    .position(x: width / 2, y: 25)

                ForEach(0...6, id: \.self) { value in
                    Rectangle()
                        .fill(value == 0 ? Color.white.opacity(0.90) : Color.white.opacity(0.34))
                        .frame(width: value == 0 ? 2 : 1, height: value == 0 ? 23 : 13)
                        .position(x: half - CGFloat(value) / 6.0 * half, y: 25)
                    Rectangle()
                        .fill(value == 0 ? Color.white.opacity(0.90) : Color.white.opacity(0.34))
                        .frame(width: value == 0 ? 2 : 1, height: value == 0 ? 23 : 13)
                        .position(x: half + CGFloat(value) / 6.0 * half, y: 25)
                }

                if minus != nil {
                    Rectangle()
                        .fill(Color.red.opacity(0.78))
                        .frame(width: half - minusX, height: 9)
                        .position(x: (minusX + half) / 2, y: 25)
                    Text(minusValue == 0 ? "0" : "-\(minusValue)")
                        .font(.caption2.bold().monospaced())
                        .foregroundStyle(.white.opacity(0.95))
                        .position(x: minusX, y: 8)
                    Circle()
                        .fill(Color.red)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white.opacity(0.70), lineWidth: 1))
                        .position(x: minusX, y: 25)
                }

                if plus != nil {
                    Rectangle()
                        .fill(Color.green.opacity(0.78))
                        .frame(width: plusX - half, height: 9)
                        .position(x: (half + plusX) / 2, y: 25)
                    Text(plusValue == 0 ? "0" : "+\(plusValue)")
                        .font(.caption2.bold().monospaced())
                        .foregroundStyle(.white.opacity(0.95))
                        .position(x: plusX, y: 42)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(Color.white.opacity(0.70), lineWidth: 1))
                        .position(x: plusX, y: 25)
                }

                Text("0")
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(.white.opacity(0.90))
                    .position(x: half, y: 42)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let x = min(max(value.location.x, 0), width)
                        if x <= half {
                            let raw = Int(round((1.0 - x / half) * 6.0))
                            minus = min(max(raw, 0), 6)
                        } else {
                            let raw = Int(round(((x - half) / half) * 6.0))
                            plus = min(max(raw, 0), 6)
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
    }
}

struct ClassificationGaugeView: View {
    let minus: Int
    let plus: Int
    var compact: Bool = false

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let half = width / 2
            let minusClamped = min(max(minus, 0), 6)
            let plusClamped = min(max(plus, 0), 6)
            ZStack(alignment: .center) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: compact ? 6 : 8)

                ForEach(-6...6, id: \.self) { value in
                    Rectangle()
                        .fill(value == 0 ? Color.white.opacity(0.86) : Color.white.opacity(0.30))
                        .frame(width: value == 0 ? 2 : 1, height: value == 0 ? (compact ? 16 : 19) : (compact ? 9 : 12))
                        .offset(x: CGFloat(value) / 6.0 * half)
                }

                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Rectangle()
                        .fill(Color.red.opacity(0.78))
                        .frame(width: half * CGFloat(minusClamped) / 6.0, height: compact ? 6 : 8)
                }
                .frame(width: half, alignment: .trailing)
                .offset(x: -half / 2)

                HStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.green.opacity(0.78))
                        .frame(width: half * CGFloat(plusClamped) / 6.0, height: compact ? 6 : 8)
                    Spacer(minLength: 0)
                }
                .frame(width: half, alignment: .leading)
                .offset(x: half / 2)

                if minusClamped > 0 {
                    Text("-\(minusClamped)")
                        .font(.caption2.bold().monospaced())
                        .foregroundStyle(.white.opacity(0.92))
                        .offset(x: -CGFloat(minusClamped) / 6.0 * half, y: compact ? -11 : -15)
                }
                if plusClamped > 0 {
                    Text("+\(plusClamped)")
                        .font(.caption2.bold().monospaced())
                        .foregroundStyle(.white.opacity(0.92))
                        .offset(x: CGFloat(plusClamped) / 6.0 * half, y: compact ? -11 : -15)
                }

                Text("0")
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(.white.opacity(0.92))
                    .offset(y: compact ? 11 : 16)
            }
        }
    }
}

struct CreatureIcon: View {
    let enemy: EnemyType?
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(accent.opacity(0.42), lineWidth: 1)
                )

            if let enemy {
                Image(enemy.assetName)
                    .resizable()
                    .interpolation(.none)
                    .scaledToFit()
                    .padding(6)
            } else {
                Text("根".gameLocalized)
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
        }
    }
}

struct HarmonyCreatureCell: View {
    let noteName: String
    let enemy: EnemyType?
    let distance: String
    let accent: Color
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 2 : 5) {
            ZStack(alignment: .topLeading) {
                CreatureIcon(enemy: enemy, accent: accent)
                    .frame(width: 54, height: 54)

                if let enemy {
                    Text(enemy.label.gameLocalized)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.black.opacity(0.70))
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(accent.opacity(0.45), lineWidth: 0.8))
                        .offset(x: 4, y: 4)
                }
            }
            Text(noteName)
                .font((compact ? Font.caption2 : Font.caption).bold().monospaced())
                .foregroundStyle(.white)
            if !compact {
                Text(distance)
                    .font(.caption2.bold())
                    .foregroundStyle(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(compact ? 2 : 6)
        .background(compact ? Color.clear : Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct HarmonyCreatureMiniCell: View {
    let enemy: EnemyType?
    let accent: Color

    var body: some View {
        CreatureIcon(enemy: enemy, accent: accent)
            .frame(width: 34, height: 34)
    }
}

struct HarmonyCreatureColumnCell: View {
    let isPresent: Bool
    let isRoot: Bool
    let enemy: EnemyType?
    let accent: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(isPresent ? accent.opacity(0.12) : Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(isPresent ? accent.opacity(0.30) : Color.white.opacity(0.045), lineWidth: 0.6)
                )

            if isPresent {
                if let enemy {
                    Image(enemy.assetName)
                        .resizable()
                        .interpolation(.none)
                        .scaledToFit()
                        .padding(2)
                } else if isRoot {
                    Text("根".gameLocalized)
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .minimumScaleFactor(0.55)
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 23, maxHeight: 23)
    }
}

struct RecordArchiveSection: View {
    @ObservedObject var game: GameModel
    let startBattle: (BattleConfig) -> Void

    var body: some View {
        VStack(spacing: 12) {
            if !game.isRecordFeatureUnlocked {
                ArchiveCard(
                    title: "記録",
                    subtitle: "外周十二の根を巡ると開く",
                    text: "この頁は、まだ閉じておく。まずは外周の十二の根をひと巡りしなさい。ひと通り見届けたら、戦いの記録をここへ書き足す。",
                    accent: .mint
                )
            } else {
                ArchiveCard(
                    title: "記録",
                    subtitle: "手の戻りを見返す頁",
                    text: "ここに残す記録の芯は、根と音の生き物の組み合わせごとのものだ。根ごとの図も、音の生き物ごとの図も、その組み合わせからならして見ている。数が小さいところほど、手が早く戻れていると考えていい。迷った場所を責めるためではなく、次に戻る場所を見つけるために眺めてほしい。",
                    accent: .mint
                )

                Button {
                    startBattle(game.weaknessTrainingConfig())
                } label: {
                    Label("戻り稽古を始める".gameLocalized, systemImage: "arrow.uturn.left.circle.fill")
                        .font(.headline.bold())
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(.mint)
                .controlSize(.large)

                ArchiveCard(
                    title: "戻り稽古",
                    subtitle: "影を相手にした稽古",
                    text: "手帳に残した記録をもとに、私が迷いやすい音の生き物の影を立てておく。影は本物ではないから攻めてこない。勝つための場ではなく、根へ戻る手つきを整えるための稽古と思ってほしい。",
                    accent: .cyan
                )

                RecordRadarSection(
                    title: "根ごと",
                    subtitle: "十二の根を見返す頁。図の目盛りを横に添えておく。",
                    rows: game.rootRecordRows(),
                    accent: .mint
                )

                RecordRadarSection(
                    title: "音の生き物ごと",
                    subtitle: "音の生き物ごとの癖を見る頁。図の目盛りを横に添えておく。",
                    rows: game.intervalRecordRows(),
                    accent: .cyan
                )

                RecordHeatmapSection(game: game)
            }
        }
    }
}

struct RecordRadarSection: View {
    let title: String
    let subtitle: String
    let rows: [WeaknessRecord]
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.gameLocalized)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(subtitle.gameLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)

            RecordRadarChart(rows: rows, accent: accent)
                .frame(height: 248)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RecordRadarChart: View {
    let rows: [WeaknessRecord]
    let accent: Color

    private let upperValue: Double = 4.0
    private let lowerValue: Double = 0.8

    private func normalizedRadius(for value: Double) -> CGFloat {
        let capped = min(upperValue, max(lowerValue, value))
        let ratio = (upperValue - capped) / (upperValue - lowerValue)
        return CGFloat(max(0.04, min(1.0, ratio)))
    }

    private func point(index: Int, count: Int, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = -Double.pi / 2.0 + Double(index) / Double(max(count, 1)) * Double.pi * 2.0
        return CGPoint(
            x: center.x + CGFloat(Darwin.cos(angle)) * radius,
            y: center.y + CGFloat(Darwin.sin(angle)) * radius
        )
    }

    private func ringValue(for ring: Int) -> Double {
        upperValue - (upperValue - lowerValue) * (Double(ring) / 4.0)
    }

    var body: some View {
        GeometryReader { proxy in
            let count = max(rows.count, 1)
            let size = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2.0, y: proxy.size.height / 2.0)
            let maxRadius = size * 0.34
            let labelRadius = maxRadius + 26

            ZStack {
                ForEach(1...4, id: \.self) { ring in
                    Path { path in
                        let radius = maxRadius * CGFloat(ring) / 4.0
                        for index in 0..<count {
                            let p = point(index: index, count: count, radius: radius, center: center)
                            if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                        }
                        path.closeSubpath()
                    }
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                }

                ForEach(0..<count, id: \.self) { index in
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: point(index: index, count: count, radius: maxRadius, center: center))
                    }
                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                }

                Path { path in
                    for (index, row) in rows.enumerated() {
                        let radius = maxRadius * normalizedRadius(for: row.value)
                        let p = point(index: index, count: count, radius: radius, center: center)
                        if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    path.closeSubpath()
                }
                .fill(accent.opacity(0.18))

                Path { path in
                    for (index, row) in rows.enumerated() {
                        let radius = maxRadius * normalizedRadius(for: row.value)
                        let p = point(index: index, count: count, radius: radius, center: center)
                        if index == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }
                    path.closeSubpath()
                }
                .stroke(accent.opacity(0.88), lineWidth: 2)

                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    VStack(spacing: 2) {
                        if let imageName = row.imageName {
                            Image(imageName)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 18, height: 18)
                        }
                        Text(row.title.gameLocalized)
                            .font(.system(size: row.imageName == nil ? 9 : 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.86))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .frame(width: row.imageName == nil ? 34 : 44)
                    .position(point(index: index, count: count, radius: labelRadius, center: center))
                }

                ForEach(1...4, id: \.self) { ring in
                    let radius = maxRadius * CGFloat(ring) / 4.0
                    Text(String(format: "%.1f", ringValue(for: ring)))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .position(x: center.x + 16, y: center.y - radius)
                }

                Text(String(format: "%.1f", upperValue))
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .position(x: center.x + 16, y: center.y - 4)
            }
        }
    }
}

struct RecordHeatmapSection: View {
    @ObservedObject var game: GameModel
    @State private var selectedText: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("細かい記録".gameLocalized)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text("縦に音の生き物、横に根を並べた。数と色が、その組み合わせでどれほど早く戻れたかの目安になる。".gameLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 3) {
                HStack(spacing: 3) {
                    Text("")
                        .frame(width: 56)
                    ForEach(game.rootAuras) { aura in
                        Text(aura.name)
                            .font(.system(size: 8, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.82))
                            .frame(maxWidth: .infinity)
                            .minimumScaleFactor(0.55)
                    }
                }

                ForEach(game.enemyTypes) { enemy in
                    HStack(spacing: 3) {
                        HStack(spacing: 2) {
                            Image(enemy.assetName)
                                .resizable()
                                .interpolation(.none)
                                .scaledToFit()
                                .frame(width: 14, height: 14)
                            Text(enemy.label.gameLocalized)
                                .font(.system(size: 7, weight: .black, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.88))
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                        }
                        .frame(width: 56, alignment: .leading)

                        ForEach(game.rootAuras) { aura in
                            let value = game.timingValueForPair(auraID: aura.id, enemyID: enemy.id)
                            Button {
                                selectedText = "\(aura.name) × \(enemy.label)　\(String(format: "%.1f", value))"
                            } label: {
                                Text(String(format: "%.1f", value))
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.92))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 20)
                                    .background(heatColor(value).opacity(0.24))
                                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.white.opacity(0.08), lineWidth: 0.6))
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            if !selectedText.isEmpty {
                Text(selectedText.gameLocalized)
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(.mint)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func heatColor(_ value: Double) -> Color {
        if value <= 1.0 { return .mint }
        if value <= 2.0 { return .cyan }
        if value <= 3.0 { return .orange }
        return .red
    }
}

struct RecordGridSection: View {
    let title: String
    let subtitle: String
    let rows: [WeaknessRecord]
    let columns: Int
    @ObservedObject var game: GameModel

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, columns))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.gameLocalized)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(subtitle.gameLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(rows) { row in
                    RecordValueCard(row: row, color: game.auraColorByIndex(row.accentIndex))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.black.opacity(0.28))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct RecordValueCard: View {
    let row: WeaknessRecord
    let color: Color

    private var valueText: String {
        String(format: "%.1f", row.value)
    }

    private var countText: String {
        row.count == 0 ? "未" : "\(row.count)"
    }

    private var gradeColor: Color {
        if row.value <= 1.0 { return .mint }
        if row.value <= 2.0 { return .cyan }
        if row.value <= 3.0 { return .yellow }
        return .red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(row.title.gameLocalized)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 2)
                Text(valueText)
                    .font(.headline.bold().monospacedDigit())
                    .foregroundStyle(gradeColor)
            }

            Text(row.detail.gameLocalized)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .minimumScaleFactor(0.75)

        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .topLeading)
        .background(Color.white.opacity(0.055))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.25), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct ArchiveCard: View {
    let title: String
    let subtitle: String
    let text: String
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title.gameLocalized)
                .font(.headline.bold())
                .foregroundStyle(.white)
            Text(subtitle.gameLocalized)
                .font(.caption.bold())
                .foregroundStyle(accent)
            Text(text.gameLocalized)
                .font(.callout)
                .foregroundStyle(.white.opacity(0.86))
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.34))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(accent.opacity(0.24), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}


struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label.gameLocalized)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .leading)
            Text(value.gameLocalized)
                .font(.body)
                .foregroundStyle(.white.opacity(0.90))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}


struct MapView: View {
    @ObservedObject var game: GameModel
    @Binding var lastMapFocusID: String
    @Binding var mapScrollOffset: CGPoint

    @State private var showingResetConfirm = false
    @AppStorage("IntervalRouteMVP.generatedBGMEnabled.v1") private var generatedBGMEnabled = true
    @AppStorage("IntervalRouteMVP.seenStoryEvents.v1") private var seenStoryEventsRaw = ""
    @AppStorage("IntervalRouteMVP.seenFirstMapGuide.v1") private var seenFirstMapGuide = false
    @State private var showingFirstMapGuide = false

    let selectAura: (RootAura) -> Void
    let startBattle: (BattleConfig) -> Void
    let openCustomize: () -> Void
    let openSilentTraining: () -> Void
    let openArchive: () -> Void
    let openMapDetail: (MapInfo, BattleConfig?) -> Void

    private let canvasSize = CGSize(width: 1360, height: 1360)

    var body: some View {
        VStack(spacing: 8) {
            Text("音環島".gameLocalized)
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            Text("十二の根を巡り、見えないまま戻る道を作る。港から外周を巡り、洞・郭・険路を越えて中心へ向かう。".gameLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            HStack {
                Text("Lv \(game.playerLevel)")
                Text("単独 \(game.clearedDungeonAuraIDs.count)/12".gameLocalized)
                Text("二重 \(game.clearedPairCount)".gameLocalized)
                Text("四重 \(game.clearedQuadCount)".gameLocalized)
                Text("宝玉 \(game.unlockedGemCount)/\(game.gemSkills.count)".gameLocalized)
            }
            .font(.caption.monospaced())
            .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                Button("強化".gameLocalized) {
                    openCustomize()
                }
                .font(.caption)
                .buttonStyle(.borderedProminent)

                Button("手帳".gameLocalized) {
                    openArchive()
                }
                .font(.caption)
                .buttonStyle(.bordered)

                Button("進行状況をリセット".gameLocalized) {
                    showingResetConfirm = true
                }
                .font(.caption)
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .confirmationDialog(
                "進行状況をリセットしますか？",
                isPresented: $showingResetConfirm,
                titleVisibility: .visible
            ) {
                Button("すべてリセット".gameLocalized, role: .destructive) {
                    game.resetProgress()
                    seenStoryEventsRaw = ""
                    seenFirstMapGuide = false
                    lastMapFocusID = "aura_0"
                    mapScrollOffset = .zero
                }

                Button("キャンセル".gameLocalized, role: .cancel) {}
            } message: {
                Text("クリア状況、宝玉、装着技、レベルが初期化されます。".gameLocalized)
            }

            OffsetPreservingScrollView(offset: $mapScrollOffset, showsIndicators: true) {
                    ZStack {
                        RouteBackground()

                    ForEach(game.rootAuras) { aura in
                        AuraMapNode(
                            aura: aura,
                            unlocked: game.isUnlocked(aura),
                            cleared: game.isCleared(aura)
                        ) {
                            lastMapFocusID = "aura_\(aura.id)"
                            if game.isUnlocked(aura) {
                                selectAura(aura)
                            } else {
                                openMapDetail(game.auraMapInfo(aura), nil)
                            }
                        }
                        .id("aura_\(aura.id)")
                        .position(position(angleIndex: Double(aura.circleIndex), radius: 590))
                    }

                    ForEach(game.multiAuraDungeons) { dungeon in
                        MultiDungeonMapNode(
                            dungeon: dungeon,
                            unlocked: game.isMultiUnlocked(dungeon),
                            cleared: game.isMultiCleared(dungeon)
                        ) {
                            lastMapFocusID = "dungeon_\(dungeon.id)"
                            if game.isMultiUnlocked(dungeon) {
                                openMapDetail(game.dungeonMapInfo(dungeon), game.multiConfig(for: dungeon))
                            } else {
                                openMapDetail(game.dungeonMapInfo(dungeon), nil)
                            }
                        }
                        .id("dungeon_\(dungeon.id)")
                        .position(position(angleIndex: dungeon.angleIndex, radius: radius(for: dungeon.tier)))
                    }

                    FinalCoreNode(
                        unlocked: game.finalNormalUnlocked,
                        cleared: game.isFinalCoreClearedForView
                    ) {
                        lastMapFocusID = "final_core"
                        if game.finalNormalUnlocked {
                            openMapDetail(game.finalCoreMapInfo(), game.finalCoreConfig())
                        } else {
                            openMapDetail(game.finalCoreMapInfo(), nil)
                        }
                    }
                    .id("final_core")
                    .position(x: canvasSize.width / 2, y: canvasSize.height / 2)
                }
                .frame(width: canvasSize.width, height: canvasSize.height)
                .padding(20)            }
            .background(Color.white.opacity(0.035))
            .clipShape(RoundedRectangle(cornerRadius: 18))

        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .onAppear {
            if !seenFirstMapGuide {
                showingFirstMapGuide = true
                seenFirstMapGuide = true
            }
        }
        .alert("父の手帳".gameLocalized, isPresented: $showingFirstMapGuide) {
            Button("わかった".gameLocalized) {}
        } message: {
            Text("上の『手帳』で、父の手帳・生物録・響きを確認できる。『強化』では技と特性を整えられる。迷ったら、まず手帳を開く。".gameLocalized)
        }
    }

    private func rewardText(for dungeon: MultiAuraDungeon) -> String {
        game.gemRewardText(for: dungeon)
    }

    private func position(angleIndex: Double, radius: CGFloat) -> CGPoint {
        let angle = -Double.pi / 2 + angleIndex * 2 * Double.pi / 12

        return CGPoint(
            x: canvasSize.width / 2 + CGFloat(Darwin.cos(angle)) * radius,
            y: canvasSize.height / 2 + CGFloat(Darwin.sin(angle)) * radius
        )
    }

    private func radius(for tier: Int) -> CGFloat {
        switch tier {
        case 2:
            return 425
        case 4:
            return 285
        case 6:
            return 165
        default:
            return 240
        }
    }

    private struct RouteSegment: Identifiable {
        let id: String
        let start: CGPoint
        let end: CGPoint
        let active: Bool
        let cleared: Bool
    }

    private func routeSegments() -> [RouteSegment] {
        var segments: [RouteSegment] = []

        // Outer ring between single-aura nodes
        for aura in game.rootAuras {
            let nextIndex = (aura.circleIndex + 1) % 12
            if let next = game.rootAuras.first(where: { $0.circleIndex == nextIndex }) {
                segments.append(
                    RouteSegment(
                        id: "outer_\(aura.id)_\(next.id)",
                        start: position(angleIndex: Double(aura.circleIndex), radius: 590),
                        end: position(angleIndex: Double(next.circleIndex), radius: 590),
                        active: game.isUnlocked(aura) || game.isUnlocked(next),
                        cleared: game.isCleared(aura) && game.isCleared(next)
                    )
                )
            }
        }

        // Single nodes to 2-aura dungeons
        for dungeon in game.multiAuraDungeons where dungeon.tier == 2 {
            let dpos = position(angleIndex: dungeon.angleIndex, radius: radius(for: dungeon.tier))
            for auraID in dungeon.auraIDs {
                if let aura = game.rootAuras.first(where: { $0.id == auraID }) {
                    segments.append(
                        RouteSegment(
                            id: "aura_\(auraID)_to_\(dungeon.id)",
                            start: position(angleIndex: Double(aura.circleIndex), radius: 590),
                            end: dpos,
                            active: game.isCleared(aura) || game.isMultiUnlocked(dungeon),
                            cleared: game.isMultiCleared(dungeon)
                        )
                    )
                }
            }
        }

        // 2-aura to 4-aura routes: route is open when 4-aura is open
        for dungeon in game.multiAuraDungeons where dungeon.tier == 4 {
            let dpos = position(angleIndex: dungeon.angleIndex, radius: radius(for: dungeon.tier))
            for pair in game.multiAuraDungeons where pair.tier == 2 && overlap(pair.auraIDs, dungeon.auraIDs) >= 2 {
                segments.append(
                    RouteSegment(
                        id: "\(pair.id)_to_\(dungeon.id)",
                        start: position(angleIndex: pair.angleIndex, radius: radius(for: pair.tier)),
                        end: dpos,
                        active: game.isMultiCleared(pair) || game.isMultiUnlocked(dungeon),
                        cleared: game.isMultiCleared(dungeon)
                    )
                )
            }
        }

        // 4-aura to 6-aura routes
        for dungeon in game.multiAuraDungeons where dungeon.tier == 6 {
            let dpos = position(angleIndex: dungeon.angleIndex, radius: radius(for: dungeon.tier))
            for quad in game.multiAuraDungeons where quad.tier == 4 && overlap(quad.auraIDs, dungeon.auraIDs) >= 3 {
                segments.append(
                    RouteSegment(
                        id: "\(quad.id)_to_\(dungeon.id)",
                        start: position(angleIndex: quad.angleIndex, radius: radius(for: quad.tier)),
                        end: dpos,
                        active: game.isMultiCleared(quad) || game.isMultiUnlocked(dungeon),
                        cleared: game.isMultiCleared(dungeon)
                    )
                )
            }
        }

        // 6-aura to center
        for dungeon in game.multiAuraDungeons where dungeon.tier == 6 {
            segments.append(
                RouteSegment(
                    id: "\(dungeon.id)_to_core",
                    start: position(angleIndex: dungeon.angleIndex, radius: radius(for: dungeon.tier)),
                    end: CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2),
                    active: game.isMultiCleared(dungeon) || game.finalNormalUnlocked,
                    cleared: false
                )
            )
        }

        return segments
    }

    private func overlap(_ a: [Int], _ b: [Int]) -> Int {
        Set(a).intersection(Set(b)).count
    }
}


#if os(iOS)
struct OffsetPreservingScrollView<Content: View>: UIViewRepresentable {
    @Binding var offset: CGPoint
    let showsIndicators: Bool
    let content: Content

    init(offset: Binding<CGPoint>, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self._offset = offset
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(offset: $offset, content: content)
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.showsVerticalScrollIndicator = showsIndicators
        scrollView.bounces = true
        scrollView.backgroundColor = .clear

        let hostedView = context.coordinator.hostingController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        hostedView.backgroundColor = .clear
        scrollView.addSubview(hostedView)

        NSLayoutConstraint.activate([
            hostedView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            hostedView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            hostedView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor)
        ])

        DispatchQueue.main.async {
            let target = initialMapOffsetIfNeeded(offset, in: scrollView)
            scrollView.setContentOffset(target, animated: false)
            offset = target
        }

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.hostingController.rootView = content
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.showsVerticalScrollIndicator = showsIndicators

        guard !scrollView.isTracking, !scrollView.isDragging, !scrollView.isDecelerating else {
            return
        }

        let target = clamped(offset, in: scrollView)
        let dx = abs(scrollView.contentOffset.x - target.x)
        let dy = abs(scrollView.contentOffset.y - target.y)

        if dx > 1 || dy > 1 {
            DispatchQueue.main.async {
                scrollView.setContentOffset(target, animated: false)
            }
        }
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var offset: Binding<CGPoint>
        let hostingController: UIHostingController<Content>

        init(offset: Binding<CGPoint>, content: Content) {
            self.offset = offset
            self.hostingController = UIHostingController(rootView: content)
            self.hostingController.view.backgroundColor = .clear
        }

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            offset.wrappedValue = scrollView.contentOffset
        }
    }
}

private func clamped(_ offset: CGPoint, in scrollView: UIScrollView) -> CGPoint {
    let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
    let maxY = max(0, scrollView.contentSize.height - scrollView.bounds.height)

    return CGPoint(
        x: min(max(offset.x, 0), maxX),
        y: min(max(offset.y, 0), maxY)
    )
}

private func initialMapOffsetIfNeeded(_ offset: CGPoint, in scrollView: UIScrollView) -> CGPoint {
    guard offset == .zero else { return clamped(offset, in: scrollView) }

    let maxX = max(0, scrollView.contentSize.width - scrollView.bounds.width)
    let centeredX = maxX / 2
    return clamped(CGPoint(x: centeredX, y: 0), in: scrollView)
}
#else
struct OffsetPreservingScrollView<Content: View>: View {
    @Binding var offset: CGPoint
    let showsIndicators: Bool
    let content: Content

    init(offset: Binding<CGPoint>, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) {
        self._offset = offset
        self.showsIndicators = showsIndicators
        self.content = content()
    }

    var body: some View {
        ScrollView([.horizontal, .vertical], showsIndicators: showsIndicators) {
            content
        }
    }
}
#endif

struct MapInfo: Identifiable {
    let id = UUID()
    let title: String
    let status: String
    let reward: String
    let note: String
    let rewardDetail: String

    init(title: String, status: String, reward: String, note: String, rewardDetail: String = "") {
        self.title = title
        self.status = status
        self.reward = reward
        self.note = note
        self.rewardDetail = rewardDetail
    }
}

struct MapInfoPanel: View {
    @ObservedObject var game: GameModel
    let info: MapInfo
    let battleConfig: BattleConfig?
    let close: () -> Void
    let start: (BattleConfig) -> Void

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(info.title.gameLocalized)
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    Text(info.status.gameLocalized)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("閉じる".gameLocalized) {
                    close()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            if !info.reward.isEmpty {
                Text(info.reward.gameLocalized)
                    .font(.caption2.bold())
                    .foregroundStyle(.yellow)
            }

            Text(info.note.gameLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)

            if let battleConfig {
                if battleConfig.id == "final_core" && game.isFinalCoreClearedForView {
                    VStack(spacing: 6) {
                        Button("通常戦闘".gameLocalized) { start(game.finalCoreConfig()) }
                            .buttonStyle(.borderedProminent)
                        Button("無装戦闘".gameLocalized) { start(game.finalCoreHardConfig()) }
                            .buttonStyle(.bordered)
                        Button("練習".gameLocalized) { start(game.finalPracticeConfig()) }
                            .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                } else {
                    Button("攻略へ進む".gameLocalized) {
                        start(battleConfig)
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 4)
                }
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.72))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 10)
    }
}

struct RewardDetailBox: View {
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.gameLocalized)
                .font(.headline.bold())
                .foregroundStyle(.yellow)
                .multilineTextAlignment(.leading)

            if !detail.isEmpty {
                Text(detail.gameLocalized)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(14)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.black.opacity(0.36))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.yellow.opacity(0.20), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MapDetailView: View {
    @ObservedObject var game: GameModel
    let info: MapInfo
    let battleConfig: BattleConfig?
    let back: () -> Void
    let start: (BattleConfig) -> Void

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Button("地図へ戻る".gameLocalized) {
                    back()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()

                Text(info.status.gameLocalized)
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            Spacer(minLength: 8)

            VStack(spacing: 10) {
                Text(info.title.gameLocalized)
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(info.note.gameLocalized)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(12)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(14)
                    .background(Color.black.opacity(0.32))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            Spacer()

            if !info.reward.isEmpty {
                RewardDetailBox(title: info.reward, detail: info.rewardDetail)
                    .padding(.horizontal, 4)
            }

            if let battleConfig {
                if battleConfig.id == "final_core" && game.isFinalCoreClearedForView {
                    VStack(spacing: 10) {
                        Button("通常戦闘".gameLocalized) {
                            start(game.finalCoreConfig())
                        }
                        .font(.title3.bold())
                        .buttonStyle(.borderedProminent)

                        Button("無装戦闘（技・特性なし）".gameLocalized) {
                            start(game.finalCoreHardConfig())
                        }
                        .font(.headline.bold())
                        .buttonStyle(.bordered)
                        .tint(.red)

                        Button("練習（敵の攻撃なし）".gameLocalized) {
                            start(game.finalPracticeConfig())
                        }
                        .font(.headline.bold())
                        .buttonStyle(.bordered)
                    }
                } else {
                    Button("攻略へ進む".gameLocalized) {
                        start(battleConfig)
                    }
                    .font(.title3.bold())
                    .buttonStyle(.borderedProminent)
                }
            } else {
                Text("まだ攻略できない".gameLocalized)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
        }
        .padding()
    }
}

struct MapViewFallback: View {
    let back: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("表示するエリアがありません".gameLocalized)
                .foregroundStyle(.secondary)

            Button("地図へ戻る".gameLocalized) {
                back()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }
}

struct RouteBackground: View {
    var body: some View {
        ZStack {
            Image("field_map_bg")
                .resizable()
                .interpolation(.none)
                .scaledToFill()
                .frame(width: 1320, height: 1320)
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .position(x: 680, y: 680)
                .overlay {
                    RoundedRectangle(cornerRadius: 36)
                        .stroke(Color.black.opacity(0.35), lineWidth: 2)
                        .frame(width: 1320, height: 1320)
                        .position(x: 680, y: 680)
                }

            Rectangle()
                .fill(Color.black.opacity(0.10))
                .frame(width: 1320, height: 1320)
                .clipShape(RoundedRectangle(cornerRadius: 36))
                .position(x: 680, y: 680)

            ForEach([1180.0, 850.0, 570.0, 330.0], id: \.self) { size in
                Circle()
                    .stroke(Color.orange.opacity(0.09), lineWidth: size == 1180.0 ? 3 : 1.4)
                    .frame(width: size, height: size)
                    .position(x: 680, y: 680)
            }

            Path { path in
                path.move(to: CGPoint(x: 680, y: 80))
                path.addLine(to: CGPoint(x: 680, y: 1280))
                path.move(to: CGPoint(x: 80, y: 680))
                path.addLine(to: CGPoint(x: 1280, y: 680))
            }
            .stroke(Color.orange.opacity(0.05), style: StrokeStyle(lineWidth: 1, dash: [10, 12]))
        }
    }
}

struct RouteLine: View {
    let start: CGPoint
    let end: CGPoint
    let active: Bool
    let cleared: Bool

    var body: some View {
        Path { path in
            path.move(to: start)
            path.addLine(to: end)
        }
        .stroke(
            cleared ? Color.cyan.opacity(0.82) : (active ? Color.orange.opacity(0.48) : Color.orange.opacity(0.12)),
            style: StrokeStyle(lineWidth: cleared ? 3.5 : 2.2, lineCap: .round, dash: active ? [] : [6, 8])
        )
    }
}


struct MapLabelText: View {
    let text: String
    let font: Font
    let color: Color

    init(_ text: String, font: Font = .caption.bold(), color: Color = .white) {
        self.text = text
        self.font = font
        self.color = color
    }

    var body: some View {
        Text(text.gameLocalized)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .shadow(color: .black.opacity(0.95), radius: 2, x: 0, y: 1)
    }
}

struct AuraMapNode: View {
    let aura: RootAura
    let unlocked: Bool
    let cleared: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            VStack(spacing: 2) {
                MapLabelText(aura.name, font: .headline.bold())

                MapLabelText(cleared ? "CLEAR" : (unlocked ? "OPEN" : "LOCK"), font: .caption2.monospaced())
            }
            .foregroundStyle(.white)
            .frame(width: 62, height: 48)
            .background(unlocked ? aura.color.opacity(cleared ? 0.86 : 0.62) : Color.brown.opacity(0.46))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(cleared ? Color.white.opacity(0.9) : Color.white.opacity(0.22), lineWidth: cleared ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
        .opacity(unlocked ? 1.0 : 0.35)
    }
}


struct MultiDungeonMapNode: View {
    let dungeon: MultiAuraDungeon
    let unlocked: Bool
    let cleared: Bool
    let action: () -> Void

    @State private var showInfo = false

    var body: some View {
        Button {
            if unlocked {
                action()
            }
        } label: {
            VStack(spacing: 2) {
                MapLabelText(tierLabel, font: .caption.bold())

                MapLabelText(shortTitle, font: .caption2)

                MapLabelText(cleared ? "CLEAR" : (unlocked ? "OPEN" : "LOCK"), font: .caption2.monospaced())
            }
            .foregroundStyle(.white)
            .frame(width: nodeWidth, height: nodeHeight)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(cleared ? Color.cyan.opacity(0.9) : Color.white.opacity(0.16), lineWidth: cleared ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .opacity(unlocked ? 1.0 : 0.42)
        .contextMenu {
            Text(dungeon.lore.gameLocalized)
        }
    }

    private var tierLabel: String {
        "\(dungeon.tier)オーラ".gameLocalized
    }

    private var shortTitle: String {
        let s = dungeon.title.gameLocalized
            .replacingOccurrences(of: "二重洞 ".gameLocalized, with: "")
            .replacingOccurrences(of: "四重洞 ".gameLocalized, with: "")
            .replacingOccurrences(of: "六重洞 ".gameLocalized, with: "")
            .replacingOccurrences(of: "六重険路 ".gameLocalized, with: "")
        if s.count > 13 {
            return "\(s.prefix(12))…"
        }
        return s
    }

    private var nodeWidth: CGFloat {
        dungeon.tier == 6 ? 132 : (dungeon.tier == 4 ? 126 : 112)
    }

    private var nodeHeight: CGFloat {
        dungeon.tier == 6 ? 58 : 52
    }

    private var backgroundColor: Color {
        if !unlocked {
            return Color.brown.opacity(0.18)
        }
        if cleared {
            return Color.cyan.opacity(0.58)
        }
        switch dungeon.tier {
        case 2:
            return Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.98)
        case 4:
            return Color.purple.opacity(0.52)
        case 6:
            return Color.red.opacity(0.56)
        default:
            return Color(red: 0.12, green: 0.10, blue: 0.08).opacity(0.98)
        }
    }
}

struct FinalCoreNode: View {
    let unlocked: Bool
    let cleared: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if unlocked {
                action()
            }
        } label: {
            VStack(spacing: 5) {
                MapLabelText("無音の核".gameLocalized, font: .title3.bold())
                MapLabelText("12オーラ".gameLocalized, font: .caption.monospaced())
                MapLabelText((unlocked ? "OPEN" : "六重洞CLEAR").gameLocalized, font: .caption2.monospaced())
                MapLabelText("沈黙の中心".gameLocalized, font: .caption2, color: .secondary)
            }
            .foregroundStyle(.white)
            .frame(width: 150, height: 104)
            .background(unlocked ? Color.red.opacity(0.50) : Color.gray.opacity(0.34))
            .overlay(
                RoundedRectangle(cornerRadius: 22)
                    .stroke(unlocked ? Color.red.opacity(0.8) : Color.white.opacity(0.15), lineWidth: unlocked ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .shadow(color: unlocked ? Color.red.opacity(0.55) : .clear, radius: 20)
        }
        .buttonStyle(.plain)
        .opacity(unlocked ? 1.0 : 0.55)
        .contextMenu {
            Text("十二の根を失わずに戻れる者だけが入れる中心。沈黙を終わらせるためではなく、沈黙から戻るために向き合う。".gameLocalized)
        }
    }
}

struct AreaDetailView: View {
    @ObservedObject var game: GameModel

    let back: () -> Void
    let start: (BattleConfig) -> Void

    var body: some View {
        let aura = game.selectedAura

        VStack(spacing: 18) {
            HStack {
                Button("地図へ".gameLocalized) {
                    back()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Spacer()
            }
            .padding(.top, 28)

            Spacer()

            Text(game.auraPlaceName(aura).gameLocalized)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(.white)

            Text(game.auraMapNote(aura).gameLocalized)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.82)

            Text(game.auraDialogue(aura).gameLocalized)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(8)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color.black.opacity(0.22))
                .clipShape(RoundedRectangle(cornerRadius: 14))

            RewardDetailBox(
                title: game.singleAuraRewardText(for: aura),
                detail: game.rewardThresholdText(forDungeonID: "aura_\(aura.id)")
            )
            .padding(.horizontal)

            VStack(spacing: 12) {

                Text("父の助言を聞きながら攻略する".gameLocalized)
                    .font(.caption.bold())
                    .foregroundStyle(.mint)

                Button {
                    start(game.dungeonConfig(for: aura))
                } label: {
                    VStack {
                        Text("近郊ダンジョンを攻略".gameLocalized)
                            .font(.title3.bold())

                        Text((game.auraBattleSummary(aura) + " クリアで隣接拠点が開く。").gameLocalized)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .minimumScaleFactor(0.72)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
    }
}

struct WeaponCustomizeView: View {
    @ObservedObject var game: GameModel
    let back: () -> Void

    @State private var selectedGemID: String?
    @State private var tab: CustomizeTab = .skills

    private enum CustomizeTab: String, CaseIterable {
        case skills = "技"
        case traits = "特性"
    }

    private let columns = [
        GridItem(.flexible(), spacing: 6),
        GridItem(.flexible(), spacing: 6)
    ]

    private var selectedSpec: GemSkillSpec? {
        if let selectedGemID {
            return game.skillSpec(byID: selectedGemID)
        }
        return nil
    }

    private var skillSpecs: [GemSkillSpec] {
        game.gemSkills.filter { game.isActiveBattleSkill($0.id) && game.isSkillUnlocked($0.id) }
    }

    private var traitSpecs: [GemSkillSpec] {
        game.gemSkills.filter { game.isTraitGem($0.id) && game.gemLevel(for: $0.id) > 0 }
    }

    private var displayedSpecs: [GemSkillSpec] {
        switch tab {
        case .skills:
            return skillSpecs
        case .traits:
            return traitSpecs
        }
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack {
                Button("地図へ戻る".gameLocalized) {
                    back()
                }
                .buttonStyle(.bordered)

                Spacer()

                Text("鍵盤武器".gameLocalized)
                    .font(.title2.bold())
                    .foregroundStyle(.white)

                Spacer()

                Text("技\(game.equippedSkillIDs.count)/5 特性コスト\(game.traitEquipCostUsed())/\(game.traitEquipCostCapacity)".gameLocalized)
                    .font(.caption.bold().monospaced())
                    .foregroundStyle(.secondary)
            }

            Picker("表示".gameLocalized, selection: $tab) {
                ForEach(CustomizeTab.allCases, id: \.self) { item in
                    Text(item.rawValue.gameLocalized).tag(item)
                }
            }
            .pickerStyle(.segmented)

            VStack(spacing: 6) {
                if tab == .skills {
                    EquippedSlotsView(game: game, title: "装着技".gameLocalized, ids: game.equippedSkillIDs, fixedSlots: 5)
                } else {
                    EquippedSlotsView(game: game, title: "装着特性".gameLocalized, ids: game.equippedTraitIDs, fixedSlots: nil)
                    TraitSummaryView(game: game)
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.32))
            .clipShape(RoundedRectangle(cornerRadius: 14))

            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(displayedSpecs) { spec in
                        CompactGemCard(
                            game: game,
                            spec: spec,
                            selected: selectedGemID == spec.id,
                            select: {
                                selectedGemID = spec.id
                            },
                            toggle: {
                                selectedGemID = spec.id
                                if game.isActiveBattleSkill(spec.id) {
                                    game.toggleEquippedSkill(spec.id)
                                } else {
                                    game.toggleEquippedTrait(spec.id)
                                }
                            }
                        )
                    }
                }
                .padding(.bottom, 12)
            }

            if let selectedSpec {
                GemDetailPanel(game: game, spec: selectedSpec)
            }
        }
        .padding()
        .onAppear {
            if selectedGemID == nil {
                selectedGemID = skillSpecs.first?.id
            }
        }
    }
}

struct EquippedSlotsView: View {
    @ObservedObject var game: GameModel
    let title: String
    let ids: [String]
    let fixedSlots: Int?

    private var displayCount: Int {
        if let fixedSlots { return fixedSlots }
        return max(1, ids.count)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.gameLocalized)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(0..<displayCount, id: \.self) { index in
                        if index < ids.count,
                           let spec = game.skillSpec(byID: ids[index]) {
                            VStack(spacing: 1) {
                                Text(spec.skillName.gameLocalized)
                                    .font(.caption2.bold())
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.55)

                                if !game.isActiveBattleSkill(spec.id) {
                                    Text("C\(game.traitEquipCost(spec.id))")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .frame(minWidth: fixedSlots == nil ? 64 : 0, maxWidth: fixedSlots == nil ? nil : .infinity)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 4)
                            .background(game.skillColor(spec.id).opacity(0.28))
                            .clipShape(RoundedRectangle(cornerRadius: 7))
                        } else {
                            Text("空".gameLocalized)
                                .font(.caption2.bold())
                                .foregroundStyle(.secondary.opacity(0.7))
                                .frame(minWidth: fixedSlots == nil ? 64 : 0, maxWidth: fixedSlots == nil ? nil : .infinity)
                                .padding(.vertical, 4)
                                .padding(.horizontal, 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 7)
                                        .stroke(Color.white.opacity(0.10), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                                )
                        }
                    }
                }
            }
        }
    }
}

struct TraitSummaryView: View {
    @ObservedObject var game: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("特性合計".gameLocalized)
                .font(.caption2.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                ForEach(game.traitSummaryLines(), id: \.self) { line in
                    Text(line)
                        .font(.caption2.monospaced())
                        .foregroundStyle(.white.opacity(0.88))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }
}

struct CompactGemCard: View {
    @ObservedObject var game: GameModel
    let spec: GemSkillSpec
    let selected: Bool
    let select: () -> Void
    let toggle: () -> Void

    private var unlocked: Bool {
        game.isSkillUnlocked(spec.id)
    }

    private var equipped: Bool {
        game.isActiveBattleSkill(spec.id) ? game.isSkillEquipped(spec.id) : game.isTraitEquipped(spec.id)
    }

    private var canToggle: Bool {
        if game.isActiveBattleSkill(spec.id) {
            return unlocked && (equipped || game.canEquipSkill(spec.id))
        }
        return unlocked && (equipped || game.canEquipTrait(spec.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(game.skillColor(spec.id).opacity(unlocked ? 0.9 : 0.28))
                        .frame(width: 8, height: 8)

                    Text(spec.skillName.gameLocalized)
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Spacer()

                    Text(game.potentialStageText(spec.id).gameLocalized)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(unlocked ? .white : .secondary)
                }

                Text(game.skillOneLineText(spec).gameLocalized)
                    .font(.system(size: 10, weight: .regular, design: .default))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                HStack {
                    Text((game.isActiveBattleSkill(spec.id) ? "技" : "C\(game.traitEquipCost(spec.id))").gameLocalized)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Button {
                        toggle()
                    } label: {
                        Text((equipped ? "外す" : (unlocked ? "装着" : "未入手")).gameLocalized)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(equipped ? .mint : (unlocked ? .white : .secondary))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canToggle)
                }
            }
            .padding(7)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(game.skillColor(spec.id).opacity(selected ? 0.24 : (unlocked ? 0.12 : 0.04)))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(game.skillColor(spec.id).opacity(selected ? 0.85 : 0.22), lineWidth: selected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .opacity(unlocked ? 1.0 : 0.60)
            .contentShape(RoundedRectangle(cornerRadius: 10))
            .onTapGesture {
                select()
            }
    }
}

struct GemDetailPanel: View {
    @ObservedObject var game: GameModel
    let spec: GemSkillSpec

    private var unlocked: Bool {
        game.isSkillUnlocked(spec.id)
    }

    private var isSkill: Bool {
        game.isActiveBattleSkill(spec.id)
    }

    private var equipped: Bool {
        isSkill ? game.isSkillEquipped(spec.id) : game.isTraitEquipped(spec.id)
    }

    private var canToggle: Bool {
        if isSkill {
            return unlocked && (equipped || game.canEquipSkill(spec.id))
        }
        return unlocked && (equipped || game.canEquipTrait(spec.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spec.skillName.gameLocalized)
                        .font(.headline.bold())
                        .foregroundStyle(.white)

                    Text(spec.gemName.gameLocalized)
                        .font(.caption2.bold())
                        .foregroundStyle(game.skillColor(spec.id))
                }

                Spacer()

                Text((spec.id == "distance_check" ? "助言" : (isSkill ? "技" : "特性")).gameLocalized)
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }

            Text(game.gemSourceText(spec).gameLocalized)
                .font(.caption2)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                Text((spec.id == "distance_check" ? "消費なし" : (isSkill ? "消費MP \(game.skillCostDisplay(spec.id))" : "コスト \(game.traitEquipCost(spec.id)) / 残 \(game.traitEquipCostRemaining())")).gameLocalized)
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(game.skillColor(spec.id).opacity(0.22))
                    .clipShape(Capsule())

                Text(game.potentialStageText(spec.id).gameLocalized)
                    .font(.caption2.bold().monospaced())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.10))
                    .clipShape(Capsule())
            }

            Text(game.skillFunctionText(spec).gameLocalized)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.9))
                .fixedSize(horizontal: false, vertical: true)

            Text(game.potentialDetailText(spec).gameLocalized)
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Spacer()

                Button {
                    if isSkill {
                        game.toggleEquippedSkill(spec.id)
                    } else {
                        game.toggleEquippedTrait(spec.id)
                    }
                } label: {
                    Text((equipped ? "外す" : "装着する").gameLocalized)
                        .foregroundStyle(.white)
                }
                .buttonStyle(.borderedProminent)
                .tint(equipped ? Color.gray : Color.blue)
                .disabled(!canToggle)
            }
        }
        .padding(10)
        .background(Color.black.opacity(0.48))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(game.skillColor(spec.id).opacity(0.50), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

struct BattleView: View {
    @ObservedObject var game: GameModel
    let backToMap: () -> Void

    @State private var showDebugClear = false

    var body: some View {
        VStack(spacing: 8) {
            BattleTopBar(game: game, backToMap: backToMap)
                .onLongPressGesture(minimumDuration: 1.2) {
                    showDebugClear.toggle()
                }

            if showDebugClear {
                DebugClearPanel(game: game)
                    .padding(.horizontal, 12)
            }

            EnemyBattlePanel(game: game)
                .frame(maxHeight: .infinity)

            SkillEffectGaugeView(game: game)

            SkillBar(game: game)


            OneOctaveKeyboardView(
                candidates: game.hintCandidates,
                auraPitchClass: game.auraHighlightedPitchClass(),
                keyboardStartPitch: game.keyboardStartPitch,
                onTap: { pitch in
                    game.tapPitch(pitch)
                }
            )
            .frame(height: 170)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .overlay {
            if game.finalCoreIntermissionActive {
                FinalCoreIntermissionOverlay(game: game)
            } else if game.battleFinished {
                BattleEndOverlay(game: game, backToMap: backToMap)
            }
        }
    }
}

struct DebugClearPanel: View {
    @ObservedObject var game: GameModel

    var body: some View {
        HStack(spacing: 6) {
            Button("DBG 4.0s") {
                game.debugClearWithAverage(4.0)
            }
            Button("DBG 2.0s") {
                game.debugClearWithAverage(2.0)
            }
            Button("DBG 1.0s") {
                game.debugClearWithAverage(1.0)
            }
            Button("DBG 0.8s") {
                game.debugClearWithAverage(0.8)
            }
        }
        .font(.caption2.bold())
        .buttonStyle(.bordered)
        .tint(.purple)
        .padding(6)
        .background(Color.purple.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct BattleTopBar: View {
    @ObservedObject var game: GameModel
    let backToMap: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Button("地図".gameLocalized) {
                    backToMap()
                }
                .buttonStyle(.bordered)

                HStack(spacing: 6) {
                    Text("Lv \(game.playerLevel)")
                        .font(.caption.bold().monospaced())
                        .foregroundStyle(.yellow)

                    if !game.levelUpText.isEmpty {
                        Text("LEVEL UP".gameLocalized)
                            .font(.caption2.bold().monospaced())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.yellow.opacity(0.22))
                            .clipShape(Capsule())
                            .foregroundStyle(.yellow)
                    }
                }

                Spacer()

                Text((game.currentBattle?.title ?? "").gameLocalized)
                    .font(.headline)
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Text("\(game.defeatedCount)/\(game.currentBattle?.targetDefeatCount ?? 0)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }

            ResourceBar(title: "HP", value: game.playerHP, maxValue: game.currentMaxHP(), color: .red)
                .opacity(game.currentBattle?.training == true ? 0.45 : 1.0)

            ResourceBar(title: "MP", value: game.playerMP, maxValue: game.currentMaxMP(), color: .blue)
                .opacity(game.currentBattle?.training == true ? 0.45 : 1.0)
        }
    }
}

struct ResonanceGauge: View {
    let text: String
    let progress: Double

    var body: some View {
        VStack(spacing: 3) {
            HStack {
                Text(text.gameLocalized)
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)

                Spacer()
            }

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.10))
                    .frame(height: 8)

                GeometryReader { proxy in
                    Capsule()
                        .fill(Color.mint.opacity(0.75))
                        .frame(width: proxy.size.width * CGFloat(min(max(progress, 0), 1)), height: 8)

                    thresholdMarker(proxy: proxy, x: 0.0, label: "4s")
                    thresholdMarker(proxy: proxy, x: 2.0 / 3.0, label: "2s")
                    thresholdMarker(proxy: proxy, x: 1.0, label: "1s")
                }
                .frame(height: 14)
            }
            .frame(height: 14)
        }
        .frame(height: 24)
    }

    private func thresholdMarker(proxy: GeometryProxy, x: Double, label: String) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.55))
                .frame(width: 1, height: 8)

            Text(label)
                .font(.system(size: 7, weight: .bold, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .position(x: proxy.size.width * CGFloat(x), y: 6)
    }
}

struct ResourceBar: View {
    let title: String
    let value: Int
    let maxValue: Int
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.caption.bold().monospaced())
                .frame(width: 28, alignment: .leading)
                .foregroundStyle(.white)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule()
                        .fill(color.opacity(0.8))
                        .frame(width: proxy.size.width * CGFloat(max(0, min(value, maxValue))) / CGFloat(max(maxValue, 1)))
                }
            }
            .frame(height: 10)

            Text("\(value)/\(maxValue)")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .trailing)
        }
    }
}

struct EnemyBattlePanel: View {
    @ObservedObject var game: GameModel

    var body: some View {
        VStack(spacing: 10) {
            if let enemy = game.currentEnemy {
                HStack {
                    Text(enemy.type.label)
                        .font(.largeTitle.weight(.black).monospaced())
                        .foregroundStyle(.white)

                    Spacer()
                }

                if game.isStealthed() {
                    VStack(spacing: 10) {
                        Image(systemName: "eye.slash.fill")
                            .font(.system(size: 60, weight: .bold))
                            .foregroundStyle(.white.opacity(0.55))

                        Text("気配を断っている".gameLocalized)
                            .font(.headline.bold())
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxHeight: 235)
                } else {
                    ZStack(alignment: .bottom) {
                        Image(enemy.type.assetName)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxHeight: 235)
                            .shadow(color: enemy.aura.color.opacity(0.8), radius: 20)

                        if !game.fatherAdviceText().isEmpty {
                            Text(game.fatherAdviceText().gameLocalized)
                                .font(.caption.bold())
                                .foregroundStyle(.black)
                                .multilineTextAlignment(.center)
                                .lineLimit(4)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .frame(maxWidth: 285)
                                .background(enemy.aura.color.opacity(0.94))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.58), lineWidth: 1))
                                .shadow(color: .black.opacity(0.45), radius: 8)
                                .offset(y: -8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(maxHeight: 235)

                    AuraBadge(aura: enemy.aura)
                }

                Text(game.message.gameLocalized)
                    .font(.headline)
                    .foregroundStyle(resultColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if game.currentBattle?.training == true || game.currentBattle?.enemyAttacks == false {
                    Text("仮想敵：攻撃なし".gameLocalized)
                        .font(.caption.bold())
                        .foregroundStyle(.mint)
                        .padding(.top, 4)
                } else if game.isStealthed() {
                    Text("敵の拍は止まっている".gameLocalized)
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                } else {
                    AttackGauge(progress: game.attackProgress)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Image(game.battleBackgroundAssetName())
                    .resizable()
                    .interpolation(.none)
                    .scaledToFill()
                Color.black.opacity(0.18)
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var resultColor: Color {
        switch game.lastResult {
        case .correct:
            return .mint
        case .heal:
            return .green
        case .skill:
            return .cyan
        case .miss, .enemyAttack, .defeat:
            return .red
        case .clear:
            return .cyan
        case .ready:
            return .secondary
        }
    }
}

struct AuraBadge: View {
    let aura: RootAura

    var body: some View {
        Text(aura.name)
            .font(.system(size: 28, weight: .black, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 3)
            .background(aura.color.opacity(0.36))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(aura.color.opacity(0.70), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.65), radius: 2, x: 0, y: 1)
    }
}

struct AttackGauge: View {
    let progress: Double

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text("攻撃ゲージ".gameLocalized)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(Int(progress * 100))%")
                    .font(.caption2.monospaced())
                    .foregroundStyle(.secondary)
            }

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.14))
                    Capsule()
                        .fill(gaugeColor)
                        .frame(width: proxy.size.width * CGFloat(min(max(progress, 0), 1)))
                }
            }
            .frame(height: 14)
        }
    }

    private var gaugeColor: Color {
        if progress < 0.5 { return .green }
        if progress < 0.8 { return .yellow }
        return .red
    }
}



struct SkillBar: View {
    @ObservedObject var game: GameModel

    private struct VisibleSkill: Identifiable {
        let id: String
        let title: String
        let cost: Int
        let color: Color
        let disabled: Bool
        let remaining: Int
    }

    private var visibleSkills: [VisibleSkill] {
        game.equippedSkillIDs.compactMap { skillID in
            guard game.isActiveBattleSkill(skillID),
                  let spec = game.skillSpec(byID: skillID) else { return nil }

            let blocksTraining = (skillID == "slow" || skillID == "quiet_key" || skillID == "heal") && game.currentBattle?.training == true
            let onCooldown = !game.isSkillReady(skillID)

            return VisibleSkill(
                id: skillID,
                title: spec.skillName,
                cost: game.skillCostDisplay(skillID),
                color: game.skillColor(skillID),
                disabled: blocksTraining || onCooldown,
                remaining: game.skillCooldownRemaining(skillID)
            )
        }
    }

    private var emptySlotCount: Int {
        max(0, 5 - visibleSkills.count)
    }

    var body: some View {
        HStack(spacing: 3) {
            ForEach(visibleSkills) { skill in
                SkillButton(title: skill.title, cost: skill.cost, color: skill.color, disabled: skill.disabled, remaining: skill.remaining) {
                    game.activateEquippedSkill(skill.id)
                }
            }

            ForEach(0..<emptySlotCount, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .overlay(
                        Text("空".gameLocalized)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary.opacity(0.55))
                    )
            }
        }
        .frame(height: 44)
    }
}

struct SkillButton: View {
    let title: String
    let cost: Int
    let color: Color
    let disabled: Bool
    let remaining: Int
    let action: () -> Void

    var body: some View {
        Button {
            if !disabled {
                action()
            }
        } label: {
            VStack(spacing: 0) {
                Text(title.gameLocalized)
                    .font(.caption2.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.60)

                Text((remaining > 0 ? "あと\(remaining)秒" : (cost == 0 ? "消費なし" : "MP \(cost)")).gameLocalized)
                    .font(.caption2.monospaced())
                    .lineLimit(1)
                    .minimumScaleFactor(0.50)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 38)
        }
        .buttonStyle(.bordered)
        .tint(color)
        .background(color.opacity(disabled ? 0.05 : 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .disabled(disabled)
    }
}


struct SkillEffectGaugeView: View {
    @ObservedObject var game: GameModel

    var body: some View {
        VStack(spacing: 4) {
            if game.slowEffectProgress() > 0 {
                EffectGaugeRow(title: "減速".gameLocalized, progress: game.slowEffectProgress(), color: .cyan)
            }

            if game.auraHintEffectProgress() > 0 {
                EffectGaugeRow(title: game.auraHintEffectLabel(), progress: game.auraHintEffectProgress(), color: .orange)
            }

            if game.hintEffectProgress() > 0 {
                EffectGaugeRow(title: game.hintEffectLabel(), progress: game.hintEffectProgress(), color: .mint)
            }

            if game.stealthEffectProgress() > 0 {
                EffectGaugeRow(title: "隠れる".gameLocalized, progress: game.stealthEffectProgress(), color: .gray)
            }
        }
        .frame(height: 52)
        .clipped()
    }
}

struct EffectGaugeRow: View {
    let title: String
    let progress: Double
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Text(title.gameLocalized)
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .frame(width: 68, alignment: .leading)

            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.12))

                    Capsule()
                        .fill(color.opacity(0.85))
                        .frame(width: proxy.size.width * CGFloat(min(max(progress, 0), 1)))
                }
            }
            .frame(height: 8)
        }
    }
}

struct OneOctaveKeyboardView: View {
    let candidates: Set<Int>
    let auraPitchClass: Int?
    let keyboardStartPitch: Int?
    let onTap: (Int) -> Void

    var body: some View {
        ShiftedOneOctaveKeyboardView(
            startPitch: keyboardStartPitch ?? 0,
            candidates: candidates,
            auraPitchClass: auraPitchClass,
            onTap: onTap
        )
    }
}

struct ShiftedOneOctaveKeyboardView: View {
    let startPitch: Int
    let candidates: Set<Int>
    let auraPitchClass: Int?
    let onTap: (Int) -> Void

    private let naturalPitches: [Int] = [0, 2, 4, 5, 7, 9, 11]

    private var whiteKeys: [(String, Int)] {
        let startIndex = naturalPitches.firstIndex(of: startPitch) ?? 0
        return (0...7).map { step in
            let pitch = naturalPitches[(startIndex + step) % naturalPitches.count]
            return (pitchName(pitch), pitch)
        }
    }

    private var blackKeys: [(String, Int, CGFloat)] {
        let whites = whiteKeys.map { $0.1 }
        var result: [(String, Int, CGFloat)] = []
        let startIndex = naturalPitches.firstIndex(of: startPitch) ?? 0
        let previousWhite = naturalPitches[(startIndex + naturalPitches.count - 1) % naturalPitches.count]
        let firstWhite = whites[0]
        if (firstWhite - previousWhite + 12) % 12 == 2 {
            let blackPitch = (previousWhite + 1) % 12
            result.append((pitchName(blackPitch), blackPitch, 0))
        }

        for i in 0..<(whites.count - 1) {
            let left = whites[i]
            let right = whites[i + 1]
            let distance = (right - left + 12) % 12

            if distance == 2 {
                let blackPitch = (left + 1) % 12
                result.append((pitchName(blackPitch), blackPitch, CGFloat(i + 1)))
            }
        }

        let lastWhite = whites[whites.count - 1]
        let nextWhite = naturalPitches[(startIndex + whiteKeys.count) % naturalPitches.count]
        if (nextWhite - lastWhite + 12) % 12 == 2 {
            let blackPitch = (lastWhite + 1) % 12
            result.append((pitchName(blackPitch), blackPitch, CGFloat(whites.count)))
        }

        return result
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .topLeading) {
                HStack(spacing: 2) {
                    ForEach(Array(whiteKeys.enumerated()), id: \.offset) { _, key in
                        Button {
                            onTap(key.1)
                        } label: {
                            VStack {
                                Spacer()

                                Text(key.0)
                                    .font(.headline.bold())
                                    .foregroundStyle(.black)
                                    .padding(.bottom, 10)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(whiteKeyColor(key.1))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(keyStrokeColor(key.1), lineWidth: candidates.contains(key.1) || auraPitchClass == key.1 ? 2 : 1)
                            )
                        }
                    }
                }

                let whiteWidth = proxy.size.width / CGFloat(whiteKeys.count)

                ForEach(Array(blackKeys.enumerated()), id: \.offset) { _, key in
                    Button {
                        onTap(key.1)
                    } label: {
                        VStack {
                            Spacer()

                            Text(key.0)
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .padding(.bottom, 8)
                        }
                        .frame(width: whiteWidth * 0.54, height: proxy.size.height * 0.62)
                        .background(blackKeyColor(key.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(keyStrokeColor(key.1), lineWidth: candidates.contains(key.1) || auraPitchClass == key.1 ? 2 : 1)
                        )
                    }
                    .position(x: whiteWidth * key.2, y: proxy.size.height * 0.31)
                }
            }
            .clipped()
        }
    }

    private func whiteKeyColor(_ pitch: Int) -> Color {
        if candidates.contains(pitch) {
            return Color(red: 0.86, green: 0.98, blue: 0.93)
        }
        if auraPitchClass == pitch {
            return Color(red: 1.00, green: 0.94, blue: 0.82)
        }
        return Color.white
    }

    private func blackKeyColor(_ pitch: Int) -> Color {
        if candidates.contains(pitch) {
            return Color(red: 0.04, green: 0.18, blue: 0.14)
        }
        if auraPitchClass == pitch {
            return Color(red: 0.24, green: 0.18, blue: 0.10)
        }
        return Color.black
    }

    private func keyStrokeColor(_ pitch: Int) -> Color {
        if candidates.contains(pitch) {
            return Color.mint.opacity(0.64)
        }
        if auraPitchClass == pitch {
            return Color.orange.opacity(0.72)
        }
        return Color.white.opacity(0.16)
    }

    private func pitchName(_ pitch: Int) -> String {
        ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"][((pitch % 12) + 12) % 12]
    }
}

struct FinalCoreIntermissionOverlay: View {
    @ObservedObject var game: GameModel

    var body: some View {
        VStack(spacing: 14) {
            Text("無音の核".gameLocalized)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)

            Text(game.finalCoreIntermissionText.gameLocalized)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)
                .lineLimit(14)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Button("進む".gameLocalized) {
                game.continueFinalCoreBattle()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: 340)
        .background(Color.black.opacity(0.88))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.18), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .padding()
    }
}

struct BattleEndOverlay: View {
    @ObservedObject var game: GameModel
    let backToMap: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text((game.battleWon ? "CLEAR" : "DEFEAT").gameLocalized)
                .font(.largeTitle.weight(.black))
                .foregroundStyle(game.battleWon ? Color.cyan : Color.red)

            Text(game.message.gameLocalized)
                .foregroundStyle(.secondary)

            if game.battleWon && !game.clearResonanceText.isEmpty {
                Text(game.clearResonanceText.gameLocalized)
                    .font(.headline.bold())
                    .foregroundStyle(.mint)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.mint.opacity(0.12))
                    .clipShape(Capsule())
            }

            if game.battleWon && !game.finalCoreSceneText.isEmpty {
                Text(game.finalCoreSceneText.gameLocalized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }

            if game.battleWon && !game.notebookRecordUnlockText.isEmpty {
                Text(game.notebookRecordUnlockText.gameLocalized)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.mint.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if game.battleWon && !game.gemRewardText.isEmpty {
                VStack(spacing: 5) {
                    Text(game.gemRewardText.gameLocalized)
                        .font(.headline.bold())
                        .foregroundStyle(.yellow)

                    if !game.gemRewardDetailText.isEmpty {
                        Text(game.gemRewardDetailText.gameLocalized)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.84))
                            .multilineTextAlignment(.center)
                            .lineLimit(5)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            if game.battleWon && !game.levelUpText.isEmpty {
                VStack(spacing: 4) {
                    Text(game.levelUpText.gameLocalized)
                        .font(.headline.bold())
                        .foregroundStyle(.yellow)

                    if !game.levelUpDetailText.isEmpty {
                        Text(game.levelUpDetailText.gameLocalized)
                            .font(.caption.bold().monospaced())
                            .foregroundStyle(.white.opacity(0.84))
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.yellow.opacity(0.16))
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            Text("単独 \(game.clearedDungeonAuraIDs.count) / 12　複数 \(game.clearedMultiDungeonIDs.count) / \(game.multiAuraDungeons.count)".gameLocalized)
                .font(.caption.monospaced())
                .foregroundStyle(.white)

            Button((game.pendingFinalCoreClearStoryEvent ? "先へ進む" : "地図へ戻る").gameLocalized) {
                backToMap()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(28)
        .frame(maxWidth: 340)
        .background(Color.black.opacity(0.90))
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

#Preview {
    ContentView()
}
