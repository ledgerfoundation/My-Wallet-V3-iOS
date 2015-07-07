//
//  BackupViewController.swift
//  Blockchain
//
//  Created by Sjors Provoost on 19-05-15.
//  Copyright (c) 2015 Qkos Services Ltd. All rights reserved.
//

import UIKit

class BackupViewController: UIViewController {
    
    @IBOutlet weak var summaryLabel: UILabel?
    @IBOutlet weak var backupWalletButton: UIButton?
    @IBOutlet weak var explanation: UILabel?
    @IBOutlet weak var backupIconImageView: UIImageView?
    
    var wallet : Wallet?

    override func viewDidLoad() {
        super.viewDidLoad()
    
        backupWalletButton?.clipsToBounds = true
        backupWalletButton?.layer.cornerRadius = Constants.Measurements.BackupButtonCornerRadius
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        if wallet!.isRecoveryPhraseVerified() {
            summaryLabel!.text = NSLocalizedString("You backed up your wallet.", comment: "");
            explanation!.text = NSLocalizedString("You only need to backup your wallet once.", comment: "")
            backupIconImageView!.image = UIImage(named: "icon_backup_complete")
            backupWalletButton?.titleLabel?.text = NSLocalizedString("VERIFY BACKUP", comment: "");
        }
    }
    
    @IBAction func backupWalletButtonTapped(sender: UIButton) {
        if wallet!.isRecoveryPhraseVerified() {
            performSegueWithIdentifier("verifyBackup", sender: nil)
        } else {
            performSegueWithIdentifier("backupWords", sender: nil)
        }
    }
    
    @IBAction func backupWalletAgainButtonTapped(sender: UIButton) {
        performSegueWithIdentifier("backupWords", sender: nil)
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "backupWords" {
            let vc = segue.destinationViewController as! BackupWordsViewController
            vc.wallet = wallet
        }
        else if segue.identifier == "verifyBackup" {
            let vc = segue.destinationViewController as! BackupVerifyViewController
            vc.wallet = wallet
        }
    }
    
    @IBAction func unwindSecondPasswordCancel(segue: UIStoryboardSegue) {
    }
    
    @IBAction func unwindVerifyWords(segue: UIStoryboardSegue) {
    }
}