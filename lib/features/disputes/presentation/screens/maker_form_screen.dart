import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/responsive_shell.dart';

enum AccountTypeSelection { atm, access }
enum AtmType { ncr, crm }

class MakerFormScreen extends ConsumerStatefulWidget {
  const MakerFormScreen({super.key});

  @override
  ConsumerState<MakerFormScreen> createState() => _MakerFormScreenState();
}

class _MakerFormScreenState extends ConsumerState<MakerFormScreen> {
  final _terminalController = TextEditingController();
  final _amountController = TextEditingController();
  final _debitAccountController = TextEditingController();
  final _creditAccountController = TextEditingController();
  final _makerController = TextEditingController(text: "Sufian Aliyyii");
  final _checkerController = TextEditingController();
  final _subjectController = TextEditingController();
  final _entryDateController = TextEditingController();
  final _transactionDateController = TextEditingController();
  final _descriptionController = TextEditingController();

  AtmType _selectedAtmType = AtmType.crm;
  AccountTypeSelection _selectedAccountType = AccountTypeSelection.atm;
  String? _fileName;

  final List<TransactionRow> _transactionRows = [
    TransactionRow("ETB100050010116", "5,000.00", "ETB1234567890123", "2024-04-24"),
    TransactionRow("ETB1000012324852", "5,000.00", "ETB1000012324852", "2024-04-24"),
    TransactionRow("ETB100050010116", "5,000.00", "ETB1234567890123", "2024-04-24"),
  ];

  @override
  void dispose() {
    _terminalController.dispose();
    _amountController.dispose();
    _debitAccountController.dispose();
    _creditAccountController.dispose();
    _makerController.dispose();
    _checkerController.dispose();
    _subjectController.dispose();
    _entryDateController.dispose();
    _transactionDateController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _autoFillAccounts() {
    String input = _terminalController.text.trim();
    if (input.length < 4) {
      return;
    }

    String fourDigitSuffix = input.substring(input.length - 4);
    int fourthDigitFromEnd = int.tryParse(fourDigitSuffix[0]) ?? 0;
    int adjustedDigit = fourthDigitFromEnd + 1;
    String lastThreeDigits = fourDigitSuffix.substring(1);
    String finalExtension = "$adjustedDigit" "0" "$lastThreeDigits";

    String baseAtmNcr = 'ETB10002000';
    String baseAtmCrm = 'ETB10005000';
    String baseAccessNcr = 'ETB17643000';
    String baseAccessCrm = 'ETB17644000';

    setState(() {
      if (_selectedAtmType == AtmType.ncr) {
        if (_selectedAccountType == AccountTypeSelection.atm) {
          _debitAccountController.text = '$baseAtmNcr$finalExtension';
        } else {
          _debitAccountController.text = '$baseAccessNcr$finalExtension';
        }
      } else {
        if (_selectedAccountType == AccountTypeSelection.atm) {
          _debitAccountController.text = '$baseAtmCrm$finalExtension';
        } else {
          _debitAccountController.text = '$baseAccessCrm$finalExtension';
        }
      }
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'xlsx', 'xls'],
    );

    if (result != null) {
      setState(() {
        _fileName = result.files.single.name;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ResponsiveShell(
      currentRoute: '/dispute_maker',
      title: 'Dispute Management',
      subtitle: 'Maker Portal & Workflow Engine',
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: LayoutBuilder(
          builder: (context, constraints) {
            bool isWideScreen = constraints.maxWidth > 900;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionCard(
                  title: "1. Transaction Source (Dropdowns & Autocomplete)",
                  content: Column(
                    children: [
                      _buildResponsiveRow(
                        isWideScreen,
                        children: [
                          _buildDropdownField<AtmType>(
                            label: "ATM Type",
                            value: _selectedAtmType,
                            items: const [
                              DropdownMenuItem(value: AtmType.ncr, child: Text("NCR")),
                              DropdownMenuItem(value: AtmType.crm, child: Text("CRM")),
                            ],
                            onChanged: (AtmType? v) {
                              if (v != null) {
                                setState(() {
                                  _selectedAtmType = v;
                                });
                                _autoFillAccounts();
                              }
                            },
                          ),
                          _buildDropdownField<AccountTypeSelection>(
                            label: "Account Type",
                            value: _selectedAccountType,
                            items: const [
                              DropdownMenuItem(
                                  value: AccountTypeSelection.atm,
                                  child: Text("ATM Account")),
                              DropdownMenuItem(
                                  value: AccountTypeSelection.access,
                                  child: Text("Access/Payble Account")),
                            ],
                            onChanged: (AccountTypeSelection? v) {
                              if (v != null) {
                                setState(() {
                                  _selectedAccountType = v;
                                });
                                _autoFillAccounts();
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isWideScreen,
                        children: [
                          TextFormField(
                            controller: _terminalController,
                            decoration: const InputDecoration(
                              labelText: "Terminal Code (e.g., 0116)",
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.pin_outlined),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            onChanged: (value) => _autoFillAccounts(),
                          ),
                          TextFormField(
                            controller: _debitAccountController,
                            decoration: const InputDecoration(
                              labelText: "Auto-Account",
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                            readOnly: true,
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _buildResponsiveRow(
                        isWideScreen,
                        children: [
                          TextFormField(
                            controller: _amountController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: "Amount (ETB)",
                              border: OutlineInputBorder(),
                              prefixText: "ETB ",
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                          TextFormField(
                            controller: _creditAccountController,
                            decoration: const InputDecoration(
                              labelText: "Credit Acc",
                              border: OutlineInputBorder(),
                              filled: true,
                              fillColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        alignment: WrapAlignment.start,
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF003366),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onPressed: () {},
                            icon: const Icon(Icons.upload_file, size: 18),
                            label: const Text("Upload EJ"),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onPressed: () async {
                              DateTime? picked = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2030),
                              );
                              if (picked != null) {
                                setState(() {
                                  _transactionDateController.text =
                                  picked.toString().split(' ')[0];
                                });
                              }
                            },
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(
                              _transactionDateController.text.isEmpty
                                  ? "Transaction Date"
                                  : _transactionDateController.text,
                            ),
                          ),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                            ),
                            onPressed: _pickFile,
                            icon: const Icon(Icons.attach_file, size: 18),
                            label: Text(
                              _fileName == null
                                  ? "Upload Confirmation Letter"
                                  : "File: ${_fileName!.length > 15 ? _fileName!.substring(0, 12) + '...' : _fileName}",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: "2. Transaction Details (Dense Data Grid/Table)",
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowColor:
                          WidgetStateProperty.all(Colors.grey[200]),
                          border: TableBorder.all(color: Colors.grey.shade300),
                          columns: const [
                            DataCell(Text("Debit Account",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13))),
                            DataCell(Text("Amount (ETB)",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13))),
                            DataCell(Text("Credit (Customer) Account",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13))),
                            DataCell(Text("Transaction Date",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13))),
                            DataCell(Text("Actions",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13))),
                          ]
                              .map((cell) => DataColumn(
                              label: (cell).child))
                              .toList(),
                          rows: _transactionRows.map((row) {
                            return DataRow(cells: [
                              DataCell(Text(row.debitAccount)),
                              DataCell(Text(row.amount)),
                              DataCell(Text(row.creditAccount)),
                              DataCell(Text(row.transactionDate)),
                              DataCell(
                                Wrap(
                                  spacing: 6,
                                  children: [
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.blue,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(60, 30),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                      ),
                                      onPressed: () {},
                                      icon: const Icon(Icons.edit, size: 12),
                                      label: const Text("Edit",
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                    ElevatedButton.icon(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        minimumSize: const Size(60, 30),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6),
                                      ),
                                      onPressed: () {},
                                      icon: const Icon(Icons.delete, size: 12),
                                      label: const Text("Delete",
                                          style: TextStyle(fontSize: 11)),
                                    ),
                                  ],
                                ),
                              ),
                            ]);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        alignment: WrapAlignment.spaceBetween,
                        children: [
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF003366)),
                            onPressed: () {},
                            icon: const Icon(Icons.add),
                            label: const Text("Add Transaction Row"),
                          ),
                          OutlinedButton(
                            onPressed: () {},
                            child: const Text("Upload credit and debit recite"),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildSectionCard(
                  title: "3. Processing & File Upload Zone",
                  content: isWideScreen
                      ? Row(
                    children: [
                      Expanded(flex: 3, child: _buildUploadZone()),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: _buildSummaryZone()),
                    ],
                  )
                      : Column(
                    children: [
                      _buildUploadZone(),
                      const SizedBox(height: 16),
                      _buildSummaryZone(),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      onPressed: () {},
                      child: const Text("Discard Changes"),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                      ),
                      onPressed: () {
                        //Navigate to Checker UI
                        Navigator.pushNamed(context, '/disputeChecker');///disputeChecker
                      },
                      child: const Text("Submit to Checker / Save"),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "User: Sufian Aliyyii (Maker)  |  Date: 2026-05-03  |   HO: Digital Banking",
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget content}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Color(0xFFE0E0E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF003366),
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveRow(bool isWideScreen, {required List<Widget> children}) {
    if (isWideScreen) {
      return Row(
        children: children.map((e) => Expanded(child: e)).toList().expand(
                (widget) => [
              widget,
              const SizedBox(width: 16)
            ]).toList()
          ..removeLast(),
      );
    } else {
      return Column(
        children:
        children.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: e,
        )).toList(),
      );
    }
  }

  Widget _buildDropdownField<T>({
    required String label,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        filled: true,
        fillColor: Colors.white,
      ),
      items: items,
      onChanged: onChanged,
    );
  }

  Widget _buildUploadZone() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.all(color: Colors.grey, style: BorderStyle.solid),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Column(
          children: [
            const Icon(Icons.cloud_upload, size: 40, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              _fileName ?? "[ Drag & Drop CSV/Excel File ]",
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryZone() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Summary:",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          SizedBox(height: 8),
          Text("Total Records: 1"),
          Text("Total Amount (ETB): 5,000.00"),
        ],
      ),
    );
  }
}

class TransactionRow {
  final String debitAccount;
  final String amount;
  final String creditAccount;
  final String transactionDate;

  TransactionRow(this.debitAccount, this.amount, this.creditAccount, this.transactionDate);
}