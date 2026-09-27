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
    @State private var confirmation: String?
    @State private var showShareError = false

    var body: some View {
        NavigationStack {
            Image(uiImage: photo.image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black)
                .accessibilityLabel("Photo with your drawing")
                .accessibilityIdentifier("capturedPhoto")
                .overlay(alignment: .bottom) {
                    if let confirmation {
                        Label(confirmation, systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Color(red: 0.06, green: 0.40, blue: 0.20), in: Capsule())
                            .padding()
                            .accessibilityIdentifier("shareConfirmation")
                    }
                }
                .navigationTitle("Your photo")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        PhotoShareButton(image: photo.image, onStart: {
                            confirmation = nil
                        }, onCompletion: finishSharing)
                    }
                }
        }
        .preferredColorScheme(.dark)
        .alert("Couldn't share photo", isPresented: $showShareError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Please try sharing your photo again.")
        }
    }

    private func finishSharing(_ outcome: PhotoShareOutcome) {
        showShareError = outcome == .failed
        confirmation = outcome.confirmation
        if let confirmation {
            UIAccessibility.post(notification: .announcement, argument: confirmation)
        }
    }
}
