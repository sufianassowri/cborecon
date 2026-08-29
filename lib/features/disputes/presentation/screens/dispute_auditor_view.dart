import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../data/model/dispute_batch_model.dart';
import '../controllers/dispute_provider.dart';

class DisputeAuditorView extends ConsumerWidget {
  const DisputeAuditorView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ResponsiveShell(
      currentRoute: '/dispute_auditor',
      title: 'Dispute Management - Internal Auditor Portal',
      subtitle: 'Audit trail ledger, assignment SLA tracking, lifecycle turnaround analysis & correction history',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
          tooltip: 'Operation Guide',
          onPressed: () {
            GuidedReconModal.show(
              context,
              moduleTitle: 'Dispute Management - Auditor Guide',
              modulePurpose: 'Audit trail ledger, assignment SLA tracking, lifecycle turnaround analysis & correction history.',
              steps: const [
                ReconStepGuide(step: 1, title: 'Monitor SLAs', format: 'Metrics', description: 'Review average turnaround times between assignment and authorization.'),
                ReconStepGuide(step: 2, title: 'Review Ledger', format: 'Table', description: 'Inspect all batches and their detailed audit history.'),
                ReconStepGuide(step: 3, title: 'Export Data', format: 'CSV', description: 'Export the complete audit ledger for external compliance tracking.'),
              ],
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh Audit Data',
          onPressed: () => ref.read(disputeBatchesNotifierProvider.notifier).refresh(),
        ),
      ],
      body: const AuditorDashboardContent(),
    );
  }
}

class AuditorDashboardContent extends ConsumerStatefulWidget {
  const AuditorDashboardContent({super.key});

  @override
  ConsumerState<AuditorDashboardContent> createState() => _AuditorDashboardContentState();
}

class _AuditorDashboardContentState extends ConsumerState<AuditorDashboardContent> {
  String _statusFilter = 'ALL';
  String _searchQuery = '';
  late PlutoGridStateManager _gridStateManager;

  Future<void> _exportAuditCsv(List<DisputeBatch> batches) async {
    final buffer = StringBuffer();
    buffer.writeln(
      'Batch/Ticket ID,FileName,TxnCount,TotalDebit,TotalCredit,Status,MadeBy,MadeAt,AssignedTo,AssignedBy,AssignedAt,AuthorizedBy,AuthorizedAt,DurationMadeToAssigned,DurationAssignedToAuth,TotalTurnaround,CheckerComment',
    );

    for (var b in batches) {
      buffer.writeln(
        '"${b.batchNumber}","${b.fileName}",${b.transactionCount},${b.totalDebitAmount},${b.totalCreditAmount},"${b.status}","${b.madeBy}","${b.madeAt}","${b.assignedTo ?? ''}","${b.assignedBy ?? ''}","${b.assignedAt ?? ''}","${b.authorizedBy ?? ''}","${b.authorizedAt ?? ''}","${b.formatDuration(b.durationMadeToAssigned)}","${b.formatDuration(b.durationAssignedToAuthorized)}","${b.formatDuration(b.totalTurnaroundDuration)}","${(b.checkerComment ?? '').replaceAll('"', '""')}"',
      );
    }

    try {
      await FileSaverUtil.saveCsv(
        baseName: 'Dispute_Audit_Report',
        csvContent: buffer.toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Audit report CSV exported successfully!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(disputeBatchesNotifierProvider);
    final analytics = ref.watch(disputeAnalyticsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: KPI Analytics Cards
          Row(
            children: [
              _buildKpiCard(
                title: 'Total Tickets',
                value: '${analytics.totalBatches}',
                subtitle: 'All dispute batches',
                icon: Icons.confirmation_number_outlined,
                color: CboColors.primaryBlue,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                title: 'Pending Tickets',
                value: '${analytics.pendingBatches}',
                subtitle: 'Awaiting assignment',
                icon: Icons.pending_actions_rounded,
                color: Colors.orange,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                title: 'Assigned (In-Review)',
                value: '${analytics.assignedBatches}',
                subtitle: 'With Checker officers',
                icon: Icons.assignment_ind_rounded,
                color: CboColors.primaryCyan,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                title: 'Authorized',
                value: '${analytics.authorizedBatches}',
                subtitle: 'Completed approvals',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
              ),
              const SizedBox(width: 12),
              _buildKpiCard(
                title: 'Returned for Correction',
                value: '${analytics.rejectedBatches}',
                subtitle: 'Rejected with notes',
                icon: Icons.rate_review_rounded,
                color: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Row 2: SLA Duration Timers Card
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CboColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.timer_outlined, color: CboColors.primaryBlue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'SLA Turnaround Benchmark Analytics',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: CboColors.primaryBlue),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Audit tracking of average duration intervals between Maker upload, Manager assignment, and Checker authorization.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  _buildSlaDurationBadge(
                    label: 'Avg Made → Assigned',
                    duration: analytics.averageMadeToAssigned,
                    color: Colors.orange.shade800,
                  ),
                  const SizedBox(width: 12),
                  _buildSlaDurationBadge(
                    label: 'Avg Assigned → Authorized',
                    duration: analytics.averageAssignedToAuthorized,
                    color: CboColors.primaryCyan,
                  ),
                  const SizedBox(width: 12),
                  _buildSlaDurationBadge(
                    label: 'Avg Total Turnaround SLA',
                    duration: analytics.averageTotalTurnaround,
                    color: Colors.green.shade800,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Audit Filter Toolbar & Export
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by Ticket/Batch ID, Maker, Checker or Comment...',
                        prefixIcon: Icon(Icons.search),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.trim().toLowerCase();
                        });
                      },
                    ),
                  ),
                  const VerticalDivider(width: 20),
                  DropdownButton<String>(
                    value: _statusFilter,
                    underline: const SizedBox.shrink(),
                    items: const [
                      DropdownMenuItem(value: 'ALL', child: Text('All Statuses')),
                      DropdownMenuItem(value: 'NEW', child: Text('Pending (NEW)')),
                      DropdownMenuItem(value: 'ASSIGNED', child: Text('Assigned')),
                      DropdownMenuItem(value: 'AUTHORIZED', child: Text('Authorized')),
                      DropdownMenuItem(value: 'REJECTED', child: Text('Rejected / Correction')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _statusFilter = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      final batches = batchesAsync.value ?? [];
                      _exportAuditCsv(batches);
                    },
                    icon: const Icon(Icons.download_rounded, size: 18, color: Colors.white),
                    label: const Text('Export Audit CSV', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CboColors.bankGreen,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Audit PlutoGrid Table
          batchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (batches) {
              final filtered = batches.where((b) {
                if (_statusFilter != 'ALL' && b.status != _statusFilter) {
                  return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final matchBatch = b.batchNumber.toLowerCase().contains(_searchQuery);
                  final matchMaker = b.madeBy.toLowerCase().contains(_searchQuery);
                  final matchChecker = (b.assignedTo ?? '').toLowerCase().contains(_searchQuery);
                  final matchComment = (b.checkerComment ?? '').toLowerCase().contains(_searchQuery);
                  return matchBatch || matchMaker || matchChecker || matchComment;
                }
                return true;
              }).toList();

              return Container(
                height: 480,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: PlutoGrid(
                  columns: [
                    PlutoColumn(
                      title: 'Ticket / DC #',
                      field: 'batchNumber',
                      type: PlutoColumnType.text(),
                      width: 180,
                    ),
                    PlutoColumn(
                      title: 'Counted Txns',
                      field: 'count',
                      type: PlutoColumnType.number(),
                      width: 110,
                    ),
                    PlutoColumn(
                      title: 'Total Amount (DR)',
                      field: 'totalAmount',
                      type: PlutoColumnType.currency(symbol: 'ETB '),
                      width: 140,
                    ),
                    PlutoColumn(
                      title: 'Made By (Maker)',
                      field: 'madeBy',
                      type: PlutoColumnType.text(),
                      width: 140,
                    ),
                    PlutoColumn(
                      title: 'Made At',
                      field: 'madeAt',
                      type: PlutoColumnType.text(),
                      width: 140,
                    ),
                    PlutoColumn(
                      title: 'Assigned To',
                      field: 'assignedTo',
                      type: PlutoColumnType.text(),
                      width: 140,
                    ),
                    PlutoColumn(
                      title: 'Assigned At',
                      field: 'assignedAt',
                      type: PlutoColumnType.text(),
                      width: 140,
                    ),
                    PlutoColumn(
                      title: 'Time: Made→Assigned',
                      field: 'durMadeToAssigned',
                      type: PlutoColumnType.text(),
                      width: 160,
                    ),
                    PlutoColumn(
                      title: 'Authorized By',
                      field: 'authorizedBy',
                      type: PlutoColumnType.text(),
                      width: 140,
                    ),
                    PlutoColumn(
                      title: 'Authorized At',
                      field: 'authorizedAt',
                      type: PlutoColumnType.text(),
                      width: 140,
                    ),
                    PlutoColumn(
                      title: 'Time: Assigned→Auth',
                      field: 'durAssignedToAuth',
                      type: PlutoColumnType.text(),
                      width: 160,
                    ),
                    PlutoColumn(
                      title: 'Total Turnaround SLA',
                      field: 'totalTurnaround',
                      type: PlutoColumnType.text(),
                      width: 160,
                    ),
                    PlutoColumn(
                      title: 'Status',
                      field: 'status',
                      type: PlutoColumnType.text(),
                      width: 120,
                    ),
                    PlutoColumn(
                      title: 'Checker Correction Comment',
                      field: 'checkerComment',
                      type: PlutoColumnType.text(),
                      width: 260,
                    ),
                  ],
                  rows: filtered.map((b) {
                    final isLive = b.status == 'NEW' || b.status == 'ASSIGNED';
                    return PlutoRow(
                      cells: {
                        'batchNumber': PlutoCell(value: b.batchNumber),
                        'count': PlutoCell(value: b.transactionCount),
                        'totalAmount': PlutoCell(value: b.totalDebitAmount),
                        'madeBy': PlutoCell(value: b.madeBy),
                        'madeAt': PlutoCell(value: DateFormat('yyyy-MM-dd HH:mm').format(b.madeAt)),
                        'assignedTo': PlutoCell(value: b.assignedTo ?? 'Unassigned'),
                        'assignedAt': PlutoCell(value: b.assignedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(b.assignedAt!) : '-'),
                        'durMadeToAssigned': PlutoCell(value: b.formatDuration(b.durationMadeToAssigned)),
                        'authorizedBy': PlutoCell(value: b.authorizedBy ?? b.rejectedBy ?? '-'),
                        'authorizedAt': PlutoCell(value: b.authorizedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(b.authorizedAt!) : (b.rejectedAt != null ? DateFormat('yyyy-MM-dd HH:mm').format(b.rejectedAt!) : '-')),
                        'durAssignedToAuth': PlutoCell(value: b.formatDuration(b.durationAssignedToAuthorized)),
                        'totalTurnaround': PlutoCell(
                          value: isLive
                              ? '${b.formatDuration(b.currentElapsedTime)} (In-Flight)'
                              : b.formatDuration(b.totalTurnaroundDuration),
                        ),
                        'status': PlutoCell(value: b.status),
                        'checkerComment': PlutoCell(value: b.checkerComment ?? '-'),
                      },
                    );
                  }).toList(),
                  onLoaded: (event) {
                    _gridStateManager = event.stateManager;
                    _gridStateManager.setShowColumnFilter(true);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
                    Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlaDurationBadge({
    required String label,
    required Duration duration,
    required Color color,
  }) {
    String text;
    if (duration.inMinutes == 0 && duration.inSeconds == 0) {
      text = '0m';
    } else if (duration.inDays > 0) {
      text = '${duration.inDays}d ${duration.inHours.remainder(24)}h';
    } else if (duration.inHours > 0) {
      text = '${duration.inHours}h ${duration.inMinutes.remainder(60)}m';
    } else {
      text = '${duration.inMinutes}m ${duration.inSeconds.remainder(60)}s';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(text, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}