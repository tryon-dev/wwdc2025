import Foundation
import SwiftUI

struct Card: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var image: String
}

let cards: [Card] = [
    .init(image: "coda_poster"),
    .init(image: "foundation_poster"),
    .init(image: "severance_poster"),
    .init(image: "dontlookup_poster"),
    .init(image: "thegrayman_poster"),
    .init(image: "theirishman_poster"),
    .init(image: "thepaleblueeye_poster"),
    .init(image: "glassonion_poster"),
    .init(image: "birdbox_poster"),
    .init(image: "theadamproject_poster"),
    .init(image: "squidgame_poster"),
    .init(image: "strangerthings_poster"),
]
