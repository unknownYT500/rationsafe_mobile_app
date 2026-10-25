// mobile/lib/widgets/dynamic_ephemeral_qr_dialog.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/beneficiary.dart';
import '../crypto/ephemeral_qr.dart';
import '../theme/app_theme.dart';
import 'glowing_badge.dart';

/// Interactive UI Dialog displaying a Dynamic Ephemeral QR code with a 180-second TTL countdown ring.
/// Prevents photo duplication, screenshot borrowing, and replay fraud.
class DynamicEphemeralQrDialog extends StatefulWidget {
  final CardBeneficiary card;

  const DynamicEphemeralQrDialog({
    super.key,
    required this.card,
  });

  @override
  State<DynamicEphemeralQrDialog> createState() => _DynamicEphemeralQrDialogState();
}

class _DynamicEphemeralQrDialogState extends State<DynamicEphemeralQrDialog> {
  EphemeralQrPayload? _payload;
  int _secondsRemaining = 180;
  Timer? _countdownTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generateFreshToken();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _generateFreshToken() async {
    setState(() => _isLoading = true);
    _countdownTimer?.cancel();

    final token = await EphemeralQrService.generateToken(widget.card, ttlSeconds: 180);
    setState(() {
      _payload = token;
      _secondsRemaining = 180;
      _isLoading = false;
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      final remaining = _payload != null ? EphemeralQrService.getRemainingSeconds(_payload!) : 0;
      if (remaining <= 0) {
        timer.cancel();
        _generateFreshToken(); // Automatically refresh on expiration
      } else {
        setState(() {
          _secondsRemaining = remaining;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _payload != null ? jsonEncode(_payload!.toJson()) : '';
    final progress = _secondsRemaining / 180.0;

    return Dialog(
      backgroundColor: AppColors.bgSecondary,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cyan500, width: 1.5),
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
                  'DYNAMIC EPHEMERAL QR',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: AppColors.cyan400,
                  ),
                ),
                GlowingBadge(
                  label: '180s ANTI-REPLAY',
                  color: AppColors.emerald500,
                  isGlowing: true,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // QR Code or Loader
            if (_isLoading || _payload == null)
              Container(
                width: 220,
                height: 220,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const CircularProgressIndicator(color: AppColors.cyan500),
              )
            else
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

            // Live TTL Countdown Ring & Text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.bgPrimary,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _secondsRemaining < 30 ? AppColors.rose500 : AppColors.borderSubtle,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 2.5,
                      backgroundColor: AppColors.borderSubtle,
                      color: _secondsRemaining < 30 ? AppColors.rose500 : AppColors.cyan400,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Expires in: $_secondsRemaining seconds',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _secondsRemaining < 30 ? AppColors.rose500 : AppColors.textMain,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),
            _infoRow('Beneficiary', widget.card.fullName),
            _infoRow('Card ID', '${widget.card.id.substring(0, 13)}...'),
            if (_payload != null) ...[
              _infoRow('Nonce', '${_payload!.nonce.substring(0, 8)}...'),
              _infoRow('Auth Scheme', 'HMAC-SHA256 (PDSv1)'),
            ],

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _generateFreshToken,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh Token'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.cyan400,
                      side: const BorderSide(color: AppColors.cyan500),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.cyan500,
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Dismiss'),
                  ),
                ),
              ],
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
