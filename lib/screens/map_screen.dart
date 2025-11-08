import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final MapController _map = MapController();

  List<LatLng> routePoints = [];
  double distanceKm = 0;
  double etaMin = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Map")),

      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.alt_route),
        onPressed: _selectStateDistrict,
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collectionGroup('bins').snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final markers = snap.data!.docs.map((doc) {
            final d = doc.data() as Map<String, dynamic>;

            final fill = (d['fill_percent'] ?? 0).toDouble();
            Color color = Colors.green;
            if (fill >= 80) {
              color = Colors.red;
            } else if (fill >= 50) {
              color = Colors.orange;
            }

            return Marker(
              point: LatLng(d['lat'], d['lng']),
              width: 40,
              height: 40,
              child: GestureDetector(
                onTap: () {
                  _editBinFill(context, doc.reference, fill);
                },
                child: Icon(
                  Icons.delete,
                  size: 32,
                  color: color,
                ),
              ),
            );
          }).toList();

          return FlutterMap(
            mapController: _map,
            options: const MapOptions(
              initialZoom: 5,
              initialCenter: LatLng(22.57, 88.36),
            ),
            children: [
              TileLayer(
                urlTemplate: "https://tile.openstreetmap.org/{z}/{x}/{y}.png",
                userAgentPackageName: 'com.cleancity',
              ),

              //  district bins
              MarkerLayer(markers: markers),

              //  AI route polyline
              if (routePoints.isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: routePoints,
                      strokeWidth: 5,
                      color: Colors.blue,
                    )
                  ],
                ),

              //  START + END POPUP MARKERS
              if (routePoints.isNotEmpty)
                MarkerLayer(
                  markers: [
                    //  START MARKER (Green)
                    Marker(
                      point: routePoints.first,
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                          _showPopup("Route Start", routePoints.first);
                        },
                        child: const Icon(
                          Icons.location_on,
                          color: Colors.green,
                          size: 38,
                        ),
                      ),
                    ),

                    //  END MARKER (Red Flag)
                    Marker(
                      point: routePoints.last,
                      width: 80,
                      height: 80,
                      child: GestureDetector(
                        onTap: () {
                          _showPopup("Route End", routePoints.last);
                        },
                        child: const Icon(
                          Icons.flag,
                          color: Colors.red,
                          size: 38,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),

      bottomSheet: (distanceKm > 0)
          ? Container(
              color: Colors.white,
              padding: const EdgeInsets.all(12),
              child: Text(
                "Distance: ${distanceKm.toStringAsFixed(2)} km | ETA: ${etaMin.toStringAsFixed(1)} min",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            )
          : null,
    );
  }

  //  Show popup dialog
  void _showPopup(String title, LatLng point) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text("Lat: ${point.latitude}\nLng: ${point.longitude}"),
        actions: [
          TextButton(
            child: const Text("OK"),
            onPressed: () => Navigator.pop(context),
          )
        ],
      ),
    );
  }

  //  Select State → District
  void _selectStateDistrict() async {
    String? selectedState;
    String? selectedDistrict;

    selectedState = await _pickState();
    if (selectedState == null) return;

    selectedDistrict = await _pickDistrict(selectedState);
    if (selectedDistrict == null) return;

    _computeRoute(selectedState, selectedDistrict);
  }

  //  Pick State
  Future<String?> _pickState() async {
    final states = await FirebaseFirestore.instance.collection("states").get();

    return showDialog<String>(
      context: context,
      builder: (_) {
        return SimpleDialog(
          title: const Text("Select State"),
          children: states.docs.map((e) {
            return SimpleDialogOption(
              child: Text(e["name"]),
              onPressed: () => Navigator.pop(context, e.id),
            );
          }).toList(),
        );
      },
    );
  }

  //  Pick District
  Future<String?> _pickDistrict(String stateId) async {
    final dists = await FirebaseFirestore.instance
        .collection("states")
        .doc(stateId)
        .collection("districts")
        .get();

    return showDialog<String>(
      context: context,
      builder: (_) {
        return SimpleDialog(
          title: const Text("Select District"),
          children: dists.docs.map((e) {
            return SimpleDialogOption(
              child: Text(e["name"]),
              onPressed: () => Navigator.pop(context, e.id),
            );
          }).toList(),
        );
      },
    );
  }

  //  Compute AI Route
  Future<void> _computeRoute(String stateId, String districtId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) =>
          const Center(child: CircularProgressIndicator(strokeWidth: 6)),
    );

    final binsSnap = await FirebaseFirestore.instance
        .collection("states")
        .doc(stateId)
        .collection("districts")
        .doc(districtId)
        .collection("bins")
        .get();

    final bins = binsSnap.docs.map((d) {
      final data = d.data();
      return {
        "id": d.id,
        "name": data["name"],
        "lat": data["lat"],
        "lng": data["lng"],
        "fill_percent": data["fill_percent"],
        "importance_level": data["importance_level"],
      };
    }).toList();

 final url = Uri.parse("https://sb0101-backend.hf.space/ai_route");
    final res = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"bins": bins}),
    );

    Navigator.pop(context);

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      List coords = data["road_geometry"];
      setState(() {
        routePoints = coords
            .map<LatLng>((p) => LatLng(p[1].toDouble(), p[0].toDouble()))
            .toList();

        distanceKm = data["distance_km"];
        etaMin = data["eta_minutes"];
      });

      if (routePoints.isNotEmpty) {
        _map.move(routePoints.first, 12);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("AI Route failed")),
      );
    }
  }

  //  Edit bin fill %
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
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
