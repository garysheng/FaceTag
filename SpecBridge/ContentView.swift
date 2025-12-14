import SwiftUI
import MWDATCore
import Contacts

struct ContentView: View {
    @StateObject private var captureManager = CaptureManager()
    @StateObject private var contactManager = ContactManager()
    
    @State private var showCaptureSheet = false
    @State private var isRegistered = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Icon and status
            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(captureManager.isConnected ? Color.green.opacity(0.15) : Color.gray.opacity(0.1))
                        .frame(width: 160, height: 160)
                    
                    Image(systemName: "eyeglasses")
                        .font(.system(size: 64))
                        .foregroundStyle(captureManager.isConnected ? .green : .gray)
                }
                
                Text("FaceTag")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(captureManager.status)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
            
            // Instructions when connected
            if captureManager.isConnected {
                VStack(spacing: 8) {
                    Image(systemName: "hand.tap.fill")
                        .font(.title)
                        .foregroundStyle(.blue)
                    Text("Tap Capture Photo below")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Controls
            VStack(spacing: 12) {
                if !captureManager.isConnected {
                    Button {
                        try? Wearables.shared.startRegistration()
                    } label: {
                        Label("Connect to Meta View", systemImage: "link")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button {
                        Task {
                            await captureManager.startListening()
                        }
                    } label: {
                        Label("Start Camera", systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    // Manual capture button
                    Button {
                        captureManager.capturePhoto()
                    } label: {
                        Label("Capture Photo", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    
                    Button {
                        Task {
                            await captureManager.stopListening()
                        }
                    } label: {
                        Label("Disconnect", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .onOpenURL { url in
            Task {
                try? await Wearables.shared.handleUrl(url)
                isRegistered = true
            }
        }
        .onChange(of: captureManager.capturedPhoto) { _, newPhoto in
            if newPhoto != nil {
                showCaptureSheet = true
            }
        }
        .sheet(isPresented: $showCaptureSheet) {
            if let photo = captureManager.capturedPhoto {
                CaptureSheet(
                    photo: photo,
                    contactManager: contactManager,
                    onDismiss: {
                        showCaptureSheet = false
                        captureManager.clearPhoto()
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
                        
                        Text("\(contact.givenName) \(contact.familyName)")
                            .foregroundStyle(.primary)
                        
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
