//
//  WebviewConsole.swift
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

/// Class which Interfaces with the hosting app, showing/hiding the webview console component on the screen
class WebviewConsole {
    
    /// Shared instance
    static let shared = WebviewConsole()
    
    /// Reference to the web view console window
    private var window = WebviewConsole.WebConsoleWindow(level: .alert)
    
    /// Shows the webview console window on top of the current key window
    func show() {
        self.window?.show()
    }
    
    /// Hides the webview console window
    func hide() {
        self.window?.hide()
    }
    
    func trackWebview(_ webview:WKWebView) {
        self.window?.webConsole?.addWebview(webview)
    }
    
}


//MARK: - extension - WebviewConsole - Web console window
fileprivate extension WebviewConsole {
    
    class WebConsoleWindow:UIWindow {
        
        //MARK: Proeprites
        
        private let animPresentationDuration:TimeInterval = 0.2
        
        /// Indicates if the window visibility is changing
        private(set) var isTransitioning:Bool = false
        
        /// Returns the referred webview console view controller
        var webConsole:WebviewConsoleViewController?{ (self.rootViewController as? WebviewConsoleRootViewController)?.webConsole }
        
        //MARK: View lifecycle
        
        override init(frame: CGRect) {
            super.init(frame: frame)
        }
        
        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
        
        /// Convenient init which creates a new instance of a WebConsole WebConsoleWindow
        /// - Parameter level: the desired window level
        convenience init?(level:UIWindow.Level) {
            let size = (UIApplication.shared.delegate?.window as? UIWindow)?.bounds.size ?? UIScreen.main.bounds.size
            self.init(frame:CGRect(origin: .zero, size: size))
            self.backgroundColor = .clear
            self.windowLevel = level
            self.rootViewController = UIStoryboard(name: "WebviewConsole", bundle: nil).instantiateInitialViewController()
            // The below showing and hiding will cause the root view to be loaded, initalizing all his children views. In this way the component will be ready to be used
            self.isHidden = false
            self.isHidden = true
        }
        
        //MARK: Public
        
        /// Show the Webview console window
        func show() {
            guard self.isHidden, !self.isTransitioning else { return }
            self.isTransitioning = true
            
            self.rootViewController?.view.alpha = 0
            self.makeKeyAndVisible()
            UIView.animate(withDuration: self.animPresentationDuration, delay: 0, options: .curveEaseIn, animations: {
                self.rootViewController?.view.alpha = 1
            }, completion: {  [weak self] (f) in
                guard let self = self else { return }
                self.isTransitioning = false
                self.webConsole?.didShow()
            })
        }
        
        /// Hide the Webview console window
        func hide() {
            guard !self.isHidden, !self.isTransitioning else { return }
            self.isTransitioning = true
            
            self.rootViewController?.view.alpha = 1
            UIView.animate(withDuration: self.animPresentationDuration, delay: 0, options: .curveEaseIn, animations: {
                self.rootViewController?.view.alpha = 0
            }) { [weak self] (f) in
                guard let self = self else { return }
                self.isHidden = true
                self.isTransitioning = false
                self.webConsole?.didHide()
            }
        }
        
    }
    
}

//MARK: - Webview console root view controller of the WebConsoleWindow
class WebviewConsoleRootViewController: UIViewController {
    
    //MARK: Properties
    
    /// Returns the referred webview console view controller
    var webConsole:WebviewConsoleViewController?{ (self.children.first as? UINavigationController)?.topViewController as? WebviewConsoleViewController }
    
    //MARK: IBOutlets
    @IBOutlet weak var containerStackView: UIStackView!
    @IBOutlet weak var topView: UIView!
    
    //MARK: View lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.topView.isUserInteractionEnabled = true
        self.topView.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(onPan(sender:))))
    }
    
    //MARK: IBAction
    
    @IBAction func onTapHide(_ sender: Any) {
        WebviewConsole.shared.hide()
    }
    
    @objc private func onPan(sender:UIPanGestureRecognizer) {
        switch sender.state {
        case .changed:
            let translation = sender.translation(in: sender.view)
            self.containerStackView.transform = .init(translationX: translation.x, y: translation.y)
        case .ended,.cancelled:
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1.0, initialSpringVelocity: 0.05, options: .beginFromCurrentState, animations: {
                self.containerStackView.transform = .identity
            }, completion: nil)
            sender.setTranslation(.zero, in: sender.view)
        default:
            break
        }
    }
    
}
