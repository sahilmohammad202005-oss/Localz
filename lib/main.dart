// ============================================================================
// LOCALZ  —  "Local food. Flexible meals."
// College MVP / prototype (single file: lib/main.dart)
//
// Flexible meal subscriptions from local food businesses, with meals only on
// the days customers need them.
//
// REQUIRED PACKAGES (pubspec.yaml):
//   firebase_core, firebase_auth
// FIREBASE SETUP (done separately):
//   1. dart pub global activate flutterfire_cli
//   2. flutterfire configure           (creates lib/firebase_options.dart)
//   3. In main() below, un-comment the import + the `options:` line.
//   4. Firebase Console -> Authentication -> Sign-in method -> enable Email/Password.
//
// Until Firebase is configured the app will NOT pretend login worked. It shows
// a clear message and offers an explicitly-labelled "demo preview" instead.
//
// FUTURE FIRESTORE COLLECTIONS (not implemented yet):
//   users, businesses, meals, orders, subscriptions
//   users/{uid}.role = 'customer' | 'businessOwner'
// ============================================================================

// ignore_for_file: deprecated_member_use

import 'dart:math' as math;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart'; // <- un-comment after running `flutterfire configure`

// ============================================================================
// 1. ENTRY POINT + FIREBASE INITIALISATION
// ============================================================================

bool firebaseReady = false;
String firebaseInitMessage = '';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // <- un-comment after flutterfire configure
    );
    firebaseReady = true;
  } catch (e) {
    firebaseReady = false;
    firebaseInitMessage =
        'Firebase is not configured yet, so login and registration are unavailable. '
        'Run "flutterfire configure" and enable Email/Password sign-in in the Firebase Console.';
  }
  runApp(const LocalzApp());
}

// ============================================================================
// 2. THEME, COLOURS & SMALL HELPERS
// ============================================================================

class LZ {
  static const cream = Color(0xFFFBF5E9);
  static const creamDark = Color(0xFFF3E8CF);
  static const maroon = Color(0xFF7A1F2B);
  static const turmeric = Color(0xFFD9A441);
  static const green = Color(0xFF2F5D3A);
  static const terracotta = Color(0xFFC4673F);
  static const gold = Color(0xFFB8893B);
  static const ink = Color(0xFF3A2A25);
  static const muted = Color(0xFF7D6A60);
}

/// Colour with opacity (0..1) that works on every Flutter version.
Color tint(Color c, double opacity) => c.withAlpha((opacity * 255).round());

TextStyle hStyle(double size,
        {Color color = LZ.maroon, FontWeight weight = FontWeight.w700}) =>
    TextStyle(
        fontFamily: 'serif',
        fontSize: size,
        color: color,
        fontWeight: weight,
        height: 1.2);

TextStyle bStyle(double size,
        {Color color = LZ.ink, FontWeight weight = FontWeight.w400}) =>
    TextStyle(fontSize: size, color: color, fontWeight: weight, height: 1.35);

String money(int v) => '₹$v';

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: LZ.maroon,
    primary: LZ.maroon,
    secondary: LZ.turmeric,
    surface: LZ.cream,
  );
  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(12),
    borderSide: BorderSide(color: tint(LZ.gold, 0.5)),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: LZ.cream,
    appBarTheme: const AppBarTheme(
      backgroundColor: LZ.cream,
      foregroundColor: LZ.maroon,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
          fontFamily: 'serif',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: LZ.maroon),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: LZ.maroon,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: LZ.maroon,
        side: const BorderSide(color: LZ.maroon, width: 1.2),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: LZ.maroon),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: LZ.maroon, width: 1.6),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: tint(LZ.turmeric, 0.45),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

// ============================================================================
// 3. MODELS
// ============================================================================

enum AccountType { customer, businessOwner }

extension AccountTypeX on AccountType {
  String get label => this == AccountType.customer ? 'Customer' : 'Food Business';
  String get code => this == AccountType.customer ? 'customer' : 'businessOwner';
}

const kDays = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
];
const kDaysShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const kDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
const kCategories = ['Breakfast', 'Lunch', 'Dinner', 'Tiffin', 'Meals', 'Snacks'];

IconData categoryIcon(String c) {
  switch (c) {
    case 'Breakfast':
      return Icons.free_breakfast_rounded;
    case 'Lunch':
      return Icons.lunch_dining_rounded;
    case 'Dinner':
      return Icons.dinner_dining_rounded;
    case 'Tiffin':
      return Icons.takeout_dining_rounded;
    case 'Meals':
      return Icons.rice_bowl_rounded;
    default:
      return Icons.cookie_rounded;
  }
}

class UserSession {
  final String uid;
  final String name;
  final String email;
  final String phone;
  AccountType type;
  final String? businessName;
  final String? businessLocation;
  final bool isDemo;
  UserSession({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.type,
    this.businessName,
    this.businessLocation,
    this.isDemo = false,
  });
}

class FoodProvider {
  String id;
  String name;
  String type;
  String imageUrl;
  String description;
  String location;
  String phone;
  double rating;
  double rangeKm; // each business decides its own service range
  FoodProvider({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
    required this.description,
    required this.location,
    required this.phone,
    required this.rating,
    required this.rangeKm,
  });
}

class Meal {
  String id;
  String providerId;
  String name;
  String description;
  String category;
  String imageUrl;
  int price;
  bool available;
  Meal({
    required this.id,
    required this.providerId,
    required this.name,
    required this.description,
    required this.price,
    required this.category,
    required this.imageUrl,
    this.available = true,
  });
}

class OrderRec {
  final String id;
  final String mealName;
  final String providerName;
  final String imageUrl;
  final int qty;
  final int unitPrice;
  final String customerName;
  final String location;
  String status;
  final DateTime placedAt;
  OrderRec({
    required this.id,
    required this.mealName,
    required this.providerName,
    required this.imageUrl,
    required this.qty,
    required this.unitPrice,
    required this.customerName,
    required this.location,
    required this.status,
    DateTime? placedAt,
  }) : placedAt = placedAt ?? DateTime.now();
  int get total => qty * unitPrice;
}

class Subscription {
  final String id;
  final String customerName;
  final String providerName;
  final String mealName;
  final String imageUrl;
  final int pricePerMeal;
  Set<int> days; // 0 = Monday ... 6 = Sunday
  String status; // Active / Cancelled
  Subscription({
    required this.id,
    required this.customerName,
    required this.providerName,
    required this.mealName,
    required this.imageUrl,
    required this.pricePerMeal,
    required this.days,
    this.status = 'Active',
  });
  int get weeklyTotal => days.length * pricePerMeal;
  String get daysText =>
      days.isEmpty ? 'No days' : (days.toList()..sort()).map((i) => kDaysShort[i]).join(', ');
  String get nextMeal => Store.nextMealText(days);
}

// ============================================================================
// 4. SAMPLE IMAGES  (all demo content — swap any URL here in ONE place)
// ============================================================================
// Images load from Wikimedia Commons. If a link is ever missing or blocked,
// FoodImage() automatically shows a friendly placeholder instead of breaking.

class Img {
  static String _c(String file) =>
      'https://commons.wikimedia.org/wiki/Special:FilePath/$file?width=800';
  static final idli = _c('Idli_Sambar.JPG');
  static final dosa = _c('Masala_Dosa.jpg');
  static final vada = _c('Medu_Vada.jpg');
  static final pongal = _c('Ven_Pongal.jpg');
  static final poori = _c('Poori_Bhaji.jpg');
  static final meals = _c('Andhra_meals.jpg');
  static final biryani = _c('Hyderabadi_Chicken_Biryani.jpg');
  static final chickenCurry = _c('Chicken_curry.jpg');
  static final paneer = _c('Paneer_curry.jpg');
  static final lemonRice = _c('Lemon_Rice.jpg');
  static final curdRice = _c('Curd_Rice.jpg');
  static final pulihora = _c('Pulihora.jpg');
  static final sambar = _c('Sambar.jpg');
  static final rasam = _c('Rasam.jpg');
}

// ============================================================================
// 5. IN-MEMORY STORE (sample data; replace with Firestore later)
// ============================================================================

class Store {
  static UserSession? user;
  static String deliveryLocation = 'Vijayawada, Andhra Pradesh';
  static int _orderCounter = 1024;
  static int _subCounter = 300;
  static String nextOrderId() => 'LZ${++_orderCounter}';
  static String nextSubId() => 'SUB${++_subCounter}';
  static int _mealCounter = 100;
  static String nextMealId() => 'm${++_mealCounter}';

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  /// Next date (starting tomorrow) that falls on one of the selected days.
  static String nextMealText(Set<int> days) {
    if (days.isEmpty) return 'No days selected';
    final now = DateTime.now();
    for (int i = 1; i <= 7; i++) {
      final d = now.add(Duration(days: i));
      if (days.contains(d.weekday - 1)) {
        return '${kDaysShort[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';
      }
    }
    return '—';
  }

  // ---- Sample providers (DEMO ONLY — not real businesses) ----
  static final List<FoodProvider> providers = [
    FoodProvider(
      id: 'p1',
      name: "Amma's Kitchen",
      type: 'Home-style tiffins & breakfast',
      imageUrl: Img.idli,
      rating: 4.6,
      rangeKm: 3,
      location: 'Temple Street (sample address)',
      phone: '+91 90000 00001',
      description: 'Soft idlis, crisp dosas and fresh chutneys made the way they are at home.',
    ),
    FoodProvider(
      id: 'p2',
      name: 'Sri Lakshmi Meals',
      type: 'South Indian meals & rice varieties',
      imageUrl: Img.meals,
      rating: 4.5,
      rangeKm: 5,
      location: 'Market Road (sample address)',
      phone: '+91 90000 00002',
      description: 'Full vegetarian meals, tangy pulihora and comforting curd rice for lunch.',
    ),
    FoodProvider(
      id: 'p3',
      name: 'Rayalaseema Ruchulu',
      type: 'Andhra non-veg & curries',
      imageUrl: Img.chickenCurry,
      rating: 4.4,
      rangeKm: 4,
      location: 'Station Road (sample address)',
      phone: '+91 90000 00003',
      description: 'Spicy Rayalaseema-style chicken curry, biryani and paneer dishes.',
    ),
    FoodProvider(
      id: 'p4',
      name: 'Krishna Tiffin Centre',
      type: 'Tiffins & snacks',
      imageUrl: Img.pongal,
      rating: 4.3,
      rangeKm: 2.5,
      location: 'Canal Road (sample address)',
      phone: '+91 90000 00004',
      description: 'Quick morning tiffins — pongal, poori, idli-vada combos and more.',
    ),
    FoodProvider(
      id: 'p5',
      name: 'Nellore Spice Kitchen',
      type: 'Biryani, curries & meals',
      imageUrl: Img.biryani,
      rating: 4.7,
      rangeKm: 6,
      location: 'Ring Road (sample address)',
      phone: '+91 90000 00005',
      description: 'Nellore-style chicken biryani and hearty curry meals for dinner.',
    ),
  ];

  // ---- Sample meals ----
  static final List<Meal> meals = [
    // Amma's Kitchen
    Meal(id: 'm1', providerId: 'p1', name: 'Idli (3 pcs)', description: 'Soft steamed idlis served with sambar and two chutneys.', price: 40, category: 'Breakfast', imageUrl: Img.idli),
    Meal(id: 'm2', providerId: 'p1', name: 'Masala Dosa', description: 'Crisp golden dosa filled with spiced potato masala, with chutney and sambar.', price: 60, category: 'Breakfast', imageUrl: Img.dosa),
    Meal(id: 'm3', providerId: 'p1', name: 'Medu Vada (2 pcs)', description: 'Crunchy outside, fluffy inside. Served with coconut chutney.', price: 35, category: 'Snacks', imageUrl: Img.vada),
    Meal(id: 'm4', providerId: 'p1', name: 'Ven Pongal', description: 'Creamy rice-and-moong pongal with pepper, cumin and ghee.', price: 50, category: 'Breakfast', imageUrl: Img.pongal),
    Meal(id: 'm5', providerId: 'p1', name: 'Poori with Potato Masala', description: 'Three puffed pooris with a mildly spiced potato masala.', price: 55, category: 'Tiffin', imageUrl: Img.poori),
    // Sri Lakshmi Meals
    Meal(id: 'm6', providerId: 'p2', name: 'South Indian Meals', description: 'Rice, sambar, rasam, two curries, kootu, papad, pickle and curd.', price: 120, category: 'Meals', imageUrl: Img.meals),
    Meal(id: 'm7', providerId: 'p2', name: 'Lemon Rice', description: 'Tangy lemon rice tempered with peanuts, curry leaves and mustard.', price: 70, category: 'Lunch', imageUrl: Img.lemonRice),
    Meal(id: 'm8', providerId: 'p2', name: 'Curd Rice', description: 'Cooling curd rice with pomegranate, tempering and a pickle on the side.', price: 60, category: 'Lunch', imageUrl: Img.curdRice),
    Meal(id: 'm9', providerId: 'p2', name: 'Pulihora (Tamarind Rice)', description: 'Andhra-style tangy tamarind rice with roasted peanuts.', price: 65, category: 'Lunch', imageUrl: Img.pulihora),
    Meal(id: 'm10', providerId: 'p2', name: 'Sambar (500 ml)', description: 'Freshly made vegetable sambar with drumstick and pumpkin.', price: 45, category: 'Meals', imageUrl: Img.sambar),
    Meal(id: 'm11', providerId: 'p2', name: 'Rasam (500 ml)', description: 'Peppery tomato rasam with garlic and curry leaves.', price: 40, category: 'Meals', imageUrl: Img.rasam),
    // Rayalaseema Ruchulu
    Meal(id: 'm12', providerId: 'p3', name: 'Andhra Chicken Curry Meals', description: 'Spicy Andhra chicken curry with rice, rasam, curd and pickle.', price: 150, category: 'Dinner', imageUrl: Img.chickenCurry),
    Meal(id: 'm13', providerId: 'p3', name: 'Chicken Biryani', description: 'Aromatic dum-style chicken biryani with raita and mirchi ka salan.', price: 170, category: 'Dinner', imageUrl: Img.biryani),
    Meal(id: 'm14', providerId: 'p3', name: 'Paneer Curry with Chapati', description: 'Soft paneer in a rich tomato-onion gravy with two chapatis.', price: 130, category: 'Dinner', imageUrl: Img.paneer),
    // Krishna Tiffin Centre
    Meal(id: 'm15', providerId: 'p4', name: 'Idli Vada Combo', description: 'Two idlis and one vada with sambar and chutney.', price: 55, category: 'Tiffin', imageUrl: Img.idli),
    Meal(id: 'm16', providerId: 'p4', name: 'Pongal Vada', description: 'Hot ven pongal with a crunchy medu vada on the side.', price: 60, category: 'Tiffin', imageUrl: Img.pongal),
    Meal(id: 'm17', providerId: 'p4', name: 'Poori Set (3 pcs)', description: 'Three fluffy pooris with potato masala.', price: 50, category: 'Tiffin', imageUrl: Img.poori),
    Meal(id: 'm18', providerId: 'p4', name: 'Masala Dosa', description: 'Crisp masala dosa with chutney and sambar. (Sold out today)', price: 55, category: 'Breakfast', imageUrl: Img.dosa, available: false),
    // Nellore Spice Kitchen
    Meal(id: 'm19', providerId: 'p5', name: 'Nellore Chicken Biryani', description: 'Spicy Nellore-style biryani with tender chicken pieces.', price: 180, category: 'Dinner', imageUrl: Img.biryani),
    Meal(id: 'm20', providerId: 'p5', name: 'Andhra Chicken Curry Meals', description: 'Chicken curry, rice, rasam and curd — a full dinner plate.', price: 150, category: 'Dinner', imageUrl: Img.chickenCurry),
    Meal(id: 'm21', providerId: 'p5', name: 'Paneer Curry Meals', description: 'Paneer curry with rice, dal and curd.', price: 130, category: 'Meals', imageUrl: Img.paneer),
    Meal(id: 'm22', providerId: 'p5', name: 'Lemon Rice & Curry', description: 'Lemon rice with a mild vegetable curry and papad.', price: 80, category: 'Lunch', imageUrl: Img.lemonRice),
  ];

  // ---- Customer data ----
  static final List<OrderRec> customerOrders = [];
  static final List<Subscription> customerSubs = [];

  // ---- Business-owner data ----
  static FoodProvider ownerBusiness = FoodProvider(
    id: 'owner',
    name: 'My Food Business',
    type: 'Local food business',
    imageUrl: Img.meals,
    rating: 0,
    rangeKm: 3,
    location: 'Add your location',
    phone: '',
    description: 'Fresh South Indian food made daily.',
  );
  static final List<Meal> ownerMeals = [];
  static final List<OrderRec> ownerOrders = [];
  static final List<Subscription> ownerSubs = [];

  static FoodProvider? provider(String id) {
    if (id == 'owner') return ownerBusiness;
    for (final p in providers) {
      if (p.id == id) return p;
    }
    return null;
  }

  static String providerName(String id) => provider(id)?.name ?? 'Local kitchen';

  /// Called whenever someone logs in / registers. Resets sample data.
  static void startSession(UserSession s) {
    user = s;
    customerOrders
      ..clear()
      ..addAll([
        OrderRec(id: 'LZ1021', mealName: 'Masala Dosa', providerName: "Amma's Kitchen", imageUrl: Img.dosa, qty: 2, unitPrice: 60, customerName: s.name, location: deliveryLocation, status: 'Delivered', placedAt: DateTime.now().subtract(const Duration(days: 2))),
        OrderRec(id: 'LZ1022', mealName: 'Curd Rice', providerName: 'Sri Lakshmi Meals', imageUrl: Img.curdRice, qty: 1, unitPrice: 60, customerName: s.name, location: deliveryLocation, status: 'Out for delivery'),
      ]);
    customerSubs
      ..clear()
      ..add(Subscription(id: 'SUB300', customerName: s.name, providerName: 'Sri Lakshmi Meals', mealName: 'South Indian Meals', imageUrl: Img.meals, pricePerMeal: 120, days: {0, 1, 3, 4}));

    if (s.type == AccountType.businessOwner) {
      ownerBusiness = FoodProvider(
        id: 'owner',
        name: s.businessName ?? 'My Food Business',
        type: 'Local food business',
        imageUrl: Img.meals,
        rating: 0,
        rangeKm: 3,
        location: s.businessLocation ?? 'Add your location',
        phone: s.phone,
        description: 'Fresh South Indian food made daily.',
      );
      ownerMeals
        ..clear()
        ..addAll([
          Meal(id: 'o1', providerId: 'owner', name: 'Idli (3 pcs)', description: 'Soft steamed idlis with sambar and chutney.', price: 40, category: 'Breakfast', imageUrl: Img.idli),
          Meal(id: 'o2', providerId: 'owner', name: 'Ven Pongal', description: 'Creamy pongal with pepper, cumin and ghee.', price: 50, category: 'Breakfast', imageUrl: Img.pongal),
          Meal(id: 'o3', providerId: 'owner', name: 'Chicken Meals', description: 'Rice, Andhra chicken curry, rasam and curd.', price: 150, category: 'Meals', imageUrl: Img.chickenCurry),
        ]);
      ownerOrders
        ..clear()
        ..addAll([
          OrderRec(id: 'LZ1024', mealName: 'Chicken Meals', providerName: ownerBusiness.name, imageUrl: Img.chickenCurry, qty: 2, unitPrice: 150, customerName: 'Arjun', location: 'Gandhi Nagar', status: 'New'),
          OrderRec(id: 'LZ1023', mealName: 'Idli (3 pcs)', providerName: ownerBusiness.name, imageUrl: Img.idli, qty: 4, unitPrice: 40, customerName: 'Sravani', location: 'Patamata', status: 'Preparing'),
          OrderRec(id: 'LZ1020', mealName: 'Ven Pongal', providerName: ownerBusiness.name, imageUrl: Img.pongal, qty: 2, unitPrice: 50, customerName: 'Karthik', location: 'Benz Circle', status: 'Out for delivery'),
        ]);
      ownerSubs
        ..clear()
        ..addAll([
          Subscription(id: 'SUB101', customerName: 'Priya', providerName: ownerBusiness.name, mealName: 'Chicken Meals', imageUrl: Img.chickenCurry, pricePerMeal: 150, days: {0, 1, 3}),
          Subscription(id: 'SUB102', customerName: 'Ravi', providerName: ownerBusiness.name, mealName: 'Idli (3 pcs)', imageUrl: Img.idli, pricePerMeal: 40, days: {0, 1, 2, 3, 4}),
          Subscription(id: 'SUB103', customerName: 'Meena', providerName: ownerBusiness.name, mealName: 'Ven Pongal', imageUrl: Img.pongal, pricePerMeal: 50, days: {1, 3, 5}),
        ]);
    }
  }

  static void endSession() {
    user = null;
  }
}

// Tiny cross-screen "remote controls" (built-in ValueNotifier, no packages)
final ValueNotifier<int> customerTab = ValueNotifier<int>(0);
final ValueNotifier<int> businessTab = ValueNotifier<int>(0);
final ValueNotifier<int> ordersSubTab = ValueNotifier<int>(0);
final ValueNotifier<String> exploreQuery = ValueNotifier<String>('');
final ValueNotifier<String?> exploreCategory = ValueNotifier<String?>(null);

// ============================================================================
// 6. AUTH SERVICE (Firebase Authentication)
// ============================================================================
// registerCustomer(), registerBusinessOwner(), loginUser(), logoutUser()
// Roles are kept in a local map for now. Later: store in Firestore users/{uid}.

class AuthResult {
  final UserSession? session;
  final String? error;
  final bool needsRole;
  const AuthResult({this.session, this.error, this.needsRole = false});
}

class AuthService {
  static final Map<String, AccountType> _localRoles = {};
  static final Map<String, Map<String, String>> _localProfiles = {};

  static AuthResult _unavailable() => AuthResult(
        error: firebaseInitMessage.isEmpty
            ? 'Firebase is not available right now. Please try again later.'
            : firebaseInitMessage,
      );

  static String _friendly(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address does not look right.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account with this email already exists. Try logging in.';
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'network-request-failed':
        return 'No internet connection. Please check your network.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'operation-not-allowed':
        return 'Email/Password sign-in is not enabled. Enable it in Firebase Console → Authentication → Sign-in method.';
      default:
        return e.message ?? 'Authentication failed (${e.code}).';
    }
  }

  static Future<AuthResult> _register({
    required AccountType type,
    required String name,
    required String email,
    required String phone,
    required String password,
    String? businessName,
    String? businessLocation,
  }) async {
    if (!firebaseReady) return _unavailable();
    try {
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email.trim(), password: password);
      final user = cred.user!;
      await user.updateDisplayName(name.trim());
      _localRoles[user.uid] = type;
      _localProfiles[user.uid] = {
        'name': name.trim(),
        'phone': phone.trim(),
        if (businessName != null) 'businessName': businessName.trim(),
        if (businessLocation != null) 'businessLocation': businessLocation.trim(),
      };
      // FUTURE FIRESTORE: users/{uid} = {role: type.code, name, phone}
      //                   businesses/{uid} = {...} when type == businessOwner
      return AuthResult(
        session: UserSession(
          uid: user.uid,
          name: name.trim(),
          email: user.email ?? email.trim(),
          phone: phone.trim(),
          type: type,
          businessName: businessName?.trim(),
          businessLocation: businessLocation?.trim(),
        ),
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _friendly(e));
    } catch (e) {
      return AuthResult(error: 'Something went wrong: $e');
    }
  }

  static Future<AuthResult> registerCustomer({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) =>
      _register(type: AccountType.customer, name: name, email: email, phone: phone, password: password);

  static Future<AuthResult> registerBusinessOwner({
    required String ownerName,
    required String businessName,
    required String email,
    required String phone,
    required String businessLocation,
    required String password,
  }) =>
      _register(
        type: AccountType.businessOwner,
        name: ownerName,
        email: email,
        phone: phone,
        password: password,
        businessName: businessName,
        businessLocation: businessLocation,
      );

  static Future<AuthResult> loginUser({required String email, required String password}) async {
    if (!firebaseReady) return _unavailable();
    try {
      final cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
      final user = cred.user!;
      final role = _localRoles[user.uid];
      final prof = _localProfiles[user.uid] ?? <String, String>{};
      return AuthResult(
        needsRole: role == null,
        session: UserSession(
          uid: user.uid,
          name: user.displayName ?? prof['name'] ?? email.split('@').first,
          email: user.email ?? email.trim(),
          phone: prof['phone'] ?? '',
          type: role ?? AccountType.customer,
          businessName: prof['businessName'],
          businessLocation: prof['businessLocation'],
        ),
      );
    } on FirebaseAuthException catch (e) {
      return AuthResult(error: _friendly(e));
    } catch (e) {
      return AuthResult(error: 'Something went wrong: $e');
    }
  }

  static void saveRole(String uid, AccountType t) => _localRoles[uid] = t;

  static Future<void> logoutUser() async {
    try {
      if (firebaseReady) await FirebaseAuth.instance.signOut();
    } catch (_) {}
    Store.endSession();
  }
}

// ============================================================================
// 7. REUSABLE UI WIDGETS
// ============================================================================

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmText = 'Yes',
  String cancelText = 'No',
}) async {
  final res = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LZ.cream,
      title: Text(title, style: hStyle(20)),
      content: Text(message, style: bStyle(15)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(cancelText)),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmText),
        ),
      ],
    ),
  );
  return res ?? false;
}

Future<void> editLocationDialog(BuildContext context) async {
  final c = TextEditingController(text: Store.deliveryLocation);
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: LZ.cream,
      title: Text('Delivery location', style: hStyle(20)),
      content: TextField(
        controller: c,
        decoration: const InputDecoration(
            labelText: 'Area / address', prefixIcon: Icon(Icons.location_on_outlined)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (ok == true && c.text.trim().isNotEmpty) {
    Store.deliveryLocation = c.text.trim();
  }
}

/// Centers content with a max width and keeps layouts tidy on tablet/desktop.
class ResponsiveBody extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  final EdgeInsets padding;
  const ResponsiveBody({
    super.key,
    required this.child,
    this.maxWidth = 1000,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        heightFactor: 1,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Padding(padding: padding, child: child),
        ),
      );
}

/// Lays children out in as many equal-width columns as will fit.
class AdaptiveWrap extends StatelessWidget {
  final List<Widget> children;
  final double minTileWidth;
  final double spacing;
  const AdaptiveWrap({super.key, required this.children, this.minTileWidth = 320, this.spacing = 12});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, c) {
        final w = c.maxWidth;
        int cols = (w / minTileWidth).floor();
        if (cols < 1) cols = 1;
        final tileW = ((w - spacing * (cols - 1)) / cols).floorToDouble();
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children.map((e) => SizedBox(width: tileW, child: e)).toList(),
        );
      });
}

class LzCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? color;
  const LzCard({super.key, required this.child, this.padding = const EdgeInsets.all(14), this.onTap, this.color});
  @override
  Widget build(BuildContext context) => Material(
        color: color ?? Colors.white,
        elevation: 2,
        shadowColor: tint(Colors.black, 0.25),
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: tint(LZ.gold, 0.3)),
        ),
        child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
      );
}

/// Network food image with loading + error fallback so the UI never breaks.
class FoodImage extends StatelessWidget {
  final String url;
  final String label;
  final double height;
  final double? width;
  final double radius;
  const FoodImage({super.key, required this.url, required this.label, required this.height, this.width, this.radius = 14});

  Widget _fallback() => Container(
        color: tint(LZ.turmeric, 0.25),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        child: height < 100
            ? const Icon(Icons.rice_bowl_rounded, color: LZ.maroon)
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.rice_bowl_rounded, color: LZ.maroon, size: 38),
                  const SizedBox(height: 6),
                  Text(label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: bStyle(13, color: LZ.maroon, weight: FontWeight.w600)),
                  Text('Image unavailable', style: bStyle(11, color: LZ.muted)),
                ],
              ),
      );

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          height: height,
          width: width,
          child: Image.network(
            url,
            fit: BoxFit.cover,
            headers: kIsWeb ? null : const {'User-Agent': 'LOCALZ-College-Prototype/1.0'},
            loadingBuilder: (ctx, child, progress) {
              if (progress == null) return child;
              return Container(
                color: LZ.creamDark,
                alignment: Alignment.center,
                child: const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: LZ.gold),
                ),
              );
            },
            errorBuilder: (ctx, err, st) => _fallback(),
          ),
        ),
      );
}

/// Small kolam-inspired dot-and-loop pattern.
class _KolamDotsPainter extends CustomPainter {
  final Color color;
  _KolamDotsPainter({required this.color});
  @override
  void paint(Canvas canvas, Size size) {
    const n = 5;
    final gap = math.min(size.width, size.height) / n;
    final span = (n - 1) * gap;
    final ox = (size.width - span) / 2;
    final oy = (size.height - span) / 2;
    final loop = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    final dot = Paint()..color = color;
    for (int i = 0; i < n; i++) {
      for (int j = 0; j < n; j++) {
        if ((i - 2).abs() + (j - 2).abs() <= 2) {
          final c = Offset(ox + i * gap, oy + j * gap);
          canvas.drawCircle(c, 2.2, dot);
          canvas.drawCircle(c, gap * 0.5, loop);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Gold line with a small diamond ornament in the middle.
class KolamDivider extends StatelessWidget {
  const KolamDivider({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: SizedBox(height: 14, width: double.infinity, child: CustomPaint(painter: _DividerPainter())),
      );
}

class _DividerPainter extends CustomPainter {
  const _DividerPainter();
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = tint(LZ.gold, 0.6)
      ..strokeWidth = 1;
    final cy = size.height / 2;
    final mid = size.width / 2;
    canvas.drawLine(Offset(0, cy), Offset(mid - 44, cy), line);
    canvas.drawLine(Offset(mid + 44, cy), Offset(size.width, cy), line);
    for (int i = -2; i <= 2; i++) {
      final x = mid + i * 16.0;
      final s = i == 0 ? 5.5 : 3.0;
      final path = Path()
        ..moveTo(x, cy - s)
        ..lineTo(x + s, cy)
        ..lineTo(x, cy + s)
        ..lineTo(x - s, cy)
        ..close();
      canvas.drawPath(path, Paint()..color = i == 0 ? LZ.maroon : LZ.gold);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

/// Temple-border inspired strip of small triangles.
class TempleBorder extends StatelessWidget {
  final Color color;
  const TempleBorder({super.key, this.color = LZ.maroon});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 10,
        width: double.infinity,
        child: CustomPaint(painter: _TemplePainter(color)),
      );
}

class _TemplePainter extends CustomPainter {
  final Color color;
  _TemplePainter(this.color);
  @override
  void paint(Canvas canvas, Size size) {
    const w = 14.0;
    final p = Paint()..color = color;
    final g = Paint()..color = LZ.turmeric;
    for (double x = 0; x < size.width; x += w) {
      final path = Path()
        ..moveTo(x, 0)
        ..lineTo(x + w, 0)
        ..lineTo(x + w / 2, size.height)
        ..close();
      canvas.drawPath(path, p);
      canvas.drawCircle(Offset(x + w / 2, size.height - 3), 1.2, g);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => old is _TemplePainter && old.color != color;
}

/// Maroon header band used at the top of tabs.
class HeaderBand extends StatelessWidget {
  final Widget child;
  const HeaderBand({super.key, required this.child});
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            color: LZ.maroon,
            child: Stack(
              children: [
                Positioned(
                  right: -30,
                  top: -30,
                  child: IgnorePointer(
                    child: CustomPaint(
                      size: const Size(170, 170),
                      painter: _KolamDotsPainter(color: tint(LZ.turmeric, 0.22)),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: ResponsiveBody(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                    child: child,
                  ),
                ),
              ],
            ),
          ),
          const TempleBorder(),
        ],
      );
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 22, bottom: 10),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: hStyle(20)),
                  if (subtitle != null) Text(subtitle!, style: bStyle(13, color: LZ.muted)),
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      );
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});
  Color get _color {
    switch (status) {
      case 'New':
        return LZ.terracotta;
      case 'Preparing':
        return LZ.gold;
      case 'Out for delivery':
      case 'Delivered':
      case 'Active':
        return LZ.green;
      default:
        return LZ.muted;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: tint(_color, 0.14), borderRadius: BorderRadius.circular(20)),
        child: Text(status, style: TextStyle(color: _color, fontSize: 12, fontWeight: FontWeight.w700)),
      );
}

class SmallTag extends StatelessWidget {
  final String text;
  final Color color;
  final IconData? icon;
  const SmallTag(this.text, {super.key, this.color = LZ.green, this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: tint(color, 0.12), borderRadius: BorderRadius.circular(8)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[Icon(icon, size: 13, color: color), const SizedBox(width: 3)],
            Flexible(
              child: Text(text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      );
}

/// Seven small circles (M T W T F S S); selected days are filled green.
class DayPills extends StatelessWidget {
  final Set<int> days;
  const DayPills(this.days, {super.key});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(7, (i) {
          final on = days.contains(i);
          return Container(
            margin: const EdgeInsets.only(right: 4),
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: on ? LZ.green : tint(LZ.muted, 0.12),
            ),
            child: Text(kDayLetters[i],
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: on ? Colors.white : LZ.muted)),
          );
        }),
      );
}

class KeyValueRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const KeyValueRow(this.label, this.value, {super.key, this.bold = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: Text(label, style: bStyle(14, color: LZ.muted))),
            Expanded(
              child: Text(value,
                  style: bStyle(bold ? 17 : 14,
                      color: bold ? LZ.maroon : LZ.ink,
                      weight: bold ? FontWeight.w800 : FontWeight.w600)),
            ),
          ],
        ),
      );
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  const EmptyState({super.key, required this.icon, required this.message});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: tint(LZ.gold, 0.7)),
              const SizedBox(height: 10),
              Text(message, textAlign: TextAlign.center, style: bStyle(15, color: LZ.muted)),
            ],
          ),
        ),
      );
}

class ErrorBox extends StatelessWidget {
  final String message;
  const ErrorBox(this.message, {super.key});
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: tint(LZ.terracotta, 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint(LZ.terracotta, 0.5)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: LZ.terracotta, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: bStyle(13.5, color: LZ.ink))),
          ],
        ),
      );
}

class _RoundBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _RoundBtn(this.icon, this.onTap);
  @override
  Widget build(BuildContext context) => Material(
        color: onTap == null ? tint(LZ.muted, 0.12) : tint(LZ.turmeric, 0.3),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 20, color: onTap == null ? LZ.muted : LZ.maroon),
          ),
        ),
      );
}

class QtyStepper extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  const QtyStepper({super.key, required this.value, required this.onChanged, this.min = 1, this.max = 20});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _RoundBtn(Icons.remove, value > min ? () => onChanged(value - 1) : null),
          Container(
            width: 44,
            alignment: Alignment.center,
            child: Text('$value', style: hStyle(20, color: LZ.ink)),
          ),
          _RoundBtn(Icons.add, value < max ? () => onChanged(value + 1) : null),
        ],
      );
}

Widget lzField({
  required TextEditingController controller,
  required String label,
  IconData? icon,
  String? Function(String?)? validator,
  TextInputType? keyboard,
  bool obscure = false,
  Widget? suffix,
  int maxLines = 1,
  void Function(String)? onChanged,
}) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        validator: validator,
        keyboardType: keyboard,
        obscureText: obscure,
        maxLines: maxLines,
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: icon == null ? null : Icon(icon, color: LZ.gold),
          suffixIcon: suffix,
        ),
      ),
    );

String? requiredValidator(String? v, [String label = 'This field']) =>
    (v == null || v.trim().isEmpty) ? '$label is required' : null;

String? emailValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Email is required';
  if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim())) return 'Enter a valid email';
  return null;
}

String? phoneValidator(String? v) {
  if (v == null || v.trim().isEmpty) return 'Phone number is required';
  final digits = v.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length < 10) return 'Enter a valid phone number';
  return null;
}

String? passwordValidator(String? v) {
  if (v == null || v.isEmpty) return 'Password is required';
  if (v.length < 6) return 'Use at least 6 characters';
  return null;
}

/// Hands the session to AuthGate then closes all auth screens.
void finishAuth(BuildContext context, void Function(UserSession) cb, UserSession s) {
  cb(s);
  Navigator.of(context).popUntil((r) => r.isFirst);
}

// ============================================================================
// 8. APP ROOT + AUTH GATE
// ============================================================================

class LocalzApp extends StatelessWidget {
  const LocalzApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'LOCALZ',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: const AuthGate(),
      );
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});
  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  UserSession? _session;

  void _onAuthenticated(UserSession s) {
    Store.startSession(s);
    customerTab.value = 0;
    businessTab.value = 0;
    setState(() => _session = s);
  }

  Future<void> _logout() async {
    await AuthService.logoutUser();
    if (!mounted) return;
    setState(() => _session = null);
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    if (s == null) return WelcomeScreen(onAuthenticated: _onAuthenticated);
    if (s.type == AccountType.customer) {
      return CustomerShell(session: s, onLogout: _logout);
    }
    return BusinessShell(session: s, onLogout: _logout);
  }
}

// ============================================================================
// 9. WELCOME / LOGIN / REGISTER SCREENS
// ============================================================================

class WelcomeScreen extends StatelessWidget {
  final void Function(UserSession) onAuthenticated;
  const WelcomeScreen({super.key, required this.onAuthenticated});

  void _demo(AccountType t) {
    onAuthenticated(UserSession(
      uid: 'demo-${t.code}',
      name: t == AccountType.customer ? 'Demo Customer' : 'Demo Owner',
      email: 'demo@localz.app',
      phone: '9000000000',
      type: t,
      businessName: t == AccountType.businessOwner ? 'Demo Tiffin Centre' : null,
      businessLocation: t == AccountType.businessOwner ? 'Sample Street, Vijayawada' : null,
      isDemo: true,
    ));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 140,
                      height: 140,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CustomPaint(
                            size: const Size(140, 140),
                            painter: _KolamDotsPainter(color: tint(LZ.gold, 0.7)),
                          ),
                          Container(
                            width: 76,
                            height: 76,
                            decoration: BoxDecoration(
                              color: LZ.maroon,
                              shape: BoxShape.circle,
                              border: Border.all(color: LZ.turmeric, width: 3),
                            ),
                            child: const Icon(Icons.rice_bowl_rounded, color: LZ.turmeric, size: 38),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('LOCALZ', style: hStyle(42).copyWith(letterSpacing: 5)),
                    const SizedBox(height: 4),
                    Text('Local food. Flexible meals.',
                        style: bStyle(17, color: LZ.gold, weight: FontWeight.w600)
                            .copyWith(fontStyle: FontStyle.italic)),
                    const KolamDivider(),
                    Text(
                      'Flexible meal subscriptions from local food businesses, with meals only on the days you need them.',
                      textAlign: TextAlign.center,
                      style: bStyle(15, color: LZ.muted),
                    ),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => LoginScreen(onAuthenticated: onAuthenticated)),
                        ),
                        child: const Text('Login'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => AccountTypeScreen(onAuthenticated: onAuthenticated)),
                        ),
                        child: const Text('Create Account'),
                      ),
                    ),
                    if (!firebaseReady) ...[
                      const SizedBox(height: 22),
                      ErrorBox(firebaseInitMessage),
                      Text('Preview the prototype without signing in:', style: bStyle(13, color: LZ.muted)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          TextButton.icon(
                            onPressed: () => _demo(AccountType.customer),
                            icon: const Icon(Icons.person_outline),
                            label: const Text('Demo: Customer'),
                          ),
                          TextButton.icon(
                            onPressed: () => _demo(AccountType.businessOwner),
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Demo: Food Business'),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 20),
                    Text(
                      'College prototype • Sample businesses and images are for demo only',
                      textAlign: TextAlign.center,
                      style: bStyle(12, color: LZ.muted),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class LoginScreen extends StatefulWidget {
  final void Function(UserSession) onAuthenticated;
  const LoginScreen({super.key, required this.onAuthenticated});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<AccountType> _askRole() async {
    final t = await showDialog<AccountType>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: LZ.cream,
        title: Text('Which account is this?', style: hStyle(20)),
        content: Text(
          'This device does not know the account type for this login yet '
          '(roles will be stored in Firestore later). Please choose one.',
          style: bStyle(14),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, AccountType.customer), child: const Text('Customer')),
          FilledButton(
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
            onPressed: () => Navigator.pop(ctx, AccountType.businessOwner),
            child: const Text('Food Business'),
          ),
        ],
      ),
    );
    return t ?? AccountType.customer;
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final r = await AuthService.loginUser(email: _email.text, password: _pass.text);
    if (!mounted) return;
    if (r.session == null) {
      setState(() {
        _busy = false;
        _error = r.error;
      });
      return;
    }
    final s = r.session!;
    if (r.needsRole) {
      final t = await _askRole();
      if (!mounted) return;
      s.type = t;
      AuthService.saveRole(s.uid, t);
    }
    setState(() => _busy = false);
    finishAuth(context, widget.onAuthenticated, s);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Login')),
        body: SingleChildScrollView(
          child: ResponsiveBody(
            maxWidth: 460,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Welcome back', style: hStyle(28)),
                  const SizedBox(height: 4),
                  Text('Log in to continue with LOCALZ.', style: bStyle(15, color: LZ.muted)),
                  const KolamDivider(),
                  if (!firebaseReady) ErrorBox(firebaseInitMessage),
                  if (_error != null) ErrorBox(_error!),
                  lzField(
                    controller: _email,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: emailValidator,
                  ),
                  lzField(
                    controller: _pass,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: _hide,
                    validator: (v) => requiredValidator(v, 'Password'),
                    suffix: IconButton(
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Login'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => AccountTypeScreen(onAuthenticated: widget.onAuthenticated)),
                      ),
                      child: const Text('New here? Create account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

class AccountTypeScreen extends StatelessWidget {
  final void Function(UserSession) onAuthenticated;
  const AccountTypeScreen({super.key, required this.onAuthenticated});

  Widget _option(BuildContext context, AccountType t, IconData icon, String desc, Color color) => LzCard(
        padding: const EdgeInsets.all(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RegisterScreen(type: t, onAuthenticated: onAuthenticated)),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(color: tint(color, 0.14), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.label, style: hStyle(20)),
                  const SizedBox(height: 4),
                  Text(desc, style: bStyle(14, color: LZ.muted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: LZ.gold),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create Account')),
        body: SingleChildScrollView(
          child: ResponsiveBody(
            maxWidth: 520,
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('How will you use LOCALZ?', style: hStyle(26)),
                const SizedBox(height: 4),
                Text('Choose your account type to continue.', style: bStyle(15, color: LZ.muted)),
                const KolamDivider(),
                _option(
                  context,
                  AccountType.customer,
                  Icons.person_rounded,
                  'Discover local meals, order when you need them, and create flexible meal plans.',
                  LZ.green,
                ),
                const SizedBox(height: 14),
                _option(
                  context,
                  AccountType.businessOwner,
                  Icons.storefront_rounded,
                  'Reach local customers, manage meals, and receive orders and subscriptions.',
                  LZ.terracotta,
                ),
              ],
            ),
          ),
        ),
      );
}

class RegisterScreen extends StatefulWidget {
  final AccountType type;
  final void Function(UserSession) onAuthenticated;
  const RegisterScreen({super.key, required this.type, required this.onAuthenticated});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _business = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _pass = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _hide = true;
  String? _error;

  bool get _isCustomer => widget.type == AccountType.customer;

  @override
  void dispose() {
    for (final c in [_name, _business, _email, _phone, _location, _pass, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final AuthResult r = _isCustomer
        ? await AuthService.registerCustomer(
            name: _name.text, email: _email.text, phone: _phone.text, password: _pass.text)
        : await AuthService.registerBusinessOwner(
            ownerName: _name.text,
            businessName: _business.text,
            email: _email.text,
            phone: _phone.text,
            businessLocation: _location.text,
            password: _pass.text);
    if (!mounted) return;
    setState(() => _busy = false);
    if (r.session == null) {
      setState(() => _error = r.error);
      return;
    }
    finishAuth(context, widget.onAuthenticated, r.session!);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_isCustomer ? 'Customer Account' : 'Food Business Account')),
        body: SingleChildScrollView(
          child: ResponsiveBody(
            maxWidth: 520,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_isCustomer ? 'Create your account' : 'Register your business', style: hStyle(26)),
                  const KolamDivider(),
                  if (!firebaseReady) ErrorBox(firebaseInitMessage),
                  if (_error != null) ErrorBox(_error!),
                  lzField(
                    controller: _name,
                    label: _isCustomer ? 'Full name' : 'Owner name',
                    icon: Icons.person_outline,
                    validator: (v) => requiredValidator(v, 'Name'),
                  ),
                  if (!_isCustomer)
                    lzField(
                      controller: _business,
                      label: 'Business name',
                      icon: Icons.storefront_outlined,
                      validator: (v) => requiredValidator(v, 'Business name'),
                    ),
                  lzField(
                    controller: _email,
                    label: 'Email',
                    icon: Icons.email_outlined,
                    keyboard: TextInputType.emailAddress,
                    validator: emailValidator,
                  ),
                  lzField(
                    controller: _phone,
                    label: 'Phone number',
                    icon: Icons.phone_outlined,
                    keyboard: TextInputType.phone,
                    validator: phoneValidator,
                  ),
                  if (!_isCustomer)
                    lzField(
                      controller: _location,
                      label: 'Business location',
                      icon: Icons.location_on_outlined,
                      validator: (v) => requiredValidator(v, 'Business location'),
                    ),
                  lzField(
                    controller: _pass,
                    label: 'Password',
                    icon: Icons.lock_outline,
                    obscure: _hide,
                    validator: passwordValidator,
                    suffix: IconButton(
                      icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                      onPressed: () => setState(() => _hide = !_hide),
                    ),
                  ),
                  lzField(
                    controller: _confirm,
                    label: 'Confirm password',
                    icon: Icons.lock_reset_outlined,
                    obscure: _hide,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Please confirm your password';
                      if (v != _pass.text) return 'Passwords do not match';
                      return null;
                    },
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                          : const Text('Create Account'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ============================================================================
// 10. SHARED SHELL (bottom nav on phones, side rail on tablet/desktop)
// ============================================================================

class ShellScaffold extends StatelessWidget {
  final ValueNotifier<int> tab;
  final List<IconData> icons;
  final List<String> labels;
  final Widget Function(int) pageBuilder;
  const ShellScaffold({
    super.key,
    required this.tab,
    required this.icons,
    required this.labels,
    required this.pageBuilder,
  });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
        valueListenable: tab,
        builder: (context, idx, _) => LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 800;
          final body = pageBuilder(idx);
          return Scaffold(
            body: wide
                ? Row(
                    children: [
                      NavigationRail(
                        selectedIndex: idx,
                        onDestinationSelected: (i) => tab.value = i,
                        labelType: NavigationRailLabelType.all,
                        backgroundColor: Colors.white,
                        indicatorColor: tint(LZ.turmeric, 0.45),
                        leading: Padding(
                          padding: const EdgeInsets.only(top: 24, bottom: 12),
                          child: Text('LOCALZ', style: hStyle(18).copyWith(letterSpacing: 2)),
                        ),
                        destinations: [
                          for (int i = 0; i < icons.length; i++)
                            NavigationRailDestination(icon: Icon(icons[i]), label: Text(labels[i])),
                        ],
                      ),
                      const VerticalDivider(width: 1),
                      Expanded(child: body),
                    ],
                  )
                : body,
            bottomNavigationBar: wide
                ? null
                : NavigationBar(
                    selectedIndex: idx,
                    onDestinationSelected: (i) => tab.value = i,
                    destinations: [
                      for (int i = 0; i < icons.length; i++)
                        NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
                    ],
                  ),
          );
        }),
      );
}

// ============================================================================
// 11. CUSTOMER SIDE
// ============================================================================

class CustomerShell extends StatelessWidget {
  final UserSession session;
  final VoidCallback onLogout;
  const CustomerShell({super.key, required this.session, required this.onLogout});

  @override
  Widget build(BuildContext context) => ShellScaffold(
        tab: customerTab,
        icons: const [Icons.home_rounded, Icons.explore_rounded, Icons.receipt_long_rounded, Icons.person_rounded],
        labels: const ['Home', 'Explore', 'Orders', 'Profile'],
        pageBuilder: (i) {
          switch (i) {
            case 0:
              return const HomeTab();
            case 1:
              return const ExploreTab();
            case 2:
              return const OrdersTab();
            default:
              return ProfileTab(session: session, onLogout: onLogout);
          }
        },
      );
}

// ---------- Cards used on customer screens ----------

class ProviderCard extends StatelessWidget {
  final FoodProvider provider;
  const ProviderCard({super.key, required this.provider});
  @override
  Widget build(BuildContext context) => LzCard(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: provider)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FoodImage(url: provider.imageUrl, label: provider.name, height: 130, radius: 0),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(provider.name, style: hStyle(18), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(provider.type, style: bStyle(13, color: LZ.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      SmallTag(provider.rating.toStringAsFixed(1), color: LZ.gold, icon: Icons.star_rounded),
                      SmallTag('Serves ${provider.rangeKm.toStringAsFixed(provider.rangeKm % 1 == 0 ? 0 : 1)} km',
                          color: LZ.green, icon: Icons.delivery_dining_rounded),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(provider.description, style: bStyle(13), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      );
}

class MealCard extends StatelessWidget {
  final Meal meal;
  final bool showProvider;
  const MealCard({super.key, required this.meal, this.showProvider = true});
  @override
  Widget build(BuildContext context) => LzCard(
        padding: const EdgeInsets.all(10),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => MealDetailScreen(meal: meal)),
        ),
        child: Row(
          children: [
            FoodImage(url: meal.imageUrl, label: meal.name, height: 84, width: 84, radius: 12),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(meal.name, style: bStyle(16, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (showProvider)
                    Text(Store.providerName(meal.providerId),
                        style: bStyle(13, color: LZ.muted), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(money(meal.price), style: hStyle(18)),
                      const SizedBox(width: 8),
                      Flexible(child: SmallTag(meal.category, color: LZ.terracotta)),
                      if (!meal.available) ...[
                        const SizedBox(width: 6),
                        const Flexible(child: SmallTag('Sold out', color: LZ.muted)),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

Widget searchField({
  required TextEditingController controller,
  required String hint,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
}) =>
    TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, color: LZ.gold),
        fillColor: Colors.white,
      ),
    );

// ---------- Home ----------

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});
  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _goSearch(String q) {
    exploreQuery.value = q.trim();
    exploreCategory.value = null;
    customerTab.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    final popular = Store.meals.where((m) => m.available).take(6).toList();
    final firstName = (Store.user?.name ?? 'friend').split(' ').first;
    final planMeal = Store.meals.firstWhere((m) => m.category == 'Meals' && m.available);

    return SingleChildScrollView(
      child: Column(
        children: [
          HeaderBand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Namaste, $firstName', style: bStyle(14, color: LZ.turmeric, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    await editLocationDialog(context);
                    if (mounted) setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: tint(Colors.white, 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on_rounded, size: 16, color: LZ.turmeric),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(Store.deliveryLocation,
                              overflow: TextOverflow.ellipsis,
                              style: bStyle(13, color: Colors.white, weight: FontWeight.w600)),
                        ),
                        const Icon(Icons.expand_more_rounded, size: 18, color: Colors.white),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text('Good food, from local kitchens.', style: hStyle(28, color: Colors.white)),
                const SizedBox(height: 6),
                Text('Discover meals from food businesses around you.',
                    style: bStyle(15, color: tint(Colors.white, 0.85))),
                const SizedBox(height: 16),
                searchField(
                  controller: _search,
                  hint: 'Search meals or kitchens',
                  onSubmitted: _goSearch,
                ),
              ],
            ),
          ),
          ResponsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Categories'),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final c in kCategories)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ActionChip(
                            avatar: Icon(categoryIcon(c), size: 18, color: LZ.maroon),
                            label: Text(c),
                            backgroundColor: Colors.white,
                            side: BorderSide(color: tint(LZ.gold, 0.5)),
                            onPressed: () {
                              exploreCategory.value = c;
                              exploreQuery.value = '';
                              customerTab.value = 1;
                            },
                          ),
                        ),
                    ],
                  ),
                ),
                SectionTitle('Featured providers',
                    subtitle: 'Sample local kitchens',
                    trailing: TextButton(onPressed: () => customerTab.value = 1, child: const Text('See all'))),
                SizedBox(
                  height: 330,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: Store.providers.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (_, i) => SizedBox(width: 270, child: ProviderCard(provider: Store.providers[i])),
                  ),
                ),
                const SectionTitle('Popular meals'),
                AdaptiveWrap(children: [for (final m in popular) MealCard(meal: m)]),
                const SizedBox(height: 22),
                LzCard(
                  color: tint(LZ.green, 0.08),
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.calendar_month_rounded, color: LZ.green),
                          const SizedBox(width: 8),
                          Expanded(child: Text('Only the days you need', style: hStyle(19, color: LZ.green))),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pick just the days you want meals — skip the rest. No fixed Monday-to-Sunday plan.',
                        style: bStyle(14),
                      ),
                      const SizedBox(height: 12),
                      const DayPills({0, 1, 3, 4}),
                      const SizedBox(height: 14),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: LZ.green),
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SubscribeScreen.fromMeal(planMeal)),
                        ),
                        icon: const Icon(Icons.event_available_rounded),
                        label: const Text('Plan my week'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Explore ----------

class ExploreTab extends StatefulWidget {
  const ExploreTab({super.key});
  @override
  State<ExploreTab> createState() => _ExploreTabState();
}

class _ExploreTabState extends State<ExploreTab> {
  late final TextEditingController _q;
  String? _cat;

  @override
  void initState() {
    super.initState();
    _q = TextEditingController(text: exploreQuery.value);
    _cat = exploreCategory.value;
    exploreQuery.value = '';
    exploreCategory.value = null;
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _q.text.trim().toLowerCase();
    final providers = Store.providers.where((p) {
      final matchQ = q.isEmpty || p.name.toLowerCase().contains(q) || p.type.toLowerCase().contains(q);
      final matchC = _cat == null || Store.meals.any((m) => m.providerId == p.id && m.category == _cat);
      return matchQ && matchC;
    }).toList();
    final meals = Store.meals.where((m) {
      if (!m.available) return false;
      if (_cat != null && m.category != _cat) return false;
      if (q.isEmpty) return true;
      return m.name.toLowerCase().contains(q) ||
          m.description.toLowerCase().contains(q) ||
          Store.providerName(m.providerId).toLowerCase().contains(q);
    }).toList();

    return Column(
      children: [
        HeaderBand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Explore', style: hStyle(26, color: Colors.white)),
              const SizedBox(height: 12),
              searchField(controller: _q, hint: 'Search meals or kitchens', onChanged: (_) => setState(() {})),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: ResponsiveBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final c in [null, ...kCategories])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(c ?? 'All'),
                              selected: _cat == c,
                              selectedColor: tint(LZ.turmeric, 0.5),
                              backgroundColor: Colors.white,
                              side: BorderSide(color: tint(LZ.gold, 0.5)),
                              onSelected: (_) => setState(() => _cat = c),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (providers.isEmpty && meals.isEmpty)
                    const EmptyState(icon: Icons.search_off_rounded, message: 'Nothing matched. Try another search or category.'),
                  if (providers.isNotEmpty) ...[
                    const SectionTitle('Kitchens'),
                    AdaptiveWrap(
                      minTileWidth: 280,
                      children: [for (final p in providers) ProviderCard(provider: p)],
                    ),
                  ],
                  if (meals.isNotEmpty) ...[
                    const SectionTitle('Meals'),
                    AdaptiveWrap(children: [for (final m in meals) MealCard(meal: m)]),
                  ],
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------- Provider details ----------

class ProviderDetailScreen extends StatelessWidget {
  final FoodProvider provider;
  const ProviderDetailScreen({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    final meals = Store.meals.where((m) => m.providerId == provider.id).toList();
    return Scaffold(
      appBar: AppBar(title: Text(provider.name)),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 800,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodImage(url: provider.imageUrl, label: provider.name, height: 220, radius: 18),
              const SizedBox(height: 14),
              Text(provider.name, style: hStyle(26)),
              Text(provider.type, style: bStyle(15, color: LZ.muted)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SmallTag('${provider.rating.toStringAsFixed(1)} rating', color: LZ.gold, icon: Icons.star_rounded),
                  SmallTag(
                      'Serves within ${provider.rangeKm.toStringAsFixed(provider.rangeKm % 1 == 0 ? 0 : 1)} km',
                      color: LZ.green,
                      icon: Icons.delivery_dining_rounded),
                  SmallTag(provider.location, color: LZ.terracotta, icon: Icons.location_on_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Text(provider.description, style: bStyle(15)),
              const SizedBox(height: 6),
              Text('Sample business for this college prototype.', style: bStyle(12, color: LZ.muted)),
              const KolamDivider(),
              Text('Available meals', style: hStyle(20)),
              const SizedBox(height: 10),
              AdaptiveWrap(
                minTileWidth: 340,
                children: [for (final m in meals) MealCard(meal: m, showProvider: false)],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Meal details ----------

class MealDetailScreen extends StatefulWidget {
  final Meal meal;
  const MealDetailScreen({super.key, required this.meal});
  @override
  State<MealDetailScreen> createState() => _MealDetailScreenState();
}

class _MealDetailScreenState extends State<MealDetailScreen> {
  int _qty = 1;

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    final prov = Store.provider(m.providerId);
    return Scaffold(
      appBar: AppBar(title: Text(m.name, overflow: TextOverflow.ellipsis)),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodImage(url: m.imageUrl, label: m.name, height: 260, radius: 18),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(m.name, style: hStyle(26))),
                  Text(money(m.price), style: hStyle(26, color: LZ.terracotta)),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  SmallTag(m.category, color: LZ.terracotta),
                  SmallTag(m.available ? 'Available today' : 'Currently unavailable',
                      color: m.available ? LZ.green : LZ.muted,
                      icon: m.available ? Icons.check_circle_rounded : Icons.block_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Text(m.description, style: bStyle(15)),
              const SizedBox(height: 12),
              LzCard(
                onTap: prov == null || prov.id == 'owner'
                    ? null
                    : () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => ProviderDetailScreen(provider: prov)),
                        ),
                child: Row(
                  children: [
                    const Icon(Icons.storefront_rounded, color: LZ.maroon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Provider', style: bStyle(12, color: LZ.muted)),
                          Text(Store.providerName(m.providerId), style: bStyle(16, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: LZ.gold),
                  ],
                ),
              ),
              const KolamDivider(),
              Row(
                children: [
                  Expanded(child: Text('Quantity', style: hStyle(18, color: LZ.ink))),
                  QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Subtotal: ${money(m.price * _qty)}', style: bStyle(15, color: LZ.muted)),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: m.available
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => SubscribeScreen.fromMeal(m)),
                              )
                          : null,
                      icon: const Icon(Icons.event_repeat_rounded),
                      label: const Text('Subscribe'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: m.available
                          ? () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => CheckoutScreen(meal: m, qty: _qty)),
                              )
                          : null,
                      icon: const Icon(Icons.shopping_bag_rounded),
                      label: const Text('Order Now'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- One-time order ----------

class CheckoutScreen extends StatefulWidget {
  final Meal meal;
  final int qty;
  const CheckoutScreen({super.key, required this.meal, required this.qty});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  late int _qty = widget.qty;
  late final TextEditingController _loc = TextEditingController(text: Store.deliveryLocation);

  @override
  void dispose() {
    _loc.dispose();
    super.dispose();
  }

  void _place() {
    final loc = _loc.text.trim();
    if (loc.isEmpty) {
      toast(context, 'Please enter a delivery location');
      return;
    }
    Store.deliveryLocation = loc;
    final order = OrderRec(
      id: Store.nextOrderId(),
      mealName: widget.meal.name,
      providerName: Store.providerName(widget.meal.providerId),
      imageUrl: widget.meal.imageUrl,
      qty: _qty,
      unitPrice: widget.meal.price,
      customerName: Store.user?.name ?? 'Customer',
      location: loc,
      status: 'New',
    );
    Store.customerOrders.insert(0, order);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => OrderConfirmationScreen(order: order)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.meal;
    return Scaffold(
      appBar: AppBar(title: const Text('Your Order')),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 600,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LzCard(
                child: Row(
                  children: [
                    FoodImage(url: m.imageUrl, label: m.name, height: 72, width: 72, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m.name, style: bStyle(16, weight: FontWeight.w700)),
                          Text(Store.providerName(m.providerId), style: bStyle(13, color: LZ.muted)),
                          const SizedBox(height: 4),
                          Text('${money(m.price)} each', style: bStyle(14, color: LZ.maroon, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text('Quantity', style: hStyle(18, color: LZ.ink))),
                  QtyStepper(value: _qty, onChanged: (v) => setState(() => _qty = v)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _loc,
                decoration: const InputDecoration(
                  labelText: 'Delivery location',
                  prefixIcon: Icon(Icons.location_on_outlined, color: LZ.gold),
                ),
              ),
              const KolamDivider(),
              KeyValueRow('Item price', money(m.price)),
              KeyValueRow('Quantity', '$_qty'),
              KeyValueRow('Total', money(m.price * _qty), bold: true),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: tint(LZ.turmeric, 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.payments_outlined, color: LZ.gold),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Pay on delivery for now. Online payment is a future feature.',
                        style: bStyle(13),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _place,
                  child: Text('Place Order • ${money(m.price * _qty)}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderConfirmationScreen extends StatelessWidget {
  final OrderRec order;
  const OrderConfirmationScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Order confirmation')),
        body: SingleChildScrollView(
          child: ResponsiveBody(
            maxWidth: 560,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: tint(LZ.green, 0.14), shape: BoxShape.circle),
                  child: const Icon(Icons.check_circle_rounded, color: LZ.green, size: 56),
                ),
                const SizedBox(height: 14),
                Text('Order placed successfully', style: hStyle(25), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Thank you for supporting a local kitchen.', style: bStyle(14, color: LZ.muted)),
                const KolamDivider(),
                LzCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    children: [
                      KeyValueRow('Order ID', '#${order.id}', bold: true),
                      KeyValueRow('Meal', '${order.qty} × ${order.mealName}'),
                      KeyValueRow('Provider', order.providerName),
                      KeyValueRow('Deliver to', order.location),
                      KeyValueRow('Total', money(order.total)),
                      KeyValueRow('Estimated', 'About 30–40 minutes (sample estimate)'),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      ordersSubTab.value = 0;
                      customerTab.value = 2;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: const Text('View My Orders'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      customerTab.value = 0;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ---------- Flexible subscription (core feature) ----------

class DayTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const DayTile({super.key, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 76,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? LZ.green : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? LZ.green : tint(LZ.gold, 0.55), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15, color: selected ? Colors.white : LZ.ink)),
              const SizedBox(height: 6),
              Icon(selected ? Icons.check_circle_rounded : Icons.cancel_outlined,
                  size: 26, color: selected ? Colors.white : LZ.muted),
              const SizedBox(height: 4),
              Text(selected ? 'Meal' : 'Skip',
                  style: TextStyle(fontSize: 11, color: selected ? Colors.white : LZ.muted)),
            ],
          ),
        ),
      );
}

class SubscribeScreen extends StatefulWidget {
  final String mealName;
  final String providerName;
  final String imageUrl;
  final int pricePerMeal;
  final Subscription? existing;

  const SubscribeScreen({
    super.key,
    required this.mealName,
    required this.providerName,
    required this.imageUrl,
    required this.pricePerMeal,
    this.existing,
  });

  SubscribeScreen.fromMeal(Meal m, {super.key})
      : mealName = m.name,
        providerName = Store.providerName(m.providerId),
        imageUrl = m.imageUrl,
        pricePerMeal = m.price,
        existing = null;

  @override
  State<SubscribeScreen> createState() => _SubscribeScreenState();
}

class _SubscribeScreenState extends State<SubscribeScreen> {
  late final Set<int> _days = widget.existing != null ? Set<int>.from(widget.existing!.days) : {0, 1, 3, 4};

  bool get _edit => widget.existing != null;
  int get _count => _days.length;
  int get _total => _count * widget.pricePerMeal;

  void _toggle(int i) => setState(() => _days.contains(i) ? _days.remove(i) : _days.add(i));

  void _confirm() {
    if (_days.isEmpty) {
      toast(context, 'Select at least one day');
      return;
    }
    if (_edit) {
      widget.existing!.days = Set<int>.from(_days);
      Navigator.pop(context, true);
      return;
    }
    final sub = Subscription(
      id: Store.nextSubId(),
      customerName: Store.user?.name ?? 'Customer',
      providerName: widget.providerName,
      mealName: widget.mealName,
      imageUrl: widget.imageUrl,
      pricePerMeal: widget.pricePerMeal,
      days: Set<int>.from(_days),
    );
    Store.customerSubs.insert(0, sub);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => SubscriptionConfirmationScreen(sub: sub)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sorted = _days.toList()..sort();
    return Scaffold(
      appBar: AppBar(title: Text(_edit ? 'Manage Subscription' : 'Subscribe')),
      bottomNavigationBar: SafeArea(
        child: ResponsiveBody(
          maxWidth: 700,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _days.isEmpty ? null : _confirm,
              child: Text(_edit ? 'Save Changes' : 'Confirm Subscription'),
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 700,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LzCard(
                child: Row(
                  children: [
                    FoodImage(url: widget.imageUrl, label: widget.mealName, height: 68, width: 68, radius: 12),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(widget.mealName, style: bStyle(17, weight: FontWeight.w700)),
                          Text(widget.providerName, style: bStyle(13, color: LZ.muted)),
                          const SizedBox(height: 2),
                          Text('${money(widget.pricePerMeal)} per meal',
                              style: bStyle(14, color: LZ.maroon, weight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SectionTitle('Choose your days',
                  subtitle: 'Tap a day to switch it on or off. You only get meals on the days you pick.'),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    label: const Text('Weekdays'),
                    backgroundColor: Colors.white,
                    onPressed: () => setState(() {
                      _days
                        ..clear()
                        ..addAll({0, 1, 2, 3, 4});
                    }),
                  ),
                  ActionChip(
                    label: const Text('Weekends'),
                    backgroundColor: Colors.white,
                    onPressed: () => setState(() {
                      _days
                        ..clear()
                        ..addAll({5, 6});
                    }),
                  ),
                  ActionChip(
                    label: const Text('Clear'),
                    backgroundColor: Colors.white,
                    onPressed: () => setState(_days.clear),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (int i = 0; i < 7; i++)
                    DayTile(label: kDaysShort[i], selected: _days.contains(i), onTap: () => _toggle(i)),
                ],
              ),
              const KolamDivider(),
              LzCard(
                padding: const EdgeInsets.all(18),
                color: tint(LZ.turmeric, 0.10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Subscription summary', style: hStyle(19)),
                    const SizedBox(height: 8),
                    KeyValueRow('Meal', widget.mealName),
                    KeyValueRow('Provider', widget.providerName),
                    KeyValueRow('Selected days', sorted.isEmpty ? 'None selected' : sorted.map((i) => kDays[i]).join(', ')),
                    KeyValueRow('Price per meal', money(widget.pricePerMeal)),
                    KeyValueRow('Meals per week', '$_count'),
                    const Divider(height: 24),
                    Text('$_count meals × ${money(widget.pricePerMeal)} = ${money(_total)}',
                        style: hStyle(21, color: LZ.green)),
                    const SizedBox(height: 4),
                    Text('Estimated weekly total • Next meal: ${Store.nextMealText(_days)}',
                        style: bStyle(13, color: LZ.muted)),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class SubscriptionConfirmationScreen extends StatelessWidget {
  final Subscription sub;
  const SubscriptionConfirmationScreen({super.key, required this.sub});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(automaticallyImplyLeading: false, title: const Text('Subscription')),
        body: SingleChildScrollView(
          child: ResponsiveBody(
            maxWidth: 560,
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 84,
                  height: 84,
                  decoration: BoxDecoration(color: tint(LZ.green, 0.14), shape: BoxShape.circle),
                  child: const Icon(Icons.event_available_rounded, color: LZ.green, size: 52),
                ),
                const SizedBox(height: 14),
                Text('Subscription created', style: hStyle(25), textAlign: TextAlign.center),
                const SizedBox(height: 4),
                Text('Meals will arrive only on the days you chose.', style: bStyle(14, color: LZ.muted)),
                const KolamDivider(),
                LzCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      KeyValueRow('Provider', sub.providerName),
                      KeyValueRow('Meal', sub.mealName),
                      KeyValueRow('Selected days', (sub.days.toList()..sort()).map((i) => kDays[i]).join(', ')),
                      KeyValueRow('Next meal', sub.nextMeal),
                      KeyValueRow('Estimated total',
                          '${sub.days.length} × ${money(sub.pricePerMeal)} = ${money(sub.weeklyTotal)} / week',
                          bold: true),
                      const SizedBox(height: 8),
                      DayPills(sub.days),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final nav = Navigator.of(context);
                      ordersSubTab.value = 1;
                      customerTab.value = 2;
                      nav.popUntil((r) => r.isFirst);
                      nav.push(MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(sub: sub)));
                    },
                    child: const Text('View Subscription'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      customerTab.value = 0;
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    },
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class SubscriptionDetailScreen extends StatefulWidget {
  final Subscription sub;
  const SubscriptionDetailScreen({super.key, required this.sub});
  @override
  State<SubscriptionDetailScreen> createState() => _SubscriptionDetailScreenState();
}

class _SubscriptionDetailScreenState extends State<SubscriptionDetailScreen> {
  Future<void> _manage() async {
    final s = widget.sub;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SubscribeScreen(
          mealName: s.mealName,
          providerName: s.providerName,
          imageUrl: s.imageUrl,
          pricePerMeal: s.pricePerMeal,
          existing: s,
        ),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _cancel() async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel subscription?',
      message: 'You will stop receiving ${widget.sub.mealName} from ${widget.sub.providerName}. This cannot be undone in the prototype.',
      confirmText: 'Yes, cancel',
      cancelText: 'Keep it',
    );
    if (ok && mounted) {
      setState(() => widget.sub.status = 'Cancelled');
      toast(context, 'Subscription cancelled');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sub;
    final active = s.status == 'Active';
    return Scaffold(
      appBar: AppBar(title: const Text('Subscription details')),
      body: SingleChildScrollView(
        child: ResponsiveBody(
          maxWidth: 640,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FoodImage(url: s.imageUrl, label: s.mealName, height: 180, radius: 18),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: Text(s.mealName, style: hStyle(24))),
                  StatusChip(s.status),
                ],
              ),
              Text(s.providerName, style: bStyle(15, color: LZ.muted)),
              const SizedBox(height: 12),
              DayPills(s.days),
              const SizedBox(height: 12),
              LzCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    KeyValueRow('Subscription ID', s.id),
                    KeyValueRow('Selected days', s.daysText),
                    KeyValueRow('Next meal', active ? s.nextMeal : '—'),
                    KeyValueRow('Price per meal', money(s.pricePerMeal)),
                    KeyValueRow('Weekly total', '${s.days.length} × ${money(s.pricePerMeal)} = ${money(s.weeklyTotal)}', bold: true),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: active ? _manage : null,
                      icon: const Icon(Icons.edit_calendar_rounded),
                      label: const Text('Manage'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: LZ.terracotta),
                      onPressed: active ? _cancel : null,
                      icon: const Icon(Icons.cancel_outlined),
                      label: const Text('Cancel'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------- Orders tab ----------

class OrdersTab extends StatefulWidget {
  const OrdersTab({super.key});
  @override
  State<OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<OrdersTab> with SingleTickerProviderStateMixin {
  late final TabController _tc;

  @override
  void initState() {
    super.initState();
    _tc = TabController(length: 2, vsync: this, initialIndex: ordersSubTab.value);
    ordersSubTab.value = 0;
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  Future<void> _cancelSub(Subscription s) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel subscription?',
      message: 'You will stop receiving ${s.mealName} from ${s.providerName}.',
      confirmText: 'Yes, cancel',
      cancelText: 'Keep it',
    );
    if (ok && mounted) {
      setState(() => s.status = 'Cancelled');
      toast(context, 'Subscription cancelled');
    }
  }

  Widget _orderCard(OrderRec o) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: LzCard(
          child: Row(
            children: [
              FoodImage(url: o.imageUrl, label: o.mealName, height: 64, width: 64, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text('#${o.id}', style: bStyle(13, color: LZ.muted, weight: FontWeight.w700))),
                        StatusChip(o.status),
                      ],
                    ),
                    Text('${o.qty} × ${o.mealName}', style: bStyle(16, weight: FontWeight.w700)),
                    Text(o.providerName, style: bStyle(13, color: LZ.muted)),
                    const SizedBox(height: 2),
                    Text('${money(o.total)} • ${o.location}',
                        style: bStyle(13, color: LZ.maroon, weight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _subCard(Subscription s) {
    final active = s.status == 'Active';
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LzCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FoodImage(url: s.imageUrl, label: s.mealName, height: 56, width: 56, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.mealName, style: bStyle(16, weight: FontWeight.w700)),
                      Text(s.providerName, style: bStyle(13, color: LZ.muted)),
                    ],
                  ),
                ),
                StatusChip(s.status),
              ],
            ),
            const SizedBox(height: 10),
            DayPills(s.days),
            const SizedBox(height: 8),
            Text(active ? 'Next meal: ${s.nextMeal}' : 'Subscription ended',
                style: bStyle(13, color: LZ.green, weight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SubscriptionDetailScreen(sub: s)),
                    );
                    if (mounted) setState(() {});
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 18),
                  label: const Text('View'),
                ),
                TextButton.icon(
                  onPressed: active
                      ? () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => SubscribeScreen(
                                mealName: s.mealName,
                                providerName: s.providerName,
                                imageUrl: s.imageUrl,
                                pricePerMeal: s.pricePerMeal,
                                existing: s,
                              ),
                            ),
                          );
                          if (mounted) setState(() {});
                        }
                      : null,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 18),
                  label: const Text('Manage'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: LZ.terracotta),
                  onPressed: active ? () => _cancelSub(s) : null,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                  label: const Text('Cancel'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          HeaderBand(child: Text('My Orders', style: hStyle(26, color: Colors.white))),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tc,
              labelColor: LZ.maroon,
              unselectedLabelColor: LZ.muted,
              indicatorColor: LZ.turmeric,
              tabs: const [Tab(text: 'Orders'), Tab(text: 'Subscriptions')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                Store.customerOrders.isEmpty
                    ? const EmptyState(icon: Icons.receipt_long_outlined, message: 'No orders yet. Order a meal to see it here.')
                    : ResponsiveBody(
                        maxWidth: 800,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          children: [for (final o in Store.customerOrders) _orderCard(o)],
                        ),
                      ),
                Store.customerSubs.isEmpty
                    ? const EmptyState(icon: Icons.event_repeat_rounded, message: 'No subscriptions yet. Pick a meal and tap Subscribe.')
                    : ResponsiveBody(
                        maxWidth: 800,
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          children: [for (final s in Store.customerSubs) _subCard(s)],
                        ),
                      ),
              ],
            ),
          ),
        ],
      );
}

// ---------- Customer profile ----------

class ProfileTab extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;
  const ProfileTab({super.key, required this.session, required this.onLogout});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  bool _notify = true;

  Future<void> _logout() async {
    final ok = await confirmDialog(context,
        title: 'Log out?', message: 'You can log back in any time.', confirmText: 'Log out', cancelText: 'Stay');
    if (ok) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return SingleChildScrollView(
      child: Column(
        children: [
          HeaderBand(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: LZ.turmeric,
                  child: Text(s.name.isEmpty ? '?' : s.name[0].toUpperCase(), style: hStyle(26)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name, style: hStyle(22, color: Colors.white), overflow: TextOverflow.ellipsis),
                      Text(s.email, style: bStyle(13, color: tint(Colors.white, 0.8)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ResponsiveBody(
            maxWidth: 700,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle('Your details'),
                LzCard(
                  child: Column(
                    children: [
                      KeyValueRow('Name', s.name),
                      KeyValueRow('Email', s.email),
                      KeyValueRow('Phone', s.phone.isEmpty ? 'Not added' : s.phone),
                      KeyValueRow('Delivery', Store.deliveryLocation),
                      KeyValueRow('Account type', s.type.label),
                      if (s.isDemo) KeyValueRow('Mode', 'Demo preview (not signed in)'),
                    ],
                  ),
                ),
                const SectionTitle('Settings'),
                LzCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.location_on_outlined, color: LZ.maroon),
                        title: const Text('Edit delivery location'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          await editLocationDialog(context);
                          if (mounted) setState(() {});
                        },
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        secondary: const Icon(Icons.notifications_outlined, color: LZ.maroon),
                        title: const Text('Order updates'),
                        subtitle: const Text('Prototype setting only'),
                        value: _notify,
                        activeColor: LZ.green,
                        onChanged: (v) => setState(() => _notify = v),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.info_outline_rounded, color: LZ.maroon),
                        title: const Text('About LOCALZ'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => showAboutDialog(
                          context: context,
                          applicationName: 'LOCALZ',
                          applicationVersion: 'Prototype 0.1',
                          children: const [
                            Text('Local food. Flexible meals.\n\nA college MVP: flexible meal subscriptions from local food businesses, with meals only on the days customers need them. Sample businesses and images are for demo only.'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout_rounded),
                    label: const Text('Logout'),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 12. BUSINESS-OWNER SIDE
// ============================================================================

class BusinessShell extends StatelessWidget {
  final UserSession session;
  final VoidCallback onLogout;
  const BusinessShell({super.key, required this.session, required this.onLogout});

  @override
  Widget build(BuildContext context) => ShellScaffold(
        tab: businessTab,
        icons: const [Icons.dashboard_rounded, Icons.restaurant_menu_rounded, Icons.receipt_long_rounded, Icons.storefront_rounded],
        labels: const ['Dashboard', 'Meals', 'Orders', 'Profile'],
        pageBuilder: (i) {
          switch (i) {
            case 0:
              return BizDashboardTab(session: session);
            case 1:
              return const BizMealsTab();
            case 2:
              return const BizOrdersTab();
            default:
              return BizProfileTab(session: session, onLogout: onLogout);
          }
        },
      );
}

const _orderFlow = ['New', 'Preparing', 'Out for delivery', 'Delivered'];

class OwnerOrderCard extends StatelessWidget {
  final OrderRec order;
  final VoidCallback onChanged;
  const OwnerOrderCard({super.key, required this.order, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final idx = _orderFlow.indexOf(order.status);
    final next = (idx >= 0 && idx < _orderFlow.length - 1) ? _orderFlow[idx + 1] : null;
    return LzCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text('Order #${order.id}', style: bStyle(13, color: LZ.muted, weight: FontWeight.w700))),
              StatusChip(order.status),
            ],
          ),
          const SizedBox(height: 4),
          Text(order.mealName, style: bStyle(17, weight: FontWeight.w700)),
          Text('${order.qty} × ${money(order.unitPrice)} = ${money(order.total)}',
              style: bStyle(14, color: LZ.maroon, weight: FontWeight.w600)),
          Text('Customer: ${order.customerName} • ${order.location}', style: bStyle(13, color: LZ.muted)),
          if (next != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                onPressed: () {
                  order.status = next;
                  onChanged();
                },
                child: Text('Mark as $next'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class OwnerSubCard extends StatelessWidget {
  final Subscription sub;
  const OwnerSubCard({super.key, required this.sub});
  @override
  Widget build(BuildContext context) => LzCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(color: tint(LZ.green, 0.14), shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(sub.customerName[0].toUpperCase(), style: hStyle(18, color: LZ.green)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sub.customerName, style: bStyle(16, weight: FontWeight.w700)),
                  Text(sub.mealName, style: bStyle(13, color: LZ.muted)),
                  const SizedBox(height: 6),
                  DayPills(sub.days),
                  const SizedBox(height: 6),
                  Text('Next delivery: ${sub.nextMeal}', style: bStyle(13, color: LZ.green, weight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      );
}

class OwnerMealTile extends StatelessWidget {
  final Meal meal;
  final VoidCallback onChanged;
  const OwnerMealTile({super.key, required this.meal, required this.onChanged});

  @override
  Widget build(BuildContext context) => LzCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                FoodImage(url: meal.imageUrl, label: meal.name, height: 68, width: 68, radius: 12),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(meal.name, style: bStyle(16, weight: FontWeight.w700), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(money(meal.price), style: hStyle(17)),
                          const SizedBox(width: 8),
                          Flexible(child: SmallTag(meal.category, color: LZ.terracotta)),
                        ],
                      ),
                    ],
                  ),
                ),
                Column(
                  children: [
                    Switch(
                      value: meal.available,
                      activeColor: LZ.green,
                      onChanged: (v) {
                        meal.available = v;
                        onChanged();
                      },
                    ),
                    Text(meal.available ? 'Available' : 'Off', style: bStyle(11, color: LZ.muted)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => MealFormScreen(existing: meal)),
                    );
                    onChanged();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit'),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: LZ.terracotta),
                  onPressed: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Remove meal?',
                      message: '"${meal.name}" will be removed from your menu.',
                      confirmText: 'Remove',
                      cancelText: 'Keep',
                    );
                    if (ok) {
                      Store.ownerMeals.remove(meal);
                      onChanged();
                    }
                  },
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  label: const Text('Remove'),
                ),
              ],
            ),
          ],
        ),
      );
}

Future<void> openAddMeal(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const MealFormScreen()));

// ---------- Dashboard ----------

class BizDashboardTab extends StatefulWidget {
  final UserSession session;
  const BizDashboardTab({super.key, required this.session});
  @override
  State<BizDashboardTab> createState() => _BizDashboardTabState();
}

class _BizDashboardTabState extends State<BizDashboardTab> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  Widget _stat(IconData icon, String label, String value, Color color) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: tint(Colors.white, 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: tint(LZ.turmeric, 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: LZ.turmeric, size: 22),
              const SizedBox(height: 6),
              Text(value, style: hStyle(24, color: Colors.white)),
              Text(label, style: bStyle(12, color: tint(Colors.white, 0.85))),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final b = Store.ownerBusiness;
    final activeMeals = Store.ownerMeals.where((m) => m.available).length;
    final activeSubs = Store.ownerSubs.where((s) => s.status == 'Active').toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          HeaderBand(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Business Dashboard', style: hStyle(26, color: Colors.white)),
                const SizedBox(height: 4),
                Text(b.name, style: bStyle(16, color: LZ.turmeric, weight: FontWeight.w700)),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _stat(Icons.receipt_long_rounded, "Today's orders", '${Store.ownerOrders.length}', LZ.turmeric),
                    const SizedBox(width: 10),
                    _stat(Icons.event_repeat_rounded, 'Subscriptions', '${activeSubs.length}', LZ.turmeric),
                    const SizedBox(width: 10),
                    _stat(Icons.restaurant_menu_rounded, 'Active meals', '$activeMeals', LZ.turmeric),
                  ],
                ),
              ],
            ),
          ),
          ResponsiveBody(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionTitle("Today's Orders"),
                if (Store.ownerOrders.isEmpty)
                  const EmptyState(icon: Icons.inbox_outlined, message: 'No orders yet today.')
                else
                  AdaptiveWrap(
                    minTileWidth: 360,
                    children: [for (final o in Store.ownerOrders) OwnerOrderCard(order: o, onChanged: _refresh)],
                  ),
                const SectionTitle('Upcoming Subscriptions'),
                if (activeSubs.isEmpty)
                  const EmptyState(icon: Icons.event_busy_outlined, message: 'No active subscriptions yet.')
                else
                  AdaptiveWrap(
                    minTileWidth: 360,
                    children: [for (final s in activeSubs) OwnerSubCard(sub: s)],
                  ),
                SectionTitle(
                  'Meals',
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      TextButton(onPressed: () => businessTab.value = 1, child: const Text('See all')),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
                        onPressed: () async {
                          await openAddMeal(context);
                          _refresh();
                        },
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Meal'),
                      ),
                    ],
                  ),
                ),
                if (Store.ownerMeals.isEmpty)
                  const EmptyState(icon: Icons.restaurant_menu_outlined, message: 'No meals yet. Tap Add Meal to create one.')
                else
                  AdaptiveWrap(
                    minTileWidth: 360,
                    children: [for (final m in Store.ownerMeals.take(3)) OwnerMealTile(meal: m, onChanged: _refresh)],
                  ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------- Meals tab ----------

class BizMealsTab extends StatefulWidget {
  const BizMealsTab({super.key});
  @override
  State<BizMealsTab> createState() => _BizMealsTabState();
}

class _BizMealsTabState extends State<BizMealsTab> {
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          HeaderBand(
            child: Row(
              children: [
                Expanded(child: Text('Your Meals', style: hStyle(26, color: Colors.white))),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: LZ.turmeric,
                    foregroundColor: LZ.maroon,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onPressed: () async {
                    await openAddMeal(context);
                    _refresh();
                  },
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Meal'),
                ),
              ],
            ),
          ),
          Expanded(
            child: Store.ownerMeals.isEmpty
                ? const EmptyState(icon: Icons.restaurant_menu_outlined, message: 'No meals yet. Tap Add Meal to create your first one.')
                : SingleChildScrollView(
                    child: ResponsiveBody(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: AdaptiveWrap(
                          minTileWidth: 380,
                          children: [for (final m in Store.ownerMeals) OwnerMealTile(meal: m, onChanged: _refresh)],
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      );
}

// ---------- Add / Edit meal ----------

class MealFormScreen extends StatefulWidget {
  final Meal? existing;
  const MealFormScreen({super.key, this.existing});
  @override
  State<MealFormScreen> createState() => _MealFormScreenState();
}

class _MealFormScreenState extends State<MealFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: widget.existing?.name ?? '');
  late final TextEditingController _desc = TextEditingController(text: widget.existing?.description ?? '');
  late final TextEditingController _price =
      TextEditingController(text: widget.existing == null ? '' : '${widget.existing!.price}');
  late final TextEditingController _img = TextEditingController(text: widget.existing?.imageUrl ?? '');
  late String _category = widget.existing?.category ?? kCategories.first;
  late bool _available = widget.existing?.available ?? true;
  String _previewUrl = '';

  bool get _edit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _previewUrl = _img.text.trim();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _price.dispose();
    _img.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final url = _img.text.trim().isEmpty ? Img.meals : _img.text.trim();
    final price = int.parse(_price.text.trim());
    if (_edit) {
      final m = widget.existing!;
      m.name = _name.text.trim();
      m.description = _desc.text.trim();
      m.price = price;
      m.category = _category;
      m.imageUrl = url;
      m.available = _available;
    } else {
      Store.ownerMeals.insert(
        0,
        Meal(
          id: Store.nextMealId(),
          providerId: 'owner',
          name: _name.text.trim(),
          description: _desc.text.trim(),
          price: price,
          category: _category,
          imageUrl: url,
          available: _available,
        ),
      );
    }
    toast(context, _edit ? 'Meal updated' : 'Meal added to your menu');
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(_edit ? 'Edit Meal' : 'Add Meal')),
        body: SingleChildScrollView(
          child: ResponsiveBody(
            maxWidth: 560,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  lzField(
                    controller: _name,
                    label: 'Meal name',
                    icon: Icons.restaurant_rounded,
                    validator: (v) => requiredValidator(v, 'Meal name'),
                  ),
                  lzField(
                    controller: _desc,
                    label: 'Description',
                    icon: Icons.notes_rounded,
                    maxLines: 3,
                    validator: (v) => requiredValidator(v, 'Description'),
                  ),
                  lzField(
                    controller: _price,
                    label: 'Price (₹)',
                    icon: Icons.currency_rupee_rounded,
                    keyboard: TextInputType.number,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Price is required';
                      final n = int.tryParse(v.trim());
                      if (n == null || n <= 0) return 'Enter a whole number above 0';
                      return null;
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: const InputDecoration(
                          labelText: 'Category', prefixIcon: Icon(Icons.category_outlined, color: LZ.gold)),
                      items: [for (final c in kCategories) DropdownMenuItem(value: c, child: Text(c))],
                      onChanged: (v) => setState(() => _category = v ?? _category),
                    ),
                  ),
                  lzField(
                    controller: _img,
                    label: 'Image URL (optional)',
                    icon: Icons.image_outlined,
                    keyboard: TextInputType.url,
                  ),
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: () => setState(() => _previewUrl = _img.text.trim()),
                        icon: const Icon(Icons.visibility_outlined, size: 18),
                        label: const Text('Preview image'),
                      ),
                    ],
                  ),
                  if (_previewUrl.isNotEmpty) ...[
                    FoodImage(url: _previewUrl, label: 'Preview', height: 160, radius: 14),
                    const SizedBox(height: 12),
                  ],
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Available for customers'),
                    subtitle: const Text('Turn off if sold out'),
                    value: _available,
                    activeColor: LZ.green,
                    onChanged: (v) => setState(() => _available = v),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(onPressed: _save, child: Text(_edit ? 'Save Changes' : 'Add Meal')),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ---------- Business orders tab ----------

class BizOrdersTab extends StatefulWidget {
  const BizOrdersTab({super.key});
  @override
  State<BizOrdersTab> createState() => _BizOrdersTabState();
}

class _BizOrdersTabState extends State<BizOrdersTab> with SingleTickerProviderStateMixin {
  late final TabController _tc = TabController(length: 2, vsync: this);

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          HeaderBand(child: Text('Orders & Subscriptions', style: hStyle(24, color: Colors.white))),
          Material(
            color: Colors.white,
            child: TabBar(
              controller: _tc,
              labelColor: LZ.maroon,
              unselectedLabelColor: LZ.muted,
              indicatorColor: LZ.turmeric,
              tabs: const [Tab(text: 'Orders'), Tab(text: 'Subscriptions')],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tc,
              children: [
                Store.ownerOrders.isEmpty
                    ? const EmptyState(icon: Icons.inbox_outlined, message: 'No orders yet.')
                    : ResponsiveBody(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          children: [
                            for (final o in Store.ownerOrders)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: OwnerOrderCard(order: o, onChanged: _refresh),
                              ),
                          ],
                        ),
                      ),
                Store.ownerSubs.isEmpty
                    ? const EmptyState(icon: Icons.event_busy_outlined, message: 'No subscriptions yet.')
                    : ResponsiveBody(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          children: [
                            for (final s in Store.ownerSubs)
                              Padding(padding: const EdgeInsets.only(bottom: 12), child: OwnerSubCard(sub: s)),
                          ],
                        ),
                      ),
              ],
            ),
          ),
        ],
      );
}

// ---------- Business profile ----------

class BizProfileTab extends StatefulWidget {
  final UserSession session;
  final VoidCallback onLogout;
  const BizProfileTab({super.key, required this.session, required this.onLogout});
  @override
  State<BizProfileTab> createState() => _BizProfileTabState();
}

class _BizProfileTabState extends State<BizProfileTab> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(text: Store.ownerBusiness.name);
  late final TextEditingController _desc = TextEditingController(text: Store.ownerBusiness.description);
  late final TextEditingController _loc = TextEditingController(text: Store.ownerBusiness.location);
  late final TextEditingController _phone = TextEditingController(text: Store.ownerBusiness.phone);
  late double _range = Store.ownerBusiness.rangeKm.clamp(0.5, 15.0).toDouble();

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _loc.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final b = Store.ownerBusiness;
    b.name = _name.text.trim();
    b.description = _desc.text.trim();
    b.location = _loc.text.trim();
    b.phone = _phone.text.trim();
    b.rangeKm = _range;
    toast(context, 'Business profile saved');
    setState(() {});
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context,
        title: 'Log out?', message: 'You can log back in any time.', confirmText: 'Log out', cancelText: 'Stay');
    if (ok) widget.onLogout();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    return SingleChildScrollView(
      child: Column(
        children: [
          HeaderBand(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: LZ.turmeric,
                  child: const Icon(Icons.storefront_rounded, color: LZ.maroon, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(Store.ownerBusiness.name, style: hStyle(22, color: Colors.white), overflow: TextOverflow.ellipsis),
                      Text('${s.name} • ${s.email}', style: bStyle(13, color: tint(Colors.white, 0.8)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ResponsiveBody(
            maxWidth: 600,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Business profile', style: hStyle(20)),
                  Text('Account type: ${s.type.label}${s.isDemo ? ' (demo preview)' : ''}',
                      style: bStyle(13, color: LZ.muted)),
                  const SizedBox(height: 14),
                  lzField(controller: _name, label: 'Business name', icon: Icons.storefront_outlined, validator: (v) => requiredValidator(v, 'Business name')),
                  lzField(controller: _desc, label: 'Description', icon: Icons.notes_rounded, maxLines: 3, validator: (v) => requiredValidator(v, 'Description')),
                  lzField(controller: _loc, label: 'Location', icon: Icons.location_on_outlined, validator: (v) => requiredValidator(v, 'Location')),
                  lzField(controller: _phone, label: 'Phone', icon: Icons.phone_outlined, keyboard: TextInputType.phone, validator: phoneValidator),
                  LzCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.delivery_dining_rounded, color: LZ.green),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Service / delivery range', style: bStyle(15, weight: FontWeight.w700))),
                            Text('${_range.toStringAsFixed(1)} km', style: hStyle(18)),
                          ],
                        ),
                        Slider(
                          value: _range,
                          min: 0.5,
                          max: 15,
                          divisions: 29,
                          activeColor: LZ.green,
                          label: '${_range.toStringAsFixed(1)} km',
                          onChanged: (v) => setState(() => _range = v),
                        ),
                        Text('You decide how far you serve. Customers see this on your kitchen page.',
                            style: bStyle(12, color: LZ.muted)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  SizedBox(width: double.infinity, child: FilledButton(onPressed: _save, child: const Text('Save Changes'))),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Logout'),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}