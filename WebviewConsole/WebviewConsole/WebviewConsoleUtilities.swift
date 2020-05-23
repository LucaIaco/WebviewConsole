//
//  WebviewConsoleUtilities.swift
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

//MARK: extension - String
extension String {
    /// Returns the trimmed representation of this string
    var trimmed:String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

//MARK: extension - CGRect
extension CGRect {
    var top:CGFloat { origin.y }
    var left:CGFloat { origin.x }
    var right:CGFloat { origin.x + size.width }
    var bottom:CGFloat { origin.y + size.height }
}

//MARK: extension - UIView
extension UIView {
    
    /// Returns the 60% size of the view screenshot
    var screenshot: UIImage {
        let scale:CGFloat = 0.6
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: self.bounds.width * scale,
                                                            height: self.bounds.height * scale))
        return renderer.image { (context) in
            context.cgContext.scaleBy(x: scale, y: scale)
            self.layer.render(in: context.cgContext)
        }
    }
    
    /// The set options which can be used to apply the drop shadow of the specific side of the view
    ///
    /// See method addDropShadow(sides:offset:radius:color:opacity:)
    enum DropShadowSide {
        case top
        case bottom
        case left
        case right
        
        /// Applies the given offset to the provided size, for the current dropshadow side
        ///
        /// - Parameters:
        ///   - size: the size to be affected
        ///   - offset: the offset to be used on
        fileprivate func applyOffsetToSize(size: inout CGSize, offset:CGFloat){
            switch self {
            case .top:
                size.height -= offset
            case .bottom:
                size.height += offset
            case .left:
                size.width -= offset
            case .right:
                size.width += offset
            }
        }
    }
    
    /// It applies a dropshadow effect on the current view given the provided criteria
    ///
    /// - Parameters:
    ///   - sides: the sides to be affected
    ///   - offset: the offset to be used from the view sides
    ///   - radius: the shadow radious to be used
    ///   - color: the shadow color
    ///   - opacity: the shadow opacity
    func addDropShadow(sides:[UIView.DropShadowSide] = [.bottom], offset:CGFloat = 0, radius:CGFloat = 3, color:UIColor = .black, opacity:Float = 1){
        guard sides.count > 0 else{ return }
        self.layer.shadowColor = color.cgColor
        self.layer.shadowOpacity = opacity
        var offsetSize:CGSize = .zero
        sides.forEach { $0.applyOffsetToSize(size: &offsetSize, offset: offset) }
        self.layer.shadowOffset = offsetSize
        self.layer.shadowRadius = radius
        self.layer.masksToBounds = false
    }
    
    /// Returns the array of subviews in the view hierarchy which match the provided type
    /// - Parameter type: the type filter
    func allSubviews<T:UIView>(of type:T.Type) -> [T] {
        var result = self.subviews.compactMap({$0 as? T})
        var subviews = self.subviews
        
        // Inspect also the non visible views on the same level
        var notVisibleViews = [UIView]()
        subviews.forEach { (v) in
            if let vc = v.next as? UIViewController {
                let childVCViews = vc.children.filter({$0.isViewLoaded && $0.view.window == nil }).compactMap({$0.view})
                notVisibleViews.append(contentsOf: childVCViews)
            }
            if let vc = v.next as? UINavigationController {
                let nvNavVC = vc.viewControllers.filter({$0.isViewLoaded && $0.view.window == nil })
                let navVCViews = nvNavVC.compactMap({$0.view})
                notVisibleViews.append(contentsOf: navVCViews)
                // detect child vc in not visible vc in the nav controller
                let childInNvNavVC = nvNavVC.compactMap({$0.children}).reduce([],+).compactMap({$0.view})
                notVisibleViews.append(contentsOf: childInNvNavVC)
            }
            if let vc = v.next as? UITabBarController {
                let tabViewControllers = vc.viewControllers?.filter({$0.isViewLoaded && $0.view.window == nil }) ?? [UIViewController]()
                // detect navigation controller in the hidden tab bar view controllers
                let vc1 = tabViewControllers.compactMap({$0 as? UINavigationController})
                vc1.forEach { (vc) in
                    let nvNavVC = vc.viewControllers.filter({$0.isViewLoaded && $0.view.window == nil })
                    let navVCViews = nvNavVC.compactMap({$0.view})
                    notVisibleViews.append(contentsOf: navVCViews)
                    // detect child vc in not visible vc in the nav controller
                    let childInNvNavVC = nvNavVC.compactMap({$0.children}).reduce([],+).compactMap({$0.view})
                    notVisibleViews.append(contentsOf: childInNvNavVC)
                }
                // ad non-navigation controller in the hidden tab bar view controllers
                let tabVCViews = tabViewControllers.compactMap({($0 as? UINavigationController) == nil ? $0.view : nil})
                notVisibleViews.append(contentsOf: tabVCViews)
            }
        }
        subviews.append(contentsOf: notVisibleViews.distinct())
        
        subviews.forEach { (subview) in
            result.append(contentsOf: subview.allSubviews(of: type))
        }
        return result.distinct()
    }
}

//MARK: extension - Hashable array
extension Array where Element: Hashable {
    
    /// Returns the array representation of unique elements
    /// - Returns: the unique representation of this array
    func distinct() -> [Element] {
        var added = [Element:Bool]()
        return self.filter { added.updateValue(true, forKey: $0) == nil }
    }
}

//MARK: extension - NSAttributedString
extension NSAttributedString {
    
    /// Return the attributes string representation of the original one which the highlight on the searched string
    ///
    /// - Parameters:
    ///   - searchString: the string/substring we are looking for
    ///   - highlightColor: the highlight color to use
    /// - Returns: the resulting attributed representation of the string
    func highlightMatches(searchString:String, highlightColor:UIColor = .yellow)->NSAttributedString{
        
        guard let regex = try? NSRegularExpression(pattern: searchString, options: .caseInsensitive) else{
            return self
        }
        let attr = NSMutableAttributedString(attributedString: self)
        let targetString = self.string
        
        for match in regex.matches(in: targetString, options: NSRegularExpression.MatchingOptions(), range: NSRange(location: 0, length: targetString.count)) as [NSTextCheckingResult] {
            attr.addAttribute(NSAttributedString.Key.backgroundColor, value: highlightColor, range: match.range)
        }
        
        return attr
    }
    
}

//MARK: - extension - WebviewConsole - JSBridgeFunction definition
extension WebviewConsole {
    
    /// Set of supported js bridge function names to be attached to a webview
    enum JSBridgeFunction:String,CaseIterable {
        case consoleLog
        case consoleInfo
        case consoleWarn
        case consoleError
        
        /// Returns the javascript function to be bridged
        var jsFunction:String {
            switch self {
            case .consoleLog:
                return "console.log"
            case .consoleInfo:
                return "console.info"
            case .consoleWarn:
                return "console.warn"
            case .consoleError:
                return "console.error"
            }
        }
        
        /// Extend the associated js function to this item and attach the webkit js message handler
        /// to the provided object handler
        /// - Parameters:
        ///   - webview: the target webview
        ///   - completion: block called when the operation is completed, giving and error if needed
        func attachBridge(to webview:WKWebView, completion:((WKError?)->())?) {
            // expands the designated js function with the bridging
            let source = """
            \(self.jsFunction) = (function(_super) {
            return function() {
            window.webkit.messageHandlers.\(self.rawValue).postMessage(arguments[0]);
            return _super.apply(this, arguments);
            };
            })(\(self.jsFunction));
            """
            webview.evaluateJavaScript(source) { (out, err) in
                if err == nil || (err as? WKError)?.code != .javaScriptResultTypeIsUnsupported {
                    completion?(err as? WKError)
                } else {
                    completion?(nil)
                }
            }
        }
        
        /// Returns the attributed string representation of the given messaage for this JS function
        /// - Parameter msg: the message to process
        func attributeStringMsg(_ msg:String) -> NSAttributedString {
            let color:UIColor
            switch self {
            case .consoleLog:
                color = .black
            case .consoleInfo:
                color = UIColor(red: 0, green: 0, blue: 0.5, alpha: 1)
            case .consoleWarn:
                color = UIColor(red: 0.6, green: 0.6, blue: 0, alpha: 1)
            case .consoleError:
                color = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
            }
            return NSAttributedString(string: "\(msg)", attributes: [NSAttributedString.Key.foregroundColor : color])
        }
        
    }
}

//MARK: - extension - WebviewConsole - CommandSuggestionView component
extension WebviewConsole {
    
    /// Tableview component used to suggest commands to the user
    class CommandSuggestionView:UITableView, UITableViewDelegate, UITableViewDataSource {
        
        //MARK: Public
        
        /// Callback called when user taps on an entry in the tableview
        var onSelect:((_ index:Int,_ value:String)->())?
        
        /// Get/Set the filter string to be used on the suggestion data set
        var filter:String? {
            didSet{
                guard self.superview != nil else { return }
                self.filter(by: self.filter)
            }
        }
        
        // The default full dataset of suggestions
        var dataset:[String] = ["console","console.log","console.warn","console.error","console.info", "document","document.activeElement","document.addEventListener","document.anchors","document.baseURI","document.body","document.cookie","document.characterSet","document.createAttribute","document.createElement","document.defaultView","document.doctype","document.documentElement","document.documentURI","document.domain","document.forms","document.getElementById","document.getElementsByClassName","document.getElementsByName","document.getElementsByTagName","document.hasFocus()","document.head","document.images","document.inputEncoding","document.links","document.querySelector","document.readyState","document.referrer","document.removeEventListener","document.title","document.URL","window","window.defaultStatus","window.innerHeight","window.innerWidth","window.name","window.outerHeight","window.outerWidth","window.pageXOffset","window.pageYOffset","window.screenX","window.screenY","window.scrollX","window.scrollY","window.status","location","location.hash","location.host","location.hostname","location.href","location.origin","location.pathname","location.port","location.search"]
        
        //MARK: Private properties
        
        private let cellID = "suggestionCellId"
        
        /// Cell height
        private let cellHeight:CGFloat = 35.0
        
        /// Max component height
        private let maxHeight:CGFloat = 150.0
        
        // The current filtered dataset
        private var filteredDataset:[String] = []
        
        //MARK: Initialisers
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
            self.setup()
        }
        
        override init(frame: CGRect, style: UITableView.Style) {
            super.init(frame: frame, style: style)
            self.setup()
        }
        
        //MARK: View lifecycle
        
        override func willMove(toSuperview newSuperview: UIView?) {
            if newSuperview != nil {
                self.filter(by: self.filter)
            }
        }
        
        override var intrinsicContentSize: CGSize {
            let oSize = super.intrinsicContentSize
            return CGSize(width: oSize.width,
                          height: CGFloat.minimum(CGFloat(self.filteredDataset.count) * cellHeight, maxHeight))
        }
        
        //MARK: Private
        
        private func setup() {
            self.dataSource = self
            self.delegate = self
            self.backgroundColor = UIColor(red: 1, green: 247/255.0, blue: 228/255.0, alpha: 0.9)
            self.estimatedRowHeight = cellHeight
            self.register(UITableViewCell.self, forCellReuseIdentifier: cellID)
        }
        
        /// Filters the datasource by the given search string
        /// - Parameter value: the string to use for filtering the datasource
        private func filter(by value:String?) {
            if let value = value?.trimmed, !value.isEmpty {
                self.filteredDataset = self.dataset.filter({$0.lowercased().contains(value.lowercased())}).sorted()
            }else{
                self.filteredDataset = self.dataset.sorted()
            }
            self.reloadData()
            self.invalidateIntrinsicContentSize()
            self.layoutIfNeeded()
        }
        
        //MARK: Tableview datasource and delegate
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return cellHeight
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return self.filteredDataset.count
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
            cell.backgroundColor = .clear
            cell.textLabel?.text = self.filteredDataset[indexPath.row]
            return cell
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            guard let callback = self.onSelect else { return }
            callback(indexPath.row, self.filteredDataset[indexPath.row])
        }
        
    }
    
}

//MARK: - The webview console cell used in the collection view
class WebviewConsoleCell: UICollectionViewCell {
    
    //MARK: IBOutlets
    
    @IBOutlet weak var container: UIView!
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var lblJavascript: UILabel!
    @IBOutlet weak var lblVisible: UILabel!
    @IBOutlet weak var lblUrl: UILabel!
    
    //MARK: Private properties
    
    private let radius:CGFloat = 5.0
    
    //MARK: View lifecycle
    
    override func awakeFromNib() {
        super.awakeFromNib()
        self.contentView.layer.masksToBounds = false
        self.layer.masksToBounds = false
        self.container.layer.cornerRadius = radius
        self.container.addDropShadow(sides: [.bottom,.right], offset: 0, radius: radius, color: .black, opacity: 0.5)
        self.imageView.layer.cornerRadius = radius
        self.imageView.layer.maskedCorners = [.layerMinXMinYCorner,.layerMinXMaxYCorner]
        
        self.reset()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        self.reset()
    }
    
    //MARK: Public
    
    /// Represents the given webview in this cell
    /// - Parameters:
    ///   - webview: the webview to be represented in this cell
    ///   - cache: the cache containing all the cached webview screenshots
    ///   - useCachedSnapshot: if false, the cell will acquire and cache a new snapshot for this webview
    func load(webview:WKWebView, cache:NSCache<NSNumber,UIImage>, useCachedSnapshot:Bool = true){
        guard let url = webview.url else { return }
        
        let isJSEnabled = webview.configuration.preferences.javaScriptEnabled
        let isWebviewVisible = !webview.isHidden && webview.window != nil
        self.lblJavascript.text = "\(isJSEnabled)"
        self.lblVisible.text = "\(isWebviewVisible)"
        self.lblJavascript.textColor = isJSEnabled ? UIColor(red: 0, green: 0.5, blue: 0, alpha: 1) : .red
        self.lblVisible.textColor = isWebviewVisible ? UIColor(red: 0, green: 0.5, blue: 0, alpha: 1) : .red
        self.lblUrl.text = url.absoluteString
        // set the snapshot
        if useCachedSnapshot, let screen = cache.object(forKey: NSNumber(value: webview.hash)) {
            self.imageView.image = screen
        }else{
            let img = webview.screenshot
            self.imageView.image = img
            cache.setObject(img, forKey: NSNumber(value: webview.hash))
        }
    }
    
    //MARK: Private
    
    private func reset() {
        self.imageView.image = nil
        self.lblJavascript.text = "N/A"
        self.lblVisible.text = "N/A"
        self.lblJavascript.textColor = self.lblUrl.textColor
        self.lblVisible.textColor = self.lblUrl.textColor
        self.lblUrl.text = " "
    }
    
}
