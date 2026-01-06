import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/auth/presentation/splash_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/otp_screen.dart';
import '../../features/auth/presentation/pin_screen.dart';
import '../../features/customer/presentation/customer_home_screen.dart';
import '../../features/customer/presentation/customer_profile_screen.dart';
import '../../features/customer/presentation/customer_transactions_screen.dart';
import '../../features/manager/presentation/manager_profile_screen.dart';
import '../../features/manager/presentation/manager_home_screen.dart';
import '../../features/manager/presentation/add_fuel_screen.dart';
import '../../features/manager/presentation/todays_log_screen.dart';
import '../../features/admin/presentation/admin_home_screen.dart';
import '../../features/admin/presentation/users/user_list_screen.dart';
import '../../features/admin/presentation/users/user_detail_screen.dart';
import '../../features/admin/presentation/bunks/bunk_list_screen.dart';
import '../../features/admin/presentation/bunks/bunk_detail_screen.dart';
import '../../features/admin/presentation/config/global_config_screen.dart';
import '../../features/admin/presentation/analytics/analytics_dashboard_screen.dart';
import '../../features/admin/presentation/analytics/analytics_bunk_list_screen.dart';
import '../../features/admin/presentation/analytics/transaction_list_screen.dart';
import '../../features/admin/presentation/analytics/audit_log_screen.dart';
import '../../features/admin/presentation/profile/admin_profile_screen.dart';
import '../../features/auth/data/auth_provider.dart';
import '../../features/auth/data/user_provider.dart';

/// RouterNotifier listens to auth and profile changes and notifies the router to refresh.
class RouterNotifier extends ChangeNotifier {
  final Ref ref;

  RouterNotifier(this.ref) {
    ref.listen(authStateProvider, (_, __) => notifyListeners());
    ref.listen(userProfileProvider, (_, __) => notifyListeners());
    ref.listen(pinSessionProvider, (_, __) => notifyListeners());
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    initialLocation: '/',
    refreshListenable:
        notifier, // Re-evaluates redirect logic when notifier updates
    debugLogDiagnostics:
        kDebugMode, // Enable internal GoRouter logs in debug mode
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (context, state) => const OtpScreen()),
      GoRoute(
        path: '/set-pin',
        builder: (context, state) => const PinScreen(mode: PinMode.set),
      ),
      GoRoute(
        path: '/verify-pin',
        builder: (context, state) => const PinScreen(mode: PinMode.verify),
      ),
      GoRoute(
        path: '/reset-pin',
        builder: (context, state) => const PinScreen(mode: PinMode.set),
      ),
      GoRoute(
        path: '/customer-home',
        builder: (context, state) => const CustomerHomeScreen(),
      ),
      GoRoute(
        path: '/customer/profile',
        builder: (context, state) => const CustomerProfileScreen(),
      ),
      GoRoute(
        path: '/customer/transactions',
        builder: (context, state) => const CustomerTransactionsScreen(),
      ),
      GoRoute(
        path: '/manager-home',
        builder: (context, state) => const ManagerHomeScreen(),
      ),
      GoRoute(
        path: '/manager/profile',
        builder: (context, state) => const ManagerProfileScreen(),
      ),
      GoRoute(
        path: '/manager/add-fuel',
        builder: (context, state) => const AddFuelScreen(),
      ),
      GoRoute(
        path: '/manager/todays-logs',
        builder: (context, state) => const TodaysLogScreen(),
      ),
      GoRoute(
        path: '/admin-home',
        builder: (context, state) => const AdminHomeScreen(),
      ),
      // Admin Modules
      GoRoute(
        path: '/admin/users',
        builder: (context, state) => const UserListScreen(),
        routes: [
          GoRoute(
            path: ':uid', // /admin/users/:uid
            builder: (context, state) {
              final uid = state.pathParameters['uid']!;
              return UserDetailScreen(uid: uid);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin/bunks',
        builder: (context, state) => const BunkListScreen(),
        routes: [
          GoRoute(
            path: ':bunkId', // /admin/bunks/:bunkId
            builder: (context, state) {
              final bunkId = state.pathParameters['bunkId']!;
              return BunkDetailScreen(bunkId: bunkId);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin/config',
        builder: (context, state) => const GlobalConfigScreen(),
      ),
      GoRoute(
        path: '/admin/analytics',
        builder: (context, state) => const AnalyticsBunkListScreen(),
        routes: [
          GoRoute(
            path: 'dashboard', // /admin/analytics/dashboard
            name: 'analytics_dashboard',
            builder: (context, state) {
              final q = state.uri.queryParameters;
              return AnalyticsDashboardScreen(
                bunkId: q['bunkId'],
                initialPeriod: q['period'],
                initialStartDate: q['startDate'],
                initialEndDate: q['endDate'],
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/admin/transactions',
        builder: (context, state) => const TransactionListScreen(),
      ),
      GoRoute(
        path: '/admin/profile',
        builder: (context, state) => const AdminProfileScreen(),
      ),
      GoRoute(
        path: '/admin/audit-logs',
        builder: (context, state) => const AuditLogScreen(),
      ),
    ],
    redirect: (context, state) {
      // Use ref.read to get current values without creating a dependency loop inside the builder/provider
      final authState = ref.read(authStateProvider);
      final userProfile = ref.read(userProfileProvider);
      final pinSession = ref.read(pinSessionProvider);

      final isAuthenticated = authState.value != null;
      final isLoggingIn =
          state.uri.toString() == '/login' ||
          state.uri.toString().startsWith('/login?') || // Handle query params
          state.uri.toString() == '/otp' ||
          state.uri.toString().startsWith('/otp?');

      if (kDebugMode) {
        print(
          'Router Redirect Check: Path=${state.uri}, Auth=$isAuthenticated',
        );
      }

      // 0. Loading states
      if (authState.isLoading || userProfile.isLoading) {
        if (kDebugMode) print('Router: Auth/Profile Loading...');
        return null;
      }

      // 1. Not Authenticated -> Login
      if (!isAuthenticated) {
        if (kDebugMode && !isLoggingIn)
          print('Router: Not authenticated, Redirect to Login');
        return isLoggingIn ? null : '/login';
      }

      // 2. Authenticated but Profile not loaded / Null
      if (!userProfile.hasValue) {
        // Still loading or no emission yet
        return null;
      }

      if (userProfile.value == null) {
        // Auth exists but Firestore Doc does NOT exist.
        // This implies incomplete registration or new user.
        if (state.uri.toString() == '/set-pin') return null;
        if (kDebugMode)
          print(
            'Router: Profile document missing for ${authState.value?.uid}, redirecting to /set-pin',
          );
        return '/set-pin';
      }

      final userData = userProfile.value!;
      if (kDebugMode)
        print(
          'Router: Profile loaded: ${userData['role']}, isPinSet: ${userData['isPinSet']}',
        );

      final isPinSet = userData['isPinSet'] == true;

      // 3. Authenticated but PIN not set -> Set PIN
      // Exception: If we are intentionally going to /reset-pin (which is basically set pin mode), allow it
      // But /reset-pin uses PinMode.set, so it's fine.
      if (!isPinSet) {
        if (state.uri.toString() == '/set-pin') return null;
        if (kDebugMode) print('Router: PIN not set, redirecting to /set-pin');
        return '/set-pin';
      }

      // 4. PIN set but not verified in session -> Verify PIN
      if (!pinSession) {
        if (state.uri.toString() == '/verify-pin') return null;
        if (kDebugMode)
          print('Router: PIN session invalid, redirecting to /verify-pin');
        return '/verify-pin';
      }

      // 5. Verified -> Check for Explicit Redirect (e.g. Reset PIN flow)
      final explicitRedirect = state.uri.queryParameters['redirect'];
      if (explicitRedirect != null && explicitRedirect.isNotEmpty) {
        if (kDebugMode) print('Router: Explicit redirect to $explicitRedirect');
        // If we are already there, return null to allow render
        if (state.uri.toString().startsWith(explicitRedirect)) return null;
        return explicitRedirect;
      }

      // 6. Verified -> Role Home
      final role = userData['role'];
      String target = '/customer-home';
      if (role == 'manager') target = '/manager-home';
      if (role == 'admin') target = '/admin-home';

      // Avoid redirect loops if we are already at the target or a sub-route
      if (state.uri.toString() == '/' ||
          state.uri.toString().startsWith('/login') ||
          state.uri.toString().startsWith('/otp') ||
          state.uri.toString() == '/set-pin' ||
          state.uri.toString() == '/verify-pin') {
        if (kDebugMode) print('Router: Redirecting to Role Home $target');
        return target;
      }

      // Allow /reset-pin if we navigated there manually (e.g. from Profile)
      if (state.uri.toString() == '/reset-pin') return null;

      return null; // Allow other processing
    },
  );
});
