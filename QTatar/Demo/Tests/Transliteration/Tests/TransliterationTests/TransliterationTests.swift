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

    // Verify QırımKey Swipe v2.1 hybrid decoder directly through SuggestionsDataBaseManager.shared.matchSwipePath
    func topSwipeMatch(for rawKeys: [Character], isCyrillic: Bool = true) -> String? {
        let matches = SuggestionsDataBaseManager.shared.matchSwipePath(
            keySequence: rawKeys.map { String($0) },
            isCyrillic: isCyrillic,
            shouldCapitalize: false,
            contextWords: []
        )
        return matches.first?.text.lowercased(with: Locale(identifier: "tr"))
    }

    // 1. Cyrillic & Latin `maşalla` (including physical `ş` at Row 1, Col 10) & `sen` & `bor`
    #expect(topSwipeMatch(for: ["м", "а", "в", "п", "о", "ш", "щ", "о", "п", "а", "в", "а", "п", "о", "л", "о", "п", "а"], isCyrillic: true) == "maşalla")
    #expect(topSwipeMatch(for: ["м", "а", "ш", "л", "а", "л", "а"], isCyrillic: true) == "maşalla")
    #expect(topSwipeMatch(for: ["м", "а", "ш", "а", "л", "а"], isCyrillic: true) == "maşalla")
    #expect(topSwipeMatch(for: ["m", "a", "s", "d", "f", "g", "h", "j", "k", "l", "ş", "l", "a"], isCyrillic: false) == "maşalla")
    #expect(topSwipeMatch(for: ["с", "в", "а", "п", "е", "н"], isCyrillic: true) == "sen")
    #expect(topSwipeMatch(for: ["б", "о", "р"], isCyrillic: true) == "bor")

    // 2. Short high-frequency words with collinear transit keys & post-turnaround consonants (`bir`, `edi`, `men`, `alda`, `eli`)
    #expect(topSwipeMatch(for: ["b", "g", "y", "i", "u", "r"], isCyrillic: false) == "bir")
    #expect(topSwipeMatch(for: ["e", "d", "f", "g", "h", "j", "i"], isCyrillic: false) == "edi")
    #expect(topSwipeMatch(for: ["m", "j", "y", "t", "r", "e", "d", "f", "g", "b", "n"], isCyrillic: false) == "men")
    #expect(topSwipeMatch(for: ["a", "l", "d", "a"], isCyrillic: false) == "alda")
    #expect(topSwipeMatch(for: ["e", "l", "i"], isCyrillic: false) == "eli")

    // 3. Physical start-key distance check on 12-column Latin (`küç` vs `qılıç`, `soñ` vs `şunıñ`)
    #expect(topSwipeMatch(for: ["k", "u", "j", "v", "c"], isCyrillic: false) == "küç")
    #expect(topSwipeMatch(for: ["s", "o", "j", "n"], isCyrillic: false) == "soñ")

    // 4. Cyrillic `ъ` / `ʼ` corridor cleaning & apostrophe skipping (`soñ`, `almaq`, `quçağında`, `onıñ`, `çoq`, `bularnıñ`, `qar`, `qoya`, `qaydan`)
    #expect(topSwipeMatch(for: ["с", "о", "н", "г", "ш", "щ", "з", "х", "ъ"], isCyrillic: true) == "soñ")
    #expect(topSwipeMatch(for: ["с", "о", "н", "г", "ш", "щ", "з", "х", "ʼ"], isCyrillic: true) == "soñ")
    #expect(topSwipeMatch(for: ["с", "о", "н"], isCyrillic: true) == "soñ")
    #expect(topSwipeMatch(for: ["а", "л", "м", "а", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"], isCyrillic: true) == "almaq")
    #expect(topSwipeMatch(for: ["а", "л", "м", "а", "к"], isCyrillic: true) == "almaq")
    #expect(topSwipeMatch(for: ["к", "у", "ч", "а", "г", "ы", "н", "д", "а"], isCyrillic: true) == "quçağında")
    #expect(topSwipeMatch(for: ["к", "е", "н", "г", "ш", "щ", "з", "х", "ъ", "х", "з", "щ", "ш", "г", "н", "е", "у", "ч", "а", "г", "ш", "щ", "з", "х", "ъ", "х", "з", "щ", "ш", "ы", "н", "д", "а"], isCyrillic: true) == "quçağında")
    #expect(topSwipeMatch(for: ["о", "н", "ы", "у", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"], isCyrillic: true) == "onıñ")
    #expect(topSwipeMatch(for: ["ч", "о", "н", "е", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"], isCyrillic: true) == "çoq")
    #expect(topSwipeMatch(for: ["б", "у", "л", "а", "р", "н", "ы", "у", "к", "е", "н", "г", "ш", "щ", "з", "х", "ъ"], isCyrillic: true) == "bularnıñ")
    #expect(topSwipeMatch(for: ["к", "е", "н", "г", "ш", "щ", "з", "х", "ъ", "х", "з", "щ", "ш", "г", "н", "е", "к", "а", "р"], isCyrillic: true) == "qar")
    #expect(topSwipeMatch(for: ["к", "е", "н", "г", "ш", "щ", "з", "х", "ъ", "х", "з", "щ", "ш", "г", "н", "о", "я"], isCyrillic: true) == "qoya")
    #expect(topSwipeMatch(for: ["к", "е", "н", "г", "ш", "щ", "з", "х", "ъ", "х", "з", "щ", "ш", "г", "н", "е", "к", "а", "й", "д", "а", "н"], isCyrillic: true) == "qaydan")

    // 5. DB cleanliness (absence of Turkish/dialect forms) & NotebookLM agglutinative words
    #expect(wordFrequency("yok") == 0)
    #expect(wordFrequency("değil") == 0)
    #expect(wordFrequency("bolğan") == 0)
    #expect(wordFrequency("teşebbüslerimiz") >= 10)
    #expect(wordFrequency("qıymetlendiriñiz") >= 10)
    #expect(wordFrequency("irişimli") >= 10)
    #expect(wordFrequency("sazlamalar") >= 10)
}

@Test func phase11VelocityAnchorAndMemorySafetyVerification() throws {
    let pts: [CGPoint] = [
        CGPoint(x: 150, y: 120), // b
        CGPoint(x: 350, y: 70),  // i
        CGPoint(x: 280, y: 70),  // l (collinear dwell anchor)
        CGPoint(x: 350, y: 70),  // i
        CGPoint(x: 110, y: 20)   // r
    ]
    let dwellTimestamps: [TimeInterval] = [0.00, 0.04, 0.19, 0.23, 0.27]
    let dwellMatches = SuggestionsDataBaseManager.shared.matchSwipePath(
        keySequence: ["b", "i", "l", "i", "r"],
        isCyrillic: false,
        shouldCapitalize: false,
        contextWords: [],
        trailPoints: pts,
        timestamps: dwellTimestamps
    )
    #expect(!dwellMatches.isEmpty)
    #expect(dwellMatches.first?.text.lowercased(with: Locale(identifier: "tr")) == "bilir")

    // Edge cases: empty timestamps, single timestamp, identical timestamps (zero dt)
    let zeroDtMatches = SuggestionsDataBaseManager.shared.matchSwipePath(
        keySequence: ["m", "e", "n"],
        isCyrillic: false,
        shouldCapitalize: false,
        contextWords: [],
        trailPoints: [CGPoint(x: 240, y: 120), CGPoint(x: 80, y: 20), CGPoint(x: 210, y: 120)],
        timestamps: [1.0, 1.0, 1.0]
    )
    #expect(zeroDtMatches.first?.text.lowercased(with: Locale(identifier: "tr")) == "men")

    let singleTsMatches = SuggestionsDataBaseManager.shared.matchSwipePath(
        keySequence: ["s", "e", "n"],
        isCyrillic: false,
        shouldCapitalize: false,
        contextWords: [],
        trailPoints: [CGPoint(x: 60, y: 70), CGPoint(x: 80, y: 20), CGPoint(x: 210, y: 120)],
        timestamps: [0.5]
    )
    #expect(singleTsMatches.first?.text.lowercased(with: Locale(identifier: "tr")) == "sen")

    // Verify Jetsam / 0xdead10cc lifecycle helpers execute without error
    SuggestionsDataBaseManager.shared.releaseMemory()
    SuggestionsDataBaseManager.shared.clearUserLexicon()
    let postReleaseMatches = SuggestionsDataBaseManager.shared.matchSwipePath(
        keySequence: ["b", "i", "r"],
        isCyrillic: false,
        shouldCapitalize: false,
        contextWords: []
    )
    #expect(postReleaseMatches.first?.text.lowercased(with: Locale(identifier: "tr")) == "bir")
}

#if !canImport(UIKit)
enum Autocomplete {
    struct Suggestion: Equatable {
        let text: String
        let title: String?
        let isAutocorrect: Bool
        let isUnknown: Bool
        let additionalInfo: [String: Any]

        init(
            text: String,
            title: String? = nil,
            isAutocorrect: Bool = false,
            isUnknown: Bool = false,
            additionalInfo: [String: Any] = [:]
        ) {
            self.text = text
            self.title = title
            self.isAutocorrect = isAutocorrect
            self.isUnknown = isUnknown
            self.additionalInfo = additionalInfo
        }

        static func == (lhs: Suggestion, rhs: Suggestion) -> Bool {
            lhs.text == rhs.text && lhs.isAutocorrect == rhs.isAutocorrect && lhs.isUnknown == rhs.isUnknown
        }
    }
}

enum UIKeyboardType {
    case `default`, emailAddress, numberPad, decimalPad, phonePad, asciiCapableNumberPad, numbersAndPunctuation
}

struct UITextContentType: Hashable {
    let rawValue: String
    static let password = UITextContentType(rawValue: "password")
    static let newPassword = UITextContentType(rawValue: "newPassword")
    static let oneTimeCode = UITextContentType(rawValue: "oneTimeCode")
    static let creditCardNumber = UITextContentType(rawValue: "creditCardNumber")
    static let emailAddress = UITextContentType(rawValue: "emailAddress")
    static let telephoneNumber = UITextContentType(rawValue: "telephoneNumber")
}

protocol UITextDocumentProxy {
    var isSecureTextEntry: Bool? { get }
    var keyboardType: UIKeyboardType? { get }
    var textContentType: UITextContentType? { get }
}

enum UIApplication {
    static let willResignActiveNotification = Notification.Name("UIApplicationWillResignActive")
    static let didEnterBackgroundNotification = Notification.Name("UIApplicationDidEnterBackground")
    static let didBecomeActiveNotification = Notification.Name("UIApplicationDidBecomeActive")
    static let willEnterForegroundNotification = Notification.Name("UIApplicationWillEnterForeground")
}

extension Notification.Name {
    static let NSExtensionHostWillResignActive = Notification.Name("NSExtensionHostWillResignActive")
    static let NSExtensionHostDidEnterBackground = Notification.Name("NSExtensionHostDidEnterBackground")
    static let NSExtensionHostDidBecomeActive = Notification.Name("NSExtensionHostDidBecomeActive")
    static let NSExtensionHostWillEnterForeground = Notification.Name("NSExtensionHostWillEnterForeground")
}

enum AppConfiguration {
    static let appGroupID = "group.crh.key.keyboardplus.tests"
}

enum KeyboardPreferences {
    static var wordLearningEnabled: Bool = false
    static var ukrainianCyrillicLayoutEnabled: Bool = false
    static let defaults = UserDefaults.standard
}

enum KeyboardUsageStats {
    static let statsResetNotification = "crh.key.statsReset.tests"
    static func updateLearnedWordsCount(_ count: Int) {}
    static func recordWordLearned() {}
}
#endif




