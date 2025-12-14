import SwiftUI
import MWDATCore
import Contacts

struct ContentView: View {
    @StateObject private var streamManager = StreamManager()
    @StateObject private var contactManager = ContactManager()
    
    @State private var capturedPhoto: UIImage?
    @State private var showCaptureSheet = false
    @State private var isRegistered = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FaceTag")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(streamManager.status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding()
            
            // Video Feed
            ZStack {
                Color.black
                
                if let frame = streamManager.currentFrame {
                    Image(uiImage: frame)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "eyeglasses")
                            .font(.system(size: 60))
                            .foregroundStyle(.gray.opacity(0.5))
                        Text("Connect your glasses to begin")
                            .font(.subheadline)
                            .foregroundStyle(.gray)
                    }
                }
                
                // Capture button overlay
                if streamManager.isStreaming {
                    VStack {
                        Spacer()
                        Button {
                            capturePhoto()
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(.white)
                                    .frame(width: 72, height: 72)
                                Circle()
                                    .stroke(.white, lineWidth: 4)
                                    .frame(width: 82, height: 82)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .frame(maxHeight: .infinity)
            
            // Bottom controls
            VStack(spacing: 16) {
                if !streamManager.isStreaming {
                    if !isRegistered {
                        Button {
                            try? Wearables.shared.startRegistration()
                        } label: {
                            Label("Connect Glasses", systemImage: "link")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                    
                    Button {
                        Task {
                            await streamManager.startStreaming()
                        }
                    } label: {
                        Label("Start Camera", systemImage: "video.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    Button {
                        Task {
                            await streamManager.stopStreaming()
                        }
                    } label: {
                        Label("Stop Camera", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .onOpenURL { url in
            Task {
                try? await Wearables.shared.handleUrl(url)
                isRegistered = true
            }
        }
        .sheet(isPresented: $showCaptureSheet) {
            if let photo = capturedPhoto {
                CaptureSheet(
                    photo: photo,
                    contactManager: contactManager,
                    onDismiss: {
                        showCaptureSheet = false
                        capturedPhoto = nil
                    }
                )
            }
        }
        .onAppear {
            Task {
                _ = await contactManager.requestAccess()
            }
        }
    }
    
    private func capturePhoto() {
        if let photo = streamManager.capturePhoto() {
            capturedPhoto = photo
            showCaptureSheet = true
        }
    }
}

// MARK: - Capture Sheet
struct CaptureSheet: View {
    let photo: UIImage
    @ObservedObject var contactManager: ContactManager
    let onDismiss: () -> Void
    
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var showContactPicker = false
    @State private var isSaving = false
    @State private var showSuccess = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Photo preview
                Image(uiImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(radius: 8)
                    .padding(.top)
                
                // Name input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Who is this?")
                        .font(.headline)
                    
                    TextField("First name", text: $firstName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.givenName)
                        .autocorrectionDisabled()
                    
                    TextField("Last name (optional)", text: $lastName)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.familyName)
                        .autocorrectionDisabled()
                }
                .padding(.horizontal)
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                
                Spacer()
                
                // Action buttons
                VStack(spacing: 12) {
                    Button {
                        createNewContact()
                    } label: {
                        Label("Create New Contact", systemImage: "person.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(firstName.isEmpty || isSaving)
                    
                    Button {
                        showContactPicker = true
                    } label: {
                        Label("Add to Existing Contact", systemImage: "person.crop.circle.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(isSaving)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Save Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onDismiss()
                    }
                }
            }
            .sheet(isPresented: $showContactPicker) {
                ContactPickerView(photo: photo, contactManager: contactManager) {
                    showSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onDismiss()
                    }
                }
            }
            .overlay {
                if showSuccess {
                    SuccessOverlay()
                }
            }
        }
    }
    
    private func createNewContact() {
        isSaving = true
        errorMessage = nil
        
        Task {
            do {
                _ = try await contactManager.createContact(
                    firstName: firstName,
                    lastName: lastName.isEmpty ? nil : lastName,
                    photo: photo
                )
                await MainActor.run {
                    showSuccess = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        onDismiss()
                    }
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    isSaving = false
                }
            }
        }
    }
}

// MARK: - Contact Picker
struct ContactPickerView: View {
    let photo: UIImage
    @ObservedObject var contactManager: ContactManager
    let onComplete: () -> Void
    
    @State private var searchText = ""
    @State private var contacts: [CNContact] = []
    @State private var isSaving = false
    @Environment(\.dismiss) var dismiss
    
    var filteredContacts: [CNContact] {
        if searchText.isEmpty {
            return contacts
        }
        return contacts.filter { contact in
            let name = "\(contact.givenName) \(contact.familyName)".lowercased()
            return name.contains(searchText.lowercased())
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredContacts, id: \.identifier) { contact in
                Button {
                    addPhotoToContact(contact)
                } label: {
                    HStack(spacing: 12) {
                        // Contact avatar
                        if let imageData = contact.thumbnailImageData,
                           let image = UIImage(data: imageData) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 44, height: 44)
                                .clipShape(Circle())
                        } else {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(.gray)
                        }
                        
                        VStack(alignment: .leading) {
                            Text("\(contact.givenName) \(contact.familyName)")
                                .foregroundStyle(.primary)
                        }
                        
                        Spacer()
                    }
                }
                .disabled(isSaving)
            }
            .searchable(text: $searchText, prompt: "Search contacts")
            .navigationTitle("Select Contact")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                contacts = contactManager.fetchAllContacts()
            }
        }
    }
    
    private func addPhotoToContact(_ contact: CNContact) {
        isSaving = true
        
        Task {
            do {
                try await contactManager.addPhotoToContact(contact, photo: photo)
                await MainActor.run {
                    onComplete()
                    dismiss()
                }
            } catch {
                print("Error: \(error)")
                isSaving = false
            }
        }
    }
}

// MARK: - Success Overlay
struct SuccessOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.green)
                Text("Saved!")
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        }
    }
}

#Preview {
    ContentView()
}
