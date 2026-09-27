import 'package:flutter/foundation.dart';

/// ViewModel for the Login / Register screen (mockup 1).
///
/// Milestone 1 does not call a real server yet: it only validates input format and
/// simulates network latency so the navigation flow works end to end.
class AuthViewModel extends ChangeNotifier {
  bool _isBusy = false;
  bool _isSignedIn = false;
  String? _error;
  String _email = '';

  bool get isBusy => _isBusy;
  bool get isSignedIn => _isSignedIn;
  String? get error => _error;
  String get email => _email;

  Future<bool> signIn(String email, String password) async {
    _error = null;
    if (!email.contains('@') || email.trim().isEmpty) {
      _error = 'Please enter a valid email address.';
      notifyListeners();
      return false;
    }
    if (password.length < 6) {
      _error = 'Password must be at least 6 characters.';
      notifyListeners();
      return false;
    }

    _isBusy = true;
    notifyListeners();

    await Future<void>.delayed(const Duration(milliseconds: 700));

    _email = email.trim();
    _isSignedIn = true;
    _isBusy = false;
    notifyListeners();
    return true;
  }

  Future<bool> register(String email, String password) => signIn(email, password);

  void signOut() {
    _isSignedIn = false;
    _email = '';
    notifyListeners();
  }
}
