import SwiftUI

struct IntertitleEditorSheet: View {
    let existingCard: IntertitleCard?
    let clipCount: Int
    let onSave: (IntertitleCard) -> Void
    let onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var duration: TimeInterval
    @State private var position: Int
    @FocusState private var textFocused: Bool

    init(
        card: IntertitleCard?,
        clipCount: Int,
        onSave: @escaping (IntertitleCard) -> Void,
        onDelete: (() -> Void)? = nil
    ) {
        existingCard = card
        self.clipCount = clipCount
        self.onSave = onSave
        self.onDelete = onDelete
        _text = State(initialValue: card?.text ?? "")
        _duration = State(initialValue: card?.duration ?? 2)
        _position = State(initialValue: min(card?.position ?? clipCount, clipCount))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Card text") {
                    TextField("Intertitle", text: $text, axis: .vertical)
                        .lineLimit(2...5)
                        .focused($textFocused)
                        .submitLabel(.done)
                    Text("\(text.count)/120 characters")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("Timing") {
                    Picker("Position", selection: $position) {
                        ForEach(0...clipCount, id: \.self) { value in
                            Text(positionLabel(value)).tag(value)
                        }
                    }
                    LabeledContent("Duration", value: String(format: "%.1f seconds", duration))
                    Slider(value: $duration, in: 0.5...5, step: 0.5)
                        .accessibilityLabel("Intertitle duration")
                }

                if existingCard != nil, let onDelete {
                    Section {
                        Button("Remove Card", role: .destructive) {
                            onDelete()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle(existingCard == nil ? "New Intertitle" : "Edit Intertitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let card = IntertitleCard(
                            id: existingCard?.id ?? UUID(),
                            text: text,
                            duration: duration,
                            position: position
                        )
                        onSave(card)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { textFocused = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func positionLabel(_ value: Int) -> String {
        if value == 0 { return "Before first clip" }
        if value == clipCount { return "After last clip" }
        return "Between clips \(value) and \(value + 1)"
    }
}
