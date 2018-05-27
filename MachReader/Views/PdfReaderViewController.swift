//
//  PdfReaderViewController.swift
//  MachReader
//
//  Created by ShuichiNagao on 2018/05/25.
//  Copyright © 2018 mach-technologies. All rights reserved.
//

import UIKit
import PDFKit

class PdfReaderViewController: UIViewController {

    // MARK: - Properties
    
    @IBOutlet private weak var pdfView: PDFView!
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        // This is supposed to block user interaction when loading...
        let indicator = UIActivityIndicatorView(activityIndicatorStyle: .gray)
        indicator.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        indicator.center = self.view.center
        indicator.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleBottomMargin]
        indicator.hidesWhenStopped = true
        return indicator
    }()
    
    private var book: Book! = nil {
        didSet {
            drawStoredHighlights()
            activityIndicator.stopAnimating()
        }
    }
    
    private var currentPageNumber: Int {
        let page = pdfView.currentPage
        return pdfView.document?.index(for: page!) ?? 0
    }
    
    // MARK: - Life cycle methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(activityIndicator)
        activityIndicator.startAnimating()
        
        NotificationObserver.add(name: .PDFViewAnnotationHit, method: handleHitAnnotation)
        NotificationObserver.add(name: .PDFViewPageChanged, method: handlePageChanged)
        
        setupDocument()
        setupPDFView()
        createMenu()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        NotificationObserver.removeAll(from: self)
    }
    
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if action == #selector(highlight(_:)) {
            return true
        } else if action == #selector(comment(_:)) {
            return true
        }
        return false
    }
    
    // MARK: - private methods
    
    /// PDF data handling for init
    private func setupDocument() {
        guard let path = Bundle.main.path(forResource: "sample", ofType: "pdf") else {
            print("failed to get path.")
            return
        }
        
        let pdfURL = URL(fileURLWithPath: path)
        let document = PDFDocument(url: pdfURL)
        pdfView.document = document
        
        let hashID = SHA1.hexString(fromFile: path) ?? ""
        Book.findOrCreate(by: hashID) { [weak self] book, error in
            self?.book = book
        }
    }
    
    /// Base settings for PDFView.
    private func setupPDFView() {
        pdfView.backgroundColor = .lightGray
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.usePageViewController(true)
    }

    /// Customize UIMenuController.
    private func createMenu() {
        let highlightItem = UIMenuItem(title: "Highlight", action: #selector(highlight(_:)))
        let commentItem = UIMenuItem(title: "Comment", action: #selector(comment(_:)))
        UIMenuController.shared.menuItems = [highlightItem, commentItem]
    }
    
    /// Notification handler for hitting of annotation, such as an existing highlight.
    @objc private func handleHitAnnotation(notification: Notification) {
        print("TODO: show popup")
    }
    
    /// Notification handler for the current page change.
    @objc private func handlePageChanged(notification: Notification) {
        drawStoredHighlights()
    }
    
    /// Fetch Highlights stored at Firestore and display those annotation views.
    private func drawStoredHighlights() {
        book?.getHighlights() { [weak self] highlight, error in
            guard let `self` = self else { return }
            guard let h = highlight else { return }
            
            if h.page == self.currentPageNumber {
                guard let selection = self.pdfView.document?.findString(h.text ?? "", withOptions: .caseInsensitive).first else { return }
                guard let page = selection.pages.first else { return }
                self.highlight(selection: selection, page: page)
            }
        }
    }
    
    /// Add highlight annotation view.
    private func highlight(selection: PDFSelection, page: PDFPage) {
        selection.selectionsByLine().forEach { s in
            let highlight = PDFAnnotation(bounds: s.bounds(for: page), forType: .highlight, withProperties: nil)
            highlight.endLineStyle = .square
            page.addAnnotation(highlight)
        }
    }
    
    /// Call above method and save this Highlight at Firestore.
    @objc private func highlight(_ sender: UIMenuController?) {
        guard let currentSelection = pdfView.currentSelection else { return }
        guard let page = currentSelection.pages.first else { return }
        
        highlight(selection: currentSelection, page: page)
        
        pdfView.clearSelection()
        
        book.saveHighlight(text: currentSelection.string, pageNumber: pdfView.document?.index(for: page))
    }
    
    /// Go to AddCommentViewController to save both Highlight and Comment.
    @objc private func comment(_ sender: UIMenuController?) {
        guard let currentSelection = pdfView.currentSelection else { return }
        guard let page = currentSelection.pages.first else { return }
        guard let text = currentSelection.string else { return }
        guard let pageNumber = pdfView.document?.index(for: page) else { return }
        
        pdfView.clearSelection()
        
        let h = Highlight()
        h.text = text
        h.page = pageNumber
        let vc = AddCommentViewController.instantiate(highlight: h, book: book) { [weak self] in
            self?.highlight(selection: currentSelection, page: page)
        }
        present(vc, animated: true)
    }
}
