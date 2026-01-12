import ContactsUI
import CoreData
import SwiftUI

struct AddPersonView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.presentationMode) var presentationMode

    @State private var showingContactPicker = false
    @State private var name: String = ""
    @State private var phoneNumber: String = ""

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                TextField("Phone Number", text: $phoneNumber)
                    .keyboardType(.phonePad)
            }

            Section {
                Button(action: { showingContactPicker = true }) {
                    Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                }
            }

            Section {
                Button("Save Person") {
                    addPerson()
                }
                .disabled(name.isEmpty)
            }
        }
        .navigationTitle("Add Person")
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker(name: $name, phoneNumber: $phoneNumber)
        }
    }

    private func addPerson() {
        let newPerson = Person(context: viewContext)
        newPerson.id = UUID()
        newPerson.name = name
        newPerson.phoneNumber = phoneNumber
        // Assign a random color hex for avatar
        newPerson.colorHex = "#" + String(Int.random(in: 0...0xFFFFFF), radix: 16)

        do {
            try viewContext.save()
            presentationMode.wrappedValue.dismiss()
        } catch {
            print("Error saving person: \(error)")
        }
    }
}

struct ContactPicker: UIViewControllerRepresentable {
    @Binding var name: String
    @Binding var phoneNumber: String

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        picker.displayedPropertyKeys = [
            CNContactPhoneNumbersKey, CNContactGivenNameKey, CNContactFamilyNameKey,
        ]
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context)
    {}

    class Coordinator: NSObject, CNContactPickerDelegate {
        var parent: ContactPicker

        init(_ parent: ContactPicker) {
            self.parent = parent
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            let givenName = contact.givenName
            let familyName = contact.familyName
            parent.name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespaces)

            if let firstPhoneNumber = contact.phoneNumbers.first?.value.stringValue {
                parent.phoneNumber = firstPhoneNumber
            }
        }
    }
}
