//
//  NetworkBar.swift
//  monitor
//
//  Created by wyy on 2019/10/15.
//  Copyright © 2019 yahaha. All rights reserved.
//

import Cocoa
import Foundation

// MARK: - NetworkBar

extension NSUserInterfaceItemIdentifier {
    static let tableCellView = NSUserInterfaceItemIdentifier("TableCellView")
}

class NetworkBar: NSObject, NSTableViewDataSource, NSTableViewDelegate {
    var sort: Bool?

    // 网络信息
    var bandwidth = NettopBandwidth()
//    var bandwidth = PnetBandwidth.instance

    // 文本最大宽度
    private lazy var maxStatusBarWidth: CGFloat = NSAttributedString(string: " 1024.12 KB/s ↑", attributes: textAttributes).size().width + 5
    private lazy var maxSingleCellWidth: CGFloat = {
        NSTextField(labelWithString: " 1024.12 KB/s ").intrinsicContentSize.width
    }()

    private lazy var networkMenuItem: NSStatusItem = {
        NSStatusBar.system.statusItem(withLength: maxStatusBarWidth)
    }()

    // table view
    private lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        let column1 = NSTableColumn()
        let column2 = NSTableColumn()
        let column3 = NSTableColumn()
        let column4 = NSTableColumn()

        column1.title = ""
        column1.width = 40
        column1.isEditable = false

        column2.title = "processName".localized
        column2.width = 120
        column2.isEditable = false

        column3.title = "upload".localized
        column3.width = maxSingleCellWidth + 10
        column3.isEditable = false

        column4.title = "download".localized
        column4.width = maxSingleCellWidth + 10
        column4.isEditable = false

        tableView.addTableColumn(column1)
        tableView.addTableColumn(column2)
        tableView.addTableColumn(column3)
        tableView.addTableColumn(column4)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsColumnResizing = true
        tableView.autoresizingMask = [.width, .height]
        return tableView
    }()

    // 流量文本格式
    private lazy var textAttributes: [NSAttributedString.Key: Any] = {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.maximumLineHeight = 10
        paragraphStyle.paragraphSpacing = -7
        paragraphStyle.alignment = .right
        return [
            NSAttributedString.Key.font: NSFont.systemFont(ofSize: 9),
            NSAttributedString.Key.paragraphStyle: paragraphStyle,
        ] as [NSAttributedString.Key: Any]
    }()

    private var experiment = false

    private var experimentTitle: String {
        if experiment {
            return "netop".localized
        } else {
            return "experiment".localized
        }
    }

    @objc private func switchExperimentNettop(_ sender: Any) {
        experiment.toggle()
    }

    override init() {
        super.init()

        let menu = NSMenu()
        let item = NSMenuItem()
        item.isEnabled = true
        item.view = tableView
        menu.addItem(item)
        menu.addItem(NSMenuItem.separator())

//        let switchExperiment = NSMenuItem(title: experimentTitle, action: #selector(switchExperimentNettop(_:)), keyEquivalent: "")
//        switchExperiment.isEnabled = true
//        menu.addItem(switchExperiment)
//        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "quit".localized, action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        networkMenuItem.menu = menu
        if let button = networkMenuItem.button {
            button.attributedTitle = NSAttributedString(string: "0 ↑\n0 ↓", attributes: textAttributes)
            button.imagePosition = .imageLeft
            tableView.reloadData()
        }

        start()
    }

    func numberOfRows(in tableView: NSTableView) -> Int {
        return (bandwidth.appInfo.count > 10 ? 10 : bandwidth.appInfo.count) + 1
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        var content: String?
        var image: NSImage?
        var alignment: NSTextAlignment?

        // 第一行为标题，第一行第一列不输出
        if row == 0 {
            if tableColumn != tableView.tableColumns[0] {
                content = tableColumn?.title
                switch tableColumn {
                case tableView.tableColumns[1]: alignment = .left
                case tableView.tableColumns[2]: alignment = .right
                case tableView.tableColumns[3]: alignment = .right
                default: break
                }
            }
        } else {
            // 第一列是图标，其余为信息
            let array = bandwidth.appInfo
            if array.count > row - 1 {
                let info = array[row - 1]
                switch tableColumn {
                case tableView.tableColumns[0]:
                    image = info.image
                case tableView.tableColumns[1]:
                    content = String(info.name)
                    alignment = .left
                case tableView.tableColumns[2]:
                    content = Bandwidth.formatSpeed(v: info.bytesOut)
                    alignment = .right
                case tableView.tableColumns[3]:
                    content = Bandwidth.formatSpeed(v: info.bytesIn)
                    alignment = .right
                default:
                    content = ""
                }
            }
        }
        if let pic = image {
            let cellView = getImageCellView(tableView: tableView)
            cellView?.setImage(image: pic, frame: NSRect(x: 10, y: 0, width: 16, height: 16))
            return cellView
        } else if let text = content {
            let cellView = getTextCellView(tableView: tableView)
            cellView?.label.stringValue = text
            if let align = alignment {
                cellView?.label.alignment = align
            }
            return cellView
        }
        return nil
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 16
    }

    // 获取文本cell
    func getTextCellView(tableView: NSTableView) -> TextCellView? {
        var cellView = tableView.makeView(withIdentifier: .tableCellView, owner: tableView) as? TextCellView
        if cellView == nil {
            cellView = TextCellView()
            cellView?.identifier = .tableCellView
        }
        return cellView
    }

    // 获取图像cell
    func getImageCellView(tableView: NSTableView) -> ImageCellView? {
        var cellView = tableView.makeView(withIdentifier: .tableCellView, owner: tableView) as? ImageCellView
        if cellView == nil {
            cellView = ImageCellView()
            cellView?.identifier = .tableCellView
        }
        return cellView
    }

    // 更新status bar
    private func start() {
        bandwidth.start {
            self.refresh()
        }
    }

    func refresh() {
        let (download, upload) = bandwidth.total()
        DispatchQueue.main.async {
            if let button = self.networkMenuItem.button {
                button.attributedTitle = NSAttributedString(string: "\(upload) ↑\n\(download) ↓", attributes: self.textAttributes)
                button.imagePosition = .imageLeft
                //                button.alignment = .natural
                self.tableView.reloadData()
            }
        }
    }

    // 停止，清除已缓存的信息
    func stop() {
        bandwidth.clear()
    }
}
