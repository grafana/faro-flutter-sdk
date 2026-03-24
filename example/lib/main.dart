import 'dart:io';

import 'package:faro/faro.dart';
import 'package:faro_example/features/app_diagnostics/presentation/app_diagnostics_page.dart';
import 'package:faro_example/features/custom_telemetry/presentation/custom_telemetry_page.dart';
import 'package:faro_example/features/feature_catalog/presentation/feature_catalog_page.dart';
import 'package:faro_example/features/network_requests/presentation/network_requests_page.dart';
import 'package:faro_example/features/sampling_settings/domain/sampling_settings_service.dart';
import 'package:faro_example/features/sampling_settings/presentation/sampling_settings_page.dart';
import 'package:faro_example/features/tracing/presentation/tracing_page.dart';
import 'package:faro_example/features/user_actions/presentation/user_actions_page.dart';
import 'package:faro_example/features/user_settings/user_settings_page.dart';
import 'package:faro_example/features/user_settings/user_settings_service.dart';
import 'package:faro_example/qa_config.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb) {
    // IMPORTANT: Set HttpOverrides BEFORE creating any http.Client instances!
    // The http package uses IOClient on mobile, which creates an HttpClient
    // at construction time. If HttpOverrides is set after the client is
    // created, Faro won't intercept those HTTP requests.
    HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);
  }

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

  final qaConfig = QaConfig.fromEnvironment();

  final sessionAttributes = <String, Object>{
    'team': 'mobile',
    'department': 'engineering',
    'test_int': 42,
    'test_bool': true,
    'test_double': 3.14,
    if (qaConfig.hasRunId) 'qa_run_id': qaConfig.runId!,
  };

  final initialUser = qaConfig.hasInitialUser
      ? qaConfig.initialUser
      : userSettingsService.initialUser;

  if (!kIsWeb) {
    Faro().transports.add(OfflineTransport(
          maxCacheDuration: const Duration(days: 3),
        ));
  }

  await Faro().runApp(
    optionsConfiguration: FaroConfig(
      appName: 'example_app',
      appVersion: '2.0.1',
      appEnv: 'Test',
      apiKey: faroApiKey,
      namespace: 'flutter_app',
      sampling: samplingSettingsService.sampling,
      anrTracking: true,
      cpuUsageVitals: true,
      collectorUrl: faroCollectorUrl,
      enableCrashReporting: true,
      memoryUsageVitals: true,
      refreshRateVitals: true,
      fetchVitalsInterval: const Duration(seconds: 30),
      sessionAttributes: sessionAttributes,
      initialUser: initialUser,
      persistUser: userSettingsService.persistUser,
    ),
    appRunner: () async {
      runApp(
        // Use UncontrolledProviderScope to pass the pre-created container
        // This allows providers to be accessed before runApp() if needed
        UncontrolledProviderScope(
          container: container,
          child: FaroAssetTracking(
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorObservers: [FaroNavigationObserver()],
      initialRoute: '/',
      routes: {
        '/home': (context) => const HomePage(),
        '/features': (context) => const FeatureCatalogPage(),
        '/user-settings': (context) => const UserSettingsPage(),
        '/sampling-settings': (context) => const SamplingSettingsPage(),
        '/custom-telemetry': (context) => const CustomTelemetryPage(),
        '/network-requests': (context) => const NetworkRequestsPage(),
        '/tracing': (context) => const TracingPage(),
        '/user-actions': (context) => const UserActionsPage(),
        '/app-diagnostics': (context) => const AppDiagnosticsPage(),
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
