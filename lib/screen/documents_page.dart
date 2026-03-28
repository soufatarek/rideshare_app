import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'pending_page.dart';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class DocumentsPage extends StatefulWidget {
  const DocumentsPage({super.key});

  @override
  State<DocumentsPage> createState() => _DocumentsPageState();
}

enum DocStatus { required, picked, uploading, uploaded, rejected }

class DocItem {
  final String id; // driver_license, national_id, vehicle_insurance
  final IconData icon;
  final String title;
  final String hint;

  DocStatus status;

  XFile? pickedFile; // ✅ memory only
  String? uploadedUrl; // ✅ from storage
  String? uploadedPath; // ✅ for future delete/replace
  String? rejectReason; // ✅ server/admin

  DocItem({
    required this.id,
    required this.icon,
    required this.title,
    required this.hint,
    this.status = DocStatus.required,
    this.pickedFile,
    this.uploadedUrl,
    this.uploadedPath,
    this.rejectReason,
  });

  bool get hasPicked => pickedFile != null;
  bool get isUploaded => status == DocStatus.uploaded && uploadedUrl != null;
}

class _DocumentsPageState extends State<DocumentsPage> {
  final ImagePicker _picker = ImagePicker();
  bool submitting = false;

  late final DocItem driverLicense = DocItem(
    id: "driver_license",
    icon: Icons.credit_card,
    title: "Driver's License",
    hint: "Front and back of your valid license.",
  );

  late final DocItem nationalId = DocItem(
    id: "national_id",
    icon: Icons.badge_outlined,
    title: "National ID",
    hint: "Upload your ID photo.",
  );

  late final DocItem insurance = DocItem(
    id: "vehicle_insurance",
    icon: Icons.shield_outlined,
    title: "Vehicle Insurance",
    hint: "Upload your insurance document.",
  );

  List<DocItem> get docs => [driverLicense, nationalId, insurance];

  // =========================
  // Pick / View / Remove
  // =========================

  Future<void> pickDoc(DocItem doc) async {
    final XFile? f = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (f == null) return;

    setState(() {
      doc.pickedFile = f;
      doc.status = DocStatus.picked;
      doc.rejectReason = null;
    });
  }

  void removePicked(DocItem doc) {
    setState(() {
      doc.pickedFile = null;
      doc.status = DocStatus.required;
      doc.rejectReason = null;
    });
  }

  void viewDoc(DocItem doc) {
    if (doc.pickedFile == null) return;
    showDialog(
      context: context,
      builder: (_) => _PreviewDialog(title: doc.title, file: doc.pickedFile!),
    );
  }

  // =========================
  // Submit / Upload to Firebase
  // =========================

  bool get canSubmit {
    return docs.every(
      (d) => d.status == DocStatus.picked || d.status == DocStatus.uploaded,
    );
  }

  Future<void> submitAll() async {
    if (!canSubmit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please upload all required documents first."),
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Not logged in.")));
      return;
    }

    setState(() => submitting = true);

    try {
      // 1) Parallel upload of all picked docs
      final uploadTasks = docs
          .where((doc) => doc.pickedFile != null)
          .map((doc) => _uploadOneSafely(doc, user.uid));

      final results = await Future.wait(uploadTasks);
      final errors = results.whereType<String>().toList();

      if (errors.isNotEmpty) {
        throw errors.join("\n");
      }

      // 2) build docs map for users/{uid}
      final docsMap = <String, dynamic>{};
      for (final d in docs) {
        docsMap[d.id] = {
          "status": d.status.name,
          "url": d.uploadedUrl,
          "path": d.uploadedPath,
          "updatedAt": FieldValue.serverTimestamp(),
        };
      }

      // 3) update user main doc
      await FirebaseFirestore.instance.collection("drivers").doc(user.uid).set({
        "documentsCompleted": true,
        "docs": docsMap,
        "verification": {
          "submittedAt": FieldValue.serverTimestamp(),
          "status": "submitted",
        },
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Uploaded successfully ✅")));
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const PendingPage()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Upload failed:\n$e"),
          duration: const Duration(seconds: 4),
        ),
      );
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  Future<String?> _uploadOneSafely(DocItem doc, String uid) async {
    try {
      await _uploadOne(doc: doc, uid: uid);
      return null;
    } catch (e) {
      return "${doc.title}: $e";
    }
  }

  Future<void> _uploadOne({required DocItem doc, required String uid}) async {
    final file = doc.pickedFile;
    if (file == null) return;

    setState(() => doc.status = DocStatus.uploading);

    final ext = _safeExt(file.name);
    final filename = "${DateTime.now().millisecondsSinceEpoch}.$ext";
    final storagePath = "drivers/$uid/verification/${doc.id}/$filename";

    final ref = FirebaseStorage.instance.ref(storagePath);

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await ref.putData(
        bytes,
        SettableMetadata(contentType: _contentTypeFromExt(ext)),
      );
    } else {
      await ref.putFile(File(file.path));
    }

    final url = await ref.getDownloadURL();

    // Save Firestore metadata
    await FirebaseFirestore.instance
        .collection("drivers")
        .doc(uid)
        .collection("documents")
        .doc(doc.id)
        .set({
          "docId": doc.id,
          "title": doc.title,
          "status": "uploaded",
          "url": url,
          "path": storagePath,
          "updatedAt": FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

    setState(() {
      doc.uploadedUrl = url;
      doc.uploadedPath = storagePath;
      doc.pickedFile = null;
      doc.status = DocStatus.uploaded;
      doc.rejectReason = null;
    });
  }

  String _safeExt(String name) {
    final parts = name.split(".");
    if (parts.length < 2) return "jpg";
    final e = parts.last.toLowerCase();
    if (e == "jpeg") return "jpg";
    if (e == "png" || e == "jpg" || e == "webp") return e;
    return "jpg";
  }

  String _contentTypeFromExt(String ext) {
    switch (ext) {
      case "png":
        return "image/png";
      case "webp":
        return "image/webp";
      case "jpg":
      default:
        return "image/jpeg";
    }
  }

  // UI
  @override
  Widget build(BuildContext context) {
    final bg = const Color(0xFF0B1220);
    final panel = const Color(0xFF101A2C);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 8),
                    const Text(
                      "Upload Documents",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Please ensure all photos are clear and details are readable. We need these to verify your identity.",
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.3,
                        color: Colors.white.withOpacity(0.65),
                      ),
                    ),
                    const SizedBox(height: 18),

                    _DocCardDynamic(
                      doc: driverLicense,
                      onPick: () => pickDoc(driverLicense),
                      onView: () => viewDoc(driverLicense),
                      onRemove: () => removePicked(driverLicense),
                    ),

                    const SizedBox(height: 14),

                    _DocCardDynamic(
                      doc: nationalId,
                      onPick: () => pickDoc(nationalId),
                      onView: () => viewDoc(nationalId),
                      onRemove: () => removePicked(nationalId),
                    ),

                    const SizedBox(height: 14),

                    _DocCardDynamic(
                      doc: insurance,
                      onPick: () => pickDoc(insurance),
                      onView: () => viewDoc(insurance),
                      onRemove: () => removePicked(insurance),
                    ),

                    const SizedBox(height: 16),

                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: panel,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              Icons.info_outline,
                              color: Colors.white.withOpacity(0.85),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Why do we need this?",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  "We use these documents to run a background\ncheck and ensure the safety of our community.\nYour data is encrypted and secure.",
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.65),
                                    height: 1.35,
                                    fontSize: 12.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF0A1220),
                border: Border(
                  top: BorderSide(color: Colors.white.withOpacity(0.08)),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _BottomButton(
                      text: "Back",
                      filled: false,
                      onTap: () => Navigator.pop(context),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _BottomButton(
                      text: submitting ? "Uploading..." : "submit",
                      filled: true,
                      trailing: submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.arrow_forward, size: 18),
                      onTap: submitting ? () {} : submitAll,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================
// Dynamic Card Widget
// =========================

class _DocCardDynamic extends StatelessWidget {
  final DocItem doc;
  final VoidCallback onPick;
  final VoidCallback onView;
  final VoidCallback onRemove;

  const _DocCardDynamic({
    required this.doc,
    required this.onPick,
    required this.onView,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final panel = const Color(0xFF101A2C);

    final badge = _badgeFromStatus(doc.status);
    final badgeText = badge.$1;
    final badgeBg = badge.$2;
    final badgeFg = badge.$3;

    final subtitle = doc.isUploaded
        ? "Uploaded"
        : (doc.pickedFile != null ? doc.pickedFile!.name : doc.hint);

    final showActions =
        doc.status == DocStatus.picked || doc.status == DocStatus.uploaded;
    final showFooterTap =
        doc.status == DocStatus.required || doc.status == DocStatus.picked;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            spreadRadius: 0,
            color: Colors.black.withOpacity(0.25),
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: doc.status == DocStatus.rejected
                      ? const Color(0x33FF4D4D)
                      : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  doc.status == DocStatus.rejected
                      ? Icons.warning_amber_rounded
                      : doc.icon,
                  color: doc.status == DocStatus.rejected
                      ? const Color(0xFFFF5A5A)
                      : Colors.white.withOpacity(0.85),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      doc.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      doc.status == DocStatus.rejected &&
                              doc.rejectReason != null
                          ? doc.rejectReason!
                          : subtitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.60),
                        fontSize: 12.6,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeFg,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),

          if (showActions) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  _SmallLink(
                    text: "View",
                    onTap: doc.pickedFile != null ? onView : () {},
                  ),
                  const SizedBox(width: 12),
                  _SmallLink(text: "Remove", danger: true, onTap: onRemove),
                ],
              ),
            ),
          ],

          if (showFooterTap) ...[
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onPick,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.06)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.upload_file,
                      color: Colors.white.withOpacity(0.75),
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      doc.status == DocStatus.picked
                          ? "Selected (ready)"
                          : "Tap to upload",
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  (String, Color, Color) _badgeFromStatus(DocStatus s) {
    switch (s) {
      case DocStatus.uploaded:
        return ("Uploaded", const Color(0x3322C55E), const Color(0xFF31E07B));
      case DocStatus.rejected:
        return ("Rejected", const Color(0x33FF4D4D), const Color(0xFFFF5A5A));
      case DocStatus.uploading:
        return (
          "Uploading",
          const Color(0x1AFFFFFF),
          Colors.white.withOpacity(0.80),
        );
      case DocStatus.picked:
        return (
          "Ready",
          const Color(0x1AFFFFFF),
          Colors.white.withOpacity(0.85),
        );
      case DocStatus.required:
      default:
        return (
          "Required",
          const Color(0x14FFFFFF),
          Colors.white.withOpacity(0.75),
        );
    }
  }
}

// =========================
// Preview Dialog
// =========================

class _PreviewDialog extends StatelessWidget {
  final String title;
  final XFile file;

  const _PreviewDialog({required this.title, required this.file});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF101A2C),
      insetPadding: const EdgeInsets.all(16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Colors.white.withOpacity(0.8)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _XFileImage(file: file),
            ),
          ],
        ),
      ),
    );
  }
}

class _XFileImage extends StatelessWidget {
  final XFile file;
  const _XFileImage({required this.file});

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return FutureBuilder(
        future: file.readAsBytes(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const SizedBox(
              height: 240,
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return Image.memory(
            snapshot.data as Uint8List,
            fit: BoxFit.cover,
            height: 260,
            width: double.infinity,
          );
        },
      );
    } else {
      return Image.file(
        File(file.path),
        fit: BoxFit.cover,
        height: 260,
        width: double.infinity,
      );
    }
  }
}

// =========================
// Small UI Widgets
// =========================

class _SmallLink extends StatelessWidget {
  final String text;
  final bool danger;
  final VoidCallback onTap;

  const _SmallLink({
    required this.text,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Text(
          text,
          style: TextStyle(
            color: danger
                ? const Color(0xFFFF5A5A)
                : Colors.white.withOpacity(0.75),
            fontWeight: FontWeight.w800,
            fontSize: 12.5,
          ),
        ),
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final String text;
  final bool filled;
  final Widget? trailing;
  final VoidCallback onTap;

  const _BottomButton({
    required this.text,
    required this.filled,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: filled ? Colors.white.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              text,
              style: TextStyle(
                color: Colors.white.withOpacity(0.90),
                fontWeight: FontWeight.w900,
                fontSize: 14,
                letterSpacing: 0.2,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              IconTheme(
                data: IconThemeData(color: Colors.white.withOpacity(0.90)),
                child: trailing!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
