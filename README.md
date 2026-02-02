# 🇨🇭 Swiss Coin

A modern iOS personal finance app built with SwiftUI for splitting bills, tracking expenses, managing subscriptions, and settling debts with friends and family.

## Screenshots

<!-- Add screenshots here -->
| Home | People | Transactions | Subscriptions | Profile |
|------|--------|--------------|---------------|---------|
| ![Home](screenshots/home.png) | ![People](screenshots/people.png) | ![Transactions](screenshots/transactions.png) | ![Subscriptions](screenshots/subscriptions.png) | ![Profile](screenshots/profile.png) |

## Features

### 💰 Expense Tracking
- Create and manage financial transactions (expenses, income, transfers)
- Detailed transaction history with search and filtering
- Monthly spending overview with visual summaries

### 👥 People & Groups
- Add contacts manually or import from your phone contacts
- Create groups for shared expenses (trips, roommates, events)
- iMessage-style conversation view for each person/group showing transaction history
- Send payment reminders and settle debts

### 💳 Bill Splitting
- Quick Action wizard for fast bill splitting
- Multiple split methods: equal, percentage, custom amounts, shares, adjustment
- Multi-step flow: basic details → split config → split method → confirmation

### 📱 Subscription Management
- Track personal subscriptions (Netflix, Spotify, etc.)
- Shared subscription tracking with member cost splitting
- Payment recording and renewal reminders
- Visual subscription detail view with conversation-style history

### 🔔 Smart Notifications
- Subscription renewal reminders
- Payment reminders for friends
- Configurable notification preferences

### 🔐 Security
- Face ID / Touch ID biometric authentication
- PIN code protection
- Keychain-based secure storage

### 🎨 Customization
- Light and dark mode support
- Multiple theme options
- Adjustable font sizes
- Haptic feedback preferences
- Multi-currency support (CHF, EUR, USD, GBP, and more)

### 🔍 Universal Search
- Search across transactions, people, groups, and subscriptions
- Real-time results as you type

## Tech Stack

| Component | Technology |
|-----------|-----------|
| **UI Framework** | SwiftUI |
| **Data Persistence** | CoreData |
| **Minimum iOS** | iOS 17.0 |
| **Language** | Swift 5 |
| **Architecture** | MVVM with feature-based modules |
| **Authentication** | Local (biometrics + PIN) |
| **Notifications** | UNUserNotificationCenter |

## Architecture

```
Swiss Coin/
├── App/                        # App entry point & root views
│   ├── Swiss_CoinApp.swift     # @main entry point
│   └── ContentView.swift       # Root navigation (auth/onboarding/main)
├── Features/                   # Feature modules (MVVM)
│   ├── Auth/                   # Phone login flow
│   ├── Home/                   # Dashboard with spending overview
│   ├── Onboarding/             # First-launch onboarding
│   ├── People/                 # Contacts, groups, conversations
│   ├── Profile/                # Settings, appearance, security
│   ├── QuickAction/            # Bill splitting wizard
│   ├── Search/                 # Universal search
│   ├── Subscriptions/          # Subscription tracking
│   └── Transactions/           # Transaction management
├── Models/CoreData/            # CoreData entity classes
├── Services/                   # Business logic services
│   ├── Persistence.swift       # CoreData stack with migration
│   ├── ContactsManager.swift   # Phone contacts integration
│   └── NotificationManager.swift
├── Utilities/                  # Shared helpers
│   ├── DesignSystem.swift      # Colors, typography, spacing
│   ├── CurrencyFormatter.swift # Multi-currency formatting
│   ├── BalanceCalculator.swift # Balance computation
│   └── KeychainHelper.swift    # Secure storage
├── Components/                 # Reusable UI components
├── Extensions/                 # Swift extensions
├── Views/                      # Shared views
│   └── MainTabView.swift       # Tab bar navigation
└── Resources/
    ├── Assets.xcassets/        # App icons, colors, images
    └── Swiss_Coin.xcdatamodeld # CoreData model
```

## Getting Started

### Prerequisites
- Xcode 15.0 or later
- iOS 17.0+ deployment target
- macOS Ventura or later

### Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/your-username/Swiss-Coin.git
   cd Swiss-Coin
   ```

2. Open the project in Xcode:
   ```bash
   open "Swiss Coin.xcodeproj"
   ```

3. Select your target device or simulator

4. Build and run (⌘+R)

> **Note:** No third-party dependencies required. The project uses only Apple frameworks.

## CoreData Model

The app uses CoreData with the following entities:
- **Person** — Contact (name, phone, photo, balance)
- **UserGroup** — Group of people for shared expenses
- **FinancialTransaction** — Expense/income/transfer records
- **TransactionSplit** — Individual split details per participant
- **Settlement** — Debt settlement records
- **Subscription** — Recurring subscription tracking
- **SubscriptionPayment** — Payment history for subscriptions
- **ChatMessage** — Conversation messages between users
- **Reminder** — Payment reminders

Lightweight migration is enabled for seamless model updates.

## License

This project is proprietary. All rights reserved.

---

Built with ❤️ in Switzerland
