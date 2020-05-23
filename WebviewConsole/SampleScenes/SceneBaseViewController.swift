//
//  SceneBaseViewController.swift
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

class SceneBaseViewController: UIViewController {
    
    //MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.setup()
    }
    
    //MARK: Private
    
    private func setup(){
        if let _ = self.navigationController {
            let btnAdd = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(btnAction(sender:)))
            let btnConsole = UIBarButtonItem(title: "Show console", style: .plain, target: self, action: #selector(showInspector(sender:)))
            self.navigationItem.rightBarButtonItems = [btnAdd, btnConsole]
        }
    }
    
    @objc private func btnAction(sender:Any) {
        let actionSheet = UIAlertController(title: nil, message: "Add a new webview, directly to the navigation controller, or embedded into a another view controller", preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "New webview", style: .default, handler: { (action:UIAlertAction) in
            self.newWebView()
        }))
        actionSheet.addAction(UIAlertAction(title: "New embedded single webview", style: .default, handler: { (action:UIAlertAction) in
            self.newChildWebView()
        }))
        actionSheet.addAction(UIAlertAction(title: "New embedded double webview", style: .default, handler: { (action:UIAlertAction) in
            self.newChildWebView(doubled: true)
        }))
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    @objc private func showInspector(sender:Any) {
        WebviewConsole.shared.show()
    }
    
    private func newWebView() {
        guard let newWebViewVC = self.storyboard?.instantiateViewController(withIdentifier: "webViewID") as? SceneWebViewController else { return }
        self.navigationController?.pushViewController(newWebViewVC, animated: true)
    }
    
    private func newChildWebView(doubled:Bool = false) {
        guard let newChildWebViewVC = self.storyboard?.instantiateViewController(withIdentifier: doubled ? "childDoubleWebViewID" : "childWebViewID") as? SceneChildWebViewController else { return }
        self.navigationController?.pushViewController(newChildWebViewVC, animated: true)
    }
    
}
