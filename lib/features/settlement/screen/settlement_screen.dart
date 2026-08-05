import 'package:flutter/material.dart';

import '../../../core/widget/app_design.dart';
import '../model/settlement_models.dart';
import '../service/settlement_service.dart';
import '../widget/settlement_balance_card.dart';
import '../widget/settlement_explanation_sheet.dart';
import '../widget/settlement_my_summary_card.dart';
import '../widget/settlement_status_summary.dart';
import '../widget/settlement_transfer_card.dart';

enum _SettlementTab {
  overview('전체 현황'),
  sent('송금'),
  received('수금');

  final String label;

  const _SettlementTab(this.label);
}

class SettlementScreen extends StatefulWidget {
  final int tripId;
  final String tripTitle;
  final bool isOwner;
  final int currentParticipantId;
  final String tripSettlementStatus;
  final bool showMockCases;
  final SettlementService? settlementService;

  const SettlementScreen({
    super.key,
    required this.tripId,
    required this.tripTitle,
    required this.isOwner,
    required this.currentParticipantId,
    this.tripSettlementStatus = 'NOT_STARTED',
    this.showMockCases = false,
    this.settlementService,
  });

  @override
  State<SettlementScreen> createState() => _SettlementScreenState();
}

class _SettlementScreenState extends State<SettlementScreen> {
  late final SettlementService _settlementService;

  SettlementOverview? _overview;
  _SettlementTab _selectedTab = _SettlementTab.overview;
  late SettlementMockCase _selectedMockCase;
  bool _isLoading = true;
  bool _isBusy = false;
  bool _changed = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _settlementService = widget.settlementService ?? SettlementService();
    _selectedMockCase = widget.isOwner
        ? SettlementMockCase.ownerNotStarted
        : SettlementMockCase.memberNeedsToReceive;
    _loadOverview();
  }

  Future<void> _loadOverview({bool reset = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final overview = await _settlementService.getOverview(
        tripId: widget.tripId,
        tripTitle: widget.tripTitle,
        isOwner: widget.isOwner,
        currentParticipantId: widget.currentParticipantId,
        tripSettlementStatus: widget.tripSettlementStatus,
        mockCase: _selectedMockCase,
        reset: reset,
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _selectedTab = _recommendedTab(overview);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = '정산 정보를 불러오지 못했습니다: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _selectMockCase(SettlementMockCase mockCase) async {
    if (_selectedMockCase == mockCase) return;
    setState(() {
      _selectedMockCase = mockCase;
      _selectedTab = _SettlementTab.overview;
    });
    await _loadOverview(reset: true);
  }

  Future<void> _runAction(
    Future<SettlementOverview> Function() action, {
    String? message,
  }) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _errorMessage = null;
    });

    try {
      final previousStage = _overview?.stage;
      final overview = await action();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        if (previousStage != SettlementStage.confirmed &&
            overview.stage == SettlementStage.confirmed) {
          _selectedTab = _recommendedTab(overview);
        }
        _changed = true;
      });
      if (message != null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('정산 처리에 실패했습니다: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _handlePrimaryAction() async {
    final overview = _overview;
    if (overview == null) return;

    switch (overview.stage) {
      case SettlementStage.notStarted:
        await _runAction(
          _settlementService.previewSettlement,
          message: '현재 지출 기준 정산을 미리 계산했어요.',
        );
        return;
      case SettlementStage.previewed:
        final confirmed = await _confirmSettlement();
        if (confirmed != true) return;
        await _runAction(
          _settlementService.confirmSettlement,
          message: '정산이 확정됐어요.',
        );
        return;
      case SettlementStage.confirmed:
        return;
    }
  }

  Future<bool?> _confirmSettlement() {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('정산하기'),
          content: const Text('정산을 확정하면 되돌릴 수 없고, 이후 지출을 추가하거나 수정할 수 없어요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('취소'),
            ),
            FilledButton(
              key: const ValueKey('confirmSettlementButton'),
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: AppButtonStyles.primary(),
              child: const Text('정산하기'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleShare() async {
    await _runAction(
      _settlementService.createShareToken,
      message: '공유 링크가 준비됐어요.',
    );
  }

  Future<void> _confirmTransfer(
    SettlementTransferItem transfer,
    SettlementTransferDirection direction,
  ) async {
    final action = direction == SettlementTransferDirection.sent
        ? () => _settlementService.confirmTransferAsSender(transfer.id)
        : () => _settlementService.confirmTransferAsReceiver(transfer.id);
    final message = direction == SettlementTransferDirection.sent
        ? '송금 완료로 표시했어요.'
        : '수금 완료로 표시했어요.';

    await _runAction(action, message: message);
  }

  void _showExplanation() {
    showAppBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const SettlementExplanationSheet(),
    );
  }

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  @override
  Widget build(BuildContext context) {
    final overview = _overview;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          centerTitle: false,
          leading: IconButton(
            onPressed: _close,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: '뒤로',
          ),
          title: const Text(
            '정산',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: IconButton(
                key: const ValueKey('settlementHelpButton'),
                onPressed: _showExplanation,
                tooltip: '정산 계산 방법',
                style: AppIconButtonStyles.neutral(),
                icon: const Icon(Icons.help_outline_rounded, size: 20),
              ),
            ),
          ],
        ),
        body: switch ((_isLoading, overview)) {
          (true, _) => const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          (false, null) => _SettlementErrorState(
            message: _errorMessage ?? '정산 정보를 불러오지 못했습니다.',
            onRetry: _loadOverview,
          ),
          (false, final data?) => _buildContent(data),
        },
      ),
    );
  }

  Widget _buildContent(SettlementOverview overview) {
    return Column(
      children: [
        SettlementStatusSummary(
          overview: overview,
          isBusy: _isBusy,
          onPrimaryAction: _handlePrimaryAction,
          onShare: _handleShare,
        ),
        SettlementMySummaryCard(overview: overview),
        if (widget.showMockCases)
          _MockCaseSelector(
            selectedMockCase: _selectedMockCase,
            onSelect: _selectMockCase,
          ),
        _SettlementTabs(selectedTab: _selectedTab, onSelect: _selectTab),
        Expanded(child: _buildTabBody(overview)),
      ],
    );
  }

  _SettlementTab _recommendedTab(SettlementOverview overview) {
    if (overview.stage != SettlementStage.confirmed) {
      return _SettlementTab.overview;
    }
    if (overview.hasPendingReceivedTransfers) return _SettlementTab.received;
    if (overview.hasPendingSentTransfers) return _SettlementTab.sent;
    return _SettlementTab.overview;
  }

  void _selectTab(_SettlementTab tab) {
    if (_selectedTab == tab) return;
    setState(() => _selectedTab = tab);
  }

  Widget _buildTabBody(SettlementOverview overview) {
    switch (_selectedTab) {
      case _SettlementTab.overview:
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 24),
          itemCount: overview.balances.length,
          itemBuilder: (context, index) {
            return SettlementBalanceCard(
              balance: overview.balances[index],
              currency: overview.baseCurrency,
            );
          },
        );
      case _SettlementTab.sent:
        return _TransferList(
          transfers: overview.sentTransfers,
          direction: SettlementTransferDirection.sent,
          emptyMessage: '보낼 정산이 없어요.',
          isConfirmed: overview.stage == SettlementStage.confirmed,
          isBusy: _isBusy,
          onConfirm: _confirmTransfer,
        );
      case _SettlementTab.received:
        return _TransferList(
          transfers: overview.receivedTransfers,
          direction: SettlementTransferDirection.received,
          emptyMessage: '받을 정산이 없어요.',
          isConfirmed: overview.stage == SettlementStage.confirmed,
          isBusy: _isBusy,
          onConfirm: _confirmTransfer,
        );
    }
  }
}

class _MockCaseSelector extends StatelessWidget {
  final SettlementMockCase selectedMockCase;
  final ValueChanged<SettlementMockCase> onSelect;

  const _MockCaseSelector({
    required this.selectedMockCase,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
      child: ListView.separated(
        key: const ValueKey('settlementMockCaseList'),
        scrollDirection: Axis.horizontal,
        itemCount: SettlementMockCase.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final mockCase = SettlementMockCase.values[index];
          final selected = selectedMockCase == mockCase;
          return ChoiceChip(
            key: ValueKey('settlementMockCase${mockCase.name}'),
            selected: selected,
            label: Text(mockCase.label),
            onSelected: (_) => onSelect(mockCase),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
              color: selected ? Colors.white : const Color(0xFF4A4A4A),
            ),
            selectedColor: AppColors.ink,
            backgroundColor: Colors.white,
            side: BorderSide(
              color: selected ? AppColors.ink : const Color(0xFFE2E2E2),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          );
        },
      ),
    );
  }
}

class _SettlementTabs extends StatelessWidget {
  final _SettlementTab selectedTab;
  final ValueChanged<_SettlementTab> onSelect;

  const _SettlementTabs({required this.selectedTab, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      color: AppColors.background,
      child: Row(
        children: _SettlementTab.values.map((tab) {
          final selected = selectedTab == tab;
          return Expanded(
            child: InkWell(
              key: ValueKey('settlementTab${tab.name}'),
              onTap: () => onSelect(tab),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Center(
                      child: Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: selected
                              ? AppColors.brandStrong
                              : AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  Container(
                    height: 2,
                    width: selected ? 48 : 0,
                    color: AppColors.brand,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TransferList extends StatelessWidget {
  final List<SettlementTransferItem> transfers;
  final SettlementTransferDirection direction;
  final String emptyMessage;
  final bool isConfirmed;
  final bool isBusy;
  final void Function(
    SettlementTransferItem transfer,
    SettlementTransferDirection direction,
  )
  onConfirm;

  const _TransferList({
    required this.transfers,
    required this.direction,
    required this.emptyMessage,
    required this.isConfirmed,
    required this.isBusy,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    if (transfers.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: const TextStyle(fontSize: 13, color: AppColors.textSubtle),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.only(top: 8, bottom: 24),
      itemCount: transfers.length,
      itemBuilder: (context, index) {
        final transfer = transfers[index];
        return SettlementTransferCard(
          transfer: transfer,
          direction: direction,
          canConfirm: isConfirmed && !isBusy,
          onConfirm: () => onConfirm(transfer, direction),
        );
      },
    );
  }
}

class _SettlementErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _SettlementErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textSubtle),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('다시 시도')),
          ],
        ),
      ),
    );
  }
}
