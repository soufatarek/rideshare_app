import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'otp_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final firstName = TextEditingController();
  final lastName = TextEditingController();
  final phone = TextEditingController();
  final password = TextEditingController();

  bool obscure = true;
  bool loading = false;

  @override
  void dispose() {
    firstName.dispose();
    lastName.dispose();
    phone.dispose();
    password.dispose();
    super.dispose();
  }

  String _normalizeEgyptPhone(String raw) {
    final p = raw.trim().replaceAll(' ', '');
    if (p.startsWith('+')) return p;
    if (p.startsWith('0')) return '+20${p.substring(1)}';
    if (p.startsWith('1')) return '+20$p';
    return '+20$p';
  }

  Future<void> _continueToOtp() async {
    final f = firstName.text.trim();
    final l = lastName.text.trim();
    final ph = phone.text.trim();
    final pw = password.text;

    if (f.isEmpty || l.isEmpty || ph.isEmpty || pw.isEmpty) {
      _toast("Please fill all fields");
      return;
    }

    if (pw.length < 6) {
      _toast("Password must be at least 6 characters");
      return;
    }

    final phoneE164 = _normalizeEgyptPhone(ph);

    setState(() => loading = true);

    try {
      if (kIsWeb) {
        final confirmation = await FirebaseAuth.instance.signInWithPhoneNumber(phoneE164);

        if (!mounted) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => OtpPage(
              phone: phoneE164,
              confirmationResult: confirmation,
              firstName: f,
              lastName: l,
              password: pw,
            ),
          ),
        );

      } else {
        // ✅ Mobile flow uses verifyPhoneNumber
        await FirebaseAuth.instance.verifyPhoneNumber(
          phoneNumber: phoneE164,
          verificationCompleted: (PhoneAuthCredential credential) async {
            // لو الجهاز عمل auto-verify
            await FirebaseAuth.instance.signInWithCredential(credential);

            if (!mounted) return;
            // Go to OtpPage anyway to handle Firestore creation, or skip if we move logic here.
            // For now, let's just go there with null verificationId and handle it.
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpPage(
                  phone: phoneE164,
                  verificationId: '', // Empty string to indicate it was auto-verified or similar
                  firstName: f,
                  lastName: l,
                  password: pw,
                ),
              ),
            );
          },
          verificationFailed: (FirebaseAuthException e) {
            _toast(e.message ?? "Verification failed");
          },
          codeSent: (String verificationId, int? resendToken) {
            if (!mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => OtpPage(
                  phone: phoneE164,
                  verificationId: verificationId,
                  firstName: f,
                  lastName: l,
                  password: pw,
                ),
              ),
            );
          },
          codeAutoRetrievalTimeout: (String verificationId) {},
        );
      }
    } on FirebaseAuthException catch (e) {
      _toast(e.message ?? "Auth error");
    } catch (e) {
      _toast("Error: $e");
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundArt()),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, c) {
                final h = c.maxHeight;
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
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
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D3B63).withOpacity(0.55),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white.withOpacity(0.08)),
                                  ),
                                  child: const Icon(Icons.person_add_alt_1, color: Color(0xFF37A3FF)),
                                ),
                                const SizedBox(height: 14),
                                const Text(
                                  "Create Account",
                                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "Register to start driving",
                                  style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.65)),
                                ),
                                const SizedBox(height: 26),

                                const _Label("First Name"),
                                const SizedBox(height: 8),
                                _GlassField(
                                  controller: firstName,
                                  hint: "Enter first name",
                                  prefix: Icons.person_outline,
                                ),
                                const SizedBox(height: 16),

                                const _Label("Last Name"),
                                const SizedBox(height: 8),
                                _GlassField(
                                  controller: lastName,
                                  hint: "Enter last name",
                                  prefix: Icons.person_outline,
                                ),
                                const SizedBox(height: 16),

                                const _Label("Phone"),
                                const SizedBox(height: 8),
                                _GlassField(
                                  controller: phone,
                                  hint: "01X XXXX XXXX",
                                  prefix: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),

                                const _Label("Password"),
                                const SizedBox(height: 8),
                                _GlassField(
                                  controller: password,
                                  hint: "••••••••",
                                  prefix: Icons.lock_outline,
                                  obscureText: obscure,
                                  suffix: IconButton(
                                    onPressed: () => setState(() => obscure = !obscure),
                                    icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded),
                                    color: Colors.white.withOpacity(0.6),
                                  ),
                                ),

                                const SizedBox(height: 22),
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: ElevatedButton.icon(
                                    onPressed: loading ? null : _continueToOtp,
                                    icon: loading
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : const Icon(Icons.arrow_forward),
                                    label: Text(
                                      loading ? "Sending OTP..." : "Continue",
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2F95FF),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 18),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Already have an account? ",
                                      style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        "Login",
                                        style: TextStyle(
                                          color: Color(0xFF2F95FF),
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 10),
                              ],
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
  final TextEditingController controller;
  final String hint;
  final IconData prefix;
  final bool obscureText;
  final Widget? suffix;
  final TextInputType? keyboardType;

  const _GlassField({
    required this.controller,
    required this.hint,
    required this.prefix,
    this.obscureText = false,
    this.suffix,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        style: const TextStyle(fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
          prefixIcon: Icon(prefix, color: Colors.white.withOpacity(0.60)),
          suffixIcon: suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
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
    final rect = Offset.zero & size;

    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF0B1B2A), Color(0xFF081522), Color(0xFF050D16)],
      ).createShader(rect);
    canvas.drawRect(rect, bg);

    final glow = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.0, -0.55),
        radius: 1.1,
        colors: [Colors.white.withOpacity(0.05), Colors.transparent],
      ).createShader(rect);
    canvas.drawRect(rect, glow);

    final blobPaint = Paint()..color = const Color(0xFF2F95FF).withOpacity(0.92);

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

    final blobClip = Path()..addRect(Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.60));
    canvas.save();
    canvas.clipPath(blobClip);
    canvas.drawPath(path, blobPaint);
    canvas.restore();

    final shade = Paint()..color = const Color(0xFF07101A).withOpacity(0.25);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.18, size.width, size.height * 0.60), shade);

    final dashedPaint = Paint()
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

    final topHighlight = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.white.withOpacity(0.06), Colors.transparent],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.35));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.35), topHighlight);
  }

  void _drawDashedPath(Canvas canvas, Path path, Paint paint, {double dash = 8, double gap = 6}) {
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
