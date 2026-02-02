import ContactsUI
import CoreData
import SwiftUI

struct AddPersonView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @State private var showingContactPicker = false
    @State private var name: String = ""
    @State private var phoneNumber: String = ""
    @State private var showingDuplicateWarning = false
    @State private var duplicatePersonName: String = ""

    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Name", text: $name)
                    .font(AppTypography.body())
                TextField("Phone Number", text: $phoneNumber)
                    .font(AppTypography.body())
                    .keyboardType(.phonePad)
                    .onChange(of: phoneNumber) { _, newValue in
                        checkDuplicatePhone(newValue)
                    }

                if showingDuplicateWarning {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: IconSize.sm))
                            .foregroundColor(AppColors.warning)
                        Text("Phone number already used by \(duplicatePersonName)")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.warning)
                    }
                }
            }

            Section {
                Button(action: { 
                    HapticManager.tap()
                    showingContactPicker = true 
                }) {
                    Label("Import from Contacts", systemImage: "person.crop.circle.badge.plus")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.accent)
                }
            }

            Section {
                Button("Save Person") {
                    HapticManager.tap()
                    addPerson()
                }
                .disabled(name.isEmpty)
                .font(AppTypography.bodyBold())
                .foregroundColor(name.isEmpty ? AppColors.disabled : AppColors.accent)
            }
        }
        .navigationTitle("Add Person")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker(name: $name, phoneNumber: $phoneNumber)
        }
    }

    private func checkDuplicatePhone(_ phone: String) {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showingDuplicateWarning = false
            return
        }

        let fetchRequest: NSFetchRequest<Person> = Person.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "phoneNumber == %@", trimmed)
        fetchRequest.fetchLimit = 1

        do {
            let results = try viewContext.fetch(fetchRequest)
            if let existing = results.first {
                duplicatePersonName = existing.name ?? "another person"
                showingDuplicateWarning = true
            } else {
                showingDuplicateWarning = false
            }
        } catch {
            showingDuplicateWarning = false
        }
    }

    private func addPerson() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            HapticManager.error()
            return
        }
        
        let newPerson = Person(context: viewContext)
        newPerson.id = UUID()
        newPerson.name = trimmedName
        
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        newPerson.phoneNumber = trimmedPhone.isEmpty ? nil : trimmedPhone
        
        // Assign a random color hex for avatar - ensure proper 6-digit format
        let randomColor = Int.random(in: 0...0xFFFFFF)
        newPerson.colorHex = String(format: "#%06X", randomColor)

        do {
            try viewContext.save()
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
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
