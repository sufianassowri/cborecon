import 'package:flutter/material.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';

import '../../data/data_source/remote_dipute_data_source.dart';
//import 'file_upload_service.dart'; // Import your logic code file here

class UploadScreen extends StatefulWidget {
  const UploadScreen({super.key});

  @override
  State<UploadScreen> createState() => _UploadScreenState();
}

class _UploadScreenState extends State<UploadScreen> {
  bool _isLoading = false;
  String _currentStatus = "";

  // void _startFileUpload() async {
  //   setState(() {
  //     _isLoading = true;
  //     _currentStatus = "Opening file picker...";
  //   });
  //
  //   await FileUploadService.pickAndProcessFile(
  //     onStatusUpdate: (status) {
  //       setState(() => _currentStatus = status);
  //     },
  //     onSuccess: (message) {
  //       setState(() => _isLoading = false);
  //       _showNotificationSnackBar(message, isError: false);
  //     },
  //     onError: (errorMessage) {
  //       setState(() => _isLoading = false);
  //       _showNotificationSnackBar(errorMessage, isError: true);
  //     },
  //     onCancel: () {
  //       setState(() => _isLoading = false);
  //     },
  //   );
  // }
  void _startFileUpload() async {
    setState(() {
      _isLoading = true;
      _currentStatus = "Authenticating securely...";
    });

    try {
      // 1. Check if a session already exists
      ParseUser? currentUser = await ParseUser.currentUser() as ParseUser?;

      if (currentUser == null) {
        // Create a unique temporary username using a timestamp
        final tempUsername = "user_${DateTime.now().millisecondsSinceEpoch}";
        final anonymousUser = ParseUser(tempUsername, "Pass123!", null)
          ..set("name", "Anonymous Upload Guest") // Satisfies "name is required"
          ..set("price", 0);                     // FIX: Satisfies "price is required"

        // Sign up without email constraint
        ParseResponse authResponse = await anonymousUser.signUp(allowWithoutEmail: true);

        if (!authResponse.success) {
          setState(() => _isLoading = false);
          _showNotificationSnackBar("Auth Failed: ${authResponse.error?.message}", isError: true);
          return;
        }
        print("Temporary verified session active with all custom validations satisfied.");
      }

      setState(() => _currentStatus = "Opening file picker...");

      // 2. Run your normal upload service now that the session token is active
      await FileUploadService.pickAndProcessFile(
        onStatusUpdate: (status) => setState(() => _currentStatus = status),
        onSuccess: (message) {
          setState(() => _isLoading = false);
          _showNotificationSnackBar(message, isError: false);
        },
        onError: (errorMessage) {
          setState(() => _isLoading = false);
          _showNotificationSnackBar(errorMessage, isError: true);
        },
        onCancel: () => setState(() => _isLoading = false),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      _showNotificationSnackBar("Error: $e", isError: true);
    }
  }

  void _showNotificationSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Media query parameters to control structural layout scaling responsiveness
    final double screenWidth = MediaQuery.of(context).size.width;
    final bool isLargeScreen = screenWidth > 700;

    return Scaffold(
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
        title: const Text('Back4app Document Central', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF003366),
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Center(
        child: Container(
          // Set maximum constraint width boundaries for rich display on desktop
          constraints: BoxConstraints(maxWidth: isLargeScreen ? 600 : double.infinity),
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.cloud_upload_outlined,
                    size: 72,
                    color: _isLoading ? Colors.blue.shade300 : Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Upload & Process Records',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Select files to process seamlessly inside Back4app Cloud environment.',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),

                  // Interactive File Drop/Upload Zone
                  InkWell(
                    onTap: _isLoading ? null : _startFileUpload,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _isLoading ? Colors.blue.shade200 : Colors.grey.shade300,
                          style: BorderStyle.solid,
                          width: 2,
                        ),
                      ),
                      child: _isLoading
                          ? Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          Text(
                            _currentStatus,
                            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.blue),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      )
                          : Column(
                        children: [
                          const Icon(Icons.insert_drive_file_outlined, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text(
                            'Click to browse local files',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            alignment: WrapAlignment.center,
                            children: const [
                              _TypeBadge(label: 'XLSX', color: Colors.green),
                              _TypeBadge(label: 'CSV', color: Colors.teal),
                              _TypeBadge(label: 'PDF', color: Colors.red),
                              _TypeBadge(label: 'IMAGES', color: Colors.purple),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _TypeBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }
}