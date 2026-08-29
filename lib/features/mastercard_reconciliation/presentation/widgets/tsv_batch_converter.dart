import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:csv/csv.dart';
import 'package:archive/archive.dart';
import '../../../../core/constants/cbo_colors.dart';

import '../../../master_card/to_excel_generator.dart';

class TsvBatchConverter extends StatefulWidget {
  const TsvBatchConverter({super.key});

  @override
  State<TsvBatchConverter> createState() => _TsvBatchConverterState();
}

class _TsvBatchConverterState extends State<TsvBatchConverter> {
  List<PlutoColumn> _columns = [];
  List<PlutoRow> _rows = [];
  List<List<dynamic>> _combinedMatrix = [];
  int _fileCount = 0;
  bool _isLoading = false;



  Future<void> _pickAndProcess({required bool isZip}) async {
    setState(() => _isLoading = true);
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: isZip ? ['zip'] : ['tsv', 'txt'],
        withData: true,
        allowMultiple: true,
      );

      if (result != null && result.files.isNotEmpty) {
        List<List<dynamic>> totalMatrix = [];
        List<dynamic> masterHeaders = [];
        int processedFileCount = 0;

        for (var file in result.files) {
          if (file.bytes == null) continue;

          if (isZip) {
            final archive = ZipDecoder().decodeBytes(file.bytes!);
            for (final zipFile in archive) {
              if (zipFile.isFile && (zipFile.name.endsWith('.tsv') || zipFile.name.endsWith('.txt'))) {
                final content = utf8.decode(zipFile.content as List<int>);
                _parseAndAppend(content, zipFile.name, totalMatrix, (headers) {
                  if (masterHeaders.isEmpty) masterHeaders = headers;
                });
                processedFileCount++;
              }
            }
          } else {
            final content = utf8.decode(file.bytes!);
            _parseAndAppend(content, file.name, totalMatrix, (headers) {
              if (masterHeaders.isEmpty) masterHeaders = headers;
            });
            processedFileCount++;
          }
        }

        if (totalMatrix.isEmpty) throw Exception("No readable data found in selected files.");

        final List<PlutoColumn> newCols = masterHeaders.map((h) {
          return PlutoColumn(
            title: h.toString(),
            field: h.toString(),
            type: PlutoColumnType.text(),
            enableRowChecked: h == masterHeaders.first,
          );
        }).toList();

        final List<PlutoRow> newRows = totalMatrix.where((row) => row.length > 1 && row[0] != '--- FILE START ---').map((row) {
          final cells = <String, PlutoCell>{};
          for (int i = 0; i < masterHeaders.length; i++) {
            final String cellVal = i < row.length ? row[i].toString().trim() : '';
            cells[masterHeaders[i].toString()] = PlutoCell(value: cellVal);
          }
          return PlutoRow(cells: cells);
        }).toList();

        setState(() {
          _combinedMatrix = totalMatrix;
          _columns = newCols;
          _rows = newRows;
          _fileCount = processedFileCount;
        });
      }
    } catch (e) {
      _showSnackBar("Processing error: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _parseAndAppend(String content, String fileName, List<List<dynamic>> totalMatrix, Function(List<dynamic>) onHeaders) {
    final List<List<dynamic>> matrix = const CsvToListConverter(
      fieldDelimiter: '\t',
      shouldParseNumbers: false,
    ).convert(content);

    if (matrix.isEmpty) return;

    onHeaders(matrix.first);
    totalMatrix.add(['--- FILE START ---', fileName, '', '', '', '', '', '']);
    totalMatrix.addAll(matrix);
    totalMatrix.add(['--- FILE END ---', fileName, '', '', '', '', '', '']);
    totalMatrix.add([]);
  }

  Future<void> _downloadAsExcel() async {
    if (_combinedMatrix.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      await TsvToExcelConverter.convertMatrixToExcel(_combinedMatrix, "Bulk_TSV_Export");
      _showSnackBar("$_fileCount files processed into Excel successfully!", Colors.green);
    } catch (e) {
      _showSnackBar("Export failed: $e", Colors.red);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String msg, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }



  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: Color(0xFF4527A0)),
                SizedBox(height: 16),
                Text('Processing & Decompressing Mastercard Feeds...', style: TextStyle(color: CboColors.slateMuted, fontWeight: FontWeight.w600)),
              ],
            ),
          )
        : Column(
            children: [
              // Top Control Bar
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: CboColors.cardBorder)),
                ),
                child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.start,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF4527A0),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.folder_zip_rounded, size: 18),
                        label: const Text('1. Pick Bulk ZIP File'),
                        onPressed: () => _pickAndProcess(isZip: true),
                      ),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF4527A0),
                          side: const BorderSide(color: Color(0xFF4527A0)),
                          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.file_present_rounded, size: 18),
                        label: const Text('2. Pick Direct TSV File(s)'),
                        onPressed: () => _pickAndProcess(isZip: false),
                      ),
                      if (_rows.isNotEmpty)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: CboColors.bankGreen,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          icon: const Icon(Icons.download_rounded, size: 18),
                          label: const Text('Export to Excel'),
                          onPressed: _downloadAsExcel,
                        ),
                      if (_rows.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: CboColors.primaryCyanUltraLight,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '$_fileCount Files Ingested • ${_rows.length} Rows',
                            style: const TextStyle(
                              color: CboColors.primaryCyanDark,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                // Main Table Area
                Expanded(
                  child: _rows.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.payment_rounded, size: 56, color: CboColors.slateLight),
                              const SizedBox(height: 14),
                              const Text(
                                'Awaiting Mastercard Ingestion',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: CboColors.slateDark),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Upload ZIP archives or tab-delimited TSV/TXT clearing files to generate matrix.',
                                style: TextStyle(fontSize: 13, color: CboColors.slateMuted),
                              ),
                            ],
                          ),
                        )
                      : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: PlutoGrid(
                              columns: _columns,
                              rows: _rows,
                              configuration: const PlutoGridConfiguration(
                                style: PlutoGridStyleConfig(
                                  enableGridBorderShadow: false,
                                  gridBorderColor: CboColors.cardBorder,
                                  rowHeight: 40,
                                  columnHeight: 40,
                                  columnTextStyle: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: CboColors.slateDark),
                                  cellTextStyle: TextStyle(fontSize: 11.5, color: CboColors.slateDark),
                                ),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            );
  }
}