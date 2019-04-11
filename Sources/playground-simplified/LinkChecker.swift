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
        case invalidLocalLink
        case wrongStatusCode(statusCode: Int, error: Error?)
        case other(message: String)
    }
}

/// The callback is called once for every unique URL.
func linkChecker(_ links: [String], availableLocalLinks: [String], _ callback: @escaping (LinkCheckResult) -> (), _ done: @escaping () -> ()) {
    
    let realURLs: [URL] = links.compactMap { l in
        let res: (LinkCheckResult.Payload) -> LinkCheckResult = {
            LinkCheckResult(link: l, payload: $0)
        }
        if l.hasPrefix("#") {
            let linkName = String(l.dropFirst())
            if availableLocalLinks.contains(linkName) {
                callback(res(.success))
            } else {
                callback(res(.invalidLocalLink))
            }
            return nil
        }
        guard let u = URL(string: l) else {
            callback(res(.invalidURL(message: "Can't parse URL")))
            return nil
        }
        guard let comps = URLComponents(url: u, resolvingAgainstBaseURL: false) else {
            callback(res(.invalidURL(message: "Can't get URL components")))
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
                DispatchQueue.main.async {
                    done()
                }
            }
        }).resume()
    }
}

extension String {
    fileprivate func linkAnchor() -> String? {
        if let curlyIdx = self.firstIndex(of: "{") {
            let start = self[curlyIdx...]
            if start.hasPrefix("{#"), let end = start.firstIndex(of: "}") {
                return String(start.dropFirst(2)[..<end])
            }
        }
        return nil
    }
}
import CommonMark
extension Node {
    // todo include position as well
    func localLinks() -> [String] {
        var algebra: BlockAlgebra<[String]> = collect()
        algebra.inline.text = { t in
            t.linkAnchor().map { [$0] } ?? []
        }
        return reduce(algebra)
    }
}
