import 'package:flutter/material.dart';
import 'widgets/upload_widget.dart';
import 'widgets/batch_upload_widget.dart';
import 'screens/dashboard_screen.dart';
import 'screens/results_screen.dart';
import 'screens/settings_screen.dart';
import 'services/history_service.dart';
import 'services/scan_engine.dart';
import 'services/settings_service.dart';
import 'services/encrypted_storage.dart';
import 'models/invoice.dart';
import 'models/scan_result.dart';

// Design tokens
const _kPrimary = Color(0xFF0B3D91); // deep blue
const _kAccent = Color(0xFF00A3FF); // bright cyan
const _kSurface = Color(0xFF0A1B2A); // near-black deep surface

class ShieldPayApp extends StatelessWidget {
  const ShieldPayApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark().copyWith(
      colorScheme: const ColorScheme.dark(
        primary: _kPrimary,
        secondary: _kAccent,
        surface: _kSurface,
      ),
      scaffoldBackgroundColor: const Color(0xFF071026),
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );

    return MaterialApp(
      title: 'ShieldPay',
      theme: base.copyWith(textTheme: base.textTheme.apply(fontFamily: 'Inter')),
      home: const LandingScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> with SingleTickerProviderStateMixin {
  bool _showOnboarding = false;
  int _selectedIndex = 0;
  int _hoverIndex = -1;

  late final AnimationController _animController;
  late final Animation<double> _heroAnim;
  late final Animation<Offset> _cardOffset1;
  late final Animation<Offset> _cardOffset2;
  late final Animation<double> _cardFade1;
  late final Animation<double> _cardFade2;
  late final Animation<double> _shimmerAnim;

  @override
  void initState() {
    super.initState();
    _checkFirstRun();

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _heroAnim = CurvedAnimation(parent: _animController, curve: const Interval(0.0, 0.35, curve: Curves.easeOut));
    _cardOffset1 = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.35, 0.62, curve: Curves.easeOut)));
    _cardOffset2 = Tween<Offset>(begin: const Offset(0, 0.22), end: Offset.zero).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.5, 0.85, curve: Curves.easeOut)));
    _cardFade1 = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.35, 0.62, curve: Curves.easeIn)));
    _cardFade2 = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.5, 0.85, curve: Curves.easeIn)));
    _shimmerAnim = Tween<double>(begin: -1.0, end: 1.0).animate(CurvedAnimation(parent: _animController, curve: const Interval(0.10, 0.90, curve: Curves.easeInOut)));

    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _animController.forward(); });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkFirstRun() async {
    // Load settings first to determine if encrypted storage is enabled.
    await SettingsService.instance.load();
    final settings = SettingsService.instance.current;

    // If encryption is enabled and we have a salt, prompt user to unlock.
    if (settings.encryptedStorageEnabled && (settings.encryptionSalt?.isNotEmpty ?? false)) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final pass = await showDialog<String>(context: context, builder: (ctx) {
          String val = '';
          return AlertDialog(
            title: const Text('Unlock encrypted history'),
            content: TextField(obscureText: true, onChanged: (v) => val = v, decoration: const InputDecoration(labelText: 'Passphrase')),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), TextButton(onPressed: () => Navigator.pop(ctx, val), child: const Text('Unlock'))],
          );
        });
        if (pass != null && pass.isNotEmpty) {
          try {
            EncryptedStorageService.setPassphraseWithSalt(pass, settings.encryptionSalt!);
          } catch (_) {
            if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to unlock encrypted history')));
          }
        }
      });
    }

    final history = await loadHistory();
    if (history.isEmpty) setState(() => _showOnboarding = true);
  }

  void _closeOnboarding() => setState(() => _showOnboarding = false);

  void _onScanned(ScanResult result) async {
    try {
      await saveScanToHistory({...result.details, 'score': result.score, 'reasons': result.reasons.join(' | ')});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save scan: ${e.toString()}')));
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
  }

  void _openBatchUpload() {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('Batch Upload')), body: Padding(padding: const EdgeInsets.all(12), child: BatchUploadWidget()))));
  }

  Future<void> _runDemoScan() async {
    // create a realistic-looking sample invoice and run the scan flow
    final invoice = Invoice(
      payeeName: 'Acme Supplies Ltd',
      accountNumber: 'GB33BUKB20201555555555',
      amount: 1243.50,
      email: 'billing@acme-supplies.com',
      vendorDomain: 'acme-supplies.com',
      invoiceDate: DateTime.now().subtract(const Duration(days: 3)),
    );
    final history = await loadHistory();
    final result = await ScanEngine.scan(invoice, history: history);
    try {
      await saveScanToHistory({...result.details, 'score': result.score, 'reasons': result.reasons.join(' | ')});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save demo scan: ${e.toString()}')));
    }
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => ResultsScreen(result: result)));
  }

  Future<void> _seedSampleHistory() async {
    // add a few sample rows to demonstrate dashboard and export
    final samples = [
      {'payeeName': 'Acme Supplies Ltd', 'accountNumber': 'GB33BUKB20201555555555', 'amount': '1243.50', 'email': 'billing@acme-supplies.com', 'vendorDomain': 'acme-supplies.com', 'score': 72, 'reasons': 'vendor_mismatch | amount_outlier'},
      {'payeeName': 'Contoso Ltd', 'accountNumber': 'DE89370400440532013000', 'amount': '520.00', 'email': 'accounts@contoso.com', 'vendorDomain': 'contoso.com', 'score': 12, 'reasons': 'ok'},
      {'payeeName': 'Small Vendor', 'accountNumber': 'FR7630006000011234567890189', 'amount': '15000.00', 'email': 'pay@smallvendor.com', 'vendorDomain': 'smallvendor.com', 'score': 88, 'reasons': 'iban_suspicious | amount_outlier'},
    ];
    for (final s in samples) {
      try {
        await saveScanToHistory(Map<String, dynamic>.from(s));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not seed sample history: ${e.toString()}')));
        return;
      }
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sample history added — check History')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          Container(width: 40, height: 40, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_kAccent, _kPrimary]), borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0,2))]), child: const Icon(Icons.shield, color: Colors.white, size: 20)),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [Text('ShieldPay', style: TextStyle(fontWeight: FontWeight.w700)), Text('Invoice Fraud Guard', style: TextStyle(fontSize: 12))]),
        ]),
        elevation: 0,
        backgroundColor: const Color(0xFF071026),
      ),
      body: LayoutBuilder(builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 800;
        final sidebar = Container(
          width: 260,
          color: const Color(0xFF071826),
          child: Column(children: [
            const SizedBox(height: 24),
            const ListTile(leading: Icon(Icons.shield, color: _kAccent), title: Text('ShieldPay', style: TextStyle(fontWeight: FontWeight.bold))),
            const Divider(color: Colors.white12),
            _navTile(Icons.home, 'Quick Scan', index: 0, onTap: () { setState(() => _selectedIndex = 0); }),
            _navTile(Icons.upload_file, 'Batch Upload', index: 1, onTap: () { _openBatchUpload(); setState(() => _selectedIndex = 1); }),
            _navTile(Icons.history, 'History', index: 2, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DashboardScreen()))),
            _navTile(Icons.settings, 'Settings', index: 3, onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
            const Spacer(),
          ]),
        );

        final mainContent = SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              ScaleTransition(
                scale: _heroAnim,
                child: FadeTransition(
                  opacity: _heroAnim,
                  child: Stack(
                    children: [
                      // base gradient
                      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF071026), Color(0xFF07182A)]), borderRadius: BorderRadius.circular(12))),
                      // animated shimmer overlay for a subtle pro-grade finish
                      AnimatedBuilder(
                        animation: _shimmerAnim,
                        builder: (context, child) {
                          final a = _shimmerAnim.value;
                          return Opacity(
                            opacity: _heroAnim.value * 0.9,
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment(-1.0 + a, -0.5),
                                  end: Alignment(1.0 - a, 0.7),
                                  colors: const [Color(0xFF072042), Color(0xFF00172B)],
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          );
                        },
                      ),
                      // content on top
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Row(children: [
                            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                              Text('Stop invoice fraud before it happens', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
                              SizedBox(height: 8),
                              Text('ShieldPay scans payment requests and flags suspicious accounts, amounts, and vendor mismatches — entirely in-browser, privacy-first.'),
                              SizedBox(height: 12),
                            ])),
                            FancyButton(onPressed: () { setState(() => _selectedIndex = 0); }, icon: const Icon(Icons.shield, size: 18), label: const Text('Quick Scan')),
                          ]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
              AnimatedSwitcher(duration: const Duration(milliseconds: 350), child: _selectedIndex == 0 ? _buildCardsRow() : (_selectedIndex == 1 ? _buildBatchCard() : _buildHistoryPreview())),
            ]),
          ),
        );

        if (isNarrow) {
          return Scaffold(drawer: Drawer(child: sidebar), body: mainContent);
        }

        return Row(children: [sidebar, Expanded(child: mainContent)]);
      }),
      floatingActionButton: _showOnboarding ? FloatingActionButton.extended(icon: const Icon(Icons.info_outline), label: const Text('Show Onboarding'), onPressed: _showOnboardingDialog) : null,
    );
  }

  Widget _buildCardsRow() {
    return Row(children: [
      Expanded(
        child: SlideTransition(
          position: _cardOffset1,
          child: FadeTransition(
            opacity: _cardFade1,
            child: HoverScale(child: Card(elevation: 6, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: UploadWidget(onScanned: _onScanned)))),
          ),
        ),
      ),
      const SizedBox(width: 20),
      Expanded(
        child: SlideTransition(
          position: _cardOffset2,
          child: FadeTransition(
            opacity: _cardFade2,
            child: HoverScale(child: Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: BatchUploadWidget()))),
          ),
        ),
      ),
    ]);
  }

  Widget _buildBatchCard() => Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: BatchUploadWidget()));

  Widget _buildHistoryPreview() => Card(elevation: 4, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(16), child: const DashboardScreen()));

  void _showOnboardingDialog() {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Welcome to ShieldPay'),
      content: SizedBox(width: 560, height: 360, child: OnboardingCarousel(onDemoScan: _runDemoScan, onSeedHistory: _seedSampleHistory, onClose: () { _closeOnboarding(); Navigator.pop(ctx); })),
      actions: [TextButton(onPressed: () { _closeOnboarding(); Navigator.pop(ctx); }, child: const Text('Close'))],
    ));
  }

  Widget _navTile(IconData icon, String title, {required VoidCallback onTap, int index = -1}) {
    final selected = index >= 0 && _selectedIndex == index;
    final hovered = index >= 0 && _hoverIndex == index;
    return MouseRegion(
      onEnter: (_) { if (mounted) setState(() => _hoverIndex = index); },
      onExit: (_) { if (mounted) setState(() => _hoverIndex = -1); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        padding: EdgeInsets.fromLTRB(hovered ? 14 : 8, 6, 6, 6),
        decoration: BoxDecoration(
          color: selected ? Color.fromRGBO(0, 163, 255, 0.10) : (hovered ? Colors.white10 : Colors.transparent),
          borderRadius: BorderRadius.circular(10),
          boxShadow: hovered ? [BoxShadow(color: Colors.black26, blurRadius: 8, offset: const Offset(0,4))] : null,
        ),
        child: ListTile(
          leading: AnimatedSwitcher(duration: const Duration(milliseconds: 260), transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)), child: Icon(icon, key: ValueKey<bool>(selected), color: selected ? _kAccent : Colors.white70)),
          title: AnimatedDefaultTextStyle(duration: const Duration(milliseconds: 220), style: TextStyle(color: selected ? _kAccent : Colors.white70, fontWeight: selected ? FontWeight.w700 : FontWeight.w500), child: Text(title)),
          onTap: onTap,
          selected: selected,
          visualDensity: VisualDensity.compact,
          contentPadding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}

// A subtle, professional button with hover & press micro-animations.
class FancyButton extends StatefulWidget {
  final VoidCallback onPressed;
  final Widget label;
  final Widget? icon;
  final double elevation;
  const FancyButton({super.key, required this.onPressed, required this.label, this.icon, this.elevation = 6});

  @override
  State<FancyButton> createState() => _FancyButtonState();
}

class _FancyButtonState extends State<FancyButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed ? 0.985 : (_hover ? 1.02 : 1.0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) { setState(() => _pressed = false); widget.onPressed(); },
        onTapCancel: () => setState(() => _pressed = false),
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: Color.lerp(_kAccent, Colors.white, _hover ? 0.06 : 0.0),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: widget.elevation + (_hover ? 6 : 0), offset: Offset(0, _hover ? 8 : 6))],
          ),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          child: Transform.scale(
            scale: scale,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 10)],
              DefaultTextStyle(style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700), child: widget.label),
            ]),
          ),
        ),
      ),
    );
  }
}

// Small helper that scales its child slightly on hover (web/desktop).
class HoverScale extends StatefulWidget {
  final Widget child;
  final double scale;
  const HoverScale({super.key, required this.child, this.scale = 1.03});

  @override
  State<HoverScale> createState() => _HoverScaleState();
}

class _HoverScaleState extends State<HoverScale> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _hover ? widget.scale : 1.0),
        duration: const Duration(milliseconds: 180),
        builder: (context, val, child) => Transform.scale(
          scale: val,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              boxShadow: _hover ? [BoxShadow(color: Colors.black26, blurRadius: 12, offset: const Offset(0, 8))] : [],
            ),
            child: child,
          ),
        ),
        child: widget.child,
      ),
    );
  }
}

// Simple onboarding carousel with pages and animated dots
class OnboardingCarousel extends StatefulWidget {
  final VoidCallback? onDemoScan;
  final VoidCallback? onSeedHistory;
  final VoidCallback? onClose;

  const OnboardingCarousel({super.key, this.onDemoScan, this.onSeedHistory, this.onClose});

  @override
  State<OnboardingCarousel> createState() => _OnboardingCarouselState();
}

class _OnboardingCarouselState extends State<OnboardingCarousel> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Expanded(
        child: PageView(
          controller: _controller,
          onPageChanged: (p) => setState(() => _page = p),
          children: [
            _buildPage(
              'Quick Scan',
              'Paste or type a single invoice to scan instantly. Privacy-first, runs in your browser.',
              actions: [
                ElevatedButton(onPressed: widget.onDemoScan, child: const Text('Run Demo Scan')),
              ],
            ),
            _buildPage(
              'Batch Upload',
              'Paste CSVs or upload files to scan multiple invoices quickly.',
              actions: [
                ElevatedButton(onPressed: widget.onSeedHistory, child: const Text('Add Sample History')),
              ],
            ),
            _buildPage(
              'Dashboard',
              'Track history, export CSV/PDF reports, and review flagged items.',
              actions: [
                ElevatedButton(onPressed: widget.onClose, child: const Text('Done')),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(3, (i) => AnimatedContainer(duration: const Duration(milliseconds: 250), margin: const EdgeInsets.symmetric(horizontal: 6), width: _page == i ? 26 : 10, height: 8, decoration: BoxDecoration(color: _page == i ? _kAccent : Colors.white24, borderRadius: BorderRadius.circular(6))))),
    ]);
  }

  Widget _buildPage(String title, String text, {List<Widget>? actions}) {
    return Padding(
      padding: const EdgeInsets.all(18.0),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(text),
        const Spacer(),
        Row(mainAxisAlignment: MainAxisAlignment.end, children: [
          if (actions != null) ...actions,
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () {
              if (_page < 2) {
                _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
              } else {
                if (widget.onClose != null) widget.onClose!();
              }
            },
            child: Text(_page < 2 ? 'Next' : 'Finish'),
          ),
        ]),
      ]),
    );
  }
}


