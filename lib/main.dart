import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TapsiApp());
}

class TapsiApp extends StatelessWidget {
  const TapsiApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tapsi Injector App',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF5CEBFF),
        scaffoldBackgroundColor: const Color(0xFF121C29),
      ),
      debugShowCheckedModeBanner: false,
      home: const LicenseScreen(),
    );
  }
}

// ==========================================
// صفحه ورود لایسنس
// ==========================================
class LicenseScreen extends StatefulWidget {
  const LicenseScreen({Key? key}) : super(key: key);

  @override
  State<LicenseScreen> createState() => _LicenseScreenState();
}

class _LicenseScreenState extends State<LicenseScreen> {
  final TextEditingController _licenseController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _fetchAndInject() async {
    final licenseKey = _licenseController.text.trim();
    if (licenseKey.isEmpty || !licenseKey.startsWith('TAPSI-')) {
      setState(() => _errorMessage = 'فرمت لایسنس معتبر نیست.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      // دریافت اطلاعات از سرور Railway
      final response = await http.get(
        Uri.parse('https://testtok-production.up.railway.app/api/tapsi/get-license/$licenseKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final cookies = data['data']['cookies'] ?? '';
          final localStorage = data['data']['local_storage'] ?? '{}';
          
          if (!mounted) return;
          // انتقال به صفحه WebView و ارسال دیتا
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => TapsiWebScreen(
                cookies: cookies,
                localStorageStr: localStorage,
              ),
            ),
          );
        }
      } else {
        setState(() => _errorMessage = 'لایسنس یافت نشد.');
      }
    } catch (e) {
      setState(() => _errorMessage = 'خطای شبکه.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ورود به تپسی')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _licenseController,
              decoration: const InputDecoration(
                hintText: 'TAPSI-XXXX-XXXX',
                filled: true,
                fillColor: Color(0xFF1E2D40),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            if (_errorMessage.isNotEmpty) Text(_errorMessage, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF5CEBFF)),
                onPressed: _isLoading ? null : _fetchAndInject,
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('ورود', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// صفحه WebView تپسی
// ==========================================
class TapsiWebScreen extends StatefulWidget {
  final String cookies;
  final String localStorageStr;

  const TapsiWebScreen({
    Key? key,
    required this.cookies,
    required this.localStorageStr,
  }) : super(key: key);

  @override
  State<TapsiWebScreen> createState() => _TapsiWebScreenState();
}

class _TapsiWebScreenState extends State<TapsiWebScreen> {
  InAppWebViewController? webViewController;
  bool _isSettingUp = true;

  @override
  void initState() {
    super.initState();
    _setupCookies();
  }

  // ۱. تنظیم کوکی‌ها در مرورگر داخلی پیش از باز کردن صفحه
  Future<void> _setupCookies() async {
    CookieManager cookieManager = CookieManager.instance();
    
    if (widget.cookies.isNotEmpty && widget.cookies != 'empty') {
      List<String> cookiePairs = widget.cookies.split(';');
      for (String pair in cookiePairs) {
        List<String> parts = pair.trim().split('=');
        if (parts.length >= 2) {
          String name = parts[0];
          String value = parts.sublist(1).join('=');
          
          await cookieManager.setCookie(
            url: WebUri("https://app.tapsi.cab"),
            name: name,
            value: value,
            domain: ".tapsi.cab",
            isSecure: true,
          );
        }
      }
    }
    setState(() => _isSettingUp = false);
  }

  // ۲. ساخت کد جاوااسکریپت برای تزریق Local Storage
  String _buildLocalStorageScript() {
    if (widget.localStorageStr == '{}') return "";
    
    String script = "";
    try {
      Map<String, dynamic> lsData = json.decode(widget.localStorageStr);
      lsData.forEach((key, value) {
        // جلوگیری از تداخل کاراکترها در جاوااسکر��پت
        String safeValue = value.toString().replaceAll("'", "\\'");
        script += "window.localStorage.setItem('$key', '$safeValue');\n";
      });
    } catch (e) {
      debugPrint("Error parsing LocalStorage");
    }
    return script;
  }

  @override
  Widget build(BuildContext context) {
    if (_isSettingUp) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // ۳. اجرای اسکریپت در لحظه استارت داکیومنت (قبل از رندر PWA تپسی)
    UserScript lsInjectionScript = UserScript(
      source: _buildLocalStorageScript(),
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
    );

    return Scaffold(
      body: SafeArea(
        child: InAppWebView(
          initialUrlRequest: URLRequest(url: WebUri("https://app.tapsi.cab/profile/")),
          initialUserScripts: UnmodifiableListView<UserScript>([lsInjectionScript]),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            clearCache: true,
            userAgent: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
          ),
          onWebViewCreated: (controller) {
            webViewController = controller;
          },
          onLoadStop: (controller, url) async {
            // رفرش دوم برای اطمینان از اینکه PWA دیتای لوکال استوریج را خوانده است
            bool? isReloaded = await controller.evaluateJavascript(source: "window.sessionStorage.getItem('reloaded');") == 'true';
            if (!isReloaded) {
              await controller.evaluateJavascript(source: "window.sessionStorage.setItem('reloaded', 'true');");
              controller.reload();
            }
          },
        ),
      ),
    );
  }
}
