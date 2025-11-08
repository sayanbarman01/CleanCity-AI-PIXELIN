import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter_map/flutter_map.dart';

class RouteDashboardScreen extends StatefulWidget {
  const RouteDashboardScreen({super.key});

  @override
  State<RouteDashboardScreen> createState() => _RouteDashboardScreenState();
}

class _RouteDashboardScreenState extends State<RouteDashboardScreen> {
  bool isLoading = false;
  Map<String, dynamic>? routeData;

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  // 🔹 Fetch assignments from backend
  Future<void> _fetchAssignments() async {
    setState(() => isLoading = true);

    try {
      // You can later fetch real bins/trucks from Firestore, for now we simulate
      final bins = [
        {"id": "b1", "name": "Bin 1", "lat": 22.57, "lng": 88.36, "fill_percent": 85, "importance_level": 3},
        {"id": "b2", "name": "Bin 2", "lat": 22.58, "lng": 88.40, "fill_percent": 60, "importance_level": 2},
        {"id": "b3", "name": "Bin 3", "lat": 22.59, "lng": 88.42, "fill_percent": 30, "importance_level": 1},
      ];

      final trucks = [
        {"id": "truck1", "name": "Truck 1", "lat": 22.56, "lng": 88.35, "status": "idle"},
        {"id": "truck2", "name": "Truck 2", "lat": 22.61, "lng": 88.41, "status": "idle"},
      ];

      final url = Uri.parse("http://10.0.2.2:8000/ai_assign"); // replace with backend IP if on real device
      final res = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"bins": bins, "trucks": trucks}),
      );

      if (res.statusCode == 200) {
        setState(() {
          routeData = jsonDecode(res.body);
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("❌ Failed to fetch routes (${res.statusCode})")),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("⚠️ Error: $e")));
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("AI Route Dashboard", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        actions: [
          IconButton(
            onPressed: _fetchAssignments,
            icon: const Icon(Icons.refresh, color: Colors.greenAccent),
          ),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
          : routeData == null
              ? const Center(
                  child: Text("No data yet.\nTap refresh to get routes.",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16)))
              : _buildDashboardContent(),
    );
  }

  // 🧩 UI for dashboard
  Widget _buildDashboardContent() {
    final assignments = routeData!["assignments"] ?? {};

    return ListView(
      padding: const EdgeInsets.all(16),
      children: assignments.entries.map((entry) {
        final truckId = entry.key;
        final truckData = entry.value;

        final assignedBins = List<Map<String, dynamic>>.from(truckData["ordered_route"]);
        final geometry = List<List<dynamic>>.from(truckData["road_geometry"]);
        final distance = truckData["distance_km"];
        final eta = truckData["eta_minutes"];

        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E1E1E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
          ),
          child: ExpansionTile(
            collapsedIconColor: Colors.greenAccent,
            iconColor: Colors.greenAccent,
            title: Text(
              "🚚 $truckId",
              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            subtitle: Text(
              "🛣 $distance km | ⏱ ${eta.toStringAsFixed(1)} min",
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            children: [
              // Bins List
              ...assignedBins.map((b) => ListTile(
                    leading: Icon(Icons.delete, color: _priorityColor(b["priority_score"] ?? 0)),
                    title: Text(b["id"], style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      "Priority: ${(b["priority_score"] ?? 0).toStringAsFixed(1)}",
                      style: const TextStyle(color: Colors.grey),
                    ),
                  )),

              // Mini Map
              if (geometry.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: LatLng(geometry.first[0], geometry.first[1]),
                      initialZoom: 13,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                        userAgentPackageName: 'com.cleancity',
                      ),
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: geometry
                                .map((p) => LatLng(p[0].toDouble(), p[1].toDouble()))
                                .toList(),
                            strokeWidth: 4,
                            color: Colors.blueAccent,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  // 🔹 Priority color logic
  Color _priorityColor(double score) {
    if (score >= 80) return Colors.redAccent;
    if (score >= 50) return Colors.orangeAccent;
    return Colors.greenAccent;
  }
}
