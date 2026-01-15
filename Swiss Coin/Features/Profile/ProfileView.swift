import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss

    // TODO: Replace with actual authenticated user data
    let userName = "No user logged in"
    let userEmail = ""

    var body: some View {
        NavigationView {
            List {
                // Header Profile Section
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            if !userEmail.isEmpty {
                                Text(userEmail)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }

                // Account Settings
                Section("Account") {
                    NavigationLink(destination: Text("Personal Details")) {
                        Label("Personal Details", systemImage: "person.text.rectangle")
                    }
                    NavigationLink(destination: Text("Notifications")) {
                        Label("Notifications", systemImage: "bell")
                    }
                    NavigationLink(destination: Text("Privacy & Security")) {
                        Label("Privacy & Security", systemImage: "lock")
                    }
                }

                // App Settings
                Section("Preferences") {
                    NavigationLink(destination: Text("Appearance")) {
                        Label("Appearance", systemImage: "paintbrush")
                    }
                    NavigationLink(destination: Text("Currency")) {
                        Label("Currency", systemImage: "dollarsign.circle")
                    }
                }

                Section {
                    Button(action: {
                        // Sign out logic
                    }) {
                        Text("Log Out")
                            .foregroundColor(.red)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    ProfileView()
}
