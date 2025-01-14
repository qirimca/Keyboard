//
//  LocalTexts.swift
//

import SwiftUI

enum TextConst: String {
    /// "Qırımtatar klaviaturası"
    case title = "Qırımtatar klaviaturası"
    /// "Текстовое поле"
    case textPlace = "Metin meydanı"
    /// "Тёмная тема"
    case darkTheme = "Qara mevzu"
    /// "Редактор"
    case editor = "Muarrir"
    /// "Полноэкранный редактор"
    case fullEditor = "Tam ekran muarriri"
    /// "Клавиатура"
    case keyboard = "Klaviatura"
    /// "Клавиатура появилась"
    case keyboardVisible = "Klaviatura peyda oldı"
    // "Клавиатура не показывается"
    case keyboardHidden = "Klaviatura körünmey"
    /// "Клавиатура подключена"
    case keyboardOn = "Klaviatura bağlanğan"
    /// "Клавиатура не подключена"
    case keyboardOff = "Klaviatura bağlanmağan"
    /// "Активирован полный доступ"
    case fullAccessOn = "Tam irişim faalleştirildi"
    /// "Полный доступ не предоставлен"
    case fullAccessOff = "Tam irişim berilmedi"
    /// "Сначала добавьте клавиатуру в Системных настройках, потом выберите её через 🌐 во время набора текста."
    case systemSettingsForKeyboard = "İlk olaraq Sistem Sazlamalarda klaviaturanı qoşıp, soñra yazğanda 🌐 vastasınen onı saylanız."
    /// Space
    case space = "Boşluq"
    
    var asText: Text {
        Text(self.rawValue)
    }
}
