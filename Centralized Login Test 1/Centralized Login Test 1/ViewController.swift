//
//  ViewController.swift
//  Centralized Login Test 1
//
//  Created by Sebastián Peyrott on 11/6/17.
//  Copyright © 2017 Sebastián Peyrott. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var label: UILabel!
    @IBOutlet weak var button: UIButton!
    @IBOutlet weak var sfAuthSessionSwitch: UISwitch!
    
    @objc func applicationDidBecomeActive(_ notification: NSNotification) {
        checkState()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive(_:)),
            name: NSNotification.Name.UIApplicationDidBecomeActive,
            object: nil)
        
        updateUI()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func buttonClick(_ sender: Any) {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        if appDelegate.tokens == nil {
            appDelegate.authServer.authorize(useSfAuthSession: sfAuthSessionSwitch.isOn, handler: { (success) in
                if !success {
                    //TODO: show error
                    self.updateUI()
                }
                if self.sfAuthSessionSwitch.isOn {
                    self.checkState()
                }
            })
        } else {
            appDelegate.logout()
            updateUI()
        }
    }
    
    func updateUI() {
        DispatchQueue.main.async {
            let appDelegate = UIApplication.shared.delegate as! AppDelegate
            
            if appDelegate.tokens == nil {
                if appDelegate.authServer.receivedCode == nil {
                    self.label.text = "Logged-out"
                } else {
                    self.label.text = "Finishing login..."
                }
                self.button?.setTitle("Login", for: UIControlState.normal)
                self.sfAuthSessionSwitch?.isEnabled = true;
            } else {
                if appDelegate.profile?.name == nil {
                    self.label.text = "Hello, you are logged-in"
                } else {
                    self.label.text = "Hello, " + appDelegate.profile!.name! + ", you are logged-in"
                }
                self.button.setTitle("Logout", for: UIControlState.normal)
                self.sfAuthSessionSwitch.isEnabled = false;
            }
        }
    }
    
    private func checkState() {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        
        if appDelegate.authServer.receivedCode != nil && appDelegate.authServer.receivedState != nil {
            appDelegate.authServer.getToken() { (tokens) in
                appDelegate.tokens = tokens
                if tokens != nil {
                    appDelegate.authServer.getProfile(accessToken: tokens!.accessToken, handler: { (profile) in
                        appDelegate.profile = profile
                        self.updateUI()
                    })
                } else {
                    // TODO: error getting token
                    appDelegate.logout()
                }
                self.updateUI()
            }
        }
    }
}

