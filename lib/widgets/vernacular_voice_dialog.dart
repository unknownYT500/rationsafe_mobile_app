// mobile/lib/widgets/vernacular_voice_dialog.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/beneficiary.dart';
import '../ai/vernacular_engine.dart';

class VernacularVoiceDialog extends StatefulWidget {
  final CardBeneficiary? activeCard;

  const VernacularVoiceDialog({super.key, this.activeCard});

  @override
  State<VernacularVoiceDialog> createState() => _VernacularVoiceDialogState();
}

class _VernacularVoiceDialogState extends State<VernacularVoiceDialog> with SingleTickerProviderStateMixin {
  String _selectedLanguage = 'hi';
  bool _isListening = false;
  String _transcript = '';
  VernacularIntent? _detectedIntent;
  String? _synthesizedResponse;
  GrievanceRecord? _createdGrievance;

  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _handleUtterance(String utterance) async {
    setState(() {
      _transcript = utterance;
      _isListening = false;
      _detectedIntent = VernacularEngine.parseUtterance(utterance, languageHint: _selectedLanguage);
      _synthesizedResponse = VernacularEngine.synthesizeResponse(
        intent: _detectedIntent!,
        card: widget.activeCard,
        languageOverride: _selectedLanguage,
      );
      _createdGrievance = null;
    });

    // If intent is grievance registration, save it offline immediately
    if (_detectedIntent!.type == VernacularIntentType.fileGrievance && widget.activeCard != null) {
      final grv = await VernacularEngine.registerOfflineGrievance(
        card: widget.activeCard!,
        category: _detectedIntent!.grievanceCategory ?? GrievanceCategory.general,
        rawTranscript: utterance,
        language: _selectedLanguage,
      );
      setState(() {
        _createdGrievance = grv;
      });
    }
  }

  void _toggleListening() {
    setState(() {
      _isListening = !_isListening;
      if (_isListening) {
        _transcript = 'Listening for speech input...';
        _detectedIntent = null;
        _synthesizedResponse = null;
        _createdGrievance = null;
      }
    });

    if (_isListening) {
      // Simulate real-time speech-to-text recognition after 1.5 seconds
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted && _isListening) {
          String sampleUtterance = 'Mera kitna chawal bacha hai?';
          if (_selectedLanguage == 'te') sampleUtterance = 'Naaku inka entha biyyam undi?';
          if (_selectedLanguage == 'bho') sampleUtterance = 'हमरा कार्ड पर कितना अनाज बाकी बा?';
          if (_selectedLanguage == 'en') sampleUtterance = 'How much rice is left for this month?';
          _handleUtterance(sampleUtterance);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cyan500, width: 1.5),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header with AI Badge
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.record_voice_over, color: AppColors.cyan400, size: 22),
                      const SizedBox(width: 8),
                      const Text(
                        'Vernacular Assistant',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textMain,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.cyan400.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cyan400, width: 0.8),
                    ),
                    child: const Text(
                      '242 Dialects / Offline',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: AppColors.cyan400,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Language Selector Dropdown
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderSubtle),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedLanguage,
                    isExpanded: true,
                    dropdownColor: AppColors.bgSecondary,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.cyan400),
                    items: VernacularEngine.supportedLanguages.entries.map((entry) {
                      return DropdownMenuItem<String>(
                        value: entry.key,
                        child: Text(
                          entry.value,
                          style: const TextStyle(fontSize: 13, color: AppColors.textMain),
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedLanguage = val);
                        if (_transcript.isNotEmpty && _detectedIntent != null) {
                          _handleUtterance(_transcript);
                        }
                      }
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Central Voice Microphone Button with Pulse Animation
              Center(
                child: GestureDetector(
                  onTap: _toggleListening,
                  child: AnimatedBuilder(
                    animation: _scaleAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isListening ? _scaleAnimation.value : 1.0,
                        child: Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _isListening ? AppColors.rose500 : AppColors.cyan500,
                            boxShadow: [
                              BoxShadow(
                                color: (_isListening ? AppColors.rose500 : AppColors.cyan500).withValues(alpha: 0.4),
                                blurRadius: _isListening ? 16 : 8,
                                spreadRadius: _isListening ? 4 : 1,
                              ),
                            ],
                          ),
                          child: Icon(
                            _isListening ? Icons.mic : Icons.mic_none,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _isListening ? 'Listening in real time...' : 'Tap microphone to speak in regional dialect',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _isListening ? AppColors.rose400 : AppColors.textDim,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Quick Preset Chips for Low-Literacy Operators
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _quickChip('Quota Balance', 'Mera kitna chawal bacha hai?'),
                  _quickChip('Schedule', 'Is mahine ration kab aayega?'),
                  _quickChip('Family Count', 'Mere card par kitne member hain?'),
                  _quickChip('File Grievance', 'Dukaandar ne 2 kilo kam diya'),
                ],
              ),
              const SizedBox(height: 14),

              // Transcript Display Box
              if (_transcript.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.bgSecondary,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.borderSubtle),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Citizen Spoken Input:',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDim),
                          ),
                          if (_detectedIntent != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.emerald500.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${_detectedIntent!.type.name} (${(_detectedIntent!.confidence * 100).toInt()}%)',
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.emerald400),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _transcript,
                        style: const TextStyle(fontSize: 13, color: AppColors.textMain, fontStyle: FontStyle.italic),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Synthesized Conversational Response Bubble
              if (_synthesizedResponse != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.cyan500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.cyan500.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.volume_up, color: AppColors.cyan400, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _synthesizedResponse!,
                          style: const TextStyle(fontSize: 13, color: AppColors.textMain, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Grievance Ticket Confirmation Banner
              if (_createdGrievance != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.amber500.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.amber500),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: AppColors.amber400, size: 18),
                          const SizedBox(width: 6),
                          const Text(
                            'Offline Grievance Registered',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.amber400),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Ticket: ${_createdGrievance!.id}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textMain, fontFamily: 'monospace'),
                      ),
                      Text(
                        'Category: ${_createdGrievance!.category.name.toUpperCase()} (Queued for central audit)',
                        style: const TextStyle(fontSize: 11, color: AppColors.textDim),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Dismiss / Close Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.cyan500,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Close Assistant', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickChip(String label, String utterance) {
    return ActionChip(
      label: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textMain)),
      backgroundColor: AppColors.bgSecondary,
      side: const BorderSide(color: AppColors.borderSubtle),
      onPressed: () => _handleUtterance(utterance),
    );
  }
}
