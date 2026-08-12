import Cocoa
import FlutterMacOS

class MarketStatusBarManager: NSObject {
    static let shared = MarketStatusBarManager()

    private var statusItem: NSStatusItem?
    private var methodChannel: FlutterMethodChannel?
    private var currentPrice: String = "--"
    private var currentColorHex: String?
    private var aiNewsSummary: String = "Đang cập nhật tin tức AI..."

    func setup(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: "com.do_x.market/status_bar",
                                            binaryMessenger: messenger)

        setupStatusItem()
        setupAppObservers()

        // Handle calls from Flutter
        methodChannel?.setMethodCallHandler { [weak self] (call, result) in
            switch call.method {
            case "updatePrice":
                if let args = call.arguments as? [String: Any],
                   let price = args["price"] as? String {
                    self?.currentPrice = price
                    self?.currentColorHex = args["color"] as? String
                    self?.updateStatusDisplay()
                    self?.updateMenu()
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Price is required", details: nil))
                }
            case "updateNews":
                if let args = call.arguments as? [String: Any],
                   let summary = args["summary"] as? String {
                    self?.aiNewsSummary = summary
                    self?.updateMenu()
                    result(nil)
                } else {
                    result(FlutterError(code: "INVALID_ARGUMENTS", message: "Summary is required", details: nil))
                }
            case "setVisibility":
                if let args = call.arguments as? [String: Any],
                   let visible = args["visible"] as? Bool {
                    self?.statusItem?.isVisible = visible
                    result(nil)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let assetKey = "assets/images/gold.png"
            let bundlePath = Bundle.main.bundlePath
            let imagePath = "\(bundlePath)/Contents/Frameworks/App.framework/Resources/flutter_assets/\(assetKey)"

            if FileManager.default.fileExists(atPath: imagePath), let image = NSImage(contentsOfFile: imagePath) {
                image.size = NSSize(width: 16, height: 16)
                image.isTemplate = false
                button.image = image
                button.imagePosition = .imageLeft
            } else if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .bold)
                button.image = NSImage(systemSymbolName: "bitcoinsign.circle.fill", accessibilityDescription: "Gold")?.withSymbolConfiguration(config)
                button.imagePosition = .imageLeft
            }

            updateStatusDisplay()
        }

        setupMenu()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        // --- Market Title ---
        let titleItem = NSMenuItem()
        titleItem.view = createLabelView(text: "DO X - THỊ TRƯỜNG VÀNG", font: .systemFont(ofSize: 10, weight: .bold), color: .secondaryLabelColor, padding: 10)
        menu.addItem(titleItem)

        // --- Price Info ---
        let priceItem = NSMenuItem()
        priceItem.tag = 100
        priceItem.view = createPriceView()
        menu.addItem(priceItem)

        menu.addItem(NSMenuItem.separator())

        // --- AI News Header ---
        let newsHeader = NSMenuItem()
        newsHeader.view = createLabelView(text: "TÓM TẮT THỊ TRƯỜNG (AI)", font: .systemFont(ofSize: 10, weight: .bold), color: .secondaryLabelColor, padding: 10)
        menu.addItem(newsHeader)

        // --- AI News Content ---
        let newsContentItem = NSMenuItem()
        newsContentItem.tag = 200
        newsContentItem.view = createNewsView()
        menu.addItem(newsContentItem)

        menu.addItem(NSMenuItem.separator())

        // --- Actions (Standard clickable items) ---
        let openItem = NSMenuItem(title: "Mở ứng dụng Do X", action: #selector(openApp), keyEquivalent: "o")
        openItem.target = self
        openItem.isEnabled = true
        menu.addItem(openItem)

        let quitItem = NSMenuItem(title: "Thoát hoàn toàn", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        quitItem.isEnabled = true
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    // MARK: - View Creators

    private func createLabelView(text: String, font: NSFont, color: NSColor, padding: CGFloat) -> NSView {
        let view = NSView(frame: NSRange(location: 0, length: 0).toRect(width: 280, height: 20))
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.frame = NSRect(x: 20, y: 0, width: 240, height: 20)
        view.addSubview(label)
        return view
    }

    private func createPriceView() -> NSView {
        let view = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 25))
        let label = NSTextField(labelWithString: "Giá vàng thế giới: ")
        label.font = .systemFont(ofSize: 13)
        label.frame = NSRect(x: 20, y: 0, width: 120, height: 25)

        let valueLabel = NSTextField(labelWithString: currentPrice)
        valueLabel.tag = 101
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 14, weight: .bold)
        valueLabel.frame = NSRect(x: 135, y: 0, width: 120, height: 25)

        if let hex = currentColorHex, let color = colorFromHex(hex) {
            valueLabel.textColor = color
        }

        view.addSubview(label)
        view.addSubview(valueLabel)
        return view
    }

    private func createNewsView() -> NSView {
        // News container with wrapping support
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 80))
        let textView = NSTextField(wrappingLabelWithString: aiNewsSummary)
        textView.tag = 201
        textView.font = .systemFont(ofSize: 12)
        textView.textColor = .labelColor
        textView.frame = NSRect(x: 20, y: 5, width: 240, height: 70)
        container.addSubview(textView)
        return container
    }

    private func updateMenu() {
        DispatchQueue.main.async {
            guard let menu = self.statusItem?.menu else { return }

            // Update Price Value
            if let priceItem = menu.item(withTag: 100), let view = priceItem.view {
                if let valueLabel = view.viewWithTag(101) as? NSTextField {
                    valueLabel.stringValue = self.currentPrice
                    if let hex = self.currentColorHex, let color = self.colorFromHex(hex) {
                        valueLabel.textColor = color
                    }
                }
            }

            // Update AI News Value
            if let newsItem = menu.item(withTag: 200), let view = newsItem.view {
                if let textView = view.viewWithTag(201) as? NSTextField {
                    textView.stringValue = self.aiNewsSummary
                    // Dynamic height based on content
                    let size = textView.cell?.cellSize(forBounds: NSRect(x: 0, y: 0, width: 240, height: 1000)) ?? NSSize(width: 240, height: 70)
                    textView.frame.size.height = size.height
                    view.frame.size.height = size.height + 10
                }
            }
        }
    }

    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    private func setupAppObservers() {
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(self, selector: #selector(appChanged), name: NSWorkspace.didLaunchApplicationNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appChanged), name: NSWorkspace.didTerminateApplicationNotification, object: nil)
    }

    @objc private func appChanged(_ notification: Notification) {
        if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
            let event = notification.name == NSWorkspace.didLaunchApplicationNotification ? "launched" : "terminated"
            methodChannel?.invokeMethod("onAppChanged", arguments: ["event": event, "name": app.localizedName ?? ""])
            statusItem?.isVisible = true
        }
    }

    private func updateStatusDisplay() {
        DispatchQueue.main.async {
            guard let button = self.statusItem?.button else { return }
            let priceText = " \(self.currentPrice)"
            let attributedString = NSMutableAttributedString(string: priceText)
            let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .bold)
            attributedString.addAttribute(.font, value: font, range: NSRange(location: 0, length: priceText.count))
            if let hex = self.currentColorHex, let color = self.colorFromHex(hex) {
                attributedString.addAttribute(.foregroundColor, value: color, range: NSRange(location: 0, length: priceText.count))
            }
            button.attributedTitle = attributedString
        }
    }

    private func colorFromHex(_ hex: String) -> NSColor? {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0
        return NSColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

// Utility for NSRange to NSRect
extension NSRange {
    func toRect(width: CGFloat, height: CGFloat) -> NSRect {
        return NSRect(x: 0, y: 0, width: width, height: height)
    }
}
