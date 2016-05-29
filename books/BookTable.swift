//
//  BookTableViewController.swift
//  books
//
//  Created by Andrew Bennet on 09/11/2015.
//  Copyright © 2015 Andrew Bennet. All rights reserved.
//

import UIKit
import DZNEmptyDataSet
import CoreData
import CoreSpotlight

enum TableSegmentOption: Int {
    case ToRead = 0
    case Finished = 1
    
    var toReadStates: [BookReadState] {
        return self == .ToRead ? [.ToRead, .Reading] : [.Finished]
    }
    
    static func fromReadState(state: BookReadState) -> TableSegmentOption{
        return state == .Finished ? .Finished : .ToRead
    }
}

class BookTable: SearchableFetchedResultsTable {

    @IBOutlet weak var segmentControl: UISegmentedControl!

    /// The currently selected segment
    var selectedSegment: TableSegmentOption! {
        didSet {
            // Update the selected segment index. This may have already been done, but never mind.
            segmentControl.selectedSegmentIndex = selectedSegment.rawValue
            
            // Load the data if we have changed segement and the previously stored scroll position
            if selectedSegment != oldValue {
                updatePredicate(ReadStateFilter(states: selectedSegment.toReadStates).ToPredicate())
            }
        }
    }
    
    /// The stored scroll positions to allow our single table to function like two tables
    var tableViewScrollPositions: [TableSegmentOption: CGPoint]?
    
    override func viewDidLoad() {
        resultsController = appDelegate.booksStore.FetchedBooksController()
        cellIdentifier = String(BookTableViewCell)

        // Set the DZN data set source
        tableView.emptyDataSetSource = self
        
        // Select the ToRead tab
        selectedSegment = .ToRead
        
        super.viewDidLoad()
    }
    
    override func viewDidAppear(animated: Bool) {
        // If we haven't initialised the scroll positions dictionary, do so now, for all
        // tabs, with the current scroll position (which will be the starting position).
        if tableViewScrollPositions == nil {
            tableViewScrollPositions = [.ToRead: tableView.contentOffset, .Finished: tableView.contentOffset]
        }
        
        super.viewDidAppear(animated)
    }

    override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if selectedSegment == .Finished {
            // We don't need a section title for this segment
            return nil
        }
        
        // Otherwise, turn the section name into a BookReadState and use its description property
        let sectionAsInt = Int32(self.resultsController.sections![section].name)!
        return BookReadState(rawValue: sectionAsInt)!.description
    }
    
    override func configureCell(cell: UITableViewCell, fromObject object: AnyObject) {
        (cell as! BookTableViewCell).configureFromBook(object as? Book)
    }
    
    override func tableView(tableView: UITableView, editActionsForRowAtIndexPath indexPath: NSIndexPath) -> [UITableViewRowAction]? {
        
        // For safety check that there is a Book here
        guard let selectedBook = self.resultsController.objectAtIndexPath(indexPath) as? Book else { return nil }
        
        let delete = UITableViewRowAction(style: .Destructive, title: "Delete") { _, index in
            // If there is a book at this index, delete it
            appDelegate.booksStore.DeleteBookAndDeindex(selectedBook)
            
            // If it is being displayed, clear it
            if let bookDetails = appDelegate.splitViewController.bookDetailsControllerIfSplit where bookDetails.book == selectedBook {
                bookDetails.ClearUI()
            }
        }
        delete.backgroundColor = UIColor.redColor()
        return [delete]
    }
    
    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // All cells are "editable"; just for safety check that there is a Book there
        return self.resultsController.objectAtIndexPath(indexPath) is Book
    }
    
    override func restoreUserActivityState(activity: NSUserActivity) {
        // Check that the user activity corresponds to a book which we have a row for
        guard let identifier = activity.userInfo?[CSSearchableItemActivityIdentifier] as? String,
            identifierUrl = NSURL(string: identifier),
            selectedBook = appDelegate.booksStore.GetBook(identifierUrl),
            indexPathOfSelectedBook = resultsController.indexPathForObject(selectedBook) else { return }
            
        // Dismiss any modal controllers (e.g. Add)
        self.dismissViewControllerAnimated(false, completion: nil)
        
        // Update the selected segment, which will reload the table
        selectedSegment = TableSegmentOption.fromReadState(selectedBook.readState)
                
        // Select that row and scroll it in to view.
        self.tableView.scrollToRowAtIndexPath(indexPathOfSelectedBook, atScrollPosition: .None, animated: false)
        self.tableView.selectRowAtIndexPath(indexPathOfSelectedBook, animated: false, scrollPosition: .None)
                
        // Check whether the BookDetails controller is already displayed
        if let bookDetails = appDelegate.splitViewController.detailNavigationController?.topViewController as? BookDetails {
            // Dismiss any modal controllers (e.g. Edit)
            bookDetails.dismissViewControllerAnimated(false, completion: nil)
            
            // Update the displayed book
            bookDetails.book = selectedBook
            bookDetails.UpdateUi()
        }
        else {
            // Otherwise, segue to the details view
            performSegueWithIdentifier("showDetail", sender: selectedBook)
        }
    }
    
    @IBAction func selectedSegmentChanged(sender: AnyObject) {
        // Store the scroll position for the old read state
        tableViewScrollPositions![selectedSegment] = tableView.contentOffset
        
        // If we have a position in the dictionary for the new segment state, scroll to that
        let newSegment = TableSegmentOption(rawValue: segmentControl.selectedSegmentIndex)!
        if let newPosition = tableViewScrollPositions![newSegment] {
            tableView.setContentOffset(newPosition, animated: false)
        }
        
        // Update the read state to the selected read state
        selectedSegment = newSegment
        
        // If there is a Book currently displaying on the split Detail view, select the corresponding row if possible
        if let currentlyShowingBook = appDelegate.splitViewController.bookDetailsControllerIfSplit?.book
            where selectedSegment.toReadStates.contains(currentlyShowingBook.readState) {
            tableView.selectRowAtIndexPath(self.resultsController.indexPathForObject(currentlyShowingBook), animated: false, scrollPosition: .None)
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if segue.identifier == "addBook" {
            (segue.destinationViewController as! NavWithReadState).readState = selectedSegment.toReadStates.first
        }
        else if segue.identifier == "showDetail" {
            let destinationViewController = (segue.destinationViewController as! UINavigationController).topViewController as! BookDetails

            // The sender is a Book if we are restoring state
            if let bookSender = sender as? Book {
                destinationViewController.book = bookSender
            }
            else if let cellSender = sender as? UITableViewCell,
                selectedIndex = self.tableView.indexPathForCell(cellSender) {
                destinationViewController.book = self.resultsController.objectAtIndexPath(selectedIndex) as? Book
            }
        }
    }
    
    override func predicateForSearchText(searchText: String?) -> NSPredicate? {
        // AND the read state predicate and the Title filter
        let readStatePredicate = ReadStateFilter(states: selectedSegment.toReadStates).ToPredicate()
        return NSCompoundPredicate(andPredicateWithSubpredicates: [readStatePredicate, TitleFilter(comparison: .Contains, text: searchText!).ToPredicate()])
    }    
}


/**
 Functions controlling the DZNEmptyDataSet.
 */
extension BookTable : DZNEmptyDataSetSource {
    
    private func IsShowingSearchResults() -> Bool {
        return searchController.active && searchController.searchBar.text?.isEmpty == false
    }
    
    func imageForEmptyDataSet(scrollView: UIScrollView!) -> UIImage! {
        if IsShowingSearchResults() {
            return UIImage(named: "fa-search")
        }
        return UIImage(named: "fa-book")
    }
    
    func titleForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        let attrs = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleHeadline)]
        if IsShowingSearchResults() {
            return NSAttributedString(string: "No results", attributes: attrs)
        }
        switch self.selectedSegment! {
        case .ToRead:
            return NSAttributedString(string: "You are not reading any books!", attributes: attrs)
        case .Finished:
            return NSAttributedString(string: "You haven't yet finished a book. Get going!", attributes: attrs)
        }
    }
    
    func descriptionForEmptyDataSet(scrollView: UIScrollView!) -> NSAttributedString! {
        let attrs = [NSFontAttributeName: UIFont.preferredFontForTextStyle(UIFontTextStyleBody)]
        if IsShowingSearchResults() {
            return NSAttributedString(string: "Try changing your search.", attributes: attrs)
        }
        return NSAttributedString(string: "Add a book by clicking the + button above.", attributes: attrs)
    }
}
