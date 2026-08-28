import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/widgets/glass_card.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/model/dispute_batch_model.dart';
import '../../data/model/transaction_model.dart';
import '../controllers/dispute_provider.dart';

class CheckerPanelScreen extends ConsumerStatefulWidget {
  const CheckerPanelScreen({super.key});

  @override
  ConsumerState<CheckerPanelScreen> createState() => _CheckerPanelScreenState();
}

class _CheckerPanelScreenState extends ConsumerState<CheckerPanelScreen> {
  DisputeBatch? _selectedBatch;
  DisputeTrxn? _selectedTrxn;
  late PlutoGridStateManager _gridStateManager;

  // Selected item form controllers (CBS T24 style bottom pane)
  final _accountController = TextEditingController();
  final _valueDateController = TextEditingController();
  final _amountController = TextEditingController();
  final _txnCodeController = TextEditingController();
  final _narrative1Controller = TextEditingController();
  final _narrative2Controller = TextEditingController();
  final _customerController = TextEditingController();
  final _accountOfficerController = TextEditingController();
  final _categoryController = TextEditingController();
  final _ourRefController = TextEditingController();
  String _selectedDebitCredit = 'D';

  final TextEditingController _rejectionReasonController = TextEditingController();

  @override
  void dispose() {
    _accountController.dispose();
    _valueDateController.dispose();
    _amountController.dispose();
    _txnCodeController.dispose();
    _narrative1Controller.dispose();
    _narrative2Controller.dispose();
    _customerController.dispose();
    _accountOfficerController.dispose();
    _categoryController.dispose();
    _ourRefController.dispose();
    _rejectionReasonController.dispose();
    super.dispose();
  }

  void _populateFormWithTrxn(DisputeTrxn trxn) {
    setState(() {
      _selectedTrxn = trxn;
      _accountController.text = trxn.effectiveAccount;
      _valueDateController.text = trxn.valueDate.isNotEmpty ? trxn.valueDate : DateFormat('dd MMM yyyy').format(DateTime.now()).toUpperCase();
      _amountController.text = NumberFormat('#,##0.00').format(trxn.amount);
      _txnCodeController.text = trxn.txnCode;
      _narrative1Controller.text = trxn.narrative1;
      _narrative2Controller.text = trxn.narrative2;
      _customerController.text = trxn.customer;
      _accountOfficerController.text = trxn.accountOfficer;
      _categoryController.text = trxn.category;
      _ourRefController.text = trxn.ourReference;
      _selectedDebitCredit = trxn.type;
    });
  }

  Future<void> _authorizeBatch() async {
    if (_selectedBatch == null || _selectedBatch!.objectId == null) return;

    if (!_selectedBatch!.isBalanced) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 28),
              SizedBox(width: 10),
              Text('Out of Balance Warning'),
            ],
          ),
          content: const Text(
            'The total Debits and Credits in this batch do not balance! Are you sure you want to authorize this batch?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Authorize Anyway', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    try {
      await ref
          .read(disputeBatchesNotifierProvider.notifier)
          .authorizeBatch(batchObjectId: _selectedBatch!.objectId!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Batch ${_selectedBatch!.batchNumber} AUTHORIZED successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() {
          _selectedBatch = null;
          _selectedTrxn = null;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Authorization error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showRejectDialog() {
    if (_selectedBatch == null || _selectedBatch!.objectId == null) return;
    _rejectionReasonController.clear();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.cancel_outlined, color: Colors.red),
            SizedBox(width: 10),
            Text('Reject / Send for Correction', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Batch / Ticket ID: ${_selectedBatch!.batchNumber}',
                style: const TextStyle(fontWeight: FontWeight.bold, color: CboColors.primaryBlue)),
            const SizedBox(height: 12),
            const Text('Enter correction comments / rejection reason (Required):',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            TextField(
              controller: _rejectionReasonController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'e.g., Credit and Debit out of balance by ETB 1,000. Please verify account ETB1764400020478...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                fillColor: const Color(0xFFF9FBFD),
                filled: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final comment = _rejectionReasonController.text.trim();
              if (comment.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a comment for Maker correction.')),
                );
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref
                    .read(disputeBatchesNotifierProvider.notifier)
                    .rejectBatch(
                      batchObjectId: _selectedBatch!.objectId!,
                      comment: comment,
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Batch ${_selectedBatch!.batchNumber} REJECTED with correction comment.'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                  setState(() {
                    _selectedBatch = null;
                    _selectedTrxn = null;
                  });
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Rejection error: $e'), backgroundColor: Colors.red),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Confirm Rejection', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final batchesAsync = ref.watch(disputeBatchesNotifierProvider);
    final currentUser = ref.watch(currentUserProvider);

    return ResponsiveShell(
      currentRoute: '/dispute_checker',
      title: 'Dispute Management - Checker Portal',
      subtitle: 'Inspect itemized DC transactions, verify debit/credit balance, authorize or request corrections',
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          tooltip: 'Refresh',
          onPressed: () => ref.read(disputeBatchesNotifierProvider.notifier).refresh(),
        ),
      ],
      body: batchesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error loading batches: $err')),
        data: (batches) {
          // If no batch is selected, show list of batches ready for Checker review
          if (_selectedBatch == null) {
            return _buildBatchSelectionList(batches, currentUser?.username);
          }

          // Otherwise show the CBS T24 Master-Detail View
          return _buildCbsMasterDetailView(_selectedBatch!);
        },
      ),
    );
  }

  Widget _buildBatchSelectionList(List<DisputeBatch> batches, String? currentUsername) {
    final fmt = NumberFormat('#,##0.00');

    // Checkers can view all batches or those assigned to them
    final assignedToMe = batches.where((b) =>
        b.assignedTo == currentUsername ||
        b.status == 'ASSIGNED' ||
        b.status == 'NEW').toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                    child: const Icon(Icons.fact_check_rounded, color: CboColors.primaryBlue, size: 32),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Dispute Review & Authorization Queue',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CboColors.primaryBlue),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Select any assigned Dispute Batch below to open the CBS T24 Master-Detail inspection view and verify debit/credit balance.',
                          style: TextStyle(fontSize: 13, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          if (assignedToMe.isEmpty)
            Container(
              height: 250,
              alignment: Alignment.center,
              child: const Text('No batches awaiting review for your account.',
                  style: TextStyle(color: Colors.grey, fontSize: 16)),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assignedToMe.length,
              itemBuilder: (context, index) {
                final b = assignedToMe[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: b.isBalanced ? Colors.green.shade200 : Colors.red.shade200,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (b.isBalanced ? Colors.green : Colors.red).withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        b.isBalanced ? Icons.check_circle_outline : Icons.error_outline,
                        color: b.isBalanced ? Colors.green : Colors.red,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(b.batchNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: b.isBalanced ? Colors.green.shade50 : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            b.isBalanced ? 'Balanced' : 'Out of Balance',
                            style: TextStyle(
                              color: b.isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        'Maker: ${b.madeBy} | Items: ${b.transactionCount} | DR: ETB ${fmt.format(b.totalDebitAmount)} | CR: ETB ${fmt.format(b.totalCreditAmount)} | Status: ${b.status}',
                      ),
                    ),
                    trailing: ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedBatch = b;
                        });
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16, color: Colors.white),
                      label: const Text('Open in CBS Grid', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: CboColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildCbsMasterDetailView(DisputeBatch batch) {
    final trxnAsync = ref.watch(batchTransactionsProvider(batch.objectId ?? batch.batchNumber));
    final fmt = NumberFormat('#,##0.00');

    return Column(
      children: [
        // Top T24 Action Toolbar & Batch Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: const Color(0xFF003366),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                tooltip: 'Back to Batch Queue',
                onPressed: () {
                  setState(() {
                    _selectedBatch = null;
                    _selectedTrxn = null;
                  });
                },
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amend Journal - Head Office - R22 [${batch.batchNumber}]',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  Text(
                    'Maker: ${batch.madeBy} | Count: ${batch.transactionCount} transactions | Status: ${batch.status}',
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                ],
              ),
              const Spacer(),

              // Balance Chip
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: batch.isBalanced ? Colors.green.shade800 : Colors.red.shade800,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(batch.isBalanced ? Icons.check : Icons.warning_amber, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      'DR: ${fmt.format(batch.totalDebitAmount)} | CR: ${fmt.format(batch.totalCreditAmount)}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // Checker Actions: Reject & Authorize
              OutlinedButton.icon(
                onPressed: _showRejectDialog,
                icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent, size: 16),
                label: const Text('Reject / Correction', style: TextStyle(color: Colors.redAccent)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  backgroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _authorizeBatch,
                icon: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 16),
                label: const Text('Authorize / Approve', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                ),
              ),
            ],
          ),
        ),

        // Split View: Top Grid (CBS T24 Table) + Bottom Details Form
        Expanded(
          child: trxnAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error loading transactions: $err')),
            data: (transactions) {
              if (transactions.isEmpty) {
                return const Center(child: Text('No transaction records in this batch'));
              }

              // Default select first item if none selected
              if (_selectedTrxn == null && transactions.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _populateFormWithTrxn(transactions.first);
                });
              }

              return Column(
                children: [
                  // Top PlutoGrid: Matching CBS BrowserServlet table
                  Expanded(
                    flex: 5,
                    child: PlutoGrid(
                      columns: [
                        PlutoColumn(
                          title: 'Transaction ID',
                          field: 'transactionId',
                          type: PlutoColumnType.text(),
                          width: 180,
                        ),
                        PlutoColumn(
                          title: 'Customer',
                          field: 'customer',
                          type: PlutoColumnType.text(),
                          width: 120,
                        ),
                        PlutoColumn(
                          title: 'Name',
                          field: 'name',
                          type: PlutoColumnType.text(),
                          width: 140,
                        ),
                        PlutoColumn(
                          title: 'Amount LCY',
                          field: 'amountLcy',
                          type: PlutoColumnType.currency(symbol: 'ETB '),
                          width: 140,
                        ),
                        PlutoColumn(
                          title: 'Amount FCY',
                          field: 'amountFcy',
                          type: PlutoColumnType.number(),
                          width: 110,
                        ),
                        PlutoColumn(
                          title: 'Value Date',
                          field: 'valueDate',
                          type: PlutoColumnType.text(),
                          width: 120,
                        ),
                        PlutoColumn(
                          title: 'Record Status',
                          field: 'recordStatus',
                          type: PlutoColumnType.text(),
                          width: 120,
                        ),
                      ],
                      rows: transactions.map((t) {
                        return PlutoRow(
                          cells: {
                            'transactionId': PlutoCell(value: t.transactionId),
                            'customer': PlutoCell(value: t.customer),
                            'name': PlutoCell(value: t.name),
                            'amountLcy': PlutoCell(value: t.amount),
                            'amountFcy': PlutoCell(value: 0),
                            'valueDate': PlutoCell(value: t.valueDate.isNotEmpty ? t.valueDate : '20260827'),
                            'recordStatus': PlutoCell(value: t.recordStatus),
                          },
                        );
                      }).toList(),
                      onLoaded: (event) {
                        _gridStateManager = event.stateManager;
                        _gridStateManager.setShowColumnFilter(true);
                      },
                      onRowChecked: (event) {
                        final row = event.row;
                        if (row != null) {
                          final txnId = row.cells['transactionId']?.value.toString();
                          final match = transactions.firstWhere((element) => element.transactionId == txnId,
                              orElse: () => transactions.first);
                          _populateFormWithTrxn(match);
                        }
                      },
                      onSelected: (event) {
                        final row = event.row;
                        if (row != null) {
                          final txnId = row.cells['transactionId']?.value.toString();
                          final match = transactions.firstWhere((element) => element.transactionId == txnId,
                              orElse: () => transactions.first);
                          _populateFormWithTrxn(match);
                        }
                      },
                    ),
                  ),

                  // Bottom Form: CBS T24 / Temenos Inspection Panel
                  Expanded(
                    flex: 5,
                    child: _buildCbsBottomForm(batch),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCbsBottomForm(DisputeBatch batch) {
    final trxn = _selectedTrxn;

    return Container(
      color: const Color(0xFFF7F9FC),
      child: Column(
        children: [
          // Sub-Header Bar (Amend DC... Head Office)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFE2EBF4),
            child: Row(
              children: [
                Text(
                  'Amend  ${trxn?.transactionId ?? batch.batchNumber}  LCY DR/CR FCY (Head Office)',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF003366)),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    border: Border.all(color: Colors.red.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '? ID=: PREVIOUS USERS WORK WILL BE LOST',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Form Tab bar: Amend | Audit
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Field 1: Account
                      Expanded(
                        flex: 4,
                        child: _buildCbsFormField(
                          label: 'Account',
                          controller: _accountController,
                          suffixIcon: Icons.search,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Field 2: Value Date
                      Expanded(
                        flex: 3,
                        child: _buildCbsFormField(
                          label: 'Value Date',
                          controller: _valueDateController,
                          suffixIcon: Icons.calendar_today,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Field 3: Debit / Credit
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Debit / Credit *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('C (Credit)'),
                                  selected: _selectedDebitCredit == 'C',
                                  onSelected: (selected) {
                                    if (selected) setState(() => _selectedDebitCredit = 'C');
                                  },
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('D (Debit)'),
                                  selected: _selectedDebitCredit == 'D',
                                  onSelected: (selected) {
                                    if (selected) setState(() => _selectedDebitCredit = 'D');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Field 4: Lcy Amount
                      Expanded(
                        flex: 4,
                        child: _buildCbsFormField(
                          label: 'Lcy Amount',
                          controller: _amountController,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Field 5: Transaction Cde
                      Expanded(
                        flex: 3,
                        child: _buildCbsFormField(
                          label: 'Transaction Cde *',
                          controller: _txnCodeController,
                          helperText: _selectedDebitCredit == 'D' ? 'Miscellaneous Debits' : 'Miscellaneous Credits',
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Field 6: Currency & Position Type
                      Expanded(
                        flex: 3,
                        child: _buildCbsFormField(
                          label: 'Currency / Pos',
                          controller: TextEditingController(text: 'ETB / TR'),
                          readOnly: true,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: [
                      // Field 7: Narrative 1
                      Expanded(
                        child: _buildCbsFormField(
                          label: 'Narrative.1',
                          controller: _narrative1Controller,
                        ),
                      ),
                      const SizedBox(width: 14),
                      // Field 8: Narrative 2
                      Expanded(
                        child: _buildCbsFormField(
                          label: 'Narrative.2',
                          controller: _narrative2Controller,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCbsFormField({
    required String label,
    required TextEditingController controller,
    String? helperText,
    IconData? suffixIcon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black87)),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          readOnly: readOnly,
          style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4), borderSide: BorderSide(color: Colors.grey.shade400)),
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            filled: true,
            suffixIcon: suffixIcon != null ? Icon(suffixIcon, size: 16) : null,
            helperText: helperText,
            helperStyle: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ),
      ],
    );
  }
}