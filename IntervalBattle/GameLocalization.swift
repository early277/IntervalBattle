import Foundation

enum GameLocalization {
    static var languageCode: String {
        let preferred = Locale.preferredLanguages.first ?? Locale.current.identifier
        if preferred.hasPrefix("ko") { return "ko" }
        if preferred.hasPrefix("en") { return "en" }
        return "ja"
    }

    static func t(_ key: String) -> String {
        let exact = NSLocalizedString(key, tableName: nil, bundle: .main, value: key, comment: "")
        if exact != key { return exact }
        return generatedFallback(for: key)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: t(key), arguments: arguments)
    }

    private static func generatedFallback(for key: String) -> String {
        guard languageCode != "ja" else { return key }
        if let value = generatedPatternFallback(for: key) { return value }

        var text = key
        for item in tokenReplacements {
            text = text.replacingOccurrences(of: item.ja, with: languageCode == "ko" ? item.ko : item.en)
        }
        return containsJapanese(text) ? key : text
    }

    private static func generatedPatternFallback(for key: String) -> String? {
        let lang = languageCode

        if let m = firstMatch(#"^(.+)で解放$"#, in: key) {
            let name = t(m[0])
            return lang == "ko" ? "\(name)로 해방" : "Unlocked by \(name)"
        }
        if let m = firstMatch(#"^宝玉レベル(\d+)$"#, in: key) {
            return lang == "ko" ? "보옥 Lv. \(m[0])" : "Gem Lv. \(m[0])"
        }
        if let m = firstMatch(#"^あと(\d+)秒$"#, in: key) {
            return lang == "ko" ? "\(m[0])초 남음" : "\(m[0])s remaining"
        }
        if let m = firstMatch(#"^目印 (\d+)回$"#, in: key) {
            return lang == "ko" ? "표식 \(m[0])회" : "Marker ×\(m[0])"
        }
        if let m = firstMatch(#"^深度 (\d+) / 3$"#, in: key) {
            return lang == "ko" ? "깊이 \(m[0]) / 3" : "Depth \(m[0]) / 3"
        }
        if let m = firstMatch(#"^平均調律 ([0-9.]+)秒$"#, in: key) {
            return lang == "ko" ? "평균 조율 \(m[0])초" : "Average tuning \(m[0])s"
        }
        if let m = firstMatch(#"^宝玉レベル(\d+)まで([0-9.]+)秒$"#, in: key) {
            return lang == "ko" ? "보옥 Lv. \(m[0])까지 \(m[1])초" : "\(m[1])s to Gem Lv. \(m[0])"
        }
        if key == "宝玉レベル4圏内 / Lv5まで0.80秒" {
            return lang == "ko" ? "보옥 Lv. 4 범위 / Lv5까지 0.80초" : "Gem Lv. 4 range / 0.80s to Lv. 5"
        }
        if key == "宝玉レベル5圏内" {
            return lang == "ko" ? "보옥 Lv. 5 범위" : "Gem Lv. 5 range"
        }
        if key.hasPrefix("残響  --") {
            return lang == "ko" ? "잔향  --  /  Lv2 4.00초  Lv3 2.00초  Lv4 1.00초  Lv5 0.80초" : "Echo  --  /  Lv2 4.00s  Lv3 2.00s  Lv4 1.00s  Lv5 0.80s"
        }
        if let m = firstMatch(#"^残響  平均調律 ([0-9.]+)秒  /  (.+)$"#, in: key) {
            return lang == "ko" ? "잔향  평균 조율 \(m[0])초  /  \(t(m[1]))" : "Echo  average tuning \(m[0])s  /  \(t(m[1]))"
        }
        if let m = firstMatch(#"^(.+)のオーラ × (.+)$"#, in: key) {
            return lang == "ko" ? "\(m[0]) 오라 × \(m[1])" : "\(m[0]) Aura × \(m[1])"
        }
        if let m = firstMatch(#"^(.+) × (.+) を調律$"#, in: key) {
            return lang == "ko" ? "\(m[0]) × \(m[1]) 조율" : "Tuned \(m[0]) × \(m[1])"
        }
        if let m = firstMatch(#"^(.+) の攻撃  -(\d+)$"#, in: key) {
            return lang == "ko" ? "\(m[0]) 공격  -\(m[1])" : "\(m[0]) attack  -\(m[1])"
        }
        if let m = firstMatch(#"^5秒にHP(\d+)回復$"#, in: key) {
            return lang == "ko" ? "5초마다 HP\(m[0]) 회복" : "Recover HP\(m[0]) every 5s"
        }
        if let m = firstMatch(#"^5秒にMP(\d+)回復$"#, in: key) {
            return lang == "ko" ? "5초마다 MP\(m[0]) 회복" : "Recover MP\(m[0]) every 5s"
        }
        if let m = firstMatch(#"^3秒にHP(\d+)回復 / ミス2倍$"#, in: key) {
            return lang == "ko" ? "3초마다 HP\(m[0]) 회복 / 실수 피해 2배" : "Recover HP\(m[0]) every 3s / miss damage ×2"
        }
        if let m = firstMatch(#"^3秒にMP(\d+)回復 / ミス2倍$"#, in: key) {
            return lang == "ko" ? "3초마다 MP\(m[0]) 회복 / 실수 피해 2배" : "Recover MP\(m[0]) every 3s / miss damage ×2"
        }
        if let m = firstMatch(#"^最大HP \+(\d+)( / ミス2倍)?$"#, in: key) {
            let risk = m.count > 1 && !m[1].isEmpty
            return lang == "ko" ? "최대 HP +\(m[0])\(risk ? " / 실수 피해 2배" : "")" : "Max HP +\(m[0])\(risk ? " / miss damage ×2" : "")"
        }
        if let m = firstMatch(#"^最大MP \+(\d+)( / ミス2倍)?$"#, in: key) {
            let risk = m.count > 1 && !m[1].isEmpty
            return lang == "ko" ? "최대 MP +\(m[0])\(risk ? " / 실수 피해 2배" : "")" : "Max MP +\(m[0])\(risk ? " / miss damage ×2" : "")"
        }
        if let m = firstMatch(#"^調律時HP \+(\d+)( / ミス2倍)?$"#, in: key) {
            let risk = m.count > 1 && !m[1].isEmpty
            return lang == "ko" ? "조율 시 HP +\(m[0])\(risk ? " / 실수 피해 2배" : "")" : "HP +\(m[0]) on tuning\(risk ? " / miss damage ×2" : "")"
        }
        if let m = firstMatch(#"^調律時MP \+(\d+)( / ミス2倍)?$"#, in: key) {
            let risk = m.count > 1 && !m[1].isEmpty
            return lang == "ko" ? "조율 시 MP +\(m[0])\(risk ? " / 실수 피해 2배" : "")" : "MP +\(m[0]) on tuning\(risk ? " / miss damage ×2" : "")"
        }
        if let m = firstMatch(#"^回復量 \+(\d+)$"#, in: key) {
            return lang == "ko" ? "회복량 +\(m[0])" : "Heal amount +\(m[0])"
        }
        if let m = firstMatch(#"^ミスまで被害 -(\d+)$"#, in: key) {
            return lang == "ko" ? "실수 전까지 피해 -\(m[0])" : "Damage -\(m[0]) until first miss"
        }
        if let m = firstMatch(#"^ミス/被弾まで 拍(\d+)%$"#, in: key) {
            return lang == "ko" ? "실수/피격 전까지 박 \(m[0])%" : "Beat \(m[0])% until miss/hit"
        }
        if let m = firstMatch(#"^ミス時被害 (\d+)%$"#, in: key) {
            return lang == "ko" ? "실수 피해 \(m[0])%" : "Miss damage \(m[0])%"
        }
        if let m = firstMatch(#"^被害 (\d+)%$"#, in: key) {
            return lang == "ko" ? "피해 \(m[0])%" : "Damage \(m[0])%"
        }
        if let m = firstMatch(#"^HP(\d+)%以上 拍(\d+)%$"#, in: key) {
            return lang == "ko" ? "HP \(m[0])% 이상 박 \(m[1])%" : "Beat \(m[1])% at HP \(m[0])%+"
        }
        if let m = firstMatch(#"^HP(\d+)%以下 拍(\d+)%$"#, in: key) {
            return lang == "ko" ? "HP \(m[0])% 이하 박 \(m[1])%" : "Beat \(m[1])% at HP \(m[0])% or less"
        }
        if let m = firstMatch(#"^被弾時 拍(\d+)%$"#, in: key) {
            return lang == "ko" ? "피격 시 박 \(m[0])%" : "Beat \(m[0])% on hit"
        }
        if let m = firstMatch(#"^技使用時 拍-([0-9.]+)秒$"#, in: key) {
            return lang == "ko" ? "기술 사용 시 박 -\(m[0])초" : "Beat -\(m[0])s on skill use"
        }
        if let m = firstMatch(#"^技間隔 -(\d+)秒$"#, in: key) {
            return lang == "ko" ? "기술 간격 -\(m[0])초" : "Skill cooldown -\(m[0])s"
        }
        if let m = firstMatch(#"^技効果 \+(\d+)秒$"#, in: key) {
            return lang == "ko" ? "기술 효과 +\(m[0])초" : "Skill effect +\(m[0])s"
        }
        if let m = firstMatch(#"^敵拍 (\d+)%$"#, in: key) {
            return lang == "ko" ? "적 박 \(m[0])%" : "Enemy beat \(m[0])%"
        }
        if let m = firstMatch(#"^HP/MP半分 / 敵拍(\d+)%$"#, in: key) {
            return lang == "ko" ? "HP/MP 절반 / 적 박 \(m[0])%" : "HP/MP halved / enemy beat \(m[0])%"
        }
        if let m = firstMatch(#"^被害2倍 / 敵拍(\d+)%$"#, in: key) {
            return lang == "ko" ? "피해 2배 / 적 박 \(m[0])%" : "Damage ×2 / enemy beat \(m[0])%"
        }
        if let m = firstMatch(#"^補助 \+(\d+)$"#, in: key) {
            return lang == "ko" ? "보조 +\(m[0])" : "Support +\(m[0])"
        }
        if let m = firstMatch(#"^5秒HP \+(\d+)$"#, in: key) {
            return lang == "ko" ? "5초 HP +\(m[0])" : "5s HP +\(m[0])"
        }
        if let m = firstMatch(#"^5秒MP \+(\d+)$"#, in: key) {
            return lang == "ko" ? "5초 MP +\(m[0])" : "5s MP +\(m[0])"
        }
        if let m = firstMatch(#"^3秒HP \+(\d+)$"#, in: key) {
            return lang == "ko" ? "3초 HP +\(m[0])" : "3s HP +\(m[0])"
        }
        if let m = firstMatch(#"^3秒MP \+(\d+)$"#, in: key) {
            return lang == "ko" ? "3초 MP +\(m[0])" : "3s MP +\(m[0])"
        }
        if let m = firstMatch(#"^ミス被害 ×(\d+)$"#, in: key) {
            return lang == "ko" ? "실수 피해 ×\(m[0])" : "Miss damage ×\(m[0])"
        }
        if let m = firstMatch(#"^被害 ×(\d+)$"#, in: key) {
            return lang == "ko" ? "피해 ×\(m[0])" : "Damage ×\(m[0])"
        }
        if let m = firstMatch(#"^装備コスト (\d+)/(\d+)$"#, in: key) {
            return lang == "ko" ? "장비 비용 \(m[0])/\(m[1])" : "Equip cost \(m[0])/\(m[1])"
        }

        if let m = firstMatch(#"^読み：(.+)$"#, in: key) {
            return lang == "ko" ? "읽기: \(t(m[0]))" : "Reading: \(t(m[0]))"
        }
        if let m = firstMatch(#"^距離 (.+) / 五度環 (-?\d+)$"#, in: key) {
            return lang == "ko" ? "거리 \(m[0]) / 5도환 \(m[1])" : "Distance \(m[0]) / circle \(m[1])"
        }
        if let m = firstMatch(#"^(.+) と (.+) を一緒に鳴らすと、(.+)$"#, in: key) {
            return lang == "ko" ? "\(t(m[0]))와 \(m[1])를 함께 울리면 \(t(m[2]))" : "When \(t(m[0])) and \(m[1]) sound together, \(t(m[2]))"
        }
        if let m = firstMatch(#"^(.+)調$"#, in: key) {
            return lang == "ko" ? "\(m[0])조" : "Key: \(m[0])"
        }
        if let m = firstMatch(#"^調外 (\d+)音まで$"#, in: key) {
            return lang == "ko" ? "조 밖 \(m[0])음까지" : "Up to \(m[0]) out-of-key tones"
        }
        if let m = firstMatch(#"^分類 (.+) / (.+)$"#, in: key) {
            return lang == "ko" ? "분류 \(m[0]) / \(m[1])" : "Class \(m[0]) / \(m[1])"
        }
        if let m = firstMatch(#"^表示 (\d+)/(\d+) 上限$"#, in: key) {
            return lang == "ko" ? "표시 \(m[0])/\(m[1]) 상한" : "Showing \(m[0])/\(m[1]) limit"
        }
        if let m = firstMatch(#"^表示 (\d+)/(\d+)$"#, in: key) {
            return lang == "ko" ? "표시 \(m[0])/\(m[1])" : "Showing \(m[0])/\(m[1])"
        }
        if let m = firstMatch(#"^単独 (\d+)/12$"#, in: key) {
            return lang == "ko" ? "단독 \(m[0])/12" : "Solo \(m[0])/12"
        }
        if let m = firstMatch(#"^二重 (\d+)$"#, in: key) {
            return lang == "ko" ? "이중 \(m[0])" : "Dual \(m[0])"
        }
        if let m = firstMatch(#"^四重 (\d+)$"#, in: key) {
            return lang == "ko" ? "사중 \(m[0])" : "Quad \(m[0])"
        }
        if let m = firstMatch(#"^宝玉 (\d+)/(\d+)$"#, in: key) {
            return lang == "ko" ? "보옥 \(m[0])/\(m[1])" : "Gems \(m[0])/\(m[1])"
        }
        if let m = firstMatch(#"^技(\d+)/5 特性コスト(\d+)/(\d+)$"#, in: key) {
            return lang == "ko" ? "기술 \(m[0])/5 특성 비용 \(m[1])/\(m[2])" : "Skills \(m[0])/5 Trait cost \(m[1])/\(m[2])"
        }
        if let m = firstMatch(#"^消費MP (\d+)$"#, in: key) {
            return lang == "ko" ? "MP 소모 \(m[0])" : "MP cost \(m[0])"
        }
        if let m = firstMatch(#"^コスト (\d+) / 残 (\d+)$"#, in: key) {
            return lang == "ko" ? "비용 \(m[0]) / 남음 \(m[1])" : "Cost \(m[0]) / Left \(m[1])"
        }
        if let m = firstMatch(#"^単独 (\d+) / 12　複数 (\d+) / (\d+)$"#, in: key) {
            return lang == "ko" ? "단독 \(m[0]) / 12　복수 \(m[1]) / \(m[2])" : "Solo \(m[0]) / 12　Multi \(m[1]) / \(m[2])"
        }
        if let m = firstMatch(#"^(\d+)オーラ$"#, in: key) {
            return lang == "ko" ? "\(m[0]) 오라" : "\(m[0]) Auras"
        }

        if let m = firstMatch(#"^(.+)：稽古$"#, in: key) {
            return lang == "ko" ? "\(t(m[0])): 연습" : "\(t(m[0])): Practice"
        }
        if let m = firstMatch(#"^(.+)：攻略$"#, in: key) {
            return lang == "ko" ? "\(t(m[0])): 공략" : "\(t(m[0])): Challenge"
        }
        if let m = firstMatch(#"^(.+) から$"#, in: key) {
            return lang == "ko" ? "\(t(m[0]))에서" : "From \(t(m[0]))"
        }
        if let m = firstMatch(#"^直前: ([0-9.]+)秒$"#, in: key) {
            return lang == "ko" ? "직전: \(m[0])초" : "Last: \(m[0])s"
        }
        if let m = firstMatch(#"^右へ(\d+)$"#, in: key) {
            return lang == "ko" ? "오른쪽으로 \(m[0])" : "Right \(m[0])"
        }
        if let m = firstMatch(#"^左へ(\d+)$"#, in: key) {
            return lang == "ko" ? "왼쪽으로 \(m[0])" : "Left \(m[0])"
        }
        if let m = firstMatch(#"^右へ(\d+) / 左へ(\d+)$"#, in: key) {
            return lang == "ko" ? "오른쪽으로 \(m[0]) / 왼쪽으로 \(m[1])" : "Right \(m[0]) / Left \(m[1])"
        }
        if key == "根 / 右0・左0" {
            return lang == "ko" ? "근음 / 오른쪽 0・왼쪽 0" : "Root / Right 0・Left 0"
        }
        if let m = firstMatch(#"^父：根は0。となりを1つ目にして、(.+)。$"#, in: key) {
            return lang == "ko" ? "아버지: 근음은 0. 옆을 첫 번째로 세고 \(t(m[0]))." : "Father: The root is 0. Count the next key as 1, then go \(t(m[0]))."
        }
        if let m = firstMatch(#"^父：根の音は数えない。根は0、となりを1つ目にする。右なら(\d+)、左なら(\d+)。今回は(.+)。$"#, in: key) {
            return lang == "ko" ? "아버지: 근음은 세지 않는다. 근음은 0, 옆을 첫 번째로 센다. 오른쪽이면 \(m[0]), 왼쪽이면 \(m[1]). 이번에는 \(t(m[2]))." : "Father: Do not count the root sound. The root is 0; the next key is 1. Right is \(m[0]), left is \(m[1]). This time: \(t(m[2]))."
        }
        if key == "父：動かなくていい。根の音をそのまま選ぼう。" {
            return lang == "ko" ? "아버지: 움직이지 않아도 된다. 근음을 그대로 고르자." : "Father: No need to move. Choose the root sound as it is."
        }
        if key == "父：根の音は0。動かない時は、その根の音をそのまま選ぶ。" {
            return lang == "ko" ? "아버지: 근음은 0. 움직이지 않을 때는 그 근음을 그대로 고른다." : "Father: The root sound is 0. When you do not move, choose that root sound as it is."
        }
        if let m = firstMatch(#"^正解。(.+)へ戻って、次へ。$"#, in: key) {
            return lang == "ko" ? "정답. \(t(m[0]))로 돌아가 다음으로." : "Correct. Return to \(t(m[0])), then move on."
        }
        if let m = firstMatch(#"^違う音。答えは (.+)。戻って選び直す。$"#, in: key) {
            return lang == "ko" ? "다른 소리. 답은 \(t(m[0])). 돌아가서 다시 선택." : "Wrong sound. The answer is \(t(m[0])). Return and choose again."
        }
        if let m = firstMatch(#"^五度環距離 (.+)　/　答えを自分で選ぶ$"#, in: key) {
            return lang == "ko" ? "5도환 거리 \(m[0])　/　답을 직접 선택" : "Circle distance \(m[0])　/　Choose the answer yourself"
        }
        if let m = firstMatch(#"^最大HP \+(\d+) / 最大MP \+(\d+)$"#, in: key) {
            return lang == "ko" ? "최대 HP +\(m[0]) / 최대 MP +\(m[1])" : "Max HP +\(m[0]) / Max MP +\(m[1])"
        }

        if let m = firstMatch(#"^調律HP \+(\d+)$"#, in: key) {
            return lang == "ko" ? "조율 HP +\(m[0])" : "Tuning HP +\(m[0])"
        }
        if let m = firstMatch(#"^調律MP \+(\d+)$"#, in: key) {
            return lang == "ko" ? "조율 MP +\(m[0])" : "Tuning MP +\(m[0])"
        }
        if key == "CLEAR" {
            return lang == "ko" ? "클리어" : "CLEAR"
        }
        if key == "DEFEAT" {
            return lang == "ko" ? "패배" : "DEFEAT"
        }
        if key == "OPEN" {
            return lang == "ko" ? "열림" : "OPEN"
        }
        if key == "LOCK" {
            return lang == "ko" ? "잠김" : "LOCK"
        }
        if key == "LEVEL UP" {
            return lang == "ko" ? "레벨 업" : "LEVEL UP"
        }
        return nil
    }

    private struct TokenReplacement {
        let ja: String
        let en: String
        let ko: String
    }

    private static let tokenReplacements: [TokenReplacement] = [
        TokenReplacement(ja: "音の生き物", en: "Aura Creature", ko: "오라 생명체"),
        TokenReplacement(ja: "オーラ", en: "Aura", ko: "오라"),
        TokenReplacement(ja: "宝玉レベル", en: "Gem Lv.", ko: "보옥 Lv."),
        TokenReplacement(ja: "報酬", en: "Reward", ko: "보상"),
        TokenReplacement(ja: "効果", en: "Effect", ko: "효과"),
        TokenReplacement(ja: "所持", en: "Owned", ko: "보유"),
        TokenReplacement(ja: "入手", en: "Source", ko: "입수"),
        TokenReplacement(ja: "強化", en: "Upgrade", ko: "강화"),
        TokenReplacement(ja: "未入手", en: "Not Owned", ko: "미입수"),
        TokenReplacement(ja: "初期", en: "Initial", ko: "초기"),
        TokenReplacement(ja: "消費なし", en: "No cost", ko: "소모 없음"),
        TokenReplacement(ja: "特性なし", en: "No traits", ko: "특성 없음"),
        TokenReplacement(ja: "HP/MP 半分", en: "HP/MP halved", ko: "HP/MP 절반"),
        TokenReplacement(ja: "減速", en: "Slow", ko: "감속"),
        TokenReplacement(ja: "隠れる", en: "Hide", ko: "숨기"),
        TokenReplacement(ja: "候補", en: "Candidates", ko: "후보")
    ]

    private static func containsJapanese(_ value: String) -> Bool {
        value.range(of: #"[ぁ-んァ-ン一-龯]"#, options: .regularExpression) != nil
    }

    private static func firstMatch(_ pattern: String, in text: String) -> [String]? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange) else { return nil }
        var captures: [String] = []
        for index in 1..<match.numberOfRanges {
            let range = match.range(at: index)
            if range.location == NSNotFound {
                captures.append("")
            } else if let swiftRange = Range(range, in: text) {
                captures.append(String(text[swiftRange]))
            } else {
                captures.append("")
            }
        }
        return captures
    }
}

extension String {
    var gameLocalized: String {
        GameLocalization.t(self)
    }
}
