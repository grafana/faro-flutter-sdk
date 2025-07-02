import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:faro/faro_sdk.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = FaroHttpOverrides(HttpOverrides.current);

  const faroCollectorUrl = String.fromEnvironment('FARO_COLLECTOR_URL');
  final faroApiKey = faroCollectorUrl.split('/').last;

  Faro().transports.add(OfflineTransport(
        maxCacheDuration: const Duration(days: 3),
      ));
  await Faro().runApp(
      optionsConfiguration: FaroConfig(
        appName: "example_app",
        appVersion: "2.0.1",
        appEnv: "Test",
        apiKey: faroApiKey,
        namespace: 'flutter_app',
        anrTracking: true,
        cpuUsageVitals: true,
        collectorUrl: faroCollectorUrl,
        enableCrashReporting: true,
        memoryUsageVitals: true,
        refreshRateVitals: true,
        fetchVitalsInterval: const Duration(seconds: 30),
      ),
      appRunner: () async {
        runApp(DefaultAssetBundle(
            bundle: FaroAssetBundle(),
            child: const FaroUserInteractionWidget(child: MyApp())));
      });
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
          '/features': (context) => const FeaturesPage()
        },
        home: Scaffold(
            appBar: AppBar(
              title: const Text('Faro Test App'),
            ),
            body: const HomePage()));
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
            mainAxisAlignment: MainAxisAlignment.center, // Center vertically
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
          ElevatedButton(
              child: const Text("Change Route"),
              onPressed: () {
                Navigator.pushNamed(context, '/features');
              }),
        ]));
  }
}

class FeaturesPage extends StatefulWidget {
  const FeaturesPage({super.key});

  @override
  State<FeaturesPage> createState() => _FeaturesPageState();
}

class _FeaturesPageState extends State<FeaturesPage> {
  @override
  void initState() {
    super.initState();
    Faro().markEventEnd("home_event_start", "home_page_load");
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
              ElevatedButton(
                child: const Text('HTTP POST Request - success'),
                onPressed: () async {
                  await http.post(
                    Uri.parse('https://httpbin.io/post'),
                    body: jsonEncode(<String, String>{
                      'title': "This is a title",
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
                      'title': "This is a title",
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
                  Faro().pushLog("Custom Warning Log", level: LogLevel.warn);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Info Log'),
                onPressed: () {
                  Faro()
                      .pushLog("This is an info message", level: LogLevel.info);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Error Log'),
                onPressed: () {
                  Faro().pushLog("This is an error message",
                      level: LogLevel.error);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Debug Log'),
                onPressed: () {
                  Faro().pushLog("This is a debug message",
                      level: LogLevel.debug);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Trace Log'),
                onPressed: () {
                  Faro().pushLog("This is a trace message",
                      level: LogLevel.trace);
                },
              ),
              ElevatedButton(
                child: const Text('Custom Measurement'),
                onPressed: () {
                  Faro().pushMeasurement(
                      {'custom_value': 1}, "custom_measurement");
                },
              ),
              ElevatedButton(
                child: const Text('Custom Event'),
                onPressed: () {
                  Faro().pushEvent("custom_event");
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
                    throw Exception("This is an Exception!");
                  });
                },
              ),
              ElevatedButton(
                child: const Text('Mark Event Start'),
                onPressed: () async {
                  Faro().markEventStart("event1", "event1_duration");
                },
              ),
              ElevatedButton(
                child: const Text('Mark Event End'),
                onPressed: () async {
                  Faro().markEventEnd("event1", "event1_duration");
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
