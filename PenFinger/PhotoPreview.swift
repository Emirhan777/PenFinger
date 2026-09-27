import SwiftUI
import UIKit

struct CapturedPhoto: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct CaptureAlert: Identifiable {
    let id = UUID()
    let message: String
}

struct PhotoPreview: View {
    let photo: CapturedPhoto
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .accessibilityLabel("Photo with your drawing")
                .accessibilityIdentifier("capturedPhoto")
                .navigationTitle("Your photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        ShareLink(item: Image(uiImage: photo.image),
                                  preview: SharePreview("PenFinger photo", image: Image(uiImage: photo.image))) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        .accessibilityIdentifier("sharePhotoButton")
                    }
                }
        }
        .preferredColorScheme(.dark)
    }
}
