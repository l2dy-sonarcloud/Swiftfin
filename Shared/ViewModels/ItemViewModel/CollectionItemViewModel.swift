//
// Swiftfin is subject to the terms of the Mozilla Public
// License, v2.0. If a copy of the MPL was not distributed with this
// file, you can obtain one at https://mozilla.org/MPL/2.0/.
//
// Copyright (c) 2025 Jellyfin & Jellyfin Contributors
//

import Combine
import Foundation
import JellyfinAPI
import OrderedCollections

final class CollectionItemViewModel: ItemViewModel {

    // MARK: - Published Collection Items

    @Published
    private(set) var collectionItems: OrderedDictionary<BaseItemKind, [BaseItemDto]> = [:]

    // MARK: - Task

    private var collectionItemTask: AnyCancellable?

    // MARK: - Disable PlayButton

    override var presentPlayButton: Bool {
        false
    }

    // MARK: - Override Response

    override func respond(to action: ItemViewModel.Action) -> ItemViewModel.State {

        switch action {
        case .refresh, .backgroundRefresh:
            collectionItemTask?.cancel()

            collectionItemTask = Task {
                let collectionItems = try await self.getCollectionItems()

                await MainActor.run {
                    self.collectionItems = collectionItems
                }
            }
            .asAnyCancellable()
        default: ()
        }

        return super.respond(to: action)
    }

    // MARK: - Get Collection Items

    private func getCollectionItems() async throws -> OrderedDictionary<BaseItemKind, [BaseItemDto]> {
        var parameters = Paths.GetItemsByUserIDParameters()
        parameters.fields = .MinimumFields
        parameters.includeItemTypes = BaseItemKind.supportedCases
            .appending(.episode)
        parameters.parentID = item.id

        let request = Paths.getItemsByUserID(
            userID: userSession.user.id,
            parameters: parameters
        )
        let response = try await userSession.client.send(request)

        let items = response.value.items ?? []

        let result = OrderedDictionary<BaseItemKind?, [BaseItemDto]>(
            grouping: items,
            by: \.type
        )
        .compactKeys()
        .sortedKeys { $0.rawValue < $1.rawValue }

        return result
    }
}
