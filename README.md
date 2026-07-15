# 💰 Tracklet SaveBuddy

> A modern offline-first Expense & Investment Tracker built with Flutter, Spring Boot, PostgreSQL, and SQLite.

Tracklet SaveBuddy helps users manage multiple expense books, track income and expenses, monitor investments, and visualize spending through interactive reports. The application is designed with an **offline-first architecture**, allowing users to continue working even without an internet connection.

---

## 📸 Screenshots

> Add screenshots here after taking them.

| Login | Dashboard | Expense |
|--------|-----------|----------|
| ![](screenshots/login.png) | ![](screenshots/dashboard.png) | ![](screenshots/expense.png) |

| Reports | Investments | Offline Sync |
|----------|-------------|--------------|
| ![](screenshots/reports.png) | ![](screenshots/investments.png) | ![](screenshots/offline.png) |

---

# ✨ Features

## 🔐 Authentication

- User Registration
- Secure Login
- Session Persistence
- Auto Login
- Logout

---

## 📚 Book Management

- Create Expense Books
- Edit Books
- Delete Books
- Archive Books
- Restore Archived Books
- Search Books
- Book Summary

---

## 💳 Expense Management

- Add Income
- Add Expense
- Edit Expense
- Delete Expense
- Swipe Actions (Edit/Delete)
- Category Management
- Search by Description
- Search by Category
- Filters
  - Today
  - This Week
  - This Month
  - Credit
  - Debit
- Sorting
  - Newest
  - Oldest
  - Highest Amount
  - Lowest Amount
  - A-Z
  - Z-A
- Real-time Summary Cards

---

## 📈 Reports & Analytics

- Income Summary
- Expense Summary
- Current Balance
- Pie Chart
- Bar Chart
- Daily Spending Line Chart
- Category-wise Spending
- Largest Expense
- Recent Transactions
- Average Expense
- Highest Expense
- Lowest Expense

---

## 💹 Investment Management

- Add Investments
- Edit Investments
- Delete Investments
- Investment Tracking

---

## 📡 Offline-First Support

Tracklet SaveBuddy works even without an internet connection.

Features include:

- SQLite Local Database
- Offline CRUD Operations
- Automatic Synchronization
- Repository Pattern
- Connectivity Detection
- Pending Sync Queue
- Sync Status Indicator
- Local Data Persistence

---

# 🏗 Architecture

```
                Flutter UI
                     │
                     ▼
             Repository Layer
                     │
      ┌──────────────┴──────────────┐
      ▼                             ▼
SQLite Local DB             Spring Boot REST API
      │                             │
      └──────────────┬──────────────┘
                     ▼
               PostgreSQL Database
```

---

# 🛠 Tech Stack

### Frontend

- Flutter
- Dart
- Material Design

### Backend

- Spring Boot
- Spring Security
- REST API
- Basic Authentication

### Database

- PostgreSQL
- SQLite (Offline Storage)

### Packages

- http
- sqflite
- connectivity_plus
- shared_preferences
- fl_chart
- intl
- path_provider
- path

---

# 📂 Project Structure

```
lib/
│
├── database/
├── models/
├── repositories/
├── services/
├── pages/
│   ├── Auth/
│   ├── HomePage/
│   ├── Expenses/
│   ├── Investments/
│   └── Reports/
├── custom_widgets/
├── constants/
└── main.dart
```

---

# 🚀 Getting Started

## Prerequisites

- Flutter SDK
- Android Studio / VS Code
- Java 21+
- Spring Boot Backend
- PostgreSQL

---

## Installation

Clone the repository

```bash
git clone https://github.com/yourusername/Tracklet-SaveBuddy.git
```

Navigate to project

```bash
cd Tracklet-SaveBuddy
```

Install dependencies

```bash
flutter pub get
```

Run the application

```bash
flutter run
```

---

# ⚙ Backend Setup

Configure your backend API URL inside

```
lib/constants/constant.dart
```

Example

```dart
const String baseUrl = "https://your-server-url.com";
```

Run the Spring Boot backend before launching the application.

---

# 📶 Offline Workflow

```
Internet Available

↓

Save to SQLite

↓

Upload to Server

↓

Mark Synced
```

If internet is unavailable

```
Save to SQLite

↓

Mark Pending

↓

Auto Sync When Internet Returns
```

---

# 🎯 Highlights

- Offline-first architecture
- Multi-book expense management
- Interactive analytics
- Repository Pattern
- Local + Cloud Synchronization
- Clean Material UI
- Responsive Design
- Modular Architecture

---

# 🔮 Future Improvements

- JWT Authentication
- Cloud Backup
- Export Reports (PDF/Excel)
- Budget Planning
- Recurring Transactions
- Notifications & Reminders
- Multi-currency Support
- Dark Mode
- Biometric Authentication
- Cloud Data Sharing

---

# 📊 Current Status

✅ Authentication

✅ Expense Management

✅ Book Management

✅ Investment Management

✅ Reports & Analytics

✅ Offline Support

✅ Auto Synchronization

🚀 Version: **1.0.0**

---

# 👨‍💻 Author

**Naman Punamiya**

B.Tech Computer Engineering

Flutter Developer | Backend Developer

GitHub: https://github.com/yourusername

LinkedIn: https://linkedin.com/in/yourprofile

---

# 📄 License

This project is licensed under the MIT License.

---

## ⭐ If you found this project useful, consider giving it a star!
