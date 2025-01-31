//
//  HomeViewModel.swift
//  Pokemondex
//
//  Created by Rin on 2021/09/19.
//

import Foundation
import RxCocoa
import RxSwift
import RxDataSources

//MARK: - Rxに変えたい
protocol HomeViewModelDelegate: AnyObject ,ApiAlertProtocol, HudProtocol {
    func showFailAPICallAlert(title: String, message: String)
    func stopHud()
    func showHud()
}

protocol ApiAlertProtocol {
    func showFailAPICallAlert(title: String, message: String)
}

protocol HudProtocol {
    func stopHud()
    func showHud()
}

final class HomeViewModel {
    //MARK: - Propaties
    let items = BehaviorRelay<[PokemonDexCollectionModel]>(value: [])
    private var itemObserbable: Observable<[PokemonDexCollectionModel]> {
        return items.asObservable()
    }

    private weak var homeViewController: HomeViewModelDelegate?

    //let isHudShown: Observable<Bool>
    init(viewController: HomeViewModelDelegate) {
        homeViewController = viewController
    }

    //MARK: - Methods
    func setup() {
        Task {
            do {
                homeViewController?.showHud()
                let pokemons = try await fetchPokemonsData()
                updateItems(pokemons: pokemons)
                homeViewController?.stopHud()
            } catch let error as APICallError {
                homeViewController?.showFailAPICallAlert(title: error.title, message: error.message)
                homeViewController?.stopHud()
            }
        }
    }

    private func updateItems(pokemons: [Pokemon]) {
        var sections: [PokemonDexCollectionModel] = []
        let pokemonItems = pokemons.map { PokemonInfoItem.specificPokeomnInfo(pokemon: $0) }
        let pokemonInfoSection = PokemonDexCollectionModel(model: .pokemonsInfo, items: pokemonItems)
        sections.append(pokemonInfoSection)
        items.accept(sections)
    }

    private func fetchPokemonsData() async throws -> [Pokemon] {
        let pokemonIdRange = 1...151
        var pokemons = [Pokemon]()
        do {
            try await withThrowingTaskGroup(of: (Data, URLResponse).self) { group in
                for id in pokemonIdRange {
                    group.addTask {
                        // guard let url = URL(string: "https://pokeapi.co/api/v2/pokemon/\(id)/") else { fatalError() }
                        //let url = URL(string: "https://pokeapi.co/api/v2/pokemon/\(id)/")!
                        guard let url = URL(string: "https://pokeapi.co/api/v2/pokemon/\(id)/") else { throw APICallError.unconvertibleToURL }
                        return try await URLSession.shared.data(from: url)
                    }
                }

                for try await (fetchedData, _) in group {
                    let pokemon = try JSONDecoder().decode(Pokemon.self, from: fetchedData)
                    pokemons.append(pokemon)
                    pokemons.sort(by: { $0.id < $1.id } )
                }
            }
        } catch {
            print("failToFetchData")
            throw APICallError.failToFetchData
        }
        return pokemons
   }
}
