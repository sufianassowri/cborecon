import 'package:file_picker/file_picker.dart';

import 'package:flutter_riverpod/legacy.dart';
import 'package:intl/intl.dart';
import '../../domain/entities/settlement_row_entity.dart';
import '../../domain/services/settlement_merger_engine.dart';
import '../../data/datasources/excel_workbook_exporter.dart';

class ReportMergerState {
  final String settlementType;
  final List<PlatformFile> selectedFiles;
  final bool isProcessing;
  final double progress;
  final String statusMessage;
  final MergedSettlementResult? mergedResult;
  final String activePreviewCategory;

  ReportMergerState({
    this.settlementType = 'ATM / POS Switch Settlement',
    this.selectedFiles = const [],
    this.isProcessing = false,
    this.progress = 0.0,
    this.statusMessage = '',
    this.mergedResult,
    this.activePreviewCategory = 'All_Merged',
  });

  ReportMergerState copyWith({
    String? settlementType,
    List<PlatformFile>? selectedFiles,
    bool? isProcessing,
    double? progress,
    String? statusMessage,
    MergedSettlementResult? mergedResult,
    String? activePreviewCategory,
  }) {
    return ReportMergerState(
      settlementType: settlementType ?? this.settlementType,
      selectedFiles: selectedFiles ?? this.selectedFiles,
      isProcessing: isProcessing ?? this.isProcessing,
      progress: progress ?? this.progress,
      statusMessage: statusMessage ?? this.statusMessage,
      mergedResult: mergedResult ?? this.mergedResult,
      activePreviewCategory: activePreviewCategory ?? this.activePreviewCategory,
    );
  }
}

class ReportMergerNotifier extends StateNotifier<ReportMergerState> {
  ReportMergerNotifier() : super(ReportMergerState());

  void setSettlementType(String type) {
    state = state.copyWith(settlementType: type);
  }

  void setActivePreviewCategory(String category) {
    state = state.copyWith(activePreviewCategory: category);
  }

  Future<void> pickFiles() async {
    final result = await FilePicker.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: ['xls', 'xlsx', 'csv', 'tsv', 'txt'],
      withData: true,
    );

    if (result != null && result.files.isNotEmpty) {
      final combined = [...state.selectedFiles, ...result.files];
      state = state.copyWith(selectedFiles: combined);
    }
  }

  void removeFile(int index) {
    if (index >= 0 && index < state.selectedFiles.length) {
      final updated = List<PlatformFile>.from(state.selectedFiles)..removeAt(index);
      state = state.copyWith(selectedFiles: updated);
    }
  }

  void clearFiles() {
    state = state.copyWith(selectedFiles: [], mergedResult: null);
  }

  Future<void> runMerge() async {
    if (state.selectedFiles.isEmpty) return;

    state = state.copyWith(
      isProcessing: true,
      progress: 0.0,
      statusMessage: 'Initializing settlement merger engine...',
    );

    try {
      final result = await SettlementMergerEngine.mergeFiles(
        files: state.selectedFiles,
        onProgress: (status, progress) {
          state = state.copyWith(
            statusMessage: status,
            progress: progress,
          );
        },
      );

      state = state.copyWith(
        isProcessing: false,
        mergedResult: result,
        activePreviewCategory: 'All_Merged',
        statusMessage: 'Merged successfully!',
      );
    } catch (e) {
      state = state.copyWith(
        isProcessing: false,
        statusMessage: 'Error during merge: $e',
      );
      rethrow;
    }
  }

  Future<String?> exportExcel() async {
    if (state.mergedResult == null) return null;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final baseName = 'Merged_Settlement_MultiSheet_$timestamp';

    return await ExcelWorkbookExporter.exportMultiSheetWorkbook(
      mergeResult: state.mergedResult!,
      baseFileName: baseName,
    );
  }

  Future<String?> exportCsv() async {
    if (state.mergedResult == null) return null;
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final baseName = 'Merged_Settlement_Master_$timestamp';

    List<SettlementRowEntity> rowsToExport;
    if (state.activePreviewCategory == 'All_Merged') {
      rowsToExport = state.mergedResult!.allMergedRows;
    } else {
      rowsToExport = state.mergedResult!.categorizedSheets[state.activePreviewCategory] ??
          state.mergedResult!.allMergedRows;
    }

    return await ExcelWorkbookExporter.exportMasterCsv(
      rows: rowsToExport,
      baseFileName: '${baseName}_${state.activePreviewCategory}',
    );
  }
}

final reportMergerProvider =
    StateNotifierProvider<ReportMergerNotifier, ReportMergerState>((ref) {
  return ReportMergerNotifier();
});
