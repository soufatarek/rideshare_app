import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

import 'documents_page.dart';
import 'pending_page.dart';
import 'login_page.dart';

class OtpPage extends StatefulWidget {
  final String? verificationId;
  final String phone;
  final ConfirmationResult? confirmationResult;

  final String firstName;
  final String lastName;
  final String password;

  const OtpPage({
    super.key,
    this.verificationId,
    required this.phone,
    this.confirmationResult,
    required this.firstName,
    required this.lastName,
    required this.password,
  });

  @override
  State<OtpPage> createState() => _OtpPageState();
}

class _OtpPageState extends State<OtpPage> {
  final _code = TextEditingController();
  final _focus = FocusNode();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _code.dispose();
    _focus.dispose();
    super.dispose();
  }

  String _hashPassword(String uid, String pw) {
    return sha256.convert(utf8.encode("$uid:$pw")).toString();
  }

  Future<void> verify() async {
    final otp = _code.text.trim();

    if (otp.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter the 6-digit code")),
      );
      return;
    }

    setState(() => loading = true);
    try {
      debugPrint("OTP: Starting verification for $otp");
      UserCredential uc;

      try {
        if (widget.confirmationResult != null) {
          debugPrint("OTP: Web Flow - Confirming with confirmationResult");
          uc = await widget.confirmationResult!.confirm(otp);
        } else if (widget.verificationId != null) {
          debugPrint(
            "OTP: Mobile Flow - Confirming with verificationId: ${widget.verificationId}",
          );
          final cred = PhoneAuthProvider.credential(
            verificationId: widget.verificationId!,
            smsCode: otp,
          );
          uc = await FirebaseAuth.instance.signInWithCredential(cred);
        } else {
          throw Exception("Missing verificationId or confirmationResult");
        }
        debugPrint("OTP: Auth Success! UID: ${uc.user?.uid}");
      } on FirebaseAuthException catch (ae) {
        debugPrint("OTP: Auth Error Code: ${ae.code}, Message: ${ae.message}");
        throw Exception("Auth Failed (${ae.code}): ${ae.message}");
      }

      final user = uc.user;
      if (user == null) throw Exception("No user returned from Firebase Auth");

      final db = FirebaseFirestore.instance;
      final uid = user.uid;

      // 🛑 GUARD: Check if user already exists & has submitted documents
      final userDoc = await db.collection('drivers').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        final bool docsCompleted = data?['documentsCompleted'] ?? false;
        final String? status = data?['verification']?['status'];

        if (docsCompleted && status != 'rejected') {
          if (mounted) {
            String msg = "Application under review.";
            Widget page = const PendingPage();

            if (status == 'approved') {
              msg = "Account approved! Please log in.";
              page = const Login_page();
            } else if (status == 'submitted') {
              msg = "Application submitted. Please wait.";
            }

            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(msg)));
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => page),
              (r) => false,
            );
          }
          return;
        }
      }

      debugPrint("OTP: Starting Firestore Transaction for UID: $uid");
      try {
        await db.runTransaction((tx) async {
          final phoneRef = db
              .collection('driver_phone_index')
              .doc(widget.phone);
          final phoneSnap = await tx.get(phoneRef);

          if (!phoneSnap.exists) {
            tx.set(phoneRef, {'uid': uid});
          }

          tx.set(db.collection('drivers').doc(uid), {
            'firstName': widget.firstName,
            'lastName': widget.lastName,
            'phone': widget.phone,
            'passwordHash': _hashPassword(uid, widget.password),
            'approved': false,
            'documentsCompleted': false,
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        });
        debugPrint("OTP: Firestore Transaction Success!");
      } on FirebaseException catch (fe) {
        debugPrint(
          "OTP: Firestore Error Code: ${fe.code}, Message: ${fe.message}",
        );
        throw Exception("Firestore Failed (${fe.code}): ${fe.message}");
      }

      if (mounted) {
        debugPrint("OTP: Navigating to DocumentsPage");
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DocumentsPage()),
        );
      }
    } catch (e) {
      debugPrint("OTP: Final Catch Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Verification Error: $e"),
            duration: const Duration(seconds: 10),
            action: SnackBarAction(label: "OK", onPressed: () {}),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B0F14),
      body: Center(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.arrow_back),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.white.withOpacity(0.10)),
                    ),
                    child: const Icon(
                      Icons.lock,
                      size: 32,
                      color: Color(0xFF2F95FF),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    "Verification Code",
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Please enter the 6-digit code sent to\n${widget.phone}",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.65)),
                  ),
                  const SizedBox(height: 18),

                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                    ),
                    child: TextField(
                      controller: _code,
                      focusNode: _focus,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6),
                      ],
                      onSubmitted: (_) => verify(),
                      style: const TextStyle(
                        fontSize: 18,
                        letterSpacing: 8,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: "______",
                        hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.35),
                          letterSpacing: 8,
                          fontSize: 18,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: loading ? null : verify,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2F95FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: loading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              "Verify & Proceed",
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
