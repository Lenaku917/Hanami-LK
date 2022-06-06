//
//  Publisher.swift
//  Smuggler
//
//  Created by mk.pwnz on 27/05/2022.
//

import Foundation
import Combine

extension Publisher {
    func debugDecode<Item: Decodable>(type: Item.Type, decoder: JSONDecoder = JSONDecoder()) -> AnyPublisher<Output, Never> where Self.Output == Data {
        self
            .map { data in
                var isError = true

                do {
                    _ = try decoder.decode(type, from: data)
                    isError = false
                } catch let DecodingError.dataCorrupted(context) {
                    Swift.print(context)
                } catch let DecodingError.keyNotFound(key, context) {
                    Swift.print("Key '\(key)' not found:", context.debugDescription)
                    Swift.print("codingPath:", context.codingPath)
                } catch let DecodingError.valueNotFound(value, context) {
                    Swift.print("Value '\(value)' not found:", context.debugDescription)
                    Swift.print("codingPath:", context.codingPath)
                } catch let DecodingError.typeMismatch(type, context) {
                    Swift.print("Type '\(type)' mismatch:", context.debugDescription)
                    Swift.print("codingPath:", context.codingPath)
                } catch {
                    Swift.print("error: ", error)
                }

                if isError {
                    // swiftlint:disable:next force_unwrapping
                    Swift.print(String(data: data, encoding: .utf8)!)
                }

                return data
            }
            .catch { _ in Empty() }
            .eraseToAnyPublisher()
    }
}
