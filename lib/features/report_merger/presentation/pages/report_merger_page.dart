import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../domain/entities/settlement_row_entity.dart';
import '../../domain/services/settlement_merger_engine.dart';
import '../providers/report_merger_provider.dart';

class ReportMergerPage extends ConsumerStatefulWidget {
  const ReportMergerPage({super.key});

  @override
  ConsumerState<ReportMergerPage> createState() => _ReportMergerPageState();
}

class _ReportMergerPageState extends ConsumerState<ReportMergerPage> {
  late PlutoGridStateManager _gridStateManager;

  final List<String> _settlementTypes = [
    'ATM / POS Switch Settlement',
    'Ebirr Settlement',
    'Telebirr Settlement',
    'EthSwitch IPS Settlement',
    'MasterCard Settlement',
  ];

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reportMergerProvider);
    final notifier = ref.read(reportMergerProvider.notifier);

    return ResponsiveShell(
      currentRoute: '/report_merger',
      title: 'Settlement Report Merger Engine',
      subtitle: 'Multi-file settlement merger, single-header deduplication, chronological sorting & multi-sheet generation',
      actions: [
        if (state.mergedResult != null) ...[
          OutlinedButton.icon(
            onPressed: () async {
              try {
                await notifier.exportCsv();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('CSV Exported Successfully'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.file_present_rounded, color: Colors.white, size: 18),
            label: const Text('Export CSV', style: TextStyle(color: Colors.white)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.white70),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () async {
              try {
                await notifier.exportExcel();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Multi-Sheet Excel (.xlsx) Exported Successfully!'), backgroundColor: Colors.green),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Export error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            icon: const Icon(Icons.download_rounded, color: Colors.white, size: 18),
            label: const Text('Download Multi-Sheet Excel', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: CboColors.bankGreen,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Toolbar: Settlement Feed Selector & Notice
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CboColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.hub_rounded, color: CboColors.primaryBlue, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Settlement Feed / Gateway Profile:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                          ),
                          const SizedBox(height: 4),
                          DropdownButton<String>(
                            value: state.settlementType,
                            isDense: true,
                            underline: const SizedBox.shrink(),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: CboColors.primaryBlue,
                            ),
                            items: _settlementTypes.map((type) {
                              return DropdownMenuItem(value: type, child: Text(type));
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) notifier.setSettlementType(val);
                            },
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.shield_outlined, size: 16, color: CboColors.primaryBlue),
                          SizedBox(width: 6),
                          Text(
                            'Strict 15-Header Schema Enforced',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: CboColors.primaryBlue),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Upload Dropzone & Files Queue Card
            _buildUploadAndQueueSection(state, notifier),
            const SizedBox(height: 20),

            // Progress Bar if processing
            if (state.isProcessing) ...[
              GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(state.statusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                          Text('${(state.progress * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryBlue)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: state.progress > 0 ? state.progress : null,
                        backgroundColor: Colors.grey.shade200,
                        color: CboColors.primaryBlue,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],

            // If merged result available: Show HUD Metrics + PlutoGrid Category Tabs
            if (state.mergedResult != null) ...[
              _buildHudMetrics(state.mergedResult!),
              const SizedBox(height: 20),
              _buildCategoryTabsAndGrid(state, notifier),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUploadAndQueueSection(ReportMergerState state, ReportMergerNotifier notifier) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Multi-File Ingestion Queue (15+ Reports Supported)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CboColors.primaryBlue),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Select settlement files (.xls, .xlsx, .csv). Duplicate headers and empty rows will be automatically purged.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                  ],
                ),
                Row(
                  children: [
                    if (state.selectedFiles.isNotEmpty) ...[
                      OutlinedButton.icon(
                        onPressed: state.isProcessing ? null : notifier.clearFiles,
                        icon: const Icon(Icons.clear_all_rounded, size: 18),
                        label: const Text('Clear Queue'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    ElevatedButton.icon(
                      onPressed: state.isProcessing ? null : notifier.pickFiles,
                      icon: const Icon(Icons.note_add_rounded, size: 18, color: Colors.white),
                      label: const Text('Select Settlement Files', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CboColors.primaryBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),

            if (state.selectedFiles.isEmpty)
              InkWell(
                onTap: notifier.pickFiles,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 36),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FBFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade300, strokeAlign: BorderSide.strokeAlignInside),
                  ),
                  child: Column(
                    children: const [
                      Icon(Icons.file_upload_outlined, size: 48, color: CboColors.primaryBlue),
                      SizedBox(height: 10),
                      Text(
                        'Click to browse & multi-select settlement files (.xls, .xlsx, .csv)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Supports simultaneous selection of 15+ files and 200,000+ transaction rows',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: state.selectedFiles.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final f = entry.value;
                      final kb = (f.size / 1024).toStringAsFixed(1);
                      return Chip(
                        avatar: const Icon(Icons.description_rounded, size: 16, color: CboColors.primaryBlue),
                        label: Text('${f.name} ($kb KB)', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: state.isProcessing ? null : () => notifier.removeFile(idx),
                        backgroundColor: const Color(0xFFEDF4FA),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        '${state.selectedFiles.length} file(s) queued for merging',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: state.isProcessing ? null : notifier.runMerge,
                        icon: const Icon(Icons.merge_type_rounded, color: Colors.white),
                        label: Text(
                          'Execute Merge (${state.selectedFiles.length} Files)',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade700,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHudMetrics(MergedSettlementResult res) {
    final fmt = NumberFormat('#,##0');
    final currFmt = NumberFormat('#,##0.00');

    return Row(
      children: [
        _buildMetricItem(
          title: 'Files Merged',
          value: '${res.totalFilesProcessed}',
          subtitle: 'Source reports combined',
          icon: Icons.folder_zip_rounded,
          color: CboColors.primaryBlue,
        ),
        const SizedBox(width: 12),
        _buildMetricItem(
          title: 'Valid Transactions',
          value: fmt.format(res.totalRowsAfter),
          subtitle: 'Clean 1-to-1 rows',
          icon: Icons.check_circle_outline_rounded,
          color: Colors.green,
        ),
        const SizedBox(width: 12),
        _buildMetricItem(
          title: 'Empty Rows Purged',
          value: fmt.format(res.emptyRowsPurged),
          subtitle: 'Blank/junk rows removed',
          icon: Icons.delete_sweep_rounded,
          color: Colors.orange,
        ),
        const SizedBox(width: 12),
        _buildMetricItem(
          title: 'Duplicate Headers Stripped',
          value: fmt.format(res.duplicateHeadersRemoved),
          subtitle: 'Only 1 header retained',
          icon: Icons.filter_list_off_rounded,
          color: CboColors.primaryCyan,
        ),
        const SizedBox(width: 12),
        _buildMetricItem(
          title: 'Distinct Sheets',
          value: '${res.categorizedSheets.length}',
          subtitle: 'Dynamic category tabs',
          icon: Icons.tab_rounded,
          color: Colors.purple,
        ),
        const SizedBox(width: 12),
        _buildMetricItem(
          title: 'Total Volume',
          value: 'ETB ${currFmt.format(res.totalVolumeAmount)}',
          subtitle: 'Execution: ${res.processingTime.inMilliseconds} ms',
          icon: Icons.account_balance_wallet_rounded,
          color: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Expanded(
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    const SizedBox(height: 2),
                    Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
                    Text(subtitle, style: const TextStyle(fontSize: 9, color: Colors.grey)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTabsAndGrid(ReportMergerState state, ReportMergerNotifier notifier) {
    final res = state.mergedResult!;
    final activeTab = state.activePreviewCategory;

    // Get rows to display in PlutoGrid
    List<SettlementRowEntity> activeRows;
    if (activeTab == 'All_Merged') {
      activeRows = res.allMergedRows;
    } else {
      activeRows = res.categorizedSheets[activeTab] ?? res.allMergedRows;
    }

    final categoryTabs = ['All_Merged', ...res.categorizedSheets.keys];

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Tabs Selector
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: categoryTabs.map((cat) {
                        final isSelected = cat == activeTab;
                        final count = cat == 'All_Merged'
                            ? res.allMergedRows.length
                            : (res.categorizedSheets[cat]?.length ?? 0);
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(
                              '$cat ($count)',
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                color: isSelected ? Colors.white : Colors.black87,
                                fontSize: 12,
                              ),
                            ),
                            selected: isSelected,
                            selectedColor: CboColors.primaryBlue,
                            backgroundColor: const Color(0xFFF0F4F8),
                            onSelected: (_) => notifier.setActivePreviewCategory(cat),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // PlutoGrid Table Preview
            Container(
              height: 500,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: PlutoGrid(
                key: ValueKey(activeTab), // Rebuild grid when switching tabs
                columns: [
                  PlutoColumn(
                    title: 'Issuer',
                    field: 'issuer',
                    type: PlutoColumnType.text(),
                    width: 100,
                  ),
                  PlutoColumn(
                    title: 'Acquirer',
                    field: 'acquirer',
                    type: PlutoColumnType.text(),
                    width: 100,
                  ),
                  PlutoColumn(
                    title: 'MTI',
                    field: 'mti',
                    type: PlutoColumnType.text(),
                    width: 80,
                  ),
                  PlutoColumn(
                    title: 'Card_Number',
                    field: 'card_number',
                    type: PlutoColumnType.text(),
                    width: 170,
                  ),
                  PlutoColumn(
                    title: 'Amount',
                    field: 'amount',
                    type: PlutoColumnType.currency(symbol: 'ETB '),
                    width: 140,
                  ),
                  PlutoColumn(
                    title: 'Currency',
                    field: 'currency',
                    type: PlutoColumnType.text(),
                    width: 90,
                  ),
                  PlutoColumn(
                    title: 'Transaction_Date',
                    field: 'transaction_date',
                    type: PlutoColumnType.text(),
                    width: 140,
                  ),
                  PlutoColumn(
                    title: 'Transaction_Description',
                    field: 'transaction_description',
                    type: PlutoColumnType.text(),
                    width: 220,
                  ),
                  PlutoColumn(
                    title: 'Terminal_ID',
                    field: 'terminal_id',
                    type: PlutoColumnType.text(),
                    width: 120,
                  ),
                  PlutoColumn(
                    title: 'Transaction_Place',
                    field: 'transaction_place',
                    type: PlutoColumnType.text(),
                    width: 160,
                  ),
                  PlutoColumn(
                    title: 'STAN_F11',
                    field: 'stan_f11',
                    type: PlutoColumnType.text(),
                    width: 110,
                  ),
                  PlutoColumn(
                    title: 'Refnum_F37',
                    field: 'refnum_f37',
                    type: PlutoColumnType.text(),
                    width: 140,
                  ),
                  PlutoColumn(
                    title: 'Authidresp_F38',
                    field: 'authidresp_f38',
                    type: PlutoColumnType.text(),
                    width: 120,
                  ),
                  PlutoColumn(
                    title: 'Fe_utrnno',
                    field: 'fe_utrnno',
                    type: PlutoColumnType.text(),
                    width: 140,
                  ),
                  PlutoColumn(
                    title: 'Bo_utrnno',
                    field: 'bo_utrnno',
                    type: PlutoColumnType.text(),
                    width: 140,
                  ),
                ],
                rows: activeRows.map((r) => r.toPlutoRow()).toList(),
                onLoaded: (event) {
                  _gridStateManager = event.stateManager;
                  _gridStateManager.setShowColumnFilter(true);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
