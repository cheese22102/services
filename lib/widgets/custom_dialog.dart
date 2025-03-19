import 'package:flutter/material.dart';

class CustomDialog {
  static void show(
    BuildContext context, 
    String title, 
    String message, 
    {VoidCallback? onConfirm}
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm?.call();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  static void showWithActions(
    BuildContext context, 
    String title, 
    String message, 
    List<Widget> actions
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning, color: Colors.orange),
            const SizedBox(width: 10),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: actions,
      ),
    );
  }
}