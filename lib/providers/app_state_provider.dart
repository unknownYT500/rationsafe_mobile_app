// ration_safe_mobile_app/lib/providers/app_state_provider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import '../data/repository.dart';
import '../data/supabase_service.dart';
import '../models/beneficiary.dart';
import '../models/grain_lot.dart';
import '../models/distribution_node.dart';
import '../models/registration.dart';
import '../models/audit_log.dart';

class AppStateProvider extends ChangeNotifier {
  final GrainTrustRepository _repo = GrainTrustRepository.instance;
  final SupabaseService _supabase = SupabaseService.instance;

  // Active Tab Index: 0: Dispense, 1: Registrations, 2: Edge Sync, 3: Inventory, 4: Audit Trail
  int _activeTabIndex = 0;
  int get activeTabIndex => _activeTabIndex;

  // Active Terminal / Node
  String _selectedNodeId = 'node-alpha-001';
  String get selectedNodeId => _selectedNodeId;

  // Online / Offline Simulation Toggle
  bool _isOnline = true;
  bool get isOnline => _isOnline;

  // Selected Role
  String _activeRole = 'DISTRIBUTION_OPERATOR';
  String get activeRole => _activeRole;

  // Data Collections
  List<CardBeneficiary> _cards = [];
  List<CardBeneficiary> get cards => _cards;

  String _selectedCardId = '';
  String get selectedCardId => _selectedCardId;

  List<GrainLotItem> _lots = [];
  List<GrainLotItem> get lots => _lots;

  String _distLotId = '';
  String get distLotId => _distLotId;

  List<NodeItem> _nodes = [];
  List<NodeItem> get nodes => _nodes;

  List<RegistrationItem> _registrations = [];
  List<RegistrationItem> get registrations => _registrations;

  List<AuditLogItem> _auditLogs = [];
  List<AuditLogItem> get auditLogs => _auditLogs;

  int _outboxDepth = 0;
  int get outboxDepth => _outboxDepth;

  // Dispense Form State
  double _distQuantity = 5.0;
  double get distQuantity => _distQuantity;

  bool _distAllowFallback = false;
  bool get distAllowFallback => _distAllowFallback;

  bool _distLoading = false;
  bool get distLoading => _distLoading;

  String _distCurrentState = 'ATTEMPT';
  String get distCurrentState => _distCurrentState;

  Map<String, dynamic>? _distExecutionSummary;
  Map<String, dynamic>? get distExecutionSummary => _distExecutionSummary;

  // Sync Form State
  bool _syncLoading = false;
  bool get syncLoading => _syncLoading;

  String? _syncNotice;
  String? get syncNotice => _syncNotice;

  // Registration Form State
  bool _regSubmitting = false;
  bool get regSubmitting => _regSubmitting;

  String? _regSuccessMsg;
  String? get regSuccessMsg => _regSuccessMsg;

  String? _regErrorMsg;
  String? get regErrorMsg => _regErrorMsg;

  Timer? _pollingTimer;

  AppStateProvider() {
    _init();
  }

  Future<void> _init() async {
    await _supabase.initialize();
    await loadAllData();

    // Setup Supabase Realtime channel
    _supabase.subscribeToUpdates(() {
      loadAllData();
    });

    // 5-second polling fallback
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      loadAllData();
    });
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // --- Load Data ---
  Future<void> loadAllData({String? preferredCardId}) async {
    try {
      final fetchedCards = await _repo.getCards(_selectedNodeId, isOnline: _isOnline);
      final fetchedLots = await _repo.getLots(isOnline: _isOnline);
      final fetchedNodes = await _repo.getNodes(isOnline: _isOnline);
      final fetchedRegs = await _repo.getRegistrations(isOnline: _isOnline);
      final fetchedAudit = await _repo.getAuditLogs(isOnline: _isOnline);
      final depth = await _repo.getOutboxDepth();

      _cards = fetchedCards;
      _lots = fetchedLots;
      _nodes = fetchedNodes;
      _registrations = fetchedRegs;
      _auditLogs = fetchedAudit;
      _outboxDepth = depth;

      // Card Selection Preservation
      if (preferredCardId != null && _cards.any((c) => c.id == preferredCardId)) {
        _selectedCardId = preferredCardId;
      } else if (_selectedCardId.isEmpty && _cards.isNotEmpty) {
        _selectedCardId = _cards.first.id;
      } else if (!_cards.any((c) => c.id == _selectedCardId) && _cards.isNotEmpty) {
        _selectedCardId = _cards.first.id;
      }

      // Lot Selection Preservation
      if (_distLotId.isEmpty && _lots.isNotEmpty) {
        _distLotId = _lots.first.id;
      } else if (!_lots.any((l) => l.id == _distLotId) && _lots.isNotEmpty) {
        _distLotId = _lots.first.id;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('[AppStateProvider] Error loading data: $e');
    }
  }

  // --- Navigation & Controls ---
  void setActiveTab(int index) {
    _activeTabIndex = index;
    notifyListeners();
  }

  void setSelectedNodeId(String nodeId) {
    _selectedNodeId = nodeId;
    loadAllData();
  }

  void toggleOnline() {
    _isOnline = !_isOnline;
    loadAllData();
  }

  void setActiveRole(String role) {
    _activeRole = role;
    notifyListeners();
  }

  void setSelectedCardId(String cardId) {
    _selectedCardId = cardId;
    notifyListeners();
  }

  void setDistLotId(String lotId) {
    _distLotId = lotId;
    notifyListeners();
  }

  void setDistQuantity(double qty) {
    if (qty >= 0.5 && qty <= 100.0) {
      _distQuantity = double.parse(qty.toStringAsFixed(1));
      notifyListeners();
    }
  }

  void setDistAllowFallback(bool val) {
    _distAllowFallback = val;
    notifyListeners();
  }

  // --- Actions ---

  /// Execute Grain Dispense (Online vs Offline)
  Future<void> executeDispense({String? cardId, String? lotId}) async {
    final effectiveCardId = (cardId != null && cardId.isNotEmpty)
        ? cardId
        : (_selectedCardId.isNotEmpty
            ? _selectedCardId
            : (_cards.isNotEmpty ? _cards.first.id : ''));

    final effectiveLotId = (lotId != null && lotId.isNotEmpty)
        ? lotId
        : (_distLotId.isNotEmpty
            ? _distLotId
            : (_lots.isNotEmpty ? _lots.first.id : ''));

    if (effectiveCardId.isEmpty || effectiveLotId.isEmpty) {
      debugPrint('[AppStateProvider] executeDispense failed: card ($effectiveCardId) or lot ($effectiveLotId) is empty');
      return;
    }

    _selectedCardId = effectiveCardId;
    _distLotId = effectiveLotId;

    _distLoading = true;
    _distCurrentState = 'ATTEMPT';
    _distExecutionSummary = null;
    notifyListeners();

    try {
      final res = await _repo.issueGrain(
        isOnline: _isOnline,
        cardId: effectiveCardId,
        lotId: effectiveLotId,
        nodeId: _selectedNodeId,
        quantity: _distQuantity,
        allowFallback: _distAllowFallback,
        actorId: _activeRole.toLowerCase(),
      );

      final isSuccess = res['success'] == true;
      _distCurrentState = isSuccess
          ? (_isOnline ? 'RECONCILED' : 'PROVISIONAL_ISSUE')
          : 'FAIL_REASON';

      _distExecutionSummary = res;
      await loadAllData();
    } catch (e) {
      _distCurrentState = 'FAIL_REASON';
      _distExecutionSummary = {
        'success': false,
        'code': 'ERR_500',
        'message': e.toString(),
      };
    } finally {
      _distLoading = false;
      notifyListeners();
    }
  }

  /// Trigger Batch Sync Now
  Future<void> triggerBatchSync() async {
    _syncLoading = true;
    _syncNotice = null;
    notifyListeners();

    try {
      final res = await _repo.triggerBatchSync(_selectedNodeId);
      final accepted = res['accepted'] ?? res['synced'] ?? 0;
      final dup = res['duplicate'] ?? 0;
      _syncNotice = 'Batch sync complete! Accepted: $accepted, Duplicates: $dup';
      await loadAllData();
    } catch (e) {
      _syncNotice = 'Sync failed: $e';
    } finally {
      _syncLoading = false;
      notifyListeners();
    }
  }

  /// Submit Citizen Registration
  Future<bool> submitRegistration(Map<String, dynamic> data) async {
    _regSubmitting = true;
    _regSuccessMsg = null;
    _regErrorMsg = null;
    notifyListeners();

    try {
      final res = await _repo.submitRegistration(data, _selectedNodeId);
      if (res['success'] == true) {
        _regSuccessMsg = 'Registration submitted successfully! Pending verification.';
        await loadAllData();
        return true;
      } else {
        _regErrorMsg = res['message'] ?? 'Registration failed.';
        return false;
      }
    } catch (e) {
      _regErrorMsg = e.toString();
      return false;
    } finally {
      _regSubmitting = false;
      notifyListeners();
    }
  }

  /// Verify Registration
  Future<void> verifyRegistration(String regId) async {
    await _repo.verifyRegistration(regId);
    await loadAllData();
  }

  /// Approve Registration & Issue Card
  Future<void> approveRegistration(String regId) async {
    final res = await _repo.approveRegistration(regId);
    if (res['success'] == true) {
      final newCardId = res['data']?['card']?['id'] ?? res['data']?['card_id'];
      await loadAllData(preferredCardId: newCardId?.toString());
      // Switch to Dispense tab
      _activeTabIndex = 0;
      notifyListeners();
    } else {
      _regErrorMsg = res['message'] ?? 'Failed to approve registration and issue card.';
      notifyListeners();
    }
  }

  /// Delete a single registration
  Future<void> deleteRegistration(String regId) async {
    await _repo.deleteRegistration(regId);
    await loadAllData();
  }

  /// Delete all unapproved registrations (cleanup duplicates)
  Future<void> clearUnapprovedRegistrations() async {
    await _repo.clearUnapprovedRegistrations();
    await loadAllData();
  }

  /// Reset Database
  Future<void> resetDatabase() async {
    await _repo.resetDatabase();
    await loadAllData();
  }
}
