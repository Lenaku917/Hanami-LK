//
//  Encodable.swift
//  Hanami
//
//  Created by Oleg on 03/07/2022.
//

import Foundation

extension Encodable {
    func toData(encoder: JSONEncoder = AppUtil.encoder) -> Data? {
        try? encoder.encode(self)
    }
}
