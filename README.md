# Expense Tracker Pro

A modern personal-finance app built with **Flutter** and **Supabase**. Track expenses and income, set budgets and savings goals, and see where your money goes with charts and exportable reports.

## Features

- **Auth** – email/password sign-up, login and password reset
- **Expenses & Income** – add, edit and delete entries with categories, tags and receipts
- **Budgets** – set limits per category and monitor spending against them
- **Savings goals** – create goals and track progress
- **Analytics** – interactive charts of spending patterns
- **Reports** – export to PDF, CSV and Excel
- **Notifications** – local reminders and a notification centre
- **Light / dark themes**

## Tech Stack

| Layer | Tools |
|-------|-------|
| UI | Flutter, Material, `fl_chart`, `flutter_animate`, `lottie` |
| State & routing | Riverpod, GoRouter |
| Backend | Supabase (Postgres + Auth + Storage) |
| Export | `pdf`, `csv`, `excel`, `share_plus` |

## Project Structure

```
lib/
├── core/        # constants, router, theme, services, utils
├── data/        # models and Supabase repositories
├── features/    # auth, dashboard, expenses, income, budget,
│                # savings, transactions, analytics, reports,
│                # profile, notifications
└── main.dart
supabase_schema.sql   # database schema (run in the Supabase SQL editor)
```

## Getting Started

1. Create a project at [supabase.com](https://supabase.com) and run `supabase_schema.sql` in the SQL Editor.
2. Put your **Project URL** and **anon key** in `lib/core/constants/app_constants.dart`:
   ```dart
   static const String supabaseUrl = 'YOUR_SUPABASE_URL';
   static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
   ```
3. Install and run:
   ```bash
   flutter pub get
   flutter run
   ```

See [SETUP.md](SETUP.md) for the full walkthrough.

## Author

**Gokul G** – B.Sc. AI & ML · [GitHub](https://github.com/GOKUL-AI-tech) · [LinkedIn](https://www.linkedin.com/in/gokul-g-ai-ml)
