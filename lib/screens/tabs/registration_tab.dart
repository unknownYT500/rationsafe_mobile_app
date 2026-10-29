// ration_safe_mobile_app/lib/screens/tabs/registration_tab.dart
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/app_state_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/cyber_card.dart';
import '../../widgets/glowing_badge.dart';

class RegistrationTab extends StatefulWidget {
  const RegistrationTab({super.key});

  @override
  State<RegistrationTab> createState() => _RegistrationTabState();
}

class _RegistrationTabState extends State<RegistrationTab> {
  final _formKey = GlobalKey<FormState>();

  final _firstNameCtrl = TextEditingController(text: 'Ramesh');
  final _lastNameCtrl = TextEditingController(text: 'Sharma');
  late final TextEditingController _phoneCtrl;
  final _dobCtrl = TextEditingController(text: '1988-06-15');
  final _familyCountCtrl = TextEditingController(text: '4');
  final _incomeCtrl = TextEditingController(text: '48000');
  final _addressCtrl = TextEditingController(text: 'Plot 42, Kalyanpur Village');
  final _cityCtrl = TextEditingController(text: 'Kanpur');
  final _stateCtrl = TextEditingController(text: 'Uttar Pradesh');
  bool _consent = true;

  @override
  void initState() {
    super.initState();
    final randomPhone = '98${Random().nextInt(89999999) + 10000000}';
    _phoneCtrl = TextEditingController(text: randomPhone);
  }

  static final List<Map<String, dynamic>> _sampleCitizens = [
    {
      'first_name': 'Ramesh',
      'last_name': 'Sharma',
      'phone_number': '9876543210',
      'dob': '1988-06-15',
      'family_count': '4',
      'yearly_income': '48000',
      'address': 'Plot 42, Kalyanpur Village',
      'city': 'Kanpur',
      'state': 'Uttar Pradesh',
    },
    {
      'first_name': 'Sunita',
      'last_name': 'Devi',
      'phone_number': '9812345678',
      'dob': '1992-04-10',
      'family_count': '5',
      'yearly_income': '36000',
      'address': 'House 14, Ward 6, Bithoor Block',
      'city': 'Bithoor',
      'state': 'Uttar Pradesh',
    },
    {
      'first_name': 'Vikram',
      'last_name': 'Singh',
      'phone_number': '9945678123',
      'dob': '1985-11-22',
      'family_count': '3',
      'yearly_income': '52000',
      'address': 'Sector 8, Subhash Nagar',
      'city': 'Kanpur',
      'state': 'Uttar Pradesh',
    },
    {
      'first_name': 'Fatima',
      'last_name': 'Bano',
      'phone_number': '9723456789',
      'dob': '1995-09-05',
      'family_count': '6',
      'yearly_income': '42000',
      'address': 'Gali 3, Old Bazar',
      'city': 'Kanpur',
      'state': 'Uttar Pradesh',
    },
  ];

  void _fillSampleCitizen() {
    final rand = _sampleCitizens[Random().nextInt(_sampleCitizens.length)];
    // Add random suffix to phone number so each generation is unique
    final randomPhone = '98${Random().nextInt(89999999) + 10000000}';

    setState(() {
      _firstNameCtrl.text = rand['first_name'];
      _lastNameCtrl.text = rand['last_name'];
      _phoneCtrl.text = randomPhone;
      _dobCtrl.text = rand['dob'];
      _familyCountCtrl.text = rand['family_count'];
      _incomeCtrl.text = rand['yearly_income'];
      _addressCtrl.text = rand['address'];
      _cityCtrl.text = rand['city'];
      _stateCtrl.text = rand['state'];
      _consent = true;
    });
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _dobCtrl.dispose();
    _familyCountCtrl.dispose();
    _incomeCtrl.dispose();
    _addressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppStateProvider>();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Enrollment Form Card
          CyberCard(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'CITIZEN RATION ENROLLMENT',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                          color: AppColors.cyan400,
                        ),
                      ),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.auto_awesome, size: 14, color: AppColors.amber400),
                        label: const Text('Sample Citizen', style: TextStyle(fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.amber400),
                          foregroundColor: AppColors.amber400,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        ),
                        onPressed: _fillSampleCitizen,
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Name Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _firstNameCtrl,
                          decoration: const InputDecoration(labelText: 'First Name'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _lastNameCtrl,
                          decoration: const InputDecoration(labelText: 'Last Name'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Phone & DOB Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Phone Number (10 digits)'),
                          validator: (v) => (v == null || v.length < 10) ? 'Valid phone required' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _dobCtrl,
                          decoration: const InputDecoration(labelText: 'DOB (YYYY-MM-DD)'),
                          validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Family Count & Annual Income Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _familyCountCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Family Members (1-20)'),
                          validator: (v) => (v == null || int.tryParse(v) == null) ? 'Invalid' : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _incomeCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Annual Income (₹)'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Address
                  TextFormField(
                    controller: _addressCtrl,
                    decoration: const InputDecoration(labelText: 'Residential Address'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),

                  // City & State Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _cityCtrl,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextFormField(
                          controller: _stateCtrl,
                          decoration: const InputDecoration(labelText: 'State'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Consent Checkbox
                  Row(
                    children: [
                      Checkbox(
                        value: _consent,
                        activeColor: AppColors.cyan400,
                        onChanged: (v) => setState(() => _consent = v ?? true),
                      ),
                      const Expanded(
                        child: Text(
                          'Beneficiary grants consent for biometric and quota verification.',
                          style: TextStyle(color: AppColors.textMuted, fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cyan500,
                        foregroundColor: Colors.black,
                      ),
                      onPressed: state.regSubmitting
                          ? null
                          : () async {
                              if (_formKey.currentState?.validate() ?? false) {
                                final data = {
                                  'first_name': _firstNameCtrl.text.trim(),
                                  'last_name': _lastNameCtrl.text.trim(),
                                  'phone_number': _phoneCtrl.text.trim(),
                                  'dob': _dobCtrl.text.trim(),
                                  'family_count': int.tryParse(_familyCountCtrl.text) ?? 4,
                                  'yearly_income': double.tryParse(_incomeCtrl.text) ?? 50000.0,
                                  'address': _addressCtrl.text.trim(),
                                  'city': _cityCtrl.text.trim(),
                                  'state': _stateCtrl.text.trim(),
                                  'consent_opt_in': _consent,
                                };
                                await state.submitRegistration(data);
                              }
                            },
                      child: state.regSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : const Text('Submit Application', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),

                  // Feedback messages
                  if (state.regSuccessMsg != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.emerald500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(state.regSuccessMsg!, style: const TextStyle(color: AppColors.emerald400, fontSize: 12)),
                    ),
                  ],
                  if (state.regErrorMsg != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.rose500.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(state.regErrorMsg!, style: const TextStyle(color: AppColors.rose400, fontSize: 12)),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // 2. Existing Registrations Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REGISTRATIONS (${state.registrations.length})',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  color: AppColors.textDim,
                ),
              ),
              if (state.registrations.any((r) => r.status != 'APPROVED'))
                InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AppColors.bgSecondary,
                        title: const Text('Clear Unapproved Registrations?'),
                        content: const Text(
                          'This will remove all pending, unverified, and duplicate registration drafts. Approved cards will not be affected.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.rose500),
                            onPressed: () {
                              Navigator.pop(ctx);
                              state.clearUnapprovedRegistrations();
                            },
                            child: const Text('Delete Drafts'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Row(
                    children: const [
                      Icon(Icons.delete_sweep_outlined, size: 16, color: AppColors.rose400),
                      SizedBox(width: 4),
                      Text(
                        'Clear Drafts',
                        style: TextStyle(color: AppColors.rose400, fontSize: 11, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),

          if (state.registrations.isEmpty)
            CyberCard(
              child: const Center(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text(
                    'No registrations recorded yet. Submit the form above to add an applicant.',
                    style: TextStyle(color: AppColors.textMuted, fontSize: 12),
                  ),
                ),
              ),
            )
          else
            ...state.registrations.map((reg) {
              Color statusColor;
              switch (reg.status) {
                case 'APPROVED':
                  statusColor = AppColors.emerald400;
                  break;
                case 'VERIFIED':
                  statusColor = AppColors.cyan400;
                  break;
                default:
                  statusColor = AppColors.amber400;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: CyberCard(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            reg.data.fullName,
                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                          ),
                          GlowingBadge(
                            label: reg.status,
                            color: statusColor,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${reg.data.phoneNumber} · Family: ${reg.data.familyCount} · Implied Quota: ${reg.data.familyCount * 10} kg',
                        style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
                      ),
                      Text(
                        '${reg.data.address}, ${reg.data.city}',
                        style: const TextStyle(color: AppColors.textDim, fontSize: 11),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (reg.status != 'APPROVED')
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.rose400),
                              tooltip: 'Delete Draft',
                              visualDensity: VisualDensity.compact,
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => state.deleteRegistration(reg.id),
                            )
                          else
                            const SizedBox.shrink(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          if (reg.status == 'SUBMITTED')
                            OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.cyan400),
                                foregroundColor: AppColors.cyan400,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              ),
                              onPressed: () => state.verifyRegistration(reg.id),
                              child: const Text('Verify Citizen', style: TextStyle(fontSize: 11)),
                            ),
                          if (reg.status == 'SUBMITTED' || reg.status == 'VERIFIED') ...[
                            const SizedBox(width: 8),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.emerald500,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () => state.approveRegistration(reg.id),
                              child: const Text('Approve & Issue Card', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                            ),
                          ],
                          if (reg.status == 'APPROVED')
                            ElevatedButton.icon(
                              icon: const Icon(Icons.arrow_forward_rounded, size: 14, color: Colors.black),
                              label: const Text('Dispense to Card', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.cyan400,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              ),
                              onPressed: () {
                                if (reg.cardId != null) {
                                  state.setSelectedCardId(reg.cardId!);
                                }
                                state.setActiveTab(0); // Switch to Dispense Tab
                              },
                            ),
                        ],
                      ),
                    ],
                  ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }
}
