//
//  AppError.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation

enum AppError: Error {
    case downloadError(URLError)
    case decodingError(DecodingError)
    case unknownError(Error)
    case notFound
    case databaseError(String)
}

extension AppError: Equatable {
    static func == (lhs: AppError, rhs: AppError) -> Bool {
        switch (lhs, rhs) {
            case (.downloadError, .downloadError):
                return true
                
            case (.notFound, .notFound):
                return true
                
            case (.decodingError, .decodingError):
                return true
                
            case (.unknownError, .unknownError):
                return true
                
            case (.databaseError, .databaseError):
                return true
                
            default:
                return false
        }
    }
    
    var description: String {
        switch self {
            case .downloadError:
                return "Failed to fetch data. Check your internet connection or try again later."
            case .decodingError:
                return "Internal error on data decoding."
            case .unknownError(let err):
                return "Something strange happened \n\(err.localizedDescription)"
            case .notFound:
                return "Requested item was not found"
            case .databaseError(let errorStr):
                return errorStr
        }
    }
}
