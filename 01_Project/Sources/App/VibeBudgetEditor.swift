import AppKit

/// Small AppKit window for the Vibe monthly budget: amount + reset day with
/// Save/Cancel. Pure AppKit controls per the project UI conventions. An empty
/// or non-positive amount removes the budget (the section returns to
/// token-first with no percentage).
@MainActor
final class VibeBudgetEditor: NSObject, NSWindowDelegate {
    static let shared = VibeBudgetEditor()

    private var window: NSWindow?
    private var amountField: NSTextField?
    private var dayField: NSTextField?
    private var dayStepper: NSStepper?
    private var onSave: ((Double?, Int) -> Void)?

    func present(amount: Double?, resetDay: Int, onSave: @escaping (Double?, Int) -> Void) {
        self.onSave = onSave
        if let window {
            updateControls(amount: amount, resetDay: resetDay)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let label = { (text: String) in
            let field = NSTextField(labelWithString: text)
            field.font = .systemFont(ofSize: 13)
            return field
        }

        let amount = NSTextField()
        amount.placeholderString = "none — removes the budget"
        amount.formatter = Self.amountFormatter
        amount.target = self
        amount.action = #selector(save)
        amountField = amount

        let stepper = NSStepper(frame: .zero)
        stepper.minValue = 1
        stepper.maxValue = 31
        stepper.integerValue = resetDay
        stepper.valueWraps = false
        stepper.target = self
        stepper.action = #selector(dayChanged)
        dayStepper = stepper

        let day = NSTextField()
        day.formatter = Self.dayFormatter
        day.integerValue = resetDay
        day.target = self
        day.action = #selector(dayEdited)
        dayField = day

        let save = NSButton(title: "Save", target: self, action: #selector(save))
        save.keyEquivalent = "\r"
        let cancel = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancel.keyEquivalent = "\u{1b}"

        let rows = NSStackView(views: [label("Monthly budget (USD)"), amount])
        rows.spacing = 8
        let dayRow = NSStackView(views: [label("Resets on day of month"), day, stepper])
        dayRow.spacing = 8
        let buttons = NSStackView(views: [cancel, save])
        buttons.spacing = 8

        let column = NSStackView(views: [rows, dayRow, buttons])
        column.orientation = NSUserInterfaceLayoutOrientation.vertical
        column.alignment = .leading
        column.spacing = 12
        column.edgeInsets = NSEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)

        let fitting = column.fittingSize
        let contentRect = NSRect(x: 0, y: 0, width: max(fitting.width, 320), height: fitting.height)
        let window = NSWindow(contentRect: contentRect,
                              styleMask: [.titled, .closable],
                              backing: .buffered, defer: false)
        window.title = "Vibe Monthly Budget"
        window.contentView = column
        window.isReleasedWhenClosed = false
        window.center()
        window.delegate = self
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func updateControls(amount: Double?, resetDay: Int) {
        if let amount {
            amountField?.doubleValue = amount
        } else {
            amountField?.stringValue = ""
        }
        dayField?.integerValue = resetDay
        dayStepper?.integerValue = resetDay
    }

    @objc private func dayChanged(_ sender: NSStepper) {
        dayField?.integerValue = sender.integerValue
    }

    @objc private func dayEdited(_ sender: NSTextField) {
        dayStepper?.integerValue = sender.integerValue
    }

    @objc private func save() {
        let amountText = amountField?.stringValue.trimmingCharacters(in: .whitespaces) ?? ""
        let amount: Double?
        if amountText.isEmpty {
            amount = nil
        } else if let parsed = amountField?.doubleValue, parsed > 0 {
            amount = parsed
        } else {
            NSApp.presentError(NSError(domain: "VibeBudgetEditor", code: 1,
                                       userInfo: [NSLocalizedDescriptionKey:
                                            "Enter a positive amount, or leave it empty to remove the budget."]))
            return
        }
        let day = min(max(dayStepper?.integerValue ?? 1, 1), 31)
        window?.orderOut(nil)
        onSave?(amount, day)
    }

    @objc private func cancel() {
        window?.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window?.orderOut(nil)
    }

    private static let amountFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimum = 0
        return formatter
    }()

    private static let dayFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .none
        formatter.minimum = 1
        formatter.maximum = 31
        return formatter
    }()
}
