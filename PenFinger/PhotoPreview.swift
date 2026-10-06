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
    let saveStatus: PhotoSaveStatus
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
                    } else {
                        saveStatusView
                            .font(.headline)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(saveStatus == .saved
                                        ? Color(red: 0.06, green: 0.40, blue: 0.20)
                                        : Color.black.opacity(0.8),
                                        in: RoundedRectangle(cornerRadius: 20))
                            .padding()
                            .accessibilityIdentifier("photoSaveStatus")
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

    @ViewBuilder
    private var saveStatusView: some View {
        switch saveStatus {
        case .saving:
            HStack(spacing: 8) {
                ProgressView().tint(.white)
                Text("Saving to Photos…")
            }
        case .saved:
            Label("Saved to Photos", systemImage: "checkmark.circle.fill")
        case .failed(let error):
            VStack(spacing: 8) {
                Label("Photo wasn't saved", systemImage: "exclamationmark.triangle.fill")
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .multilineTextAlignment(.center)
                if error == .accessDenied {
                    Link("Open Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                }
            }
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
