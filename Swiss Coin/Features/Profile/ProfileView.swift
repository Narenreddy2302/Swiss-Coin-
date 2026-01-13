import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    
    // Hardcoded for now as per plan, since we don't have a structured "Me" user model yet
    let profileImageName = "person.crop.circle.fill" 
    let userName = "Naren Reddy"
    let userEmail = "naren@example.com"

    var body: some View {
        NavigationView {
            List {
                // Header Profile Section
                Section {
                    HStack(spacing: 16) {
                        Image("uploaded_image_1768262251873") // Try to use asset if available, otherwise fallback handles it
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
                            .onAppear {
                                // Fallback logic if image load fails would go here in a real app
                                // For now we rely on the system to handle missing assets or use a placeholder in ProfileButton
                            }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.semibold)
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
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
