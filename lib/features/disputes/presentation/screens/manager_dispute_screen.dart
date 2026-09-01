import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/cbo_status_badge.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../../../core/widgets/responsive_row.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/model/dispute_batch_model.dart';
import '../controllers/dispute_provider.dart';
import 'dispute_auditor_view.dart';

class ManagerDisputeScreen extends ConsumerStatefulWidget {
  const ManagerDisputeScreen({super.key});

  @override
  ConsumerState<ManagerDisputeScreen> createState() => _ManagerDisputeScreenState();
}

class _ManagerDisputeScreenState extends ConsumerState<ManagerDisputeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _statusFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _showAssignCheckerDialog(DisputeBatch batch) {
    final checkersAsync = ref.read(checkersListProvider);
    String? selectedChecker = batch.assignedTo;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.assignment_ind_rounded, color: CboColors.primaryBlue),
                  const SizedBox(width: 10),
                  const Text('Assign Batch to Checker', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Batch / Ticket ID: ${batch.batchNumber}',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryBlue)),
                        const SizedBox(height: 4),
                        Text('Counted Items: ${batch.transactionCount} transactions in this batch'),
                        Text('Uploaded By Maker: ${batch.madeBy}'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Reviewer / Checker:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  checkersAsync.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Text('Error loading checkers: $err'),
                    data: (checkers) {
                      if (selectedChecker == null && checkers.isNotEmpty) {
                        selectedChecker = checkers.first;
                      }
                      return DropdownButtonFormField<String>(
                        value: selectedChecker,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        ),
                        items: checkers.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (val) {
                          setDialogState(() {
                            selectedChecker = val;
                          });
                        },
                      );
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: selectedChecker == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          if (batch.objectId != null) {
                            try {
                              await ref
                                  .read(disputeBatchesNotifierProvider.notifier)
                                  .assignBatch(
                                    batchObjectId: batch.objectId!,
                                    checkerUsername: selectedChecker!,
                                  );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                        'Batch ${batch.batchNumber} assigned to $selectedChecker'),
                                    backgroundColor: Colors.green,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                      content: Text('Assignment failed: $e'),
                                      backgroundColor: Colors.red),
                                );
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: CboColors.primaryBlue),
                  child: const Text('Confirm Assignment', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(disputeBatchesNotifierProvider);
    final analytics = ref.watch(disputeAnalyticsProvider);
    final fmt = NumberFormat('#,##0.00');

    return ResponsiveShell(
      currentRoute: '/dispute_manager',
      title: 'Dispute Management - Operations Manager Portal',
      subtitle: 'Supervisory assignment of dispute batches, counted transaction tracking & audit governance',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: Colors.white),
          tooltip: 'Operation Guide',
          onPressed: () {
            GuidedReconModal.show(
              context,
              moduleTitle: 'Dispute Management - Manager Guide',
              modulePurpose: 'Supervisory assignment of dispute batches, transaction tracking, and audit governance.',
              steps: const [
                ReconStepGuide(step: 1, title: 'Monitor Incoming Batches', format: 'Real-time', description: 'View unassigned disputes uploaded by the Maker.'),
                ReconStepGuide(step: 2, title: 'Assign Checkers', format: 'Manual', description: 'Select a registered checker from the database to authorize the batch.'),
                ReconStepGuide(step: 3, title: 'Track Turnaround SLA', format: 'Analytics', description: 'Monitor the average time taken from batch creation to authorization.'),
              ],
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh Batches',
          onPressed: () => ref.read(disputeBatchesNotifierProvider.notifier).refresh(),
        ),
      ],
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: CboColors.primaryBlue,
              unselectedLabelColor: Colors.grey,
              indicatorColor: CboColors.primaryBlue,
              indicatorWeight: 3,
              tabs: const [
                Tab(
                  icon: Icon(Icons.assignment_turned_in_rounded),
                  text: 'Batch Assignment & Segregated Overview',
                ),
                Tab(
                  icon: Icon(Icons.insights_rounded),
                  text: 'Supervisory SLA & Audit Analytics',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBatchAssignmentView(batchesAsync, analytics, fmt),
                const AuditorDashboardContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchAssignmentView(
    AsyncValue<List<DisputeBatch>> batchesAsync,
    DisputeAuditAnalytics analytics,
    NumberFormat fmt,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // KPI Metric Header Cards
          ResponsiveRow(
            children: [
              _buildMetricCard(
                title: 'Total Batches',
                value: '${analytics.totalBatches}',
                subtitle: 'Active dispute files',
                icon: Icons.folder_copy_rounded,
                color: CboColors.primaryBlue,
                onTap: () {
                  setState(() => _statusFilter = 'ALL');
                },
              ),
              _buildMetricCard(
                title: 'Pending Assignment',
                value: '${analytics.pendingBatches}',
                subtitle: 'Requires Checker routing',
                icon: Icons.hourglass_top_rounded,
                color: Colors.orange,
                onTap: () {
                  setState(() => _statusFilter = 'NEW');
                },
              ),
              _buildMetricCard(
                title: 'In Review (Assigned)',
                value: '${analytics.assignedBatches}',
                subtitle: 'With Checker officers',
                icon: Icons.fact_check_rounded,
                color: CboColors.primaryCyan,
                onTap: () {
                  setState(() => _statusFilter = 'ASSIGNED');
                },
              ),
              _buildMetricCard(
                title: 'Authorized',
                value: '${analytics.authorizedBatches}',
                subtitle: 'Completed & approved',
                icon: Icons.check_circle_rounded,
                color: Colors.green,
                onTap: () {
                  setState(() => _statusFilter = 'AUTHORIZED');
                },
              ),
              _buildMetricCard(
                title: 'Correction Required',
                value: '${analytics.rejectedBatches}',
                subtitle: 'Rejected by Checkers',
                icon: Icons.error_outline_rounded,
                color: Colors.red,
                onTap: () {
                  setState(() => _statusFilter = 'REJECTED');
                },
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search & Filter Toolbar
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by Batch / Ticket ID or Maker Username...',
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
                      DropdownMenuItem(value: 'NEW', child: Text('Pending Assignment (NEW)')),
                      DropdownMenuItem(value: 'ASSIGNED', child: Text('Assigned to Checker')),
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Notice banner explaining segregation
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade300),
            ),
            child: Row(
              children: const [
                Icon(Icons.shield_outlined, color: Colors.amber, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Segregation of Duties Policy: Operations Managers inspect aggregated transaction counts and financial totals to route batches to Checkers, while itemized reconciliation is performed in the Checker Portal.',
                    style: TextStyle(fontSize: 12, color: Colors.black87, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Batches Table
          batchesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading batches: $err')),
            data: (batches) {
              final filtered = batches.where((b) {
                if (_statusFilter != 'ALL' && b.status != _statusFilter) {
                  return false;
                }
                if (_searchQuery.isNotEmpty) {
                  final matchBatch = b.batchNumber.toLowerCase().contains(_searchQuery);
                  final matchMaker = b.madeBy.toLowerCase().contains(_searchQuery);
                  return matchBatch || matchMaker;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Container(
                  height: 250,
                  alignment: Alignment.center,
                  child: const Text('No batches match current filter/search criteria',
                      style: TextStyle(color: Colors.grey, fontSize: 15)),
                );
              }

              return Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.grey.shade200),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: DataTable(
                          columnSpacing: 16,
                          horizontalMargin: 16,
                          headingRowColor: WidgetStateProperty.all(const Color(0xFFF4F7FA)),
                          dataRowMinHeight: 56,
                          dataRowMaxHeight: 70,
                          columns: const [
                            DataColumn(label: Text('Batch / Ticket ID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Counted Txns', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Total DR (ETB)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Total CR (ETB)', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Balance Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Maker / Uploaded', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Assigned Checker', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Status', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: filtered.map((b) {
                            final isPending = b.status == 'NEW' || b.status == 'PENDING_ASSIGNMENT';
                            return DataRow(
                              cells: [
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(b.batchNumber, style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryBlue)),
                                      Text(b.fileName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: Colors.blue.shade50,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${b.transactionCount} items',
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryBlue, fontSize: 13),
                                    ),
                                  ),
                                ),
                                DataCell(Text(fmt.format(b.totalDebitAmount))),
                                DataCell(Text(fmt.format(b.totalCreditAmount))),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: b.isBalanced ? Colors.green.shade50 : Colors.red.shade50,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      b.isBalanced ? 'Balanced' : 'Diff: ${fmt.format((b.totalDebitAmount - b.totalCreditAmount).abs())}',
                                      style: TextStyle(
                                        color: b.isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(b.madeBy, style: const TextStyle(fontWeight: FontWeight.w600)),
                                      Text(DateFormat('yyyy-MM-dd HH:mm').format(b.madeAt),
                                          style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                    ],
                                  ),
                                ),
                                DataCell(
                                  Text(b.assignedTo ?? 'Unassigned',
                                      style: TextStyle(
                                        fontWeight: b.assignedTo != null ? FontWeight.bold : FontWeight.normal,
                                        color: b.assignedTo != null ? Colors.black87 : Colors.orange,
                                      )),
                                ),
                                DataCell(_buildStatusChip(b.status)),
                                DataCell(
                                  Tooltip(
                                    message: (b.status == 'AUTHORIZED' || b.status == 'REJECTED') ? 'Cannot reassign a completed batch' : '',
                                    child: ElevatedButton.icon(
                                      onPressed: (b.status == 'AUTHORIZED' || b.status == 'REJECTED') ? null : () => _showAssignCheckerDialog(b),
                                      icon: Icon(
                                        isPending ? Icons.person_add_alt_1_rounded : ((b.status == 'AUTHORIZED' || b.status == 'REJECTED') ? Icons.lock_rounded : Icons.swap_horiz_rounded),
                                        size: 16,
                                        color: (b.status == 'AUTHORIZED' || b.status == 'REJECTED') ? Colors.grey.shade600 : Colors.white,
                                      ),
                                      label: Text(
                                        isPending ? 'Assign' : ((b.status == 'AUTHORIZED' || b.status == 'REJECTED') ? 'Locked' : 'Reassign'),
                                        style: TextStyle(color: (b.status == 'AUTHORIZED' || b.status == 'REJECTED') ? Colors.grey.shade600 : Colors.white, fontSize: 12),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: (b.status == 'AUTHORIZED' || b.status == 'REJECTED') ? Colors.grey.shade300 : (isPending ? CboColors.primaryBlue : Colors.grey.shade700),
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
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

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'NEW':
      case 'PENDING_ASSIGNMENT':
        color = Colors.orange;
        break;
      case 'ASSIGNED':
        color = CboColors.primaryBlue;
        break;
      case 'AUTHORIZED':
        color = Colors.green;
        break;
      case 'REJECTED':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}
