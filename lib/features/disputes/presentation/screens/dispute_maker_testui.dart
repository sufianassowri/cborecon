import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

class MakerUI extends StatefulWidget {
  const MakerUI({super.key});

  @override
  State<MakerUI> createState() => _MakerUIState();
}

class _MakerUIState extends State<MakerUI> {
  final _terminalController = TextEditingController();
  PlatformFile? ejFile, confFile, receiptFile;
  bool _isLoading = false;

  // Function to pick a generic file
  Future<void> pickFile(String type) async {
    FilePickerResult? result = await FilePicker.pickFiles();
    if (result != null) {
      setState(() {
        if (type == 'ej') ejFile = result.files.first;
        if (type == 'conf') confFile = result.files.first;
        if (type == 'receipt') receiptFile = result.files.first;
      });
    }
  }
  // The main upload logic
  Future<void> submitToBack4App() async {
    if (_terminalController.text.isEmpty || ejFile == null || confFile == null || receiptFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields and upload all files.")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create ParseFile objects from the picked files
      ParseFileBase? parseEj = kIsWeb ? ParseWebFile(ejFile!.bytes, name: ejFile!.name) : ParseFile(File(ejFile!.path!));
      ParseFileBase? parseConf = kIsWeb ? ParseWebFile(confFile!.bytes, name: confFile!.name) : ParseFile(File(confFile!.path!));
      ParseFileBase? parseReceipt = kIsWeb ? ParseWebFile(receiptFile!.bytes, name: receiptFile!.name) : ParseFile(File(receiptFile!.path!));

      // 2. Define the ParseObject and set its fields
      final transaction = ParseObject('DisputeTransaction')
        ..set('terminalCode', _terminalController.text)
        ..set('ejFile', parseEj)
        ..set('confFile', parseConf)
        ..set('receiptFile', parseReceipt);

      // 3. Save to the cloud
      final response = await transaction.save();

      if (response.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submitted to Checker successfully.")));
          Navigator.pop(context); // Go back to main screen
        }
      } else {
        throw Exception(response.error?.message);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Upload failed: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Matching the dark UI from your sketch
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.transparent,
      foregroundColor: const Color(0xFF00E5FF), // Cyan from sketch
      side: const BorderSide(color: Color(0xFF00E5FF), width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Very dark background
      appBar: AppBar(title: const Text("Maker UI", style: TextStyle(color: Color(0xFF00E5FF)))),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF00E5FF)))
            : ListView(
          children: [
            const Text("Terminal code", style: TextStyle(fontSize: 18, color: Colors.white70)),
            const SizedBox(height: 10),
            TextField(
              controller: _terminalController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: "Enter Terminal Code (e.g., 0116)",
                hintStyle: const TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 30),

            // File Picking Buttons
            FilePickButton(title: "EJ", file: ejFile, onPick: () => pickFile('ej'), style: buttonStyle),
            FilePickButton(title: "Confirmation", file: confFile, onPick: () => pickFile('conf'), style: buttonStyle),
            FilePickButton(title: "Dr,Cr Recipt", file: receiptFile, onPick: () => pickFile('receipt'), style: buttonStyle),

            const SizedBox(height: 40),
            ElevatedButton(
              onPressed: submitToBack4App,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("SUBMIT TRANSACTION", style: TextStyle(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      ),
    );
  }
}

// Simple helper widget to show the picked filename
class FilePickButton extends StatelessWidget {
  final String title;
  final PlatformFile? file;
  final VoidCallback onPick;
  final ButtonStyle style;

  const FilePickButton({super.key, required this.title, required this.file, required this.onPick, required this.style});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ElevatedButton(onPressed: onPick, style: style, child: Text(title)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              file?.name ?? "No file selected",
              style: TextStyle(color: file != null ? Colors.white70 : Colors.white24, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}