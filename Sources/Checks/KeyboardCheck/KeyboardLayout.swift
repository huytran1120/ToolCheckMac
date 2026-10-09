import Foundation

/// 单个物理按键：macOS 虚拟 keyCode + 显示文案 + 相对宽度（1.0 = 一个标准键位）。
struct KeyDef: Identifiable, Hashable {
    let id: UInt16   // 用 keyCode 本身当 id，同一个键不会重复出现在布局里
    let keyCode: UInt16
    let label: String
    let widthUnits: CGFloat

    init(_ keyCode: UInt16, _ label: String, width: CGFloat = 1.0) {
        self.id = keyCode
        self.keyCode = keyCode
        self.label = label
        self.widthUnits = width
    }
}

/// 标准 macOS 美式 ANSI 键盘布局（无 Touch Bar）。虚拟 keyCode 定义参考 Carbon HIToolbox `Events.h`。
/// 说明：为简化渲染模型，方向键簇按四个等大按键横排展示，与实体键盘上下堆叠的 ↑/↓ 略有出入，
/// 不影响功能测试（每个方向键仍独立可测）。
enum KeyboardLayout {
    static let rows: [[KeyDef]] = [
        // 功能键行
        [
            KeyDef(53, "esc"),
            KeyDef(122, "F1"), KeyDef(120, "F2"), KeyDef(99, "F3"), KeyDef(118, "F4"),
            KeyDef(96, "F5"), KeyDef(97, "F6"), KeyDef(98, "F7"), KeyDef(100, "F8"),
            KeyDef(101, "F9"), KeyDef(109, "F10"), KeyDef(103, "F11"), KeyDef(111, "F12"),
        ],
        // 数字行
        [
            KeyDef(50, "`"), KeyDef(18, "1"), KeyDef(19, "2"), KeyDef(20, "3"), KeyDef(21, "4"),
            KeyDef(23, "5"), KeyDef(22, "6"), KeyDef(26, "7"), KeyDef(28, "8"), KeyDef(25, "9"),
            KeyDef(29, "0"), KeyDef(27, "-"), KeyDef(24, "="), KeyDef(51, "delete", width: 1.8),
        ],
        // QWERTY 行
        [
            KeyDef(48, "tab", width: 1.4),
            KeyDef(12, "Q"), KeyDef(13, "W"), KeyDef(14, "E"), KeyDef(15, "R"), KeyDef(17, "T"),
            KeyDef(16, "Y"), KeyDef(32, "U"), KeyDef(34, "I"), KeyDef(31, "O"), KeyDef(35, "P"),
            KeyDef(33, "["), KeyDef(30, "]"), KeyDef(42, "\\", width: 1.2),
        ],
        // 主行（home row）
        [
            KeyDef(57, "caps", width: 1.7),
            KeyDef(0, "A"), KeyDef(1, "S"), KeyDef(2, "D"), KeyDef(3, "F"), KeyDef(5, "G"),
            KeyDef(4, "H"), KeyDef(38, "J"), KeyDef(40, "K"), KeyDef(37, "L"), KeyDef(41, ";"),
            KeyDef(39, "'"), KeyDef(36, "return", width: 2.0),
        ],
        // 下行
        [
            KeyDef(56, "shift", width: 2.2),
            KeyDef(6, "Z"), KeyDef(7, "X"), KeyDef(8, "C"), KeyDef(9, "V"), KeyDef(11, "B"),
            KeyDef(45, "N"), KeyDef(46, "M"), KeyDef(43, ","), KeyDef(47, "."), KeyDef(44, "/"),
            KeyDef(60, "shift", width: 2.2),
        ],
        // 底行
        [
            KeyDef(63, "fn", width: 1.0),
            KeyDef(59, "control", width: 1.2),
            KeyDef(58, "option", width: 1.2),
            KeyDef(55, "⌘", width: 1.4),
            KeyDef(49, "space", width: 5.0),
            KeyDef(54, "⌘", width: 1.2),
            KeyDef(61, "option", width: 1.2),
            KeyDef(123, "←"), KeyDef(126, "↑"), KeyDef(125, "↓"), KeyDef(124, "→"),
        ],
    ]

    static var allKeys: [KeyDef] { rows.flatMap { $0 } }
    static var totalKeyCount: Int { allKeys.count }
}
