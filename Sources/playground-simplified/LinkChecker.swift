//
//  LinkChecker.swift
//  CommonMark
//
//  Created by Chris Eidhof on 11.04.19.
//

import Foundation

struct LinkCheckResult {
    var link: String
    var payload: Payload
    enum Payload {
        case success
        case invalidURL(message: String)
        case wrongStatusCode(statusCode: Int, error: Error?)
        case other(message: String)
    }
}

/// The callback is called once for every unique URL.
func linkChecker(_ links: [String], _ callback: @escaping (LinkCheckResult) -> (), _ done: @escaping () -> ()) {
    
    let realURLs: [URL] = links.compactMap { l in
        let res: (LinkCheckResult.Payload) -> LinkCheckResult = {
            LinkCheckResult(link: l, payload: $0)
        }
        guard let u = URL(string: l) else {
            callback(res(.invalidURL(message: "Can't parse URL")))
            return nil
        }
        guard let comps = URLComponents(url: u, resolvingAgainstBaseURL: false) else {
            callback(res(.invalidURL(message: "Can't get URL components")))
            return nil
        }
        guard comps.scheme != nil else {
            callback(res(.other(message: "Local link (TODO)"))) // todo)
            return nil
        }
        return u
    }
    let remainingLinks = Atomic<Set<URL>>(Set(realURLs))
    
    for url in remainingLinks.value {
        var request = URLRequest(url: url, timeoutInterval: 3)
        request.httpMethod = "HEAD"
        URLSession.shared.dataTask(with: request, completionHandler: { data, response, err in
            remainingLinks.mutate {
                $0.remove(url)
                print("\($0) links remaining")
            }
            let c = { payload in
                DispatchQueue.main.async {
                    callback(LinkCheckResult(link: url.absoluteString, payload: payload))
                }
            }
            let httpResponse = response as? HTTPURLResponse
            if httpResponse?.statusCode == 200 {
                c(.success)
            } else if let code = httpResponse?.statusCode {
                c(.wrongStatusCode(statusCode: code, error: err))
            } else {
                c(.other(message: err?.localizedDescription ?? "Unknown error"))
            }
            if remainingLinks.value.isEmpty {
                done()
            }
        }).resume()
    }
}
