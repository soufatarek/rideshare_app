// main.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:rideshare_driver/screen/register_page.dart';
import 'package:rideshare_driver/screen/test_login_page.dart';
import 'package:rideshare_driver/screen/home_page.dart';
import 'package:rideshare_driver/services/auth_service.dart';

class Login_page extends StatelessWidget {
  const Login_page({super.key});

  @override
  Widget build(BuildContext context) {
    return const DriverPortalLogin();
  }
}

class DriverPortalLogin extends StatefulWidget {
  const DriverPortalLogin({super.key});

  @override
  State<DriverPortalLogin> createState() => _DriverPortalLoginState();
}

class _DriverPortalLoginState extends State<DriverPortalLogin> {
  bool _obscure = true;
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  final _authService = AuthService();
  bool _isLoading = false;

  Future<void> _handleLogin() async {
    final id = _idController.text.trim();
    final pw = _pwController.text.trim();

    if (id.isEmpty || pw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter both ID and Password")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final result = await _authService.loginWithPhone(phone: id, password: pw);

    setState(() => _isLoading = false);

    if (result['success']) {
      if (mounted) {
        final driverId = result['uid'] as String? ?? '';
        final driverData = result['userData'] as Map<String, dynamic>? ?? {};
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => HomePage(
              driverId: driverId,
              driverData: driverData,
            ),
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? "Login failed")),
        );
      }
    }
  }

  @override
  void dispose() {
    _idController.dispose();
    _pwController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          const Positioned.fill(child: _BackgroundArt()),

          // Content (scroll + centered when possible)
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight;

                return Center(
                  child: ScrollConfiguration(
                    behavior: ScrollConfiguration.of(
                      context,
                    ).copyWith(scrollbars: false),
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 18,
                      ),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: h),
                        child: IntrinsicHeight(
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 420),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 8),

                                  // Top icon badge
                                  Container(
                                    width: 56,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0D3B63,
                                      ).withOpacity(0.55),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.white.withOpacity(0.08),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.35),
                                          blurRadius: 18,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: const Icon(
                                      Icons.directions_car_rounded,
                                      color: Color(0xFF37A3FF),
                                    ),
                                  ),

                                  const SizedBox(height: 14),

                                  const Text(
                                    "Driver Portal",
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    "Log in to start your shift",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.white.withOpacity(0.65),
                                    ),
                                  ),

                                  const SizedBox(height: 26),

                                  // Labels + fields
                                  const _Label("Phone or Email"),
                                  const SizedBox(height: 8),
                                  _GlassField(
                                    hint: "Enter your ID",
                                    prefix: Icons.person_rounded,
                                    keyboardType: TextInputType.text,
                                    controller: _idController,
                                  ),

                                  const SizedBox(height: 16),

                                  Row(
                                    children: [
                                      const Expanded(child: _Label("Password")),
                                      GestureDetector(
                                        onTap: () {},
                                        child: Text(
                                          "Forgot Password?",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: const Color(
                                              0xFF37A3FF,
                                            ).withOpacity(0.95),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  _GlassField(
                                    hint: "••••••••••",
                                    prefix: Icons.lock_rounded,
                                    obscureText: _obscure,
                                    controller: _pwController,
                                    suffix: IconButton(
                                      onPressed:
                                          () => setState(
                                            () => _obscure = !_obscure,
                                          ),
                                      icon: Icon(
                                        _obscure
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                      ),
                                      color: Colors.white.withOpacity(0.6),
                                    ),
                                  ),

                                  const SizedBox(height: 18),

                                  // Primary button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: ElevatedButton.icon(
                                      onPressed:
                                          _isLoading ? null : _handleLogin,
                                      icon:
                                          _isLoading
                                              ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                              : const Icon(
                                                Icons.login_rounded,
                                                size: 18,
                                              ),
                                      label: Text(
                                        _isLoading ? "Logging in..." : "Log In",
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2F95FF,
                                        ),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        elevation: 10,
                                        shadowColor: const Color(
                                          0xFF2F95FF,
                                        ).withOpacity(0.35),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 16),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white.withOpacity(0.10),
                                          thickness: 1,
                                        ),
                                      ),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                        ),
                                        child: Text(
                                          "Or",
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(
                                              0.6,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        child: Divider(
                                          color: Colors.white.withOpacity(0.10),
                                          thickness: 1,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 14),

                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: OutlinedButton.icon(
                                      onPressed: () {},
                                      icon: const Icon(
                                        Icons.sms_rounded,
                                        size: 18,
                                      ),
                                      label: const Text(
                                        "Login via OTP",
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.white
                                            .withOpacity(0.90),
                                        side: BorderSide(
                                          color: Colors.white.withOpacity(0.18),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        backgroundColor: Colors.white
                                            .withOpacity(0.04),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 26),

                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "Don't have an account? ",
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.65),
                                          fontSize: 12,
                                        ),
                                      ),
                                      _RegisterButton(
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder:
                                                  (context) =>
                                                      const RegisterPage(),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 10),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder:
                                              (context) =>
                                                  const TestLoginPage(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      "Go to Test Login Page",
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.4),
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: Colors.white.withOpacity(0.65),
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _GlassField extends StatelessWidget {
  final String hint;
  final IconData prefix;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;
  final TextEditingController? controller;

  const _GlassField({
    required this.hint,
    required this.prefix,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.30),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.45),
            fontSize: 13,
          ),
          prefixIcon: Icon(prefix, color: Colors.white.withOpacity(0.60)),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}

class _BackgroundArt extends StatelessWidget {
  const _BackgroundArt();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _LoginBackgroundPainter(),
      child: const SizedBox.expand(),
    );
  }
}

class _LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Base gradient background
    final rect = Offset.zero & size;
    final bg =
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B1B2A), Color(0xFF081522), Color(0xFF050D16)],
          ).createShader(rect);
    canvas.drawRect(rect, bg);

    // Soft vignette / glow
    final glow =
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.0, -0.55),
            radius: 1.1,
            colors: [Colors.white.withOpacity(0.05), Colors.transparent],
          ).createShader(rect);
    canvas.drawRect(rect, glow);

    // Blue swoosh blob
    final blobPaint =
        Paint()
          ..color = const Color(0xFF2F95FF).withOpacity(0.92)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0);

    final path = Path();
    path.moveTo(-size.width * 0.10, size.height * 0.26);
    path.cubicTo(
      size.width * 0.20,
      size.height * 0.12,
      size.width * 0.56,
      size.height * 0.16,
      size.width * 0.70,
      size.height * 0.30,
    );
    path.cubicTo(
      size.width * 0.90,
      size.height * 0.50,
      size.width * 0.70,
      size.height * 0.62,
      size.width * 0.42,
      size.height * 0.58,
    );
    path.cubicTo(
      size.width * 0.14,
      size.height * 0.54,
      size.width * 0.03,
      size.height * 0.44,
      -size.width * 0.10,
      size.height * 0.42,
    );
    path.close();

    // Clip the blob so it looks like the screenshot (not full coverage)
    final blobClip =
        Path()..addRect(
          Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.60),
        );
    canvas.save();
    canvas.clipPath(blobClip);
    canvas.drawPath(path, blobPaint);
    canvas.restore();

    // Dark overlay over the blob to keep it subtle
    final shade = Paint()..color = const Color(0xFF07101A).withOpacity(0.25);
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.60),
      shade,
    );

    // Dashed curve (white)
    final dashedPaint =
        Paint()
          ..color = Colors.white.withOpacity(0.70)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2;

    final curve = Path();
    curve.moveTo(-size.width * 0.10, size.height * 0.34);
    curve.cubicTo(
      size.width * 0.20,
      size.height * 0.18,
      size.width * 0.55,
      size.height * 0.26,
      size.width * 0.70,
      size.height * 0.40,
    );
    curve.cubicTo(
      size.width * 0.92,
      size.height * 0.60,
      size.width * 0.72,
      size.height * 0.75,
      size.width * 0.45,
      size.height * 0.70,
    );

    _drawDashedPath(canvas, curve, dashedPaint, dash: 10, gap: 10);

    // Subtle top highlight for depth
    final topHighlight =
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white.withOpacity(0.06), Colors.transparent],
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.35));
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height * 0.35),
      topHighlight,
    );
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint, {
    double dash = 8,
    double gap = 6,
  }) {
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = math.min(dash, metric.length - distance);
        final segment = metric.extractPath(distance, distance + len);
        canvas.drawPath(segment, paint);
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RegisterButton extends StatefulWidget {
  final VoidCallback onTap;
  const _RegisterButton({required this.onTap});

  @override
  State<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends State<_RegisterButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color:
                _isHovered
                    ? Colors.white.withOpacity(0.12)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color:
                  _isHovered
                      ? Colors.white.withOpacity(0.3)
                      : Colors.transparent,
            ),
          ),
          child: const Text(
            "Register Now →",
            style: TextStyle(
              color: Color(0xFF2D8CFF),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
