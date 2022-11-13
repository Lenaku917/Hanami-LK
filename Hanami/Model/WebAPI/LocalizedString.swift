//
//  LocalizedString.swift
//  Hanami
//
//  Created by Oleg on 15/05/2022.
//

import Foundation

// For details see
// https://api.mangadex.org/docs/static-data/#language-codes--localization

// swiftlint:disable identifier_name
struct LocalizedString: Codable {
    var ar, cs, en, es, esLa: String?
    var hi, hu, fa, fr, it: String?
    var jp, jpRo, ko, mn, ms: String?
    var nl, ru, th, uk, zh: String?
    var zhRo: String?
    
    enum CodingKeys: String, CodingKey {
        case ar, cs, en, es
        case esLa = "es-la"
        case hi, hu, fa, fr, it
        case jp = "ja"
        case jpRo = "ja-ro"
        case ko, mn, ms, nl, ru
        case th, uk, zh
        case zhRo = "zh-ro"
    }
}

extension LocalizedString {
    init(localizedStrings: [LocalizedString]) {
        localizedStrings.forEach { content in
            ar = ar == nil ? content.ar : ar
            cs = cs == nil ? content.cs : cs
            en = en == nil ? content.en : en
            es = es == nil ? content.es : es
            esLa = esLa == nil ? content.esLa : esLa
            hi = hi == nil ? content.hi : hi
            hu = hu == nil ? content.hu : hu
            fa = fa == nil ? content.fa : fa
            fr = fr == nil ? content.fr : fr
            it = it == nil ? content.it : it
            jp = jp == nil ? content.jp : jp
            jpRo = jpRo == nil ? content.jpRo : jpRo
            ko = ko == nil ? content.ko : ko
            mn = mn == nil ? content.mn : mn
            ms = ms == nil ? content.ms : ms
            nl = nl == nil ? content.nl : nl
            ru = ru == nil ? content.ru : ru
            th = th == nil ? content.th : th
            uk = uk == nil ? content.uk : uk
            zh = zh == nil ? content.zh : zh
            zhRo = zhRo == nil ? content.zhRo : zhRo
        }
    }
}

extension LocalizedString: Equatable { }

extension LocalizedString {
    private var _languageInfo: (language: String, flag: String)? {
        if let en {
            return (language: en, flag: "🇬🇧")
        } else if let ar {
            return (language: ar, flag: "🇦🇷")
        } else if let cs {
            return (language: cs, flag: "🇨🇿")
        } else if let es {
            return (language: es, flag: "🇪🇸")
        } else if let esLa {
            return (language: esLa, flag: "🇧🇷")
        } else if let hi {
            return (language: hi, flag: "🇮🇳")
        } else if let hu {
            return (language: hu, flag: "🇭🇺")
        } else if let fa {
            return (language: fa, flag: "🇮🇷")
        } else if let fr {
            return (language: fr, flag: "🇫🇷")
        } else if let it {
            return (language: it, flag: "🇮🇹")
        } else if let jp {
            return (language: jp, flag: "🇯🇵")
        } else if let jpRo {
            return (language: jpRo, flag: "🇯🇵")
        } else if let ko {
            return (language: ko, flag: "🇰🇷")
        } else if let mn {
            return (language: mn, flag: "🇲🇳")
        } else if let ms {
            return (language: ms, flag: "🇲🇾")
        } else if let nl {
            return (language: nl, flag: "🇳🇱")
        } else if let ru {
            return (language: ru, flag: "🇷🇺")
        } else if let th {
            return (language: th, flag: "🇹🇭")
        } else if let uk {
            return (language: uk, flag: "🇺🇦")
        } else if let zh {
            return (language: zh, flag: "🇨🇳")
        } else if let zhRo {
            return (language: zhRo, flag: "🇨🇳")
        }
        
        return nil
    }
    
    var languageInfo: (language: String, flag: String)? {
        if let info = _languageInfo {
            return (language: info.language.trimmingCharacters(in: .whitespacesAndNewlines), flag: info.flag)
        }
        return nil
    }
}
