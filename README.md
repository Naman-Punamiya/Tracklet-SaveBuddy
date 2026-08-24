# 💰 Tracklet SaveBuddy

![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-blue?logo=dart)
![Spring Boot](https://img.shields.io/badge/Spring_Boot-3.x-green?logo=springboot)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-Database-blue?logo=postgresql)
![SQLite](https://img.shields.io/badge/SQLite-Offline-blue?logo=sqlite)
![License](https://img.shields.io/badge/License-MIT-yellow)

> **Tracklet SaveBuddy** is a modern offline-first Expense & Investment Tracker built using **Flutter**, **Spring Boot**, **PostgreSQL**, and **SQLite**.

The application enables users to manage multiple expense books, record income and expenses, track investments, and analyze spending patterns through interactive reports. Designed with an **offline-first architecture**, it ensures uninterrupted usage even without an internet connection by storing data locally and synchronizing it automatically when connectivity is restored.

---

# 💡 Why Tracklet SaveBuddy?

Managing personal finances should not depend on a constant internet connection. Many expense tracking applications become unusable when offline or offer limited functionality.

Tracklet SaveBuddy was developed to provide a seamless **offline-first experience**, allowing users to continue managing their finances without interruption. Every change is stored locally using SQLite and automatically synchronized with the cloud once internet connectivity is restored.

---

# 🚀 Key Features

- 📚 Multi-book expense management
- 💰 Income & Expense tracking
- 📈 Interactive reports and analytics
- 💹 Investment management
- 📡 Offline-first architecture
- 🔄 Automatic cloud synchronization
- 📊 SQLite + PostgreSQL data management
- 🏗 Repository Pattern implementation
- 🎨 Modern Material Design UI

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
- Swipe to Edit & Delete
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
- Income vs Expense Bar Chart
- Daily Spending Line Chart
- Category-wise Spending Analysis
- Largest Expense
- Recent Transactions
- Average Expense
- Highest & Lowest Expense

---

## 💹 Investment Management

- Add Investments
- Edit Investments
- Delete Investments
- Investment Tracking

---

## 📡 Offline-First Support

Tracklet SaveBuddy continues to function even without an internet connection.

### Offline Features

- SQLite Local Database
- Offline CRUD Operations
- Repository Pattern
- Connectivity Detection
- Automatic Synchronization
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
   SQLite Local Database        Spring Boot REST API
          │                             │
          └──────────────┬──────────────┘
                         ▼
                  PostgreSQL Database
```

---

# 🛠 Tech Stack

## Frontend

- Flutter
- Dart
- Material Design

## Backend

- Spring Boot
- Spring Security
- REST API
- Basic Authentication

## Database

- PostgreSQL
- SQLite

## Packages

- http
- sqflite
- connectivity_plus
- shared_preferences
- fl_chart
- intl
- path
- path_provider

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
│
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
git clone https://github.com/Naman-Punamiya/Tracklet-SaveBuddy.git
```

Navigate into the project

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

# ⚙ Backend Configuration

Configure your backend API URL in:

```
lib/constants/constant.dart
```

Example:

```dart
const String baseUrl = "https://your-backend-url.com";
```

Ensure the Spring Boot backend is running before launching the application.

---

# 📶 Offline Synchronization Flow

### Online Mode

```
User Action
     │
     ▼
Save to SQLite
     │
     ▼
Upload to Server
     │
     ▼
Mark as Synced
```

### Offline Mode

```
User Action
     │
     ▼
Save to SQLite
     │
     ▼
Mark as Pending
     │
     ▼
Auto Sync when Internet Returns
```

---

# 🧠 Challenges & Learnings

Building Tracklet SaveBuddy helped me gain practical experience in:

- Designing an Offline-First Architecture
- Synchronizing SQLite with PostgreSQL
- Implementing the Repository Pattern
- Handling Network Connectivity Changes
- Managing Local and Remote Data Consistency
- Building Interactive Financial Reports
- Structuring a Scalable Flutter Application
- Integrating Flutter with Spring Boot REST APIs

---

# 📱 Platform Support

- ✅ Android
- ⏳ iOS (Planned)
- ⏳ Web (Future)

---

# 🔮 Future Improvements

- JWT Authentication
- Export Reports (PDF & Excel)
- Budget Planning
- Recurring Transactions
- Notifications & Reminders
- Multi-Currency Support
- Dark Mode
- Biometric Authentication
- Cloud Backup
- Shared Expense Books

---

# 📦 Current Version

**Version:** `v1.0.0`

### Completed Modules

- ✅ Authentication
- ✅ Book Management
- ✅ Expense Management
- ✅ Investment Management
- ✅ Reports & Analytics
- ✅ Offline-First Support
- ✅ Automatic Synchronization

---

# 👨‍💻 Author

**Naman Punamiya**

B.Tech Computer Engineering

Flutter Developer | Backend Developer

**GitHub:** https://github.com/Naman-Punamiya

**LinkedIn:** *(Add your LinkedIn profile URL here if you have one.)*

---

# 📄 License

This project is licensed under the **MIT License**.
