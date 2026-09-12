import Carbon
import CoreGraphics

enum WorkspaceKeySequence {
    static func strokes(for command: WorkspaceNavigationCommand, controlHeld: Bool) -> [ProcessKeyStroke] {
        func key(_ code: Int, _ down: Bool, _ flags: CGEventFlags) -> ProcessKeyStroke {
            ProcessKeyStroke(keyCode: CGKeyCode(code), keyDown: down, flags: flags)
        }
        if command == .confirmHermesSelection {
            return controlHeld ? [key(kVK_Control, false, [])] : []
        }
        if command.profile == .super {
            let code = command == .previousProject ? kVK_UpArrow : (command == .nextProject ? kVK_DownArrow : kVK_RightArrow)
            let flags: CGEventFlags = [.maskControl, .maskAlternate]
            return [key(kVK_Control,true,.maskControl),key(kVK_Option,true,flags),
                    key(code,true,flags),key(code,false,flags),
                    key(kVK_Option,false,.maskControl),key(kVK_Control,false,[])]
        }
        var result = controlHeld ? [] : [key(kVK_Control,true,.maskControl)]
        let previous = command == .previousHermesTab
        let flags: CGEventFlags = previous ? [.maskControl,.maskShift] : [.maskControl]
        if previous { result.append(key(kVK_Shift,true,flags)) }
        result += [key(kVK_Tab,true,flags),key(kVK_Tab,false,flags)]
        if previous { result.append(key(kVK_Shift,false,.maskControl)) }
        return result
    }

    static func releases(held: [CGKeyCode]) -> [ProcessKeyStroke] {
        var flags: CGEventFlags = []
        let modifiers: [(CGKeyCode, CGEventFlags)] = [(CGKeyCode(kVK_Control),.maskControl),
            (CGKeyCode(kVK_Option),.maskAlternate),(CGKeyCode(kVK_Shift),.maskShift)]
        for (key, flag) in modifiers where held.contains(key) { flags.insert(flag) }
        return held.reversed().map { key in
            if let flag = modifiers.first(where: { $0.0 == key })?.1 { flags.remove(flag) }
            return ProcessKeyStroke(keyCode:key,keyDown:false,flags:flags)
        }
    }
}
