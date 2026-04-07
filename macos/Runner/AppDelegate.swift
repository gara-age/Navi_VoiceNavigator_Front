import Cocoa
import FlutterMacOS
import SwiftUI

@main
class AppDelegate: FlutterAppDelegate {
  private var toastWindow: NSPanel?

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  func configureToastChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "voice_navigator/taskbar_popup",
      binaryMessenger: messenger
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard call.method == "showMacToast" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard let args = call.arguments as? [String: Any] else {
        result(false)
        return
      }

      self?.showMacToast(args: args)
      result(true)
    }
  }

  private func showMacToast(args: [String: Any]) {
    let title = args["title"] as? String ?? "Navi: Voice Navigator"
    let message = args["message"] as? String ?? ""
    let durationMs = args["durationMs"] as? Int ?? 5000
    let state = args["state"] as? String ?? "info"
    let themeMode = args["themeMode"] as? String ?? "light"
    let largeText = args["largeText"] as? Bool ?? false

    toastWindow?.close()

    let width: CGFloat = largeText ? 372 : 320
    let height: CGFloat = largeText ? 118 : 96

    guard let screen = NSScreen.main else {
      return
    }

    let visibleFrame = screen.visibleFrame
    let x = visibleFrame.maxX - width - 24
    let y = visibleFrame.maxY - height - 24

    let panel = NSPanel(
      contentRect: NSRect(x: x, y: y, width: width, height: height),
      styleMask: [.nonactivatingPanel, .borderless],
      backing: .buffered,
      defer: false
    )
    panel.isFloatingPanel = true
    panel.level = .statusBar
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.hidesOnDeactivate = false
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

    let rootView = MacToastView(
      title: title,
      message: message,
      state: state,
      themeMode: themeMode,
      largeText: largeText,
      onClose: { [weak self] in
        self?.toastWindow?.close()
        self?.toastWindow = nil
      }
    )

    panel.contentView = NSHostingView(rootView: rootView)
    panel.orderFrontRegardless()
    toastWindow = panel

    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(durationMs)) { [weak self] in
      self?.toastWindow?.close()
      self?.toastWindow = nil
    }
  }
}

private struct MacToastPalette {
  let background: Color
  let border: Color
  let iconBackground: Color
  let iconBorder: Color
  let iconColor: Color
  let titleColor: Color
  let messageColor: Color
  let closeBackground: Color
  let closeBorder: Color
  let closeColor: Color
  let borderWidth: CGFloat
  let iconBorderWidth: CGFloat
  let closeBorderWidth: CGFloat
}

private struct MacToastView: View {
  let title: String
  let message: String
  let state: String
  let themeMode: String
  let largeText: Bool
  let onClose: () -> Void

  var body: some View {
    let palette = resolvePalette(state: state, themeMode: themeMode)
    let titleWeight: Font.Weight = themeMode == "contrast" ? .black : .bold
    let messageWeight: Font.Weight = themeMode == "contrast" ? .bold : .medium

    ZStack(alignment: .topTrailing) {
      HStack(alignment: .top, spacing: 12) {
        RoundedRectangle(cornerRadius: 12)
          .fill(palette.iconBackground)
          .overlay(
            RoundedRectangle(cornerRadius: 12)
              .stroke(palette.iconBorder, lineWidth: palette.iconBorderWidth)
          )
          .frame(width: 40, height: 40)
          .overlay(
            Image(systemName: iconName(for: state))
              .font(.system(size: 18, weight: .semibold))
              .foregroundColor(palette.iconColor)
          )

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: largeText ? 17 : 14, weight: titleWeight))
            .foregroundColor(palette.titleColor)
            .frame(maxWidth: .infinity, alignment: .leading)

          Text(message)
            .font(.system(size: largeText ? 15 : 13, weight: messageWeight))
            .foregroundColor(palette.messageColor)
            .lineLimit(3)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

      }
      .padding(.trailing, 28)
      .padding(.horizontal, 16)
      .padding(.vertical, largeText ? 10 : 8)
      .frame(width: largeText ? 372 : 320, height: largeText ? 118 : 96)
      .background(
        RoundedRectangle(cornerRadius: 18)
          .fill(palette.background)
      )
      .overlay(
        RoundedRectangle(cornerRadius: 18)
          .stroke(palette.border, lineWidth: palette.borderWidth)
      )

      Button(action: onClose) {
        ZStack {
          Circle()
            .fill(palette.closeBackground)
            .frame(width: 28, height: 28)
            .overlay(
              Circle().stroke(palette.closeBorder, lineWidth: palette.closeBorderWidth)
            )

          Image(systemName: "xmark")
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(palette.closeColor)
        }
      }
      .buttonStyle(.plain)
      .padding(.top, 6)
      .padding(.trailing, 6)
    }
  }
}

private func iconName(for state: String) -> String {
  switch state {
  case "listening":
    return "mic.fill"
  case "processing":
    return "hourglass"
  case "success":
    return "checkmark"
  case "warning":
    return "exclamationmark.triangle"
  case "error":
    return "xmark.octagon"
  default:
    return "info.circle"
  }
}

private func resolvePalette(state: String, themeMode: String) -> MacToastPalette {
  if themeMode == "contrast" {
    switch state {
    case "info", "listening":
      return MacToastPalette(
        background: Color(hex: "#DBEAFE"),
        border: Color(hex: "#1E3A8A"),
        iconBackground: .white,
        iconBorder: Color(hex: "#1E3A8A"),
        iconColor: Color(hex: "#1E3A8A"),
        titleColor: Color(hex: "#1E3A8A"),
        messageColor: Color(hex: "#1E3A8A"),
        closeBackground: .white,
        closeBorder: Color(hex: "#1E3A8A"),
        closeColor: Color(hex: "#1E3A8A"),
        borderWidth: 2,
        iconBorderWidth: 2,
        closeBorderWidth: 2
      )
    case "processing":
      return MacToastPalette(
        background: Color(hex: "#FEF9C3"),
        border: Color(hex: "#713F12"),
        iconBackground: .white,
        iconBorder: Color(hex: "#713F12"),
        iconColor: Color(hex: "#713F12"),
        titleColor: Color(hex: "#713F12"),
        messageColor: Color(hex: "#713F12"),
        closeBackground: .white,
        closeBorder: Color(hex: "#713F12"),
        closeColor: Color(hex: "#713F12"),
        borderWidth: 2,
        iconBorderWidth: 2,
        closeBorderWidth: 2
      )
    case "success":
      return MacToastPalette(
        background: Color(hex: "#DCFCE7"),
        border: Color(hex: "#14532D"),
        iconBackground: .white,
        iconBorder: Color(hex: "#14532D"),
        iconColor: Color(hex: "#14532D"),
        titleColor: Color(hex: "#14532D"),
        messageColor: Color(hex: "#14532D"),
        closeBackground: .white,
        closeBorder: Color(hex: "#14532D"),
        closeColor: Color(hex: "#14532D"),
        borderWidth: 2,
        iconBorderWidth: 2,
        closeBorderWidth: 2
      )
    case "warning":
      return MacToastPalette(
        background: Color(hex: "#FFEDD5"),
        border: Color(hex: "#7C2D12"),
        iconBackground: .white,
        iconBorder: Color(hex: "#7C2D12"),
        iconColor: Color(hex: "#7C2D12"),
        titleColor: Color(hex: "#7C2D12"),
        messageColor: Color(hex: "#7C2D12"),
        closeBackground: .white,
        closeBorder: Color(hex: "#7C2D12"),
        closeColor: Color(hex: "#7C2D12"),
        borderWidth: 2,
        iconBorderWidth: 2,
        closeBorderWidth: 2
      )
    default:
      return MacToastPalette(
        background: Color(hex: "#FEE2E2"),
        border: Color(hex: "#7F1D1D"),
        iconBackground: .white,
        iconBorder: Color(hex: "#7F1D1D"),
        iconColor: Color(hex: "#7F1D1D"),
        titleColor: Color(hex: "#7F1D1D"),
        messageColor: Color(hex: "#7F1D1D"),
        closeBackground: .white,
        closeBorder: Color(hex: "#7F1D1D"),
        closeColor: Color(hex: "#7F1D1D"),
        borderWidth: 2,
        iconBorderWidth: 2,
        closeBorderWidth: 2
      )
    }
  }

  if themeMode == "dark" {
    switch state {
    case "listening":
      return MacToastPalette(
        background: Color(hex: "#0F172A"),
        border: Color(hex: "#3B82F6"),
        iconBackground: Color(hex: "#1D4ED8"),
        iconBorder: .clear,
        iconColor: Color(hex: "#DBEAFE"),
        titleColor: .white,
        messageColor: Color(hex: "#CBD5E1"),
        closeBackground: .clear,
        closeBorder: .clear,
        closeColor: Color(hex: "#DBEAFE"),
        borderWidth: 1.5,
        iconBorderWidth: 0,
        closeBorderWidth: 0
      )
    case "processing":
      return MacToastPalette(
        background: Color(hex: "#1F2937"),
        border: Color(hex: "#F59E0B"),
        iconBackground: Color(hex: "#78350F"),
        iconBorder: .clear,
        iconColor: Color(hex: "#FDE68A"),
        titleColor: .white,
        messageColor: Color(hex: "#E5E7EB"),
        closeBackground: .clear,
        closeBorder: .clear,
        closeColor: Color(hex: "#FCD34D"),
        borderWidth: 1.5,
        iconBorderWidth: 0,
        closeBorderWidth: 0
      )
    case "success":
      return MacToastPalette(
        background: Color(hex: "#14532D"),
        border: Color(hex: "#22C55E"),
        iconBackground: Color(hex: "#166534"),
        iconBorder: .clear,
        iconColor: Color(hex: "#DCFCE7"),
        titleColor: .white,
        messageColor: Color(hex: "#D1FAE5"),
        closeBackground: .clear,
        closeBorder: .clear,
        closeColor: Color(hex: "#BBF7D0"),
        borderWidth: 1.5,
        iconBorderWidth: 0,
        closeBorderWidth: 0
      )
    case "warning":
      return MacToastPalette(
        background: Color(hex: "#7C2D12"),
        border: Color(hex: "#FB923C"),
        iconBackground: Color(hex: "#9A3412"),
        iconBorder: .clear,
        iconColor: Color(hex: "#FFEDD5"),
        titleColor: .white,
        messageColor: Color(hex: "#FED7AA"),
        closeBackground: .clear,
        closeBorder: .clear,
        closeColor: Color(hex: "#FED7AA"),
        borderWidth: 1.5,
        iconBorderWidth: 0,
        closeBorderWidth: 0
      )
    case "error":
      return MacToastPalette(
        background: Color(hex: "#7F1D1D"),
        border: Color(hex: "#EF4444"),
        iconBackground: Color(hex: "#991B1B"),
        iconBorder: .clear,
        iconColor: Color(hex: "#FEE2E2"),
        titleColor: .white,
        messageColor: Color(hex: "#FECACA"),
        closeBackground: .clear,
        closeBorder: .clear,
        closeColor: Color(hex: "#FCA5A5"),
        borderWidth: 1.5,
        iconBorderWidth: 0,
        closeBorderWidth: 0
      )
    default:
      return MacToastPalette(
        background: Color(hex: "#0F172A"),
        border: Color(hex: "#334155"),
        iconBackground: Color(hex: "#1E3A8A"),
        iconBorder: .clear,
        iconColor: Color(hex: "#BFDBFE"),
        titleColor: .white,
        messageColor: Color(hex: "#CBD5E1"),
        closeBackground: .clear,
        closeBorder: .clear,
        closeColor: Color(hex: "#CBD5E1"),
        borderWidth: 1.5,
        iconBorderWidth: 0,
        closeBorderWidth: 0
      )
    }
  }

  switch state {
  case "listening":
    return MacToastPalette(
      background: .white,
      border: Color(hex: "#BFDBFE"),
      iconBackground: Color(hex: "#DBEAFE"),
      iconBorder: .clear,
      iconColor: Color(hex: "#2563EB"),
      titleColor: Color(hex: "#0F172A"),
      messageColor: Color(hex: "#475569"),
      closeBackground: .clear,
      closeBorder: .clear,
      closeColor: Color(hex: "#94A3B8"),
      borderWidth: 1,
      iconBorderWidth: 0,
      closeBorderWidth: 0
    )
  case "processing":
    return MacToastPalette(
      background: .white,
      border: Color(hex: "#FDE68A"),
      iconBackground: Color(hex: "#FEF3C7"),
      iconBorder: .clear,
      iconColor: Color(hex: "#F59E0B"),
      titleColor: Color(hex: "#0F172A"),
      messageColor: Color(hex: "#475569"),
      closeBackground: .clear,
      closeBorder: .clear,
      closeColor: Color(hex: "#94A3B8"),
      borderWidth: 1,
      iconBorderWidth: 0,
      closeBorderWidth: 0
    )
  case "success":
    return MacToastPalette(
      background: .white,
      border: Color(hex: "#BBF7D0"),
      iconBackground: Color(hex: "#DCFCE7"),
      iconBorder: .clear,
      iconColor: Color(hex: "#16A34A"),
      titleColor: Color(hex: "#0F172A"),
      messageColor: Color(hex: "#475569"),
      closeBackground: .clear,
      closeBorder: .clear,
      closeColor: Color(hex: "#94A3B8"),
      borderWidth: 1,
      iconBorderWidth: 0,
      closeBorderWidth: 0
    )
  case "warning":
    return MacToastPalette(
      background: .white,
      border: Color(hex: "#FDE68A"),
      iconBackground: Color(hex: "#FFF7ED"),
      iconBorder: .clear,
      iconColor: Color(hex: "#EA580C"),
      titleColor: Color(hex: "#0F172A"),
      messageColor: Color(hex: "#475569"),
      closeBackground: .clear,
      closeBorder: .clear,
      closeColor: Color(hex: "#94A3B8"),
      borderWidth: 1,
      iconBorderWidth: 0,
      closeBorderWidth: 0
    )
  case "error":
    return MacToastPalette(
      background: .white,
      border: Color(hex: "#FECACA"),
      iconBackground: Color(hex: "#FEE2E2"),
      iconBorder: .clear,
      iconColor: Color(hex: "#DC2626"),
      titleColor: Color(hex: "#0F172A"),
      messageColor: Color(hex: "#475569"),
      closeBackground: .clear,
      closeBorder: .clear,
      closeColor: Color(hex: "#94A3B8"),
      borderWidth: 1,
      iconBorderWidth: 0,
      closeBorderWidth: 0
    )
  default:
    return MacToastPalette(
      background: .white,
      border: Color(hex: "#E2E8F0"),
      iconBackground: Color(hex: "#EFF6FF"),
      iconBorder: .clear,
      iconColor: Color(hex: "#2563EB"),
      titleColor: Color(hex: "#0F172A"),
      messageColor: Color(hex: "#475569"),
      closeBackground: .clear,
      closeBorder: .clear,
      closeColor: Color(hex: "#94A3B8"),
      borderWidth: 1,
      iconBorderWidth: 0,
      closeBorderWidth: 0
    )
  }
}

private extension Color {
  init(hex: String) {
    let cleaned = hex.replacingOccurrences(of: "#", with: "")
    var int: UInt64 = 0
    Scanner(string: cleaned).scanHexInt64(&int)
    let r = Double((int >> 16) & 0xff) / 255.0
    let g = Double((int >> 8) & 0xff) / 255.0
    let b = Double(int & 0xff) / 255.0
    self.init(red: r, green: g, blue: b)
  }
}
