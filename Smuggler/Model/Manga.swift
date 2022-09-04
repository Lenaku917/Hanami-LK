//
//  Manga.swift
//  Smuggler
//
//  Created by mk.pwnz on 13/05/2022.
//

import Foundation

// MARK: - Manga
struct Manga: Codable {
    let id: UUID
    let attributes: Attributes
    let relationships: [Relationship]
    
    var mangaFolderName: String {
        id.uuidString.lowercased()
    }
    
    // MARK: - Attributes
    struct Attributes: Codable {
        let title: LocalizedString
        let altTitles: LocalizedString
        let description: LocalizedString
        let isLocked: Bool
        let originalLanguage: String
        let status: Status
        let contentRating: ContentRatings
        let tags: [Tag]
        let state: State
        
        // MARK: all this @NullCodable's are for json encoding and storing them with CoreData.
        let createdAt: Date?
        let updatedAt: Date?
        let lastVolume: String?
        let lastChapter: String?
        let publicationDemographic: PublicationDemographic?
        let year: Int?
        
        enum CodingKeys: String, CodingKey {
            case title, altTitles
            case description, isLocked, originalLanguage, lastVolume, lastChapter, publicationDemographic, status
            case year, contentRating, tags, state, createdAt, updatedAt
        }
        
        enum Status: String, Codable {
            case completed, ongoing, cancelled, hiatus
        }
        
        enum PublicationDemographic: String, Codable {
            case shounen, shoujo, josei, seinen
        }
        
        enum ContentRatings: String, Codable {
            case safe, suggestive, erotica, pornographic
        }
        
        enum State: String, Codable {
            case draft, submitted, published, rejected
        }
    }
}

// MARK: - Custom init for fucked up MangaDex API
extension Manga.Attributes {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        title = try container.decode(LocalizedString.self, forKey: .title)
        do {
            altTitles = try container.decode(LocalizedString.self, forKey: .altTitles)
        } catch {
            let altTitlesDicts = try container.decode([LocalizedString].self, forKey: .altTitles)
            altTitles = LocalizedString(localizedStrings: altTitlesDicts)
        }
        do {
            description = try container.decode(LocalizedString.self, forKey: .description)
        } catch DecodingError.typeMismatch {
            let descriptions = try container.decode([LocalizedString].self, forKey: .description)
            description = LocalizedString(localizedStrings: descriptions)
        }
        isLocked = try container.decode(Bool.self, forKey: .isLocked)
        originalLanguage = try container.decode(String.self, forKey: .originalLanguage)
        lastVolume = try? container.decode(String?.self, forKey: .lastVolume)
        lastChapter = try? container.decode(String?.self, forKey: .lastChapter)
        publicationDemographic = try? container.decode(PublicationDemographic?.self, forKey: .publicationDemographic)
        status = try container.decode(Status.self, forKey: .status)
        year = try? container.decode(Int?.self, forKey: .year)
        contentRating = try container.decode(ContentRatings.self, forKey: .contentRating)
        tags = try container.decode([Tag].self, forKey: .tags)
        state = try container.decode(State.self, forKey: .state)
        
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss+00:00"
        createdAt = fmt.date(from: (try? container.decode(String.self, forKey: .createdAt)) ?? "")
        updatedAt = fmt.date(from: (try? container.decode(String.self, forKey: .updatedAt)) ?? "")
    }
}

extension Manga: Equatable {
    static func == (lhs: Manga, rhs: Manga) -> Bool {
        lhs.id == rhs.id
    }
}

extension Manga: Identifiable { }

extension Manga {
    var title: String {
        if attributes.title.availableLang != nil {
            return attributes.title.availableLang!
        } else {
            return attributes.altTitles.availableLang ?? "No title available"
        }
    }
    
    var description: String? {
        attributes.description.availableLang
    }
    
    var authors: [Author] {
        relationships
            .filter { $0.type == .author }
            .compactMap {
                guard let attrs = $0.attributes?.get() as? Author.Attributes else {
                    return nil
                }
                
                return Author(id: $0.id, attributes: attrs, relationships: [
                    Relationship(id: self.id, type: .manga)
                ])
            }
    }
    
    var coverArtInfo: CoverArtInfo? {
        if let relationship = relationships.first(where: { $0.type == .coverArt }),
           let attributes = relationship.attributes?.get() as? CoverArtInfo.Attributes {
            return CoverArtInfo(
                id: relationship.id, attributes: attributes, relationships: [
                    Relationship(id: self.id, type: .manga)
                ]
            )
        }
        
        return nil
    }
}
