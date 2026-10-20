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
/// Follows the unified Display = On Tap principle (`ios (3).md`) and is 100% verified against `CrimeanTatarTransliterator`.
struct KeyboardGreetingPhrase: Identifiable, Equatable {
    let id: Int
    let text: String
    let bannerCyrl: String
    let attribution: String?
    let attributionCyrl: String?
    let sourceOriginal: String
    let translationUA: String
    let translationEN: String

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

    var insertTextCyrl: String {
        if let attributionCyrl, !attributionCyrl.isEmpty {
            let normalized = bannerCyrl
                .replacingOccurrences(of: "«", with: "\"")
                .replacingOccurrences(of: "»", with: "\"")
            return "«\(normalized)» (\(attributionCyrl))"
        } else {
            return bannerCyrl
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
        // I. НАРОДНІ ПРИСЛІВ'Я (QIRIMTATAR ATALAR SÖZLERİ)
        .init(
            id: 1,
            text: "Til — aqıl terazesidir.",
            bannerCyrl: "Тиль — акъыл теразесидир.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Тиль — акъыл теразесидир. (Ат.с.)",
            translationUA: "«Мова — це терези розуму.» (Кримськотатарське прислів'я)",
            translationEN: "\"Language is the scales of the mind.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 2,
            text: "İlim — aqıl çoqrağıdır.",
            bannerCyrl: "Илим — акъыл чокърагъыдыр.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Илим — акъыл чокърагъыдыр. (Ат.с.)",
            translationUA: "«Наука (знання) — це джерело розуму.» (Кримськотатарське прислів'я)",
            translationEN: "\"Knowledge is the spring of the mind.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 3,
            text: "Çoq diñle, az söyle.",
            bannerCyrl: "Чокъ динъле, аз сёйле.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Чокъ динъле, аз сёйле.",
            translationUA: "«Багато слухай, мало говори.» (Кримськотатарське прислів'я)",
            translationEN: "\"Listen much, speak little.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 4,
            text: "Güzellik közde degil, sözdedir.",
            bannerCyrl: "Гузеллик козьде дегиль, сёздедир.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Güzellik közde degil, sözdedir.",
            translationUA: "«Краса не в очах, а в слові.» (Кримськотатарське прислів'я)",
            translationEN: "\"Beauty is not in the eye, but in the word.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 5,
            text: "Tilini unutqan, ilini unutır.",
            bannerCyrl: "Тилини унуткъан, илини унутыр.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Тилини унуткъан, илини унутыр.",
            translationUA: "«Хто забув свою мову, забуде і свій край.» (Кримськотатарське прислів'я)",
            translationEN: "\"Whoever forgets their language forgets their homeland.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 6,
            text: "Yahşı niyet — yarı mal.",
            bannerCyrl: "Яхшы ниет — яры мал.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Яхшы ниет — яры мал.",
            translationUA: "«Добрий намір — половина справи (надбання).» (Кримськотатарське прислів'я)",
            translationEN: "\"A good intention is half the wealth.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 7,
            text: "Eyilik yap da, deryağa taşla.",
            bannerCyrl: "Эйилик яп да, дерьягъа ташла.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Eyilik yap da, deryağa taşla.",
            translationUA: "«Роби добро і кидай його в море.» (Кримськотатарське прислів'я)",
            translationEN: "\"Do good and cast it into the sea.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 8,
            text: "Başlağan işiñni taşlama.",
            bannerCyrl: "Башлагъан ишинъни ташлама.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Başlağan işiñni taşlama.",
            translationUA: "«Не полишай розпочату справу.» (Кримськотатарське прислів'я)",
            translationEN: "\"Do not abandon the work you have begun.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 9,
            text: "Ürmet etseñ — ürmet körersiñ.",
            bannerCyrl: "Урьмет этсенъ — урьмет корерсинъ.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Урьмет этсенъ — урьмет корерсинъ.",
            translationUA: "«Шануватимеш — сам зазнаєш пошани.» (Кримськотатарське прислів'я)",
            translationEN: "\"If you show respect, you will receive respect.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 10,
            text: "Em tatlı, em accı — tildir.",
            bannerCyrl: "Эм татлы, эм аджджы — тильдир.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Эм татлы, эм аджджы — тильдир. (Ат.с.)",
            translationUA: "«І солодке, і гірке — це язик (мова).» (Кримськотатарське прислів'я)",
            translationEN: "\"Both the sweetest and the bitterest thing is the tongue.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 11,
            text: "Birlik ev — bereketli ev.",
            bannerCyrl: "Бирлик эв — берекетли эв.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Бирлик эв — берекетли эв.",
            translationUA: "«Дім у злагоді — благословенний (достатній) дім.» (Кримськотатарське прислів'я)",
            translationEN: "\"A united home is a blessed and prosperous home.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 12,
            text: "Yarınki işke bugünden davran.",
            bannerCyrl: "Ярынки ишке бугуньден давран.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Ярынки ишке бугуньден давран.",
            translationUA: "«Про завтрашню справу подбай уже сьогодні.» (Кримськотатарське прислів'я)",
            translationEN: "\"Prepare for tomorrow's work today.\" (Crimean Tatar proverb)"
        ),

        // II. ЛІТЕРАТУРНІ ЦИТАТИ ТА ПОЕТИЧНІ РЯДКИ ПРО МОВУ (З КОРПУСУ)
        .init(
            id: 13,
            text: "Tilimiz pek zengin eken!",
            bannerCyrl: "Тилимиз пек зенгин экен!",
            attribution: "Eşref Şemi-zade",
            attributionCyrl: "Эшреф Шемьи-заде",
            sourceOriginal: "«Тилимиз пек зенгин экен!»",
            translationUA: "«Яка ж багата наша мова!» (Ешреф Шем'ї-заде)",
            translationEN: "\"How rich our language truly is!\" (Eşref Şemi-zade)"
        ),
        .init(
            id: 14,
            text: "Sev tiliñni, sevgen kibi anañnı!",
            bannerCyrl: "Сев тилинъни, севген киби ананъны!",
            attribution: "Eşref Şemi-zade",
            attributionCyrl: "Эшреф Шемьи-заде",
            sourceOriginal: "Сев тилинъни, севген киби ананъны.",
            translationUA: "«Люби свою мову, як любиш свою матір!» (Ешреф Шем'ї-заде)",
            translationEN: "\"Love your language as you love your mother!\" (Eşref Şemi-zade)"
        ),
        .init(
            id: 15,
            text: "Ana tilimiz — baylığımızdır.",
            bannerCyrl: "Ана тилимиз — байлыгъымыздыр.",
            attribution: "Qırımtatar edebiyatı dersliginden",
            attributionCyrl: "Къырымтатар эдебияты дерслигинден",
            sourceOriginal: "Ана тилимиз байлыгъымыздыр.",
            translationUA: "«Наша рідна мова — це наше багатство.» (З підручника кримськотатарської літератури)",
            translationEN: "\"Our native language is our wealth.\" (From the Crimean Tatar literature textbook)"
        ),
        .init(
            id: 16,
            text: "Seviñiz ana tilimizni!",
            bannerCyrl: "Севинъиз ана тилимизни!",
            attribution: "Qırımtatar edebiyatı dersliginden",
            attributionCyrl: "Къырымтатар эдебияты дерслигинден",
            sourceOriginal: "Севинъиз ана тилимизни!",
            translationUA: "«Любіть нашу рідну мову!» (З підручника кримськотатарської літератури)",
            translationEN: "\"Love our native language!\" (From the Crimean Tatar literature textbook)"
        ),
        .init(
            id: 17,
            text: "Ana tili beşigimniñ yırı oldı.",
            bannerCyrl: "Ана тили бешигимнинъ йыры олды.",
            attribution: "Löman Suleyman",
            attributionCyrl: "Лёман Сулейман",
            sourceOriginal: "Ана тили бешигимнинъ йыры олды.",
            translationUA: "«Рідна мова стала піснею моєї колиски.» (Льоман Сулейман)",
            translationEN: "\"My mother tongue became the song of my cradle.\" (Löman Suleyman)"
        ),
        .init(
            id: 18,
            text: "Ğururımsıñ, ana tilim!",
            bannerCyrl: "Гъурурымсынъ, ана тилим!",
            attribution: "Qırımtatar şiiriyetinden",
            attributionCyrl: "Къырымтатар шиириетинден",
            sourceOriginal: "Гъурурымсынъ ана тилим",
            translationUA: "«Ти — моя гордість, рідна мово!» (З кримськотатарської поезії)",
            translationEN: "\"You are my pride, my native tongue!\" (From Crimean Tatar poetry)"
        ),
        .init(
            id: 19,
            text: "Biz bu tilde laf eteyik!",
            bannerCyrl: "Биз бу тильде лаф этейик!",
            attribution: "Qırımtatar şiiriyetinden",
            attributionCyrl: "Къырымтатар шиириетинден",
            sourceOriginal: "Биз бу тильде лаф этейик",
            translationUA: "«Розмовляймо цією мовою!» (З кримськотатарської поезії)",
            translationEN: "\"Let us speak in this language!\" (From Crimean Tatar poetry)"
        ),
        .init(
            id: 20,
            text: "Taparsıñ tek ana tilde birdemlik.",
            bannerCyrl: "Тапарсынъ тек ана тильде бирдемлик.",
            attribution: "Refat Çaylaq",
            attributionCyrl: "Рефат Чайлакъ",
            sourceOriginal: "Taparsıñ tek ana tilde birdemlik",
            translationUA: "«Лише у рідній мові ти знайдеш єдність.» (Рефат Чайлак)",
            translationEN: "\"Only in the mother tongue will you find unity.\" (Refat Çaylaq)"
        ),
        .init(
            id: 21,
            text: "Ne yapsañ yap, öz tiliñni unutma!",
            bannerCyrl: "Не япсанъ яп, озь тилинъни унутма!",
            attribution: "Refat Çaylaq",
            attributionCyrl: "Рефат Чайлакъ",
            sourceOriginal: "Ne yapsañ yap, öz tiliñni unutma!",
            translationUA: "«Що б ти не робив, не забувай своєї мови!» (Рефат Чайлак)",
            translationEN: "\"Whatever you do, do not forget your own language!\" (Refat Çaylaq)"
        ),
        .init(
            id: 22,
            text: "Ana tilge meyil beriñ!",
            bannerCyrl: "Ана тильге мейиль беринъ!",
            attribution: "Qırımtatar şiiriyetinden",
            attributionCyrl: "Къырымтатар шиириетинден",
            sourceOriginal: "Ана тильге мейиль беринъ",
            translationUA: "«Прихиліть серце до рідної мови!» (З кримськотатарської поезії)",
            translationEN: "\"Devote your heart to your mother tongue!\" (From Crimean Tatar poetry)"
        ),
        .init(
            id: 23,
            text: "Balamıznen Ana tilde söyleşeyik!",
            bannerCyrl: "Баламызнен Ана тильде сёйлешейик!",
            attribution: "Qırımtatar şiiriyetinden",
            attributionCyrl: "Къырымтатар шиириетинден",
            sourceOriginal: "Баламызнен Ана тильде сёйлешейик",
            translationUA: "«Розмовляймо з нашими дітьми рідною мовою!» (З кримськотатарської поезії)",
            translationEN: "\"Let us speak with our children in our mother tongue!\" (From Crimean Tatar poetry)"
        ),
        .init(
            id: 24,
            text: "Evimizde tek ana tilde laf etemiz.",
            bannerCyrl: "Эвимизде тек ана тильде лаф этемиз.",
            attribution: "Qırımtatar dersliginden",
            attributionCyrl: "Къырымтатар дерслигинден",
            sourceOriginal: "Эвимизде тек ана тильде лаф этемиз.",
            translationUA: "«У нашому домі ми розмовляємо лише рідною мовою.» (З підручника)",
            translationEN: "\"In our home, we speak only in our native language.\" (From the textbook)"
        ),

        // III. АВТЕНТИЧНА ПОДЯКА, БЛАГОСЛОВЕННЯ (ALĞIŞLAR) ТА ІДІОМИ (З КОРПУСУ)
        .init(
            id: 25,
            text: "Tañrım dert körsetmesin qoluña!",
            bannerCyrl: "Танърым дерт корьсетмесин къолунъа!",
            attribution: "Halq alğışı",
            attributionCyrl: "Халкъ алгъышы",
            sourceOriginal: "Танърым дерт корьсетмесин къолуна",
            translationUA: "«Нехай Господь не дасть болю твоїм рукам!» (Народне благословення)",
            translationEN: "\"May the Lord never let your hands know pain!\" (Folk blessing)"
        ),
        .init(
            id: 26,
            text: "Tiliñe melem olayım!",
            bannerCyrl: "Тилинъе мельэм олайым!",
            attribution: "Qırımtatar aytımı",
            attributionCyrl: "Къырымтатар айтымы",
            sourceOriginal: "тилинъе мельэм олайым",
            translationUA: "«Нехай я буду бальзамом для твоїх уст!» (Кримськотатарська приказка — комплімент красномовній людині)",
            translationEN: "\"May I be a balm to your tongue!\" (Crimean Tatar idiom praising sweet speech)"
        ),
        .init(
            id: 27,
            text: "Bal tamlay dudağıñdan!",
            bannerCyrl: "Бал тамлай дудагъынъдан!",
            attribution: "Ervin Bekirov",
            attributionCyrl: "Эрвин Бекиров",
            sourceOriginal: "Бал тамлай дудагъынъдан",
            translationUA: "«Мед крапає з твоїх уст!» (Ервін Бекіров)",
            translationEN: "\"Honey drips from your lips!\" (Ervin Bekirov)"
        ),
        .init(
            id: 28,
            text: "Tili de baldan tatlı!",
            bannerCyrl: "Тили де балдан татлы!",
            attribution: "Qırımtatar şiiriyetinden",
            attributionCyrl: "Къырымтатар шиириетинден",
            sourceOriginal: "Adam bar ki, pek nazik, Tili de baldan tatlı.",
            translationUA: "«І мова його солодша за мед!» (З кримськотатарської поезії)",
            translationEN: "\"And their speech is sweeter than honey!\" (From Crimean Tatar poetry)"
        ),
        .init(
            id: 29,
            text: "Çoq sağ oluñız! Alla razı olsun!",
            bannerCyrl: "Чокъ сагъ олунъыз! Алла разы олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Сагъ олунъыз! (Алла разы олсун) / Чокъ сагъ олунъыз!",
            translationUA: "«Дуже дякую вам! Нехай Всевишній буде задоволений вами!» (Мовленнєвий етикет)",
            translationEN: "\"Thank you very much! May God be pleased with you!\" (Speech etiquette)"
        ),
        .init(
            id: 30,
            text: "Siz pek yahşı laf etesiñiz!",
            bannerCyrl: "Сиз пек яхшы лаф этесинъиз!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Сиз пек яхшы лаф этесинъиз.",
            translationUA: "«Ви дуже добре розмовляєте!» (З кримськотатарського розмовника)",
            translationEN: "\"You speak very well!\" (From the Crimean Tatar phrasebook)"
        ),
        .init(
            id: 31,
            text: "Ardı gür olsun! Eşq olsun!",
            bannerCyrl: "Арды гюр олсун! Эшкъ олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Ardı gür olsun!; eşq olsun!",
            translationUA: "«Вітаю з успіхом (нехай матиме гарне продовження)! Молодець (браво)!»",
            translationEN: "\"Congratulations on your success! Bravo (well done)!\""
        ),

        // IV. ЧАС ДОБИ ТА РОЗМОВНІ ЗВОРОТИ (З ПІДРУЧНИКІВ І СЛОВНИКІВ КОРПУСУ)
        .init(
            id: 32,
            text: "Saba şerifiñiz hayır olsun!",
            bannerCyrl: "Саба шерифинъиз хайыр олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "saba şerif(ler)iñ(iz) hayır(lı) olsun!",
            translationUA: "«Нехай ваш благословенний ранок буде добрим!»",
            translationEN: "\"May your blessed morning be good!\""
        ),
        .init(
            id: 33,
            text: "Kün şerifiñiz hayır olsun!",
            bannerCyrl: "Кунь шерифинъиз хайыр олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "kün şerif(ler)iñ(iz) hayır(lı) olsun!",
            translationUA: "«Доброго й благословенного вам дня!»",
            translationEN: "\"Have a good and blessed day!\""
        ),
        .init(
            id: 34,
            text: "Aqşam şerifiñiz hayır olsun!",
            bannerCyrl: "Акъшам шерифинъиз хайыр олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Акъшам шерифинъиз хайыр олсун!",
            translationUA: "«Нехай ваш благословенний вечір буде добрим!»",
            translationEN: "\"May your blessed evening be good!\""
        ),
        .init(
            id: 35,
            text: "Geceñiz hayır! Hayırğa qarşı!",
            bannerCyrl: "Гедженъиз хайыр! Хайыргъа къаршы!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Geceñiz hayır! / Hayırğa qarşı!",
            translationUA: "«На добраніч! Назустріч добру!»",
            translationEN: "\"Good night! Towards the good!\""
        ),
        .init(
            id: 36,
            text: "Selâm! Nasılsıñ? Ne bar, ne yoq?",
            bannerCyrl: "Селям! Насылсынъ? Не бар, не ёкъ?",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Selâm!, Nasılsıñ?, Ne bar ne yoq?",
            translationUA: "«Привіт! Як ти? Що нового?»",
            translationEN: "\"Hello! How are you? What's new?\""
        ),
        .init(
            id: 37,
            text: "Körüşkenimiz ne de yahşı oldı!",
            bannerCyrl: "Корюшкенимиз не де яхшы олды!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Körüşkenimiz ne de yahşı oldı!",
            translationUA: "«Як же добре, що ми зустрілися (побачилися)!»",
            translationEN: "\"How wonderful it is that we met!\""
        ),
        .init(
            id: 38,
            text: "Siz qırımtatarca yazasıñızmı?",
            bannerCyrl: "Сиз къырымтатарджа язасынъызмы?",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Siz qırımtatarca yazasıñızmı?",
            translationUA: "«Ви пишете кримськотатарською?»",
            translationEN: "\"Do you write in Crimean Tatar?\""
        ),
        .init(
            id: 39,
            text: "Men qırımtatar tilini ögrenem.",
            bannerCyrl: "Мен къырымтатар тилини огренем.",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Men qırımtatar tilini ögrenem.",
            translationUA: "«Я вивчаю кримськотатарську мову.»",
            translationEN: "\"I am learning the Crimean Tatar language.\""
        ),
        .init(
            id: 40,
            text: "Sırıñnı, yırıñnı şu tilde aytıñız.",
            bannerCyrl: "Сырынъны, йырынъны шу тильде айтынъыз.",
            attribution: "Güner Aqmolla",
            attributionCyrl: "Гунер Акъмолла",
            sourceOriginal: "Sırıñnı, yırıñnı şu tilde aytınız.",
            translationUA: "«Розповідайте свої таємниці й пісні цією мовою.» (Гунер Акмолла)",
            translationEN: "\"Share your secrets and your songs in this language.\" (Güner Aqmolla)"
        ),

        // A. ДУХОВНІ ТА РЕЛІГІЙНІ СВЯТА (БЕЗПЕРЕЧНІ)
        .init(
            id: 41,
            text: "Ramazan ayıñız mubarek olsun!",
            bannerCyrl: "Рамазан айынъыз мубарек олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "... mubarek olsun! (Cilt II, с. 28)",
            translationUA: "«Нехай ваш місяць Рамазан буде благословенним!»",
            translationEN: "\"May your month of Ramadan be blessed!\""
        ),
        .init(
            id: 42,
            text: "Oraza bayramıñız mubarek olsun!",
            bannerCyrl: "Ораза байрамынъыз мубарек олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Oraza/Qurban bayramıñız mubarek olsun! (Cilt II, с. 28)",
            translationUA: "«Нехай ваше свято Ораза-байрам буде благословенним!»",
            translationEN: "\"May your holiday of Oraza Bayram (Eid al-Fitr) be blessed!\""
        ),
        .init(
            id: 43,
            text: "Qurban bayramıñız mubarek olsun!",
            bannerCyrl: "Къурбан байрамынъыз мубарек олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Oraza/Qurban bayramıñız mubarek olsun! (Cilt II, с. 28)",
            translationUA: "«Нехай ваше свято Курбан-байрам буде благословенним!»",
            translationEN: "\"May your holiday of Qurban Bayram (Eid al-Adha) be blessed!\""
        ),
        .init(
            id: 44,
            text: "Cuma şerifiñiz mubarek olsun!",
            bannerCyrl: "Джума шерифинъиз мубарек олсун!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Cuma şerifiñiz mubarek olsun! (Корпус, с. 14; Cilt II, с. 28)",
            translationUA: "«Нехай ваша благословенна п'ятниця буде світлою!»",
            translationEN: "\"May your holy Friday (Jumu'ah) be blessed!\""
        ),

        // B. ДНІ РІДНОЇ МОВИ, ОСВІТИ, РОДИНИ ТА ПАМ'ЯТІ ПРЕДКІВ
        .init(
            id: 45,
            text: "Bu til maña — tolğun Ay!",
            bannerCyrl: "Бу тиль манъа — толгъун Ай!",
            attribution: "Remzi Burnaş",
            attributionCyrl: "Ремзи Бурнаш",
            sourceOriginal: "Бу тиль манъа — толгъун Ай.",
            translationUA: "«Ця мова для мене — повний Місяць!» (Ремзі Бурнаш)",
            translationEN: "\"This language is a full Moon to me!\" (Remzi Burnaş)"
        ),
        .init(
            id: 46,
            text: "Yürekten doğa şiirler.",
            bannerCyrl: "Юректен догъа шиирлер.",
            attribution: "Qırımtatar şiiriyetinden",
            attributionCyrl: "Къырымтатар шиириетинден",
            sourceOriginal: "Юрегимден догъа шиирлер",
            translationUA: "«Із серця народжуються вірші.» (З кримськотатарської поезії)",
            translationEN: "\"Poems are born from the heart.\" (From Crimean Tatar poetry)"
        ),
        .init(
            id: 47,
            text: "Dilde, fikirde, işte — birlik!",
            bannerCyrl: "Дильде, фикирде, иште — бирлик!",
            attribution: "İsmail Gasprinskiy",
            attributionCyrl: "Исмаиль Гаспринский",
            sourceOriginal: "лисан, фикир ве иш бирлиги",
            translationUA: "«У мові, думці, ділі — єдність!» (Ісмаїл Гаспринський)",
            translationEN: "\"Unity in language, thought, and action!\" (İsmail Gasprinskiy)"
        ),
        .init(
            id: 48,
            text: "Kitap — bilgi anahtarı.",
            bannerCyrl: "Китап — бильги анахтары.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Китап — бильги анахтары",
            translationUA: "«Книга — ключ до знань.» (Кримськотатарське прислів'я)",
            translationEN: "\"A book is the key to knowledge.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 49,
            text: "Analar qadrine yeteyik!",
            bannerCyrl: "Аналар къадрине етейик!",
            attribution: "Qırımtatar edebiyatından",
            attributionCyrl: "Къырымтатар эдебиятындан",
            sourceOriginal: "Инсанлар, сагълыкъта етейик аналар къадрине!",
            translationUA: "«Цінуймо наших матерів!» (З кримськотатарської літератури)",
            translationEN: "\"Let us cherish and appreciate our mothers!\" (From Crimean Tatar literature)"
        ),
        .init(
            id: 50,
            text: "Meni duadan unutmañız.",
            bannerCyrl: "Мени дуадан унутманъыз.",
            attribution: "Ümer İpçi",
            attributionCyrl: "Умер Ипчи",
            sourceOriginal: "Мени дуадан унутманъыз.",
            translationUA: "«Не забувайте мене у молитві.» (Умер Іпчі)",
            translationEN: "\"Do not forget me in your prayers.\" (Ümer İpçi)"
        ),
        .init(
            id: 51,
            text: "Balalar — közümizniñ nurudır!",
            bannerCyrl: "Балалар — козюмизнинъ нурудыр!",
            attribution: "Çerkez-Ali",
            attributionCyrl: "Черкез-Али",
            sourceOriginal: "Köz nurlarım",
            translationUA: "«Діти — світло наших очей!» (Черкез-Алі)",
            translationEN: "\"Children are the light of our eyes!\" (Çerkez-Ali)"
        ),
        .init(
            id: 52,
            text: "Meraba, sentâbr, meraba, mektep!",
            bannerCyrl: "Мераба, сентябр, мераба, мектеп!",
            attribution: "Remzi Burnaş",
            attributionCyrl: "Ремзи Бурнаш",
            sourceOriginal: "Meraba sentâbr, meraba mektep",
            translationUA: "«Здрастуй, вересню, здрастуй, школо!» (Ремзі Бурнаш)",
            translationEN: "\"Hello September, hello school!\" (Remzi Burnaş)"
        ),
        .init(
            id: 53,
            text: "Edebiyat — bilgi ve edep çoqrağı.",
            bannerCyrl: "Эдебият — бильги ве эдеп чокърагъы.",
            attribution: "Qırımtatar dersliginden",
            attributionCyrl: "Къырымтатар дерслигинден",
            sourceOriginal: "Эдебият — бильги ве эдеп чокърагъы",
            translationUA: "«Література — джерело знань і вихованості.» (З підручника)",
            translationEN: "\"Literature is the spring of knowledge and good manners.\" (From the textbook)"
        ),

        // C. ДНІ НАРОДЖЕННЯ ЗАГАЛЬНОВИЗНАНИХ КЛАСИКІВ КУЛЬТУРИ ТА ІСТОРІЇ
        .init(
            id: 54,
            text: "İlim barda — qaruv bar!",
            bannerCyrl: "Илим барда — къарув бар!",
            attribution: "Remzi Burnaş",
            attributionCyrl: "Ремзи Бурнаш",
            sourceOriginal: "İlim barda - qaruv bar",
            translationUA: "«Де є знання — там є сила (снага)!» (Ремзі Бурнаш)",
            translationEN: "\"Where there is knowledge, there is strength!\" (Remzi Burnaş)"
        ),
        .init(
            id: 55,
            text: "Öz tuvğan tilimde ayt, maña!",
            bannerCyrl: "Озь тувгъан тилимде айт, манъа!",
            attribution: "Bekir Çoban-zade",
            attributionCyrl: "Бекир Чобан-заде",
            sourceOriginal: "«Озь тувгъан тилимде айт, манъа» дермен",
            translationUA: "«Скажи мені моєю рідною мовою!» (Бекір Чобан-заде)",
            translationEN: "\"Speak to me in my native tongue!\" (Bekir Çoban-zade)"
        ),
        .init(
            id: 56,
            text: "«Ana» dedim men bu tilde birinci.",
            bannerCyrl: "«Ана» дедим мен бу тильде биринджи.",
            attribution: "Eşref Şemi-zade",
            attributionCyrl: "Эшреф Шемьи-заде",
            sourceOriginal: "«Ана» дедим мен бу тильде биринджи",
            translationUA: "«\"Мамо\" сказав я цією мовою вперше.» (Ешреф Шем'ї-заде)",
            translationEN: "\"'Mother' I said in this language first.\" (Eşref Şemi-zade)"
        ),
        .init(
            id: 57,
            text: "Terek tamırlarına tayanır.",
            bannerCyrl: "Терек тамырларына таяныр.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Terek tamırlarına tayanır, insan – tuvğanlarına.",
            translationUA: "«Дерево тримається на корінні.» (Кримськотатарське прислів'я)",
            translationEN: "\"A tree relies on its roots.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 58,
            text: "Meleklerge lâyıq tilim, Ana tilim.",
            bannerCyrl: "Мелеклерге ляйыкъ тилим, Ана тилим.",
            attribution: "Yunus Qandım",
            attributionCyrl: "Юнус Къандым",
            sourceOriginal: "Meleklerge lâyıq tilim, Ana tilim.",
            translationUA: "«Гідна янголів мово моя, рідна мово.» (Юнус Кандим)",
            translationEN: "\"My language worthy of angels, my mother tongue.\" (Yunus Qandım)"
        ),
        .init(
            id: 59,
            text: "İlim — insannıñ kemalıdır!",
            bannerCyrl: "Илим — инсаннынъ кемалыдыр!",
            attribution: "Üsein Şamil Tohtarğazı",
            attributionCyrl: "Усеин Шамиль Тохтаргъазы",
            sourceOriginal: "О — илимдир ки, инсаннынъ кемалыдыр!",
            translationUA: "«Наука (знання) — це досконалість людини!» (Усеїн Шаміль Тохтаргъази)",
            translationEN: "\"Knowledge is the perfection of humanity!\" (Üsein Şamil Tohtarğazı)"
        ),
        .init(
            id: 60,
            text: "Amet-Han, köklerde Sultansıñ!",
            bannerCyrl: "Амет-Хан, коклерде Султансынъ!",
            attribution: "Riza Fazıl",
            attributionCyrl: "Риза Фазыл",
            sourceOriginal: "Аметхан, коклерде Султансынъ",
            translationUA: "«Амет-Хане, у небесах ти — Султан!» (Різа Фазил)",
            translationEN: "\"Amet-Khan, in the skies you are a Sultan!\" (Riza Fazıl)"
        ),
        .init(
            id: 61,
            text: "Doğru yazmağa da ögrenirsiñiz!",
            bannerCyrl: "Догъру язмагъа да огренирсинъиз!",
            attribution: "Qırımtatar dersliginden",
            attributionCyrl: "Къырымтатар дерслигинден",
            sourceOriginal: "doğru yazmağa da ögrenirsiniz.",
            translationUA: "«Ви навчитеся і правильно писати!» (З підручника кримськотатарської мови)",
            translationEN: "\"You will also learn to write correctly!\" (From the Crimean Tatar textbook)"
        ),

        // D. ЩОТИЖНЕВІ ТА СЕЗОННІ ТРИГЕРИ (ПОБУТ І РОДИНА, ЗІ СЛОВНИКІВ КОРПУСУ)
        .init(
            id: 62,
            text: "Alla işiñizni oñ ketirsin!",
            bannerCyrl: "Алла ишинъизни онъ кетирсин!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Алла ишинъни онъ кетирсин",
            translationUA: "«Нехай Бог сприяє вашій справі (успішного початку)!»",
            translationEN: "\"May God grant success to your work!\""
        ),
        .init(
            id: 63,
            text: "Sizge sağlıq-amanlıq tileymiz!",
            bannerCyrl: "Сизге сагълыкъ-аманлыкъ тилеймиз!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "Сизге ве къорантанъызгъа сагълыкъ-аманлыкъ тилеймиз.",
            translationUA: "«Бажаємо вам здоров'я і благополуччя!»",
            translationEN: "\"We wish you health and well-being!\""
        ),
        .init(
            id: 64,
            text: "Avada baar qoqusı bar!",
            bannerCyrl: "Авада баарь къокъусы бар!",
            attribution: nil,
            attributionCyrl: nil,
            sourceOriginal: "(avada) baar qoqusı bar — веет весной",
            translationUA: "«У повітрі пахне весною!»",
            translationEN: "\"There is the scent of spring in the air!\""
        ),
        .init(
            id: 65,
            text: "Qapımız açıq, törümiz boş!",
            bannerCyrl: "Къапымыз ачыкъ, тёрюмиз бош!",
            attribution: "Qırımtatar aytımı",
            attributionCyrl: "Къырымтатар айтымы",
            sourceOriginal: "Къапымыз ачыкъ, тёрюмиз бош — милости просим",
            translationUA: "«Наші двері відчинені, почесне місце вільне (ласкаво просимо)!» (Кримськотатарська приказка)",
            translationEN: "\"Our door is open, our place of honor is ready for you (welcome)!\" (Crimean Tatar idiom)"
        ),

        // V. ДОДАТКОВІ ВЕРИФІКОВАНІ ФРАЗИ З АНТОЛОГІЇ «ЭЙ, АНА ТИЛЬ!», ПРИСЛІВ'ЇВ ТА ДЖЕРЕЛ (`ios_verified.md`)
        .init(
            id: 66,
            text: "Atalar sözünde altın bar.",
            bannerCyrl: "Аталар сёзюнде алтын бар.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Аталар сёзюнде алтын бар. / Atalar sözünde altın bar.",
            translationUA: "«У словах предків є золото.» (Кримськотатарське прислів'я)",
            translationEN: "\"There is gold in the words of ancestors.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 67,
            text: "Atalar sözü — aqılnıñ közü.",
            bannerCyrl: "Аталар сёзю — акъылнынъ козю.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Аталар сёзю — акъылнынъ козю. / Atalar sözü — aqılnıñ közü.",
            translationUA: "«Слово предків — око розуму.» (Кримськотатарське прислів'я)",
            translationEN: "\"The word of ancestors is the eye of the mind.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 68,
            text: "Yahşı söz — can azığı.",
            bannerCyrl: "Яхшы сёз — джан азыгъы.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Яхшы сёз — джан азыгъы, яман сёз — баш къазыгъы.",
            translationUA: "«Добре слово — пожива для душі.» (Кримськотатарське прислів'я)",
            translationEN: "\"A kind word is nourishment for the soul.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 69,
            text: "Til — yürekniñ anahtarı.",
            bannerCyrl: "Тиль — юрекнинъ анахтары.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Тиль — юрекнинъ анахтары. / Til — yürekniñ anahtarı.",
            translationUA: "«Мова — ключ до серця.» (Кримськотатарське прислів'я)",
            translationEN: "\"Language is the key to the heart.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 70,
            text: "Az ayt, naz ayt!",
            bannerCyrl: "Аз айт, наз айт!",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Аз айт, наз айт! / Az ayt — naz ayt.",
            translationUA: "«Мало кажи — вишукано кажи!» (Кримськотатарське прислів'я)",
            translationEN: "\"Speak little, speak gracefully!\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 71,
            text: "Tilge ürmet — ilge ürmettir.",
            bannerCyrl: "Тильге урьмет — ильге урьметтир.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Тильге урьмет — ильге урьметтир.",
            translationUA: "«Повага до мови — це повага до краю (народу).» (Кримськотатарське прислів'я)",
            translationEN: "\"Respect for the language is respect for the people.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 72,
            text: "Sözüñnen işiñ bir olsun!",
            bannerCyrl: "Сёзюнънен ишинъ бир олсун!",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Сёзюнънен ишинъ бир олсун! / Sözüñnen işiñ bir olsun.",
            translationUA: "«Нехай твоє слово і твоє діло будуть єдиними!» (Кримськотатарське прислів'я)",
            translationEN: "\"Let your word and your deed be one!\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 73,
            text: "Kişiniñ sözünen işi bir olmalı.",
            bannerCyrl: "Кишининъ сёзюнен иши бир олмалы.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Кишининъ сёзюнен иши бир олмалы. / Kişiniñ sözünen işi bir olmalı.",
            translationUA: "«Слово і діло людини мають бути єдиними.» (Кримськотатарське прислів'я)",
            translationEN: "\"A person's word and deed must be one.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 74,
            text: "Aqiqiy söz aqqan suvnı toqtatır.",
            bannerCyrl: "Акъикъий сёз акъкъан сувны токътатыр.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Акъикъий сёз акъкъан сувны токътатыр. / Aqiqiy söz aqqan suvnı toqtatır.",
            translationUA: "«Правдиве слово зупинить і плинну воду.» (Кримськотатарське прислів'я)",
            translationEN: "\"A true word stops even flowing water.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 75,
            text: "Tatlı söz baldan tatlı.",
            bannerCyrl: "Татлы сёз балдан татлы.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Татлы сёз балдан татлы. / Tatlı söz baldan tatlı.",
            translationUA: "«Лагідне (солодке) слово солодше за мед.» (Кримськотатарське прислів'я)",
            translationEN: "\"A sweet word is sweeter than honey.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 76,
            text: "Ana tiliñ — baldan tatlı.",
            bannerCyrl: "Ана тилинъ — балдан татлы.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Ана тилинъ — балдан татлы.",
            translationUA: "«Рідна мова — солодша за мед.» (Кримськотатарське прислів'я)",
            translationEN: "\"Your mother tongue is sweeter than honey.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 77,
            text: "Tiliñnen göñlüñ bir olmalı.",
            bannerCyrl: "Тилинънен гонълюнъ бир олмалы.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Тилинънен гонълюнъ бир олмалы. / Tiliñnen göñlüñ bir olmalı.",
            translationUA: "«Твої слова і твоє серце мають бути єдиними.» (Кримськотатарське прислів'я)",
            translationEN: "\"Your tongue and your heart must be one.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 78,
            text: "Göñlüñdeki — tiliñde.",
            bannerCyrl: "Гонълюнъдеки — тилинъде.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Гонълюнъдеки — тилинъде. / Göñlüñdeki — tiliñde.",
            translationUA: "«Що на серці (в душі) — те й на язиці.» (Кримськотатарське прислів'я)",
            translationEN: "\"What is in the heart is on the tongue.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 79,
            text: "Emek — ömürniñ zinetidir.",
            bannerCyrl: "Эмек — омюрнинъ зинетидир.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Эмек — омюрнинъ зинетидир. / Emek — ömürniñ zinetidir.",
            translationUA: "«Праця — окраса життя.» (Кримськотатарське прислів'я)",
            translationEN: "\"Labor is the adornment of life.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 80,
            text: "Birlik evde bereket bar.",
            bannerCyrl: "Бирлик эвде берекет бар.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Бирлик эвде берекет бар. / Birlik evde bereket bar.",
            translationUA: "«У домі, де є злагода (єдність), є й достаток.» (Кримськотатарське прислів'я)",
            translationEN: "\"In a united home, there is abundance.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 81,
            text: "Muhabbetlik — baht anahtarı.",
            bannerCyrl: "Мухаббетлик — бахт анахтары.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Мухаббетлик — бахт анахтары. / Muhabbetlik — baht anahtarı.",
            translationUA: "«Любов (дружелюбність) — ключ до щастя.» (Кримськотатарське прислів'я)",
            translationEN: "\"Love and affection are the key to happiness.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 82,
            text: "Tilini coyğan, Vatanını coyar.",
            bannerCyrl: "Тилини джойгъан, Ватаныны джояр.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Тилини джойгъан, Ватаныны джояр.",
            translationUA: "«Хто втратив свою мову — втратить і Батьківщину.» (Кримськотатарське прислів'я)",
            translationEN: "\"Whoever loses their language will lose their Homeland.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 83,
            text: "Aşnıñ dadı — tuznen, adamnıñ dadı — söznen.",
            bannerCyrl: "Ашнынъ дады — тузнен, адамнынъ дады — сёзнен.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Ашнынъ дады — тузнен, адамнынъ дады — сёзнен. / Aşnıñ dadı — tuznen, adamnıñ dadı — söznen.",
            translationUA: "«Смак страви — у солі, а суть людини — у слові.» (Кримськотатарське прислів'я)",
            translationEN: "\"The taste of food is in salt; the essence of a person is in their word.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 84,
            text: "Qulaq — eki, til — bir: eki diñle, bir söyle.",
            bannerCyrl: "Къулакъ — эки, тиль — бир: эки динъле, бир сёйле.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Къулакъ — эки, тиль — бир: эки динъле, бир сёйле.",
            translationUA: "«Вух — двоє, язик — один: двічі слухай, один раз кажи.» (Кримськотатарське прислів'я)",
            translationEN: "\"Two ears, one tongue: listen twice, speak once.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 85,
            text: "Tilni bilmek — dostluqnı qaviyleştirmektir.",
            bannerCyrl: "Тильни бильмек — достлукъны къавийлештирмектир.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Тильни бильмек — достлукъны къавийлештирмектир.",
            translationUA: "«Знати мову — це зміцнювати дружбу.» (Кримськотатарське прислів'я)",
            translationEN: "\"Knowing a language strengthens friendship.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 86,
            text: "Bir filcan qaveniñ qırq yıl hatri bardır.",
            bannerCyrl: "Бир фильджан къавенинъ къыркъ йыл хатри бардыр.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Бир фильджан къавенинъ къыркъ йыл хатри бардыр.",
            translationUA: "«Одна філіжанка кави має сорок років пошани.» (Кримськотатарське прислів'я)",
            translationEN: "\"A single cup of coffee is remembered with gratitude for forty years.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 87,
            text: "Ana tilim — canım-cigerim.",
            bannerCyrl: "Ана тилим — джаным-джигерим.",
            attribution: "Dilâver Osman",
            attributionCyrl: "Дилявер Осман",
            sourceOriginal: "Ана тилим — джаным-джигерим.",
            translationUA: "«Рідна мово моя — душе й серце моє.» (Ділявер Осман)",
            translationEN: "\"My native tongue is my heart and soul.\" (Dilâver Osman)"
        ),
        .init(
            id: 88,
            text: "Ana tilim — halqnıñ temeli.",
            bannerCyrl: "Ана тилим — халкънынъ темели.",
            attribution: "Dilâver Osman",
            attributionCyrl: "Дилявер Осман",
            sourceOriginal: "Ана тилим — халкънынъ темели.",
            translationUA: "«Рідна мова — основа народу.» (Ділявер Осман)",
            translationEN: "\"My native language is the foundation of the people.\" (Dilâver Osman)"
        ),
        .init(
            id: 89,
            text: "Til — bizim temelimiz!",
            bannerCyrl: "Тиль — бизим темелимиз!",
            attribution: "Seyran Üseinov",
            attributionCyrl: "Сейран Усеинов",
            sourceOriginal: "Тиль — бизим темелимиз!",
            translationUA: "«Мова — наша основа!» (Сейран Усеїнов)",
            translationEN: "\"Language is our foundation!\" (Seyran Üseinov)"
        ),
        .init(
            id: 90,
            text: "Öz tiliñni bilsin er kes!",
            bannerCyrl: "Озь тилинъни бильсин эр кес!",
            attribution: "Seyran Üseinov",
            attributionCyrl: "Сейран Усеинов",
            sourceOriginal: "Озь тилини бильсин эр кес!",
            translationUA: "«Нехай кожен знає свою рідну мову!» (Сейран Усеїнов)",
            translationEN: "\"Let everyone know their native language!\" (Seyran Üseinov)"
        ),
        .init(
            id: 91,
            text: "Dünyada eñ tatlı — qırımtatar tilimiz!",
            bannerCyrl: "Дюньяда энъ татлы — къырымтатар тилимиз!",
            attribution: "Seyran Üseinov",
            attributionCyrl: "Сейран Усеинов",
            sourceOriginal: "Дюньяда энъ татлы... Къырымтатар тилимиз!",
            translationUA: "«Найсолодша у світі — наша кримськотатарська мова!» (Сейран Усеїнов)",
            translationEN: "\"The sweetest in the world is our Crimean Tatar language!\" (Seyran Üseinov)"
        ),
        .init(
            id: 92,
            text: "Sevdigim ana til — ruhumnıñ ğıdası.",
            bannerCyrl: "Севдигим ана тиль — рухумнынъ гъыдасы.",
            attribution: "Mambet Ablâlimov",
            attributionCyrl: "Мамбет Аблялимов",
            sourceOriginal: "Севдигим ана тиль — рухумнынъ гъыдасы.",
            translationUA: "«Люба рідна мова — пожива мого духу.» (Мамбет Аблялімов)",
            translationEN: "\"My beloved mother tongue is the nourishment of my spirit.\" (Mambet Ablâlimov)"
        ),
        .init(
            id: 93,
            text: "Ana tilim — bu muabbetlik, sevgi sırı.",
            bannerCyrl: "Ана тилим — бу муаббетлик, севги сыры.",
            attribution: "Löman Suleyman",
            attributionCyrl: "Лёман Сулейман",
            sourceOriginal: "Ана тилим — бу муаббетлик, севги сыры",
            translationUA: "«Моя рідна мова — це доброта й таємниця любові.» (Льоман Сулейман)",
            translationEN: "\"My mother tongue is affection and the secret of love.\" (Löman Suleyman)"
        ),
        .init(
            id: 94,
            text: "Ana tili aenklidir, yımşaqtır.",
            bannerCyrl: "Ана тили аэнклидир, йымшакътыр.",
            attribution: "Riza Halid",
            attributionCyrl: "Риза Халид",
            sourceOriginal: "Ана тили аэнклидир, йымшакътыр.",
            translationUA: "«Рідна мова милозвучна й лагідна.» (Різа Халід)",
            translationEN: "\"The mother tongue is melodious and gentle.\" (Riza Halid)"
        ),
        .init(
            id: 95,
            text: "Sen bar ekeç, men de barım!",
            bannerCyrl: "Сен бар экеч, мен де барым!",
            attribution: "Şeryan Ali",
            attributionCyrl: "Шерьян Али",
            sourceOriginal: "Сен бар экеч, мен де барым!",
            translationUA: "«Доки є ти — є і я!» (Шерьян Алі)",
            translationEN: "\"As long as you exist, I exist too!\" (Şeryan Ali)"
        ),
        .init(
            id: 96,
            text: "Tiliñni bil, oqu, yaz!",
            bannerCyrl: "Тилинъни биль, окъу, яз!",
            attribution: "Vasfiye Qıpçaq",
            attributionCyrl: "Васфие Къыпчакъ",
            sourceOriginal: "Менден сизлерге мирас — Тилинъни биль, окъу, яз!",
            translationUA: "«Знай свою мову, читай і пиши!» (Васфіє Кипчак)",
            translationEN: "\"Know your language, read, and write!\" (Vasfiye Qıpçaq)"
        ),
        .init(
            id: 97,
            text: "Çatırtav kibidir — bu Ana tilim!",
            bannerCyrl: "Чатыртав кибидир — бу Ана тилим!",
            attribution: "Kerim Camanaqlı",
            attributionCyrl: "Керим Джаманакълы",
            sourceOriginal: "Чатыртав кибидир — бу Ана тилим!",
            translationUA: "«Немов Чатир-Даг — ця моя рідна мова!» (Керім Джаманакли)",
            translationEN: "\"Like Chatyr-Dag is this Mother Tongue of mine!\" (Kerim Camanaqlı)"
        ),
        .init(
            id: 98,
            text: "Oqup-yazam bugün men!",
            bannerCyrl: "Окъуп-язам бугунь мен!",
            attribution: "Seitümer Emin",
            attributionCyrl: "Сеитумер Эмин",
            sourceOriginal: "Окъуп-язам мен бугунь, Ана тилим бу меним.",
            translationUA: "«Сьогодні я читаю і пишу (рідною мовою)!» (Сейтумер Емін)",
            translationEN: "\"Today I read and write (in my native tongue)!\" (Seitümer Emin)"
        ),
        .init(
            id: 99,
            text: "Yürekni ohşar tatlı sözleriñ!",
            bannerCyrl: "Юрекни охшар татлы сёзлеринъ!",
            attribution: "Seitümer Emin",
            attributionCyrl: "Сеитумер Эмин",
            sourceOriginal: "Юрекни охшар татлы сёзлеринъ",
            translationUA: "«Твої солодкі слова пестять серце!» (Сейтумер Емін)",
            translationEN: "\"Your sweet words caress the heart!\" (Seitümer Emin)"
        ),
        .init(
            id: 100,
            text: "Tuvğan tilim! Güzel tilim!",
            bannerCyrl: "Тувгъан тилим! Гузель тилим!",
            attribution: "Şakir Selim",
            attributionCyrl: "Шакир Селим",
            sourceOriginal: "Тувгъан тилим! Гузель тилим! Кене яша!",
            translationUA: "«Рідна мово моя! Прекрасна мово моя!» (Шакір Селім)",
            translationEN: "\"My native tongue! My beautiful tongue!\" (Şakir Selim)"
        ),
        .init(
            id: 101,
            text: "Elleriñiz dert körmesin!",
            bannerCyrl: "Эллеринъиз дерт корьмесин!",
            attribution: "Halq alğışı",
            attributionCyrl: "Халкъ алгъышы",
            sourceOriginal: "Эллеринъиз дерт корьмесин!",
            translationUA: "«Нехай ваші руки ніколи не знають болю (біди)!» (Народне благословення)",
            translationEN: "\"May your hands never know pain!\" (Folk blessing)"
        ),
        .init(
            id: 102,
            text: "Eliñe sağlıq!",
            bannerCyrl: "Элинъе сагълыкъ!",
            attribution: "Halq alğışı",
            attributionCyrl: "Халкъ алгъышы",
            sourceOriginal: "Элинъе сагълыкъ! / Къолунъа сагълыкъ!",
            translationUA: "«Здоров'я твоїм рукам! (вдячність за гарну працю чи письмо).» (Народне благословення)",
            translationEN: "\"Health to your hands! (traditional gratitude for good work or writing).\" (Folk blessing)"
        ),
        .init(
            id: 103,
            text: "Bergen el dert körmez.",
            bannerCyrl: "Берген эль дерт корьмез.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Берген эль дерт корьмез.",
            translationUA: "«Рука, що дає, не знатиме болю (біди).» (Кримськотатарське прислів'я)",
            translationEN: "\"The hand that gives will know no pain.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 104,
            text: "Ünerli qolda bereket bar.",
            bannerCyrl: "Унерли къолда берекет бар.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Унерли къолда берекет бар. / Ünerli qolda bereket bar.",
            translationUA: "«В умілих руках є благословення (достаток).» (Кримськотатарське прислів'я)",
            translationEN: "\"In skilled hands there is blessing and abundance.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 105,
            text: "Ağzıñızdan bal tamlay!",
            bannerCyrl: "Агъзынъыздан бал тамлай!",
            attribution: "Qırımtatar aytımı",
            attributionCyrl: "Къырымтатар айтымы",
            sourceOriginal: "Агъызындан (агъзындан) бал тамлай",
            translationUA: "«З ваших уст мед крапає!» (Кримськотатарський фразеологізм)",
            translationEN: "\"Honey drips from your lips!\" (Crimean Tatar idiom)"
        ),
        .init(
            id: 106,
            text: "Hoş sefa keldiñiz!",
            bannerCyrl: "Хош сефа кельдинъиз!",
            attribution: "Selâmlaşuv",
            attributionCyrl: "Селямлашув",
            sourceOriginal: "Хош сефа кельдинъиз! / Hoş sefa keldiñiz!",
            translationUA: "«Ласкаво просимо! (Раді вашому приходу!).» (Вітання)",
            translationEN: "\"Welcome! (Glad you have come!).\" (Greeting)"
        ),
        .init(
            id: 107,
            text: "Saba şerfiñiz hayır olsun!",
            bannerCyrl: "Саба шерфинъиз хайыр олсун!",
            attribution: "Selâmlaşuv",
            attributionCyrl: "Селямлашув",
            sourceOriginal: "«Саба шерфинъиз хайыр олсын» (с. 121)",
            translationUA: "«Нехай ваш благословенний ранок буде добрим!» (Ранкове вітання)",
            translationEN: "\"May your blessed morning be good!\" (Morning greeting)"
        ),
        .init(
            id: 108,
            text: "Hayırlı sabalar olsun!",
            bannerCyrl: "Хайырлы сабалар олсун!",
            attribution: "Selâmlaşuv",
            attributionCyrl: "Селямлашув",
            sourceOriginal: "Хайырлы сабалар! / Сабалар хайыр!",
            translationUA: "«Доброго ранку!» (Ранкове вітання)",
            translationEN: "\"Good morning!\" (Morning greeting)"
        ),
        .init(
            id: 109,
            text: "Künüñiz hayırlı olsun!",
            bannerCyrl: "Кунюнъиз хайырлы олсун!",
            attribution: "Selâmlaşuv",
            attributionCyrl: "Селямлашув",
            sourceOriginal: "Кунюнъиз хайырлы олсун! / Hayırlı künler!",
            translationUA: "«Нехай ваш день буде добрим (вдалим)!» (Денне вітання)",
            translationEN: "\"Have a good and blessed day!\" (Daytime greeting)"
        ),
        .init(
            id: 110,
            text: "Aqşam şerfiñiz hayır olsun!",
            bannerCyrl: "Акъшам шерфинъиз хайыр олсун!",
            attribution: "Selâmlaşuv",
            attributionCyrl: "Селямлашув",
            sourceOriginal: "«Акъшам шерфинъиз хайыр олсын, достлар!» (с. 121–122)",
            translationUA: "«Нехай ваш благословенний вечір буде добрим!» (Вечірнє вітання)",
            translationEN: "\"May your blessed evening be good!\" (Evening greeting)"
        ),
        .init(
            id: 111,
            text: "Geceler hayır! Hayırğa qarşı!",
            bannerCyrl: "Геджелер хайыр! Хайыргъа къаршы!",
            attribution: "Sağlıqlaşuv",
            attributionCyrl: "Сагълыкълашув",
            sourceOriginal: "«Гиджелер хайыр!» / Geceñiz hayır! Hayırğa qarşı!",
            translationUA: "«На добраніч! Назустріч добру!» (Побажання на добраніч)",
            translationEN: "\"Good night! Towards the good!\" (Goodnight wish)"
        ),
        .init(
            id: 112,
            text: "Şehr-u Ramazan, merhaba!",
            bannerCyrl: "Шехр-у Рамазан, мерхаба!",
            attribution: "Ramazan ilâhisi",
            attributionCyrl: "Рамазан иляхиси",
            sourceOriginal: "«Кельди хош лутф иле шехр-у Рамазан! Мерхаба я, мерхаба я! Шехр-у Рамазан, мерхаба!»",
            translationUA: "«Ласкаво просимо, благословенний місяцю Рамазан!» (Традиційне вітання Рамазану)",
            translationEN: "\"Welcome, O blessed month of Ramadan!\" (Traditional Ramadan hymn)"
        ),
        .init(
            id: 113,
            text: "Oraza bayramıñız hayırlı olsun!",
            bannerCyrl: "Ораза байрамынъыз хайырлы олсун!",
            attribution: "Bayram qutlavı",
            attributionCyrl: "Байрам къутлавы",
            sourceOriginal: "Ораза (Рамазан) байрамы ... «Хайырлы олсын»",
            translationUA: "«Нехай ваше свято Ораза-байрам буде благословенним і добрим!» (Святкове привітання)",
            translationEN: "\"May your Eid al-Fitr (Oraza Bayram) be blessed and auspicious!\" (Holiday greeting)"
        ),
        .init(
            id: 114,
            text: "Qurban bayramıñız hayırlı olsun!",
            bannerCyrl: "Къурбан байрамынъыз хайырлы олсун!",
            attribution: "Bayram qutlavı",
            attributionCyrl: "Байрам къутлавы",
            sourceOriginal: "Къурбан байрамы — мусульманларнынъ энъ буюк эки байрамындан бири",
            translationUA: "«Нехай ваше свято Курбан-байрам буде благословенним і добрим!» (Святкове привітання)",
            translationEN: "\"May your Eid al-Adha (Qurban Bayram) be blessed and auspicious!\" (Holiday greeting)"
        ),
        .init(
            id: 115,
            text: "Cuma künüñiz mubarek olsun!",
            bannerCyrl: "Джума кунюнъиз мубарек олсун!",
            attribution: "Cuma qutlavı",
            attributionCyrl: "Джума къутлавы",
            sourceOriginal: "Джума — афтанынъ бешинджи куни (с. 154)",
            translationUA: "«Нехай ваша п'ятниця (Джума) буде благословенною!» (П'ятничне вітання)",
            translationEN: "\"May your Friday (Jumu'ah) be blessed!\" (Friday greeting)"
        ),
        .init(
            id: 116,
            text: "Amet-Han — tillerde destansıñ!",
            bannerCyrl: "Амет-Хан — тиллерде дестансынъ!",
            attribution: "Riza Fazıl",
            attributionCyrl: "Риза Фазыл",
            sourceOriginal: "Аметхан, коклерде Султансынъ, Аметхан, тиллерде дестансынъ.",
            translationUA: "«Амет-Хане, на устах ти — легенда!» (Різа Фазил)",
            translationEN: "\"Amet-Khan, on every tongue you are a legend!\" (Riza Fazıl)"
        ),
        .init(
            id: 117,
            text: "Ant etkenmen yaranı sarmağa!",
            bannerCyrl: "Ант эткенмен яраны сармагъа!",
            attribution: "Noman Çelebicihan",
            attributionCyrl: "Номан Челебиджихан",
            sourceOriginal: "Ант эткенмен, миллетимнинъ ярасыны сармагъа",
            translationUA: "«Я присягнувся перев'язати рани (свого народу)!» (Номан Челебіджихан)",
            translationEN: "\"I have sworn to bind the wounds (of my people)!\" (Noman Çelebicihan)"
        ),
        .init(
            id: 118,
            text: "Navrez keldi — yaz keldi!",
            bannerCyrl: "Наврез кельди — яз кельди!",
            attribution: "Qırımtatar halq yırı",
            attributionCyrl: "Къырымтатар халкъ йыры",
            sourceOriginal: "Наврез кельди — яз кельди!",
            translationUA: "«Наврез прийшов — весна (літо) прийшла!» (Кримськотатарська народна пісня)",
            translationEN: "\"Navrez has come—spring has arrived!\" (Crimean Tatar folk song)"
        ),
        .init(
            id: 119,
            text: "Tilde, fikirde, işte — birlik!",
            bannerCyrl: "Тильде, фикирде, иште — бирлик!",
            attribution: "İsmail Gasprinskiy",
            attributionCyrl: "Исмаиль Гаспринский",
            sourceOriginal: "‘Tilde, fikirde, işte – birlik!’ şiarında kerçekleşti.",
            translationUA: "«У мові, у думці, у ділі — єдність!» (Ісмаїл Гаспринський)",
            translationEN: "\"Unity in language, in thought, and in action!\" (İsmail Gasprinskiy)"
        ),
        .init(
            id: 120,
            text: "Közü yoq — körsete, sözü yoq — ögrete: Kitap.",
            bannerCyrl: "Козю ёкъ — корьсете, сёзю ёкъ — огрете: Китап.",
            attribution: "Qırımtatar tapmacası",
            attributionCyrl: "Къырымтатар тапмаджасы",
            sourceOriginal: "Козю ёкъ — корьсете, сёзю ёкъ — огрете. (Китап)",
            translationUA: "«Очей не має — а показує, слів не має — а навчає: Книга.» (Кримськотатарська загадка)",
            translationEN: "\"Has no eyes yet shows, has no words yet teaches: A Book.\" (Crimean Tatar riddle)"
        ),
        .init(
            id: 121,
            text: "Birlik olğan yerde tirlik bar.",
            bannerCyrl: "Бирлик олгъан ерде тирлик бар.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Бирлик олгъан ерде тирлик бар. / Birlik olğan yerde tirlik bar.",
            translationUA: "«Де є єдність — там є життя.» (Кримськотатарське прислів'я)",
            translationEN: "\"Where there is unity, there is life.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 122,
            text: "Ana-babaña ürmet etseñ, özüñ ürmet körersiñ.",
            bannerCyrl: "Ана-бабанъа урьмет этсенъ, озюнъ урьмет корерсинъ.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Ана-бабанъа урьмет этсенъ, озюнъ урьмет корерсинъ.",
            translationUA: "«Шануватимеш батька й матір — сам зазнаєш пошани.» (Кримськотатарське прислів'я)",
            translationEN: "\"If you honor your mother and father, you yourself will be honored.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 123,
            text: "Qırım — menim Vatanımdır!",
            bannerCyrl: "Къырым — меним Ватанымдыр!",
            attribution: "Çerkez-Ali",
            attributionCyrl: "Черкез-Али",
            sourceOriginal: "Къырым деген бу ульке, Манъа догъмуш Ватандыр.",
            translationUA: "«Крим — моя рідна Батьківщина!» (Черкез-Алі)",
            translationEN: "\"Crimea is my native Homeland!\" (Çerkez-Ali)"
        ),
        .init(
            id: 124,
            text: "Allah keçmişlerimizni rahmet eylesin!",
            bannerCyrl: "Аллах кечмишлеримизни рахмет эйлесин!",
            attribution: "Hatıra duası",
            attributionCyrl: "Хатыра дуасы",
            sourceOriginal: "Юдже Аллаһтан сизге рахмет тилерим (с. 126, 217)",
            translationUA: "«Нехай Всевишній помилує душі наших предків (померлих)!» (Молитва пам'яті)",
            translationEN: "\"May God have mercy on the souls of our departed ancestors!\" (Prayer of remembrance)"
        ),
        .init(
            id: 125,
            text: "Canımız-cigerimiz — balalar!",
            bannerCyrl: "Джанымыз-джигеримиз — балалар!",
            attribution: "Remziye Tarsinova",
            attributionCyrl: "Ремзие Тарсинова",
            sourceOriginal: "Барымыз-ёкъумыз, джанымыз-джигеримиз — балаларымызнынъдыр.",
            translationUA: "«Наша душа й серце — це діти!» (Ремзіє Тарсінова)",
            translationEN: "\"Our heart and soul are our children!\" (Remziye Tarsinova)"
        ),
        .init(
            id: 126,
            text: "Milletniñ şanı — bayrağında!",
            bannerCyrl: "Миллетнинъ шаны — байрагъында!",
            attribution: "Noman Çelebicihan",
            attributionCyrl: "Номан Челебиджихан",
            sourceOriginal: "Эр бир миллетнинъ шаны, шерефи, намусы... шу миллетнинъ байрагъында озь ифадесини булгъандыр.",
            translationUA: "«Слава й честь народу — у його прапорі!» (Номан Челебіджихан)",
            translationEN: "\"The glory and honor of a nation are in its flag!\" (Noman Çelebicihan)"
        ),
        .init(
            id: 127,
            text: "Oquvnı sevgen oqur, soñundan gülday qoqur.",
            bannerCyrl: "Окъувны севген окъур, сонъундан гульдай къокъур.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Окъувны севген окъур, сонъундан гульдай къокъур.",
            translationUA: "«Хто любить навчання, той читає, а згодом квітне й пахне, мов троянда.» (Кримськотатарське прислів'я)",
            translationEN: "\"Whoever loves learning will study, and later blossom like a rose.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 128,
            text: "Baardeki areket — küzdeki bereket.",
            bannerCyrl: "Баарьдеки арекет — кузьдеки берекет.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Баарьдеки арекет — кузьдеки берекет. / Baardeki areket — küzdeki bereket.",
            translationUA: "«Весняна праця (рух) — осінній достаток (урожай).» (Кримськотатарське прислів'я)",
            translationEN: "\"Effort in spring brings abundance in autumn.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 129,
            text: "Şegirt olmay, usta olmazsıñ.",
            bannerCyrl: "Шегирт олмай, уста олмазсынъ.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Шегирт олмай, уста олмазсынъ. / Şegirt olmay, usta olmazsıñ.",
            translationUA: "«Не побувши учнем, не станеш майстром.» (Кримськотатарське прислів'я)",
            translationEN: "\"Without being an apprentice, you cannot become a master.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 130,
            text: "Öz tuvğan tilimde ayt mağa!",
            bannerCyrl: "Озь тувгъан тилимде айт магъа!",
            attribution: "Bekir Çoban-zade",
            attributionCyrl: "Бекир Чобан-заде",
            sourceOriginal: "«Озь тувгъан тилимде айт магъа!» дермен",
            translationUA: "«Скажи мені моєю рідною мовою!» (Бекір Чобан-заде)",
            translationEN: "\"Speak to me in my native tongue!\" (Bekir Çoban-zade)"
        ),
        .init(
            id: 131,
            text: "Türkiy tiller gülzarınıñ fidanı!",
            bannerCyrl: "Тюркий тиллер гульзарынынъ фиданы!",
            attribution: "Eşref Şemi-zade",
            attributionCyrl: "Эшреф Шемьи-заде",
            sourceOriginal: "Тюркий тиллер гульзарынынъ Энъ чечекли фиданы.",
            translationUA: "«Пагін трояндового саду тюркських мов!» (Ешреф Шем'ї-заде)",
            translationEN: "\"The sapling of the rose garden of Turkic languages!\" (Eşref Şemi-zade)"
        ),
        .init(
            id: 132,
            text: "Terek tamırlarına tayanır, insan — tuvğanlarına.",
            bannerCyrl: "Терек тамырларына таяныр, инсан — тувгъанларына.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Терек тамырларына таяныр, инсан — тувгъанларына.",
            translationUA: "«Дерево тримається на корінні, а людина — на рідних.» (Кримськотатарське прислів'я)",
            translationEN: "\"A tree relies on its roots; a person relies on their family.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 133,
            text: "Yol köstergen Çolpan yıldızım!",
            bannerCyrl: "Ёл косьтерген Чолпан йылдызым!",
            attribution: "Yunus Qandım",
            attributionCyrl: "Юнус Къандым",
            sourceOriginal: "Къаранлыкъта ёл косьтерген Чолпан йылдызым.",
            translationUA: "«Моя ранкова зоря Чолпан, що вказує шлях!» (Юнус Кандим)",
            translationEN: "\"My morning star Venus that shows the way!\" (Yunus Qandım)"
        ),
        .init(
            id: 134,
            text: "Acayipsiñ, Ana tili!",
            bannerCyrl: "Аджайипсинъ, Ана тили!",
            attribution: "İdris Asanin",
            attributionCyrl: "Идрис Асанин",
            sourceOriginal: "Догъгъан еринъ киби дюльбер, Аджайипсинъ, Ана тили!",
            translationUA: "«Дивовижна ти, рідна мово!» (Ідріс Асанін)",
            translationEN: "\"You are wonderful, Mother Tongue!\" (İdris Asanin)"
        ),
        .init(
            id: 135,
            text: "İşiñiz oñ kelsin!",
            bannerCyrl: "Ишинъиз онъ кельсин!",
            attribution: "Halq alğışı",
            attributionCyrl: "Халкъ алгъышы",
            sourceOriginal: "ишинъиз онъ кельсин!",
            translationUA: "«Нехай ваша справа легко вдається (йде на лад)!» (Народне благословення)",
            translationEN: "\"May your work go smoothly and succeed!\" (Folk blessing)"
        ),
        .init(
            id: 136,
            text: "Vatan — ekinci anañ.",
            bannerCyrl: "Ватан — экинджи ананъ.",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "Ватан — экинджи ананъ. / Vatan — ekinci anañ.",
            translationUA: "«Батьківщина — твоя друга матір.» (Кримськотатарське прислів'я)",
            translationEN: "\"The homeland is your second mother.\" (Crimean Tatar proverb)"
        ),
        .init(
            id: 137,
            text: "Birlikte — quvet!",
            bannerCyrl: "Бирликте — къувет!",
            attribution: "Qırımtatar atalar sözü",
            attributionCyrl: "Къырымтатар аталар сёзю",
            sourceOriginal: "«Бирликте — къувет»",
            translationUA: "«У єдності — сила!» (Кримськотатарське прислів'я)",
            translationEN: "\"In unity there is strength!\" (Crimean Tatar proverb)"
        )
    ]

    private static let byID: [Int: KeyboardGreetingPhrase] = Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })

    /// General unrestricted wisdom & motivation pool (`ios_verified.md` + `ios (3).md`).
    static let dailyPool: [KeyboardGreetingPhrase] = all.filter {
        (1...31).contains($0.id) || [37, 39, 40].contains($0.id) || (66...106).contains($0.id) || [134, 137].contains($0.id)
    }

    /// Builds the eligible pool of phrases for the given date/time:
    /// 1. Fixed calendar date / Hijri holiday
    /// 2. Weekday / Weekend
    /// 3. Time-of-day greetings
    /// 4. General unrestricted wisdom & motivation pool (`dailyPool`)
    static func candidates(for date: Date = Date()) -> [KeyboardGreetingPhrase] {
        var specialAndTimeMatched: [KeyboardGreetingPhrase] = []
        let cal = Calendar(identifier: .gregorian)
        let comps = cal.dateComponents([.year, .month, .day, .weekday, .hour], from: date)
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        let weekday = comps.weekday ?? 2 // 1 = Sun, 2 = Mon, ..., 6 = Fri, 7 = Sat
        let hour = comps.hour ?? 12

        func appendIfPresent(_ id: Int) {
            if let item = byID[id], !specialAndTimeMatched.contains(item) {
                specialAndTimeMatched.append(item)
            }
        }

        // Priority 1A: Hijri (Islamic Umm al-Qura) holidays
        let hijri = Calendar(identifier: .islamicUmmAlQura)
        let hComps = hijri.dateComponents([.month, .day], from: date)
        if hComps.month == 9, hComps.day == 1 {
            appendIfPresent(41)  // 1 Ramadan
            appendIfPresent(112) // Şehr-u Ramazan, merhaba!
        } else if hComps.month == 10, let hDay = hComps.day, (1...3).contains(hDay) {
            appendIfPresent(42)  // Oraza Bayram (1–3 Shawwal)
            appendIfPresent(113)
        } else if hComps.month == 12, let hDay = hComps.day, (10...13).contains(hDay) {
            appendIfPresent(43)  // Qurban Bayram (10–13 Dhu al-Hijjah)
            appendIfPresent(114)
        }

        // Priority 1B: Exact Gregorian dates (dd.MM)
        switch (day, month) {
        case (1, 2):  appendIfPresent(116) // Amet-Han Sultan memorial day
        case (21, 2): appendIfPresent(45)  // Mother Language Day
        case (23, 2): appendIfPresent(117) // Noman Çelebicihan memorial day
        case (1, 3):
            appendIfPresent(64)  // First day of spring
            appendIfPresent(128)
        case (20, 3): appendIfPresent(54)  // İsmail Gasprinskiy
        case (21, 3):
            appendIfPresent(46)  // World Poetry Day / Navrez
            appendIfPresent(118)
        case (10, 4):
            appendIfPresent(47)  // Crimean Tatar Journalism Day (Terciman)
            appendIfPresent(119)
        case (23, 4):
            appendIfPresent(48)  // World Book Day
            appendIfPresent(120)
        case (15, 5):
            appendIfPresent(55)  // Bekir Çoban-zade
            appendIfPresent(130)
        case (18, 5):
            appendIfPresent(50)  // May 18 Remembrance Day
            appendIfPresent(123)
            appendIfPresent(124)
        case (1, 6):
            appendIfPresent(51)  // Children's Day
            appendIfPresent(125)
        case (21, 6):
            appendIfPresent(56)  // Eşref Şemi-zade
            appendIfPresent(131)
        case (26, 6): appendIfPresent(126) // Crimean Tatar Flag Day
        case (12, 7):
            appendIfPresent(57)  // Şamil Alâdin
            appendIfPresent(132)
        case (1, 9):
            appendIfPresent(52)  // Knowledge Day
            appendIfPresent(127)
        case (4, 9):
            appendIfPresent(58)  // Yunus Qandım
            appendIfPresent(133)
        case (22, 9): appendIfPresent(128) // Derviza
        case (5, 10):
            appendIfPresent(53)  // Teachers' Day
            appendIfPresent(129)
        case (10, 10): appendIfPresent(59) // Ü. Ş. Tohtarğazı
        case (20, 10): appendIfPresent(60) // Amet-Han Sultan
        case (13, 11):
            appendIfPresent(61)  // İdris Asanin & Nuzet Ümerov
            appendIfPresent(134)
        case (1, 12):
            appendIfPresent(65)  // First day of winter
            appendIfPresent(137)
        default: break
        }
        if month == 5, weekday == 6, (1...7).contains(day) {
            appendIfPresent(121) // Hıdırlez (first Friday of May)
        }
        if month == 5, weekday == 1, (8...14).contains(day) {
            appendIfPresent(49)  // Mother's Day (second Sunday of May)
            appendIfPresent(122)
        }

        // Priority 2: Weekday / Weekend
        if weekday == 6 {
            appendIfPresent(44)  // Friday (Cuma)
            appendIfPresent(115)
        } else if weekday == 2, (6..<12).contains(hour) {
            appendIfPresent(62)  // Monday morning
            appendIfPresent(135)
        } else if (weekday == 1 || weekday == 7), (9..<21).contains(hour) {
            appendIfPresent(63)  // Weekend
            appendIfPresent(136)
        }

        // Priority 3: Time-of-day greetings
        if (5..<11).contains(hour) {
            appendIfPresent(32)
            appendIfPresent(107)
            appendIfPresent(108)
        } else if (11..<18).contains(hour) {
            appendIfPresent(33)
            appendIfPresent(109)
        } else if (18..<23).contains(hour) {
            appendIfPresent(34)
            appendIfPresent(110)
        } else {
            appendIfPresent(35)
            appendIfPresent(111)
        }
        if (8..<17).contains(hour) {
            appendIfPresent(86)
        }
        if (9..<21).contains(hour) {
            appendIfPresent(36)
        }
        if (8..<20).contains(hour) {
            appendIfPresent(38)
        }

        // Combine time/date-specific candidates with the general wisdom pool
        var list = specialAndTimeMatched
        for item in dailyPool where !list.contains(item) {
            list.append(item)
        }

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
        let eligible = KeyboardGreetingPhrase.candidates(for: date)
        var shuffled = eligible.shuffled()
        if let lastID = lastPickedID, shuffled.count > 1, shuffled.first?.id == lastID {
            let first = shuffled.removeFirst()
            shuffled.append(first)
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
    let keyboardContext: KeyboardContext
    let autocompleteAction: (Autocomplete.Suggestion) -> Void

    private var isFloating: Bool {
        keyboardContext.isKeyboardFloating
    }

    private var isDockedPad: Bool {
        keyboardContext.deviceType == .pad && !isFloating
    }

    private var height: CGFloat {
        isFloating ? 42 : (isDockedPad ? 37 : 42)
    }

    private var shouldShowGreetingBanner: Bool {
        guard !greetingState.isDismissedForCurrentSession else { return false }
        let suggestions = autocompleteContext.suggestions
        guard suggestions.isEmpty else { return false }
        let before = keyboardContext.textDocumentProxy.documentContextBeforeInput ?? ""
        let after = keyboardContext.textDocumentProxy.documentContextAfterInput ?? ""
        return before.isEmpty && after.isEmpty
    }

    var body: some View {
        let suggestions = Array(autocompleteContext.suggestions.prefix(3))
        let slotCount = 3

        GeometryReader { geo in
            let totalWidth = max(geo.size.width, 1)
            let sideInset: CGFloat = 0
            let centerWidth = max(totalWidth - (sideInset * 2), 1)
            let slotWidth = max((centerWidth - 1.0) / CGFloat(slotCount), 1)

            ZStack {
                if shouldShowGreetingBanner {
                    greetingBannerView(centerWidth: centerWidth)
                        .frame(width: totalWidth, height: height)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else {
                    HStack(spacing: 0) {
                        ForEach(0..<slotCount, id: \.self) { index in
                            let suggestion: Autocomplete.Suggestion? = index < suggestions.count ? suggestions[index] : nil

                            Button {
                                if let suggestion {
                                    autocompleteAction(suggestion)
                                }
                            } label: {
                                ZStack {
                                    Color.primary.opacity(0.001)

                                    if let suggestion {
                                        Text(suggestion.isUnknown ? "“\(suggestion.title)”" : suggestion.title)
                                            .font(isFloating ? .subheadline : .system(size: 16, weight: suggestion.isAutocorrect ? .semibold : .regular))
                                            .foregroundStyle(Color.primary)
                                            .lineLimit(1)
                                            .padding(.horizontal, isFloating ? 6 : 12)
                                            .padding(.vertical, isFloating ? 3 : 5)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6)
                                                    .fill(suggestion.isAutocorrect ? Color.primary.opacity(0.12) : Color.clear)
                                            )
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(FullSlotButtonStyle())
                            .frame(width: slotWidth, height: height)
                            .contentShape(Rectangle())
                            .accessibilityIdentifier("autocomplete.slot.\(index)")

                            if index < slotCount - 1 {
                                Color.secondary.opacity(0.28)
                                    .frame(width: 0.5, height: isFloating ? 16 : 24)
                            }
                        }
                    }
                    .frame(width: totalWidth, height: height)
                    .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.2), value: shouldShowGreetingBanner)
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
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

    @ViewBuilder
    private func greetingBannerView(centerWidth: CGFloat) -> some View {
        let phrase = greetingState.currentPhrase()
        let rightReserved: CGFloat = isDockedPad ? 96 : 10
        let maxPillWidth = min(max(centerWidth - rightReserved, 200), isDockedPad ? 660 : 520)

        HStack(spacing: 5) {
            Button {
                let inserted = phrase.formattedInsertText(for: KeyboardPreferences.interfaceLanguage)
                KeyboardUsageStats.markInjectedText(inserted)
                KeyboardUsageStats.recordPhraseInserted()
                TextHistoryManager.shared.recordInsert(inserted)
                keyboardContext.textDocumentProxy.insertText(inserted)
                SpaceBarState.shared.fadeToResting()
                greetingState.dismissForTyping()
            } label: {
                HStack(spacing: 6) {
                    TaraqTamgaShape()
                        .fill(Color.primary.opacity(0.65))
                        .frame(width: 13.5, height: 7.5)

                    Text(phrase.bannerCRH)
                        .font(.system(size: isFloating ? 12.5 : 14.0, weight: .medium))
                        .foregroundStyle(Color.primary.opacity(0.88))
                        .lineLimit(2)
                        .minimumScaleFactor(0.68)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    Image(systemName: "arrow.up.left.circle.fill")
                        .font(.system(size: 12.0, weight: .medium))
                        .foregroundStyle(Color.secondary.opacity(0.75))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, isDockedPad ? 4.0 : 4.5)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("autocomplete.greetingBanner")

            Button {
                greetingState.cycleNext()
            } label: {
                Image(systemName: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.secondary.opacity(0.8))
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(Color.primary.opacity(0.06)))
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
