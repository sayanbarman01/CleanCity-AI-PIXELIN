import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bins_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("CleanCity Dashboard")),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection("states").snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final states = snap.data!.docs;

          return ListView(
            children: states.map((stateDoc) {
              return _StateTile(stateDoc: stateDoc);
            }).toList(),
          );
        },
      ),
    );
  }
}

class _StateTile extends StatelessWidget {
  final QueryDocumentSnapshot stateDoc;

  const _StateTile({required this.stateDoc});

  @override
  Widget build(BuildContext context) {
    final stateId = stateDoc.id;
    final stateName = stateDoc['name'];

    return FutureBuilder<double>(
      future: _computeStateCleanliness(stateId),
      builder: (context, snap) {
        if (!snap.hasData) {
          return ListTile(title: Text(stateName), subtitle: const Text("Calculating..."));
        }

        final clean = snap.data!;

        return ListTile(
          title: Text(stateName),
          subtitle: Text("${clean.toStringAsFixed(1)}% clean"),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => DistrictScreen(stateId: stateId)),
            );
          },
        );
      },
    );
  }
}

// ✅ AUTO CALCULATE STATE CLEAN
Future<double> _computeStateCleanliness(String stateId) async {
  final distSnap = await FirebaseFirestore.instance
      .collection("states")
      .doc(stateId)
      .collection("districts")
      .get();

  if (distSnap.docs.isEmpty) return 100;

  double total = 0;
  int count = 0;

  for (var d in distSnap.docs) {
    final clean = await _computeDistrictCleanliness(stateId, d.id);
    total += clean;
    count++;
  }

  return total / count;
}

// ✅ AUTO CALCULATE DISTRICT CLEAN
Future<double> _computeDistrictCleanliness(String stateId, String districtId) async {
  final bins = await FirebaseFirestore.instance
      .collection("states")
      .doc(stateId)
      .collection("districts")
      .doc(districtId)
      .collection("bins")
      .get();

  if (bins.docs.isEmpty) return 100;

  double totalFill = 0;

  for (var b in bins.docs) {
    totalFill += (b['fill_percent'] ?? 0).toDouble();
  }

  double avgFill = totalFill / bins.docs.length;
  return 100 - avgFill;
}
////////////////////////////////
// ✅ DISTRICT SCREEN
class DistrictScreen extends StatelessWidget {
  final String stateId;
  const DistrictScreen({super.key, required this.stateId});

  @override
  Widget build(BuildContext context) {
    final distRef = FirebaseFirestore.instance
        .collection("states")
        .doc(stateId)
        .collection("districts");

    return Scaffold(
      appBar: AppBar(title: const Text("Districts")),
      body: StreamBuilder<QuerySnapshot>(
        stream: distRef.snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final districts = snap.data!.docs;

          return ListView(
            children: districts.map((d) {
              final name = d['name'];
              final districtId = d.id;

              // District Cleanliness FutureBuilder
              return FutureBuilder<double>(
                future: _computeDistrictCleanliness(stateId, districtId),
                builder: (context, cleanSnap) {
                  if (!cleanSnap.hasData) {
                    return ListTile(title: Text(name), subtitle: const Text("Calculating..."));
                  }

                  final clean = cleanSnap.data!;

                  return ListTile(
                    title: Text(name),
                    subtitle: Text("${clean.toStringAsFixed(1)}% clean"),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => FirestoreBinsScreen(
                            stateId: stateId,
                            districtId: districtId,
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}