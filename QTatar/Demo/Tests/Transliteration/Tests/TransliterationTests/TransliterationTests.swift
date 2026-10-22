import Foundation
import SQLite3
import Testing
@testable import Transliteration

/// Expected values are produced by the reference engine (qirimca/ctcorpus_translit `mod_translit.js` with
/// `ModTranslitData`), with four documented missing-capture corrections and approved exception fixes.
/// See Tools/correct_reference_captures.py and Resources/capture_corrections.json.
private let parityCases: [(String, String)] = {
    guard let url = Bundle.module.url(forResource: "parity", withExtension: "json"),
          let data = try? Data(contentsOf: url),
          let raw = try? JSONDecoder().decode([[String]].self, from: data) else { return [] }
    return raw.compactMap { $0.count == 2 ? ($0[0], $0[1]) : nil }
}()

@Test func matchesReferenceEngine() {
    #expect(parityCases.count > 5000)
    let mismatches = parityCases.filter { CrimeanTatarTransliterator.transliterate($0.0) != $0.1 }
    #expect(mismatches.isEmpty, "first mismatches: \(mismatches.prefix(10).map { "\($0.0)→\(CrimeanTatarTransliterator.transliterate($0.0)) (want \($0.1))" })")
}

@Test func typingCharacterByCharacterEqualsWholeWord() {
    var failures: [String] = []
    for (word, expected) in parityCases {
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = "x "
        for character in word {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
        }
        if document != "x " + expected { failures.append("\(word)→\(document) (want \(expected))") }
    }
    #expect(failures.isEmpty, "\(failures.prefix(10))")
}

@Test func backspaceRestoresPreviousLiveState() {
    for word in ["къырым", "ЁЛКА", "юз", "джан", "щука", "ель"] {
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = ""
        var states = [""]
        for character in word {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            states.append(document)
        }
        for expected in states.dropLast().reversed() {
            guard let edit = engine.backspace(context: document, documentID: id) else { Issue.record("no edit for \(word)"); return }
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            #expect(document == expected)
        }
    }
}

@Test func digraphAndBackspace() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    #expect(engine.append("г", context: "hello ", documentID: id) == .init(deleteCount: 0, insertion: "g"))
    #expect(engine.append("ъ", context: "hello g", documentID: id) == .init(deleteCount: 1, insertion: "ğ"))
    #expect(engine.backspace(context: "hello ğ", documentID: id) == .init(deleteCount: 1, insertion: "g"))
    #expect(engine.backspace(context: "hello g", documentID: id) == .init(deleteCount: 1, insertion: ""))
    #expect(engine.backspace(context: "hello ", documentID: id) == nil)
}

@Test func changedContextNeverDeletesUnownedText() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    _ = engine.append("г", context: "", documentID: id)
    #expect(engine.append("ъ", context: "other", documentID: id).deleteCount == 0)
    #expect(engine.backspace(context: "other moved", documentID: id) == nil)
}

@Test func changingDocumentResetsComposition() {
    var engine = CrimeanTatarTransliterator()
    _ = engine.append("г", context: "", documentID: UUID())
    #expect(engine.append("ъ", context: "g", documentID: UUID()).deleteCount == 0)
}

@Test func missingContextNeverDeletesText() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    _ = engine.append("г", context: nil, documentID: id)
    #expect(engine.append("ъ", context: nil, documentID: id).deleteCount == 0)
    #expect(engine.backspace(context: nil, documentID: id) == nil)
}

@Test func exceptionRewritesOnlyOwnedWord() {
    var engine = CrimeanTatarTransliterator()
    let id = UUID()
    var document = "prefix "
    for character in "алейкум" {
        let edit = engine.append(String(character), context: document, documentID: id)
        document = String(document.dropLast(edit.deleteCount)) + edit.insertion
    }
    #expect(document == "prefix aleyküm")
}

@Test func referenceExceptionsAcrossDigitsAndHyphens() {
    for word in ["бус-бутюн", "БУС-БУТЮН", "3-юнджи"] {
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = "prefix "
        var states = [document]
        for character in word {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            states.append(document)
        }
        #expect(document == "prefix " + CrimeanTatarTransliterator.transliterate(word))
        for expected in states.dropLast().reversed() {
            guard let edit = engine.backspace(context: document, documentID: id) else {
                Issue.record("Composition lost for \(word)")
                break
            }
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            #expect(document == expected)
        }
    }
}

/// Confirmed against the ctcorpus.org mod_translit endpoint on 2026-10-17.
@Test func postConsonantIotatedVowelsMatchLiveReference() {
    let cases = [("любов", "lübov"), ("любовь", "lübov"), ("люди", "lüdi"),
                 ("люк", "lük"), ("бюро", "büro"), ("полюшко", "polüşko"),
                 ("ля", "lâ"), ("юз", "yüz")]
    for (source, expected) in cases {
        #expect(CrimeanTatarTransliterator.transliterate(source) == expected)
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = ""
        for character in source {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
        }
        #expect(document == expected)
    }
}

@Test func thousandsOfRealWordsMatchReference() throws {
    let url = try #require(Bundle.module.url(forResource: "real_words", withExtension: "json"))
    let cases = try JSONDecoder().decode([[String]].self, from: Data(contentsOf: url))
    #expect(cases.count >= 2000)
    var failures: [String] = []
    for pair in cases {
        let source = pair[0], expected = pair[1]
        let whole = CrimeanTatarTransliterator.transliterate(source)
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = ""
        for character in source {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
        }
        if whole != expected || document != expected {
            failures.append("\(source): whole=\(whole), typing=\(document), reference=\(expected)")
        }
    }
    #expect(failures.isEmpty, "\(failures.count) mismatches: \(failures.prefix(20))")
}

@Test func capitalIotatedLettersPreserveFollowingConsonant() {
    for (source, expected) in [("ЁЛКА", "YOLKA"), ("ЦИРК", "TSİRK"),
                               ("ЮЛ", "YUL"), ("ЩК", "ŞÇK")] {
        #expect(CrimeanTatarTransliterator.transliterate(source) == expected)
    }
}

@Test func correctedExceptionsAndAllCapsDigraphsMatch() {
    let cases = [
        ("Коменда", "Komenda"),
        ("Косме", "Kosme"),
        ("муарриет", "muarririyet"),
        ("Муарриет", "Muarririyet"),
        ("МУАРРИЕТ", "MUARRİRİYET"),
        ("селямет", "selâmet"),
        ("КЪУРТУМЕР", "QURTÜMER")
    ]
    for (source, expected) in cases {
        #expect(CrimeanTatarTransliterator.transliterate(source) == expected)
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = ""
        for character in source {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
        }
        #expect(document == expected)
    }
}

@Test func emptyFieldAndRandomCombinationParity() {
    let sequences = [
        "къырымтатарджа",
        "гъает",
        "нъ",
        "джан",
        "лья",
        "бью",
        "сье",
        "подъезд",
        "объект",
        "абвгъдеёжзийклмнопрстуфхцчшщъыьэюя",
        "АБВГЪДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ",
        "йцукенгшщзхъфывапролджэячсмитьбюё"
    ]
    for sequence in sequences {
        let expected = CrimeanTatarTransliterator.transliterate(sequence)
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = ""
        var states = [document]
        for character in sequence {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            states.append(document)
        }
        #expect(document == expected, "\(sequence) -> \(document) (want \(expected))")
        for prev in states.dropLast().reversed() {
            guard let edit = engine.backspace(context: document, documentID: id) else {
                Issue.record("Backspace failed on \(sequence)")
                break
            }
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            #expect(document == prev)
        }
    }
}

@Test func multiWordSentencesAndProverbsMatchReference() {
    let sentences: [(String, String)] = [
        ("Селям алейкум, азиз достлар!", "Selâm aleyküm, aziz dostlar!"),
        ("Къырымтатар тили — бизим миллий байлыгъымыздыр.", "Qırımtatar tili — bizim milliy baylığımızdır."),
        ("Тилимиз яшаса, миллетимиз яшар.", "Tilimiz yaşasa, milletimiz yaşar."),
        ("Ана тили — миллетнинъ юреги ве рухудыр.", "Ana tili — milletniñ yüregi ve ruhudır."),
        ("Бугунь ава чокъ гузель, кунеш парылдай.", "Bugün ava çoq güzel, küneş parılday."),
        ("Яхшы сёз джан азыгъы, яман сёз баш къазыгъы.", "Yahşı söz can azığı, yaman söz baş qazığı."),
        ("Бирлик олгъан ерде берекет олур.", "Birlik olğan yerde bereket olur.")
    ]

    for (source, expected) in sentences {
        #expect(CrimeanTatarTransliterator.transliterate(source) == expected)

        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = ""
        for character in source {
            let s = String(character)
            let isLetterOrDigit = character.isLetter || character.isNumber || character == "-"
            if isLetterOrDigit {
                let edit = engine.append(s, context: document, documentID: id)
                document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            } else {
                engine.reset()
                document += s
            }
        }
        #expect(document == expected, "Sentence typing mismatch for '\(source)': got '\(document)', expected '\(expected)'")
    }
}

@Test func randomizedWordsMaintainLiveBackspaceParity() {
    let syllables = [
        "къа", "къы", "гъа", "гъы", "нъ", "дж", "лю", "ля", "юз", "ель",
        "та", "тар", "тил", "мил", "лет", "дост", "гу", "зель", "чокъ", "ях",
        "шы", "сёз", "къу", "неш", "ба", "гъча", "са", "рай", "де", "нъиз"
    ]
    var rngState: UInt64 = 0x5152_4D54_4154_4152 // Deterministic seed ("QRMTATAR")
    func nextInt(_ upperBound: Int) -> Int {
        rngState = rngState &* 6364136223846793005 &+ 1442695040888963407
        return Int((rngState >> 33) % UInt64(upperBound))
    }

    for _ in 0..<150 {
        let count = 2 + nextInt(5)
        var word = ""
        for idx in 0..<count {
            var syl = syllables[nextInt(syllables.count)]
            if idx == 0 && nextInt(3) == 0 {
                syl = syl.prefix(1).uppercased() + syl.dropFirst()
            }
            word += syl
        }

        let expected = CrimeanTatarTransliterator.transliterate(word)
        var engine = CrimeanTatarTransliterator()
        let id = UUID()
        var document = "시작 "
        var states = [document]
        for character in word {
            let edit = engine.append(String(character), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            states.append(document)
        }
        #expect(document == "시작 " + expected, "Random word '\(word)' -> '\(document)' (want '시작 \(expected)')")

        for prev in states.dropLast().reversed() {
            guard let edit = engine.backspace(context: document, documentID: id) else {
                Issue.record("Backspace failed on random word \(word)")
                break
            }
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            #expect(document == prev)
        }
    }
}

@Test func ios3CorpusPhrasesMatchTransliterator() {
    let cases: [(String, String)] = [
        // Section 2: UI Strings
        ("Бош ер", "Boş yer"),
        ("Кирсетмек", "Kirsetmek"),
        ("Кечюв", "Keçüv"),
        ("Сильмек", "Silmek"),
        ("Сильгич", "Silgiç"),
        ("Къыдырмакъ", "Qıdırmaq"),
        ("Къыдыр", "Qıdır"),
        ("Азыр", "Azır"),
        ("Сонъраки", "Soñraki"),
        ("Сазламалар", "Sazlamalar"),
        ("Меню", "Menü"),
        ("Пайлашмакъ", "Paylaşmaq"),
        ("Денъиштирмек", "Deñiştirmek"),
        ("Сакъламакъ", "Saqlamaq"),
        ("Сакълангъан", "Saqlanğan"),
        ("Режим", "Rejim"),
        ("Автоматик", "Avtomatik"),
        ("Ачыкъ", "Açıq"),
        ("Къою", "Qoyu"),
        ("Сес", "Ses"),
        ("Хата", "Hata"),
        ("Яхшы", "Yahşı"),
        ("Эбет", "Ebet"),
        ("Ёкъ", "Yoq"),
        ("Лугъат", "Luğat"),
        ("Къырымтатарджа", "Qırımtatarca"),
        // Section 3 & 4: All 65 Corpus Phrases from ios (3).md
        ("Тиль — акъыл теразесидир.", "Til — aqıl terazesidir."),
        ("Илим — акъыл чокърагъыдыр.", "İlim — aqıl çoqrağıdır."),
        ("Чокъ динъле, аз сёйле.", "Çoq diñle, az söyle."),
        ("Гузеллик козьде дегиль, сёздедир.", "Güzellik közde degil, sözdedir."),
        ("Тилини унуткъан, илини унутыр.", "Tilini unutqan, ilini unutır."),
        ("Яхшы ниет — яры мал.", "Yahşı niyet — yarı mal."),
        ("Эйилик яп да, дерьягъа ташла.", "Eyilik yap da, deryağa taşla."),
        ("Башлагъан ишинъни ташлама.", "Başlağan işiñni taşlama."),
        ("Урьмет этсенъ — урьмет корерсинъ.", "Ürmet etseñ — ürmet körersiñ."),
        ("Эм татлы, эм аджджы — тильдир.", "Em tatlı, em accı — tildir."),
        ("Бирлик эв — берекетли эв.", "Birlik ev — bereketli ev."),
        ("Ярынки ишке бугуньден давран.", "Yarınki işke bugünden davran."),
        ("Тилимиз пек зенгин экен!", "Tilimiz pek zengin eken!"),
        ("Сев тилинъни, севген киби ананъны!", "Sev tiliñni, sevgen kibi anañnı!"),
        ("Ана тилимиз — байлыгъымыздыр.", "Ana tilimiz — baylığımızdır."),
        ("Севинъиз ана тилимизни!", "Seviñiz ana tilimizni!"),
        ("Ана тили бешигимнинъ йыры олды.", "Ana tili beşigimniñ yırı oldı."),
        ("Гъурурымсынъ, ана тилим!", "Ğururımsıñ, ana tilim!"),
        ("Биз бу тильде лаф этейик!", "Biz bu tilde laf eteyik!"),
        ("Тапарсынъ тек ана тильде бирдемлик.", "Taparsıñ tek ana tilde birdemlik."),
        ("Не япсанъ яп, озь тилинъни унутма!", "Ne yapsañ yap, öz tiliñni unutma!"),
        ("Ана тильге мейиль беринъ!", "Ana tilge meyil beriñ!"),
        ("Баламызнен Ана тильде сёйлешейик!", "Balamıznen Ana tilde söyleşeyik!"),
        ("Эвимизде тек ана тильде лаф этемиз.", "Evimizde tek ana tilde laf etemiz."),
        ("Танърым дерт корьсетмесин къолуна!", "Tañrım dert körsetmesin qoluna!"),
        ("Тилинъе мельэм олайым!", "Tiliñe melem olayım!"),
        ("Бал тамлай дудагъынъдан!", "Bal tamlay dudağıñdan!"),
        ("Тили де балдан татлы!", "Tili de baldan tatlı!"),
        ("Чокъ сагъ олунъыз! Алла разы олсун!", "Çoq sağ oluñız! Alla razı olsun!"),
        ("Сиз пек яхшы лаф этесинъиз!", "Siz pek yahşı laf etesiñiz!"),
        ("Арды гурь олсун! Эшкъ олсун!", "Ardı gür olsun! Eşq olsun!"),
        ("Саба шерифинъиз хайыр олсун!", "Saba şerifiñiz hayır olsun!"),
        ("Кунь шерифинъиз хайыр олсун!", "Kün şerifiñiz hayır olsun!"),
        ("Акъшам шерифинъиз хайыр олсун!", "Aqşam şerifiñiz hayır olsun!"),
        ("Гедженъиз хайыр! Хайыргъа къаршы!", "Geceñiz hayır! Hayırğa qarşı!"),
        ("Селям! Насылсынъ? Не бар, не ёкъ?", "Selâm! Nasılsıñ? Ne bar, ne yoq?"),
        ("Корюшкенимиз не де яхшы олды!", "Körüşkenimiz ne de yahşı oldı!"),
        ("Сиз къырымтатарджа язасынъызмы?", "Siz qırımtatarca yazasıñızmı?"),
        ("Мен къырымтатар тилини огренем.", "Men qırımtatar tilini ögrenem."),
        ("Сырынъны, йырынъны шу тильде айтынъыз.", "Sırıñnı, yırıñnı şu tilde aytıñız."),
        ("Рамазан айынъыз мубарек олсун!", "Ramazan ayıñız mubarek olsun!"),
        ("Ораза байрамынъыз мубарек олсун!", "Oraza bayramıñız mubarek olsun!"),
        ("Къурбан байрамынъыз мубарек олсун!", "Qurban bayramıñız mubarek olsun!"),
        ("Джума шерифинъиз мубарек олсун!", "Cuma şerifiñiz mubarek olsun!"),
        ("Бу тиль манъа — толгъун Ай!", "Bu til maña — tolğun Ay!"),
        ("Юрегимден догъа шиирлер!", "Yüregimden doğa şiirler!"),
        ("Дильде, фикирде, иште — бирлик!", "Dilde, fikirde, işte — birlik!"),
        ("Китап — бильги анахтары.", "Kitap — bilgi anahtarı."),
        ("Аналар къадрине етейик!", "Analar qadrine yeteyik!"),
        ("Мени дуадан унутманъыз.", "Meni duadan unutmañız."),
        ("Балалар — козюмизнинъ нурудыр!", "Balalar — közümizniñ nurudır!"),
        ("Мераба, сентябрь, мераба, мектеп!", "Meraba, sentâbr, meraba, mektep!"),
        ("Эдебият — бильги ве эдеп чокърагъы.", "Edebiyat — bilgi ve edep çoqrağı."),
        ("Илим барда — къарув бар!", "İlim barda — qaruv bar!"),
        ("Озь тувгъан тилимде айт, манъа!", "Öz tuvğan tilimde ayt, maña!"),
        ("«Ана» дедим мен бу тильде биринджи.", "«Ana» dedim men bu tilde birinci."),
        ("Терек тамырларына таяныр.", "Terek tamırlarına tayanır."),
        ("Мелеклерге ляйыкъ тилим, Ана тилим.", "Meleklerge lâyıq tilim, Ana tilim."),
        ("Илим — инсаннынъ кемалыдыр!", "İlim — insannıñ kemalıdır!"),
        ("Амет-Хан, коклерде Султансынъ!", "Amet-Han, köklerde Sultansıñ!"),
        ("Догъру язмагъа да огренирсинъиз!", "Doğru yazmağa da ögrenirsiñiz!"),
        ("Алла ишинъни онъ кетирсин!", "Alla işiñni oñ ketirsin!"),
        ("Сизге сагълыкъ-аманлыкъ тилеймиз!", "Sizge sağlıq-amanlıq tileymiz!"),
        ("Авада баарь къокъусы бар!", "Avada baar qoqusı bar!"),
        ("Къапымыз ачыкъ, тёрюмиз бош!", "Qapımız açıq, törümiz boş!"),
        // Attributions
        ("Къырымтатар аталар сёзю", "Qırımtatar atalar sözü"),
        ("Эшреф Шемьи-заде", "Eşref Şemi-zade"),
        ("Къырымтатар эдебияты дерслигинден", "Qırımtatar edebiyatı dersliginden"),
        ("Лёман Сулейман", "Löman Suleyman"),
        ("Къырымтатар шиириетинден", "Qırımtatar şiiriyetinden"),
        ("Рефат Чайлакъ", "Refat Çaylaq"),
        ("Къырымтатар дерслигинден", "Qırımtatar dersliginden"),
        ("Халкъ алгъышы", "Halq alğışı"),
        ("Къырымтатар айтымы", "Qırımtatar aytımı"),
        ("Эрвин Бекиров", "Ervin Bekirov"),
        ("Гунер Акъмолла", "Güner Aqmolla"),
        ("Ремзи Бурнаш", "Remzi Burnaş"),
        ("Исмаиль Гаспринский", "İsmail Gasprinskiy"),
        ("Къырымтатар эдебиятындан", "Qırımtatar edebiyatından"),
        ("Умер Ипчи", "Ümer İpçi"),
        ("Черкез-Али", "Çerkez-Ali"),
        ("Бекир Чобан-заде", "Bekir Çoban-zade"),
        ("Юнус Къандым", "Yunus Qandım"),
        ("Усеин Шамиль Тохтаргъазы", "Üsein Şamil Tohtarğazı"),
        ("Риза Фазыл", "Riza Fazıl"),
        // Section 5 of ios_verified.md: 15 UI elements
        ("буюк арифлер", "büyük arifler"),
        ("ракъамлар ве темсиллер", "raqamlar ve temsiller"),
        ("къапатмакъ", "qapatmaq"),
        ("сечип алмакъ", "seçip almaq"),
        ("дёгмени басмакъ", "dögmeni basmaq"),
        ("ёлламакъ", "yollamaq"),
        ("девам этмек", "devam etmek"),
        ("Къырымтатар клавиатурасы", "Qırımtatar klaviaturası"),
        ("метин кирсетюв ери", "metin kirsetüv yeri"),
        ("тиклемек", "tiklemek"),
        // Additional Corpus Phrases & Attributions from ios_verified.md (1..85)
        ("Аталар сёзюнде алтын бар.", "Atalar sözünde altın bar."),
        ("Аталар сёзю — акъылнынъ козю.", "Atalar sözü — aqılnıñ közü."),
        ("Яхшы сёз — джан азыгъы.", "Yahşı söz — can azığı."),
        ("Тиль — юрекнинъ анахтары.", "Til — yürekniñ anahtarı."),
        ("Аз айт, наз айт!", "Az ayt, naz ayt!"),
        ("Тильге урьмет — ильге урьметтир.", "Tilge ürmet — ilge ürmettir."),
        ("Сёзюнънен ишинъ бир олсун!", "Sözüñnen işiñ bir olsun!"),
        ("Кишининъ сёзюнен иши бир олмалы.", "Kişiniñ sözünen işi bir olmalı."),
        ("Акъикъий сёз акъкъан сувны токътатыр.", "Aqiqiy söz aqqan suvnı toqtatır."),
        ("Татлы сёз балдан татлы.", "Tatlı söz baldan tatlı."),
        ("Ана тилинъ — балдан татлы.", "Ana tiliñ — baldan tatlı."),
        ("Тилинънен гонълюнъ бир олмалы.", "Tiliñnen göñlüñ bir olmalı."),
        ("Гонълюнъдеки — тилинъде.", "Göñlüñdeki — tiliñde."),
        ("Эмек — омюрнинъ зинетидир.", "Emek — ömürniñ zinetidir."),
        ("Бирлик эвде берекет бар.", "Birlik evde bereket bar."),
        ("Мухаббетлик — бахт анахтары.", "Muhabbetlik — baht anahtarı."),
        ("Тилини джойгъан, Ватаныны джояр.", "Tilini coyğan, Vatanını coyar."),
        ("Ашнынъ дады — тузнен, адамнынъ дады — сёзнен.", "Aşnıñ dadı — tuznen, adamnıñ dadı — söznen."),
        ("Къулакъ — эки, тиль — бир: эки динъле, бир сёйле.", "Qulaq — eki, til — bir: eki diñle, bir söyle."),
        ("Тильни бильмек — достлукъны къавийлештирмектир.", "Tilni bilmek — dostluqnı qaviyleştirmektir."),
        ("Бир фильджан къавенинъ къыркъ йыл хатри бардыр.", "Bir filcan qaveniñ qırq yıl hatri bardır."),
        ("Ана тилим — джаным-джигерим.", "Ana tilim — canım-cigerim."),
        ("Ана тилим — халкънынъ темели.", "Ana tilim — halqnıñ temeli."),
        ("Тиль — бизим темелимиз!", "Til — bizim temelimiz!"),
        ("Озь тилини бильсин эр кес!", "Öz tilini bilsin er kes!"),
        ("Дюньяда энъ татлы — къырымтатар тилимиз!", "Dünyada eñ tatlı — qırımtatar tilimiz!"),
        ("Севдигим ана тиль — рухумнынъ гъыдасы.", "Sevdigim ana til — ruhumnıñ ğıdası."),
        ("Ана тилим — бу муаббетлик, севги сыры.", "Ana tilim — bu muabbetlik, sevgi sırı."),
        ("Ана тили аэнклидир, йымшакътыр.", "Ana tili aenklidir, yımşaqtır."),
        ("Сен бар экеч, мен де барым!", "Sen bar ekeç, men de barım!"),
        ("Тилинъни биль, окъу, яз!", "Tiliñni bil, oqu, yaz!"),
        ("Сырынъны, йырынъны шу тильде айтынъыз!", "Sırıñnı, yırıñnı şu tilde aytıñız!"),
        ("Чатыртав кибидир — бу Ана тилим!", "Çatırtav kibidir — bu Ana tilim!"),
        ("Окъуп-язам мен бугунь!", "Oqup-yazam men bugün!"),
        ("Юрекни охшар татлы сёзлеринъ!", "Yürekni ohşar tatlı sözleriñ!"),
        ("Тувгъан тилим! Гузель тилим!", "Tuvğan tilim! Güzel tilim!"),
        ("Эллеринъиз дерт корьмесин!", "Elleriñiz dert körmesin!"),
        ("Элинъе сагълыкъ!", "Eliñe sağlıq!"),
        ("Берген эль дерт корьмез.", "Bergen el dert körmez."),
        ("Унерли къолда берекет бар.", "Ünerli qolda bereket bar."),
        ("Агъзынъыздан бал тамлай!", "Ağzıñızdan bal tamlay!"),
        ("Хош сефа кельдинъиз!", "Hoş sefa keldiñiz!"),
        ("Саба шерфинъиз хайыр олсун!", "Saba şerfiñiz hayır olsun!"),
        ("Хайырлы сабалар олсун!", "Hayırlı sabalar olsun!"),
        ("Кунюнъиз хайырлы олсун!", "Künüñiz hayırlı olsun!"),
        ("Акъшам шерфинъиз хайыр олсун!", "Aqşam şerfiñiz hayır olsun!"),
        ("Геджелер хайыр! Хайыргъа къаршы!", "Geceler hayır! Hayırğa qarşı!"),
        ("Геджелер хайыр!", "Geceler hayır!"),
        ("Шехр-у Рамазан, мерхаба!", "Şehr-u Ramazan, merhaba!"),
        ("Ораза байрамынъыз хайырлы олсун!", "Oraza bayramıñız hayırlı olsun!"),
        ("Къурбан байрамынъыз хайырлы олсун!", "Qurban bayramıñız hayırlı olsun!"),
        ("Джума кунюнъиз мубарек олсун!", "Cuma künüñiz mubarek olsun!"),
        ("Амет-Хан — тиллерде дестансынъ!", "Amet-Han — tillerde destansıñ!"),
        ("Ант эткенмен яраны сармагъа!", "Ant etkenmen yaranı sarmağa!"),
        ("Наврез кельди — яз кельди!", "Navrez keldi — yaz keldi!"),
        ("Тильде, фикирде, иште — бирлик!", "Tilde, fikirde, işte — birlik!"),
        ("Козю ёкъ — корьсете, сёзю ёкъ — огрете: Китап.", "Közü yoq — körsete, sözü yoq — ögrete: Kitap."),
        ("Бирлик олгъан ерде тирлик бар.", "Birlik olğan yerde tirlik bar."),
        ("Ана-бабанъа урьмет этсенъ, озюнъ урьмет корерсинъ.", "Ana-babaña ürmet etseñ, özüñ ürmet körersiñ."),
        ("Къырым — меним Ватанымдыр!", "Qırım — menim Vatanımdır!"),
        ("Аллах кечмишлеримизни рахмет эйлесин!", "Allah keçmişlerimizni rahmet eylesin!"),
        ("Джанымыз-джигеримиз — балалар!", "Canımız-cigerimiz — balalar!"),
        ("Миллетнинъ шаны — байрагъында!", "Milletniñ şanı — bayrağında!"),
        ("Окъувны севген окъур, сонъундан гульдай къокъур.", "Oquvnı sevgen oqur, soñundan gülday qoqur."),
        ("Баарьдеки арекет — кузьдеки берекет.", "Baardeki areket — küzdeki bereket."),
        ("Шегирт олмай, уста олмазсынъ.", "Şegirt olmay, usta olmazsıñ."),
        ("Илим барда — къарув бар.", "İlim barda — qaruv bar."),
        ("Озь тувгъан тилимде айт магъа!", "Öz tuvğan tilimde ayt mağa!"),
        ("Тюркий тиллер гульзарынынъ фиданы!", "Türkiy tiller gülzarınıñ fidanı!"),
        ("Терек тамырларына таяныр, инсан — тувгъанларына.", "Terek tamırlarına tayanır, insan — tuvğanlarına."),
        ("Ёл косьтерген Чолпан йылдызым!", "Yol köstergen Çolpan yıldızım!"),
        ("Аджайипсинъ, Ана тили!", "Acayipsiñ, Ana tili!"),
        ("Ишинъиз онъ кельсин!", "İşiñiz oñ kelsin!"),
        ("Ватан — экинджи ананъ.", "Vatan — ekinci anañ."),
        ("Бирликте — къувет!", "Birlikte — quvet!"),
        // Additional Attributions from ios_verified.md
        ("Дилявер Осман", "Dilâver Osman"),
        ("Сейран Усеинов", "Seyran Üseinov"),
        ("Мамбет Аблялимов", "Mambet Ablâlimov"),
        ("Риза Халид", "Riza Halid"),
        ("Шерьян Али", "Şeryan Ali"),
        ("Васфие Къыпчакъ", "Vasfiye Qıpçaq"),
        ("Керим Джаманакълы", "Kerim Camanaqlı"),
        ("Сеитумер Эмин", "Seitümer Emin"),
        ("Шакир Селим", "Şakir Selim"),
        ("Селямлашув", "Selâmlaşuv"),
        ("Сагълыкълашув", "Sağlıqlaşuv"),
        ("Рамазан иляхиси", "Ramazan ilâhisi"),
        ("Байрам къутлавы", "Bayram qutlavı"),
        ("Джума къутлавы", "Cuma qutlavı"),
        ("Номан Челебиджихан", "Noman Çelebicihan"),
        ("Къырымтатар халкъ йыры", "Qırımtatar halq yırı"),
        ("Къырымтатар тапмаджасы", "Qırımtatar tapmacası"),
        ("Хатыра дуасы", "Hatıra duası"),
        ("Ремзие Тарсинова", "Remziye Tarsinova"),
        ("Идрис Асанин", "İdris Asanin")
    ]

    var mismatches: [String] = []
    for (cyrl, expectedLat) in cases {
        let actualLat = CrimeanTatarTransliterator.transliterate(cyrl)
        if actualLat != expectedLat {
            mismatches.append("'\(cyrl)' -> '\(actualLat)' (expected '\(expectedLat)')")
        }
    }
    #expect(mismatches.isEmpty, "Mismatches: \(mismatches)")
}

@Test func ukrainianCyrillicLayoutTransliterationAndBackspace() {
    let cases: [(String, String)] = [
        ("і", "i"),
        ("І", "İ"),
        ("и", "ı"),
        ("И", "I"),
        ("е", "e"),
        ("Е", "E"),
        ("є", "ye"),
        ("Є", "Ye"),
        ("єр", "yer"),
        ("Єр", "Yer"),
        ("ЄР", "YER"),
        ("єді", "yedi"),
        ("аєт", "ayet"),
        ("ґ", "g"),
        ("Ґ", "G"),
        ("ґє", "gye"),
        ("Ґє", "Gye"),
        ("ҐЄ", "GYE"),
        ("ґʼе", "gye"),
        ("Ґʼе", "Gye"),
        ("ҐʼЕ", "GYE"),
        ("г", "ğ"),
        ("Г", "Ğ"),
        ("гʼ", "ğ"),
        ("Гʼ", "Ğ"),
        ("гъ", "ğ"),
        ("Гъ", "Ğ"),
        ("ГЪ", "Ğ"),
        ("ге", "ğe"),
        ("Ге", "Ğe"),
        ("ГЕ", "ĞE"),
        ("гʼе", "ğe"),
        ("Гʼе", "Ğe"),
        ("кʼ", "q"),
        ("Кʼ", "Q"),
        ("кʼе", "qe"),
        ("Кʼе", "Qe"),
        ("КʼЕ", "QE"),
        ("нʼ", "ñ"),
        ("Нʼ", "Ñ"),
        ("нʼе", "ñe"),
        ("Нʼе", "Ñe"),
        ("НʼЕ", "ÑE"),
        ("ервін", "ervin"),
        ("Ервін", "Ervin"),
        ("ЕРВІН", "ERVİN"),
        ("ел", "el"),
        ("мен", "men"),
        ("кʼирим", "qırım"),
        ("Кʼирим", "Qırım"),
        ("КʼИРИМ", "QIRIM"),
        ("къирим", "qırım"),
        ("Къирим", "Qırım"),
        ("КЪИРИМ", "QIRIM"),
        ("тілі", "tili"),
        ("Тілі", "Tili"),
        ("ґузель", "güzel"),
        ("гаєт", "ğayet"),
        ("гʼаєт", "ğayet"),
        ("гъаєт", "ğayet"),
        ("джаним", "canım"),
        ("селям", "selâm"),
        ("буґунь", "bugün"),
        ("міллетнінʼ", "milletniñ"),
        ("міллетнінъ", "milletniñ"),
        ("яхши", "yahşı"),
        ("дембель", "dembel"),
        ("Дембель", "Dembel"),
        ("ДЕМБЕЛЬ", "DEMBEL"),
        ("пʼєр", "pyer"),
        ("Пʼєр", "Pyer"),
        ("ПʼЄР", "PYER"),
        ("пʼер", "pyer"),
        ("Пʼер", "Pyer"),
        ("ПʼЕР", "PYER"),
        ("ґʼє", "gye"),
        ("Ґʼє", "Gye"),
        ("ҐʼЄ", "GYE"),
        ("аʼ", "aʼ"),
        ("ʼ", "ʼ"),
        ("пʼʼ", "pʼ"),
        ("кʼʼ", "qʼ"),
        ("єшіль", "yeşil"),
        ("єшиль", "yeşil"),
        ("Єшиль", "Yeşil"),
        ("ЄШИЛЬ", "YEŞİL")
    ]
    for (source, expected) in cases {
        #expect(CrimeanTatarTransliterator.transliterate(source, ukrainianLayout: true) == expected)
        var engine = CrimeanTatarTransliterator()
        engine.ukrainianLayout = true
        let id = UUID()
        var document = ""
        var states = [document]
        for ch in source {
            let edit = engine.append(String(ch), context: document, documentID: id)
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            states.append(document)
        }
        #expect(document == expected)
        for prev in states.dropLast().reversed() {
            guard let edit = engine.backspace(context: document, documentID: id) else {
                Issue.record("Backspace failed on \(source)")
                break
            }
            document = String(document.dropLast(edit.deleteCount)) + edit.insertion
            #expect(document == prev)
        }
    }
}

@Test func phase8SwipeProperNounsAndSenNeVerification() throws {
    // 1. Verify Cyrillic swipe path "машала" / "машла" transliterates to "maşala" / "maşla" and matches "maşalla" in qırım_tatar.db
    let cyrSwipeFull = CrimeanTatarTransliterator.transliterate(["м", "а", "ш", "а", "л", "а"].joined())
    let cyrSwipeFast = CrimeanTatarTransliterator.transliterate(["м", "а", "ш", "л", "а"].joined())
    #expect(cyrSwipeFull == "maşala")
    #expect(cyrSwipeFast == "maşla")

    let testFileURL = URL(fileURLWithPath: #filePath)
    let dbURL = testFileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .appendingPathComponent("Keyboard/qırım_tatar.db")
    #expect(FileManager.default.fileExists(atPath: dbURL.path))

    var db: OpaquePointer?
    #expect(sqlite3_open_v2(dbURL.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
    defer { sqlite3_close(db) }

    func wordFrequency(_ word: String) -> Int {
        var stmt: OpaquePointer?
        defer { sqlite3_finalize(stmt) }
        guard sqlite3_prepare_v2(db, "SELECT freq FROM words WHERE word = ?1 LIMIT 1;", -1, &stmt, nil) == SQLITE_OK else { return 0 }
        let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
        _ = word.withCString { sqlite3_bind_text(stmt, 1, $0, -1, transient) }
        guard sqlite3_step(stmt) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int(stmt, 0))
    }

    #expect(wordFrequency("maşalla") > 50, "maşalla must exist with high frequency in qırım_tatar.db")
    #expect(wordFrequency("qırım") > 1000, "qırım must exist in qırım_tatar.db")
    #expect(wordFrequency("aytasıñ") > 0, "aytasıñ must exist in qırım_tatar.db")
    #expect(wordFrequency("yapasıñ") > 0, "yapasıñ must exist in qırım_tatar.db")
    #expect(wordFrequency("deysiñ") > 0, "deysiñ must exist in qırım_tatar.db")

    // Verify QırımKey Swipe v2 hybrid decoder (12-column layout geometry, Δθ >= 22° curvature weighting,
    // 16-point resampled SHARK2 trajectory comparison, ъ/ʼ corridor cleaning, physical start-key distance,
    // and two-sided (prefix, allowedEndBaseChars) candidate retrieval) on qırım_tatar.db
    let cyrToLat: [Character: [Character]] = [
        "а": ["a"], "б": ["b"], "в": ["v"], "г": ["g", "ğ"], "ґ": ["g"], "д": ["d"],
        "е": ["e"], "є": ["y", "e"], "ё": ["o"], "ж": ["j", "c"], "з": ["z"], "и": ["i"],
        "і": ["i"], "ї": ["y", "i"], "й": ["y"], "к": ["q", "k"], "л": ["l"], "м": ["m"],
        "н": ["n"], "о": ["o"], "п": ["p"], "р": ["r"], "с": ["s"], "т": ["t"],
        "у": ["u"], "ф": ["f"], "х": ["h"], "ц": ["s", "t"], "ч": ["c"],
        "ш": ["s"], "щ": ["s"], "ы": ["i"], "э": ["e"], "ю": ["u"], "я": ["a"]
    ]
    let cyrNeighbors: [Character: Set<Character>] = [
        "a": ["v", "p", "u", "q", "k", "c", "s", "m"],
        "c": ["a", "s", "v", "f", "i", "d", "l", "e", "z", "h"],
        "d": ["l", "j", "c", "s", "z", "b", "u"],
        "e": ["q", "k", "n", "p", "r", "j", "c", "h"],
        "g": ["n", "s", "r", "o", "a", "f"],
        "i": ["f", "v", "y", "s", "t", "m", "p", "r"],
        "k": ["u", "e", "v", "a", "p"],
        "l": ["o", "d", "s", "b", "u"],
        "m": ["s", "i", "a", "p"],
        "n": ["e", "g", "p", "r"],
        "o": ["r", "l", "g", "s", "t", "b"],
        "p": ["a", "r", "k", "q", "e", "m", "i"],
        "q": ["u", "e", "v", "a", "p"],
        "r": ["p", "o", "e", "n", "g", "i", "t"],
        "s": ["c", "m", "v", "a", "g", "z", "o", "l", "d", "y", "u"],
        "t": ["i", "b", "r", "o", "y", "u", "v"],
        "u": ["s", "t", "q", "k", "v", "a", "b", "d", "j"],
        "v": ["i", "a", "u", "q", "k", "c", "s"]
    ]
    let latNeighbors: [Character: Set<Character>] = [
        "q": ["w", "a"], "w": ["q", "e", "a", "s"], "e": ["w", "r", "s", "d"],
        "r": ["e", "t", "d", "f"], "t": ["r", "y", "f", "g"], "y": ["t", "u", "g", "h"],
        "u": ["y", "i", "h", "j"], "i": ["u", "o", "j", "k"], "o": ["i", "p", "k", "l"],
        "p": ["o", "l"], "a": ["q", "w", "s", "z"], "s": ["w", "e", "a", "d", "z", "x"],
        "d": ["e", "r", "s", "f", "x", "c"], "f": ["r", "t", "d", "g", "c", "v"],
        "g": ["t", "y", "f", "h", "v", "b"], "h": ["y", "u", "g", "j", "b", "n"],
        "j": ["u", "i", "h", "k", "n", "m"], "k": ["i", "o", "j", "l", "m"],
        "l": ["o", "p", "k"], "z": ["a", "s", "x"], "x": ["s", "d", "z", "c"],
        "c": ["d", "f", "x", "v"], "v": ["f", "g", "c", "b"], "b": ["g", "h", "v", "n"],
        "n": ["h", "j", "b", "m"], "m": ["j", "k", "n"]
    ]
    let baseVowels: Set<Character> = ["a", "e", "i", "o", "u"]
    let baseMap: [Character: Character] = ["ş": "s", "ı": "i", "ñ": "n", "ğ": "g", "ç": "c", "ö": "o", "ü": "u", "â": "a", "î": "i", "û": "u"]
    let diacriticForms: [Character: [Character]] = [
        "a": ["â"], "c": ["ç"], "g": ["ğ"], "i": ["ı"], "k": ["q"], "n": ["ñ"],
        "o": ["ö"], "s": ["ş"], "u": ["ü", "û"]
    ]

    func layoutCenters(isCyrillic: Bool) -> [Character: (x: Double, y: Double)] {
        let w = 32.0, h = 52.0
        var c: [Character: (x: Double, y: Double)] = [:]
        if !isCyrillic {
            for (i, ch) in Array("qwertyuıopğü").enumerated() { c[ch] = ((Double(i) + 0.5) * w, 0.5 * h) }
            for (i, ch) in Array("âasdfghjklşi").enumerated() { c[ch] = ((Double(i) + 0.5) * w, 1.5 * h) }
            for (i, ch) in Array("zxcvbnmöçñ").enumerated() { c[ch] = ((Double(i) + 1.5) * w, 2.5 * h) }
        } else {
            for (i, ch) in Array("йцукенгшщзхъ").enumerated() { c[ch] = ((Double(i) + 0.5) * w, 0.5 * h) }
            for (i, ch) in Array("фывапролджэ").enumerated() { c[ch] = ((Double(i) + 1.0) * w, 1.5 * h) }
            for (i, ch) in Array("ячсмитьбюё").enumerated() { c[ch] = ((Double(i) + 1.5) * w, 2.5 * h) }
            c["ʼ"] = c["ъ"]; c["і"] = c["и"]; c["є"] = c["э"]; c["ґ"] = c["г"]
        }
        return c
    }

    func wordCharCenter(_ ch: Character, centers: [Character: (x: Double, y: Double)], isCyrillic: Bool) -> (x: Double, y: Double)? {
        if !isCyrillic { return centers[ch] ?? centers[baseMap[ch] ?? ch] }
        switch ch {
        case "a", "â": return centers["а"]
        case "b": return centers["б"]
        case "c", "d": return centers["д"]
        case "ç": return centers["ч"]
        case "e": return centers["е"]
        case "f": return centers["ф"]
        case "g", "ğ": return centers["г"]
        case "h": return centers["х"]
        case "ı", "i", "î": return centers["и"]
        case "j": return centers["ж"]
        case "k", "q": return centers["к"]
        case "l": return centers["л"]
        case "m": return centers["м"]
        case "n", "ñ": return centers["н"]
        case "o", "ö": return centers["о"]
        case "p": return centers["п"]
        case "r": return centers["р"]
        case "s": return centers["с"]
        case "ş": return centers["ш"]
        case "t": return centers["т"]
        case "u", "ü", "û": return centers["у"]
        case "v": return centers["в"]
        case "y": return centers["й"]
        case "z": return centers["з"]
        default: return nil
        }
    }

    func resample16(_ pts: [(x: Double, y: Double)]) -> [(x: Double, y: Double)] {
        guard pts.count >= 2 else { return pts }
        var cum = [0.0]
        var total = 0.0
        for i in 1..<pts.count {
            total += hypot(pts[i].x - pts[i - 1].x, pts[i].y - pts[i - 1].y)
            cum.append(total)
        }
        guard total > 0.001 else { return Array(repeating: pts[0], count: 16) }
        var out: [(x: Double, y: Double)] = []
        var seg = 0
        for k in 0..<16 {
            let td = total * Double(k) / 15.0
            while seg + 1 < cum.count - 1 && cum[seg + 1] < td { seg += 1 }
            let len = cum[seg + 1] - cum[seg]
            let t = len > 0.0001 ? min(1.0, max(0.0, (td - cum[seg]) / len)) : 0.0
            out.append((pts[seg].x + (pts[seg + 1].x - pts[seg].x) * t, pts[seg].y + (pts[seg + 1].y - pts[seg].y) * t))
        }
        return out
    }

    func topSwipeMatch(for rawKeys: [Character], isCyrillic: Bool = true) -> String? {
        let centers = layoutCenters(isCyrillic: isCyrillic)
        let signChars: Set<Character> = ["ъ", "ь", "\u{02BC}", "'", "’"]
        let row0Corridor: Set<Character> = ["у", "к", "е", "н", "г", "ш", "щ", "з", "х"]
        let triggers: Set<Character> = ["к", "г", "н"]
        var removed = Set<Int>()
        var explicitDia = Set<Character>()
        if isCyrillic {
            for (idx, ch) in rawKeys.enumerated() where signChars.contains(ch) {
                removed.insert(idx)
                var scan = idx - 1
                var tPos: Int? = nil
                while scan >= 0 {
                    if triggers.contains(rawKeys[scan]) { tPos = scan }
                    if row0Corridor.contains(rawKeys[scan]) || signChars.contains(rawKeys[scan]) { scan -= 1 } else { break }
                }
                if let tp = tPos {
                    let tr = rawKeys[tp]
                    if tr == "к" { explicitDia.insert("q") }
                    else if tr == "г" { explicitDia.insert("ğ") }
                    else if tr == "н" { explicitDia.insert("ñ") }
                    if tp + 1 < idx { for k in (tp + 1)..<idx { removed.insert(k) } }
                    var fwd = idx + 1
                    while fwd < rawKeys.count && ["х", "з", "щ", "ш", "г", "н", "е"].contains(rawKeys[fwd]) {
                        removed.insert(fwd); fwd += 1
                    }
                }
            }
        }
        var keys: [Character] = []
        for (i, ch) in rawKeys.enumerated() where !removed.contains(i) {
            if keys.last != ch { keys.append(ch) }
        }
        var basePath: [Character] = []
        var basePts: [(x: Double, y: Double)] = []
        var startCandidates: [Character] = []
        var endCandidates = Set<Character>()
        var prevCyr: Character? = nil
        for (idx, ch) in keys.enumerated() {
            let pt = centers[ch]
            if isCyrillic {
                if ch == "ж", prevCyr == "д" { prevCyr = ch; continue }
                var mapped = cyrToLat[ch] ?? []
                if ch == "д", idx + 1 < keys.count, keys[idx + 1] == "ж" { mapped = ["c", "d"] }
                let isStartOrAfterVowel = basePath.isEmpty || (prevCyr.map { ["а","е","є","ё","и","і","ї","о","у","ы","э","ю","я"].contains($0) } ?? false)
                if isStartOrAfterVowel {
                    if ch == "я" { mapped = ["y", "a"] }
                    else if ch == "ю" { mapped = ["y", "u"] }
                    else if ch == "ё" { mapped = ["y", "o"] }
                }
                if startCandidates.isEmpty { startCandidates = mapped }
                endCandidates = Set(mapped.map { baseMap[$0] ?? $0 })
                for m in mapped {
                    let b = baseMap[m] ?? m
                    if basePath.last != b {
                        basePath.append(b)
                        if let pt { basePts.append(pt) }
                    }
                }
                prevCyr = ch
            } else {
                let b = baseMap[ch] ?? ch
                if startCandidates.isEmpty { startCandidates = [ch, b] }
                endCandidates = [b]
                if basePath.last != b {
                    basePath.append(b)
                    if let pt { basePts.append(pt) }
                }
            }
        }
        guard let firstBase = basePath.first, basePath.count >= 2 else { return nil }
        var isAnchor = Array(repeating: true, count: basePath.count)
        var weights = Array(repeating: 1.0, count: basePath.count)
        if basePts.count == basePath.count && basePath.count >= 3 {
            for idx in 1..<(basePath.count - 1) {
                let v1x = basePts[idx].x - basePts[idx - 1].x, v1y = basePts[idx].y - basePts[idx - 1].y
                let v2x = basePts[idx + 1].x - basePts[idx].x, v2y = basePts[idx + 1].y - basePts[idx].y
                let n1 = hypot(v1x, v1y), n2 = hypot(v2x, v2y)
                if n1 > 1 && n2 > 1 {
                    let cosT = min(1.0, max(-1.0, (v1x * v2x + v1y * v2y) / (n1 * n2)))
                    let deg = acos(cosT) * 180.0 / .pi
                    if deg < 22.0 { isAnchor[idx] = false; weights[idx] = 0.20 + (deg / 22.0) * 0.18 }
                    else { isAnchor[idx] = true; weights[idx] = min(1.0, 0.70 + (deg - 22.0) / 90.0 * 0.30) }
                }
            }
        }
        let anchorCount = max(2, isAnchor.filter { $0 }.count)
        let resampledSwipe = resample16(basePts)
        let startPt = basePts.first
        let neighborMap = isCyrillic ? cyrNeighbors : latNeighbors
        var lastNeighbors = Set<Character>()
        for ec in endCandidates { lastNeighbors.formUnion(neighborMap[ec] ?? []) }
        lastNeighbors.subtract(endCandidates)

        var prefixes = Set<String>()
        for sc in startCandidates {
            let b = baseMap[sc] ?? sc
            prefixes.insert(String(b))
            for v in diacriticForms[b] ?? [] {
                if !isCyrillic && b == "k" && v == "q" { continue }
                prefixes.insert(String(v))
            }
        }
        prefixes.insert(String(firstBase))
        for v in diacriticForms[firstBase] ?? [] {
            if !isCyrillic && firstBase == "k" && v == "q" { continue }
            prefixes.insert(String(v))
        }

        let maxLen = min(22, basePath.count + 5)
        var candidates: [(String, Int)] = []
        var seen = Set<String>()
        let casingLocale = Locale(identifier: "tr")
        for pfx in prefixes {
            var stmt: OpaquePointer?
            defer { sqlite3_finalize(stmt) }
            let sql = "SELECT word, freq FROM words WHERE word >= ?1 AND word < ?2 AND freq >= 2 AND length(word) BETWEEN 2 AND ?3 AND instr(word, ' ') = 0 ORDER BY freq DESC;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { continue }
            let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)
            _ = pfx.withCString { sqlite3_bind_text(stmt, 1, $0, -1, transient) }
            let hi = pfx + "\u{FFFF}"
            _ = hi.withCString { sqlite3_bind_text(stmt, 2, $0, -1, transient) }
            sqlite3_bind_int(stmt, 3, Int32(maxLen))
            var exactCount = 0
            var neighborCount = 0
            while sqlite3_step(stmt) == SQLITE_ROW {
                if let cStr = sqlite3_column_text(stmt, 0) {
                    let w = String(cString: cStr)
                    let wl = w.lowercased(with: casingLocale)
                    if let lc = wl.last {
                        let lb = baseMap[lc] ?? lc
                        if endCandidates.contains(lb) {
                            if exactCount < 320, seen.insert(wl).inserted {
                                candidates.append((w, Int(sqlite3_column_int(stmt, 1))))
                                exactCount += 1
                            }
                        } else if lastNeighbors.contains(lb) {
                            if neighborCount < 140, seen.insert(wl).inserted {
                                candidates.append((w, Int(sqlite3_column_int(stmt, 1))))
                                neighborCount += 1
                            }
                        }
                        if exactCount >= 320 && neighborCount >= 140 { break }
                    }
                }
            }
        }

        let rawKeySet = Set(keys)
        let innerUpperBound = max(1, basePath.count - 1)
        var bestWord: String?
        var bestScore = -Double.infinity
        for (word, freq) in candidates {
            let lower = word.lowercased(with: casingLocale)
            guard let firstWordChar = lower.first else { continue }
            var wordBase: [Character] = []
            var wordPts: [(x: Double, y: Double)] = []
            for ch in lower where ch != "-" {
                let b = baseMap[ch] ?? ch
                if wordBase.last != b {
                    wordBase.append(b)
                    if let pt = wordCharCenter(ch, centers: centers, isCyrillic: isCyrillic) { wordPts.append(pt) }
                }
            }
            guard wordBase.count >= 2, let wordLast = wordBase.last else { continue }
            let exactLast = endCandidates.contains(wordLast)
            let neighborLast = !exactLast && lastNeighbors.contains(wordLast)
            guard exactLast || neighborLast else { continue }
            var pathIdx = 0, exactHits = 0, neighborHits = 0, misses = 0, repeatedVowelMisses = 0
            var weightedExact = 0.0, matchedAnchors = 0, transitOnly = 0, startBonus = 0.0
            var matchedVowels = Set<Character>()
            for (i, targetChar) in wordBase.enumerated() {
                if i == 0 {
                    if let u1 = startPt, let k1 = wordCharCenter(firstWordChar, centers: centers, isCyrillic: isCyrillic) {
                        let d0 = hypot(u1.x - k1.x, u1.y - k1.y) / 32.0
                        if d0 <= 0.75 { exactHits += 1; weightedExact += 1.0; matchedAnchors += 1; startBonus = 1.65 }
                        else if d0 <= 1.75 { neighborHits += 1; weightedExact += 0.65; startBonus = 0.25 }
                        else { neighborHits += 1; weightedExact += 0.30; startBonus = -min(2.6, d0 * 0.42) }
                    } else {
                        exactHits += 1; weightedExact += 1.0; matchedAnchors += 1
                    }
                    if baseVowels.contains(targetChar) { matchedVowels.insert(targetChar) }
                    pathIdx = 1
                    continue
                }
                if i == wordBase.count - 1 {
                    if exactLast { exactHits += 1; weightedExact += 1.0; matchedAnchors += 1 }
                    else { neighborHits += 1 }
                    continue
                }
                var searchLimit = innerUpperBound
                if baseVowels.contains(targetChar), i + 1 < wordBase.count - 1 {
                    let nextChar = wordBase[i + 1]
                    if !baseVowels.contains(nextChar),
                       let nextPos = basePath[pathIdx..<innerUpperBound].lastIndex(of: nextChar),
                       !basePath[pathIdx..<nextPos].contains(targetChar) {
                        searchLimit = nextPos
                    }
                }
                var foundExact = false
                for sIdx in pathIdx..<searchLimit where basePath[sIdx] == targetChar {
                    foundExact = true; pathIdx = sIdx + 1; exactHits += 1
                    weightedExact += weights[sIdx]
                    if isAnchor[sIdx] { matchedAnchors += 1 } else { transitOnly += 1 }
                    if baseVowels.contains(targetChar) { matchedVowels.insert(targetChar) }
                    break
                }
                if !foundExact {
                    let nSet = neighborMap[targetChar] ?? []
                    var foundN = false
                    for nIdx in pathIdx..<searchLimit where nSet.contains(basePath[nIdx]) {
                        foundN = true; pathIdx = nIdx + 1; neighborHits += 1; break
                    }
                    if !foundN {
                        misses += 1
                        if (baseVowels.contains(targetChar) && (matchedVowels.contains(targetChar) || wordLast == targetChar))
                            || (wordBase.count >= 5 && (targetChar == wordBase.first || targetChar == wordLast)) {
                            repeatedVowelMisses += 1
                        }
                    }
                }
            }
            let maxAllowedMisses = wordBase.count <= 3 ? 0 : max(1, (wordBase.count - 1) / 2)
            guard misses <= maxAllowedMisses else { continue }
            var specificBonus = startBonus
            if isCyrillic {
                if rawKeySet.contains("ш") || rawKeySet.contains("щ") {
                    if lower.contains("ş") { specificBonus += 1.8 }
                    else if lower.contains("s") && !rawKeySet.contains("с") { specificBonus -= 1.2 }
                }
                if rawKeySet.contains("с") && lower.contains("s") { specificBonus += 0.8 }
                if rawKeySet.contains("ч") && lower.contains("ç") { specificBonus += 1.6 }
                for d in explicitDia where lower.contains(d) { specificBonus += 1.8 }
            }
            var geoBonus = 0.0
            if resampledSwipe.count == 16 && wordPts.count >= 2 {
                let rw = resample16(wordPts)
                var ds = 0.0
                for k in 0..<16 { ds += hypot(resampledSwipe[k].x - rw[k].x, resampledSwipe[k].y - rw[k].y) }
                geoBonus = max(-2.6, (1.20 - (ds / 16.0) / 32.0) * 1.95)
            }
            let regularMisses = max(0, misses - repeatedVowelMisses)
            let missPenalty = Double(regularMisses) * 1.65 + Double(repeatedVowelMisses) * 0.35
            let coverageRatio = (weightedExact + Double(neighborHits) * 0.55 - missPenalty) / max(2.0, Double(wordBase.count) - Double(repeatedVowelMisses) * 0.5)
            let matchedKeyBonus = min(weightedExact * 0.95 + Double(neighborHits) * 0.35, 7.5)
            let allExactBonus = (exactHits == wordBase.count && misses == 0 && neighborHits == 0) ? 1.8 : 0.0
            let anchorBonus = (matchedAnchors == anchorCount && wordBase.count == anchorCount && misses == 0) ? 2.1 : 0.0
            let unanchoredPenalty = Double(max(0, transitOnly)) * 0.55
            let lengthPenalty = Double(max(0, wordBase.count - basePath.count)) * 0.55 + Double(max(0, basePath.count - wordBase.count)) * 0.02
            let endBonus = exactLast ? 2.5 : 0.4
            let freqScore = log10(Double(max(1, freq)) + 1.35) * 1.35
            let score = (coverageRatio * 6.0) + matchedKeyBonus + allExactBonus + anchorBonus + geoBonus + endBonus + freqScore + specificBonus - lengthPenalty - unanchoredPenalty
            if score > bestScore { bestScore = score; bestWord = word }
        }
        return bestWord
    }

    // 1. Cyrillic `машалла` & `сен` & `бор`
    #expect(topSwipeMatch(for: ["м", "а", "в", "п", "о", "ш", "щ", "о", "п", "а", "в", "а", "п", "о", "л", "о", "п", "а"], isCyrillic: true) == "maşalla")
    #expect(topSwipeMatch(for: ["м", "а", "ш", "л", "а", "л", "а"], isCyrillic: true) == "maşalla")
    #expect(topSwipeMatch(for: ["м", "а", "ш", "а", "л", "а"], isCyrillic: true) == "maşalla")
    #expect(topSwipeMatch(for: ["с", "в", "а", "п", "е", "н"], isCyrillic: true) == "sen")
    #expect(topSwipeMatch(for: ["б", "о", "р"], isCyrillic: true) == "bor")

    // 2. Short high-frequency words with collinear transit keys (`bir`, `edi`, `men`)
    #expect(topSwipeMatch(for: ["b", "g", "y", "i", "u", "r"], isCyrillic: false) == "bir")
    #expect(topSwipeMatch(for: ["e", "d", "f", "g", "h", "j", "i"], isCyrillic: false) == "edi")
    #expect(topSwipeMatch(for: ["m", "j", "y", "t", "r", "e", "d", "f", "g", "b", "n"], isCyrillic: false) == "men")

    // 3. Physical start-key distance check on 12-column Latin (`küç` vs `qılıç`, `soñ` vs `şunıñ`)
    #expect(topSwipeMatch(for: ["k", "u", "j", "v", "c"], isCyrillic: false) == "küç")
    #expect(topSwipeMatch(for: ["s", "o", "j", "n"], isCyrillic: false) == "soñ")

    // 4. Cyrillic `ъ` / `ʼ` corridor cleaning & apostrophe skipping (`soñ`, `almaq`, `quçağında`)
    #expect(topSwipeMatch(for: ["с", "о", "н", "г", "ш", "щ", "з", "х", "ъ"], isCyrillic: true) == "soñ")
    #expect(topSwipeMatch(for: ["с", "о", "н", "г", "ш", "щ", "з", "х", "ʼ"], isCyrillic: true) == "soñ")
    #expect(topSwipeMatch(for: ["с", "о", "н"], isCyrillic: true) == "soñ")
    #expect(topSwipeMatch(for: ["а", "л", "м", "а", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"], isCyrillic: true) == "almaq")
    #expect(topSwipeMatch(for: ["а", "л", "м", "а", "к"], isCyrillic: true) == "almaq")
    #expect(topSwipeMatch(for: ["к", "у", "ч", "а", "г", "ы", "н", "д", "а"], isCyrillic: true) == "quçağında")
    #expect(topSwipeMatch(for: ["к", "е", "н", "г", "ш", "щ", "з", "х", "ъ", "х", "з", "щ", "ш", "г", "н", "е", "у", "ч", "а", "г", "ш", "щ", "з", "х", "ъ", "х", "з", "щ", "ш", "ы", "н", "д", "а"], isCyrillic: true) == "quçağında")

    // 5. DB cleanliness (absence of Turkish/dialect forms) & NotebookLM agglutinative words
    #expect(wordFrequency("yok") == 0)
    #expect(wordFrequency("değil") == 0)
    #expect(wordFrequency("bolğan") == 0)
    #expect(wordFrequency("teşebbüslerimiz") >= 10)
    #expect(wordFrequency("qıymetlendiriñiz") >= 10)
    #expect(wordFrequency("irişimli") >= 10)
    #expect(wordFrequency("sazlamalar") >= 10)
}



