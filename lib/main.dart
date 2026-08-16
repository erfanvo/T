import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const TapsiPremiumApp());
}

class TapsiPremiumApp extends StatelessWidget {
  const TapsiPremiumApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium Client',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF66FCF1),
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF66FCF1),
          secondary: Color(0xFF45A29E),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthScreen(),
    );
  }
}

// ==========================================
// SECURE AUTHENTICATION SCREEN (LUXURY UI)
// ==========================================
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final TextEditingController _licenseController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _authenticate() async {
    final licenseKey = _licenseController.text.trim();
    if (licenseKey.isEmpty || !licenseKey.startsWith('TAPSI-')) {
      setState(() => _errorMessage = 'INVALID LICENSE FORMAT');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await http.get(
        Uri.parse('https://testtok-production.up.railway.app/api/tapsi/get-license/$licenseKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final cookies = data['data']['cookies'] ?? '';
          final localStorage = data['data']['local_storage'] ?? '{}';
          
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) => CoreEngineScreen(
                cookies: cookies,
                localStorageStr: localStorage,
              ),
              transitionsBuilder: (context, animation, secondaryAnimation, child) {
                return FadeTransition(opacity: animation, child: child);
              },
            ),
          );
        }
      } else {
        setState(() => _errorMessage = 'LICENSE EXPIRED OR NOT FOUND');
      }
    } catch (e) {
      setState(() => _errorMessage = 'NETWORK CONNECTION FAILED');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0B0C10), Color(0xFF1F2833)],
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF66FCF1).withOpacity(0.1),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF66FCF1).withOpacity(0.2),
                        blurRadius: 30,
                        spreadRadius: 10,
                      )
                    ]
                  ),
                  child: const Icon(Icons.shield_rounded, size: 70, color: Color(0xFF66FCF1)),
                ),
                const SizedBox(height: 40),
                const Text(
                  'PREMIUM ACCESS',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 4.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Enter your secure license key to proceed',
                  style: TextStyle(fontSize: 12, color: Colors.white54, letterSpacing: 1.0),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _licenseController,
                  style: const TextStyle(color: Colors.white, letterSpacing: 2.0, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.3),
                    hintText: 'TAPSI-XXXX-XXXX',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 2.0),
                    contentPadding: const EdgeInsets.symmetric(vertical: 20),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                if (_errorMessage.isNotEmpty)
                  Text(_errorMessage, style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF66FCF1),
                      foregroundColor: const Color(0xFF0B0C10),
                      elevation: 10,
                      shadowColor: const Color(0xFF66FCF1).withOpacity(0.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _isLoading ? null : _authenticate,
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0B0C10), strokeWidth: 3))
                        : const Text('AUTHENTICATE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
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

// ==========================================
// CORE ENGINE SCREEN (WEBVIEW)
// ==========================================
class CoreEngineScreen extends StatefulWidget {
  final String cookies;
  final String localStorageStr;

  const CoreEngineScreen({
    Key? key,
    required this.cookies,
    required this.localStorageStr,
  }) : super(key: key);

  @override
  State<CoreEngineScreen> createState() => _CoreEngineScreenState();
}

class _CoreEngineScreenState extends State<CoreEngineScreen> {
  InAppWebViewController? webViewController;
  bool _isSettingUp = true;

  @override
  void initState() {
    super.initState();
    _setupCore();
  }

  Future<void> _setupCore() async {
    CookieManager cookieManager = CookieManager.instance();
    
    if (widget.cookies.isNotEmpty && widget.cookies != 'empty') {
      List<String> cookiePairs = widget.cookies.split(';');
      
      // Massive Domain Blanket to ensure SSO captures the token
      List<String> targetDomains = [
        ".tapsi.cab", "app.tapsi.cab", "api.tapsi.cab", 
        ".tapsi.ir", "accounts.tapsi.ir", "accounts-api.tapsi.ir", 
        ".tapsi.markets", "www.tapsi.markets", "apigateway.tapsi.markets"
      ];

      for (String pair in cookiePairs) {
        List<String> parts = pair.trim().split('=');
        if (parts.length >= 2) {
          String name = parts[0].trim();
          String value = parts.sublist(1).join('=').trim();
          
          for (String d in targetDomains) {
            String urlStr = "https://" + (d.startsWith('.') ? d.substring(1) : d);
            await cookieManager.setCookie(
              url: WebUri(urlStr),
              name: name,
              value: value,
              domain: d,
              isSecure: true,
            );
          }
        }
      }
    }
    setState(() => _isSettingUp = false);
  }

  String _buildInjectionScript() {
    String lsInjection = "";
    
    if (widget.localStorageStr != '{}') {
      try {
        Map<String, dynamic> lsData = json.decode(widget.localStorageStr);
        lsData.forEach((key, value) {
          String safeValue = value.toString().replaceAll("'", "\\'").replaceAll('\n', '\\n');
          lsInjection += "window.localStorage.setItem('$key', '$safeValue');\n";
        });
      } catch (e) {
        debugPrint("Error parsing LocalStorage");
      }
    }

    // THE MAGIC LOGIC: Inject into tapsi.cab AND tapsi.ir (SSO) but NOT into tapsi.markets!
    return """
      var host = window.location.hostname;
      if (host.includes('tapsi.cab') || host.includes('tapsi.ir')) {
        $lsInjection
      }
      
      // Override popups
      window.open = function(url, target, features) {
        window.location.href = url;
        return null;
      };
      
      document.addEventListener('click', function(e) {
        var a = e.target.closest('a');
        if (a && a.getAttribute('target') === '_blank') {
          a.setAttribute('target', '_self');
        }
      }, true);
    """;
  }

  @override
  Widget build(BuildContext context) {
    if (_isSettingUp) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0C10),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              CircularProgressIndicator(color: Color(0xFF66FCF1)),
              SizedBox(height: 20),
              Text('ESTABLISHING SECURE CONNECTION...', style: TextStyle(color: Color(0xFF66FCF1), letterSpacing: 2.0, fontSize: 10)),
            ],
          )
        )
      );
    }

    UserScript injectionScript = UserScript(
      source: _buildInjectionScript(),
      injectionTime: UserScriptInjectionTime.AT_DOCUMENT_START,
      forMainFrameOnly: false, 
    );

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        if (webViewController != null && await webViewController!.canGoBack()) {
          webViewController!.goBack();
        } else {
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0B0C10),
        body: SafeArea(
          child: InAppWebView(
            initialUrlRequest: URLRequest(url: WebUri("https://app.tapsi.cab/profile/")),
            initialUserScripts: UnmodifiableListView<UserScript>([injectionScript]),
            initialSettings: InAppWebViewSettings(
              javaScriptEnabled: true,
              domStorageEnabled: true,
              clearCache: true,
              thirdPartyCookiesEnabled: true, 
              supportMultipleWindows: false,
              javaScriptCanOpenWindowsAutomatically: false,
              userAgent: "Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
            ),
            onWebViewCreated: (controller) {
              webViewController = controller;
            },
            onLoadStop: (controller, url) async {
              bool? isReloaded = await controller.evaluateJavascript(source: "window.sessionStorage.getItem('reloaded');") == 'true';
              if (!isReloaded) {
                await controller.evaluateJavascript(source: "window.sessionStorage.setItem('reloaded', 'true');");
                controller.reload();
              }
            },
          ),
        ),
      ),
    );
  }
}
