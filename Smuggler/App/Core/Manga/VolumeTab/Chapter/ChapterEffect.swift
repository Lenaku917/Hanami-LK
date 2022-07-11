//
//  ChapterEffect.swift
//  Smuggler
//
//  Created by mk.pwnz on 22/05/2022.
//

import Foundation
import ComposableArchitecture

// Example for URL https://api.mangadex.org/chapter/a33906f0-1928-4758-b6fc-f7f079e2dee2
func downloadChapterInfo(chapterID: UUID) -> Effect<Response<ChapterDetails>, AppError> {
    var components = URLComponents()
    
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/chapter/\(chapterID.uuidString.lowercased())"
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<ChapterDetails>.self, decoder: AppUtil.decoder)
        .mapError { err -> AppError in
            if let err = err as? URLError {
                return AppError.downloadError(err)
            } else if let err = err as? DecodingError {
                return AppError.decodingError(err)
            }
            
            return AppError.unknownError(err)
        }
        .eraseToEffect()
}

func fetchScanlationGroupInfo(scanlationGroupID: UUID) -> Effect<Response<ScanlationGroup>, AppError> {
    var components = URLComponents()
    
    components.scheme = "https"
    components.host = "api.mangadex.org"
    components.path = "/group/\(scanlationGroupID.uuidString.lowercased())"
    
    guard let url = components.url else {
        fatalError("Error on creating URL")
    }
    
    return URLSession.shared.dataTaskPublisher(for: url)
        .validateResponseCode()
        .retry(3)
        .map(\.data)
        .decode(type: Response<ScanlationGroup>.self, decoder: AppUtil.decoder)
        .mapError { err -> AppError in
            if let err = err as? URLError {
                return AppError.downloadError(err)
            } else if let err = err as? DecodingError {
                return AppError.decodingError(err)
            }
            
            return AppError.unknownError(err)
        }
        .eraseToEffect()
}
