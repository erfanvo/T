import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:collection';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PremiumClientApp());
}

class PremiumClientApp extends StatelessWidget {
  const PremiumClientApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Premium Access',
      theme: ThemeData.dark().copyWith(
        primaryColor: const Color(0xFF5CEBFF),
        scaffoldBackgroundColor: const Color(0xFF0B0C10),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF5CEBFF),
          secondary: Color(0xFFD4AF37), // Gold accent
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthenticationScreen(),
    );
  }
}

// ==========================================
// PREMIUM AUTHENTICATION SCREEN
// ==========================================
class AuthenticationScreen extends StatefulWidget {
  const AuthenticationScreen({Key? key}) : super(key: key);

  @override
  State<AuthenticationScreen> createState() => _AuthenticationScreenState();
}

class _AuthenticationScreenState extends State<AuthenticationScreen> {
  final TextEditingController _licenseController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _verifyLicense() async {
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
        setState(() => _errorMessage = 'LICENSE EXPIRED OR UNAUTHORIZED');
      }
    } catch (e) {
      setState(() => _errorMessage = 'SECURE CONNECTION FAILED');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1F2833), Color(0xFF0B0C10)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF5CEBFF).withOpacity(0.05),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5CEBFF).withOpacity(0.15),
                        blurRadius: 40,
                        spreadRadius: 10,
                      )
                    ]
                  ),
                  child: const Icon(Icons.fingerprint_rounded, size: 80, color: Color(0xFF5CEBFF)),
                ),
                const SizedBox(height: 40),
                const Text(
                  'SYSTEM ACCESS',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6.0,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Please provide your secure token to proceed',
                  style: TextStyle(fontSize: 13, color: Colors.white54, letterSpacing: 1.2),
                ),
                const SizedBox(height: 45),
                TextField(
                  controller: _licenseController,
                  style: const TextStyle(color: Color(0xFF5CEBFF), letterSpacing: 2.5, fontWeight: FontWeight.bold, fontSize: 16),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black.withOpacity(0.4),
                    hintText: 'TAPSI-XXXX-XXXX',
                    hintStyle: const TextStyle(color: Colors.white24, letterSpacing: 3.0),
                    contentPadding: const EdgeInsets.symmetric(vertical: 22),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide(color: Colors.white.withOpacity(0.05), width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(color: Color(0xFF5CEBFF), width: 1.5),
                    ),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                if (_errorMessage.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Text(_errorMessage, style: const TextStyle(color: Color(0xFFFF5252), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.0)),
                  ),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF5CEBFF),
                      foregroundColor: const Color(0xFF0B0C10),
                      elevation: 8,
                      shadowColor: const Color(0xFF5CEBFF).withOpacity(0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    ),
                    onPressed: _isLoading ? null : _verifyLicense,
                    child: _isLoading 
                        ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Color(0xFF0B0C10), strokeWidth: 3))
                        : const Text('AUTHENTICATE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 3.0)),
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
// CORE ENGINE SCREEN (WEBVIEW INTEGRATION)
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
  bool _isEngineReady = false;

  @override
  void initState() {
    super.initState();
    _initializeEngine();
  }

  Future<void> _initializeEngine() async {
    CookieManager cookieManager = CookieManager.instance();
    
    if (widget.cookies.isNotEmpty && widget.cookies != 'empty') {
      List<String> cookiePairs = widget.cookies.split(';');
      
      // Target ALL micro-service domains to bypass SSO entirely
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
              sameSite: HTTPCookieSameSitePolicy.NONE, // CRITICAL FOR CROSS-DOMAIN SSO
            );
          }
        }
      }
    }
    setState(() => _isEngineReady = true);
  }

  String _buildInjectionScript() {
    String storageInjection = "";
    
    if (widget.localStorageStr != '{}') {
      try {
        Map<String, dynamic> lsData = json.decode(widget.localStorageStr);
        lsData.forEach((key, value) {
          String safeValue = value.toString().replaceAll("\\", "\\\\").replaceAll("'", "\\'").replaceAll('\n', '\\n');
          // UNCONDITIONAL INJECTION: Force token into every micro-service (markets, food, etc.)
          storageInjection += "window.localStorage.setItem('$key', '$safeValue');\n";
          storageInjection += "window.sessionStorage.setItem('$key', '$safeValue');\n";
        });
      } catch (e) {
        debugPrint("Data parsing error");
      }
    }

    return """
      $storageInjection
      
      // Override popups to load internally and prevent freezes
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
    if (!_isEngineReady) {
      return Scaffold(
        backgroundColor: const Color(0xFF0B0C10),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              SizedBox(width: 40, height: 40, child: CircularProgressIndicator(color: Color(0xFF5CEBFF), strokeWidth: 2)),
              SizedBox(height: 24),
              Text('INITIALIZING CORE ENGINE...', style: TextStyle(color: Color(0xFF5CEBFF), letterSpacing: 3.0, fontSize: 11, fontWeight: FontWeight.bold)),
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
              bool? isReloaded = await controller.evaluateJavascript(source: "window.sessionStorage.getItem('core_init');") == 'true';
              if (!isReloaded) {
                await controller.evaluateJavascript(source: "window.sessionStorage.setItem('core_init', 'true');");
                controller.reload();
              }
            },
          ),
        ),
      ),
    );
  }
}
