import 'dart:convert';

import 'package:amplify_api/amplify_api.dart';
import 'package:amplify_auth_cognito/amplify_auth_cognito.dart';
import 'package:amplify_flutter/amplify_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:table_calendar/table_calendar.dart';

import 'amplifyconfiguration.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    MobileAds.instance.initialize();
  }
  runApp(const ProgressTrackerApp());
}

class ProgressTrackerApp extends StatefulWidget {
  const ProgressTrackerApp({super.key});

  @override
  State<ProgressTrackerApp> createState() => _ProgressTrackerAppState();
}

class _ProgressTrackerAppState extends State<ProgressTrackerApp> {
  final AmplifyClient _amplify = AmplifyClient();
  late final ProgressRepository _repository;
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  final GlobalKey<ScaffoldMessengerState> _messengerKey =
      GlobalKey<ScaffoldMessengerState>();
  ThemeMode _themeMode = ThemeMode.light;
  String? _userId;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _repository = ProgressRepository(
      localStore: LocalCacheStore(),
      remoteStore: AmplifyRemoteStore(_amplify),
    );
    _initialize();
  }

  Future<void> _initialize() async {
    await _amplify.configure();
    final userId = await _amplify.currentUserId();
    setState(() {
      _userId = userId;
      _ready = true;
    });
  }

  Future<void> _signIn() async {
    if (!_amplify.isConfigured) {
      _showMessage('Amplify not configured yet.');
      return;
    }
    final result = await _showAuthSheet();
    if (result == null) {
      return;
    }
    if (result.mode == _AuthMode.signUp) {
    final signUpResult = await _amplify.signUp(
      username: result.username,
      password: result.password,
      email: result.email,
    );
    if (signUpResult.error != null) {
      _showMessage(signUpResult.error!);
      return;
    }
    final signUpComplete = signUpResult.success;
    if (!signUpComplete) {
      _showMessage('Sign up failed.');
      return;
    }
      while (true) {
        final code = await _promptForCode();
        if (code == null) {
          _showMessage('Confirmation cancelled.');
          return;
        }
        if (code.isEmpty) {
          _showMessage('Confirmation code required.');
          continue;
        }
        final confirmResult = await _amplify.confirmSignUp(
          username: result.username,
          confirmationCode: code,
        );
        if (confirmResult.error != null) {
          _showMessage(confirmResult.error!);
          continue;
        }
        if (confirmResult.success) {
          break;
        }
        _showMessage('Confirmation failed. Check the code and try again.');
      }
    }
    final signInResult = await _amplify.signInWithPassword(
      username: result.username,
      password: result.password,
    );
    if (signInResult.error != null) {
      _showMessage(signInResult.error!);
      return;
    }
    final userId = signInResult.userId;
    if (userId == null) {
      _showMessage('Sign in failed. Check credentials.');
      return;
    }
    setState(() => _userId = userId);
  }

  Future<void> _signOut() async {
    await _amplify.signOut();
    setState(() {
      _userId = null;
    });
  }

  void _toggleTheme() {
    setState(() {
      _themeMode =
          _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    });
  }

  void _showMessage(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<_AuthFormResult?> _showAuthSheet() {
    final context = _navKey.currentContext;
    if (context == null) {
      return Future.value(null);
    }
    final formKey = GlobalKey<FormState>();
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    var mode = _AuthMode.signIn;
    return showModalBottomSheet<_AuthFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      height: 4,
                      width: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SegmentedButton<_AuthMode>(
                      segments: const [
                        ButtonSegment(
                          value: _AuthMode.signIn,
                          label: Text('Sign in'),
                        ),
                        ButtonSegment(
                          value: _AuthMode.signUp,
                          label: Text('Create account'),
                        ),
                      ],
                      selected: {mode},
                      onSelectionChanged: (value) {
                        setModalState(() => mode = value.first);
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                      ),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'Email is required.';
                        }
                        if (!v.contains('@')) {
                          return 'Enter a valid email.';
                        }
                        return null;
                      },
                    ),
                    TextFormField(
                      controller: passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                      textInputAction: TextInputAction.done,
                      validator: (value) {
                        final v = value?.trim() ?? '';
                        if (v.isEmpty) {
                          return 'Password is required.';
                        }
                        if (v.length < 8) {
                          return 'Password must be at least 8 characters.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () {
                            final valid = formKey.currentState?.validate() ??
                                false;
                            if (!valid) {
                              return;
                            }
                            Navigator.of(context).pop(_AuthFormResult(
                              mode: mode,
                              username: usernameController.text.trim(),
                              password: passwordController.text.trim(),
                              email: usernameController.text.trim(),
                            ));
                          },
                          child: Text(mode == _AuthMode.signUp
                              ? 'Create'
                              : 'Sign in'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<String?> _promptForCode() {
    final context = _navKey.currentContext;
    if (context == null) {
      return Future.value(null);
    }
    final codeController = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm account'),
          content: TextField(
            controller: codeController,
            decoration: const InputDecoration(
              labelText: 'Confirmation code',
            ),
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(codeController.text.trim()),
              child: const Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final lightBase = ThemeData(
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF1F3A5F),
        secondary: Color(0xFFE56B6F),
        surface: Color(0xFFF6F1EC),
        background: Color(0xFFF0E9E1),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF1C1B1F),
        onBackground: Color(0xFF1C1B1F),
        outline: Color(0xFFDED6CC),
      ),
      useMaterial3: true,
    );

    final darkBase = ThemeData(
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF9CC4FF),
        secondary: Color(0xFFF2A9AC),
        surface: Color(0xFF1E1B17),
        background: Color(0xFF151310),
        onPrimary: Color(0xFF0C1C2E),
        onSecondary: Color(0xFF2D1517),
        onSurface: Color(0xFFF3EEE8),
        onBackground: Color(0xFFF3EEE8),
        outline: Color(0xFF3B332C),
      ),
      useMaterial3: true,
    );

    return MaterialApp(
      title: 'Streak Sheet',
      themeMode: _themeMode,
      navigatorKey: _navKey,
      scaffoldMessengerKey: _messengerKey,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
      ],
      theme: lightBase.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(lightBase.textTheme),
        scaffoldBackgroundColor: const Color(0xFFF0E9E1),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFF0E9E1),
          surfaceTintColor: Color(0xFFF0E9E1),
          elevation: 0,
        ),
      ),
      darkTheme: darkBase.copyWith(
        textTheme: GoogleFonts.spaceGroteskTextTheme(darkBase.textTheme),
        scaffoldBackgroundColor: const Color(0xFF151310),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF151310),
          surfaceTintColor: Color(0xFF151310),
          elevation: 0,
        ),
      ),
      home: _ready
          ? ProgressWindowsScreen(
              repository: _repository,
              isDark: _themeMode == ThemeMode.dark,
              onToggleTheme: _toggleTheme,
              onSignIn: _signIn,
              onSignOut: _signOut,
              userId: _userId,
              amplifyConfigured: _amplify.isConfigured,
            )
          : const _StartupScreen(),
    );
  }
}

class _StartupScreen extends StatelessWidget {
  const _StartupScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}

enum _AuthMode { signIn, signUp }

class _AuthFormResult {
  _AuthFormResult({
    required this.mode,
    required this.username,
    required this.password,
    required this.email,
  });

  final _AuthMode mode;
  final String username;
  final String password;
  final String email;
}

class _AuthResult {
  const _AuthResult({required this.success, this.userId, this.error});

  final bool success;
  final String? userId;
  final String? error;

  factory _AuthResult.success([String? userId]) =>
      _AuthResult(success: true, userId: userId);

  factory _AuthResult.error(String message) =>
      _AuthResult(success: false, error: message);
}

// SECTION: Models, storage, and Amplify clients.
class ProgressWindow {
  ProgressWindow({
    required this.id,
    required this.name,
    required this.notes,
    required this.tags,
    required this.goalCategory,
    required this.weeklyTarget,
    Map<DateTime, bool>? entries,
  }) : entries = entries ?? <DateTime, bool>{};

  final String id;
  String name;
  String notes;
  List<String> tags;
  String goalCategory;
  int weeklyTarget;
  final Map<DateTime, bool> entries;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      'tags': tags,
      'goalCategory': goalCategory,
      'weeklyTarget': weeklyTarget,
      'entries': entries.map((key, value) => MapEntry(_dateKey(key), value)),
    };
  }

  Map<String, dynamic> toRemoteJson(String ownerId) {
    return {
      'id': id,
      'owner': ownerId,
      'name': name,
      'notes': notes,
      'tags': tags,
      'goalCategory': goalCategory,
      'weeklyTarget': weeklyTarget,
      'entries': jsonEncode(
        entries.map((key, value) => MapEntry(_dateKey(key), value)),
      ),
    };
  }

  static ProgressWindow fromJson(Map<String, dynamic> json) {
    final entryMap = (json['entries'] as Map?)?.cast<String, dynamic>() ?? {};
    return ProgressWindow(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Untitled',
      notes: (json['notes'] as String?) ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? <String>[],
      goalCategory: (json['goalCategory'] as String?) ?? 'Personal',
      weeklyTarget: (json['weeklyTarget'] as int?) ?? 5,
      entries: entryMap.map((key, value) {
        return MapEntry(_parseDateKey(key), value == true);
      }),
    );
  }

  static ProgressWindow fromRemote(Map<String, dynamic> json) {
    Map<String, dynamic> entryMap = {};
    final rawEntries = json['entries'];
    if (rawEntries is String && rawEntries.isNotEmpty) {
      final decoded = jsonDecode(rawEntries);
      if (decoded is Map<String, dynamic>) {
        entryMap = decoded;
      }
    }
    return ProgressWindow(
      id: json['id'] as String,
      name: (json['name'] as String?) ?? 'Untitled',
      notes: (json['notes'] as String?) ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? <String>[],
      goalCategory: (json['goalCategory'] as String?) ?? 'Personal',
      weeklyTarget: (json['weeklyTarget'] as int?) ?? 5,
      entries: entryMap.map((key, value) {
        return MapEntry(_parseDateKey(key), value == true);
      }),
    );
  }
}

class ProgressRepository {
  ProgressRepository({required this.localStore, required this.remoteStore});

  final LocalCacheStore localStore;
  final AmplifyRemoteStore remoteStore;

  Future<List<ProgressWindow>> load({String? userId}) async {
    final local = await localStore.load();
    if (userId == null || !remoteStore.isEnabled) {
      return local;
    }
    final remote = await remoteStore.list(userId);
    if (remote.isNotEmpty) {
      await localStore.saveAll(remote);
      return remote;
    }
    return local;
  }

  Future<void> upsert(ProgressWindow window, {String? userId}) async {
    await localStore.upsert(window);
    if (userId == null || !remoteStore.isEnabled) {
      return;
    }
    await remoteStore.upsert(window, userId);
  }

  Future<void> delete(String id, {String? userId}) async {
    await localStore.delete(id);
    if (userId == null || !remoteStore.isEnabled) {
      return;
    }
    await remoteStore.delete(id);
  }
}

class LocalCacheStore {
  static const _storageKey = 'progress_windows_cache_v1';

  Future<List<ProgressWindow>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return [];
    }
    final decoded = jsonDecode(raw);
    if (decoded is! List) {
      return [];
    }
    return decoded
        .whereType<Map<String, dynamic>>()
        .map(ProgressWindow.fromJson)
        .toList();
  }

  Future<void> saveAll(List<ProgressWindow> windows) async {
    final prefs = await SharedPreferences.getInstance();
    final data = windows.map((window) => window.toJson()).toList();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> upsert(ProgressWindow window) async {
    final windows = await load();
    final index = windows.indexWhere((item) => item.id == window.id);
    if (index == -1) {
      windows.add(window);
    } else {
      windows[index] = window;
    }
    await saveAll(windows);
  }

  Future<void> delete(String id) async {
    final windows = await load();
    windows.removeWhere((item) => item.id == id);
    await saveAll(windows);
  }
}

class AmplifyRemoteStore {
  AmplifyRemoteStore(this.client);

  final AmplifyClient client;

  bool get isEnabled => client.isConfigured;

  Future<List<ProgressWindow>> list(String ownerId) async {
    final response = await client.query(_listQuery, {'owner': ownerId});
    if (response == null) {
      return [];
    }
    try {
      final data = jsonDecode(response);
      final items = (data['listProgressWindows']?['items'] as List?) ?? [];
      return items
          .whereType<Map<String, dynamic>>()
          .map(ProgressWindow.fromRemote)
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> upsert(ProgressWindow window, String ownerId) async {
    final payload = window.toRemoteJson(ownerId);
    final created = await client.mutate(_createMutation, {'input': payload});
    if (created != null) {
      return;
    }
    await client.mutate(_updateMutation, {'input': payload});
  }

  Future<void> delete(String id) async {
    await client.mutate(_deleteMutation, {
      'input': {'id': id},
    });
  }
}

class AmplifyClient {
  bool _configured = false;

  bool get isConfigured => _configured;

  Future<void> configure() async {
    if (_configured) {
      return;
    }
    try {
      Amplify.addPlugins([
        AmplifyAuthCognito(),
        AmplifyAPI(),
      ]);
      await Amplify.configure(amplifyconfig);
      _configured = true;
    } on AmplifyAlreadyConfiguredException {
      _configured = true;
    } catch (error) {
      safePrint('Amplify configure failed: $error');
    }
  }

  Future<String?> currentUserId() async {
    if (!_configured) {
      return null;
    }
    try {
      final user = await Amplify.Auth.getCurrentUser();
      return user.userId;
    } catch (_) {
      return null;
    }
  }

  Future<_AuthResult> signInWithPassword({
    required String username,
    required String password,
  }) async {
    if (!_configured) {
      return _AuthResult.error('Amplify is not configured.');
    }
    try {
      final result = await Amplify.Auth.signIn(
        username: username,
        password: password,
      );
      if (!result.isSignedIn) {
        return _AuthResult.error('Sign in was not completed.');
      }
      return _AuthResult.success(await currentUserId());
    } on AuthException catch (error) {
      return _AuthResult.error(error.message);
    } catch (error) {
      safePrint('Sign-in failed: $error');
      return _AuthResult.error('Sign in failed.');
    }
  }

  Future<_AuthResult> signUp({
    required String username,
    required String password,
    String? email,
  }) async {
    if (!_configured) {
      return _AuthResult.error('Amplify is not configured.');
    }
    try {
      final options = SignUpOptions(
        userAttributes: email == null || email.isEmpty
            ? {}
            : {AuthUserAttributeKey.email: email},
      );
      await Amplify.Auth.signUp(
        username: username,
        password: password,
        options: options,
      );
      return _AuthResult.success();
    } on AuthException catch (error) {
      return _AuthResult.error(error.message);
    } catch (error) {
      safePrint('Sign-up failed: $error');
      return _AuthResult.error('Sign up failed.');
    }
  }

  Future<_AuthResult> confirmSignUp({
    required String username,
    required String confirmationCode,
  }) async {
    if (!_configured) {
      return _AuthResult.error('Amplify is not configured.');
    }
    try {
      final result = await Amplify.Auth.confirmSignUp(
        username: username,
        confirmationCode: confirmationCode,
      );
      if (!result.isSignUpComplete) {
        return _AuthResult.error('Confirmation incomplete.');
      }
      return _AuthResult.success();
    } on AuthException catch (error) {
      return _AuthResult.error(error.message);
    } catch (error) {
      safePrint('Confirm sign-up failed: $error');
      return _AuthResult.error('Confirmation failed.');
    }
  }

  Future<void> signOut() async {
    if (!_configured) {
      return;
    }
    try {
      await Amplify.Auth.signOut();
    } catch (error) {
      safePrint('Sign-out failed: $error');
    }
  }

  Future<String?> query(String document, Map<String, dynamic> variables) async {
    if (!_configured) {
      return null;
    }
    try {
      final request = GraphQLRequest<String>(
        document: document,
        variables: variables,
      );
      final response = await Amplify.API.query(request: request).response;
      return response.data;
    } catch (error) {
      safePrint('GraphQL query failed: $error');
      return null;
    }
  }

  Future<String?> mutate(String document, Map<String, dynamic> variables) async {
    if (!_configured) {
      return null;
    }
    try {
      final request = GraphQLRequest<String>(
        document: document,
        variables: variables,
      );
      final response = await Amplify.API.mutate(request: request).response;
      return response.data;
    } catch (error) {
      safePrint('GraphQL mutation failed: $error');
      return null;
    }
  }
}

// SECTION: UI
class ProgressWindowsScreen extends StatefulWidget {
  const ProgressWindowsScreen({
    super.key,
    required this.repository,
    required this.isDark,
    required this.onToggleTheme,
    required this.onSignIn,
    required this.onSignOut,
    required this.userId,
    required this.amplifyConfigured,
  });

  final ProgressRepository repository;
  final bool isDark;
  final VoidCallback onToggleTheme;
  final VoidCallback onSignIn;
  final VoidCallback onSignOut;
  final String? userId;
  final bool amplifyConfigured;

  @override
  State<ProgressWindowsScreen> createState() => _ProgressWindowsScreenState();
}

class _ProgressWindowsScreenState extends State<ProgressWindowsScreen> {
  final List<ProgressWindow> _windows = [];
  int _counter = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWindows();
  }

  @override
  void didUpdateWidget(covariant ProgressWindowsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _loadWindows();
    }
  }

  Future<void> _loadWindows() async {
    setState(() {
      _loading = true;
    });
    final windows = await widget.repository.load(userId: widget.userId);
    setState(() {
      _windows
        ..clear()
        ..addAll(windows);
      _counter = _windows.length + 1;
      _loading = false;
    });
  }

  Future<void> _addWindow() async {
    final controller = TextEditingController(text: 'Goal $_counter');
    final name = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('New Progress Window'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Goal name',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(controller.text.trim()),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (name == null || name.isEmpty) {
      return;
    }

    final window = ProgressWindow(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: name,
      notes: '',
      tags: const ['focus'],
      goalCategory: 'Personal',
      weeklyTarget: 5,
    );

    setState(() {
      _windows.add(window);
      _counter += 1;
    });
    await widget.repository.upsert(window, userId: widget.userId);
  }

  int _countCheckedThisMonth(ProgressWindow window) {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    return window.entries.entries.where((entry) {
      if (!entry.value) {
        return false;
      }
      return entry.key.isAfter(firstDay.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(nextMonth);
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark
                ? const [Color(0xFF151310), Color(0xFF1E1B17)]
                : const [Color(0xFFF0E9E1), Color(0xFFE7DCCD)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Streak Sheet',
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Track daily goals across multiple windows.',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: colors.onBackground),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: widget.onToggleTheme,
                      icon: Icon(widget.isDark
                          ? Icons.wb_sunny_outlined
                          : Icons.nightlight_round),
                      tooltip: 'Toggle theme',
                    ),
                    const SizedBox(width: 6),
                    if (widget.userId == null)
                      OutlinedButton.icon(
                        onPressed:
                            widget.amplifyConfigured ? widget.onSignIn : null,
                        icon: const Icon(Icons.login),
                        label: const Text('Sign in'),
                      )
                    else
                      OutlinedButton.icon(
                        onPressed: widget.onSignOut,
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: _addWindow,
                      icon: const Icon(Icons.add),
                      label: const Text('Add'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _SyncBanner(
                  signedIn: widget.userId != null,
                  amplifyConfigured: widget.amplifyConfigured,
                ),
                const SizedBox(height: 12),
                const AdBanner(height: 72),
                const SizedBox(height: 16),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _windows.isEmpty
                          ? _EmptyState(onAdd: _addWindow)
                          : ListView.separated(
                              itemCount: _windows.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final window = _windows[index];
                                final checked = _countCheckedThisMonth(window);
                                return _WindowCard(
                                  window: window,
                                  checkedThisMonth: checked,
                                  onTap: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => ProgressWindowScreen(
                                          window: window,
                                          repository: widget.repository,
                                          userId: widget.userId,
                                        ),
                                      ),
                                    );
                                    setState(() {});
                                  },
                                  onDelete: () async {
                                    setState(() {
                                      _windows.removeAt(index);
                                    });
                                    await widget.repository.delete(window.id,
                                        userId: widget.userId);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({
    required this.signedIn,
    required this.amplifyConfigured,
  });

  final bool signedIn;
  final bool amplifyConfigured;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    String text;
    if (!amplifyConfigured) {
      text = 'Offline mode. Data stays on this device.';
    } else if (!signedIn) {
      text = 'Offline mode. Sign in to sync across devices.';
    } else {
      text = 'Sync enabled across your devices.';
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outline),
      ),
      child: Row(
        children: [
          const Icon(Icons.security_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class AdBanner extends StatefulWidget {
  const AdBanner({super.key, required this.height});

  final double height;

  @override
  State<AdBanner> createState() => _AdBannerState();
}

class _AdBannerState extends State<AdBanner> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      return;
    }
    final adUnitId = kReleaseMode
        ? 'ca-app-pub-3257451695610666/6744050166'
        : 'ca-app-pub-3940256099942544/6300978111';
    _bannerAd = BannerAd(
      size: AdSize.banner,
      adUnitId: adUnitId,
      listener: BannerAdListener(
        onAdLoaded: (_) => setState(() => _loaded = true),
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
      request: const AdRequest(),
    )..load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(height: widget.height);
    }
    if (!_loaded || _bannerAd == null) {
      return SizedBox(height: widget.height);
    }
    return SizedBox(
      height: widget.height,
      child: Align(
        alignment: Alignment.center,
        child: AdWidget(ad: _bannerAd!),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colors.surface.withOpacity(0.85),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: colors.outline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Add your first progress window.',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Each window has a calendar with one checkbox per day.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: colors.onSurface),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Create Window'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowCard extends StatelessWidget {
  const _WindowCard({
    required this.window,
    required this.checkedThisMonth,
    required this.onTap,
    required this.onDelete,
  });

  final ProgressWindow window;
  final int checkedThisMonth;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              height: 52,
              width: 52,
              decoration: BoxDecoration(
                color: colors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.calendar_today, color: colors.onPrimary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    window.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$checkedThisMonth days checked this month',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: colors.onSurface),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class ProgressWindowScreen extends StatefulWidget {
  const ProgressWindowScreen({
    super.key,
    required this.window,
    required this.repository,
    required this.userId,
  });

  final ProgressWindow window;
  final ProgressRepository repository;
  final String? userId;

  @override
  State<ProgressWindowScreen> createState() => _ProgressWindowScreenState();
}

class _ProgressWindowScreenState extends State<ProgressWindowScreen> {
  late DateTime _focusedDay;
  WindowView _view = WindowView.calendar;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
  }

  DateTime _normalize(DateTime day) => DateTime(day.year, day.month, day.day);

  Future<void> _toggleDay(DateTime day) async {
    final key = _normalize(day);
    setState(() {
      final current = widget.window.entries[key] ?? false;
      widget.window.entries[key] = !current;
    });
    await widget.repository.upsert(widget.window, userId: widget.userId);
  }

  bool _isChecked(DateTime day) {
    final key = _normalize(day);
    return widget.window.entries[key] ?? false;
  }

  Set<DateTime> _checkedSet() {
    return widget.window.entries.entries
        .where((entry) => entry.value)
        .map((entry) => _normalize(entry.key))
        .toSet();
  }

  int _currentStreak() {
    final checked = _checkedSet();
    var streak = 0;
    var day = _normalize(DateTime.now());
    while (checked.contains(day)) {
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  int _bestStreak() {
    final checked = _checkedSet().toList()..sort();
    if (checked.isEmpty) {
      return 0;
    }
    var best = 1;
    var current = 1;
    for (var i = 1; i < checked.length; i++) {
      final diff = checked[i].difference(checked[i - 1]).inDays;
      if (diff == 1) {
        current += 1;
        if (current > best) {
          best = current;
        }
      } else if (diff > 1) {
        current = 1;
      }
    }
    return best;
  }

  int _negativeStreak() {
    final checked = _checkedSet();
    var streak = 0;
    var day = _normalize(DateTime.now());
    for (var i = 0; i < 365; i++) {
      if (checked.contains(day)) {
        break;
      }
      streak += 1;
      day = day.subtract(const Duration(days: 1));
    }
    return streak;
  }

  double _monthCompletion() {
    final now = DateTime.now();
    final firstDay = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final daysInMonth = nextMonth.difference(firstDay).inDays;
    final checked = widget.window.entries.entries.where((entry) {
      if (!entry.value) {
        return false;
      }
      return entry.key.isAfter(firstDay.subtract(const Duration(days: 1))) &&
          entry.key.isBefore(nextMonth);
    }).length;
    return daysInMonth == 0 ? 0 : checked / daysInMonth;
  }

  List<double> _yearlyCompletion() {
    final now = DateTime.now();
    return List.generate(12, (index) {
      final month = index + 1;
      final firstDay = DateTime(now.year, month, 1);
      final nextMonth = DateTime(now.year, month + 1, 1);
      final daysInMonth = nextMonth.difference(firstDay).inDays;
      final checked = widget.window.entries.entries.where((entry) {
        if (!entry.value) {
          return false;
        }
        return entry.key.isAfter(firstDay.subtract(const Duration(days: 1))) &&
            entry.key.isBefore(nextMonth);
      }).length;
      return daysInMonth == 0 ? 0 : checked / daysInMonth;
    });
  }

  Future<void> _editDetails() async {
    final nameController = TextEditingController(text: widget.window.name);
    final notesController = TextEditingController(text: widget.window.notes);
    final tagsController =
        TextEditingController(text: widget.window.tags.join(', '));
    final categoryController =
        TextEditingController(text: widget.window.goalCategory);
    final weeklyController =
        TextEditingController(text: widget.window.weeklyTarget.toString());

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Edit goal details',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Goal name'),
              ),
              TextField(
                controller: notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              TextField(
                controller: tagsController,
                decoration: const InputDecoration(
                  labelText: 'Tags (comma separated)',
                ),
              ),
              TextField(
                controller: categoryController,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              TextField(
                controller: weeklyController,
                decoration: const InputDecoration(labelText: 'Weekly target'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );

    if (saved != true) {
      return;
    }

    setState(() {
      widget.window.name = nameController.text.trim();
      widget.window.notes = notesController.text.trim();
      widget.window.tags = tagsController.text
          .split(',')
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      widget.window.goalCategory = categoryController.text.trim().isEmpty
          ? 'Personal'
          : categoryController.text.trim();
      final parsed = int.tryParse(weeklyController.text.trim());
      widget.window.weeklyTarget = parsed == null || parsed <= 0 ? 5 : parsed;
    });
    await widget.repository.upsert(widget.window, userId: widget.userId);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final monthCompletion = _monthCompletion();
    final yearlyCompletion = _yearlyCompletion();
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.window.name),
        actions: [
          IconButton(
            onPressed: _editDetails,
            icon: const Icon(Icons.edit),
            tooltip: 'Edit goal',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SegmentedButton<WindowView>(
              segments: const [
                ButtonSegment(
                  value: WindowView.calendar,
                  label: Text('Calendar'),
                  icon: Icon(Icons.calendar_today),
                ),
                ButtonSegment(
                  value: WindowView.insights,
                  label: Text('Insights'),
                  icon: Icon(Icons.bar_chart),
                ),
              ],
              selected: <WindowView>{_view},
              onSelectionChanged: (value) {
                setState(() {
                  _view = value.first;
                });
              },
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _view == WindowView.calendar
                    ? Column(
                        key: const ValueKey('calendar'),
                        children: [
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 18,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final availableHeight = constraints.maxHeight;
                                  final rowHeight =
                                      (availableHeight - 56) / 7.0;
                                  final clampedRowHeight =
                                      rowHeight.clamp(36.0, 60.0);
                                  return TableCalendar(
                                firstDay: DateTime.utc(2020, 1, 1),
                                lastDay: DateTime.utc(2035, 12, 31),
                                focusedDay: _focusedDay,
                                calendarFormat: CalendarFormat.month,
                                availableCalendarFormats: const {
                                  CalendarFormat.month: 'Month',
                                },
                                rowHeight: clampedRowHeight,
                                daysOfWeekHeight: 18,
                                headerStyle: const HeaderStyle(
                                  titleCentered: true,
                                  formatButtonVisible: false,
                                ),
                                onPageChanged: (focusedDay) {
                                  setState(() {
                                    _focusedDay = focusedDay;
                                  });
                                },
                                onDaySelected: (selectedDay, focusedDay) {
                                  setState(() {
                                    _focusedDay = focusedDay;
                                  });
                                  _toggleDay(selectedDay);
                                },
                                calendarBuilders: CalendarBuilders(
                                  defaultBuilder: (context, day, focusedDay) {
                                    return _DayCheckboxCell(
                                      day: day,
                                      checked: _isChecked(day),
                                      onToggle: () => _toggleDay(day),
                                    );
                                  },
                                  todayBuilder: (context, day, focusedDay) {
                                    return _DayCheckboxCell(
                                      day: day,
                                      checked: _isChecked(day),
                                      highlight: true,
                                      onToggle: () => _toggleDay(day),
                                    );
                                  },
                                  outsideBuilder: (context, day, focusedDay) {
                                    return _DayCheckboxCell(
                                      day: day,
                                      checked: _isChecked(day),
                                      disabled: true,
                                      onToggle: () {},
                                    );
                                  },
                                  selectedBuilder: (context, day, focusedDay) {
                                    return _DayCheckboxCell(
                                      day: day,
                                      checked: _isChecked(day),
                                      highlight: true,
                                      onToggle: () => _toggleDay(day),
                                    );
                                  },
                                ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _GoalDetailsCard(window: widget.window),
                        ],
                      )
                    : _InsightsView(
                        key: const ValueKey('insights'),
                        checkedSet: _checkedSet(),
                        currentStreak: _currentStreak(),
                        bestStreak: _bestStreak(),
                        negativeStreak: _negativeStreak(),
                        monthCompletion: monthCompletion,
                        yearlyCompletion: yearlyCompletion,
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const AdBanner(height: 64),
          ],
        ),
      ),
    );
  }
}

class _GoalDetailsCard extends StatelessWidget {
  const _GoalDetailsCard({required this.window});

  final ProgressWindow window;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Goal details',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            window.notes.isEmpty ? 'No notes yet.' : window.notes,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: window.tags
                .map(
                  (tag) => Chip(
                    label: Text(tag),
                    backgroundColor: colors.primary.withOpacity(0.1),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 8),
          Text(
            'Category: ${window.goalCategory}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Weekly target: ${window.weeklyTarget} days',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

enum WindowView { calendar, insights }

class _InsightsView extends StatelessWidget {
  const _InsightsView({
    super.key,
    required this.checkedSet,
    required this.currentStreak,
    required this.bestStreak,
    required this.negativeStreak,
    required this.monthCompletion,
    required this.yearlyCompletion,
  });

  final Set<DateTime> checkedSet;
  final int currentStreak;
  final int bestStreak;
  final int negativeStreak;
  final double monthCompletion;
  final List<double> yearlyCompletion;

  List<DateTime> _lastDays(int count) {
    final today = DateTime.now();
    return List.generate(
      count,
      (index) => DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: count - 1 - index)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final recentDays = _lastDays(14);
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _MetricCard(
                  label: 'Current streak',
                  value: '$currentStreak days',
                  icon: Icons.local_fire_department_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricCard(
                  label: 'Best streak',
                  value: '$bestStreak days',
                  icon: Icons.emoji_events_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MetricCard(
            label: 'Missed streak',
            value: '$negativeStreak days',
            icon: Icons.broken_image_outlined,
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Month completion',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${(monthCompletion * 100).round()}% complete',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LinearProgressIndicator(
                    value: monthCompletion,
                    minHeight: 12,
                    backgroundColor: colors.outline.withOpacity(0.2),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Yearly overview',
            child: _YearlyChart(values: yearlyCompletion),
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: 'Last 14 days',
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: recentDays.map((day) {
                final checked = checkedSet.contains(day);
                return Container(
                  height: 28,
                  width: 28,
                  decoration: BoxDecoration(
                    color: checked ? colors.secondary : colors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color:
                                checked ? colors.onSecondary : colors.onSurface,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _YearlyChart extends StatelessWidget {
  const _YearlyChart({required this.values});

  final List<double> values;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    const labels = [
      'J',
      'F',
      'M',
      'A',
      'M',
      'J',
      'J',
      'A',
      'S',
      'O',
      'N',
      'D'
    ];
    return SizedBox(
      height: 140,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(12, (index) {
          final value = index < values.length ? values[index] : 0.0;
          final height = 20 + (value * 90);
          return Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: height,
                  width: 10,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                const SizedBox(height: 6),
                Text(labels[index],
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DayCheckboxCell extends StatelessWidget {
  const _DayCheckboxCell({
    required this.day,
    required this.checked,
    required this.onToggle,
    this.highlight = false,
    this.disabled = false,
  });

  final DateTime day;
  final bool checked;
  final VoidCallback onToggle;
  final bool highlight;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textColor = disabled
        ? colors.outline
        : highlight
            ? colors.primary
            : colors.onSurface;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.all(2),
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
      decoration: BoxDecoration(
        color: highlight ? colors.primary.withOpacity(0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: highlight ? colors.primary : colors.outline,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${day.day}',
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: textColor, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          IgnorePointer(
            ignoring: disabled,
            child: SizedBox(
              height: 18,
              width: 18,
              child: Checkbox(
                value: checked,
                onChanged: (_) => onToggle(),
                visualDensity: VisualDensity.compact,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _dateKey(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}

DateTime _parseDateKey(String key) {
  final parts = key.split('-');
  if (parts.length != 3) {
    return DateTime.now();
  }
  return DateTime(
    int.tryParse(parts[0]) ?? DateTime.now().year,
    int.tryParse(parts[1]) ?? DateTime.now().month,
    int.tryParse(parts[2]) ?? DateTime.now().day,
  );
}

const _createMutation = r'''
mutation CreateProgressWindow($input: CreateProgressWindowInput!) {
  createProgressWindow(input: $input) {
    id
    name
  }
}
''';

const _updateMutation = r'''
mutation UpdateProgressWindow($input: UpdateProgressWindowInput!) {
  updateProgressWindow(input: $input) {
    id
    name
  }
}
''';

const _deleteMutation = r'''
mutation DeleteProgressWindow($input: DeleteProgressWindowInput!) {
  deleteProgressWindow(input: $input) {
    id
  }
}
''';

const _listQuery = r'''
query ListProgressWindows($owner: String!) {
  listProgressWindows(filter: { owner: { eq: $owner } }) {
    items {
      id
      name
      notes
      tags
      goalCategory
      weeklyTarget
      entries
    }
  }
}
''';
