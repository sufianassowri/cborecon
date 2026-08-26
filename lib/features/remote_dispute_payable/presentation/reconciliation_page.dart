import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:file_picker/file_picker.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:intl/intl.dart'; // Handles the standard thousands separator logic cleanly

class RemoteDisputePayableTables {
  static const String remoteDisputePayableClass = 'RemoteDisputePayable';
  static const String remoteDisputeChargebackClass = 'RemoteDisputeChargeback';
}

enum TransactionType { payable, chargeback }

class TableSchemaConfig {
  final List<PlutoColumn> columns;
  final String refHeaderKey;
  final String amountHeaderKey;
  final List<String> databaseFields;

  TableSchemaConfig({
    required this.columns,
    required this.refHeaderKey,
    required this.amountHeaderKey,
    required this.databaseFields,
  });
}

class RemoteDisputePayableDashboardScreenTest extends StatefulWidget {
  const RemoteDisputePayableDashboardScreenTest({super.key});

  @override
  State<RemoteDisputePayableDashboardScreenTest> createState() => _RemoteDisputeAdaptiveDashboardScreenState();
}

class _RemoteDisputeAdaptiveDashboardScreenState extends State<RemoteDisputePayableDashboardScreenTest> {
  TransactionType selectedTableType = TransactionType.chargeback;

  bool _isUploading = false;
  int _savedCount = 0;
  int _duplicateCount = 0;

  double _totalSubsidiary = 0.0;
  double _glAmountInput = 0.0;
  final TextEditingController _glController = TextEditingController();
  final NumberFormat _commaFormatter = NumberFormat('#,##0.00', 'en_US');
  List<Map<String, dynamic>> _databaseRecords = [];

  int _countSettled = 0;
  int _countUnsettled = 0;
  int _countSettlement = 0;
  int _countDispute = 0;

  double _sumSettled = 0.0;
  double _sumUnsettled = 0.0;
  double _sumSettlement = 0.0;
  double _sumDispute = 0.0;

  List<PlutoColumn> columns = [];
  List<PlutoRow> rows = [];
  PlutoGridStateManager? stateManager;

  @override
  void initState() {
    super.initState();
    _applyActiveSchemaConfiguration();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadLiveDatabaseRecords());
  }

  @override
  void dispose() {
    _glController.dispose();
    super.dispose();
  }

  TableSchemaConfig _getSchemaConfig() {
    if (selectedTableType == TransactionType.payable) {
      return TableSchemaConfig(
        refHeaderKey: 'TRANSREF',
        amountHeaderKey: 'TXNAMOUNT',
        databaseFields: ['TRANSREF', 'PANNUMBER', 'VALUEDATE', 'DEBITACCTNO', 'TXNAMOUNT', 'RETRIEVALREFNO', 'STATUS'],
        columns: [
          PlutoColumn(title: 'Transaction Ref', field: 'TRANSREF', type: PlutoColumnType.text(), enableRowChecked: true, width: 160),
          PlutoColumn(title: 'Card PAN Number', field: 'PANNUMBER', type: PlutoColumnType.text(), width: 180),
          PlutoColumn(title: 'Value Date', field: 'VALUEDATE', type: PlutoColumnType.text(), width: 130),
          PlutoColumn(title: 'Debit Account', field: 'DEBITACCTNO', type: PlutoColumnType.text(), width: 180),
          PlutoColumn(title: 'Amount', field: 'TXNAMOUNT', type: PlutoColumnType.number(format: '#,###.00'), textAlign: PlutoColumnTextAlign.right, width: 140),
          PlutoColumn(title: 'Retrieval Ref No', field: 'RETRIEVALREFNO', type: PlutoColumnType.text(), width: 160),
          PlutoColumn(title: 'Status', field: 'STATUS', type: PlutoColumnType.text(), width: 120),
        ],
      );
    } else {
      return TableSchemaConfig(
        refHeaderKey: 'REFERANCE',
        amountHeaderKey: 'Amount',
        databaseFields: [
          'Issuer', 'Acquirer', 'Card_Number', 'Amount', 'Transaction_Date',
          'Transaction_Description', 'Terminal_ID', 'Transaction_Place', 'Refnum_F37',
          'Authidresp_F38', 'Bo_utrnno', 'ACCOUNT', 'REFERANCE', 'NAME', 'Chargeback_Date', 'STATUS'
        ],
        columns: [
          PlutoColumn(title: 'Reference (F37 Key)', field: 'REFERANCE', type: PlutoColumnType.text(), enableRowChecked: true, width: 160),
          PlutoColumn(title: 'Issuer Bank', field: 'Issuer', type: PlutoColumnType.text(), width: 140),
          PlutoColumn(title: 'Acquirer Network', field: 'Acquirer', type: PlutoColumnType.text(), width: 130),
          PlutoColumn(title: 'Card Number', field: 'Card_Number', type: PlutoColumnType.text(), width: 180),
          PlutoColumn(title: 'Amount', field: 'Amount', type: PlutoColumnType.number(format: '#,###.00'), textAlign: PlutoColumnTextAlign.right, width: 130),
          PlutoColumn(title: 'Transaction Date', field: 'Transaction_Date', type: PlutoColumnType.text(), width: 160),
          PlutoColumn(title: 'Description', field: 'Transaction_Description', type: PlutoColumnType.text(), width: 180),
          PlutoColumn(title: 'Terminal ID', field: 'Terminal_ID', type: PlutoColumnType.text(), width: 120),
          PlutoColumn(title: 'Transaction Place', field: 'Transaction_Place', type: PlutoColumnType.text(), width: 180),
          PlutoColumn(title: 'Refnum F37', field: 'Refnum_F37', type: PlutoColumnType.text(), width: 140),
          PlutoColumn(title: 'Auth Response F38', field: 'Authidresp_F38', type: PlutoColumnType.text(), width: 130),
          PlutoColumn(title: 'BO UTRNNO', field: 'Bo_utrnno', type: PlutoColumnType.text(), width: 150),
          PlutoColumn(title: 'Account', field: 'ACCOUNT', type: PlutoColumnType.text(), width: 160),
          PlutoColumn(title: 'Cardholder Name', field: 'NAME', type: PlutoColumnType.text(), width: 180),
          PlutoColumn(title: 'Chargeback Date', field: 'Chargeback_Date', type: PlutoColumnType.text(), width: 160),
          PlutoColumn(title: 'Status', field: 'STATUS', type: PlutoColumnType.text(), width: 120),
        ],
      );
    }
  }

  void _applyActiveSchemaConfiguration() {
    final config = _getSchemaConfig();
    setState(() {
      columns = List.from(config.columns);
    });

    if (stateManager != null) {
      stateManager!.removeColumns(stateManager!.columns);
      stateManager!.insertColumns(0, config.columns);
    }
  }

  void _calculateDatabaseAnchoredMetrics() {
    double dynamicSubSum = 0.0;
    final config = _getSchemaConfig();
    for (var record in _databaseRecords) {
      String status = (record['STATUS'] ?? 'Unsettled').toString().trim();
      double amt = double.tryParse(record[config.amountHeaderKey]?.toString() ?? '0') ?? 0.0;

      if (status != 'Settled') {
        dynamicSubSum += amt;
      }
    }
    setState(() {
      _totalSubsidiary = dynamicSubSum;
    });
  }

  void _recalculateUiFilteredMetrics() {
    if (stateManager == null) return;
    int cSettled = 0; int cUnsettled = 0; int cSettlement = 0; int cDispute = 0;
    double sSettled = 0.0; double sUnsettled = 0.0; double sSettlement = 0.0; double sDispute = 0.0;

    final config = _getSchemaConfig();
    for (var row in stateManager!.rows) {
      final statusCell = row.cells['STATUS'];
      final String status = (statusCell != null ? statusCell.value : 'Unsettled').toString().trim();

      final amtCell = row.cells[config.amountHeaderKey];
      final double amt = double.tryParse(amtCell != null ? amtCell.value.toString() : '0.0') ?? 0.0;

      switch (status) {
        case 'Settled': cSettled++; sSettled += amt; break;
        case 'Dispute': cDispute++; sDispute += amt; break;
        case 'Settlement': cSettlement++; sSettlement += amt; break;
        default: cUnsettled++; sUnsettled += amt; break;
      }
    }

    setState(() {
      _countSettled = cSettled; _countUnsettled = cUnsettled; _countSettlement = cSettlement; _countDispute = cDispute;
      _sumSettled = sSettled; _sumUnsettled = sUnsettled; _sumSettlement = sSettlement; _sumDispute = sDispute;
    });
  }

  void _populateGridRows(List<Map<String, dynamic>> recordsList) {
    _databaseRecords = recordsList;
    final config = _getSchemaConfig();

    List<PlutoRow> newRows = recordsList.map((rowMap) {
      Map<String, PlutoCell> cells = {};

      for (var col in columns) {
        var rawVal = rowMap[col.field];
        if (col.field == config.amountHeaderKey) {
          cells[col.field] = PlutoCell(value: double.tryParse(rawVal?.toString() ?? '0') ?? 0.0);
        } else if (col.field == 'STATUS') {
          cells[col.field] = PlutoCell(value: rawVal?.toString() ?? 'Unsettled');
        } else {
          cells[col.field] = PlutoCell(value: rawVal?.toString() ?? '');
        }
      }
      return PlutoRow(cells: cells);
    }).toList();

    if (stateManager != null) {
      stateManager!.removeRows(stateManager!.rows);
      stateManager!.appendRows(newRows);
    } else {
      setState(() => rows = newRows);
    }

    _calculateDatabaseAnchoredMetrics();
    _recalculateUiFilteredMetrics();
  }

  Future<void> _loadLiveDatabaseRecords() async {
    final String targetClass = selectedTableType == TransactionType.payable
        ? RemoteDisputePayableTables.remoteDisputePayableClass
        : RemoteDisputePayableTables.remoteDisputeChargebackClass;

    setState(() => _isUploading = true);
    try {
      final QueryBuilder<ParseObject> databaseQuery = QueryBuilder<ParseObject>(ParseObject(targetClass))
        ..setLimit(2000)
        ..orderByDescending('createdAt');
      final ParseResponse response = await databaseQuery.query();

      if (response.success && response.results != null) {
        final config = _getSchemaConfig();
        List<Map<String, dynamic>> loadedData = response.results!.map((parseObj) {
          String rawStatus = (parseObj.get<String>('status') ?? parseObj.get<String>('STATUS') ?? 'Unsettled').toString().trim().toLowerCase();
          String localizedStatus = 'Unsettled';
          if (rawStatus == 'settled') localizedStatus = 'Settled';
          else if (rawStatus == 'dispute') localizedStatus = 'Dispute';
          else if (rawStatus == 'settlement') localizedStatus = 'Settlement';

          Map<String, dynamic> itemMap = {
            'objectId': parseObj.objectId,
            'STATUS': localizedStatus,
          };

          for (var fieldName in config.databaseFields) {
            if (fieldName == 'STATUS') continue;
            var backendVal = parseObj.get(fieldName);
            if (fieldName == config.amountHeaderKey) {
              itemMap[fieldName] = backendVal ?? 0.0;
            } else {
              itemMap[fieldName] = backendVal?.toString() ?? '';
            }
          }

          return itemMap;
        }).toList();
        _populateGridRows(loadedData);
      } else {
        _populateGridRows([]);
      }
    } catch (e) {
      debugPrint("Database sync error: $e");
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _processSpreadsheetImport(String targetClass) async {
    FilePickerResult? fileSelectionResult = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (fileSelectionResult == null || fileSelectionResult.files.single.bytes == null) return;
    setState(() => _isUploading = true);
    try {
      final PlatformFile targetFile = fileSelectionResult.files.single;
      final String rawCsvString = utf8.decode(targetFile.bytes!);
      final List<List<dynamic>> parsedMatrix = const CsvToListConverter().convert(rawCsvString);

      if (parsedMatrix.isEmpty) throw Exception("Selected template matrix is empty.");
      final List<dynamic> fileHeaders = parsedMatrix.first.map((e) => e.toString().trim().toUpperCase()).toList();
      final config = _getSchemaConfig();

      final int refIndex = fileHeaders.indexOf(config.refHeaderKey.toUpperCase());
      if (refIndex == -1) throw Exception("Spreadsheet missing matching track key layout field: '${config.refHeaderKey}'");

      final QueryBuilder<ParseObject> databaseQuery = QueryBuilder<ParseObject>(ParseObject(targetClass))..setLimit(2000);
      final ParseResponse databaseResponse = await databaseQuery.query();

      Set<String> registeredDatabaseRefs = {};
      if (databaseResponse.success && databaseResponse.results != null) {
        for (var parseObj in databaseResponse.results!) {
          final String? existingRef = parseObj.get<String>(config.refHeaderKey);
          if (existingRef != null) registeredDatabaseRefs.add(existingRef.trim().toUpperCase());
        }
      }

      int addedRecords = 0;
      int skippedRecords = 0;
      List<ParseObject> batchPool = [];

      for (int i = 1; i < parsedMatrix.length; i++) {
        final row = parsedMatrix[i];
        if (row.length <= refIndex || row[refIndex] == null || row[refIndex].toString().isEmpty) continue;

        final String localRef = row[refIndex].toString().trim();
        if (registeredDatabaseRefs.contains(localRef.toUpperCase())) {
          skippedRecords++;
          continue;
        }

        final ParseObject newRecord = ParseObject(targetClass)..set('status', 'Unsettled');
        for (var fieldName in config.databaseFields) {
          if (fieldName == 'STATUS') continue;
          int fieldIdx = fileHeaders.indexOf(fieldName.toUpperCase());
          if (fieldIdx != -1 && row.length > fieldIdx && row[fieldIdx] != null) {
            var val = row[fieldIdx];
            if (fieldName == config.amountHeaderKey) {
              double parsedAmt = double.tryParse(val.toString().replaceAll(',', '').trim()) ?? 0.0;
              newRecord.set(fieldName, parsedAmt);
            } else {
              newRecord.set(fieldName, val.toString().trim());
            }
          } else {
            newRecord.set(fieldName, fieldName == config.amountHeaderKey ? 0.0 : '');
          }
        }

        batchPool.add(newRecord);
        registeredDatabaseRefs.add(localRef.toUpperCase());
        if (batchPool.length >= 40) {
          final results = await Future.wait(batchPool.map((obj) => obj.save()));
          addedRecords += results.where((res) => res.success).length;
          batchPool.clear();
        }
      }

      if (batchPool.isNotEmpty) {
        final results = await Future.wait(batchPool.map((obj) => obj.save()));
        addedRecords += results.where((res) => res.success).length;
        batchPool.clear();
      }

      setState(() {
        _savedCount = addedRecords;
        _duplicateCount = skippedRecords;
      });
      await _loadLiveDatabaseRecords();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Import done! Added: $addedRecords, Duplicates Skipped: $skippedRecords"), backgroundColor: Colors.green),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${error.toString()}"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _runIsolatedVerificationCheck(String targetClass) async {
    FilePickerResult? fileSelectionResult = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
    if (fileSelectionResult == null || fileSelectionResult.files.single.bytes == null) return;
    setState(() => _isUploading = true);
    try {
      final PlatformFile targetFile = fileSelectionResult.files.single;
      final String rawCsvString = utf8.decode(targetFile.bytes!);
      final List<List<dynamic>> parsedMatrix = const CsvToListConverter().convert(rawCsvString);

      if (parsedMatrix.isEmpty) throw Exception("Selected verification targets are empty.");
      final List<dynamic> fileHeaders = parsedMatrix.first.map((e) => e.toString().trim().toUpperCase()).toList();
      final config = _getSchemaConfig();

      final int refIndex = fileHeaders.indexOf(config.refHeaderKey.toUpperCase());
      if (refIndex == -1) throw Exception("Required tracking validation header '${config.refHeaderKey}' missing.");

      final QueryBuilder<ParseObject> databaseQuery = QueryBuilder<ParseObject>(ParseObject(targetClass))..setLimit(2000);
      final ParseResponse databaseResponse = await databaseQuery.query();

      Map<String, String> registeredDatabaseRefs = {};
      if (databaseResponse.success && databaseResponse.results != null) {
        for (var parseObj in databaseResponse.results!) {
          final String? existingRef = parseObj.get<String>(config.refHeaderKey);
          final String dbStatus = parseObj.get<String>('status') ?? parseObj.get<String>('STATUS') ?? 'unsettled';
          if (existingRef != null) {
            registeredDatabaseRefs[existingRef.trim().toUpperCase()] = dbStatus.trim().toLowerCase();
          }
        }
      }

      List<Map<String, dynamic>> displayOutputRows = [];
      int uniqueMatchCount = 0;
      int duplicateMatchCount = 0;

      for (int i = 1; i < parsedMatrix.length; i++) {
        final row = parsedMatrix[i];
        if (row.length <= refIndex || row[refIndex] == null || row[refIndex].toString().isEmpty) continue;

        final String localRef = row[refIndex].toString().trim();
        String finalStatus = 'Settlement';
        if (registeredDatabaseRefs.containsKey(localRef.toUpperCase())) {
          duplicateMatchCount++;
          final String linkedStatus = registeredDatabaseRefs[localRef.toUpperCase()]!;
          finalStatus = (linkedStatus == 'settled') ? 'Settled' : 'Dispute';
        } else {
          uniqueMatchCount++;
        }

        Map<String, dynamic> rowMap = {'STATUS': finalStatus};
        for (var fieldName in config.databaseFields) {
          if (fieldName == 'STATUS') continue;
          int hIdx = fileHeaders.indexOf(fieldName.toUpperCase());
          if (hIdx != -1 && row.length > hIdx && row[hIdx] != null) {
            var val = row[hIdx];
            if (fieldName == config.amountHeaderKey) {
              rowMap[fieldName] = double.tryParse(val.toString().replaceAll(',', '').trim()) ?? 0.0;
            } else {
              rowMap[fieldName] = val.toString().trim();
            }
          } else {
            rowMap[fieldName] = fieldName == config.amountHeaderKey ? 0.0 : '';
          }
        }

        displayOutputRows.add(rowMap);
      }

      setState(() {
        _savedCount = uniqueMatchCount;
        _duplicateCount = duplicateMatchCount;
      });
      _populateGridRows(displayOutputRows);

    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: ${error.toString()}"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _finalizeCheckedDisputesToSettled() async {
    if (stateManager == null || stateManager!.checkedRows.isEmpty) return;
    final checkedRowsList = stateManager!.checkedRows;
    final config = _getSchemaConfig();

    final selectedRefs = checkedRowsList
        .map((row) => row.cells[config.refHeaderKey]?.value?.toString().trim() ?? '')
        .where((ref) => ref.isNotEmpty)
        .toSet();
    if (selectedRefs.isEmpty) return;

    final targetClass = selectedTableType == TransactionType.payable
        ? RemoteDisputePayableTables.remoteDisputePayableClass
        : RemoteDisputePayableTables.remoteDisputeChargebackClass;

    setState(() => _isUploading = true);
    try {
      List<ParseObject> objectsToUpdate = [];
      final refsList = selectedRefs.toList();
      for (int i = 0; i < refsList.length; i += 500) {
        final chunk = refsList.sublist(i, (i + 500 > refsList.length) ? refsList.length : i + 500);
        final query = QueryBuilder<ParseObject>(ParseObject(targetClass))
          ..whereContainedIn(config.refHeaderKey, chunk)
          ..setLimit(500);
        final response = await query.query();
        if (response.success && response.results != null) {
          objectsToUpdate.addAll(response.results!.cast<ParseObject>());
        }
      }

      for (var obj in objectsToUpdate) {
        obj.set('status', 'Settled');
      }

      int updatedCount = 0;
      if (objectsToUpdate.isNotEmpty) {
        for (int i = 0; i < objectsToUpdate.length; i += 40) {
          int end = (i + 40 > objectsToUpdate.length) ? objectsToUpdate.length : i + 40;
          final chunk = objectsToUpdate.sublist(i, end);
          final results = await Future.wait(chunk.map((obj) => obj.save()));
          updatedCount += results.where((res) => res.success).length;
        }
      }

      await _loadLiveDatabaseRecords();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Successfully marked $updatedCount items as Settled."), backgroundColor: const Color(0xFF2A9D8F)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _exportRowsToCsv({required List<PlutoRow> targetRows, required String fileNameSpec}) async {
    if (targetRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No records match standard filter options selection."), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _isUploading = true);
    try {
      List<String> headerLine = columns.map((col) => col.field).toList();
      List<List<dynamic>> csvMatrix = [headerLine];
      for (var row in targetRows) {
        csvMatrix.add(columns.map((col) => row.cells[col.field]?.value).toList());
      }

      String csvString = const ListToCsvConverter().convert(csvMatrix);
      Uint8List csvBytes = Uint8List.fromList(utf8.encode(csvString));

      final String finalFileName = '${fileNameSpec}_${DateTime.now().millisecondsSinceEpoch}';
      await FileSaver.instance.saveFile(name: finalFileName, bytes: csvBytes, fileExtension: 'csv', mimeType: MimeType.csv);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Export completed: $finalFileName.csv"), backgroundColor: const Color(0xFF2A9D8F)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Download failed: $e"), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  /// Triggered via onChanged to format user input with 3-digit comma separations live
  void _handleGlInputFormatting(String inputString) {
    if (inputString.isEmpty) {
      setState(() => _glAmountInput = 0.0);
      return;
    }

    // Isolate only the explicit digits and the decimal point
    String cleanDigits = inputString.replaceAll(RegExp(r'[^\d.]'), '');

    // Safety check against handling double decimals
    if (cleanDigits.split('.').length > 2) {
      cleanDigits = cleanDigits.substring(0, cleanDigits.lastIndexOf('.'));
    }

    double parsedVal = double.tryParse(cleanDigits) ?? 0.0;

    // Track original cursor baseline selection relative to string tail to prevent jumpy input
    int offsetFromEnd = _glController.text.length - _glController.selection.end;

    // Format the text representation layout
    String formattedText;
    if (cleanDigits.contains('.')) {
      List<String> dynamicSplit = cleanDigits.split('.');
      String wholePart = dynamicSplit[0];
      String decimalPart = dynamicSplit[1];

      // Format only whole number segment with standard grouping separators
      double wholeVal = double.tryParse(wholePart) ?? 0.0;
      String formattedWhole = NumberFormat('#,##0', 'en_US').format(wholeVal);

      // Keep decimal characters up to length 2
      if (decimalPart.length > 2) {
        decimalPart = decimalPart.substring(0, 2);
      }
      formattedText = '$formattedWhole.$decimalPart';
    } else {
      formattedText = NumberFormat('#,##0', 'en_US').format(parsedVal);
    }

    _glController.value = TextEditingValue(
      text: formattedText,
      selection: TextSelection.collapsed(
        offset: (formattedText.length - offsetFromEnd).clamp(0, formattedText.length),
      ),
    );

    setState(() {
      _glAmountInput = parsedVal;
    });
  }

  @override
  Widget build(BuildContext context) {
    final String targetsClassName = selectedTableType == TransactionType.payable
        ? RemoteDisputePayableTables.remoteDisputePayableClass
        : RemoteDisputePayableTables.remoteDisputeChargebackClass;

    final double calculatedDifference = _totalSubsidiary - _glAmountInput;
    return Scaffold(
      backgroundColor: const Color(0xFFE9EBEE),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          tooltip: 'Back to Dashboard',
          onPressed: () {
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              Navigator.pushReplacementNamed(context, '/');
            }
          },
        ),
        title: Text('Dispute & Chargeback Workspace [Target: $targetsClassName]', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1D5C96),
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final bool useHorizontalLayout = constraints.maxWidth > 1100;
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              _buildTopPanelButton(Icons.folder_open, "Download All", const Color(0xFFE5A93B), _isUploading ? null : () => _exportRowsToCsv(targetRows: stateManager?.rows ?? rows, fileNameSpec: '${targetsClassName}_all')),
                              _buildTopPanelButton(Icons.emoji_events_outlined, "Download Duplicates", const Color(0xFFE5A93B), _isUploading ? null : () => _exportRowsToCsv(targetRows: (stateManager?.rows ?? rows).where((r) => r.cells['STATUS']?.value == 'Dispute').toList(), fileNameSpec: '${targetsClassName}_duplicates')),
                              _buildTopPanelButton(Icons.check_box, "Download Selected", const Color(0xFF2A9D8F), _isUploading ? null : () => _exportRowsToCsv(targetRows: stateManager?.checkedRows ?? [], fileNameSpec: '${targetsClassName}_selected')),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1D5C96), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                                onPressed: _isUploading ? null : _finalizeCheckedDisputesToSettled,
                                icon: const Icon(Icons.gavel, size: 14),
                                label: const Text("Finalize", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade400)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TransactionType>(
                              value: selectedTableType,
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.black87),
                              onChanged: (updatedType) {
                                if (updatedType != null) {
                                  setState(() {

                                    selectedTableType = updatedType;
                                    _glAmountInput = 0.0;
                                    _glController.clear();
                                    _applyActiveSchemaConfiguration();
                                  });
                                  _loadLiveDatabaseRecords();
                                }
                              },
                              items: const [
                                DropdownMenuItem(value: TransactionType.payable, child: Text("Payable")),
                                DropdownMenuItem(value: TransactionType.chargeback, child: Text("Chargeback")),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      elevation: 2,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _isUploading ? null : () => _processSpreadsheetImport(targetsClassName),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: const Color(0xFF1D5C96).withAlpha(25), shape: BoxShape.circle),
                                child: const Icon(Icons.upload_file, size: 24, color: Color(0xFF1D5C96)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Process Spreadsheet into: $targetsClassName", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    const Text("Select target configuration to avoid layout redundancy mapping updates.", style: TextStyle(fontSize: 11, color: Colors.grey)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2A9D8F), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
                                onPressed: _isUploading ? null : () => _runIsolatedVerificationCheck(targetsClassName),
                                icon: const Icon(Icons.youtube_searched_for, size: 16),
                                label: const Text("Check / Verify File", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFE2F0D9), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFA9D18E))),
                            child: Text("Added Unique: $_savedCount", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF385723), fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: const Color(0xFFFCE4D6), borderRadius: BorderRadius.circular(4), border: Border.all(color: const Color(0xFFF4B183))),
                            child: Text("Skipped Duplicates: $_duplicateCount", style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFC65911), fontSize: 13)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Expanded(
                      child: Flex(
                        direction: useHorizontalLayout ? Axis.horizontal : Axis.vertical,
                        children: [
                          Expanded(
                            flex: useHorizontalLayout ? 7 : 0,
                            child: SizedBox(
                              height: useHorizontalLayout ? double.infinity : 400,
                              child: Container(
                                decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                                child: PlutoGrid(
                                  key: ValueKey(selectedTableType),
                                  columns: columns,
                                  rows: rows,
                                  onChanged: (event) => _recalculateUiFilteredMetrics(),
                                  onLoaded: (event) {
                                    stateManager = event.stateManager;
                                    stateManager!.setShowColumnFilter(true);
                                    stateManager!.setColumnSizeConfig(const PlutoGridColumnSizeConfig(autoSizeMode: PlutoAutoSizeMode.equal));
                                    stateManager!.addListener(() => _recalculateUiFilteredMetrics());
                                    _recalculateUiFilteredMetrics();
                                  },
                                  rowColorCallback: (context) {
                                    final statusCell = context.row.cells['STATUS'];
                                    final String status = (statusCell != null ? statusCell.value : 'Unsettled').toString();
                                    if (status == 'Settled') return const Color(0xFFD4EDDA);
                                    if (status == 'Dispute') return const Color(0xFFF8D7DA);
                                    if (status == 'Settlement') return const Color(0xFFFFF3CD);
                                    return Colors.white;
                                  },
                                ),
                              ),
                            ),
                          ),
                          useHorizontalLayout ? const SizedBox(width: 16) : const SizedBox(height: 16),
                          Expanded(
                            flex: useHorizontalLayout ? 3 : 0,
                            child: SizedBox(
                              width: useHorizontalLayout ? 320 : double.infinity,
                              child: SingleChildScrollView(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.grey.shade300)),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text("Database Reconciler Layout", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1D5C96))),
                                      const SizedBox(height: 10),
                                      _buildMetricRow("Total Subsidiary:", _totalSubsidiary, isBold: true),
                                      const SizedBox(height: 10),
                                      const Text("GL Ledger Amount Input", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
                                      const SizedBox(height: 4),
                                      SizedBox(
                                        height: 36,
                                        child: TextField(
                                          controller: _glController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          // Allow digits, commas, and dots to be keyed in smoothly
                                          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d,.]'))],
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            hintText: "Enter ledger total...", contentPadding: const EdgeInsets.symmetric(horizontal: 8), filled: true, fillColor: const Color(0xFFF8F9FA),
                                            enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)), focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFF1D5C96))),
                                          ),
                                          onChanged: _handleGlInputFormatting,
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(4)),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            const Text("Difference:", style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                                            Text(_commaFormatter.format(calculatedDifference), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red)),
                                          ],
                                        ),
                                      ),
                                      const Divider(height: 20),
                                      const Text("Workspace Filter Summaries", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF2A9D8F))),
                                      const SizedBox(height: 8),
                                      _buildCounterTag("Settled:", "$_countSettled rows", const Color(0xFF28A745)),
                                      _buildCounterTag("Unsettled:", "$_countUnsettled rows", Colors.blueGrey),
                                      _buildCounterTag("Settlement:", "$_countSettlement rows", const Color(0xFFFFC107)),
                                      _buildCounterTag("Active Dispute:", "$_countDispute rows", const Color(0xFFDC3545)),
                                      const SizedBox(height: 10),
                                      _buildMetricRow("Settled Sum:", _sumSettled),
                                      _buildMetricRow("Unsettled Sum:", _sumUnsettled),
                                      _buildMetricRow("Settlement Sum:", _sumSettlement),
                                      _buildMetricRow("Dispute Sum:", _sumDispute),
                                      const Divider(height: 20),
                                      const Text("Status Legend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                      const SizedBox(height: 10),
                                      _buildLegendItem(const Color(0xFF28A745), "Settled", "Cleared Records"),
                                      const SizedBox(height: 8),
                                      _buildLegendItem(const Color(0xFFDC3545), "Dispute", "Network Redundancy Duplicates"),
                                      const SizedBox(height: 8),
                                      _buildLegendItem(const Color(0xFFFFC107), "Settlement", "Awaiting Processing Pipeline"),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          if (_isUploading)
            Container(color: Colors.black26, child: const Center(child: CircularProgressIndicator(color: Color(0xFF1D5C96)))),
        ],
      ),
    );
  }

  Widget _buildTopPanelButton(IconData icon, String label, Color color, VoidCallback? callback) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDCDFE4), foregroundColor: Colors.black87, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4))),
      onPressed: callback, icon: Icon(icon, size: 14, color: color), label: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    );
  }

  Widget _buildMetricRow(String label, double value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(_commaFormatter.format(value), style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: isBold ? Colors.black : Colors.black87)),
        ],
      ),
    );
  }

  Widget _buildCounterTag(String label, String value, Color indicatorColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        children: [
          Container(width: 6, height: 6, decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle)),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontSize: 11)),
          const Spacer(),
          Text(value, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color indicatorColor, String heading, String subtitle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: indicatorColor, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(heading, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
            Text(subtitle, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        )
      ],
    );
  }
}