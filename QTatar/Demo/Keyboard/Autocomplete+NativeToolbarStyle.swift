//
//  Autocomplete+NativeToolbarStyle.swift
//  Keyboard
//
//  Created by Mustafa Bekirov on 06.06.2026.
//

import KeyboardKit
import SwiftUI
import UIKit

/// Verified Crimean Tatar motivational greeting / wisdom phrase for the keyboard's top banner.
/// Follows the unified Display = On Tap principle (`ios_verified.md`) and is 100% verified against `CrimeanTatarTransliterator`.
struct KeyboardGreetingPhrase: Identifiable, Equatable {
    let id: Int
    let defaultText: String
    let defaultAttribution: String?
    let defaultTranslationUA: String
    let defaultTranslationEN: String

    init(
        id: Int,
        text: String,
        attribution: String?,
        translationUA: String,
        translationEN: String
    ) {
        self.id = id
        self.defaultText = text
        self.defaultAttribution = attribution
        self.defaultTranslationUA = translationUA
        self.defaultTranslationEN = translationEN
    }

    private static func localizedValue(forKey key: String, language: String, fallback: String) -> String {
        let bundle = KeyboardPreferences.localizationBundle(for: language)
        let sentinel = "__MISSING_\(key)__"
        let resolved = bundle.localizedString(forKey: key, value: sentinel, table: "DailyPhrases")
        if resolved == sentinel || resolved == key {
            return fallback
        }
        return resolved
    }

    var text: String {
        let val = Self.localizedValue(forKey: "phrase.\(id).text", language: "crh", fallback: defaultText)
        return val.isEmpty ? defaultText : val
    }

    var attribution: String? {
        let fallback = defaultAttribution ?? ""
        let val = Self.localizedValue(forKey: "phrase.\(id).attribution", language: "crh", fallback: fallback)
        return val.isEmpty ? nil : val
    }

    var translationUA: String {
        let val = Self.localizedValue(forKey: "phrase.\(id).translation", language: "uk", fallback: defaultTranslationUA)
        return val.isEmpty ? defaultTranslationUA : val
    }

    var translationEN: String {
        let val = Self.localizedValue(forKey: "phrase.\(id).translation", language: "en", fallback: defaultTranslationEN)
        return val.isEmpty ? defaultTranslationEN : val
    }

    var bannerCRH: String { text }

    /// Ready-to-insert text for `textDocumentProxy.insertText(...)`:
    /// automatically wraps `text` in guillemets and appends `(attribution)` when `attribution` is non-nil.
    var insertText: String {
        if let attribution, !attribution.isEmpty {
            let normalized = text
                .replacingOccurrences(of: "«", with: "\"")
                .replacingOccurrences(of: "»", with: "\"")
            return "«\(normalized)» (\(attribution))"
        } else {
            return text
        }
    }


    /// Formats the text to insert when the user taps the greeting banner according to the active interface language.
    func formattedInsertText(for interfaceLanguage: String) -> String {
        let translation: String
        switch interfaceLanguage {
        case "uk":
            translation = translationUA
        case "en":
            translation = translationEN
        default:
            return insertText
        }
        guard !translation.isEmpty else {
            return insertText
        }
        return "\(insertText)\n— \(translation)"
    }

    static let all: [KeyboardGreetingPhrase] = [
        .init(
            id: 1,
            text: "Atalar sözünde altın bar.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«У словах предків є золото.» (Кримськотатарське прислів'я)",
            translationEN: "\"There is gold in the words of ancestors.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 2,
            text: "Atalar sözü — aqılnıñ közü.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Слово предків — око розуму.» (Кримськотатарське прислів'я)",
            translationEN: "\"The word of ancestors is the eye of the mind.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 3,
            text: "Yahşı söz — can azığı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Добре слово — пожива для душі.» (Кримськотатарське прислів'я)",
            translationEN: "\"A kind word is nourishment for the soul.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 4,
            text: "Til — aqıl terazesidir.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Мова — це терези розуму.» (Кримськотатарське прислів'я)",
            translationEN: "\"Language is the scales of the mind.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 5,
            text: "Til — yürekniñ anahtarı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Мова — ключ до серця.» (Кримськотатарське прислів'я)",
            translationEN: "\"Language is the key to the heart.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 6,
            text: "Az ayt, naz ayt!",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Мало кажи — вишукано кажи!» (Кримськотатарське прислів'я)",
            translationEN: "\"Speak little, speak gracefully!\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 7,
            text: "Tilge ürmet — ilge ürmettir.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Повага до мови — це повага до народу.» (Кримськотатарське прислів'я)",
            translationEN: "\"Respect for the language is respect for the people.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 8,
            text: "Sözüñnen işiñ bir olsun!",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Нехай твоє слово і твоє діло будуть єдиними!» (Кримськотатарське прислів'я)",
            translationEN: "\"Let your word and your deed be one!\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 9,
            text: "Kişiniñ sözünen işi bir olmalı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Слово і діло людини мають бути єдиними.» (Кримськотатарське прислів'я)",
            translationEN: "\"A person's word and deed must be one.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 10,
            text: "Aqiqiy söz aqqan suvnı toqtatır.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Правдиве слово зупинить і плинну воду.» (Кримськотатарське прислів'я)",
            translationEN: "\"A true word stops even flowing water.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 11,
            text: "İlim — aqıl çoqrağıdır.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Знання — це джерело розуму.» (Кримськотатарське прислів'я)",
            translationEN: "\"Knowledge is the spring of wisdom.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 12,
            text: "Tatlı söz baldan tatlı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Лагідне слово солодше за мед.» (Кримськотатарське прислів'я)",
            translationEN: "\"A sweet word is sweeter than honey.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 13,
            text: "Ana tiliñ — baldan tatlı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Рідна мова — солодша за мед.» (Кримськотатарське прислів'я)",
            translationEN: "\"Your mother tongue is sweeter than honey.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 14,
            text: "Tiliñnen göñlüñ bir olmalı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Твої слова і твоє серце мають бути єдиними.» (Кримськотатарське прислів'я)",
            translationEN: "\"Your tongue and your heart must be one.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 15,
            text: "Göñlüñdeki — tiliñde.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Що на серці — те й на язиці.» (Кримськотатарське прислів'я)",
            translationEN: "\"What is in the heart is on the tongue.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 16,
            text: "Emek — ömürniñ zinetidir.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Праця — окраса життя.» (Кримськотатарське прислів'я)",
            translationEN: "\"Labor is the adornment of life.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 17,
            text: "Birlik evde bereket bar.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«У домі, де панує єдність, є й достаток.» (Кримськотатарське прислів'я)",
            translationEN: "\"In a united home, there is abundance.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 18,
            text: "Muabbetlik — baht anahtarı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Любов і щирість — ключ до щастя.» (Кримськотатарське прислів'я)",
            translationEN: "\"Love and affection are the key to happiness.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 19,
            text: "Tilini coyğan, Vatanını coyar.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Хто втратив свою мову — втратить і Батьківщину.» (Кримськотатарське прислів'я)",
            translationEN: "\"Whoever loses their language will lose their Homeland.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 20,
            text: "Aşnıñ dadı — tuznen, adamnıñ dadı — söznen.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Смак страви — у солі, а суть людини — у слові.» (Кримськотатарське прислів'я)",
            translationEN: "\"The taste of food is in salt; the worth of a person is in words.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 21,
            text: "Qulaq — eki, til — bir: eki diñle, bir söyle.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Вух — двоє, язик — один: двічі слухай, один раз кажи.» (Кримськотатарське прислів'я)",
            translationEN: "\"Two ears, one tongue: listen twice, speak once.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 22,
            text: "Tilni bilmek — dostluqnı qaviyleştirmektir.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Знати мову — це зміцнювати дружбу.» (Кримськотатарське прислів'я)",
            translationEN: "\"Knowing a language strengthens friendship.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 23,
            text: "Bir filcan qaveniñ qırq yıl hatri bardır.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Одна філіжанка кави має сорок років пошани.» (Кримськотатарське прислів'я)",
            translationEN: "\"A single cup of coffee is remembered for forty years.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 24,
            text: "Ana tilim — canım-cigerim.",
            attribution: "Dilâver Osman",
            translationUA: "«Рідна мово моя — душе й серце моє.» (Ділявер Осман)",
            translationEN: "\"My native tongue is my heart and soul.\" (Dilâver Osman)"
        ),
        .init(
            id: 25,
            text: "Ana tilim — halqnıñ temeli.",
            attribution: "Dilâver Osman",
            translationUA: "«Рідна мова — основа народу.» (Ділявер Осман)",
            translationEN: "\"My native language is the foundation of the people.\" (Dilâver Osman)"
        ),
        .init(
            id: 26,
            text: "Til — bizim temelimiz!",
            attribution: "Seyran Üseinov",
            translationUA: "«Мова — наша основа!» (Сейран Усеїнов)",
            translationEN: "\"Language is our foundation!\" (Seyran Üseinov)"
        ),
        .init(
            id: 27,
            text: "Öz tilini bilsin er kes!",
            attribution: "Seyran Üseinov",
            translationUA: "«Нехай кожен знає свою рідну мову!» (Сейран Усеїнов)",
            translationEN: "\"Let everyone know their native language!\" (Seyran Üseinov)"
        ),
        .init(
            id: 28,
            text: "Dünyada eñ tatlı — qırımtatar tilimiz!",
            attribution: "Seyran Üseinov",
            translationUA: "«Найсолодша у світі — наша кримськотатарська мова!» (Сейран Усеїнов)",
            translationEN: "\"The sweetest in the world is our Crimean Tatar language!\" (Seyran Üseinov)"
        ),
        .init(
            id: 29,
            text: "Sev tiliñni, sevgen kibi anañnı!",
            attribution: "Eşref Şemi-zade",
            translationUA: "«Люби свою мову, як любиш свою матір!» (Ешреф Шем'ї-заде)",
            translationEN: "\"Love your language as you love your mother!\" (Eşref Şemi-zade)"
        ),
        .init(
            id: 30,
            text: "Tilimiz pek zengin eken!",
            attribution: "Eşref Şemi-zade",
            translationUA: "«Наша мова така багата!» (Ешреф Шем'ї-заде)",
            translationEN: "\"Our language is truly so rich!\" (Eşref Şemi-zade)"
        ),
        .init(
            id: 31,
            text: "Sevdigim ana til — ruhumnıñ ğıdası.",
            attribution: "Mambet Ablâlimov",
            translationUA: "«Люба рідна мова — пожива мого духу.» (Мамбет Аблялімов)",
            translationEN: "\"My beloved mother tongue is the nourishment of my spirit.\" (Mambet Ablâlimov)"
        ),
        .init(
            id: 32,
            text: "Ana tili beşigimniñ yırı oldı.",
            attribution: "Löman Suleyman",
            translationUA: "«Рідна мова стала піснею моєї колиски.» (Льоман Сулейман)",
            translationEN: "\"The mother tongue became the song of my cradle.\" (Löman Suleyman)"
        ),
        .init(
            id: 33,
            text: "Ana tilim — bu muabbetlik, sevgi sırı.",
            attribution: "Löman Suleyman",
            translationUA: "«Моя рідна мова — це доброта й таємниця любові.» (Льоман Сулейман)",
            translationEN: "\"My mother tongue is affection and the secret of love.\" (Löman Suleyman)"
        ),
        .init(
            id: 34,
            text: "Ana tili aenklidir, yımşaqtır.",
            attribution: "Riza Halid",
            translationUA: "«Рідна мова милозвучна й лагідна.» (Різа Халід)",
            translationEN: "\"The mother tongue is melodious and gentle.\" (Riza Halid)"
        ),
        .init(
            id: 35,
            text: "Sen bar ekeç, men de barım!",
            attribution: "Şeryan Ali",
            translationUA: "«Доки живеш ти, рідна мово, — живу і я!» (Шерьян Алі)",
            translationEN: "\"As long as you live, O native tongue, I live too!\" (Şeryan Ali)"
        ),
        .init(
            id: 36,
            text: "Tiliñni bil, oqu, yaz!",
            attribution: "Vasfiye Qıpçaq",
            translationUA: "«Знай свою мову, читай і пиши!» (Васфіє Кипчак)",
            translationEN: "\"Know your language, read, and write!\" (Vasfiye Qıpçaq)"
        ),
        .init(
            id: 37,
            text: "Sırıñnı, yırıñnı şu tilde aytıñız!",
            attribution: "Güner Aqmolla",
            translationUA: "«Свої таємниці й свої пісні розповідайте цією мовою!» (Гунер Акмолла)",
            translationEN: "\"Share your secrets and your songs in this language!\" (Güner Aqmolla)"
        ),
        .init(
            id: 38,
            text: "Çatırtav kibidir — bu Ana tilim!",
            attribution: "Kerim Camanaqlı",
            translationUA: "«Немов Чатир-Даг — ця моя рідна мова!» (Керім Джаманакли)",
            translationEN: "\"Like Chatyr-Dag is this Mother Tongue of mine!\" (Kerim Camanaqlı)"
        ),
        .init(
            id: 39,
            text: "Oqup-yazam men bugün!",
            attribution: "Seitümer Emin",
            translationUA: "«Сьогодні я читаю і пишу рідною мовою!» (Сейтумер Емін)",
            translationEN: "\"Today I read and write in my native tongue!\" (Seitümer Emin)"
        ),
        .init(
            id: 40,
            text: "Yürekni ohşar tatlı sözleriñ!",
            attribution: "Seitümer Emin",
            translationUA: "«Твої солодкі слова пестять серце!» (Сейтумер Емін)",
            translationEN: "\"Your sweet words caress the heart!\" (Seitümer Emin)"
        ),
        .init(
            id: 41,
            text: "Tuvğan tilim! Güzel tilim!",
            attribution: "Şakir Selim",
            translationUA: "«Рідна мово моя! Прекрасна мово моя!» (Шакір Селім)",
            translationEN: "\"My native tongue! My beautiful tongue!\" (Şakir Selim)"
        ),
        .init(
            id: 42,
            text: "Ne yapsañ yap, öz tiliñni unutma!",
            attribution: "Refat Çaylaq",
            translationUA: "«Що б ти не робив, не забувай своєї рідної мови!» (Рефат Чайлак)",
            translationEN: "\"Whatever you do, do not forget your native language!\" (Refat Çaylaq)"
        ),
        .init(
            id: 43,
            text: "Elleriñiz dert körmesin!",
            attribution: nil,
            translationUA: "Нехай ваші руки ніколи не знають втоми й болю!",
            translationEN: "May your hands never know pain!"
        ),
        .init(
            id: 44,
            text: "Eliñe sağlıq!",
            attribution: nil,
            translationUA: "Здоров'я твоїм рукам!",
            translationEN: "Health to your hands!"
        ),
        .init(
            id: 45,
            text: "Bergen el dert körmez.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Рука, що дає, ніколи не знатиме біди.» (Кримськотатарське прислів'я)",
            translationEN: "\"The hand that gives will know no pain.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 46,
            text: "Ünerli qolda bereket bar.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«В умілих руках — благословення й достаток.» (Кримськотатарське прислів'я)",
            translationEN: "\"In skilled hands there is blessing and abundance.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 47,
            text: "Ağzıñızdan bal tamlay!",
            attribution: nil,
            translationUA: "З ваших уст мед крапає!",
            translationEN: "Honey drips from your lips!"
        ),
        .init(
            id: 48,
            text: "Körüşkenimiz ne de yahşı oldı!",
            attribution: nil,
            translationUA: "Як же добре, що ми зустрілися!",
            translationEN: "How wonderful it is that we met!"
        ),
        .init(
            id: 49,
            text: "Hoş sefa keldiñiz!",
            attribution: nil,
            translationUA: "Ласкаво просимо, раді вашому приходу!",
            translationEN: "Welcome, we are glad you have come!"
        ),
        .init(
            id: 50,
            text: "Saba şerfiñiz hayır olsun!",
            attribution: nil,
            translationUA: "Нехай ваш благословенний ранок буде добрим!",
            translationEN: "May your blessed morning be good!"
        ),
        .init(
            id: 51,
            text: "Hayırlı sabalar olsun!",
            attribution: nil,
            translationUA: "Доброго ранку!",
            translationEN: "Good morning!"
        ),
        .init(
            id: 52,
            text: "Künüñiz hayırlı olsun!",
            attribution: nil,
            translationUA: "Нехай ваш день буде добрим і благословенним!",
            translationEN: "Have a good and blessed day!"
        ),
        .init(
            id: 53,
            text: "Aqşam şerfiñiz hayır olsun!",
            attribution: nil,
            translationUA: "Нехай ваш благословенний вечір буде добрим!",
            translationEN: "May your blessed evening be good!"
        ),
        .init(
            id: 54,
            text: "Geceler hayır!",
            attribution: nil,
            translationUA: "Доброї та спокійної ночі!",
            translationEN: "Good night!"
        ),
        .init(
            id: 55,
            text: "Şehr-u Ramazan, merhaba!",
            attribution: nil,
            translationUA: "Ласкаво просимо, благословенний місяцю Рамазан!",
            translationEN: "Welcome, O blessed month of Ramadan!"
        ),
        .init(
            id: 56,
            text: "Oraza bayramıñız hayırlı olsun!",
            attribution: nil,
            translationUA: "Нехай ваше свято Ораза-байрам буде благословенним і добрим!",
            translationEN: "May your Oraza Bayram be blessed and joyful!"
        ),
        .init(
            id: 57,
            text: "Qurban bayramıñız hayırlı olsun!",
            attribution: nil,
            translationUA: "Нехай ваше свято Курбан-байрам буде благословенним і добрим!",
            translationEN: "May your Qurban Bayram be blessed and joyful!"
        ),
        .init(
            id: 58,
            text: "Cuma künüñiz mubarek olsun!",
            attribution: nil,
            translationUA: "Нехай ваша п'ятниця буде благословенною!",
            translationEN: "May your Friday be blessed!"
        ),
        .init(
            id: 59,
            text: "Amet-Han — tillerde destansıñ!",
            attribution: "Riza Fazıl",
            translationUA: "«Амет-Хане, на устах ти — легенда!» (Різа Фазил)",
            translationEN: "\"Amet-Khan, on every tongue you are a legend!\" (Riza Fazıl)"
        ),
        .init(
            id: 60,
            text: "Bu til maña — tolğun Ay!",
            attribution: "Remzi Burnaş",
            translationUA: "«Ця мова для мене — повний Місяць!» (Ремзі Бурнаш)",
            translationEN: "\"This language is a full Moon to me!\" (Remzi Burnaş)"
        ),
        .init(
            id: 61,
            text: "Ant etkenmen yaranı sarmağa!",
            attribution: "Noman Çelebicihan",
            translationUA: "«Я присягнувся перев'язати рани свого народу!» (Номан Челебіджихан)",
            translationEN: "\"I have sworn to bind the wounds of my people!\" (Noman Çelebicihan)"
        ),
        .init(
            id: 62,
            text: "Navrez keldi — yaz keldi!",
            attribution: "Qırımtatar halq yırı",
            translationUA: "«Наврез прийшов — весна прийшла!» (Кримськотатарська народна пісня)",
            translationEN: "\"Navrez has come—spring has arrived!\" (Crimean Tatar folk song)"
        ),
        .init(
            id: 63,
            text: "Tilde, fikirde, işte — birlik!",
            attribution: "İsmail Gasprinskiy",
            translationUA: "«У мові, у думці, у ділі — єдність!» (Ісмаїл Гаспринський)",
            translationEN: "\"Unity in language, in thought, and in action!\" (İsmail Gasprinskiy)"
        ),
        .init(
            id: 64,
            text: "Kitap — bilgi anahtarı.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Книга — ключ до знань.» (Кримськотатарське прислів'я)",
            translationEN: "\"A book is the key to knowledge.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 65,
            text: "Közü yoq — körsete, sözü yoq — ögrete: Kitap.",
            attribution: "Qırımtatar tapmacası",
            translationUA: "«Очей не має — а показує, слів не має — а навчає: Книга.» (Кримськотатарська загадка)",
            translationEN: "\"Has no eyes yet shows, has no words yet teaches: A Book.\" (Crimean Tatar riddle)"
        ),
        .init(
            id: 66,
            text: "Birlik olğan yerde tirlik bar.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Де є єдність — там є життя.» (Кримськотатарське прислів'я)",
            translationEN: "\"Where there is unity, there is life.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 67,
            text: "Ana-babaña ürmet etseñ, özüñ ürmet körersiñ.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Шануватимеш батька й матір — сам зазнаєш пошани.» (Кримськотатарське прислів'я)",
            translationEN: "\"Honor your mother and father, and you too will be honored.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 68,
            text: "Qırım — menim Vatanımdır!",
            attribution: "Çerkez-Ali",
            translationUA: "«Крим — моя рідна Батьківщина!» (Черкез-Алі)",
            translationEN: "\"Crimea is my native Homeland!\" (Çerkez-Ali)"
        ),
        .init(
            id: 69,
            text: "Allah keçmişlerimizni rahmet eylesin!",
            attribution: nil,
            translationUA: "Нехай Всевишній помилує душі наших померлих предків!",
            translationEN: "May God have mercy on the souls of our departed ancestors!"
        ),
        .init(
            id: 70,
            text: "Canımız-cigerimiz — balalar!",
            attribution: "Remziye Tarsinova",
            translationUA: "«Наша душа й серце — це діти!» (Ремзіє Тарсінова)",
            translationEN: "\"Our heart and soul are our children!\" (Remziye Tarsinova)"
        ),
        .init(
            id: 71,
            text: "Milletniñ şanı — bayrağında!",
            attribution: "Noman Çelebicihan",
            translationUA: "«Слава й честь народу — у його прапорі!» (Номан Челебіджихан)",
            translationEN: "\"The glory and honor of a nation are in its flag!\" (Noman Çelebicihan)"
        ),
        .init(
            id: 72,
            text: "Oquvnı sevgen oqur, soñundan gülday qoqur.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Хто любить науку — вчиться, а згодом пахне, мов троянда.» (Кримськотатарське прислів'я)",
            translationEN: "\"Who loves learning will study and later bloom like a rose.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 73,
            text: "Baardeki areket — küzdeki bereket.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Весняна праця — осінній достаток.» (Кримськотатарське прислів'я)",
            translationEN: "\"Effort in spring brings abundance in autumn.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 74,
            text: "Şegirt olmay, usta olmazsıñ.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Не побувши учнем, не станеш майстром.» (Кримськотатарське прислів'я)",
            translationEN: "\"Without being an apprentice, you cannot become a master.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 75,
            text: "İlim barda — qaruv bar.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Де є знання — там є сила й снага.» (Кримськотатарське прислів'я)",
            translationEN: "\"Where there is knowledge, there is strength.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 76,
            text: "Öz tuvğan tilimde ayt mağa!",
            attribution: "Bekir Çoban-zade",
            translationUA: "«Скажи мені моєю рідною мовою!» (Бекір Чобан-заде)",
            translationEN: "\"Speak to me in my native tongue!\" (Bekir Çoban-zade)"
        ),
        .init(
            id: 77,
            text: "Türkiy tiller gülzarınıñ fidanı!",
            attribution: "Eşref Şemi-zade",
            translationUA: "«Пагін трояндового саду тюркських мов!» (Ешреф Шем'ї-заде)",
            translationEN: "\"The sapling of the rose garden of Turkic languages!\" (Eşref Şemi-zade)"
        ),
        .init(
            id: 78,
            text: "Terek tamırlarına tayanır, insan — tuvğanlarına.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Дерево тримається на корінні, а людина — на рідних.» (Кримськотатарське прислів'я)",
            translationEN: "\"A tree relies on its roots; a person relies on their family.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 79,
            text: "Yol köstergen Çolpan yıldızım!",
            attribution: "Yunus Qandım",
            translationUA: "«Моя ранкова зоря Чолпан, що вказує шлях!» (Юнус Кандим)",
            translationEN: "\"My morning star Venus that shows the way!\" (Yunus Qandım)"
        ),
        .init(
            id: 80,
            text: "İlim — insannıñ kemalıdır!",
            attribution: "Üsein Şamil Tohtarğazı",
            translationUA: "«Знання — це досконалість людини!» (Усеїн Шаміль Тохтаргази)",
            translationEN: "\"Knowledge is the perfection of humanity!\" (Üsein Şamil Tohtarğazı)"
        ),
        .init(
            id: 81,
            text: "Amet-Han, köklerde Sultansıñ!",
            attribution: "Riza Fazıl",
            translationUA: "«Амет-Хане, у небесах ти — Султан!» (Різа Фазил)",
            translationEN: "\"Amet-Khan, in the skies you are a Sultan!\" (Riza Fazıl)"
        ),
        .init(
            id: 82,
            text: "Acayipsiñ, Ana tili!",
            attribution: "İdris Asanin",
            translationUA: "«Дивовижна ти, рідна мово!» (Ідріс Асанін)",
            translationEN: "\"You are wonderful, Mother Tongue!\" (İdris Asanin)"
        ),
        .init(
            id: 83,
            text: "İşiñiz oñ kelsin!",
            attribution: nil,
            translationUA: "Нехай ваша справа легко вдається й іде на лад!",
            translationEN: "May your work go smoothly and succeed!"
        ),
        .init(
            id: 84,
            text: "Vatan — ekinci anañ.",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«Батьківщина — твоя друга матір.» (Кримськотатарське прислів'я)",
            translationEN: "\"The homeland is your second mother.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 85,
            text: "Birlikte — quvet!",
            attribution: "Qırımtatar atalar sözü",
            translationUA: "«У єдності — сила!» (Кримськотатарське прислів'я)",
            translationEN: "\"In unity there is strength!\" (Crimean Tatar proverb)"
        )
    ]

    private static let byID: [Int: KeyboardGreetingPhrase] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// General unrestricted daily wisdom & motivation pool (`ios_verified.md` #1–#49, excluding #23 which is daytime 08:00–17:00).
    static let dailyPool: [KeyboardGreetingPhrase] = all.filter {
        (1...49).contains($0.id) && $0.id != 23
    }

    /// Builds the eligible pool of phrases for the given date/time (`ios_verified.md` Priorities 1–4):
    /// 1. Fixed calendar date / Hijri holiday / Nth weekday (#55–#57, #59–#82, #85)
    /// 2. Weekday / Weekend (#58, #83, #84)
    /// 3. Time-of-day greetings (#50–#54, #23)
    /// 4. General unrestricted wisdom & motivation pool (`dailyPool`: #1–#22, #24–#49)
    /// Returns Priority 1 commemorative / holiday phrases matched for the given date (`ios_verified.md` Section 2, Priority 1).
    static func priority1Candidates(for date: Date = Date()) -> [KeyboardGreetingPhrase] {
        var priority1: [KeyboardGreetingPhrase] = []
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .weekday], from: date)
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let weekday = comps.weekday ?? 2 // 1 = Sun, 2 = Mon, ..., 6 = Fri, 7 = Sat

        func appendIfPresent(_ id: Int) {
            if let item = byID[id], !priority1.contains(item) {
                priority1.append(item)
            }
        }

        // Priority 1A: Hijri (Islamic Umm al-Qura) holidays (#55–#57)
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let hComps = hijri.dateComponents([.month, .day], from: date)
        if hComps.month == 9, hComps.day == 1 {
            appendIfPresent(55) // 1 Ramadan: Şehr-u Ramazan, merhaba!
        } else if hComps.month == 10, let hDay = hComps.day, (1...3).contains(hDay) {
            appendIfPresent(56) // Oraza Bayram (1–3 Shawwal)
        } else if hComps.month == 12, let hDay = hComps.day, (10...13).contains(hDay) {
            appendIfPresent(57) // Qurban Bayram (10–13 Dhu al-Hijjah)
        }

        // Priority 1B: Exact Gregorian dates (dd.MM) (#59–#65, #68–#82)
        switch (day, month) {
        case (1, 2):
            appendIfPresent(59)            // 01.02: Amet-Han Sultan memorial day (Amet-Han — tillerde destansıñ!)
            appendIfPresent(81)            // 01.02 (alt.): Amet-Han Sultan memorial day (Amet-Han, köklerde Sultansıñ!)
        case (21, 2):  appendIfPresent(60) // 21.02: International Mother Language Day (Bu til maña — tolğun Ay!)
        case (23, 2):  appendIfPresent(61) // 23.02: Noman Çelebicihan memorial day (Ant etkenmen yaranı sarmağa!)
        case (20, 3):  appendIfPresent(75) // 20.03: İsmail Gasprinskiy birthday (İlim barda — qaruv bar.)
        case (21, 3):  appendIfPresent(62) // 21.03: Navrez & World Poetry Day (Navrez keldi — yaz keldi!)
        case (10, 4):  appendIfPresent(63) // 10.04: Terciman newspaper day (Tilde, fikirde, işte — birlik!)
        case (23, 4):
            appendIfPresent(64)            // 23.04: World Book Day (Kitap — bilgi anahtarı.)
            appendIfPresent(65)            // 23.04: World Book Day riddle (Közü yoq — körsete, sözü yoq — ögrete: Kitap.)
        case (15, 5):  appendIfPresent(76) // 15.05: Bekir Çoban-zade birthday (Öz tuvğan tilimde ayt mağa!)
        case (18, 5):
            appendIfPresent(68)            // 18.05: 1944 Genocide Remembrance Day (Qırım — menim Vatanımdır!)
            appendIfPresent(69)            // 18.05: Prayer of remembrance (Allah keçmişlerimizni rahmet eylesin!)
        case (1, 6):   appendIfPresent(70) // 01.06: International Children's Day (Canımız-cigerimiz — balalar!)
        case (21, 6):  appendIfPresent(77) // 21.06: Eşref Şemi-zade birthday (Türkiy tiller gülzarınıñ fidanı!)
        case (26, 6):  appendIfPresent(71) // 26.06: Crimean Tatar Flag Day (Milletniñ şanı — bayrağında!)
        case (12, 7):  appendIfPresent(78) // 12.07: Şamil Alâdin birthday (Terek tamırlarına tayanır, insan — tuvğanlarına.)
        case (1, 9):   appendIfPresent(72) // 01.09: Knowledge Day (Oquvnı sevgen oqur, soñundan gülday qoqur.)
        case (4, 9):   appendIfPresent(79) // 04.09: Yunus Qandım birthday (Yol köstergen Çolpan yıldızım!)
        case (22, 9):  appendIfPresent(73) // 22.09: Derviza harvest festival (Baardeki areket — küzdeki bereket.)
        case (5, 10):  appendIfPresent(74) // 05.10: Teachers' Day (Şegirt olmay, usta olmazsıñ.)
        case (10, 10): appendIfPresent(80) // 10.10: Üsein Şamil Tohtarğazı birthday (İlim — insannıñ kemalıdır!)
        case (13, 11): appendIfPresent(82) // 13.11: İdris Asanin & Nuzet Ümerov tribute (Acayipsiñ, Ana tili!)
        default: break
        }
        if month == 5, weekday == 6, (1...7).contains(day) {
            appendIfPresent(66) // Hıdırlez (first Friday of May)
        }
        if month == 5, weekday == 1, (8...14).contains(day) {
            appendIfPresent(67) // Mother's Day (second Sunday of May)
        }

        return priority1
    }

    /// Returns Priority 2 weekday & start-of-season phrases matched for the given date (`ios_verified.md` Section 2, Priority 2).
    static func priority2Candidates(for date: Date = Date()) -> [KeyboardGreetingPhrase] {
        var priority2: [KeyboardGreetingPhrase] = []
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.month, .day, .weekday, .hour], from: date)
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let weekday = comps.weekday ?? 2 // 1 = Sun, 2 = Mon, ..., 6 = Fri, 7 = Sat
        let hour = comps.hour ?? 12

        func appendIfPresent(_ id: Int) {
            if let item = byID[id], !priority2.contains(item) {
                priority2.append(item)
            }
        }

        if day == 1, month == 3 {
            appendIfPresent(73) // 01.03: Beginning of spring (Baardeki areket — küzdeki bereket.)
        }
        if day == 1, month == 12 {
            appendIfPresent(85) // 01.12: First day of winter (Birlikte — quvet!)
        }

        if weekday == 6, (5..<16).contains(hour) {
            appendIfPresent(58) // Friday (Cuma, 05:00–16:00)
        } else if weekday == 2, (6..<12).contains(hour) {
            appendIfPresent(83) // Monday morning (06:00–12:00)
        } else if (weekday == 1 || weekday == 7), (9..<21).contains(hour) {
            appendIfPresent(84) // Weekend (09:00–21:00)
        }

        return priority2
    }

    /// Returns Priority 3 time-of-day phrases matched for the given date (`ios_verified.md` Section 2, Priority 3).
    static func priority3Candidates(for date: Date = Date()) -> [KeyboardGreetingPhrase] {
        var priority3: [KeyboardGreetingPhrase] = []
        let cal = Calendar(identifier: .gregorian)
        let hour = cal.component(.hour, from: date)

        func appendIfPresent(_ id: Int) {
            if let item = byID[id], !priority3.contains(item) {
                priority3.append(item)
            }
        }

        if (5..<11).contains(hour) {
            appendIfPresent(50) // 05:00–11:00
            appendIfPresent(51) // 05:00–11:00
        } else if (11..<18).contains(hour) {
            appendIfPresent(52) // 11:00–18:00
        } else if (18..<23).contains(hour) {
            appendIfPresent(53) // 18:00–23:00
        } else {
            appendIfPresent(54) // 23:00–05:00
        }
        if (8..<17).contains(hour) {
            appendIfPresent(23) // 08:00–17:00
        }

        return priority3
    }

    /// Returns Priority 4 general daily wisdom pool (`#1–#49` excluding `#23` and any IDs already present in Priorities 1–3).
    static func priority4Candidates(excluding excludedIDs: Set<Int> = []) -> [KeyboardGreetingPhrase] {
        dailyPool.filter { !excludedIDs.contains($0.id) }
    }

    static func candidates(for date: Date = Date()) -> [KeyboardGreetingPhrase] {
        let p1 = priority1Candidates(for: date)
        let p2 = priority2Candidates(for: date)
        let p3 = priority3Candidates(for: date)
        var list: [KeyboardGreetingPhrase] = []
        for item in (p1 + p2 + p3) where !list.contains(item) {
            list.append(item)
        }
        let excludedIDs = Set(list.map(\.id))
        list.append(contentsOf: priority4Candidates(excluding: excludedIDs))
        return list.isEmpty ? [all[0]] : list
    }
}

/// Coordinates showing, randomizing, and dismissing the top motivational greeting banner on the keyboard.
final class GreetingBannerState: ObservableObject {
    static let shared = GreetingBannerState()

    @Published var isDismissedForCurrentSession: Bool = false
    @Published var candidateIndex: Int = 0
    private var shuffledPool: [KeyboardGreetingPhrase] = []
    private var lastPickedID: Int?

    init() {
        reshufflePool()
    }

    private func reshufflePool(for date: Date = Date()) {
        let p1 = KeyboardGreetingPhrase.priority1Candidates(for: date).shuffled()
        var seenIDs = Set(p1.map(\.id))

        let p2 = KeyboardGreetingPhrase.priority2Candidates(for: date)
            .filter { seenIDs.insert($0.id).inserted }
            .shuffled()

        let p3 = KeyboardGreetingPhrase.priority3Candidates(for: date)
            .filter { seenIDs.insert($0.id).inserted }
            .shuffled()

        let p4 = KeyboardGreetingPhrase.priority4Candidates(excluding: seenIDs).shuffled()

        var shuffled = p1 + p2 + p3 + p4
        if let lastID = lastPickedID, shuffled.count > 1, shuffled.first?.id == lastID {
            let firstTierCount: Int
            if !p1.isEmpty {
                firstTierCount = p1.count
            } else if !p2.isEmpty {
                firstTierCount = p2.count
            } else if !p3.isEmpty {
                firstTierCount = p3.count
            } else {
                firstTierCount = p4.count
            }
            if firstTierCount > 1 {
                let first = shuffled.removeFirst()
                shuffled.insert(first, at: firstTierCount - 1)
            }
        }
        shuffledPool = shuffled
        candidateIndex = 0
        lastPickedID = shuffled.first?.id
    }

    func prepareForAppearance() {
        var transaction = Transaction(animation: nil)
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            isDismissedForCurrentSession = false
            reshufflePool()
        }
    }

    func dismissForTyping() {
        guard !isDismissedForCurrentSession else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            isDismissedForCurrentSession = true
        }
    }

    func cycleNext() {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.85)) {
            if shuffledPool.isEmpty {
                reshufflePool()
            } else {
                candidateIndex = (candidateIndex + 1) % max(shuffledPool.count, 1)
                lastPickedID = shuffledPool[candidateIndex].id
            }
        }
    }

    func currentPhrase(for date: Date = Date()) -> KeyboardGreetingPhrase {
        let pool = shuffledPool.isEmpty ? KeyboardGreetingPhrase.candidates(for: date) : shuffledPool
        let idx = abs(candidateIndex) % max(pool.count, 1)
        return pool[idx]
    }
}

/// A native-style autocomplete toolbar that renders the motivational Crimean Tatar greeting banner
/// when the text field is empty before typing begins, and smoothly transitions into 3 equal-width
/// suggestion slots separated by 2 vertical dividers as soon as typing starts.
struct NativeAutocompleteToolbar: View {

    @ObservedObject var autocompleteContext: AutocompleteContext
    @ObservedObject private var greetingState = GreetingBannerState.shared
    @ObservedObject var keyboardContext: KeyboardContext
    let autocompleteAction: (Autocomplete.Suggestion) -> Void

    private var isFloating: Bool {
        keyboardContext.isKeyboardFloating
    }

    private var isDockedPad: Bool {
        keyboardContext.deviceType == .pad && !isFloating
    }

    private var isSplitPad: Bool {
        isDockedPad && keyboardContext.isKeyboardSplit
    }

    private var height: CGFloat {
        isFloating ? 38 : (isDockedPad ? 38 : 40)
    }

    private var shouldShowGreetingBanner: Bool {
        guard DemoStyleProvider.shouldShowTopToolbar(for: keyboardContext) else { return false }
        if DemoStyleProvider.effectiveProxyKeyboardType(for: keyboardContext) == .webSearch {
            return false
        }
        guard !greetingState.isDismissedForCurrentSession else { return false }
        let suggestions = autocompleteContext.suggestions
        guard suggestions.isEmpty else { return false }
        let before = keyboardContext.textDocumentProxy.documentContextBeforeInput ?? ""
        let after = keyboardContext.textDocumentProxy.documentContextAfterInput ?? ""
        return before.isEmpty && after.isEmpty
    }

    private var isDark: Bool {
        DemoStyleProvider.effectiveIsDark(for: keyboardContext)
    }

    private var primaryColor: Color {
        isDark ? .white : .black
    }

    static func slotWidths(
        for suggestions: [Autocomplete.Suggestion],
        totalWidth: CGFloat,
        slotCount: Int = 3
    ) -> [CGFloat] {
        let usableWidth = max(totalWidth - 1.0, CGFloat(slotCount))
        let equalWidth = usableWidth / CGFloat(slotCount)
        let lengths = (0..<slotCount).map { idx -> Int in
            guard idx < suggestions.count else { return 0 }
            return suggestions[idx].title.count
        }
        let maxLen = lengths.max() ?? 0
        guard maxLen >= 10 else {
            return Array(repeating: equalWidth, count: slotCount)
        }
        let rawWeights = (0..<slotCount).map { idx -> CGFloat in
            let len = lengths[idx]
            guard len > 0 else { return 7.0 }
            let isAutocorrectBonus: CGFloat = (idx < suggestions.count && suggestions[idx].isAutocorrect) ? 2.0 : 0.0
            return min(max(CGFloat(len) + isAutocorrectBonus, 6.5), 25.0)
        }
        let rawSum = max(rawWeights.reduce(0, +), 1.0)
        var fractions = rawWeights.map { min(max($0 / rawSum, 0.22), 0.52) }
        let fracSum = max(fractions.reduce(0, +), 0.001)
        fractions = fractions.map { $0 / fracSum }
        return fractions.map { max(usableWidth * $0, 1.0) }
    }

    private func adaptiveSlotWidths(
        suggestions: [Autocomplete.Suggestion],
        availableWidth: CGFloat,
        slotCount: Int = 3
    ) -> [CGFloat] {
        Self.slotWidths(for: suggestions, totalWidth: availableWidth, slotCount: slotCount)
    }

    @ViewBuilder
    private func suggestionSlotButton(index: Int, suggestion: Autocomplete.Suggestion?, width: CGFloat) -> some View {
        Button {
            if let suggestion {
                autocompleteAction(suggestion)
            }
        } label: {
            ZStack {
                primaryColor.opacity(0.001)

                if let suggestion {
                    let isMathUnknown = suggestion.additionalInfo["mathAction"] != nil
                    let displayTitle = suggestion.isUnknown
                        ? (isMathUnknown ? "«\(suggestion.title)»" : "“\(suggestion.title)”")
                        : suggestion.title
                    let isPad = keyboardContext.deviceType == .pad && !isFloating
                    let allowTwoLines = displayTitle.count >= 18 || (displayTitle.contains("-") && displayTitle.count >= 13)
                    if suggestion.isAutocorrect {
                        Text(displayTitle)
                            .font(isFloating ? .subheadline.weight(.regular) : .system(size: 17, weight: .regular))
                            .foregroundStyle(primaryColor)
                            .lineLimit(allowTwoLines ? 2 : 1)
                            .minimumScaleFactor(0.58)
                            .allowsTightening(true)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, isFloating ? 6 : 10)
                            .frame(
                                minWidth: isPad ? 138 : min(88, max(width - 12, 48)),
                                maxWidth: isPad ? max(168, width - 20) : .infinity,
                                minHeight: isPad ? 35 : (isFloating ? 28 : 32)
                            )
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(isDark ? Color.white.opacity(0.24) : Color.white.opacity(0.92))
                                    .shadow(color: Color.black.opacity(isDark ? 0.18 : 0.06), radius: 1.5, x: 0, y: 0.5)
                            )
                            .padding(.horizontal, isFloating ? 3 : (isDockedPad ? 10 : 6))
                    } else {
                        Text(displayTitle)
                            .font(isFloating ? .subheadline : .system(size: 17, weight: .regular))
                            .foregroundStyle(primaryColor)
                            .lineLimit(allowTwoLines ? 2 : 1)
                            .minimumScaleFactor(0.58)
                            .allowsTightening(true)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, isFloating ? 4 : 8)
                            .padding(.vertical, isFloating ? 2 : 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(FullSlotButtonStyle())
        .frame(width: width, height: height)
        .contentShape(Rectangle())
        .accessibilityIdentifier("autocomplete.slot.\(index)")
    }

    var body: some View {
        let suggestions = Array(autocompleteContext.suggestions.prefix(3))
        let slotCount = 3

        GeometryReader { geo in
            let totalWidth = max(geo.size.width, 1)
            let sideInset: CGFloat = 0
            let centerWidth = max(totalWidth - (sideInset * 2), 1)
            let slotWidths = adaptiveSlotWidths(suggestions: suggestions, availableWidth: centerWidth, slotCount: slotCount)
            let isPortrait = keyboardContext.interfaceOrientation.isPortrait
            let minGapFraction: CGFloat = isPortrait ? 0.22 : 0.38
            let splitClusterWidth = min(max((totalWidth * (1.0 - minGapFraction)) / 2.0, 1), isPortrait ? 276 : 320)

            ZStack {
                if shouldShowGreetingBanner {
                    if isSplitPad {
                        HStack(spacing: 0) {
                            splitLeftGreetingBannerView(clusterWidth: splitClusterWidth)
                                .frame(width: splitClusterWidth, height: height)
                            Spacer(minLength: 0)
                            splitRightGreetingControlsView(clusterWidth: splitClusterWidth)
                                .frame(width: splitClusterWidth, height: height)
                        }
                        .frame(width: totalWidth, height: height)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        greetingBannerView(centerWidth: centerWidth)
                            .frame(width: totalWidth, height: height)
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                } else {
                    if isSplitPad {
                        let leftSlotWidth = max((splitClusterWidth - 0.5) / 2.0, 1)
                        let s0 = suggestions.indices.contains(0) ? suggestions[0] : nil
                        let s1 = suggestions.indices.contains(1) ? suggestions[1] : nil
                        let hideLeftDivider = (s0?.isAutocorrect == true) || (s1?.isAutocorrect == true)
                        HStack(spacing: 0) {
                            HStack(spacing: 0) {
                                suggestionSlotButton(
                                    index: 0,
                                    suggestion: s0,
                                    width: leftSlotWidth
                                )
                                primaryColor.opacity(hideLeftDivider ? 0.0 : 0.22)
                                    .frame(width: 0.5, height: 22)
                                suggestionSlotButton(
                                    index: 1,
                                    suggestion: s1,
                                    width: leftSlotWidth
                                )
                            }
                            .frame(width: splitClusterWidth, height: height)

                            Spacer(minLength: 0)

                            suggestionSlotButton(
                                index: 2,
                                suggestion: suggestions.indices.contains(2) ? suggestions[2] : nil,
                                width: splitClusterWidth
                            )
                        }
                        .frame(width: totalWidth, height: height)
                        .transition(.opacity)
                    } else {
                        HStack(spacing: 0) {
                            ForEach(0..<slotCount, id: \.self) { index in
                                let suggestion: Autocomplete.Suggestion? = index < suggestions.count ? suggestions[index] : nil
                                let nextSuggestion: Autocomplete.Suggestion? = (index + 1) < suggestions.count ? suggestions[index + 1] : nil
                                let hideDivider = (suggestion?.isAutocorrect == true) || (nextSuggestion?.isAutocorrect == true)

                                suggestionSlotButton(
                                    index: index,
                                    suggestion: suggestion,
                                    width: slotWidths[index]
                                )

                                if index < slotCount - 1 {
                                    primaryColor.opacity(hideDivider ? 0.0 : 0.22)
                                        .frame(width: 0.5, height: isFloating ? 16 : 24)
                                }
                            }
                        }
                        .frame(width: totalWidth, height: height)
                        .transition(.opacity)
                    }
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shouldShowGreetingBanner)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .environment(\.colorScheme, isDark ? .dark : .light)
    }

    private struct FullSlotButtonStyle: ButtonStyle {
        func makeBody(configuration: Configuration) -> some View {
            configuration.label
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.primary.opacity(0.001))
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.65 : 1.0)
        }
    }

    private func insertCurrentPhrase(_ phrase: KeyboardGreetingPhrase) {
        let inserted = phrase.formattedInsertText(for: KeyboardPreferences.interfaceLanguage)
        KeyboardUsageStats.markInjectedText(inserted)
        KeyboardUsageStats.recordPhraseInserted()
        TextHistoryManager.shared.recordInsert(inserted)
        keyboardContext.textDocumentProxy.insertText(inserted)
        SpaceBarState.shared.fadeToResting()
        greetingState.dismissForTyping()
    }

    @ViewBuilder
    private func splitLeftGreetingBannerView(clusterWidth: CGFloat) -> some View {
        let phrase = greetingState.currentPhrase()
        Button {
            insertCurrentPhrase(phrase)
        } label: {
            HStack(spacing: 5) {
                BreathingTamgaView(isDark: isDark, minOpacity: 0.45, maxOpacity: 0.85)
                    .frame(width: 12.5, height: 7.0)

                Text(phrase.bannerCRH)
                    .font(.system(size: 12.0, weight: .medium))
                    .foregroundStyle(primaryColor.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.55)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 3.5)
            .frame(maxWidth: max(clusterWidth - 12, 120))
            .background(
                Capsule(style: .continuous)
                    .fill(primaryColor.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("autocomplete.greetingBanner")
    }

    @ViewBuilder
    private func splitRightGreetingControlsView(clusterWidth: CGFloat) -> some View {
        let phrase = greetingState.currentPhrase()
        HStack(spacing: 6) {
            if let attributionText = phrase.attribution, !attributionText.isEmpty {
                Button {
                    insertCurrentPhrase(phrase)
                } label: {
                    HStack(spacing: 5) {
                        Text(attributionText)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(primaryColor.opacity(0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.65)

                        Image(systemName: "arrow.up.left.circle.fill")
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(primaryColor.opacity(0.55))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        Capsule(style: .continuous)
                            .fill(primaryColor.opacity(0.06))
                    )
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    insertCurrentPhrase(phrase)
                } label: {
                    Image(systemName: "arrow.up.left.circle.fill")
                        .font(.system(size: 13.0, weight: .medium))
                        .foregroundStyle(primaryColor.opacity(0.58))
                        .frame(width: 26, height: 26)
                        .background(Circle().fill(primaryColor.opacity(0.06)))
                }
                .buttonStyle(.plain)
            }

            Button {
                greetingState.cycleNext()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryColor.opacity(0.62))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(primaryColor.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("autocomplete.greetingNext")
        }
        .padding(.horizontal, 6)
        .frame(maxWidth: max(clusterWidth - 10, 120))
    }

    @ViewBuilder
    private func greetingBannerView(centerWidth: CGFloat) -> some View {
        let phrase = greetingState.currentPhrase()
        let rightReserved: CGFloat = isDockedPad ? 96 : 10
        let maxPillWidth = min(max(centerWidth - rightReserved, 160), isDockedPad ? 660 : 520)

        HStack(spacing: 5) {
            Button {
                insertCurrentPhrase(phrase)
            } label: {
                HStack(spacing: 6) {
                    BreathingTamgaView(isDark: isDark, minOpacity: 0.45, maxOpacity: 0.85)
                        .frame(width: 13.5, height: 7.5)

                    Text(phrase.bannerCRH)
                        .font(.system(size: isFloating ? 12.5 : 14.0, weight: .medium))
                        .foregroundStyle(primaryColor.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.68)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Image(systemName: "arrow.up.left.circle.fill")
                        .font(.system(size: 12.0, weight: .medium))
                        .foregroundStyle(primaryColor.opacity(0.58))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, isDockedPad ? 4.0 : 4.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(primaryColor.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("autocomplete.greetingBanner")

            Button {
                greetingState.cycleNext()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(primaryColor.opacity(0.62))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(primaryColor.opacity(0.06)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("autocomplete.greetingNext")
        }
        .frame(maxWidth: maxPillWidth)
    }
}

extension Autocomplete.ToolbarStyle {

    static var nativeClean: Autocomplete.ToolbarStyle {
        .init(
            height: 42,
            item: .init(
                titleFont: .system(size: 16),
                titleColor: .primary,
                subtitleFont: .footnote,
                subtitleColor: .secondary
            ),
            separator: .init(
                color: Color.secondary.opacity(0.25),
                width: 0.5,
                height: 22
            )
        )
    }
}
