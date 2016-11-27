/**
 * Tae Won Ha - http://taewon.de - @hataewon
 * See LICENSE
 */

import Cocoa
import PureLayout

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

  @IBOutlet weak var window: NSWindow!

  fileprivate var workspace: Workspace = Workspace(mainView: NSView())

  @IBAction func toggleBars(_ sender: AnyObject!) {
    workspace.toggleAllTools()
  }

  @IBAction func toggleButtons(_ sender: AnyObject!) {
    workspace.toggleToolButtons()
  }

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    let contentView = self.window.contentView!
    let workspace = Workspace(mainView: DummyView(NSColor.white))
    self.workspace = workspace

    contentView.addSubview(workspace)
    workspace.autoPinEdgesToSuperviewEdges()

    workspace.append(tool: WorkspaceTool(title: "Top-1", view: DummyToolView(NSColor.yellow)), location: .top)
    workspace.append(tool: WorkspaceTool(title: "Right-1", view: DummyToolView(NSColor.magenta)), location: .right)
    workspace.append(tool: WorkspaceTool(title: "Right-2", view: DummyToolView(NSColor.black)), location: .right)
    let tool = WorkspaceTool(title: "Left-1", view: DummyToolView(NSColor.green))
    workspace.append(tool: tool, location: .left)
    workspace.append(tool: WorkspaceTool(title: "Left-2", view: DummyToolView(NSColor.red)), location: .left)
    workspace.append(tool: WorkspaceTool(title: "Left-3", view: DummyToolView(NSColor.gray)), location: .left)
    workspace.append(tool: WorkspaceTool(title: "Bottom-1", view: DummyToolView(NSColor.cyan)), location: .bottom)
    workspace.append(tool: WorkspaceTool(title: "Bottom-2", view: DummyToolView(NSColor.blue)), location: .bottom)

    let left = workspace.bars[.left]!
    left.toggle(tool)
  }
}

class DummyToolView: NSView {

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  init(_ color: NSColor) {
    super.init(frame: .zero)
    self.configureForAutoLayout()
    self.wantsLayer = true

    let innerToolbar = InnerToolBar(forAutoLayout:())
    let dummyView = DummyView(color)

    self.addSubview(innerToolbar)
    self.addSubview(dummyView)

    innerToolbar.autoPinEdge(toSuperviewEdge: .top)
    innerToolbar.autoPinEdge(toSuperviewEdge: .right)
    innerToolbar.autoPinEdge(toSuperviewEdge: .left)

    dummyView.autoPinEdge(.top, to: .bottom, of: innerToolbar)
    dummyView.autoPinEdge(toSuperviewEdge: .right)
    dummyView.autoPinEdge(toSuperviewEdge: .left)
  }
}

class DummyView: NSView {

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  init(_ color: NSColor) {
    super.init(frame: .zero)
    self.configureForAutoLayout()
    self.wantsLayer = true
    self.layer?.backgroundColor = color.cgColor
  }

  override func mouseDown(with event: NSEvent) {
    NSLog("mouse down")
  }
}
