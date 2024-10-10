import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:offline_transport/offline_transport.dart';
import 'package:rum_sdk/rum_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  HttpOverrides.global = RumHttpOverrides(HttpOverrides.current);
  await dotenv.load(fileName: ".env");
  RumFlutter()
      .transports
      .add(OfflineTransport(maxCacheDuration: const Duration(days: 3)));
  await RumFlutter().runApp(
      optionsConfiguration: RumConfig(
        appName: "example_app",
        appVersion: "2.0.1",
        appEnv: "Test",
        apiKey: dotenv.env['FARO_API_KEY'] ?? '',
        anrTracking: true,
        cpuUsageVitals: true,
        collectorUrl: dotenv.env['FARO_COLLECTOR_URL'] ?? '',
        enableCrashReporting: true,
        memoryUsageVitals: true,
        refreshRateVitals: true,
        fetchVitalsInterval: const Duration(seconds: 30),
      ),
      appRunner: () async {
        runApp(DefaultAssetBundle(
            bundle: RumAssetBundle(),
            child: const RumUserInteractionWidget(child: MyApp())));
      });
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  // test
  //  final _rumSdkPlugin = RumSdkPlatform.instance;

  @override
  void initState() {
    super.initState();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        navigatorObservers: [RumNavigationObserver()],
        initialRoute: '/',
        routes: {
          '/home': (context) => const HomePage(),
          '/features': (context) => const FeaturesPage()
        },
        home: Scaffold(
            appBar: AppBar(
              title: const Text('RUM Test App'),
            ),
            body: const HomePage()));
  }
}

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  _HomePageState createState() => _HomePageState();
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
            crossAxisAlignment:
                CrossAxisAlignment.center, // Center horizontally
            children: [
          // const Image(image: AssetImage("assets/AppHomeImage.png"),),
          ElevatedButton(
              child: const Text("Change Route"),
              onPressed: () {
                Navigator.pushNamed(context, '/features');
              }),
        ]));
  }
}

class _FeaturesPageState extends State<FeaturesPage> {
  @override
  void initState() {
    super.initState();
    RumFlutter().markEventEnd("home_event_start", "home_page_load");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Features'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                final response = await http.post(
                  Uri.parse('<mock_api_endpoint>'),
                  body: jsonEncode(<String, String>{
                    'title': "This is a title",
                  }),
                );
              },
              child: const Text('HTTP POST Request - fail'),
            ),
            ElevatedButton(
              onPressed: () async {
                final response = await http.post(
                  Uri.parse('<mock_api_endpoint>'),
                  body: jsonEncode(<String, String>{
                    'title': "This is a title",
                  }),
                );
              },
              child: const Text('HTTP POST Request - success'),
            ),
            ElevatedButton(
              onPressed: () async {
                final response = await http
                    .get(Uri.parse('<mock_api_endpoint>'));
              },
              child: const Text('HTTP GET Request - success'),
            ),
            ElevatedButton(
              onPressed: () async {
                final response =
                    await http.get(Uri.parse('<mock_api_endpoint>'));
              },
              child: const Text('HTTP GET Request - fail'),
            ),
            ElevatedButton(
              onPressed: () {
                RumFlutter().pushLog("Custom Log", level: "warn");
              },
              child: const Text('Custom Warn Log'),
            ),
            ElevatedButton(
              onPressed: () {
                RumFlutter()
                    .pushMeasurement({'customvalue': 1}, "custom_measurement");
              },
              child: const Text('Custom Measurement'),
            ),
            ElevatedButton(
              onPressed: () {
                RumFlutter().pushEvent("custom_event");
              },
              child: const Text('Custom Event'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  throw Error();
                });
              },
              child: Text('Error'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  double a = 0 / 0;
                  throw Exception("This is an Exception!");
                });
              },
              child: Text('Exception'),
            ),
            ElevatedButton(
              onPressed: () async {
                RumFlutter().markEventStart("event1", "event1_duration");
              },
              child: const Text('Mark Event Start'),
            ),
            ElevatedButton(
              onPressed: () async {
                RumFlutter().markEventEnd("event1", "event1_duration");
              },
              child: const Text('Mark Event End'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class FeaturesPage extends StatefulWidget {
  const FeaturesPage({Key? key}) : super(key: key);

  @override
  _FeaturesPageState createState() => _FeaturesPageState();
}
