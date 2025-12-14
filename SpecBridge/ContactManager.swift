import Foundation
import Combine
import Contacts
import ContactsUI
import UIKit

class ContactManager: ObservableObject {
    @Published var authorizationStatus: CNAuthorizationStatus = .notDetermined
    
    private let store = CNContactStore()
    
    init() {
        checkAuthorization()
    }
    
    func checkAuthorization() {
        authorizationStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAccess() async -> Bool {
        do {
            let granted = try await store.requestAccess(for: .contacts)
            await MainActor.run {
                self.authorizationStatus = granted ? .authorized : .denied
            }
            return granted
        } catch {
            print("Contact access error: \(error)")
            return false
        }
    }
    
    /// Create a new contact with name and photo
    func createContact(firstName: String, lastName: String?, photo: UIImage) async throws -> CNContact {
        // Check authorization
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw ContactError.notAuthorized
            }
        }
        
        let contact = CNMutableContact()
        contact.givenName = firstName
        if let lastName = lastName {
            contact.familyName = lastName
        }
        
        // Set photo
        if let imageData = photo.jpegData(compressionQuality: 0.9) {
            contact.imageData = imageData
        }
        
        // Save
        let saveRequest = CNSaveRequest()
        saveRequest.add(contact, toContainerWithIdentifier: nil)
        try store.execute(saveRequest)
        
        return contact
    }
    
    /// Add photo to an existing contact
    func addPhotoToContact(_ contact: CNContact, photo: UIImage) async throws {
        // Check authorization
        if authorizationStatus != .authorized {
            let granted = await requestAccess()
            if !granted {
                throw ContactError.notAuthorized
            }
        }
        
        guard let mutableContact = contact.mutableCopy() as? CNMutableContact else {
            throw ContactError.updateFailed
        }
        
        if let imageData = photo.jpegData(compressionQuality: 0.9) {
            mutableContact.imageData = imageData
        }
        
        let saveRequest = CNSaveRequest()
        saveRequest.update(mutableContact)
        try store.execute(saveRequest)
    }
    
    /// Search contacts by name
    func searchContacts(query: String) -> [CNContact] {
        guard authorizationStatus == .authorized else { return [] }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        
        do {
            let predicate = CNContact.predicateForContacts(matchingName: query)
            return try store.unifiedContacts(matching: predicate, keysToFetch: keysToFetch)
        } catch {
            print("Search error: \(error)")
            return []
        }
    }
    
    /// Fetch all contacts (for picker)
    func fetchAllContacts() -> [CNContact] {
        guard authorizationStatus == .authorized else { return [] }
        
        let keysToFetch: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactThumbnailImageDataKey as CNKeyDescriptor,
            CNContactIdentifierKey as CNKeyDescriptor
        ]
        
        var contacts: [CNContact] = []
        let request = CNContactFetchRequest(keysToFetch: keysToFetch)
        request.sortOrder = .givenName
        
        do {
            try store.enumerateContacts(with: request) { contact, _ in
                contacts.append(contact)
            }
        } catch {
            print("Fetch error: \(error)")
        }
        
        return contacts
    }
}

enum ContactError: LocalizedError {
    case notAuthorized
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .notAuthorized:
            return "Contact access not authorized"
        case .updateFailed:
            return "Failed to update contact"
        }
    }
}

