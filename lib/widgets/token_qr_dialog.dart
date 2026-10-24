// ration_safe_mobile_app/lib/widgets/token_qr_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/provisional_token.dart';
import '../theme/app_theme.dart';
import 'glowing_badge.dart';

class TokenQrDialog extends StatelessWidget {
  final SignedProvisionalToken token;

  const TokenQrDialog({
    super.key,
    required this.token,
  });

  @override
  Widget build(BuildContext context) {
    final qrData = jsonEncode(token.toJson());

    return Dialog(
      backgroundColor: AppColors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderAccent, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'PROVISIONAL TOKEN QR',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.cyan400,
                  ),
                ),
                GlowingBadge(
                  label: 'SIGNED ED25519',
                  color: AppColors.amber500,
                  isGlowing: true,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200.0,
              ),
            ),
            const SizedBox(height: 16),
            _infoRow('Token ID', token.id),
            _infoRow('Txn ID', token.txnId),
            _infoRow('Quantity', '${token.payload.qty} kg'),
            _infoRow('Counter', '#${token.payload.c}'),
            _infoRow('Signature', '${token.signature.substring(0, 16)}...'),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan500,
                  foregroundColor: Colors.black,
                ),
                child: const Text('Close Receipt'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textDim, fontSize: 11)),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.textMain,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
