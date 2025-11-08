import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'bins_screen.dart';

// ===================== CLEANLINESS CALCULATION ===================== //
Future<double> _computeDistrictCleanliness(
  String stateId,
  String districtId,
) async {
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
  return 100 - (totalFill / bins.docs.length);
}

Future<double> _computeStateCleanliness(String stateId) async {
  final distSnap = await FirebaseFirestore.instance
      .collection("states")
      .doc(stateId)
      .collection("districts")
      .get();

  if (distSnap.docs.isEmpty) return 100;

  double total = 0;
  for (var d in distSnap.docs) {
    total += await _computeDistrictCleanliness(stateId, d.id);
  }
  return total / distSnap.docs.length;
}

// ===================== DASHBOARD SCREEN ===================== //
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  int _refreshKey = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    // Fade animation on Dashboard load
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeInOut,
    );

    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  // Pull-to-refresh handler
  Future<void> _onRefresh() async {
    setState(() => _refreshKey++);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Scaffold(
        backgroundColor: const Color(0xFF1C1C1E),
        appBar: AppBar(
          backgroundColor: const Color(0xFF000000),
          elevation: 0,
          title: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF00D4FF), Color(0xFF0077ED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                "CleanCity",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _onRefresh,
          backgroundColor: const Color(0xFF2C2C2E),
          color: const Color(0xFF0A84FF),
          child: StreamBuilder<QuerySnapshot>(
            key: ValueKey(_refreshKey),
            stream: FirebaseFirestore.instance.collection("states").snapshots(),
            builder: (context, snap) {
              if (!snap.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: snap.data!.docs.length,
                itemBuilder: (context, index) {
                  return _StateTile(stateDoc: snap.data!.docs[index]);
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ===================== STATE CARD WIDGET ===================== //
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
        final clean = snap.data ?? 0;
        final isLoading = !snap.hasData;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF2C2C2E),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    transitionDuration: const Duration(milliseconds: 500),
                    pageBuilder: (_, __, ___) =>
                        DistrictScreen(stateId: stateId),
                    transitionsBuilder: (_, animation, __, child) =>
                        FadeTransition(opacity: animation, child: child),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getGradientColors(clean),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getCleanIcon(clean),
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stateName,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 6),
                          isLoading
                              ? const Text(
                                  "Loading...",
                                  style: TextStyle(color: Color(0xFF8E8E93)),
                                )
                              : Text(
                                  "${clean.toStringAsFixed(1)}% Clean",
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                    color: _getSolidColor(clean),
                                  ),
                                ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Color(0xFF636366),
                      size: 16,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  List<Color> _getGradientColors(double clean) {
    if (clean >= 80) return [const Color(0xFF32D74B), const Color(0xFF30D158)];
    if (clean >= 50) return [const Color(0xFFFF9F0A), const Color(0xFFFF9500)];
    return [const Color(0xFFFF453A), const Color(0xFFFF3B30)];
  }

  Color _getSolidColor(double clean) {
    if (clean >= 80) return const Color(0xFF32D74B);
    if (clean >= 50) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }

  IconData _getCleanIcon(double clean) {
    if (clean >= 80) return Icons.check_circle_rounded;
    if (clean >= 50) return Icons.warning_rounded;
    return Icons.error_rounded;
  }
}

// ===================== DISTRICT SCREEN ===================== //
class DistrictScreen extends StatefulWidget {
  final String stateId;
  const DistrictScreen({super.key, required this.stateId});

  @override
  State<DistrictScreen> createState() => _DistrictScreenState();
}

class _DistrictScreenState extends State<DistrictScreen> {
  int _refreshKey = 0;

  Future<void> _onRefresh() async {
    setState(() => _refreshKey++);
    await Future.delayed(const Duration(milliseconds: 500));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1C1C1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Districts",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.5,
            color: Colors.white,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        backgroundColor: const Color(0xFF2C2C2E),
        color: const Color(0xFF0A84FF),
        child: StreamBuilder<QuerySnapshot>(
          key: ValueKey(_refreshKey),
          stream: FirebaseFirestore.instance
              .collection("states")
              .doc(widget.stateId)
              .collection("districts")
              .snapshots(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF0A84FF)),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: snap.data!.docs.length,
              itemBuilder: (context, index) {
                final d = snap.data!.docs[index];
                final name = d['name'];
                final districtId = d.id;

                return FutureBuilder<double>(
                  future: _computeDistrictCleanliness(
                    widget.stateId,
                    districtId,
                  ),
                  builder: (context, cleanSnap) {
                    final clean = cleanSnap.data ?? 0;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              PageRouteBuilder(
                                transitionDuration: const Duration(
                                  milliseconds: 500,
                                ),
                                pageBuilder: (_, __, ___) =>
                                    FirestoreBinsScreen(
                                      stateId: widget.stateId,
                                      districtId: districtId,
                                    ),
                                transitionsBuilder: (_, animation, __, child) =>
                                    FadeTransition(
                                      opacity: animation,
                                      child: child,
                                    ),
                              ),
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: _getGradient(clean),
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.location_city_rounded,
                                    color: Colors.white,
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        "${clean.toStringAsFixed(1)}% Clean",
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: _getColor(clean),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Color(0xFF636366),
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }

  List<Color> _getGradient(double clean) {
    if (clean >= 80) return [const Color(0xFF32D74B), const Color(0xFF30D158)];
    if (clean >= 50) return [const Color(0xFFFF9F0A), const Color(0xFFFF9500)];
    return [const Color(0xFFFF453A), const Color(0xFFFF3B30)];
  }

  Color _getColor(double clean) {
    if (clean >= 80) return const Color(0xFF32D74B);
    if (clean >= 50) return const Color(0xFFFF9F0A);
    return const Color(0xFFFF453A);
  }
}
