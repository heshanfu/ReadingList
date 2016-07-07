//
//  SearchResultsViewController.swift
//  books
//
//  Created by Andrew Bennet on 29/11/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import UIKit
import SwiftyJSON

class SearchByIsbn: UIViewController {
 
    @IBOutlet weak var spinner: UIActivityIndicatorView!
    
    /// This must be populated by any controller segueing to this one
    var isbn13: String!
    var foundMetadata: BookMetadata?
    
    override func viewDidLoad() {
        spinner.startAnimating()
        
        // We've found an ISBN-13. Let's search for it online.
        OnlineBookClient<GoogleBooksParser>.TryGetBookMetadata(GoogleBooksRequest.GetIsbn(isbn13).url, completionHandler: searchCompletionHandler)
    }
    
    func searchCompletionHandler(metadata: BookMetadata?) {
        if let metadata = metadata {
            foundMetadata = metadata
            spinner.stopAnimating()
            self.performSegueWithIdentifier("showIsbnSearchResultSegue", sender: self)
        }
        else {
            PresentNoResultsAlert()
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "showIsbnSearchResultSegue" {
            let createReadStateController = segue.destinationViewController as! CreateReadState
            createReadStateController.bookMetadata = foundMetadata
        }
    }
    
    /// Presents a popup alerting the use to the fact that there were no results.
    func PresentNoResultsAlert() {
        let alert = UIAlertController(title: "No Results", message: "No matching books found online.", preferredStyle: UIAlertControllerStyle.Alert)
            alert.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: { _ in
                self.spinner.stopAnimating()
                self.dismissViewControllerAnimated(true, completion: nil)
        }))
        self.presentViewController(alert, animated: true, completion: nil)
    }
}