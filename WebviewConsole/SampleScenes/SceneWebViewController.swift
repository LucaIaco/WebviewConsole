//
//  SceneWebViewController.swift
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

class SceneWebViewController: SceneBaseViewController {
    
    //MARK: Properties
    
    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var lblUrl: UILabel!
    @IBOutlet weak var lblStatus: UILabel!
    @IBOutlet weak var btnNewUrl: UIButton!
    @IBOutlet weak var btnLoad: UIButton!
    
    /// The url to be loaded. Once set, it will automatically start loading it in the webview
    var url:URL? {
        didSet{
            guard self.isViewLoaded else { return }
            self.lblUrl.text = url?.absoluteString ?? "N/A"
            self.loadUrl()
        }
    }
    
    //MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
    }
    
    //MARK: Private
    
    private func setup() {
        self.webView.navigationDelegate = self
        
        // default sample url
        if self.url == nil {
            self.url = URL(string: "https://jsitor.com/p/DoSU2lIN6")
        }
    }
    
    /// Loads the current set url in the webview
    private func loadUrl() {
        guard let url = self.url else { return }
        if self.webView.isLoading {
            self.webView.stopLoading()
        }
        self.webView.load(URLRequest(url: url , cachePolicy: .reloadIgnoringCacheData, timeoutInterval: 30.0))
        self.btnLoad.setTitle("Interrupt ■", for: .normal)
    }
    
    //MARK: IBActions

    @IBAction func onTapNewUrl(_ sender: UIButton) {
        self.showInputDialog(title: "New Url", message: "Insert a new url to be loaded") { (urlStr) in
            guard let urlStr = urlStr?.trimmed, let url = URL(string: urlStr), url.isHTTP else { return }
            self.url = url
        }
    }
    
    @IBAction func onTapLoad(_ sender: UIButton) {
        if self.webView.isLoading {
            self.webView.stopLoading()
            self.lblStatus.text = "Loading interrupted"
            self.btnLoad.setTitle("Load ↻", for: .normal)
        }else{
            self.loadUrl()
        }
    }
    
}

//MARK: - WKNavigationDelegate implementation
extension SceneWebViewController: WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.lblStatus.text = "Loading..."
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.lblStatus.text = "Ready"
        self.btnLoad.setTitle("Load ↻", for: .normal)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.lblStatus.text = "Loading failed"
        self.btnLoad.setTitle("Load ↻", for: .normal)
    }
    
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.lblStatus.text = "Loading failed"
        self.btnLoad.setTitle("Load ↻", for: .normal)
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        WebviewConsole.shared.trackWebview(webView)
    }
}

//MARK: UIViewController extension
fileprivate extension UIViewController {
    func showInputDialog(title:String? = nil, message:String? = nil, actionHandler: ((_ text: String?) -> ())? = nil) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addTextField(configurationHandler: nil)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action:UIAlertAction) in
            guard let textField =  alert.textFields?.first else {
                actionHandler?(nil)
                return
            }
            actionHandler?(textField.text)
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }
}

//MARK: URL extension
fileprivate extension URL {
    
    /// Returns true if the url is an http(s) url
    var isHTTP:Bool {
        guard let scheme = self.scheme else { return false }
        return ["http","https"].contains(scheme)
    }
    
}
