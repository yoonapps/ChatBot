//
//  TripAPI.swift
//  Flights
//
//  Created by Yoon, Kyle on 2/12/16.
//  Copyright © 2016 Kyle Yoon. All rights reserved.
//

import Foundation
import QPXExpressWrapper
import Alamofire
import Gloss

typealias TripAPISuccessCompletion = (SearchResults) -> Void
typealias TripAPIFailureCompletion = ((Error) -> Void)?
typealias MessageResponseSuccessCompletion = (MessageResponse) -> ()

class APIUtility {
    static let shared = APIUtility()
    
    // MARK: - QPXExpress

    let baseURL = "https://www.googleapis.com/qpxExpress/v1/trips/search"
    let maxSolutions = 3
    
    func searchTripsWithRequest(tripRequest: TripRequest,
                                success: @escaping TripAPISuccessCompletion,
                                failure: TripAPIFailureCompletion) {
        guard var tripsURLComponents = URLComponents(string: baseURL) else {
            return
        }
        
        let keyQueryItem = URLQueryItem(name: "key", value: APIKey)
        tripsURLComponents.queryItems = [keyQueryItem]
        
        guard let tripsURL = tripsURLComponents.url, let json = tripRequest.toJSON() else {
            return
        }
        
        Alamofire
            .request(tripsURL.absoluteString,
                     method: .post,
                     parameters: json,
                     encoding: JSONEncoding.default,
                     headers: ["Content-Type": "application/json"])
            .responseJSON {
                response in
                if
                    let result = response.result.value as? JSON,
                    let tripSearchResult = SearchResults(json: result) {
                    success(tripSearchResult)
                }
                else {
                    if
                        let error = response.error,
                        let failure = failure {
                        failure(error)
                    }
                }
        }
    }
    
    // MARK: - Watson

    let conversationURL = "https://gateway.watsonplatform.net/conversation/api/v1/workspaces/"
    let versionParameter = "version=2017-02-03"
    var workspaceIdentifier: String?
    
    func queryWorkspaceIdentifier(success: (() -> ())?, failure: (() -> ())?) {
        Alamofire.request(conversationURL + "?" + versionParameter)
            .authenticate(user: username, password: password)
            .responseJSON {
                [weak self]
                response in
                if
                    let json = response.result.value as? [String: Any],
                    let workspaces = json["workspaces"] as? [[String: Any]],
                    let workspaceIdentifier = workspaces.first?["workspace_id"] as? String {
                    self?.workspaceIdentifier = workspaceIdentifier
                    if let success = success {
                        success()
                    }
                }
                else {
                    if let failure = failure {
                        failure()
                    }
                }
        }
    }
    
    func sendMessage(message: String,
                     withPreviousContext context: RuntimeContext?,
                     customContext: [String: Any]? = nil,
                     success: @escaping MessageResponseSuccessCompletion,
                     failure: ((Error?) -> ())?) {
        guard let workspaceIdentifier = workspaceIdentifier else {
            return
        }
        
        let input = ["text": message]
        var json: [String: Any] = ["input": input]
        
        if let context = context {
            json["context"] = context.toJSON()
        }
        
        if
            let customContext = customContext,
            var jsonContext = json["context"] as? JSON {
            customContext.forEach({ key, value in
                jsonContext[key] = value
            })
            json["context"] = jsonContext
        }
        
        Alamofire
            .request(conversationURL + "\(workspaceIdentifier)/message?" + versionParameter,
                     method: .post,
                     parameters: json,
                     encoding: JSONEncoding.default,
                     headers: ["Content-Type": "application/json"])
            .authenticate(user: username, password: password)
            .responseJSON {
                json in
                if
                    let json = json.result.value as? [String: Any],
                    let messageResponse = MessageResponse(json: json) {
                    success(messageResponse)
                }
                else {
                    if let failure = failure {
                        failure(json.error)
                    }
                }
        }
    }
    
    func getNearbyAirports(latitude: Double,
                           longitude: Double, 
                           success: @escaping ([String]) -> (),
                           failure: @escaping (Error?) -> ()) {
        let placesURL = "https://maps.googleapis.com/maps/api/place/nearbysearch/json?key=\(GooglePlacesSearchAPIKey)&location=\(latitude),\(longitude)&radius=35000&type=airport"
        Alamofire.request(placesURL,
                          method: .post,
                          encoding: JSONEncoding.default,
                          headers: ["Content-Type": "application/json"])
            .responseJSON { response in
                guard
                    let value = response.result.value as? JSON,
                    let results = value["results"] as? [JSON] else {
                    failure(response.error)
                    return
                }
                var names = [String]()
                for airportDict in results {
                    if let name = airportDict["name"] as? String {
                        names.append(name)
                    }
                }
                success(names)
        }
    }
}
