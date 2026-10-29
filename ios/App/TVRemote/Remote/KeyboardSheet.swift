import SwiftUI
import TVRemoteKit

/// A text field for the TV's search box. Return or Send puts the text into the TV's field, Delete presses its
/// delete key. Without a text field on the TV it says what to do first.
struct KeyboardSheet: View {
    @Environment(ConnectionManager.self) private var connection

    @State private var text = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            TextField("Type on the TV", text: $text)
                .focused($isFocused)
                .submitLabel(.send)
                .onSubmit(send)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .tint(Theme.text)
                .font(.system(size: 17))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)
                .frame(height: 50)
                .background(Theme.surface3, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                )
            HStack(spacing: 10) {
                Button { connection.press(.del) } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "delete.left")
                            .font(.system(size: 16, weight: .medium))
                        Text("Delete")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(SheetButtonStyle(shape: RoundedRectangle(cornerRadius: 13, style: .continuous)))
                Button(action: send) {
                    Text("Send")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(canSend ? Theme.sheet : Theme.secondary)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(
                    SheetButtonStyle(
                        shape: RoundedRectangle(cornerRadius: 13, style: .continuous),
                        fill: canSend ? Theme.text : Theme.surface3,
                        pressedFill: canSend ? Theme.tileLabel : Theme.surface3
                    )
                )
                .disabled(!canSend)
            }
            if !connection.canType {
                Text("Select a search box on the TV first, then type here.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(210)])
        .presentationDragIndicator(.visible)
        .presentationBackground(Theme.sheet)
        .presentationCornerRadius(26)
        .onAppear { Haptics.prepare() }
        .task { isFocused = true }
    }

    private var canSend: Bool {
        connection.canType && !text.isEmpty
    }

    private func send() {
        guard canSend else { return }
        connection.type(text)
        text = ""
    }
}
