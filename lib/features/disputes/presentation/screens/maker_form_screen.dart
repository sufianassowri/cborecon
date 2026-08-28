import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/datasources/dispute_file_parser.dart';
import '../../data/model/dispute_batch_model.dart';
import '../controllers/dispute_provider.dart';

class MakerFormScreen extends ConsumerStatefulWidget {
  const MakerFormScreen({super.key});

  @override
  ConsumerState<MakerFormScreen> createState() => _MakerFormScreenState();
}

class _MakerFormScreenState extends ConsumerState<MakerFormScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // File Upload State
  String? _selectedFileName;
  ParsedDisputeBatchResult? _parsedResult;
  bool _isUploading = false;
  double _uploadProgress = 0.0;
  String _uploadStatusMessage = '';

  // Manual Raw Text Input Controller
  final TextEditingController _pasteTextController = TextEditingController();

  // Sample data button helper
  static const String sample6LineText = '''ETB1764400020478
D
38400
1
Deposit Dispute
Deposit Dispute
ETB1000500020478
D
19800
1
Deposit Dispute
Deposit Dispute
ETB1000500010013
D
1000
1
Deposit Dispute
Deposit Dispute
1051800016565
C
38400
51
Deposit Dispute
Deposit Dispute
1051800016565
C
19800
51
Deposit Dispute
Deposit Dispute
1006300315056
C
1000
51
Deposit Dispute
Deposit Dispute''';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _pasteTextController.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['txt', 'csv', 'xlsx', 'xls', 'log'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        final currentUser = ref.read(currentUserProvider);
        final makerName = currentUser?.username ?? 'Sufian_Maker';

        setState(() {
          _selectedFileName = file.name;
        });

        if (file.extension == 'xlsx' || file.extension == 'xls') {
          if (file.bytes != null) {
            final parsed = DisputeFileParser.parseExcelBytes(
              bytes: file.bytes!,
              fileName: file.name,
              makerUsername: makerName,
            );
            setState(() {
              _parsedResult = parsed;
            });
          }
        } else {
          // Plain text / CSV
          String text = '';
          if (file.bytes != null) {
            text = utf8.decode(file.bytes!, allowMalformed: true);
          }
          final parsed = DisputeFileParser.parseRawText(
            rawText: text,
            fileName: file.name,
            makerUsername: makerName,
          );
          setState(() {
            _parsedResult = parsed;
          });
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error reading file: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _parsePastedText() {
    final text = _pasteTextController.text.trim();
    if (text.isEmpty) return;

    final currentUser = ref.read(currentUserProvider);
    final makerName = currentUser?.username ?? 'Sufian_Maker';

    final parsed = DisputeFileParser.parseRawText(
      rawText: text,
      fileName: 'Pasted_Dispute_${DateFormat('HHmmss').format(DateTime.now())}.txt',
      makerUsername: makerName,
    );

    setState(() {
      _selectedFileName = 'Direct Text Input';
      _parsedResult = parsed;
    });
  }

  void _loadSampleData() {
    _pasteTextController.text = sample6LineText;
    _parsePastedText();
  }

  Future<void> _submitBatchToBack4App() async {
    if (_parsedResult == null || _parsedResult!.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No valid transactions parsed to upload.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _uploadStatusMessage = 'Initializing Back4App Dispute Batch...';
    });

    try {
      final notifier = ref.read(disputeBatchesNotifierProvider.notifier);
      final savedBatch = await notifier.uploadBatch(
        batch: _parsedResult!.batch,
        items: _parsedResult!.items,
        onProgress: (current, total) {
          setState(() {
            _uploadProgress = current / total;
            _uploadStatusMessage =
                'Saving transactions to b4app ($current / $total)...';
          });
        },
      );

      setState(() {
        _isUploading = false;
        _parsedResult = null;
        _selectedFileName = null;
        _pasteTextController.clear();
      });

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.check_circle_rounded, color: Colors.green, size: 28),
              SizedBox(width: 10),
              Text('Batch Registered Successfully', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Ticket / Batch ID: ${savedBatch.batchNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryBlue)),
              const SizedBox(height: 8),
              Text('Total Count: ${savedBatch.transactionCount} transactions (Single Batch Header)'),
              Text('Debit Sum: ETB ${NumberFormat('#,##0.00').format(savedBatch.totalDebitAmount)}'),
              Text('Credit Sum: ETB ${NumberFormat('#,##0.00').format(savedBatch.totalCreditAmount)}'),
              Text('Status: PENDING ASSIGNMENT', style: TextStyle(color: Colors.amber[800], fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const Text('The batch is now pending review and assignment by Operations Manager.',
                  style: TextStyle(fontSize: 13, color: Colors.grey)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _tabController.animateTo(1); // Switch to History Tab
              },
              style: ElevatedButton.styleFrom(backgroundColor: CboColors.primaryBlue),
              child: const Text('View Batch History', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    } catch (e) {
      setState(() {
        _isUploading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Upload failed: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(currentUserProvider);

    return ResponsiveShell(
      currentRoute: '/dispute_maker',
      title: 'Dispute Management - Maker Portal',
      subtitle: 'Upload multi-line dispute files, auto-aggregate single batch DC tickets & track review workflow',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh Batch History',
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
                  icon: Icon(Icons.cloud_upload_rounded),
                  text: 'Upload & Parse Dispute File',
                ),
                Tab(
                  icon: Icon(Icons.history_rounded),
                  text: 'My Batches & Approval Status',
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUploadTab(),
                _buildHistoryTab(currentUser?.username ?? 'Sufian_Maker'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          GlassCard(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CboColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.post_add_rounded, color: CboColors.primaryBlue, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Maker Upload & Auto-Aggregation Engine',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CboColors.primaryBlue),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Uploads are saved to Back4App (b4app) as a single Batch / Ticket / DC header containing 100s or 1000s of child transaction records.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _loadSampleData,
                    icon: const Icon(Icons.data_object_rounded, size: 18),
                    label: const Text('Load 6-Line Sample'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: CboColors.primaryCyan,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Upload Option Selection (File Picker vs Direct Text Area)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Left Column: File Dropzone & Paste Box
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    // File Pick Button Card
                    InkWell(
                      onTap: _pickFile,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(28),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _selectedFileName != null ? CboColors.primaryCyan : Colors.grey.shade300,
                            width: 2,
                            strokeAlign: BorderSide.strokeAlignInside,
                          ),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              _selectedFileName != null ? Icons.task_alt_rounded : Icons.file_upload_outlined,
                              size: 48,
                              color: _selectedFileName != null ? Colors.green : CboColors.primaryBlue,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _selectedFileName ?? 'Click to browse dispute file (.txt, .csv, .xlsx)',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: _selectedFileName != null ? Colors.green.shade800 : Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Supports continuous 6-line dispute records or standard settlement CSV/Excel formats',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Direct Paste Area
                    GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Or Paste Raw 6-Line Dispute Content',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                TextButton.icon(
                                  onPressed: _parsePastedText,
                                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                                  label: const Text('Parse Text'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _pasteTextController,
                              maxLines: 8,
                              style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'ETB1764400020478\nD\n38400\n1\nDeposit Dispute\nDeposit Dispute\n...',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                contentPadding: const EdgeInsets.all(12),
                                fillColor: const Color(0xFFF9FBFD),
                                filled: true,
                              ),
                              onChanged: (_) => _parsePastedText(),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 20),

              // Right Column: Parsed Batch Summary & Sub-DC Items
              Expanded(
                flex: 7,
                child: _parsedResult == null
                    ? Container(
                        height: 380,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.inventory_2_outlined, size: 60, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('No file or text parsed yet',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.grey)),
                              SizedBox(height: 4),
                              Text('Upload or paste dispute lines on the left to see the aggregated batch',
                                  style: TextStyle(fontSize: 13, color: Colors.grey)),
                            ],
                          ),
                        ),
                      )
                    : _buildParsedSummaryView(),
              ),
            ],
          ),

          if (_isUploading) ...[
            const SizedBox(height: 20),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_uploadStatusMessage, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text('${(_uploadProgress * 100).toInt()}%',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryBlue)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    LinearProgressIndicator(
                      value: _uploadProgress > 0 ? _uploadProgress : null,
                      backgroundColor: Colors.grey.shade200,
                      color: CboColors.primaryBlue,
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
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

  Widget _buildParsedSummaryView() {
    final batch = _parsedResult!.batch;
    final items = _parsedResult!.items;
    final fmt = NumberFormat('#,##0.00');

    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Batch Header & Save Button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: CboColors.primaryBlue,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            batch.batchNumber,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: batch.isBalanced ? Colors.green.shade100 : Colors.red.shade100,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            batch.isBalanced ? 'BALANCED (DR = CR)' : 'OUT OF BALANCE',
                            style: TextStyle(
                              color: batch.isBalanced ? Colors.green.shade900 : Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Single Batch Ticket: ${batch.transactionCount} transactions detected',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _isUploading ? null : _submitBatchToBack4App,
                  icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
                  label: const Text('Save Batch to b4app', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.shade700,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Financial Summary Metrics
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F5E9),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Debit (DR)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('ETB ${fmt.format(batch.totalDebitAmount)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.green)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE3F2FD),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.blue.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Total Credit (CR)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('ETB ${fmt.format(batch.totalCreditAmount)}',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: CboColors.primaryBlue)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: batch.isBalanced ? const Color(0xFFF1F8E9) : const Color(0xFFFFEBEE),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: batch.isBalanced ? Colors.green.shade200 : Colors.red.shade200,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Balance Difference', style: TextStyle(fontSize: 11, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(
                          'ETB ${fmt.format((batch.totalDebitAmount - batch.totalCreditAmount).abs())}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: batch.isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Line Items Preview Table (Sub-DC IDs)
            const Text(
              'Parsed Transaction Line Items Preview (DC Records):',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 8),
            Container(
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final it = items[index];
                  final isDebit = it.type == 'D';
                  return ListTile(
                    dense: true,
                    leading: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isDebit ? Colors.red.shade50 : Colors.green.shade50,
                        border: Border.all(color: isDebit ? Colors.red.shade300 : Colors.green.shade300),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        it.type,
                        style: TextStyle(
                          color: isDebit ? Colors.red.shade900 : Colors.green.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(it.transactionId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(width: 12),
                        Text(it.effectiveAccount, style: const TextStyle(fontSize: 13, fontFamily: 'monospace')),
                      ],
                    ),
                    subtitle: Text('${it.narrative1} | Code: ${it.txnCode} | Status: ${it.recordStatus}'),
                    trailing: Text(
                      'ETB ${fmt.format(it.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryTab(String currentMaker) {
    final batchesAsync = ref.watch(disputeBatchesNotifierProvider);
    final fmt = NumberFormat('#,##0.00');

    return batchesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error loading batches: $err')),
      data: (batches) {
        if (batches.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.history_rounded, size: 64, color: Colors.grey),
                SizedBox(height: 12),
                Text('No dispute batches uploaded yet', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: batches.length,
          itemBuilder: (context, index) {
            final b = batches[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ExpansionTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _getStatusColor(b.status).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_getStatusIcon(b.status), color: _getStatusColor(b.status)),
                ),
                title: Row(
                  children: [
                    Text(b.batchNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(width: 10),
                    _buildStatusChip(b.status),
                  ],
                ),
                subtitle: Text(
                  'Created: ${DateFormat('yyyy-MM-dd HH:mm').format(b.madeAt)} | ${b.transactionCount} transactions | Total: ETB ${fmt.format(b.totalDebitAmount)}',
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Assigned To Checker: ${b.assignedTo ?? "Not yet assigned"}',
                                style: const TextStyle(fontWeight: FontWeight.w600)),
                            if (b.assignedAt != null)
                              Text('Assigned: ${DateFormat('yyyy-MM-dd HH:mm').format(b.assignedAt!)}',
                                  style: const TextStyle(color: Colors.grey, fontSize: 12)),
                          ],
                        ),
                        if (b.checkerComment != null && b.checkerComment!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.feedback_rounded, color: Colors.red, size: 20),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text('Checker Comment: ${b.checkerComment}',
                                      style: TextStyle(color: Colors.red.shade900, fontWeight: FontWeight.w500)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'NEW':
      case 'PENDING_ASSIGNMENT':
        return Colors.orange;
      case 'ASSIGNED':
        return CboColors.primaryBlue;
      case 'AUTHORIZED':
        return Colors.green;
      case 'REJECTED':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'NEW':
      case 'PENDING_ASSIGNMENT':
        return Icons.hourglass_top_rounded;
      case 'ASSIGNED':
        return Icons.assignment_ind_rounded;
      case 'AUTHORIZED':
        return Icons.check_circle_rounded;
      case 'REJECTED':
        return Icons.cancel_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }

  Widget _buildStatusChip(String status) {
    final color = _getStatusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11),
      ),
    );
  }
}