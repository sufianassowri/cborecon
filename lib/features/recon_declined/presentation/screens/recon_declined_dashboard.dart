import 'dart:typed_data';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';

import '../../../../core/constants/cbo_colors.dart';
import '../../../../core/utils/csv_parser_util.dart';
import '../../../../core/utils/file_saver_util.dart';
import '../../../../core/widgets/cbo_file_dropzone.dart';
import '../../../../core/widgets/cbo_metric_card.dart';
import '../../../../core/widgets/guided_recon_modal.dart';
import '../../../../core/widgets/responsive_shell.dart';
import '../../domain/entities/recon_declined_models.dart';
import '../../domain/usecases/reconcile_declined_usecase.dart';

enum ReconDeclinedFilter { matched, debitable, excessOnly, declinedOnly, all }

class ReconDeclinedDashboard extends StatefulWidget {
  const ReconDeclinedDashboard({super.key});

  @override
  State<ReconDeclinedDashboard> createState() => _ReconDeclinedDashboardState();
}

class _ReconDeclinedDashboardState extends State<ReconDeclinedDashboard> {
  final ReconcileDeclinedUseCase _useCase = ReconcileDeclinedUseCase();

  List<Map<String, dynamic>> _excessRaw = [];
  List<Map<String, dynamic>> _declinedRaw = [];
  String? _excessFileName;
  String? _declinedFileName;

  ReconDeclinedResult? _result;
  bool _isProcessing = false;
  bool _hasExecuted = false;
  ReconDeclinedFilter _selectedFilter = ReconDeclinedFilter.matched;

  final NumberFormat _currencyFormat = NumberFormat('#,##0.00', 'en_US');
  final NumberFormat _countFormat = NumberFormat('#,##0', 'en_US');

  void _showGuide() {
    GuidedReconModal.show(
      context,
      moduleTitle: 'Declined Transaction Reconciliation Guide',
      modulePurpose:
          'Automates settlement debit calculation across Excess GL accounts and Cash at ATM accounts for declined transactions. Derives accounts based on CARD.ACC.ID hardware classification (NCR & CRM) and models the exact debit split.',
      steps: const [
        ReconStepGuide(
          step: 1,
          title: 'Load Excess Account Detail File',
          format: '.CSV / .XLSX / .XLS',
          description:
              'Downloaded excess account ledger. Required columns: "Account No" and "Account Balance". Optional: "Customer", "Name", "Product", "Ccy", "Account Officer".',
          expectedColumns: ['Account No', 'Account Balance'],
        ),
        ReconStepGuide(
          step: 2,
          title: 'Load Declined Transaction Report',
          format: '.CSV / .XLSX / .XLS',
          description:
              'Declined transactions in Pivot or Raw Detail format. In both formats, CARD.ACC.ID is used to derive hardware accounts.',
          expectedColumns: ['CARD.ACC.ID', 'TXN.AMOUNT'],
        ),
        ReconStepGuide(
          step: 3,
          title: 'Automatic Hardware Account Derivation',
          format: 'Automatic',
          description:
              'NCR (contains "N"): Excess ETB17643..., ATM ETB10002...\nCRM (contains "C"): Excess ETB17644..., ATM ETB10005...',
        ),
        ReconStepGuide(
          step: 4,
          title: 'Settlement Debit Split Logic',
          format: 'Automatic',
          description:
              'Remaining = Excess Balance - Total Declined\n• If Remaining >= 0: Excess Account debited with Total Declined (ATM Debit = 0).\n• If Remaining < 0 & Balance > 0: Excess debited with Balance, ATM debited with shortage.\n• If Balance <= 0: ATM Account debited with full amount.',
        ),
      ],
      tips: const [
        'Excess account derivation strictly depends on CARD.ACC.ID (not CREDIT.ACCT.NO).',
        'Both Pivot format (aggregated) and raw detail format are automatically detected.',
        'Negative or zero excess balances automatically re-route 100% of debit to the Cash at ATM account.',
        'Export multi-sheet Excel reports containing matched settlements, excess-only, and declined-only records.',
      ],
    );
  }

  List<List<dynamic>> _parseBytesToTable(Uint8List bytes, String fileName) {
    if (fileName.toLowerCase().endsWith('.xlsx') || fileName.toLowerCase().endsWith('.xls')) {
      try {
        final excel = excel_pkg.Excel.decodeBytes(bytes);
        for (final table in excel.tables.keys) {
          final sheet = excel.tables[table];
          if (sheet != null && sheet.rows.isNotEmpty) {
            return sheet.rows.map((row) {
              return row.map((cell) => cell?.value?.toString().trim() ?? '').toList();
            }).toList();
          }
        }
      } catch (e) {
        debugPrint('Excel decoding fallback: $e');
      }
    }
    return CsvParserUtil.parseBytes(bytes);
  }

  bool _isHeaderRow(List<dynamic> row, bool isExcess) {
    if (row.isEmpty) return false;
    final firstCell = row[0]?.toString().trim().toUpperCase() ?? '';
    final secondCell = row.length > 1 ? row[1]?.toString().trim().toUpperCase() ?? '' : '';

    if (isExcess) {
      if (firstCell.contains('ACCOUNT') ||
          firstCell.contains('ACCT') ||
          firstCell == 'NO' ||
          firstCell == 'ACC' ||
          firstCell == 'CUSTOMER') {
        return true;
      }
      if (firstCell.startsWith('ETB') ||
          firstCell.startsWith('1764') ||
          firstCell.startsWith('1000') ||
          RegExp(r'^\d{8,}$').hasMatch(firstCell)) {
        return false;
      }
    } else {
      // Declined file
      if (firstCell.contains('CARD') ||
          firstCell.contains('TERMINAL') ||
          firstCell.contains('TRANS') ||
          firstCell.contains('REF') ||
          firstCell.contains('VALUE') ||
          firstCell.contains('DEBIT') ||
          firstCell.contains('CREDIT') ||
          firstCell.contains('ROW LABELS') ||
          firstCell.contains('ROW_LABELS') ||
          firstCell == 'LABELS') {
        return true;
      }
      if (firstCell.startsWith('ETB') ||
          firstCell.startsWith('1000') ||
          firstCell.startsWith('1764') ||
          (firstCell.length >= 6 &&
              firstCell.length <= 12 &&
              (firstCell.contains('N') || firstCell.contains('C')) &&
              RegExp(r'\d{3,}$').hasMatch(firstCell))) {
        return false;
      }
    }

    if (secondCell.isNotEmpty) {
      final cleanSecond = secondCell.replaceAll(',', '').replaceAll('ETB', '').trim();
      if (double.tryParse(cleanSecond) != null) {
        return false;
      }
    }

    return true;
  }

  Future<void> _pickFile(bool isExcess) async {
    final res = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
      withData: true,
    );
    if (res != null && res.files.single.bytes != null) {
      final fileName = res.files.single.name;
      final data = _parseBytesToTable(res.files.single.bytes!, fileName);
      if (data.isEmpty) return;

      List<String> headers;
      List<List<dynamic>> dataRows;

      final bool hasHeaders = _isHeaderRow(data[0], isExcess);
      if (hasHeaders) {
        headers = data[0].map((e) => e.toString().trim()).toList();
        dataRows = data.skip(1).toList();
      } else {
        if (isExcess) {
          headers = ['Account No', 'Account Balance'];
          for (int i = 2; i < data[0].length; i++) {
            headers.add('COL_$i');
          }
        } else {
          headers = ['CARD.ACC.ID', 'TXN.AMOUNT'];
          for (int i = 2; i < data[0].length; i++) {
            headers.add('COL_$i');
          }
        }
        dataRows = data;
      }

      final mapped = dataRows
          .where((row) => row.any((cell) => cell.toString().trim().isNotEmpty))
          .map((row) {
            final m = <String, dynamic>{};
            for (int i = 0; i < headers.length; i++) {
              if (i < row.length) m[headers[i]] = row[i];
            }
            return m;
          })
          .where((m) {
            final firstVal = m.values.isNotEmpty ? m.values.first.toString().trim().toUpperCase() : '';
            return firstVal.isNotEmpty &&
                firstVal != 'GRAND TOTAL' &&
                firstVal != 'TOTAL' &&
                !firstVal.startsWith('TOTAL ');
          })
          .toList();

      setState(() {
        _hasExecuted = false;
        if (isExcess) {
          _excessRaw = mapped;
          _excessFileName = fileName;
        } else {
          _declinedRaw = mapped;
          _declinedFileName = fileName;
        }
      });
    }
  }

  void _runReconciliation() {
    if (_excessRaw.isEmpty || _declinedRaw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please upload both Excess Account Detail and Declined Transaction files.')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    final result = _useCase(_excessRaw, _declinedRaw);

    setState(() {
      _result = result;
      _isProcessing = false;
      _hasExecuted = true;
      _selectedFilter = ReconDeclinedFilter.matched;
    });
  }

  List<PlutoColumn> _buildColumns() {
    switch (_selectedFilter) {
      case ReconDeclinedFilter.matched:
        return [
          PlutoColumn(
            title: 'Status',
            field: 'status',
            type: PlutoColumnType.text(),
            width: 110,
            enableEditingMode: false,
            renderer: (ctx) => _statusBadge('MATCHED'),
          ),
          PlutoColumn(
            title: 'CARD.ACC.ID',
            field: 'card_acc_id',
            type: PlutoColumnType.text(),
            width: 130,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Hardware',
            field: 'hardware',
            type: PlutoColumnType.text(),
            width: 100,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Excess Account',
            field: 'excess_acc',
            type: PlutoColumnType.text(),
            width: 180,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Debit Amount (Excess)',
            field: 'excess_debit',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 170,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'ATM Account',
            field: 'atm_acc',
            type: PlutoColumnType.text(),
            width: 180,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Debit Amount (ATM)',
            field: 'atm_debit',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 170,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Difference (Balance - Total Declined)',
            field: 'difference_formula',
            type: PlutoColumnType.text(),
            width: 240,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Excess Balance',
            field: 'excess_balance',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 150,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Total Declined',
            field: 'total_declined',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 150,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Customer',
            field: 'customer',
            type: PlutoColumnType.text(),
            width: 120,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Customer Name',
            field: 'name',
            type: PlutoColumnType.text(),
            width: 180,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Product',
            field: 'product',
            type: PlutoColumnType.text(),
            width: 140,
            enableEditingMode: false,
          ),
        ];

      case ReconDeclinedFilter.debitable:
        return [
          PlutoColumn(
            title: 'DebitAccount',
            field: 'debit_account',
            type: PlutoColumnType.text(),
            width: 220,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'debitAmount',
            field: 'debit_amount',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 180,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Account Type',
            field: 'account_type',
            type: PlutoColumnType.text(),
            width: 160,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Terminal (CARD.ACC.ID)',
            field: 'card_acc_id',
            type: PlutoColumnType.text(),
            width: 180,
            enableEditingMode: false,
          ),
        ];

      case ReconDeclinedFilter.excessOnly:
        return [
          PlutoColumn(
            title: 'Status',
            field: 'status',
            type: PlutoColumnType.text(),
            width: 130,
            enableEditingMode: false,
            renderer: (ctx) => _statusBadge('EXCESS ONLY'),
          ),
          PlutoColumn(
            title: 'Account No',
            field: 'account_no',
            type: PlutoColumnType.text(),
            width: 180,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Account Balance',
            field: 'balance',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 160,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Customer',
            field: 'customer',
            type: PlutoColumnType.text(),
            width: 130,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Customer Name',
            field: 'name',
            type: PlutoColumnType.text(),
            width: 200,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Product',
            field: 'product',
            type: PlutoColumnType.text(),
            width: 150,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Ccy',
            field: 'ccy',
            type: PlutoColumnType.text(),
            width: 90,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Account Officer',
            field: 'officer',
            type: PlutoColumnType.text(),
            width: 150,
            enableEditingMode: false,
          ),
        ];

      case ReconDeclinedFilter.declinedOnly:
        return [
          PlutoColumn(
            title: 'Status',
            field: 'status',
            type: PlutoColumnType.text(),
            width: 140,
            enableEditingMode: false,
            renderer: (ctx) => _statusBadge('DECLINED ONLY'),
          ),
          PlutoColumn(
            title: 'CARD.ACC.ID',
            field: 'card_acc_id',
            type: PlutoColumnType.text(),
            width: 140,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Hardware',
            field: 'hardware',
            type: PlutoColumnType.text(),
            width: 110,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Total Declined Amount',
            field: 'total_declined',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 180,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Derived Excess Account',
            field: 'derived_excess',
            type: PlutoColumnType.text(),
            width: 190,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Derived ATM Account',
            field: 'derived_atm',
            type: PlutoColumnType.text(),
            width: 190,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Txn Count',
            field: 'txn_count',
            type: PlutoColumnType.number(),
            width: 110,
            enableEditingMode: false,
          ),
        ];

      case ReconDeclinedFilter.all:
        return [
          PlutoColumn(
            title: 'Status',
            field: 'status',
            type: PlutoColumnType.text(),
            width: 140,
            enableEditingMode: false,
            renderer: (ctx) => _statusBadge(ctx.cell.value.toString()),
          ),
          PlutoColumn(
            title: 'Identifier (Terminal/Account)',
            field: 'identifier',
            type: PlutoColumnType.text(),
            width: 180,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Hardware',
            field: 'hardware',
            type: PlutoColumnType.text(),
            width: 110,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Excess Debit',
            field: 'excess_debit',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 150,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'ATM Debit',
            field: 'atm_debit',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 150,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Total Amount',
            field: 'amount',
            type: PlutoColumnType.currency(symbol: 'ETB '),
            width: 150,
            enableEditingMode: false,
          ),
          PlutoColumn(
            title: 'Formula / Notes',
            field: 'notes',
            type: PlutoColumnType.text(),
            width: 250,
            enableEditingMode: false,
          ),
        ];
    }
  }

  Widget _statusBadge(String val) {
    final bool isMatch = val == 'MATCHED';
    final bool isExcessOnly = val.contains('EXCESS');
    Color bg = isMatch
        ? CboColors.statusOkBg
        : (isExcessOnly ? const Color(0xFFFFF3E0) : CboColors.statusMissingBg);
    Color fg = isMatch
        ? CboColors.statusOkText
        : (isExcessOnly ? const Color(0xFFE65100) : CboColors.statusMissingText);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        val,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }

  List<PlutoRow> _buildRows() {
    if (_result == null) return [];

    switch (_selectedFilter) {
      case ReconDeclinedFilter.matched:
        return _result!.matched.map((m) {
          return PlutoRow(cells: {
            'status': PlutoCell(value: 'MATCHED'),
            'card_acc_id': PlutoCell(value: m.cardAccId),
            'hardware': PlutoCell(value: m.hardwareTypeName),
            'excess_acc': PlutoCell(value: m.excessAccount),
            'excess_debit': PlutoCell(value: m.excessDebitAmount),
            'atm_acc': PlutoCell(value: m.atmAccount),
            'atm_debit': PlutoCell(value: m.atmDebitAmount),
            'difference_formula': PlutoCell(value: m.differenceFormula),
            'excess_balance': PlutoCell(value: m.excessBalance),
            'total_declined': PlutoCell(value: m.totalDeclinedAmount),
            'customer': PlutoCell(value: m.customer),
            'name': PlutoCell(value: m.name),
            'product': PlutoCell(value: m.product),
          });
        }).toList();

      case ReconDeclinedFilter.debitable:
        return _result!.debitableAccounts.map((d) {
          return PlutoRow(cells: {
            'debit_account': PlutoCell(value: d.debitAccount),
            'debit_amount': PlutoCell(value: d.debitAmount),
            'account_type': PlutoCell(value: d.accountType),
            'card_acc_id': PlutoCell(value: d.cardAccId),
          });
        }).toList();

      case ReconDeclinedFilter.excessOnly:
        return _result!.excessOnly.map((e) {
          return PlutoRow(cells: {
            'status': PlutoCell(value: 'EXCESS ONLY'),
            'account_no': PlutoCell(value: e.accountNo),
            'balance': PlutoCell(value: e.accountBalance),
            'customer': PlutoCell(value: e.customer),
            'name': PlutoCell(value: e.name),
            'product': PlutoCell(value: e.product),
            'ccy': PlutoCell(value: e.ccy),
            'officer': PlutoCell(value: e.accountOfficer),
          });
        }).toList();

      case ReconDeclinedFilter.declinedOnly:
        return _result!.declinedOnly.map((d) {
          return PlutoRow(cells: {
            'status': PlutoCell(value: 'DECLINED ONLY'),
            'card_acc_id': PlutoCell(value: d.cardAccId),
            'hardware': PlutoCell(value: d.hardwareTypeName),
            'total_declined': PlutoCell(value: d.totalDeclinedAmount),
            'derived_excess': PlutoCell(value: d.derivedExcessAccount),
            'derived_atm': PlutoCell(value: d.derivedAtmAccount),
            'txn_count': PlutoCell(value: d.transactionCount),
          });
        }).toList();

      case ReconDeclinedFilter.all:
        final List<PlutoRow> allRows = [];

        for (final m in _result!.matched) {
          allRows.add(PlutoRow(cells: {
            'status': PlutoCell(value: 'MATCHED'),
            'identifier': PlutoCell(value: m.cardAccId),
            'hardware': PlutoCell(value: m.hardwareTypeName),
            'excess_debit': PlutoCell(value: m.excessDebitAmount),
            'atm_debit': PlutoCell(value: m.atmDebitAmount),
            'amount': PlutoCell(value: m.totalDeclinedAmount),
            'notes': PlutoCell(value: m.differenceFormula),
          }));
        }

        for (final d in _result!.declinedOnly) {
          allRows.add(PlutoRow(cells: {
            'status': PlutoCell(value: 'DECLINED ONLY'),
            'identifier': PlutoCell(value: d.cardAccId),
            'hardware': PlutoCell(value: d.hardwareTypeName),
            'excess_debit': PlutoCell(value: 0.0),
            'atm_debit': PlutoCell(value: d.totalDeclinedAmount),
            'amount': PlutoCell(value: d.totalDeclinedAmount),
            'notes': PlutoCell(value: 'Excess account not found in uploaded file'),
          }));
        }

        for (final e in _result!.excessOnly) {
          allRows.add(PlutoRow(cells: {
            'status': PlutoCell(value: 'EXCESS ONLY'),
            'identifier': PlutoCell(value: e.accountNo),
            'hardware': PlutoCell(value: '-'),
            'excess_debit': PlutoCell(value: 0.0),
            'atm_debit': PlutoCell(value: 0.0),
            'amount': PlutoCell(value: e.accountBalance),
            'notes': PlutoCell(value: 'No matching declined transactions for this excess account'),
          }));
        }

        return allRows;
    }
  }

  Future<void> _exportResults() async {
    if (_result == null || !_hasExecuted) return;

    final excel = excel_pkg.Excel.createExcel();

    // 1. Debitable Accounts Sheet (2 columns: DebitAccount, debitAmount)
    if (_result!.debitableAccounts.isNotEmpty) {
      final debitableSheet = excel['Debitable_Accounts'];
      final headers = ['DebitAccount', 'debitAmount'];
      debitableSheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (final d in _result!.debitableAccounts) {
        debitableSheet.appendRow([
          excel_pkg.TextCellValue(d.debitAccount),
          excel_pkg.DoubleCellValue(d.debitAmount),
        ]);
      }
    }

    // 2. Matched Sheet
    if (_result!.matched.isNotEmpty) {
      final matchedSheet = excel['Matched_Settlements'];
      final headers = [
        'CARD.ACC.ID',
        'Hardware',
        'Excess Account',
        'Debit Amount (Excess)',
        'ATM Account',
        'Debit Amount (ATM)',
        'Difference (Balance - Total Declined)',
        'Excess Balance',
        'Total Declined',
        'Status',
        'Customer',
        'Customer Name',
        'Product',
      ];
      matchedSheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (final m in _result!.matched) {
        matchedSheet.appendRow([
          excel_pkg.TextCellValue(m.cardAccId),
          excel_pkg.TextCellValue(m.hardwareTypeName),
          excel_pkg.TextCellValue(m.excessAccount),
          excel_pkg.DoubleCellValue(m.excessDebitAmount),
          excel_pkg.TextCellValue(m.atmAccount),
          excel_pkg.DoubleCellValue(m.atmDebitAmount),
          excel_pkg.TextCellValue(m.differenceFormula),
          excel_pkg.DoubleCellValue(m.excessBalance),
          excel_pkg.DoubleCellValue(m.totalDeclinedAmount),
          excel_pkg.TextCellValue(m.status),
          excel_pkg.TextCellValue(m.customer),
          excel_pkg.TextCellValue(m.name),
          excel_pkg.TextCellValue(m.product),
        ]);
      }
    }

    // 2. Excess Only Sheet
    if (_result!.excessOnly.isNotEmpty) {
      final excessSheet = excel['Excess_Only'];
      final headers = ['Status', 'Account No', 'Account Balance', 'Customer', 'Customer Name', 'Product', 'Ccy', 'Account Officer'];
      excessSheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (final e in _result!.excessOnly) {
        excessSheet.appendRow([
          excel_pkg.TextCellValue(e.status),
          excel_pkg.TextCellValue(e.accountNo),
          excel_pkg.DoubleCellValue(e.accountBalance),
          excel_pkg.TextCellValue(e.customer),
          excel_pkg.TextCellValue(e.name),
          excel_pkg.TextCellValue(e.product),
          excel_pkg.TextCellValue(e.ccy),
          excel_pkg.TextCellValue(e.accountOfficer),
        ]);
      }
    }

    // 3. Declined Only Sheet
    if (_result!.declinedOnly.isNotEmpty) {
      final declinedSheet = excel['Declined_Only'];
      final headers = ['Status', 'CARD.ACC.ID', 'Hardware', 'Total Declined Amount', 'Derived Excess Account', 'Derived ATM Account', 'Transaction Count'];
      declinedSheet.appendRow(headers.map((h) => excel_pkg.TextCellValue(h)).toList());

      for (final d in _result!.declinedOnly) {
        declinedSheet.appendRow([
          excel_pkg.TextCellValue(d.status),
          excel_pkg.TextCellValue(d.cardAccId),
          excel_pkg.TextCellValue(d.hardwareTypeName),
          excel_pkg.DoubleCellValue(d.totalDeclinedAmount),
          excel_pkg.TextCellValue(d.derivedExcessAccount),
          excel_pkg.TextCellValue(d.derivedAtmAccount),
          excel_pkg.IntCellValue(d.transactionCount),
        ]);
      }
    }

    // 4. Executive Summary Sheet
    final summarySheet = excel['Summary'];
    summarySheet.appendRow([excel_pkg.TextCellValue('Metric'), excel_pkg.TextCellValue('Value')]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Total Matched Terminals'), excel_pkg.IntCellValue(_result!.totalMatchedCount)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Total Matched Declined Amount'), excel_pkg.DoubleCellValue(_result!.totalMatchedDeclinedAmount)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Total Excess Account Debits'), excel_pkg.DoubleCellValue(_result!.totalMatchedExcessDebitAmount)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Total Cash at ATM Debits'), excel_pkg.DoubleCellValue(_result!.totalMatchedAtmDebitAmount)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Unmatched Excess Accounts Count'), excel_pkg.IntCellValue(_result!.totalExcessOnlyCount)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Unmatched Excess Balance Total'), excel_pkg.DoubleCellValue(_result!.totalExcessOnlyBalance)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Unmatched Declined Terminals Count'), excel_pkg.IntCellValue(_result!.totalDeclinedOnlyCount)]);
    summarySheet.appendRow([excel_pkg.TextCellValue('Unmatched Declined Amount Total'), excel_pkg.DoubleCellValue(_result!.totalDeclinedOnlyAmount)]);

    if (excel.sheets.containsKey('Sheet1') && excel.sheets.length > 1) {
      excel.delete('Sheet1');
    }

    final fileBytes = excel.save();
    if (fileBytes != null) {
      await FileSaverUtil.saveBytes(
        bytes: Uint8List.fromList(fileBytes),
        fileName: 'Recon_Declined_Settlement_Report_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Declined Transaction Settlement Excel exported successfully!')),
        );
      }
    }
  }

  Widget _buildSummaryBanner() {
    if (_result == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF00695C), Color(0xFF00897B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 800;
          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStatsBlock(
                  'MATCHED SETTLEMENTS:',
                  'Terminals: ${_countFormat.format(_result!.totalMatchedCount)}',
                  'Total Declined: ${_currencyFormat.format(_result!.totalMatchedDeclinedAmount)} ETB',
                ),
                const Divider(color: Colors.white24, height: 18),
                _buildStatsBlock(
                  'DEBIT ALLOCATION:',
                  'Excess Debited: ${_currencyFormat.format(_result!.totalMatchedExcessDebitAmount)} ETB',
                  'ATM Debited: ${_currencyFormat.format(_result!.totalMatchedAtmDebitAmount)} ETB',
                ),
                const Divider(color: Colors.white24, height: 18),
                _buildStatsBlock(
                  'UNMATCHED EXCEPTIONS:',
                  'Excess Only: ${_countFormat.format(_result!.totalExcessOnlyCount)} (${_currencyFormat.format(_result!.totalExcessOnlyBalance)} ETB)',
                  'Declined Only: ${_countFormat.format(_result!.totalDeclinedOnlyCount)} (${_currencyFormat.format(_result!.totalDeclinedOnlyAmount)} ETB)',
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildStatsBlock(
                  'MATCHED SETTLEMENTS:',
                  'Terminals: ${_countFormat.format(_result!.totalMatchedCount)}',
                  'Total Declined: ${_currencyFormat.format(_result!.totalMatchedDeclinedAmount)} ETB',
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white30),
              Expanded(
                child: _buildStatsBlock(
                  'DEBIT ALLOCATION:',
                  'Excess Debited: ${_currencyFormat.format(_result!.totalMatchedExcessDebitAmount)} ETB',
                  'ATM Debited: ${_currencyFormat.format(_result!.totalMatchedAtmDebitAmount)} ETB',
                ),
              ),
              Container(width: 1, height: 60, color: Colors.white30),
              Expanded(
                child: _buildStatsBlock(
                  'UNMATCHED EXCEPTIONS:',
                  'Excess Only: ${_countFormat.format(_result!.totalExcessOnlyCount)} (${_currencyFormat.format(_result!.totalExcessOnlyBalance)} ETB)',
                  'Declined Only: ${_countFormat.format(_result!.totalDeclinedOnlyCount)} (${_currencyFormat.format(_result!.totalDeclinedOnlyAmount)} ETB)',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatsBlock(String title, String line1, String line2) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            line1,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            line2,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      currentRoute: '/recon_declined',
      title: 'Declined Transaction Reconciliation',
      subtitle: 'Excess & Cash at ATM Multi-Hardware Settlement Engine',
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline_rounded, color: CboColors.slateMedium),
          tooltip: 'Calculation Guide',
          onPressed: _showGuide,
        ),
      ],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Metric Cards HUD
            LayoutBuilder(
              builder: (context, constraints) {
                final isCompact = constraints.maxWidth < 900;
                final metrics = [
                  CboMetricCard(
                    title: 'Total Matched Debits',
                    value: _result != null
                        ? '${_currencyFormat.format(_result!.totalMatchedDeclinedAmount)} ETB'
                        : '0.00 ETB',
                    subtitle: _result != null
                        ? '${_result!.totalMatchedCount} Terminals Settled'
                        : 'Awaiting Execution',
                    icon: Icons.account_balance_wallet_rounded,
                    color: CboColors.primaryCyan,
                  ),
                  CboMetricCard(
                    title: 'Excess Account Debited',
                    value: _result != null
                        ? '${_currencyFormat.format(_result!.totalMatchedExcessDebitAmount)} ETB'
                        : '0.00 ETB',
                    subtitle: 'Debited from Excess GLs',
                    icon: Icons.pie_chart_rounded,
                    color: const Color(0xFF00897B),
                  ),
                  CboMetricCard(
                    title: 'ATM Account Debited',
                    value: _result != null
                        ? '${_currencyFormat.format(_result!.totalMatchedAtmDebitAmount)} ETB'
                        : '0.00 ETB',
                    subtitle: 'Shortage / ATM GL Debited',
                    icon: Icons.atm_rounded,
                    color: const Color(0xFFD84315),
                  ),
                  CboMetricCard(
                    title: 'Unmatched Exceptions',
                    value: _result != null
                        ? '${_result!.totalExcessOnlyCount + _result!.totalDeclinedOnlyCount} Records'
                        : '0 Records',
                    subtitle: _result != null
                        ? 'Excess: ${_result!.totalExcessOnlyCount} | Declined: ${_result!.totalDeclinedOnlyCount}'
                        : 'Exceptions Isolated',
                    icon: Icons.warning_amber_rounded,
                    color: CboColors.accentGold,
                  ),
                ];

                if (isCompact) {
                  return Column(
                    children: metrics
                        .map((m) => Padding(padding: const EdgeInsets.only(bottom: 12), child: m))
                        .toList(),
                  );
                }

                return Row(
                  children: [
                    for (int i = 0; i < metrics.length; i++) ...[
                      Expanded(child: metrics[i]),
                      if (i < metrics.length - 1) const SizedBox(width: 12),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 20),

            // Dropzone Row
            LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 800;
                final file1 = CboFileDropzone(
                  title: '1. Excess Account Detail File',
                  subtitle: 'Upload downloaded excess account ledger (.csv, .xlsx)',
                  icon: Icons.account_balance_rounded,
                  fileName: _excessFileName,
                  rowCount: _excessRaw.length,
                  onTap: () => _pickFile(true),
                );

                final file2 = CboFileDropzone(
                  title: '2. Declined Transactions Report',
                  subtitle: 'Upload Pivot or Raw Detail declined report (.csv, .xlsx)',
                  icon: Icons.receipt_long_rounded,
                  fileName: _declinedFileName,
                  rowCount: _declinedRaw.length,
                  onTap: () => _pickFile(false),
                );

                if (isNarrow) {
                  return Column(
                    children: [
                      file1,
                      const SizedBox(height: 14),
                      file2,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: file1),
                    const SizedBox(width: 16),
                    Expanded(child: file2),
                  ],
                );
              },
            ),

            const SizedBox(height: 18),

            // Action Buttons
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _runReconciliation,
                  icon: _isProcessing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: Text(_isProcessing ? 'Processing Settlement...' : 'Reconcile Declined Transactions'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: CboColors.primaryCyan,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 12),
                if (_hasExecuted)
                  OutlinedButton.icon(
                    onPressed: _exportResults,
                    icon: const Icon(Icons.download_rounded),
                    label: const Text('Export Multi-Sheet Excel'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CboColors.primaryCyanDark,
                      side: const BorderSide(color: CboColors.primaryCyan),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
              ],
            ),

            if (_hasExecuted && _result != null) ...[
              const SizedBox(height: 20),
              _buildSummaryBanner(),
              const SizedBox(height: 20),

              // Filter Tabs Bar
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: CboColors.cardBorder),
                ),
                child: Row(
                  children: [
                    _buildTabButton(
                      'Matched Debits (${_result!.totalMatchedCount})',
                      ReconDeclinedFilter.matched,
                      Icons.check_circle_outline_rounded,
                    ),
                    _buildTabButton(
                      'Debitable Accounts (${_result!.totalDebitableAccountsCount})',
                      ReconDeclinedFilter.debitable,
                      Icons.payments_outlined,
                    ),
                    _buildTabButton(
                      'Excess Only (${_result!.totalExcessOnlyCount})',
                      ReconDeclinedFilter.excessOnly,
                      Icons.account_balance_outlined,
                    ),
                    _buildTabButton(
                      'Declined Only (${_result!.totalDeclinedOnlyCount})',
                      ReconDeclinedFilter.declinedOnly,
                      Icons.highlight_off_rounded,
                    ),
                    _buildTabButton(
                      'All Records (${_result!.totalMatchedCount + _result!.totalExcessOnlyCount + _result!.totalDeclinedOnlyCount})',
                      ReconDeclinedFilter.all,
                      Icons.list_alt_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // PlutoGrid Data Table Container
              Container(
                height: 520,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: CboColors.cardBorder),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: PlutoGrid(
                    columns: _buildColumns(),
                    rows: _buildRows(),
                    configuration: const PlutoGridConfiguration(
                      style: PlutoGridStyleConfig(
                        gridBorderColor: CboColors.cardBorder,
                        rowHeight: 44,
                        columnHeight: 46,
                        defaultCellPadding: EdgeInsets.symmetric(horizontal: 10),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String label, ReconDeclinedFilter filter, IconData icon) {
    final isSelected = _selectedFilter == filter;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _selectedFilter = filter),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? CboColors.primaryCyan.withValues(alpha: 0.12) : Colors.transparent,
            border: isSelected
                ? const Border(bottom: BorderSide(color: CboColors.primaryCyan, width: 3))
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? CboColors.primaryCyanDark : CboColors.slateMedium,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? CboColors.primaryCyanDark : CboColors.slateDark,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                    fontSize: 13,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
