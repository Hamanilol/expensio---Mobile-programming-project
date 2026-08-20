# Expensio — Personal Expense Tracker

**IT8108 Mobile Programming — Repeat Assessment**

A native iOS expense tracking app built with Swift and UIKit. Users can log daily expenses, attach receipt photos, filter spending by category or month, and view a monthly summary with category breakdowns.

---

## Features

| Feature | Description |
|---|---|
| Authentication | Email/password sign-up and sign-in via Firebase Auth |
| Add Expense | Title, amount, category, date picker, optional receipt photo |
| Edit / Delete | Tap any expense to view details, then edit or delete |
| Category Filter | Filter by Food, Transport, Bills, Shopping, Health, or Other |
| Month Filter | Filter expenses by calendar month |
| Search | Live search by expense title |
| Monthly Summary | Total spent, % change vs. previous month, per-category progress bars, weekly bar chart |
| Receipt Upload | Attach a photo from the photo library; stored on Cloudinary |
| Session Persistence | Login state is preserved via `UserDefaults` so re-opening the app skips the login screen |

---

## Architecture

The project follows the **MVC** pattern required by the assessment:

```
Controller/   — UIViewControllers (one per screen)
Models/       — Expense, ExpenseCategory (data types)
Services/     — AuthService, DatabaseService, CloudinaryService (business logic)
Views/        — Main.storyboard (all screens and segues)
```

### Screens & Storyboard Segues

```
LoginViewController
  │── (LoginSuccess segue) ──────────────► TabBarController
  └── (L-seg2 segue) ────────────────────► SignUpViewController
         └── (SignUpSuccess segue) ───────► TabBarController

TabBarController
  ├── ExpensesViewController
  │     ├── (E-seg1 segue) ─────────────► AddExpenseViewController
  │     └── (ShowExpenseDetail segue) ──► ExpenseDetailViewController
  │               └── (EditExpense segue)─► AddExpenseViewController
  └── SummaryViewController
```

---

## Firebase Authentication

**Service:** `AuthService.swift`

Firebase Authentication handles all user identity with email/password:

- **Sign Up** — `Auth.auth().createUser(withEmail:password:)`, then updates the display name with `changeRequest`.
- **Sign In** — `Auth.auth().signIn(withEmail:password:)`.
- **Sign Out** — `Auth.auth().signOut()`, followed by navigating back to the Login screen.
- **Session persistence** — Firebase Auth persists the token locally. On launch, `SceneDelegate` checks `Auth.auth().currentUser`; if a user is already signed in, the app goes straight to the Tab Bar, skipping login.

---

## Firebase Realtime Database

**Service:** `DatabaseService.swift` (inside `FirestoreService.swift`)

> Note: The project originally used Cloud Firestore but was migrated to **Firebase Realtime Database** (`firebase.database`) as required by the assessment brief.

Data is stored under each user's own node so no user can read another's data:

```
users/
  {uid}/
    expenses/
      {autoId}/
        title        : String
        amount       : Double
        category     : String   (e.g. "food")
        date         : Double   (Unix timestamp)
        receiptImageURL : String?
        createdAt    : Double
```

Key operations:

| Method | What it does |
|---|---|
| `addExpense` | `childByAutoId().setValue(...)` |
| `fetchExpenses` | `observeSingleEvent(.value)` — one-time fetch |
| `observeExpenses` | `observe(.value)` — live listener, returns `DatabaseObserver` to cancel later |
| `updateExpense` | `child(id).setValue(...)` |
| `deleteExpense` | `child(id).removeValue()` |

A `DatabaseObserver` wrapper (similar to Firestore's `ListenerRegistration`) is used to cancel the live listener when the Expenses screen disappears:

```swift
expensesListener = DatabaseService.shared.observeExpenses { result in ... }
// later:
expensesListener?.remove()
```

---

## Cloudinary (Receipt Photos)

**Service:** `CloudinaryService.swift`

Receipt photos are uploaded to Cloudinary using an **unsigned upload preset** (`ml_default`) — no server needed:

1. User taps "Attach Receipt" → `UIImagePickerController` opens the photo library.
2. The selected image is JPEG-compressed and POSTed to `https://api.cloudinary.com/v1_1/{cloud_name}/image/upload`.
3. On success, the returned `secure_url` is saved alongside the expense record in the Realtime Database.
4. When viewing an expense, the URL is loaded via `URLSession` (no third-party library).

> **Setup required:** In the Cloudinary dashboard go to Settings → Upload → Upload presets and set `ml_default` to **Unsigned**.

---

## Setup Instructions

1. **Clone the repo**
   ```bash
   git clone <repo-url>
   cd expensio---Mobile-programming-project/expensio
   ```

2. **Open in Xcode**
   ```
   open expensio.xcodeproj
   ```

3. **Firebase**
   - The `GoogleService-Info.plist` is already in the project.
   - Realtime Database URL: `https://expensio-60da0-default-rtdb.europe-west1.firebasedatabase.app/`
   - Ensure database rules allow authenticated reads/writes under `users/{uid}`.

4. **Cloudinary**
   - Cloud name: `dcgs06flw`
   - Set the `ml_default` upload preset to **Unsigned** in the Cloudinary dashboard.

5. **Build & Run**
   - Select an iOS 16+ simulator or physical device.
   - Press `⌘R`.

---

## Dependencies

Managed via Swift Package Manager:

| Package | Purpose |
|---|---|
| Firebase iOS SDK | Authentication + Realtime Database |
| GoogleService-Info.plist | Firebase project configuration |

---

## Project Info

| | |
|---|---|
| Language | Swift 5 |
| UI Framework | UIKit + Storyboards (MVC) |
| Minimum iOS | 16.0 |
| Database | Firebase Realtime Database |
| Auth | Firebase Authentication |
| Image Storage | Cloudinary |
| Session | Firebase Auth persistence + UserDefaults |
