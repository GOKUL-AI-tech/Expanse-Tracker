class AppConstants {
  // Supabase - Replace with your project credentials
  static const String supabaseUrl = 'YOUR_SUPABASE_URL';
  static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';

  // App
  static const String appName = 'Expense Tracker Pro';

  // Currencies
  static const List<Map<String, String>> currencies = [
    {'code': 'INR', 'symbol': '₹', 'name': 'Indian Rupee'},
    {'code': 'USD', 'symbol': '\$', 'name': 'US Dollar'},
    {'code': 'EUR', 'symbol': '€', 'name': 'Euro'},
    {'code': 'GBP', 'symbol': '£', 'name': 'British Pound'},
    {'code': 'AED', 'symbol': 'د.إ', 'name': 'UAE Dirham'},
    {'code': 'SGD', 'symbol': 'S\$', 'name': 'Singapore Dollar'},
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    'Food',
    'Travel',
    'Shopping',
    'Entertainment',
    'Education',
    'Healthcare',
    'Rent',
    'Bills',
    'Fuel',
    'Subscription',
    'Investment',
    'Others',
  ];

  // Income Categories
  static const List<String> incomeCategories = [
    'Salary',
    'Freelancing',
    'Business',
    'Investment',
    'Scholarship',
    'Side Hustle',
    'Other',
  ];

  // Payment Methods
  static const List<String> paymentMethods = [
    'Cash',
    'Credit Card',
    'Debit Card',
    'UPI',
    'Net Banking',
    'Wallet',
    'Cheque',
    'Other',
  ];

  // Category Icons mapping
  static const Map<String, String> categoryIcons = {
    'Food': '🍔',
    'Travel': '✈️',
    'Shopping': '🛍️',
    'Entertainment': '🎬',
    'Education': '📚',
    'Healthcare': '🏥',
    'Rent': '🏠',
    'Bills': '📄',
    'Fuel': '⛽',
    'Subscription': '📱',
    'Investment': '📈',
    'Others': '💰',
    'Salary': '💼',
    'Freelancing': '💻',
    'Business': '🏢',
    'Scholarship': '🎓',
    'Side Hustle': '🔧',
    'Other': '💵',
  };

  // Date Filter Options
  static const List<String> dateFilters = [
    'Today',
    'Last 7 Days',
    'Last 30 Days',
    'Last 3 Months',
    'Last 6 Months',
    'Last 1 Year',
    'Last 5 Years',
    'All Time',
    'Custom Range',
  ];
}
