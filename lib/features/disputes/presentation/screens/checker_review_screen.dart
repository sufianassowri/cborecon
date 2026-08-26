import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pluto_grid/pluto_grid.dart';
import 'package:pdfx/pdfx.dart';

class CheckerPanelScreen extends StatefulWidget {
  const CheckerPanelScreen({super.key});
  @override
  State<CheckerPanelScreen> createState() => _CheckerPanelScreenState();
}
class _CheckerPanelScreenState extends State<CheckerPanelScreen> {
  final ValueNotifier<bool> _isFileViewerVisible = ValueNotifier<bool>(false);
  String _selectedFileViewTitle = '';
  Uint8List? _selectedFileBytes;

  @override
  void dispose() {
    _isFileViewerVisible.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
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
        title: const Text(
          "Dispute Management - Checker Portal",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      backgroundColor: const Color(0xFFF0F4F7),
      body: Stack(
        children: [
          SafeArea(
            child: isDesktop
                ? const DesktopCheckerLayout()
                : const MobileCheckerLayout(),
          ),
          ValueListenableBuilder<bool>(
            valueListenable: _isFileViewerVisible,
            builder: (context, isVisible, _) {
              if (!isVisible) return const SizedBox.shrink();
              return Positioned(
                bottom: 60,
                right: 20,
                width: isDesktop ? 400 : MediaQuery.of(context).size.width * 0.9,
                child: FileViewerModal(
                  title: _selectedFileViewTitle,
                  fileBytes: _selectedFileBytes,
                  onClose: () => _isFileViewerVisible.value = false,
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: isDesktop ? null : const MobileBottomActions(),
    );
  }

  // Modified to handle both dynamically loaded bytes or local assets
  Future<void> _onFileViewRequested(String fileName, [Uint8List? fileBytes]) async {
    Uint8List? bytesToDisplay = fileBytes;

    String targetFileName = fileName.isEmpty ? 'dispconf.pdf' : fileName;
    if (targetFileName == 'Conf703101.pdf') {
      targetFileName = 'dispconf.pdf';
    }

    if (bytesToDisplay == null) {
      try {
        final byteData = await rootBundle.load('assets/$targetFileName');
        bytesToDisplay = byteData.buffer.asUint8List();
      } catch (e) {
        // Fallback to myej file if the format fails or if it's treated as a generic text asset
        try {
          final textByteData = await rootBundle.load('assets/myej');
          bytesToDisplay = textByteData.buffer.asUint8List();
          targetFileName = 'myej';
        } catch (fallbackError) {
          print('Asset file $targetFileName not found: $fallbackError');
        }
      }
    }

    setState(() {
      _selectedFileViewTitle = 'File Viewer: $targetFileName';
      _selectedFileBytes = bytesToDisplay;
    });
    _isFileViewerVisible.value = true;
  }
}

class DesktopCheckerLayout extends StatelessWidget {
  const DesktopCheckerLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const HeaderBar(),
        const TabBarHeader(),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Pending Transactions for Authorization',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold)),
                        Text('Status: Updated 1 second ago',
                            style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: PlutoGridManagerWidget(
                      onFileViewRequested: (fileName, [bytes]) {
                        context
                            .findAncestorStateOfType<_CheckerPanelScreenState>()
                            ?._onFileViewRequested(fileName, bytes);
                      },
                    ),
                  ),
                  const Divider(height: 1),
                  const MobileBottomActions(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class HeaderBar extends StatelessWidget {
  const HeaderBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
          color: Color(0xFFEBEFF2),
          border: Border(bottom: BorderSide(color: Color(0xFFDDE1E4)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(DateFormat('EEEE, MMMM d, yyyy').format(DateTime.now()),
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 8),
          OutlinedButton(
            onPressed: () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.grey, width: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            ),
            child: const Text('Log Out',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
        ],
      ),
    );
  }
}

class TabBarHeader extends StatelessWidget {
  const TabBarHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TabButton(title: 'Checker Panel', isSelected: true),
              SizedBox(width: 4),
              TabButton(title: 'Auditor Dashboard', isSelected: false),
              SizedBox(width: 4),
              TabButton(title: 'Manager Overview', isSelected: false),
            ],
          ),
          Text('Logged in as: Checker',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}

class TabButton extends StatelessWidget {
  final String title;
  final bool isSelected;
  const TabButton({super.key, required this.title, required this.isSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : const Color(0xFFF4F6F8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: const Color(0xFFDCE1E6)),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          color: isSelected ? Colors.black : Colors.black87,
        ),
      ),
    );
  }
}

class PlutoGridManagerWidget extends StatefulWidget {
  final Function(String, [Uint8List?]) onFileViewRequested;
  const PlutoGridManagerWidget({super.key, required this.onFileViewRequested});

  @override
  State<PlutoGridManagerWidget> createState() => _PlutoGridManagerWidgetState();
}

class _PlutoGridManagerWidgetState extends State<PlutoGridManagerWidget> {
  final List<PlutoColumn> columns = [];
  final List<PlutoRow> rows = [];
  PlutoGridStateManager? stateManager;

  @override
  void initState() {
    super.initState();
    _buildColumns();
    _buildRows();
  }

  void _buildColumns() {
    columns.addAll([
      PlutoColumn(
        title: 'Role',
        field: 'role',
        type: PlutoColumnType.select(<String>['Maker', 'Checker', 'Auditor', 'Manager']),
        width: 120,
        enableEditingMode: true,
      ),
      PlutoColumn(
        title: '',
        field: 'select',
        type: PlutoColumnType.select(<String>[]),
        width: 40,
        enableEditingMode: true,
      ),
      PlutoColumn(
        title: 'TraxnID',
        field: 'traxnid',
        type: PlutoColumnType.text(),
        width: 80,
      ),
      PlutoColumn(
        title: 'Subject',
        field: 'subject',
        type: PlutoColumnType.text(),
        width: 150,
      ),
      PlutoColumn(
        title: 'ATMType',
        field: 'atmtype',
        type: PlutoColumnType.text(),
        width: 80,
      ),
      PlutoColumn(
        title: 'TerminalCode',
        field: 'terminalcode',
        type: PlutoColumnType.text(),
        width: 100,
      ),
      PlutoColumn(
        title: 'DebitAcc',
        field: 'debitacc',
        type: PlutoColumnType.text(),
        width: 100,
      ),
      PlutoColumn(
        title: 'Amount',
        field: 'amount',
        type: PlutoColumnType.currency(symbol: '\$'),
        width: 100,
      ),
      PlutoColumn(
        title: 'CreditAcc',
        field: 'creditacc',
        type: PlutoColumnType.text(),
        width: 100,
      ),
      PlutoColumn(
        title: 'TraxnDate',
        field: 'traxndate',
        type: PlutoColumnType.date(format: 'M/d/yyyy h:mm a'),
        width: 150,
      ),
      PlutoColumn(
        title: 'Maker_Uname',
        field: 'maker',
        type: PlutoColumnType.text(),
        width: 100,
      ),
      // Here is the non-icon text button mapping
      PlutoColumn(
        title: 'EJ',
        field: 'ej_file_view',
        type: PlutoColumnType.text(),
        width: 60,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final cellValue = rendererContext.cell.value.toString();
          return InkWell(
            onTap: cellValue.isNotEmpty
                ? () => widget.onFileViewRequested(cellValue)
                : null,
            child: Center(
              child: Text(
                cellValue,
                style: TextStyle(
                  fontSize: 10,
                  color: cellValue.isNotEmpty ? Colors.blue : Colors.black87,
                  decoration: cellValue.isNotEmpty ? TextDecoration.underline : null,
                ),
              ),
            ),
          );
        },
      ),
      _buildFileViewColumn('EJ File', 'ej_file_icon'),
      PlutoColumn(
        title: 'Confirmation File',
        field: 'confirm_file',
        type: PlutoColumnType.text(),
        width: 120,
        enableEditingMode: false,
        renderer: (rendererContext) {
          final cellValue = rendererContext.cell.value.toString();
          if (cellValue.isEmpty) return const SizedBox.shrink();

          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.description_outlined, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              TextButton(
                onPressed: () {
                  widget.onFileViewRequested(cellValue);
                },
                child: const Text('View', style: TextStyle(fontSize: 10, color: Colors.blue)),
              ),
            ],
          );
        },
      ),
      _buildFileViewColumn('debitCreditRecite File', 'receipt_file'),
    ]);
  }

  PlutoColumn _buildFileViewColumn(String title, String field,
      {bool isIcon = true, double width = 80}) {
    return PlutoColumn(
        title: title,
        field: field,
        type: PlutoColumnType.text(),
        width: width,
        enableEditingMode: false,
        renderer: (rendererContext) {
          if (isIcon) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.description_outlined,
                    size: 16, color: Colors.blue),
                const SizedBox(width: 4),
                TextButton(
                  onPressed: () => widget
                      .onFileViewRequested(rendererContext.cell.value.toString()),
                  style: TextButton.styleFrom(
                      minimumSize: const Size(0, 0),
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                  child: const Text('View',
                      style: TextStyle(fontSize: 10, color: Colors.blue)),
                ),
              ],
            );
          } else {
            return Center(
              child: Text(rendererContext.cell.value.toString(),
                  style: const TextStyle(fontSize: 10)),
            );
          }
        });
  }

  void _buildRows() {
    final mockData = [
      {'id': '703101', 'amt': 155.00, 'date': DateTime(2026, 5, 1, 0, 0)},
      {'id': '702012', 'amt': 170.00, 'date': DateTime(2026, 5, 1, 0, 50)},
      {'id': '702302', 'amt': 75.00, 'date': DateTime(2026, 5, 1, 0, 0)},
      {'id': '703302', 'amt': 75.00, 'date': DateTime(2026, 5, 1, 0, 0)},
      {'id': '702394', 'amt': 25.00, 'date': DateTime(2026, 5, 1, 0, 0)},
    ];

    for (var i = 0; i < mockData.length; i++) {
      final data = mockData[i];
      final idText = data['id'] as String;
      final traxnDateTextDate = DateFormat('M/d/yyyy h:mm a').format(data['date'] as DateTime);

      rows.add(PlutoRow(cells: {
        'role': PlutoCell(value: 'Checker'),
        'select': PlutoCell(value: i == 0),
        'traxnid': PlutoCell(value: idText),
        'subject': PlutoCell(value: 'ATM Short-Cash Dispute'),
        'atmtype': PlutoCell(value: 'ATM'),
        'terminalcode': PlutoCell(value: i < 2 ? '7001' : '7002'),
        'debitacc': PlutoCell(value: i < 2 ? '00000C1' : '00009C1'),
        'amount': PlutoCell(value: data['amt'] as double),
        'creditacc': PlutoCell(value: i < 2 ? '00008C2' : '0000RC2'),
        'traxndate': PlutoCell(value: traxnDateTextDate),
        'maker': PlutoCell(value: 'Checker'),
        'ej_file_view': PlutoCell(value: i < 3 ? 'View' : ''), // Displays clickable "View" on text column
        'ej_file_icon': PlutoCell(value: i < 3 ? 'EJ$idText.txt' : ''),
        'confirm_file': PlutoCell(value: i == 0 ? 'Conf$idText.pdf' : ''),
        'receipt_file': PlutoCell(value: i < 1 ? 'Receipt$idText.png' : ''),
      }));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PlutoGrid(
      columns: columns,
      rows: rows,
      onChanged: (PlutoGridOnChangedEvent event) {
        if (event.column.field == 'select') {
          print('Row selected: ${event.value}');
        }
      },
      onLoaded: (PlutoGridOnLoadedEvent event) {
        stateManager = event.stateManager;
        stateManager!.setSelectingMode(PlutoGridSelectingMode.row);
        stateManager!.setShowColumnFilter(true);
      },
      configuration: const PlutoGridConfiguration(
        style: PlutoGridStyleConfig(
          gridBorderColor: Color(0xFFDCE1E6),
          columnHeight: 40,
          rowHeight: 32,
          defaultCellPadding: EdgeInsets.all(4),
          cellTextStyle: TextStyle(fontSize: 10, color: Colors.black87),
          columnTextStyle:
          TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black),
          oddRowColor: Color(0xFFF9FAFB),
          evenRowColor: Colors.white,
          activatedColor: Color(0xFFD0E1F0),
        ),
      ),
    );
  }
}

class FileViewerModal extends StatefulWidget {
  final String title;
  final Uint8List? fileBytes;
  final VoidCallback onClose;

  const FileViewerModal({super.key, required this.title, this.fileBytes, required this.onClose});

  @override
  State<FileViewerModal> createState() => _FileViewerModalState();
}

class _FileViewerModalState extends State<FileViewerModal> {
  // Use a string to check if the asset is text vs PDF
  bool _isTextFile = false;
  String _textContent = '';
  PdfDocument? _document;
  PdfPageImage? _pageImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _handleFileDisplay();
  }

  Future<void> _handleFileDisplay() async {
    if (widget.fileBytes != null) {
      if (widget.title.contains('myej')) {
        setState(() {
          _textContent = String.fromCharCodes(widget.fileBytes!);
          _isTextFile = true;
          _isLoading = false;
        });
      } else {
        await _loadPdfFromBytes(widget.fileBytes!);
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadPdfFromBytes(Uint8List bytes) async {
    try {
      _document = await PdfDocument.openData(bytes);
      final page = await _document!.getPage(1);
      final pageImage = await page.render(
        width: page.width,
        height: page.height,
        format: PdfPageImageFormat.jpeg,
      );

      setState(() {
        _pageImage = pageImage;
        _isTextFile = false;
        _isLoading = false;
      });
      await page.close();
    } catch (e) {
      setState(() {
        _isTextFile = false;
        _isLoading = false;
      });
      print('Error parsing PDF: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 350,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 4))
        ],
        border: Border.all(color: const Color(0xFFBCC6CC)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFEBEFF2),
              borderRadius: BorderRadius.vertical(top: Radius.circular(7)),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, size: 18, color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(widget.title,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold))),
                InkWell(
                  onTap: widget.onClose,
                  child: const Icon(Icons.close, size: 18, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _isTextFile
                ? SingleChildScrollView(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                _textContent,
                style: const TextStyle(
                    fontFamily: 'monospace', fontSize: 10, color: Colors.black87),
              ),
            )
                : _pageImage != null
                ? InteractiveViewer(
              child: Image.memory(_pageImage!.bytes),
            )
                : const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Text('Confirmation Document loaded for verification.'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class MobileBottomActions extends StatelessWidget {
  const MobileBottomActions({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Upload Files',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            Container(
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: const Color(0xFFDCE1E6), width: 1),
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.drive_folder_upload, size: 28, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('Drag-and drop',
                        style: TextStyle(fontSize: 12, color: Colors.black87)),
                    Text('CSV, Excel, PDF, PNG, JPG, TXT',
                        style: TextStyle(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Status: Updated 1 second ago',
                    style: TextStyle(color: Colors.grey, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MobileCheckerLayout extends StatelessWidget {
  const MobileCheckerLayout({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('Mobile Layout Placeholder - Simplified'));
  }
}
//flutter pub add parse_server_sdk_flutter
//flutter pub get