//
//  WebviewConsoleViewController.swift
//  WebviewConsole
//
//  MIT License
//
//  Copyright (c) 2020 Luca Iaconis. All rights reserved.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import UIKit
import WebKit

class WebviewConsoleViewController: UIViewController {
    
    //MARK: Public properties
    
    /// Get/Set whether the component should scan the view hierachy to find webviews when it get shown
    ///
    /// If set to true, it will also run a scan to detect the webviews in the view hierarchy
    ///
    var autoDetectWebviews:Bool = true {
        didSet {
            guard self.isSetup, self.autoDetectWebviews != oldValue, self.autoDetectWebviews == true else{
                return
            }
            self.autoDetectWebviewSwitch.isOn = self.autoDetectWebviews
            self.scanWebviews()
        }
    }
    
    /// Get/Set whether the current webviews list should be cleared when the component gets hidden
    var clearWebviewsOnHide:Bool = false
    
    /// Get/Set whether the command suggestions should be displayed to the user while editing
    var suggestCommandsOnEditing:Bool = true
    
    /// Get/Set whether the logs should be scrolled to the bottom in order to show the newest when a new logs gets added, for the current webview
    var scrollToBottomOnLogAdd = true
    
    //MARK: IBOutlets
    
    @IBOutlet private weak var collectionView: UICollectionView!
    @IBOutlet private weak var textViewLogs: UITextView!
    
    @IBOutlet private weak var actionContainer: UIView!
    @IBOutlet private weak var actionContainerBottomLayout: NSLayoutConstraint!
    @IBOutlet private weak var txtInput: UITextField!
    @IBOutlet private weak var subActionsContainer: UIStackView!
    @IBOutlet private weak var txtSearch: UITextField!
    @IBOutlet private weak var autoDetectWebviewSwitch: UISwitch!
    
    /// Reference to any currently shown command suggest view
    private weak var commandSuggestView:WebviewConsole.CommandSuggestionView?
    
    //MARK: Private properties
    
    /// Array of weak references to webviews
    private let webviews = NSHashTable<WKWebView>.weakObjects()
    
    /// In memory cached screenshots (webview hash -> image)
    private let webviewsScreenshots = NSCache<NSNumber,UIImage>()
    
    /// In memory logs (webview hash -> String)
    private var webviewsLogs = [Int:NSMutableAttributedString]()
    
    /// The hashes list of all the webviews which have been bridged to this view controller instance
    private var bridgedWebviewsHashHistory:Set<Int> = Set<Int>()
    
    /// Weak reference to the currently selected webview
    private weak var selectedWebView:WKWebView? {
        didSet {
            if let selWebview = self.selectedWebView {
                self.selectedWebviewIndex = self.webviews.allObjects.firstIndex(of: selWebview)
            } else {
                self.selectedWebviewIndex = nil
            }
            // notify change if needed
            if oldValue != self.selectedWebView{
                self.webviewSelectionChanged(previousWebview: oldValue)
            }
        }
    }
    
    /// Index of selected webview, or nil if none is selected
    private var selectedWebviewIndex:Int? = nil
    
    /// Whether the view did setup on viewDidLoad
    private var isSetup:Bool = false
    
    /// The last keyboard event name
    private var lastKeyboardEvent: NSNotification.Name?
    
    //MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setupBarActionItem()
        self.setupKeyboardEvents()
        self.autoDetectWebviewSwitch.isOn = self.autoDetectWebviews
        self.isSetup = true
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.didShow()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.didHide()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        self.collectionView.reloadData()
    }
    
}

//MARK: - Public methods
extension WebviewConsoleViewController {
    
    /// Adds the provided webview instance in the tracked webview list and attaches/updates the webview event
    /// - Parameter webview: the webview to be tracked
    /// - Returns: true if the webview got added, false if was already in the webview list
    @discardableResult func addWebview(_ webview:WKWebView) -> Bool {
        let result = !self.webviews.allObjects.contains(webview)
        if result {
            self.webviews.add(webview)
        }
        self.attachWebviewEventsIfNeeded(for: webview)
        return result
    }
    
    /// Called when the component gets shown
    func didShow() {
        if self.autoDetectWebviews {
            self.scanWebviews()
        } else {
            self.updateWebviewList()
        }
    }
    
    /// Called when the component gets hidden
    func didHide() {
        if self.clearWebviewsOnHide {
            self.clearWebViewList(keepSelected: false)
        }
    }
    
    /// It clears the component, removing any referred webview
    func clearAll() {
        self.clearWebViewList(keepSelected: false)
        self.updateWebviewList()
        // reset all logs
        Array(self.webviewsLogs.keys).forEach({self.webviewsLogs[$0] = NSMutableAttributedString(string: "") })
    }
    
}

//MARK: - IBActions
extension WebviewConsoleViewController {
    
    @IBAction func onInputTextChanged(_ sender: UITextField) {
        self.addUpdateCommandSuggestView(filter: sender.text)
    }
    
    @IBAction func onSearchTextChanged(_ sender: UITextField) {
        guard let webview = self.selectedWebView, let log = self.webviewsLogs[webview.hash] else { return }
        self.displayViewLog(log)
    }
    
    @IBAction func onTapShowHideSubActions(_ sender: UIButton) {
        UIView.animate(withDuration: 0.2, delay:0, options: [.allowUserInteraction,.beginFromCurrentState,.curveEaseInOut], animations: {
            self.subActionsContainer.isHidden.toggle()
        }, completion: { (_) in
            if self.txtSearch.isFirstResponder {
                self.txtInput.becomeFirstResponder()
            }
        })
    }
    
    @IBAction func onAutodetectSwitchChanged(_ sender: UISwitch) {
        self.autoDetectWebviews = sender.isOn
    }
    
}

//MARK: - Private - Bar button item and actions
extension WebviewConsoleViewController {
    
    private func setupBarActionItem() {
        let barItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(showActions(sender:)))
        self.navigationItem.rightBarButtonItem = barItem
    }
    
    @objc private func showActions(sender:Any) {
        let alert = UIAlertController(title: "Webview actions", message: nil, preferredStyle: .actionSheet)
        
        if self.selectedWebView != nil {
            alert.addAction(UIAlertAction(title: "Reload current webview url", style: .default , handler:{ [weak self] (UIAlertAction) in
                guard let wevView = self?.selectedWebView else { return }
                wevView.reload()
            }))
            alert.addAction(UIAlertAction(title: "Clear current webview logs", style: .destructive , handler:{ [weak self] (UIAlertAction) in
                guard let wevView = self?.selectedWebView else { return }
                self?.webviewsLogs[wevView.hash] = NSMutableAttributedString(string: "")
                self?.displayViewLog(NSAttributedString(string: ""))
            }))
        }
        
        alert.addAction(UIAlertAction(title: "Clear all logs", style: .destructive , handler:{ (UIAlertAction) in
            // reset all logs
            Array(self.webviewsLogs.keys).forEach({self.webviewsLogs[$0] = NSMutableAttributedString(string: "") })
            self.displayViewLog(NSAttributedString(string: ""))
        }))
        alert.addAction(UIAlertAction(title: "Clear all", style: .destructive , handler:{ (UIAlertAction) in
            self.clearAll()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        self.present(alert, animated: true, completion: nil)
    }
}

//MARK: -  Private - Webview detection, dataset and webview selection handling
extension WebviewConsoleViewController {
    
    /// Scans for all the currently instantiates webiews under the visible windows
    private func scanWebviews() {
        DispatchQueue.main.async {
            // get all the visible windows from which we wanna detect all the webviews
            let windows = UIApplication.shared.windows.filter({$0.isHidden == false && $0.rootViewController != nil})
            // clear last webview list and cache
            self.clearWebViewList()
            // get all the webvview across the visible windows
            windows.forEach { (window) in
                let foundWebviews = window.allSubviews(of: WKWebView.self)
                foundWebviews.forEach { (webview) in
                    self.addWebview(webview)
                }
            }
            // update the list with the new detected webviews
            self.updateWebviewList()
        }
    }
    
    /// Refresh the list of detected webviews on the screen. It also sync the selected webview based on the
    /// current state of the alive webviews weak references
    private func updateWebviewList() {
        // update the index of the selected webview in case the dataset has changed
        if let selWebview = self.selectedWebView, self.webviews.allObjects.contains(selWebview) {
            self.selectedWebviewIndex = self.webviews.allObjects.firstIndex(of: selWebview)
        } else if self.webviews.allObjects.count > 0 {
            self.selectedWebView = self.webviews.allObjects.first
        }
        
        // put placeholder if no webview is available
        if self.webviews.allObjects.count == 0 {
            let lblPlaceholder = UILabel(frame: .zero)
            lblPlaceholder.numberOfLines = 0
            lblPlaceholder.textAlignment = .center
            lblPlaceholder.textColor = .lightGray
            lblPlaceholder.text = "No webview instance detected"
            self.collectionView.backgroundView = lblPlaceholder
            // reset the text view log from any past session
            self.textViewLogs.text = ""
        } else {
            self.collectionView.backgroundView = nil
        }
        // refresh the collection view
        self.collectionView.reloadData()
        
        // sync to the cell
        if let curWebviewIx = self.selectedWebviewIndex, self.webviews.allObjects.indices.contains(curWebviewIx) {
            self.collectionView.scrollToItem(at: IndexPath(row: curWebviewIx, section: 0), at: .right, animated: false)
        }
    }
    
    /// Clears the referenced webviews, and the cached screenshots
    /// - Parameter keepSelected: if true, it keep the weak reference to the last selected webview
    /// - Parameter keepScreenshots: if true, it will preserve the cached webview screenshots
    private func clearWebViewList(keepSelected:Bool = true, keepScreenshots:Bool = true) {
        if !keepSelected {
            self.selectedWebView = nil
        }
        if !keepScreenshots {
            self.webviewsScreenshots.removeAllObjects()
        }
        self.webviews.removeAllObjects()
    }
    
    /// Called when the selectedWebview change value
    /// - Parameter previousWebview: the previous selected webview if any
    private func webviewSelectionChanged(previousWebview:WKWebView?) {
        guard let webview = self.selectedWebView else {
            self.textViewLogs.text = ""
            return
        }
        self.displayViewLog(self.webviewsLogs[webview.hash] ?? NSAttributedString(string: ""))
    }
    
    /// Adds and display a new log for the current selected or designated webview
    /// - Parameter msg: the log entry to be added and displayed for the current webview
    /// - Parameter jsFunction: if provided will be used to decorate the message in the log
    /// - Parameter targetWebview: if nil, the selected webview will be addressed. If set, the log wil be displayed only if the currently selected webview is equal to `targetWebview`
    /// - Results: true if added, false on error (eg no webview is available)
    @discardableResult private func addLog(_ msg:Any, jsFunction:WebviewConsole.JSBridgeFunction? = nil, targetWebview:WKWebView? = nil) -> Bool{
        guard let webview = (targetWebview ?? self.selectedWebView) else { return false }
        let currentLog = self.webviewsLogs[webview.hash] ?? NSMutableAttributedString(string: "")
        
        let newLogEntry = jsFunction?.attributeStringMsg("\(msg)\n") ?? NSAttributedString(string:"\(msg)\n")
        
        currentLog.append(newLogEntry)
        self.webviewsLogs[webview.hash] = currentLog
        // display the new log in the text view
        if targetWebview == nil || targetWebview == self.selectedWebView {
            self.displayViewLog(currentLog)
        }
        // scrolls to bottom if needed
        if self.scrollToBottomOnLogAdd {
            self.scrollLogsToBottom()
        }
        return true
    }
    
    /// Displays the text in the log text view on the screen
    /// - Parameter attrString: the attribute string to be displayed
    private func displayViewLog(_ attrString:NSAttributedString){
        if let searchStr = self.txtSearch.text?.trimmed, !searchStr.isEmpty {
            self.textViewLogs.attributedText = attrString.highlightMatches(searchString: searchStr)
        } else {
            self.textViewLogs.attributedText = attrString
        }
    }
    
}

//MARK: - Private - Webview listeners and js interaction
extension WebviewConsoleViewController:WKScriptMessageHandler {
    
    /// Attach the logger to the provided webview
    /// - Parameter webview: the webview at which we want to attach the logger
    private func attachWebviewEventsIfNeeded(for webview:WKWebView) {
        
        // make sure the webview instance has javascript enabled
        guard webview.configuration.preferences.javaScriptEnabled else {
            let msg = "Unable to attach observer. Javascript is not enabled for this webview\n"
            self.webviewsLogs[webview.hash] = NSMutableAttributedString(string:msg)
            self.displayViewLog(NSAttributedString(string: msg))
            return
        }
        
        let wasWebviewHashInHistory = self.bridgedWebviewsHashHistory.contains(webview.hash)
        
        // initialize the logs and track the hash for this webview if needed
        if wasWebviewHashInHistory == false {
            self.webviewsLogs[webview.hash] = NSMutableAttributedString(string:"")
            self.bridgedWebviewsHashHistory.insert(webview.hash)
        }
        // If the js flag was not defined for this webview, for the current loaded/loading web page,
        // then proceed by attaching all the js bridge functions
        webview.evaluateJavaScript("(typeof window.wbDbgSet === 'undefined')") { (res0, err0) in
            if err0 == nil, let res = res0 as? Bool, res == true {
                // set the js flag for in this webview webpage
                webview.evaluateJavaScript("window.wbDbgSet = true;") { (_, _) in }
                // attach all the supported bridges
                WebviewConsole.JSBridgeFunction.allCases.forEach { (name) in
                    name.attachBridge(to: webview) { (err) in
                        if let err = err {
                            self.textViewLogs.text += "Unable to attach observer.\nError: '\(err)'\n"
                            return
                        }
                        // register the bridge script that listens for the output if not done yet
                        if wasWebviewHashInHistory == false {
                            webview.configuration.userContentController.add(self, name: name.rawValue)
                        }
                    }
                }
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let webview = message.webView else { return }
        guard let jsFunction = WebviewConsole.JSBridgeFunction(rawValue: message.name.trimmed) else { return }
        
        switch jsFunction {
        case .consoleLog,.consoleInfo,.consoleWarn,.consoleError:
            self.addLog(message.body, jsFunction: jsFunction, targetWebview: webview)
        }
    }
    
}

//MARK: - Private - Keyboard events show/hide
extension WebviewConsoleViewController {
    
    private func setupKeyboardEvents(){
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShowHideOrChange(sender:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(onKeyboardWillShowHideOrChange(sender:)), name: UIResponder.keyboardWillChangeFrameNotification, object: nil)
    }
    
    @objc private func onKeyboardWillShowHideOrChange(sender:Notification){
        
        // operate only if this view is shown on screen
        guard self.view.window != nil else { return }
        
        guard let userInfo = sender.userInfo else { return }
        guard let kbdStartFrame = userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? CGRect else { return }
        guard let kbdEndFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
        let duration = userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.2
        let animCurve = userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? UInt ?? UIView.AnimationOptions.curveEaseInOut.rawValue
        
        // prevent flickering when keyboard is shown and user changes focus from a textfield to another
        guard kbdEndFrame != kbdStartFrame else { return }
        
        if sender.name == UIResponder.keyboardWillHideNotification {
            self.actionContainerBottomLayout.constant = 0
        } else {
            if self.lastKeyboardEvent == UIResponder.keyboardWillChangeFrameNotification {
                self.actionContainerBottomLayout.constant += (kbdEndFrame.height - kbdStartFrame.height)
            } else {
                guard let window = self.view.window, let txtSuperview = self.actionContainer.superview else { return }
                let viewInWindow = window.convert(self.actionContainer.frame, from: txtSuperview)
                self.actionContainerBottomLayout.constant = kbdEndFrame.height - (window.bounds.height - viewInWindow.bottom)
            }
        }
        self.lastKeyboardEvent = sender.name
        UIView.animate(withDuration: duration, delay: 0.0, options: UIView.AnimationOptions(rawValue: animCurve), animations: {
            self.view.layoutIfNeeded()
        }, completion: nil)
    }
    
}

//MARK: - Textfield , JS Command execution, Search text in log
extension WebviewConsoleViewController: UITextFieldDelegate {
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        switch textField {
        case self.txtInput:
            if let jscommand = textField.text?.trimmed {
                self.executeJsCommand(jscommand)
            }
            // clear the textfield
            textField.text = nil
            self.removeCommandSuggestView()
        default:
            break
        }
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        if textField == self.txtInput {
            self.addUpdateCommandSuggestView(filter: nil)
        }
    }
    
    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        if textField == self.txtInput {
            self.removeCommandSuggestView()
        }
    }
    
    /// Executes the given javascript command on the currently selected webview
    /// - Parameter jscommand: the javascript command to be executed
    private func executeJsCommand(_ jscommand:String){
        guard !jscommand.isEmpty, let webview = self.selectedWebView else { return }
        webview.evaluateJavaScript(jscommand) { (result, error) in
            let msg:Any?
            if let err = error {
                msg = "> Command execution: FAILED. Error:\n '\(err)'\n"
            }else if let result = result {
                msg = "> Command execution: SUCCESS. Result:\n'\(result)'\n"
            }else {
                msg = nil
            }
            // append the meessage in the webview logs and update the text view
            if let msg = msg {
                self.addLog(msg)
            }
        }
    }
    
    /// Adds a new suggestion view or update the exiting one on top of the action container, with the given
    /// filter string to be used
    /// - Parameter filter: the string to be filtered in the suggestion view
    private func addUpdateCommandSuggestView(filter:String?) {
        // add/update the suggestion view
        if let suggestView = self.commandSuggestView {
            suggestView.filter = self.txtInput.text
        } else {
            guard self.suggestCommandsOnEditing else { return }
            
            let cmdSuggest = WebviewConsole.CommandSuggestionView(frame: .zero)
            cmdSuggest.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(cmdSuggest)
            cmdSuggest.leadingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.leadingAnchor).isActive = true
            cmdSuggest.trailingAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.trailingAnchor).isActive = true
            cmdSuggest.bottomAnchor.constraint(equalTo: self.actionContainer.topAnchor).isActive = true
            cmdSuggest.topAnchor.constraint(greaterThanOrEqualToSystemSpacingBelow: self.view.topAnchor, multiplier: 1.0).isActive = true
            cmdSuggest.filter = self.txtInput.text
            cmdSuggest.onSelect = {[weak self] (ix, val) in
                self?.txtInput.text = val
                self?.removeCommandSuggestView()
            }
            self.view.layoutIfNeeded()
            self.commandSuggestView = cmdSuggest
        }
    }
    
    /// Removes any existing command suggest view from the view
    private func removeCommandSuggestView() {
        self.commandSuggestView?.removeFromSuperview()
        self.commandSuggestView = nil
    }
    
    /// Scrolls the content of the logs to the bottom, to the newest available log
    private func scrollLogsToBottom() {
        let offset = self.textViewLogs.contentSize.height - self.textViewLogs.bounds.size.height
        guard offset > 0 else { return }
        self.textViewLogs.setContentOffset(CGPoint(x: 0, y: offset), animated: true)
    }
    
}

//MARK: - UICollectionView Datasource and Delegate
extension WebviewConsoleViewController: UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.webviews.allObjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "webCellId", for: indexPath) as? WebviewConsoleCell else {
            return UICollectionViewCell()
        }
        if self.webviews.allObjects.indices.contains(indexPath.row) {
            cell.load(webview: self.webviews.allObjects[indexPath.row], cache: self.webviewsScreenshots)
        }
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: collectionView.bounds.width,
                      height: collectionView.bounds.height * 0.9)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let cell = collectionView.cellForItem(at: indexPath) as? WebviewConsoleCell else { return }
        // reload cell on tap
        if self.webviews.allObjects.indices.contains(indexPath.row) {
            cell.load(webview: self.webviews.allObjects[indexPath.row],
                      cache: self.webviewsScreenshots,
                      useCachedSnapshot: false)
        }
    }
    
}

//MARK: - Scrollview delegate
extension WebviewConsoleViewController {
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        // if the component is the collection view containing the webview, then update the selected webview
        if scrollView == self.collectionView {
            let ix = Int(collectionView.contentOffset.x) / Int(collectionView.frame.width)
            if self.webviews.allObjects.indices.contains(ix) {
                self.selectedWebView = self.webviews.allObjects[ix]
            }
        }
    }
}
