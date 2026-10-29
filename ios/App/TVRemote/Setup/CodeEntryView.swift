import SwiftUI
import TVRemoteKit
import UIKit

/// The pairing screen: six boxes for the code the TV shows. One hidden text field takes the typing and pasting.
struct CodeEntryView: View {
    @Environment(ConnectionManager.self) private var connection

    /// The TV being paired; nil only when the app was started in the middle of a pairing (demo mode).
    let target: DiscoveredTV?
    let retry: (DiscoveredTV) -> Void
    let chooseAnother: () -> Void

    @State private var code = ""
    @State private var shakes: CGFloat = 0
    @FocusState private var isFocused: Bool

    private var step: ConnectionManager.PairingStep? {
        if case .pairing(let step) = connection.state { return step }
        return nil
    }

    /// Whether typed characters count: the TV is showing a code and no check is under way.
    private var isAccepting: Bool {
        step == .enterCode || step == .wrongCode
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if case .failed(let message) = step {
                failure(message)
            } else {
                entry
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: code) { _, new in
            let clean = PairingCode.sanitize(new)
            guard clean == new else {
                code = clean
                return
            }
            if isAccepting, let valid = PairingCode.normalize(clean) {
                Task { await connection.submitCode(valid) }
            }
        }
        .onChange(of: step) { _, new in
            switch new {
            case .enterCode:
                isFocused = true
            case .wrongCode:
                code = ""
                isFocused = true
                UINotificationFeedbackGenerator().notificationOccurred(.error)
                withAnimation(.easeOut(duration: 0.4)) { shakes += 1 }
            case .failed:
                isFocused = false
            default:
                break
            }
        }
        .task {
            // The field has to be on screen before it can take focus.
            try? await Task.sleep(for: .milliseconds(250))
            isFocused = isAccepting
        }
    }

    // MARK: - Entering the code

    private var entry: some View {
        VStack(alignment: .leading, spacing: 0) {
            SetupHeader(
                symbol: "tv",
                title: "Enter the code on your TV",
                subtitle: step == .connecting
                    ? "Your TV will show a code in a moment."
                    : "It has 6 characters: the numbers 0–9 and the letters A–F."
            )
            boxes.padding(.top, 36)
            status.padding(.top, 20)
            Button("Choose another TV", action: chooseAnother)
                .buttonStyle(QuietButtonStyle())
                .padding(.top, 20)
                .opacity(step == .checking ? 0 : 1)
        }
    }

    private var boxes: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { index in
                CodeBox(
                    character: character(at: index),
                    isCurrent: isAccepting && index == min(code.count, 5) && code.count < 6
                )
            }
        }
        .opacity(step == .connecting ? 0.4 : 1)
        .modifier(Shake(shakes: shakes))
        .accessibilityHidden(true)
        .overlay {
            TextField("Code from the TV", text: $code)
                .focused($isFocused)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .frame(width: 1, height: 1)
                .opacity(0.01)
        }
        .contentShape(Rectangle())
        .onTapGesture { if isAccepting { isFocused = true } }
        .contextMenu {
            if isAccepting {
                Button("Paste", systemImage: "doc.on.clipboard") {
                    code = PairingCode.sanitize(UIPasteboard.general.string ?? "")
                }
            }
        }
    }

    private func character(at index: Int) -> Character? {
        index < code.count ? code[code.index(code.startIndex, offsetBy: index)] : nil
    }

    /// One line under the boxes, always the same height so nothing jumps.
    @ViewBuilder
    private var status: some View {
        Group {
            switch step {
            case .connecting:
                progress("Connecting to \(target?.name ?? "the TV")…")
            case .checking:
                progress("Checking…")
            case .wrongCode:
                Text("That code didn't match. Check the TV and try again.")
                    .font(.system(size: 16))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .topLeading)
    }

    private func progress(_ text: String) -> some View {
        HStack(spacing: 10) {
            ProgressView().tint(Theme.secondary)
            Text(text)
                .font(.system(size: 16))
                .foregroundStyle(Theme.secondary)
        }
    }

    // MARK: - Failure

    private func failure(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SetupHeader(symbol: "wifi.exclamationmark", title: message, isSentence: true)
            Button("Try again") {
                if let target { retry(target) } else { chooseAnother() }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.top, 36)
            Button("Choose another TV", action: chooseAnother)
                .buttonStyle(QuietButtonStyle())
                .padding(.top, 12)
        }
    }
}

private struct CodeBox: View {
    let character: Character?
    /// The box the next character goes into.
    let isCurrent: Bool

    var body: some View {
        ZStack {
            if let character {
                Text(String(character))
                    .font(.system(size: 32, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.text)
            } else if isCurrent {
                Caret()
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 68)
        .background(Theme.surface2, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isCurrent ? Theme.accent : Theme.hairline, lineWidth: isCurrent ? 1.5 : 1)
        )
        .animation(.easeOut(duration: 0.12), value: isCurrent)
    }
}

/// The blinking bar in the box that is next.
private struct Caret: View {
    @State private var lit = true

    var body: some View {
        RoundedRectangle(cornerRadius: 1, style: .continuous)
            .fill(Theme.accent)
            .frame(width: 2, height: 30)
            .opacity(lit ? 1 : 0.15)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { lit = false }
            }
    }
}

/// Moves a view side to side while `shakes` counts up by one.
private struct Shake: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 9 * sin(shakes * .pi * 4), y: 0))
    }
}
