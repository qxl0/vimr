/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import RxSwift
import PureLayout
import CocoaMarkdown
import WebKit

fileprivate class WebviewMessageHandler: NSObject, WKScriptMessageHandler {

  enum Action {

    case scroll(lineBegin: Int, columnBegin: Int, lineEnd: Int, columnEnd: Int)
  }

  fileprivate let flow: EmbeddableComponent

  override init() {
    flow = EmbeddableComponent(source: Observable.empty())
    super.init()
  }

  func userContentController(_: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let msgBody = message.body as? [String: Int] else {
      return
    }

    guard let lineBegin = msgBody["lineBegin"],
          let columnBegin = msgBody["columnBegin"],
          let lineEnd = msgBody["lineEnd"],
          let columnEnd = msgBody["columnEnd"]
      else {
      return
    }

    flow.publish(event: Action.scroll(lineBegin: lineBegin, columnBegin: columnBegin,
                                      lineEnd: lineEnd, columnEnd: columnEnd))
  }
}

class MarkdownRenderer: NSObject, Flow, PreviewRenderer {

  static let identifier = "com.qvacua.vimr.tool.preview.markdown"
  static func prefData(from dict: [String: Any]) -> StandardPrefData? {
    return PrefData(dict: dict)
  }

  struct PrefData: StandardPrefData {

    fileprivate static let identifier = "identifier"
    fileprivate static let isForwardSearchAutomatically = "is-forward-search-automatically"
    fileprivate static let isReverseSearchAutomatically = "is-reverse-search-automatically"

    static let `default` = PrefData(isForwardSearchAutomatically: false, isReverseSearchAutomatically: false)

    var isForwardSearchAutomatically: Bool
    var isReverseSearchAutomatically: Bool

    init(isForwardSearchAutomatically: Bool, isReverseSearchAutomatically: Bool) {
      self.isForwardSearchAutomatically = isForwardSearchAutomatically
      self.isReverseSearchAutomatically = isReverseSearchAutomatically
    }

    init?(dict: [String: Any]) {
      guard PrefUtils.string(from: dict, for: PrefData.identifier) == MarkdownRenderer.identifier else {
        return nil
      }

      guard let isForward = PrefUtils.bool(from: dict, for: PrefData.isForwardSearchAutomatically) else {
        return nil
      }

      guard let isReverse = PrefUtils.bool(from: dict, for: PrefData.isReverseSearchAutomatically) else {
        return nil
      }

      self.init(isForwardSearchAutomatically: isForward, isReverseSearchAutomatically: isReverse)
    }

    func dict() -> [String: Any] {
      return [
        PrefData.identifier: MarkdownRenderer.identifier,
        PrefData.isForwardSearchAutomatically: self.isForwardSearchAutomatically,
        PrefData.isReverseSearchAutomatically: self.isReverseSearchAutomatically,
      ]
    }
  }

  fileprivate let flow: EmbeddableComponent

  fileprivate let scheduler = ConcurrentDispatchQueueScheduler(qos: .userInitiated)
  fileprivate let baseUrl = Bundle.main.resourceURL!.appendingPathComponent("markdown")
  fileprivate let extensions = Set(["md", "markdown", ])
  fileprivate let template: String

  fileprivate let userContentController = WKUserContentController()
  fileprivate let webviewMessageHandler = WebviewMessageHandler()

  fileprivate var isForwardSearchAutomatically = false
  fileprivate var isReverseSearchAutomatically = false

  fileprivate let webview: WKWebView

  let identifier: String = MarkdownRenderer.identifier
  var prefData: StandardPrefData? {
    return PrefData(isForwardSearchAutomatically: self.isForwardSearchAutomatically,
                    isReverseSearchAutomatically: self.isReverseSearchAutomatically)
  }

  var sink: Observable<Any> {
    return self.flow.sink
  }

  let toolbar: NSView? = NSView(forAutoLayout: ())
  let menuItems: [NSMenuItem]?

  init(source: Observable<Any>) {
    guard let templateUrl = Bundle.main.url(forResource: "template",
                                            withExtension: "html",
                                            subdirectory: "markdown")
      else {
      preconditionFailure("ERROR Cannot load markdown template")
    }

    guard let template = try? String(contentsOf: templateUrl) else {
      preconditionFailure("ERROR Cannot load markdown template")
    }

    self.template = template

    self.flow = EmbeddableComponent(source: source)

    let configuration = WKWebViewConfiguration()
    configuration.userContentController = self.userContentController
    self.webview = WKWebView(frame: .zero, configuration: configuration)
    self.webview.configureForAutoLayout()

    let forwardSearchMenuItem = NSMenuItem(title: "Forward Search", action: nil, keyEquivalent: "")
    let reverseSearchMenuItem = NSMenuItem(title: "Reverse Search", action: nil, keyEquivalent: "")
    let automaticForwardMenuItem = NSMenuItem(title: "Automatic Forward Search", action: nil, keyEquivalent: "")
    let automaticReverseMenuItem = NSMenuItem(title: "Automatic Reverse Search", action: nil, keyEquivalent: "")

    self.menuItems = [
      forwardSearchMenuItem,
      reverseSearchMenuItem,
      NSMenuItem.separator(),
      automaticForwardMenuItem,
      automaticReverseMenuItem,
    ]

    super.init()

    self.flow.set(subscription: self.subscription)

    self.initCustomUiElements()

    forwardSearchMenuItem.target = self
    forwardSearchMenuItem.action = #selector(MarkdownRenderer.forwardSearchAction)
    reverseSearchMenuItem.target = self
    reverseSearchMenuItem.action = #selector(MarkdownRenderer.reverseSearchAction)
    automaticForwardMenuItem.target = self
    automaticForwardMenuItem.action = #selector(MarkdownRenderer.automaticForwardSearchAction)
    automaticReverseMenuItem.target = self
    automaticReverseMenuItem.action = #selector(MarkdownRenderer.automaticReverseSearchAction)

    self.addReactions()
    self.userContentController.add(webviewMessageHandler, name: "com_vimr_preview_markdown")
  }

  func canRender(fileExtension: String) -> Bool {
    return extensions.contains(fileExtension)
  }

  fileprivate func subscription(source: Observable<Any>) -> Disposable {
    return source
      .observeOn(self.scheduler)
      .mapOmittingNil { action in

        switch action {
        case let PreviewComponent.Action.automaticRefresh(url):
          return url

        default:
          return nil

        }
      }
      .filter { self.canRender(fileExtension: $0.pathExtension) }
      .subscribe(onNext: { [unowned self] url in self.render(from: url) })
  }

  fileprivate func initCustomUiElements() {
    let forward = NSButton(forAutoLayout: ())
    InnerToolBar.configureToStandardIconButton(button: forward, iconName: .chevronCircleRight)
    forward.toolTip = "Forward Search"
    forward.target = self
    forward.action = #selector(MarkdownRenderer.forwardSearchAction)

    let reverse = NSButton(forAutoLayout: ())
    InnerToolBar.configureToStandardIconButton(button: reverse, iconName: .chevronCircleLeft)
    reverse.toolTip = "Reverse Search"
    reverse.target = self
    reverse.action = #selector(MarkdownRenderer.reverseSearchAction)

    self.toolbar?.addSubview(forward)
    self.toolbar?.addSubview(reverse)

    forward.autoPinEdge(toSuperviewEdge: .top)
    forward.autoPinEdge(toSuperviewEdge: .right)

    reverse.autoPinEdge(toSuperviewEdge: .top)
    reverse.autoPinEdge(.right, to: .left, of: forward)
  }

  fileprivate func addReactions() {
    self.webviewMessageHandler.flow.sink
      .filter { $0 is WebviewMessageHandler.Action }
      .map { $0 as! WebviewMessageHandler.Action }
      .subscribe(onNext: { [weak self] action in
        switch action {
        case let .scroll(lineBegin, columnBegin, _, _):
          self?.flow.publish(event: PreviewRendererAction.scroll(to: Position(row: lineBegin, column: columnBegin)))
        }
      })
      .addDisposableTo(self.flow.disposeBag)
  }

  fileprivate func filledTemplate(body: String, title: String) -> String {
    return self.template
      .replacingOccurrences(of: "{{ title }}", with: title)
      .replacingOccurrences(of: "{{ body }}", with: body)
  }

  fileprivate func render(from url: URL) {

    NSLog("\(#function): \(url)")

    let doc = CMDocument(contentsOfFile: url.path, options: .sourcepos)
    let renderer = CMHTMLRenderer(document: doc)

    guard let body = renderer?.render() else {
      self.flow.publish(event: PreviewRendererAction.error)
      return
    }

    let html = filledTemplate(body: body, title: url.lastPathComponent)
    self.webview.loadHTMLString(html, baseURL: self.baseUrl)

    try? html.write(toFile: "/tmp/markdown-preview.html", atomically: false, encoding: .utf8)
    self.flow.publish(event: PreviewRendererAction.view(renderer: self, view: self.webview))
  }
}

// MARK: - Actions
extension MarkdownRenderer {

  func forwardSearchAction(_: Any?) {
    NSLog("\(#function)")
  }

  func reverseSearchAction(_: Any?) {
    NSLog("\(#function)")
  }

  func automaticForwardSearchAction(_: Any?) {
    self.isForwardSearchAutomatically = !self.isForwardSearchAutomatically
    NSLog("\(#function)")
  }

  func automaticReverseSearchAction(_: Any?) {
    self.isReverseSearchAutomatically = !self.isReverseSearchAutomatically
    NSLog("\(#function)")
  }
}