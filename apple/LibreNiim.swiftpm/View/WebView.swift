import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    static var shared = WebView()
    var view: WKWebView?
    var image: UIImage?
    var onImageAvailable: ((UIImage?) -> Void)?

    func exportCanvas() {
        let script = """
        exportCanvas();
        """
        print(WebView.shared.view?.configuration.userContentController.userScripts.count)
        WebView.shared.view!.evaluateJavaScript(script, completionHandler: {
            _, err in
            print("Javascript Image Export Error", err.debugDescription)
        })
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.loadURL("http://127.0.0.1:1234")
        WebView.shared.view = webView
        let script = """
        function backingScale(context) {
          if ('devicePixelRatio' in window) {
              if (window.devicePixelRatio > 1) {
                  return window.devicePixelRatio;
              }
          }
          return 1;
        }
        function exportCanvas() {
            document.getElementById('deselectButton').click();
            var canvas = document.getElementById('labelCanvas');
            const canvasScale = backingScale(canvas.getContext("2d"));
            var dataURL = canvas.toDataURL('image/png');
            window.webkit.messageHandlers.imageHandler.postMessage({"dataURL": dataURL, "scale": canvasScale});
        }
        """
        webView.configuration.userContentController.addUserScript(WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: false))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var parent: WebView

        init(_ parent: WebView) {
            self.parent = parent
//            self.onImageCaptured = onImageCaptured
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.configuration.userContentController.add(self, name: "imageHandler")
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "imageHandler", 
                let dictionary = message.body as? [String: Any],
                let url = URL(string: dictionary["dataURL"] as! String),
                   let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data, scale: dictionary["scale"] as! CGFloat) {
                        WebView.shared.onImageAvailable! (image)
                    }
            }
    }
}

extension WKWebView {
    func loadURL(_ address: String) {
        guard let url = URL(string: address) else { return }
        load(URLRequest(url: url))
    }
}
