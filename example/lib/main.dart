import 'dart:convert';
import 'dart:io';

import 'package:faro/faro.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'features/sampling_settings/domain/sampling_settings_service.dart';
import 'features/sampling_settings/presentation/sampling_settings_page.dart';
import 'features/tracing/presentation/tracing_page.dart';
import 'features/user_settings/user_settings_page.dart';
import 'features/user_settings/user_settings_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // IMPORTANT: Set HttpOverrides BEFORE creating any http.Client instances!
  // The http package uses IOClient on mobile, which creates an HttpClient
  // at construction time. If HttpOverrides is set after the client is created,
  // Faro won't intercept those HTTP requests.
  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  // Create ProviderContainer with SharedPreferences override
  // This is Riverpod's root and allows us to access providers before runApp()
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    ],
  );

  // Load user settings service (still using singleton pattern)
  final userSettingsService = UserSettingsService.instance;
  await userSettingsService.init();

  // Get sampling settings from Riverpod
  final samplingSettingsService =
      container.read(samplingSettingsServiceProvider);

  const faroCollectorUrl = String.fromEnvironment('FARO_COLLECTOR_URL');
  final faroApiKey = faroCollectorUrl.split('/').last;

  Faro().transports.add(OfflineTransport(
        maxCacheDuration: const Duration(days: 3),
      ));

  await Faro().runApp(
    optionsConfiguration: FaroConfig(
      appName: 'example_app',
      appVersion: '2.0.1',
      appEnv: 'Test',
      apiKey: faroApiKey,
      namespace: 'flutter_app',
      // Sampling is configured via SamplingSettingsService
      sampling: samplingSettingsService.sampling,
      anrTracking: true,
      cpuUsageVitals: true,
      collectorUrl: faroCollectorUrl,
      enableCrashReporting: true,
      memoryUsageVitals: true,
      refreshRateVitals: true,
      fetchVitalsInterval: const Duration(seconds: 30),
      sessionAttributes: {
        'team': 'mobile',
        'department': 'engineering',
        'test_int': 42,
        'test_bool': true,
        'test_double': 3.14,
      },
      initialUser: userSettingsService.initialUser,
      persistUser: userSettingsService.persistUser,
    ),
    appRunner: () async {
      runApp(
        // Use UncontrolledProviderScope to pass the pre-created container
        // This allows providers to be accessed before runApp() if needed
        UncontrolledProviderScope(
          container: container,
          child: DefaultAssetBundle(
            bundle: FaroAssetBundle(),
            child: const FaroUserInteractionWidget(child: MyApp()),
          ),
        ),
      );
    },
  );
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    setState(() {});
  }

  // Method to simulate an ANR by blocking the main thread
  void simulateANR({int seconds = 10}) {
    debugPrint(
        'Simulating ANR by blocking main thread for $seconds seconds...');
    final startTime = DateTime.now();
    // This loop will block the main thread
    while (DateTime.now().difference(startTime).inSeconds < seconds) {
      // Perform intensive calculations to block the thread
      for (int i = 0; i < 10000000; i++) {
        final _ = i * i * i;
      }
    }
    debugPrint('ANR simulation completed');
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [FaroNavigationObserver()],
      initialRoute: '/',
      routes: {
        '/home': (context) => const HomePage(),
        '/features': (context) => const FeaturesPage(),
        '/user-settings': (context) => const UserSettingsPage(),
        '/sampling-settings': (context) => const SamplingSettingsPage(),
        '/tracing': (context) => const TracingPage(),
      },
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Faro Test App'),
        ),
        body: const HomePage(),
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton(
            child: const Text('Change Route'),
            onPressed: () {
              Navigator.pushNamed(context, '/features');
            },
          ),
        ],
      ),
    );
  }
}

class FeaturesPage extends StatefulWidget {
  const FeaturesPage({super.key});

  @override
  State<FeaturesPage> createState() => _FeaturesPageState();
}

class _FeaturesPageState extends State<FeaturesPage> {
  final _userSettingsService = UserSettingsService.instance;
  String _currentUserDisplay = 'Not set';

  bool get _isSessionSampled => Faro().isSampled;
  String get _samplingStatusDisplay =>
      _isSessionSampled ? 'Sampled' : 'Not sampled';

  @override
  void initState() {
    super.initState();
    Faro().markEventEnd('home_event_start', 'home_page_load');
    _updateCurrentUser();
  }

  void _updateCurrentUser() {
    setState(() {
      _currentUserDisplay = _userSettingsService.getCurrentUserDisplay();
    });
  }

  void simulateANR({int seconds = 10}) {
    debugPrint(
        'Simulating ANR by blocking main thread for $seconds seconds...');
    final startTime = DateTime.now();
    while (DateTime.now().difference(startTime).inSeconds < seconds) {
      for (int i = 0; i < 10000000; i++) {
        final _ = i * i * i;
      }
    }
    debugPrint('ANR simulation completed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Features'),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // User Settings Card
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person),
                  title: const Text('User Settings'),
                  subtitle: Text('Current: $_currentUserDisplay'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.pushNamed(context, '/user-settings');
                    _updateCurrentUser();
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Sampling Settings Card
              Card(
                child: ListTile(
                  leading: Icon(
                    Icons.analytics,
                    color: _isSessionSampled ? Colors.green : Colors.grey,
                  ),
                  title: const Text('Sampling Settings'),
                  subtitle: Text(
                    'Session: $_samplingStatusDisplay',
                    style: TextStyle(
                      color: _isSessionSampled ? Colors.green : Colors.grey,
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.pushNamed(context, '/sampling-settings');
                    // Trigger rebuild (sampling status is a getter)
                    setState(() {});
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Tracing Card
              Card(
                child: ListTile(
                  leading: const Icon(Icons.timeline),
                  title: const Text('Tracing / Spans'),
                  subtitle: const Text('Test spans and traces'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pushNamed(context, '/tracing');
                  },
                ),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              ElevatedButton(
                child: const Text('HTTP POST Request - success'),
                onPressed: () async {
                  await http.post(
                    Uri.parse('https://httpbin.io/post'),
                    body: jsonEncode(<String, String>{
                      'title': 'This is a title',
                    }),
                  );
                },
              ),
              ElevatedButton(
                child: const Text('HTTP POST Request - fail'),
                onPressed: () async {
                  await http.post(
                    Uri.parse('https://httpbin.io/unstable'),
                    body: jsonEncode(<String, String>{
                      'title': 'This is a title',
                    }),
                  );
                },
              ),
              ElevatedButton(
                child: const Text('HTTP GET Request - success'),
                onPressed: () async {
                  await http.get(Uri.parse('https://httpbin.io/get?foo=bar'));
                },
              ),
              ElevatedButton(
                child: const Text('HTTP GET Request - fail'),
                onPressed: () async {
                  await http.get(Uri.parse('https://httpbin.io/unstable'));
                },
              ),
              ElevatedButton(
                child: const Text('Custom Warn Log'),
                onPressed: () {
                  Faro().pushLog('Custom Warning Log', level: LogLevel.warn);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Info Log'),
                onPressed: () {
                  Faro()
                      .pushLog('This is an info message', level: LogLevel.info);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Error Log'),
                onPressed: () {
                  Faro().pushLog('This is an error message',
                      level: LogLevel.error);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Debug Log'),
                onPressed: () {
                  Faro().pushLog('This is a debug message',
                      level: LogLevel.debug);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Trace Log'),
                onPressed: () {
                  Faro().pushLog('This is a trace message',
                      level: LogLevel.trace);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Measurement'),
                onPressed: () {
                  Faro().pushMeasurement(
                      {'custom_value': 1}, 'custom_measurement');
                },
              ),
              ElevatedButton(
                child: const Text('Custom Event'),
                onPressed: () {
                  Faro().pushEvent('custom_event');
                },
              ),
              ElevatedButton(
                child: const Text('Error'),
                onPressed: () {
                  setState(() {
                    throw Error();
                  });
                },
              ),
              ElevatedButton(
                child: const Text('Exception'),
                onPressed: () {
                  setState(() {
                    double _ = 0 / 0;
                    throw Exception('This is an Exception!');
                  });
                },
              ),
              ElevatedButton(
                child: const Text('Mark Event Start'),
                onPressed: () async {
                  Faro().markEventStart('event1', 'event1_duration');
                },
              ),
              ElevatedButton(
                child: const Text('Mark Event End'),
                onPressed: () async {
                  Faro().markEventEnd('event1', 'event1_duration');
                },
              ),
              ElevatedButton(
                onPressed: () => simulateANR(),
                child: const Text('Simulate ANR (10s)'),
              ),
              ElevatedButton(
                onPressed: () => simulateANR(seconds: 8),
                child: const Text('Simulate ANR (8s)'),
              ),
              ElevatedButton(
                child: Text(
                    'Data Collection: ${Faro().enableDataCollection ? "ENABLED" : "DISABLED"}'),
                onPressed: () {
                  Faro().enableDataCollection = !Faro().enableDataCollection;
                  setState(() {}); // Refresh UI
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
