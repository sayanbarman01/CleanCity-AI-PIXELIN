import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreBinsScreen extends StatelessWidget {
  final String stateId;
  final String districtId;

  const FirestoreBinsScreen({
    super.key,
    required this.stateId,
    required this.districtId,
  });

  @override
  Widget build(BuildContext context) {
    final binsRef = FirebaseFirestore.instance
        .collection('states')
        .doc(stateId)
        .collection('districts')
        .doc(districtId)
        .collection('bins');

    return Scaffold(
      appBar: AppBar(title: const Text("Bins")),
      body: StreamBuilder<QuerySnapshot>(
        stream: binsRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snap.data!.docs;

          return ListView(
            children: docs.map((binDoc) {
              final b = binDoc.data() as Map<String, dynamic>;
              final fill = (b['fill_percent'] ?? 0).toDouble();

              Color color = Colors.green;
              if (fill >= 80) color = Colors.red;
              else if (fill >= 50) color = Colors.orange;

              return ListTile(
                leading: Icon(Icons.delete, color: color),
                title: Text(b['name']),
                subtitle: Text(
                  "Fill: ${fill.toStringAsFixed(0)}%  |  Imp: ${b['importance_level'] ?? 1}"
                      ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _editBinFill(context, binDoc.reference, fill),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _editBinFill(BuildContext context, DocumentReference ref, double current) {
    final controller = TextEditingController(text: current.toString());

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Edit Fill %"),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              final value = double.tryParse(controller.text) ?? current;
              ref.update({'fill_percent': value});
              Navigator.pop(context);
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}