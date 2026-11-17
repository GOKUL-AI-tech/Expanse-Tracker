# Expense Tracker Pro – Setup Guide

## Prerequisites
- Flutter SDK 3.0+
- Dart SDK 3.0+
- A Supabase account (https://supabase.com)

---

## Step 1: Supabase Setup

1. Go to https://supabase.com and create a new project.
2. In the SQL Editor, run the entire contents of `supabase_schema.sql`.
3. Copy your **Project URL** and **Anon Key** from:
   `Settings → API → Project URL` and `anon public` key.

---

## Step 2: Configure the App

Open `lib/core/constants/app_constants.dart` and replace:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

with your actual values.

---

## Step 3: Install Dependencies

```bash
flutter pub get
```

---

## Step 4: Run the App

```bash
flutter run
```

---

## Project Structure

```
lib/
├── core/
│   ├── constants/       # App constants, categories, currencies
│   ├── router/          # GoRouter navigation
│   ├── theme/           # Light/Dark themes, colors
│   └── utils/           # Currency & date formatters
├── data/
│   ├── models/          # Dart data models
│   └── repositories/    # Supabase CRUD operations
├── features/
│   ├── auth/            # Login, Register, Forgot Password
│   ├── dashboard/       # Main dashboard + bottom nav shell
│   ├── expenses/        # Expense list + add/edit
│   ├── income/          # Income list + add/edit
│   ├── budget/          # Budget management
│   ├── savings/         # Savings goals
│   ├── transactions/    # Combined transaction history
│   ├── analytics/       # Charts & analytics
│   ├── reports/         # PDF/CSV export
│   ├── profile/         # User profile + settings
│   └── notifications/   # Notification center
└── main.dart
```

---

## Key Features
- **Auth**: Email/password login, register, forgot password
- **Expenses**: Add/edit/delete with categories, receipt upload, tags
- **Income**: Add/edit/delete with categories
- **Budgets**: Monthly category budgets with alerts
- **Savings Goals**: Progress tracking with deadline
- **Analytics**: Pie/bar/line charts with FL Chart
- **Reports**: PDF & CSV export with date filters
- **Dark/Light Mode**: System-aware with manual override
- **Multi-Currency**: INR, USD, EUR, GBP, AED, SGD
- **Security**: Supabase RLS – each user sees only their data

---

## Android Setup

Add internet permission in `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
```

Set min SDK in `android/app/build.gradle`:
```gradle
minSdkVersion 21
```
