//
//  ViewController.swift
//  Centralized Login Test 2
//
//  Created by Sebastián Peyrott on 11/14/17.
//  Copyright © 2017 Sebastián Peyrott. All rights reserved.
//

import UIKit
import Auth0

let domain = "https://speyrott.auth0.com"
let clientId = "LTx5ETNYJD0kLv2wB5ogQQuR6rLUIIXc"

class ViewController: UIViewController {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    
    var profile: Auth0.UserInfo? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buttonClicked(_ sender: Any) {
        if profile != nil {
            profile = nil
            updateUI()
        } else {
            Auth0
                .webAuth(clientId: clientId, domain: domain)
                .scope("openid token profile")
                .start { result in
                    
                    switch result {
                    
                    case .success(let credentials):
                        Auth0
                            .authentication(clientId: clientId, domain: domain)
                            .userInfo(withAccessToken: credentials.accessToken!)
                            .start { result in
                    
                                switch result {
                                
                                case .success(let profile):
                                    self.profile = profile
                                
                                case .failure(let error):
                                    print("Failed with \(error)")
                                    self.profile = nil
                                }
                                
                                self.updateUI()
                        }
                    
                    case .failure(let error):
                        self.profile = nil
                        print("Failed with \(error)")
                    }
                    
                    self.updateUI()
            }
        }
    }
    
    func updateUI() {
        DispatchQueue.main.async {
            if self.profile != nil {
                self.label.text = "Hello, \(self.profile!.name ?? "user with no name"), you are logged in"
                self.button.setTitle("Logout", for: UIControlState.normal)
            } else {
                self.label.text = "Logged-out"
                self.button.setTitle("Login", for: UIControlState.normal)
            }
        }
    }
    
}

