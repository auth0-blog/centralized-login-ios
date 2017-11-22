//
//  AuthorizationServer.swift
//  Centralized Login Test 1
//
//  Created by Sebastián Peyrott on 11/7/17.
//  Copyright © 2017 Sebastián Peyrott. All rights reserved.
//

import Foundation
import SafariServices

let domain = "https://speyrott.auth0.com"
let clientId = "iV2lnrgSBw64uzf1x0MN3svQTYQYcBl2"

struct Tokens {
    var accessToken: String
    var idToken: String?
    var refreshToken: String?
}

struct Profile {
    var name: String?
    var email: String?
}

func base64UrlEncode(_ data: Data) -> String {
    var b64 = data.base64EncodedString()
    b64 = b64.replacingOccurrences(of: "=", with: "")
    b64 = b64.replacingOccurrences(of: "+", with: "-")
    b64 = b64.replacingOccurrences(of: "/", with: "_")
    return b64
}

func generateRandomBytes() -> String? {
    var keyData = Data(count: 32)
    let result = keyData.withUnsafeMutableBytes {
        (mutableBytes: UnsafeMutablePointer<UInt8>) -> Int32 in
        SecRandomCopyBytes(kSecRandomDefault, keyData.count, mutableBytes)
    }
    if result == errSecSuccess {
        return base64UrlEncode(keyData)
    } else {
        // TODO: handle error
        return nil
    }
}

func sha256(string: String) -> Data {
    let messageData = string.data(using:String.Encoding.utf8)!
    var digestData = Data(count: Int(CC_SHA256_DIGEST_LENGTH))
    
    _ = digestData.withUnsafeMutableBytes {digestBytes in
        messageData.withUnsafeBytes {messageBytes in
            CC_SHA256(messageBytes, CC_LONG(messageData.count), digestBytes)
        }
    }
    return digestData
}

class AuthorizationServer {
    private var codeVerifier: String? = nil
    private var savedState: String? = nil
    
    var receivedCode: String? = nil
    var receivedState: String? = nil
    
    private var sfAuthSession: SFAuthenticationSession? = nil
    private var sfSafariViewController: SFSafariViewController? = nil
    
    func authorize(viewController: UIViewController, useSfAuthSession: Bool, handler: @escaping (Bool) -> Void) {
        guard let challenge = generateCodeChallenge() else {
            // TODO: handle error
            handler(false)
            return
        }
    
        savedState = generateRandomBytes()
        
        var urlComp = URLComponents(string: domain + "/authorize")!
    
        urlComp.queryItems = [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: savedState),
            URLQueryItem(name: "scope", value: "id_token profile"),
            URLQueryItem(name: "redirect_uri", value: "auth0test1://test"),
        ]
        
        if useSfAuthSession {
            sfAuthSession = SFAuthenticationSession(url: urlComp.url!, callbackURLScheme: "auth0test1", completionHandler: { (url, error) in
                guard error == nil else {
                    return handler(false)
                }
                
                handler(url != nil && self.parseAuthorizeRedirectUrl(url: url!))
            })
            sfAuthSession?.start()
        } else {
            sfSafariViewController = SFSafariViewController(url: urlComp.url!)
            viewController.present(sfSafariViewController!, animated: true)
            handler(true)
        }
    }
    
    func parseAuthorizeRedirectUrl(url: URL) -> Bool {
        guard let urlComp = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            sfSafariViewController?.dismiss(animated: true, completion: nil)
            return false
        }
        
        if urlComp.queryItems == nil {
            sfSafariViewController?.dismiss(animated: true, completion: nil)
            return false
        }
        
        for item in urlComp.queryItems! {
            if item.name == "code" {
                receivedCode = item.value
            } else if item.name == "state" {
                receivedState = item.value
            }
        }
        
        sfSafariViewController?.dismiss(animated: true, completion: nil)
        
        return receivedCode != nil && receivedState != nil
    }
    
    func getToken(handler: @escaping (Tokens?) -> Void) {
        if receivedCode == nil || codeVerifier == nil || savedState != receivedState {
            handler(nil)
            return
        }
        
        let urlComp = URLComponents(string: domain + "/oauth/token")!
        
        let body = [
            "grant_type": "authorization_code",
            "client_id": clientId,
            "code": receivedCode,
            "code_verifier": codeVerifier,
            "redirect_uri": "auth0test1://test",
        ]
        
        var request = URLRequest(url: urlComp.url!)
        request.httpMethod = "POST"
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let task = URLSession.shared.dataTask(with: request) {
            (data, response, error) in
            if(error != nil || data == nil) {
                // TODO: handle error
                handler(nil)
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data!) as? [String: Any],
                  let accessToken = json!["access_token"] as? String
            else {
                handler(nil)
                return
            }
            
            handler(Tokens(accessToken: accessToken,
                           idToken: json!["id_token"] as? String,
                           refreshToken: json!["refresh_token"] as? String))
        }
        
        task.resume()
    }
    
    func getProfile(accessToken: String, handler: @escaping (Profile?) -> Void) {
        let urlComp = URLComponents(string: domain + "/userinfo")!
        
        let urlSessionConfig = URLSessionConfiguration.default;
        urlSessionConfig.httpAdditionalHeaders = [
            AnyHashable("Authorization"): "Bearer " + accessToken
        ]
        let urlSession = URLSession(configuration: urlSessionConfig)
        let task = urlSession.dataTask(with: urlComp.url!) {
            (data, response, error) in
            if(error != nil || data == nil) {
                // TODO: handle error
                handler(nil)
                return
            }
            
            guard let json = try? JSONSerialization.jsonObject(with: data!) as? [String: String] else {
                handler(nil)
                // TODO: handle error
                return
            }

            let result = Profile(name: json?["name"], email: json?["email"])
            handler(result)
        }
        
        task.resume()
    }
    
    func reset() {
        codeVerifier = nil
        savedState = nil
        receivedCode = nil
        receivedState = nil
        sfAuthSession = nil
    }
    
    private func generateCodeChallenge() -> String? {
        codeVerifier = generateRandomBytes()
        guard codeVerifier != nil else {
            return nil
        }
        return base64UrlEncode(sha256(string: codeVerifier!))
    }
    
}
