//
//  AddSubscriptionView.swift
//  Swiss Coin
//
//  Redesigned subscription creation with focus on simplicity and user experience.
//

import CoreData
import SwiftUI

struct AddSubscriptionView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) var dismiss

    let defaultIsShared: Bool
    
    // MARK: - Core State
    @State private var name = ""
    @State private var amount = ""
    @State private var cycle: BillingCycle = .monthly
    @State private var isShared = false
    @State private var selectedMembers: Set<Person> = []
    
    // MARK: - Optional State (collapsed by default)
    @State private var startDate = Date()
    @State private var selectedCategory = "Entertainment"
    @State private var notificationEnabled = true
    @State private var notificationDays = 3
    @State private var notes = ""
    @State private var showingAdvanced = false
    
    // MARK: - UI State
    @State private var showingMemberPicker = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isAnimating = false
    
    let categories = ["Entertainment", "Productivity", "Utilities", "Health", "Food", "Transportation", "Education", "Other"]
    
    init(isSharedDefault: Bool = false) {
        self.defaultIsShared = isSharedDefault
        _isShared = State(initialValue: isSharedDefault)
    }
    
    // MARK: - Validation
    private var canSave: Bool {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let amountValue = Double(amount) ?? 0
        let hasBasicInfo = !trimmedName.isEmpty && amountValue > 0
        if isShared {
            return hasBasicInfo && !selectedMembers.isEmpty
        }
        return hasBasicInfo
    }
    
    private var monthlyCost: Double {
        let value = Double(amount) ?? 0
        return cycle.monthlyEquivalent(for: value)
    }


    // MARK: - Body
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Live Preview Card
                    previewCard
                    
                    // Type Selector
                    typeSelector
                    
                    // Core Form
                    coreForm
                    
                    // Member Selection (if shared)
                    if isShared {
                        memberSection
                    }
                    
                    // Advanced Options Toggle
                    advancedToggle
                    
                    // Advanced Options (expandable)
                    if showingAdvanced {
                        advancedOptions
                    }
                    
                    Spacer(minLength: 100)
                }
            }
            .background(AppColors.backgroundSecondary)
            .navigationTitle("Add Subscription")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        HapticManager.cancel()
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveSubscription()
                    }
                    .disabled(!canSave)
                    .fontWeight(.semibold)
                    .foregroundColor(canSave ? AppColors.accent : AppColors.textSecondary)
                }
            }
            .sheet(isPresented: $showingMemberPicker) {
                MemberPickerView(selectedMembers: $selectedMembers)
                    .environment(\.managedObjectContext, viewContext)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    // MARK: - Preview Card
    private var previewCard: some View {
        VStack(spacing: Spacing.lg) {
            // Icon
            ZStack {
                Circle()
                    .fill(gradientForCategory)
                    .frame(width: 80, height: 80)
                
                Image(systemName: iconForCategory)
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .shadow(color: shadowColorForCategory, radius: 10, x: 0, y: 4)
            
            // Name
            Text(name.isEmpty ? "Subscription Name" : name)
                .font(AppTypography.title3())
                .foregroundColor(name.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)
                .multilineTextAlignment(.center)
            
            // Amount
            HStack(alignment: .firstTextBaseline, spacing: Spacing.xs) {
                Text(CurrencyFormatter.currencySymbol)
                    .font(AppTypography.title2())
                    .foregroundColor(AppColors.textSecondary)
                
                Text(amount.isEmpty ? "0" : amount)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.textPrimary)
            }
            
            // Cycle
            Text(cycle.displayName)
                .font(AppTypography.subheadline())
                .foregroundColor(AppColors.textSecondary)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(AppColors.backgroundTertiary)
                .clipShape(Capsule())
            
            // Monthly equivalent (for non-monthly cycles)
            if cycle != .monthly && !amount.isEmpty {
                Text("~ \(CurrencyFormatter.format(monthlyCost))/month")
                    .font(AppTypography.caption())
                    .foregroundColor(AppColors.textSecondary)
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(AppColors.background)
        .cornerRadius(CornerRadius.lg, corners: [.bottomLeft, .bottomRight])
        .shadow(color: Color(white: 0, opacity: 0.08), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Type Selector
    private var typeSelector: some View {
        VStack(spacing: Spacing.md) {
            HStack(spacing: Spacing.md) {
                TypeButton(
                    title: "Personal",
                    icon: "person.fill",
                    isSelected: !isShared
                ) {
                    withAnimation(AppAnimation.spring) {
                        isShared = false
                        selectedMembers.removeAll()
                    }
                    HapticManager.selectionChanged()
                }
                
                TypeButton(
                    title: "Shared",
                    icon: "person.2.fill",
                    isSelected: isShared
                ) {
                    withAnimation(AppAnimation.spring) {
                        isShared = true
                    }
                    HapticManager.selectionChanged()
                }
            }
            .padding(.horizontal, Spacing.lg)
        }
        .padding(.top, Spacing.lg)
    }
    
    // MARK: - Core Form
    private var coreForm: some View {
        VStack(spacing: 0) {
            // Name
            FormRow(icon: "textformat", title: "Name", color: AppColors.accent) {
                TextField("Netflix, Spotify, etc.", text: $name)
                    .font(AppTypography.body())
                    .limitTextLength(to: ValidationLimits.maxNameLength, text: $name)
                    .multilineTextAlignment(.trailing)
            }
            
            Divider().padding(.leading, 52)
            
            // Amount
            FormRow(icon: "dollarsign.circle", title: "Amount", color: AppColors.positive) {
                HStack(spacing: Spacing.xs) {
                    Text(CurrencyFormatter.currencySymbol)
                        .foregroundColor(AppColors.textSecondary)
                    TextField("0.00", text: $amount)
                        .keyboardType(.decimalPad)
                        .limitTextLength(to: 12, text: $amount)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Divider().padding(.leading, 52)
            
            // Cycle
            FormRow(icon: "calendar", title: "Billing", color: AppColors.warning) {
                Picker("", selection: $cycle) {
                    ForEach(BillingCycle.allCases) { cycle in
                        Text(cycle.displayName).tag(cycle)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.textPrimary)
            }
            
            Divider().padding(.leading, 52)
            
            // Category
            FormRow(icon: "tag", title: "Category", color: AppColors.textSecondary) {
                Picker("", selection: $selectedCategory) {
                    ForEach(categories, id: \.self) { category in
                        Label(category, systemImage: iconFor(category))
                            .tag(category)
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.textPrimary)
            }
        }
        .padding(.vertical, Spacing.sm)
        .background(AppColors.background)
        .cornerRadius(CornerRadius.md)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
    
    // MARK: - Member Section
    private var memberSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            // Header with add button
            HStack {
                Label("Split With", systemImage: "person.2")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Button {
                    HapticManager.tap()
                    showingMemberPicker = true
                } label: {
                    HStack(spacing: Spacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text("Add")
                    }
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.accent)
                }
            }
            
            if selectedMembers.isEmpty {
                // Empty state
                HStack(spacing: Spacing.md) {
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 24))
                        .foregroundColor(AppColors.textSecondary.opacity(0.5))
                    
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text("No members yet")
                            .font(AppTypography.body())
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text("Tap 'Add' to select people to split with")
                            .font(AppTypography.caption())
                            .foregroundColor(AppColors.textSecondary.opacity(0.7))
                    }
                    
                    Spacer()
                }
                .padding(.vertical, Spacing.md)
            } else {
                // Member chips
                let sortedMembers = Array(selectedMembers).sorted(by: { member1, member2 in
                    let name1 = member1.name ?? ""
                    let name2 = member2.name ?? ""
                    return name1 < name2
                })
                FlowLayout(spacing: Spacing.sm) {
                    ForEach(sortedMembers) { member in
                        MemberChip(person: member) {
                            _ = withAnimation(AppAnimation.quick) {
                                selectedMembers.remove(member)
                            }
                            HapticManager.tap()
                        }
                    }
                }
            }
            
            // Cost per person preview
            if !selectedMembers.isEmpty, let amountValue = Double(amount), amountValue > 0 {
                let perPerson = amountValue / Double(selectedMembers.count + 1) // +1 for current user
                HStack {
                    Text("Each person pays:")
                        .font(AppTypography.caption())
                        .foregroundColor(AppColors.textSecondary)
                    
                    Spacer()
                    
                    Text(CurrencyFormatter.format(perPerson))
                        .font(AppTypography.bodyBold())
                        .foregroundColor(AppColors.accent)
                }
                .padding(.top, Spacing.sm)
            }
        }
        .padding(Spacing.lg)
        .background(AppColors.background)
        .cornerRadius(CornerRadius.md)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
    
    // MARK: - Advanced Toggle
    private var advancedToggle: some View {
        Button {
            withAnimation(AppAnimation.standard) {
                showingAdvanced.toggle()
            }
            HapticManager.tap()
        } label: {
            HStack {
                Image(systemName: "gear")
                    .foregroundColor(AppColors.textSecondary)
                
                Text("Advanced Options")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                Image(systemName: showingAdvanced ? "chevron.up" : "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(Spacing.lg)
            .background(AppColors.background)
            .cornerRadius(CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.lg)
    }
    
    // MARK: - Advanced Options
    private var advancedOptions: some View {
        VStack(spacing: 0) {
            // Start Date
            FormRow(icon: "calendar.badge.clock", title: "Start Date", color: AppColors.textSecondary) {
                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            
            Divider().padding(.leading, 52)
            
            // Notifications
            FormRow(icon: "bell.badge", title: "Reminders", color: AppColors.warning) {
                Toggle("", isOn: $notificationEnabled)
                    .tint(AppColors.accent)
            }
            
            if notificationEnabled {
                Divider().padding(.leading, 52)
                
                HStack {
                    Text("Notify")
                        .font(AppTypography.body())
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Stepper("\(notificationDays) days before", value: $notificationDays, in: 1...14)
                        .labelsHidden()
                    
                    Text("\(notificationDays) days before")
                        .font(AppTypography.subheadline())
                        .foregroundColor(AppColors.textSecondary)
                        .frame(minWidth: 100, alignment: .trailing)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            }
            
            Divider().padding(.leading, 52)
            
            // Notes
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label("Notes", systemImage: "text.alignleft")
                    .font(AppTypography.subheadlineMedium())
                    .foregroundColor(AppColors.textPrimary)
                
                TextEditor(text: $notes)
                    .frame(height: 80)
                    .font(AppTypography.body())
                    .limitTextLength(to: ValidationLimits.maxNoteLength, text: $notes)
            }
            .padding(Spacing.lg)
        }
        .padding(.vertical, Spacing.sm)
        .background(AppColors.background)
        .cornerRadius(CornerRadius.md)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
    }
    
    // MARK: - Helper Views
    
    private struct FormRow<Content: View>: View {
        let icon: String
        let title: String
        let color: Color
        @ViewBuilder let content: Content
        
        var body: some View {
            HStack(spacing: Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: IconSize.md))
                    .foregroundColor(color)
                    .frame(width: 28)
                
                Text(title)
                    .font(AppTypography.body())
                    .foregroundColor(AppColors.textPrimary)
                
                Spacer()
                
                content
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
        }
    }
    
    private struct TypeButton: View {
        let title: String
        let icon: String
        let isSelected: Bool
        let action: () -> Void
        
        var body: some View {
            Button(action: action) {
                VStack(spacing: Spacing.sm) {
                    ZStack {
                        Circle()
                            .fill(isSelected ? AppColors.buttonBackground : AppColors.backgroundTertiary)
                            .frame(width: 56, height: 56)

                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(isSelected ? AppColors.buttonForeground : AppColors.textSecondary)
                    }
                    
                    Text(title)
                        .font(AppTypography.subheadlineMedium())
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.md)
            .background(isSelected ? AppColors.accent.opacity(0.1) : AppColors.background)
            .cornerRadius(CornerRadius.md)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.md)
                    .stroke(isSelected ? AppColors.accent : Color.clear, lineWidth: 2)
            )
        }
    }
    
    // MARK: - Helpers
    
    private var gradientForCategory: LinearGradient {
        switch selectedCategory {
        case "Entertainment":
            return LinearGradient(colors: [Color.red.opacity(0.8), Color.pink.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Productivity":
            return LinearGradient(colors: [Color.blue.opacity(0.8), Color.cyan.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Utilities":
            return LinearGradient(colors: [Color.orange.opacity(0.8), Color.yellow.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Health":
            return LinearGradient(colors: [Color.green.opacity(0.8), Color.teal.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Food":
            return LinearGradient(colors: [Color.orange.opacity(0.9), Color.red.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Transportation":
            return LinearGradient(colors: [Color.purple.opacity(0.8), Color.indigo.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case "Education":
            return LinearGradient(colors: [Color.cyan.opacity(0.8), Color.blue.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            return LinearGradient(colors: [Color.gray.opacity(0.6), Color.gray.opacity(0.4)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var shadowColorForCategory: Color {
        switch selectedCategory {
        case "Entertainment":
            return Color.red.opacity(0.3)
        case "Productivity":
            return Color.blue.opacity(0.3)
        case "Utilities":
            return Color.orange.opacity(0.3)
        case "Health":
            return Color.green.opacity(0.3)
        case "Food":
            return Color.orange.opacity(0.3)
        case "Transportation":
            return Color.purple.opacity(0.3)
        case "Education":
            return Color.cyan.opacity(0.3)
        default:
            return Color.gray.opacity(0.3)
        }
    }
    
    private var iconForCategory: String {
        iconFor(selectedCategory)
    }
    
    private func iconFor(_ category: String) -> String {
        switch category {
        case "Entertainment": return "film.fill"
        case "Productivity": return "briefcase.fill"
        case "Utilities": return "bolt.fill"
        case "Health": return "heart.fill"
        case "Food": return "fork.knife"
        case "Transportation": return "car.fill"
        case "Education": return "book.fill"
        default: return "creditcard.fill"
        }
    }
    
    // MARK: - Save
    
    private func saveSubscription() {
        HapticManager.save()
        
        let subscription = Subscription(context: viewContext)
        subscription.id = UUID()
        subscription.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        subscription.amount = Double(amount) ?? 0
        subscription.cycle = cycle.rawValue
        subscription.startDate = startDate
        subscription.nextBillingDate = calculateNextBillingDate()
        subscription.isShared = isShared
        subscription.isActive = true
        subscription.category = selectedCategory
        subscription.iconName = iconForCategory
        subscription.notificationEnabled = notificationEnabled
        subscription.notificationDaysBefore = Int16(notificationDays)
        subscription.notes = notes.isEmpty ? nil : notes
        subscription.colorHex = colorHexForCategory
        
        if isShared {
            let currentUser = CurrentUser.getOrCreate(in: viewContext)
            subscription.addToSubscribers(currentUser)
            for member in selectedMembers {
                subscription.addToSubscribers(member)
            }
        }
        
        do {
            try viewContext.save()
            
            if notificationEnabled {
                NotificationManager.shared.scheduleSubscriptionReminder(for: subscription)
            }
            
            HapticManager.success()
            dismiss()
        } catch {
            viewContext.rollback()
            HapticManager.error()
            errorMessage = "Failed to save subscription"
            showingError = true
        }
    }
    
    private var colorHexForCategory: String {
        switch selectedCategory {
        case "Entertainment": return "#FF2D55"
        case "Productivity": return "#007AFF"
        case "Utilities": return "#FF9500"
        case "Health": return "#34C759"
        case "Food": return "#FF3B30"
        case "Transportation": return "#5856D6"
        case "Education": return "#5AC8FA"
        default: return "#8E8E93"
        }
    }
    
    private func calculateNextBillingDate() -> Date {
        let calendar = Calendar.current
        let now = Date()
        var nextDate = startDate
        
        while nextDate <= now {
            switch cycle {
            case .weekly:
                nextDate = calendar.date(byAdding: .day, value: 7, to: nextDate) ?? nextDate
            case .monthly:
                nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? nextDate
            case .yearly:
                nextDate = calendar.date(byAdding: .year, value: 1, to: nextDate) ?? nextDate
            case .custom:
                // Custom cycle without specific days - use 30 days as default
                nextDate = calendar.date(byAdding: .day, value: 30, to: nextDate) ?? nextDate
            }
        }
        
        return nextDate
    }
}

// MARK: - Billing Cycle Enum

enum BillingCycle: String, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Yearly"
    case custom = "Custom"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        case .yearly: return "Yearly"
        case .custom: return "Custom"
        }
    }
    
    func monthlyEquivalent(for amount: Double) -> Double {
        switch self {
        case .weekly:
            return amount * 4.33
        case .monthly:
            return amount
        case .yearly:
            return amount / 12.0
        case .custom:
            return amount // Simplified - would need days parameter
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }
    
    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []
        
        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var rowHeight: CGFloat = 0
            
            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)
                
                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += rowHeight + spacing
                    rowHeight = 0
                }
                
                positions.append(CGPoint(x: x, y: y))
                rowHeight = max(rowHeight, size.height)
                x += size.width + spacing
            }
            
            self.size = CGSize(width: maxWidth, height: y + rowHeight)
        }
    }
}

// MARK: - Corner Radius Helper

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
