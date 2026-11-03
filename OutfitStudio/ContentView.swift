import SwiftUI
import PhotosUI

private let ink = Color(red: 0.18, green: 0.20, blue: 0.17)
private let paper = Color(red: 0.97, green: 0.96, blue: 0.93)

struct ContentView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    HStack {
                        Text("OUTFIT STUDIO").font(.caption.weight(.semibold)).tracking(3)
                        Spacer()
                        Image(systemName: "sparkle")
                    }
                    .padding(.top, 20)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Your style.\nYour canvas.")
                            .font(.system(size: 48, weight: .regular, design: .serif))
                        Text("A little inspiration. A look that’s entirely you.")
                            .foregroundStyle(.secondary)
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 24).fill(Color(red: 0.88, green: 0.86, blue: 0.80))
                        HStack(spacing: 18) {
                            inspirationTile("tshirt.fill", label: "THE ESSENTIALS", angle: -9)
                            inspirationTile("handbag.fill", label: "YOUR SIGNATURE", angle: 9)
                        }.padding(28)
                    }.frame(height: 240)
                    .accessibilityLabel("Style inspiration: clothing and accessories")

                    NavigationLink {
                        CollageEditor()
                    } label: {
                        HStack {
                            Image(systemName: "plus")
                            Text("Create New Collage")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.headline).padding(22)
                        .foregroundStyle(.white).background(ink, in: RoundedRectangle(cornerRadius: 18))
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("A LOOK STARTS WITH AN IDEA").font(.caption.weight(.semibold)).tracking(2)
                        Text("Add your photos, arrange your pieces, and make room for inspiration.")
                            .font(.system(size: 23, design: .serif))
                        Text("This first version is a workspace for experimenting. Saving your collages is coming next.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(24)
            }
            .background(paper).foregroundStyle(ink)
            .toolbar(.hidden, for: .navigationBar)
        }.tint(ink)
    }

    private func inspirationTile(_ symbol: String, label: String, angle: Double) -> some View {
        VStack(spacing: 24) {
            Image(systemName: symbol).font(.system(size: 64, weight: .ultraLight))
            Text(label).font(.system(size: 8, weight: .medium)).tracking(1)
        }
        .frame(maxWidth: .infinity).frame(height: 165)
        .background(paper, in: RoundedRectangle(cornerRadius: 4))
        .rotationEffect(.degrees(angle))
        .shadow(color: .black.opacity(0.08), radius: 10, y: 8)
    }
}

private struct CollagePiece: Identifiable {
    let id = UUID()
    var image: UIImage
    var offset: CGSize = .zero
    var scale: CGFloat = 1
    var rotation: Angle = .zero
}

private struct CollageEditor: View {
    @State private var pieces: [CollagePiece] = []
    @State private var selection: UUID?
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var backgroundIndex = 0
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var confirmClear = false
    private let backgrounds: [Color] = [.white, paper, Color(red: 0.85, green: 0.89, blue: 0.82), Color(red: 0.94, green: 0.84, blue: 0.82), Color(red: 0.20, green: 0.22, blue: 0.23)]

    var body: some View {
        VStack(spacing: 18) {
            HStack {
                Text("Make it yours").font(.system(size: 28, design: .serif))
                Spacer()
                if loading { ProgressView() }
                Text("\(pieces.count) photos").font(.caption).foregroundStyle(.secondary)
            }

            canvas

            Text("Select a photo · Drag to move · Pinch to resize · Twist to rotate")
                .font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)

            backgroundControls

            HStack {
                PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                    Label("Add Photos", systemImage: "plus")
                        .font(.headline).padding(16).frame(maxWidth: .infinity)
                        .foregroundStyle(.white).background(ink, in: RoundedRectangle(cornerRadius: 14))
                }.disabled(loading)
                Button {
                    pieces.removeAll { $0.id == selection }
                    selection = nil
                } label: {
                    Image(systemName: "trash").padding(18)
                }
                .disabled(selection == nil)
                .accessibilityLabel("Delete selected photo")
            }
            Text("Draft only — leaving this editor discards your collage.")
                .font(.caption2).foregroundStyle(.secondary)
        }
        .padding(20).frame(maxHeight: .infinity, alignment: .top)
        .background(paper)
        .navigationTitle("New Collage").navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("Clear") { confirmClear = true }.disabled(pieces.isEmpty)
        }
        .confirmationDialog("Remove all photos?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear canvas", role: .destructive) { pieces = []; selection = nil }
        }
        .alert("Couldn’t load photo", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
        .onChange(of: photoItems) { _, items in
            guard !items.isEmpty else { return }
            Task { @MainActor in
                loading = true
                defer { loading = false; photoItems = [] }
                for item in items {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self),
                              let image = UIImage(data: data) else {
                            errorMessage = "Please try another image."
                            continue
                        }
                        // Decode a bounded thumbnail to keep multiple large photos responsive.
                        let thumbnail = await image.byPreparingThumbnail(ofSize: CGSize(width: 1200, height: 1200)) ?? image
                        let piece = CollagePiece(image: thumbnail)
                        pieces.append(piece)
                        selection = piece.id
                    } catch {
                        errorMessage = "The image is unavailable. Check your connection if it is stored in iCloud, then try again."
                    }
                }
            }
        }
    }

    private var canvas: some View {
        GeometryReader { geometry in
            ZStack {
                backgrounds[backgroundIndex]
                    .onTapGesture { selection = nil }
                if pieces.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.on.rectangle.angled").font(.largeTitle)
                        Text("Your next look starts here").font(.system(size: 22, design: .serif))
                        Text("Tap Add Photos below").font(.footnote)
                    }
                    .foregroundStyle(backgroundIndex == 4 ? .white : ink)
                    .allowsHitTesting(false)
                }
                ForEach($pieces) { $piece in
                    PieceView(piece: $piece, selected: selection == piece.id,
                              size: min(geometry.size.width, geometry.size.height) * 0.46,
                              select: { selection = piece.id })
                    .zIndex(selection == piece.id ? 1 : 0)
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(.black.opacity(0.08)))
        }
        .aspectRatio(0.8, contentMode: .fit)
    }

    private var backgroundControls: some View {
        HStack(spacing: 14) {
            Text("Background").font(.caption)
            ForEach(backgrounds.indices, id: \.self) { index in
                Button { backgroundIndex = index } label: {
                    Circle().fill(backgrounds[index]).frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(backgroundIndex == index ? ink : .gray.opacity(0.3), lineWidth: backgroundIndex == index ? 3 : 1))
                }
                .accessibilityLabel(["White", "Cream", "Sage", "Blush", "Charcoal"][index])
                .accessibilityAddTraits(backgroundIndex == index ? .isSelected : [])
            }
        }
    }

}

private struct PieceView: View {
    @Binding var piece: CollagePiece
    let selected: Bool
    let size: CGFloat
    let select: () -> Void
    @GestureState private var drag: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1
    @GestureState private var rotation: Angle = .zero

    var body: some View {
        Image(uiImage: piece.image)
            .resizable().scaledToFit().frame(width: size, height: size)
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 3).stroke(ink.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                }
            }
            .scaleEffect(clamp(piece.scale * magnification))
            .rotationEffect(piece.rotation + rotation)
            .offset(x: piece.offset.width + drag.width, y: piece.offset.height + drag.height)
            .onTapGesture(perform: select)
            .gesture(dragGesture)
            .simultaneousGesture(resizeGesture)
            .simultaneousGesture(rotationGesture)
            .accessibilityLabel("Collage photo")
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .updating($drag) { value, state, _ in state = value.translation }
            .onChanged { _ in select() }
            .onEnded { value in
                piece.offset.width += value.translation.width
                piece.offset.height += value.translation.height
            }
    }

    private var resizeGesture: some Gesture {
        MagnifyGesture()
            .updating($magnification) { value, state, _ in state = value.magnification }
            .onChanged { _ in select() }
            .onEnded { value in piece.scale = clamp(piece.scale * value.magnification) }
    }

    private var rotationGesture: some Gesture {
        RotateGesture()
            .updating($rotation) { value, state, _ in state = value.rotation }
            .onChanged { _ in select() }
            .onEnded { value in piece.rotation += value.rotation }
    }

    private func clamp(_ value: CGFloat) -> CGFloat { min(max(value, 0.25), 4) }
}

#Preview { ContentView() }
