import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart'; // Add this import for the gauge
import 'package:west_segregation/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await NotificationService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Waste Segregation Dashboard',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  DocumentReference? _logDocument;
  final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref();

  int _metalCount = 0;
  int _dryCount = 0;
  int _wetCount = 0;
  double _irValue = 0.0; // 0 to 100 for the gauge

  // Store previous RTDB values to detect 0->1 transitions
  int _prevMetalValue = 0;
  int _prevDryValue = 0;
  int _prevWetValue = 0;

  late AnimationController _metalController;
  late AnimationController _dryController;
  late AnimationController _wetController;

  double _metalLevel = 0.0;
  double _dryLevel = 0.0;
  double _wetLevel = 0.0;

  final int _maxCapacity = 10;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _metalController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _dryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _wetController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _initializeFirestore();
  }

  void _initializeFirestore() async {
    try {
      _logDocument = _firestore.collection('logs').doc('6GEWdLfRumCQ7gqv3JrH');
      DocumentSnapshot snapshot = await _logDocument!.get();

      if (snapshot.exists) {
        final metal = snapshot['metalCount'] ?? 0;
        final dry = snapshot['dryCount'] ?? 0;
        final wet = snapshot['waterCount'] ?? 0;
        setState(() {
          _metalCount = metal;
          _dryCount = dry;
          _wetCount = wet;
          _metalLevel = (metal / _maxCapacity).clamp(0.0, 1.0);
          _dryLevel = (dry / _maxCapacity).clamp(0.0, 1.0);
          _wetLevel = (wet / _maxCapacity).clamp(0.0, 1.0);
          _metalController.value = _metalLevel;
          _dryController.value = _dryLevel;
          _wetController.value = _wetLevel;
        });
      }

      // Firestore snapshot listener to keep UI in sync with backend changes
      _logDocument!.snapshots().listen((snapshot) async {
        if (snapshot.exists) {
          setState(() {
            final newMetal = snapshot['metalCount'] ?? 0;
            final newDry = snapshot['dryCount'] ?? 0;
            final newWet = snapshot['waterCount'] ?? 0;

            if (newMetal > _metalCount) {
              _metalController.forward(from: 0);
            }
            if (newDry > _dryCount) {
              _dryController.forward(from: 0);
            }
            if (newWet > _wetCount) {
              _wetController.forward(from: 0);
            }

            _metalCount = newMetal;
            _dryCount = newDry;
            _wetCount = newWet;
            _updateFillLevels();
            // Ensure fill levels are clamped to full if count >= maxCapacity
            if (_metalCount >= _maxCapacity) _metalLevel = 1.0;
            if (_dryCount >= _maxCapacity) _dryLevel = 1.0;
            if (_wetCount >= _maxCapacity) _wetLevel = 1.0;
          });

          // Notification logic for any change (including manual DB edits)
          if (_metalCount > _maxCapacity && _prevMetalValue <= _maxCapacity) {
            await NotificationService().showFullBucketNotification('Metal');
            await _storeNotificationInFirestore('metal');
          }
          if (_dryCount > _maxCapacity && _prevDryValue <= _maxCapacity) {
            await NotificationService().showFullBucketNotification('Dry');
            await _storeNotificationInFirestore('dry');
          }
          if (_wetCount > _maxCapacity && _prevWetValue <= _maxCapacity) {
            await NotificationService().showFullBucketNotification('Wet');
            await _storeNotificationInFirestore('wet');
          }
          _prevMetalValue = _metalCount;
          _prevDryValue = _dryCount;
          _prevWetValue = _wetCount;
        }
      });

      _setupRealtimeListeners();
    } catch (e) {
      print("Error initializing Firestore: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _setupRealtimeListeners() {
    // Listen to /metal key
    _rtdbRef.child('metalDetected').onValue.listen((event) {
      final value = _parseRTDBValue(event.snapshot.value);
      if (value != null) {
        _handleRealtimeValueChange(
          type: 'metal',
          newValue: value,
          prevValue: _prevMetalValue,
          onIncrement: () => _incrementMetalCount(),
        );
        _prevMetalValue = value;
      }
    });

    // Listen to /dry key
    _rtdbRef.child('dryDetected').onValue.listen((event) {
      final value = _parseRTDBValue(event.snapshot.value);
      if (value != null) {
        _handleRealtimeValueChange(
          type: 'dry',
          newValue: value,
          prevValue: _prevDryValue,
          onIncrement: () => _incrementDryCount(),
        );
        _prevDryValue = value;
      }
    });

    // Listen to /wet key
    _rtdbRef.child('wetDetected').onValue.listen((event) {
      final value = _parseRTDBValue(event.snapshot.value);
      if (value != null) {
        _handleRealtimeValueChange(
          type: 'wet',
          newValue: value,
          prevValue: _prevWetValue,
          onIncrement: () => _incrementWetCount(),
        );
        _prevWetValue = value;
      }
    });

    // Listen to /irDetected key for the gauge
    _rtdbRef.child('irDetected').onValue.listen((event) {
      final value = _parseRTDBValue(event.snapshot.value);
      if (value != null) {
        setState(() {
          _irValue = value == 1 ? 100.0 : 0.0;
        });
      }
    });
  }

  int? _parseRTDBValue(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value);
    }
    return null;
  }

  void _handleRealtimeValueChange({
    required String type,
    required int newValue,
    required int prevValue,
    required VoidCallback onIncrement,
  }) {
    if (prevValue == 0 && newValue == 1) {
      onIncrement();
    }
  }

  void _incrementMetalCount() async {
    if (_metalCount >= _maxCapacity) {
      await NotificationService().showFullBucketNotification('Metal');
      await _storeNotificationInFirestore('metal');
      return;
    }
    setState(() {
      _metalCount++;
      _metalController.forward(from: 0);
      _updateFillLevels();
    });
    _updateFirestoreCount('metalCount');
    if (_metalCount == _maxCapacity) {
      await NotificationService().showFullBucketNotification('Metal');
      await _storeNotificationInFirestore('metal');
    }
  }

  void _incrementDryCount() async {
    if (_dryCount >= _maxCapacity) {
      await NotificationService().showFullBucketNotification('Dry');
      await _storeNotificationInFirestore('dry');
      return;
    }
    setState(() {
      _dryCount++;
      _dryController.forward(from: 0);
      _updateFillLevels();
    });
    _updateFirestoreCount('dryCount');
    if (_dryCount == _maxCapacity) {
      await NotificationService().showFullBucketNotification('Dry');
      await _storeNotificationInFirestore('dry');
    }
  }

  void _incrementWetCount() async {
    if (_wetCount >= _maxCapacity) {
      await NotificationService().showFullBucketNotification('Wet');
      await _storeNotificationInFirestore('wet');
      return;
    }
    setState(() {
      _wetCount++;
      _wetController.forward(from: 0);
      _updateFillLevels();
    });
    _updateFirestoreCount('waterCount');
    if (_wetCount == _maxCapacity) {
      await NotificationService().showFullBucketNotification('Wet');
      await _storeNotificationInFirestore('wet');
    }
  }

  Future<void> _updateFirestoreCount(String field) async {
    if (_logDocument == null) return;
    try {
      await _logDocument!.update({
        field: FieldValue.increment(1),
      });
    } catch (e) {
      print("Error updating Firestore field $field: $e");
    }
  }

  Future<void> _storeNotificationInFirestore(String bucketType) async {
    try {
      await FirebaseFirestore.instance.collection('notifications').add({
        'bucketType': bucketType,
        'message':
            '${bucketType[0].toUpperCase()}${bucketType.substring(1)} bucket is full, please clear it.',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error storing notification: $e');
    }
  }

  void _updateFillLevels() {
    _metalLevel = (_metalCount / _maxCapacity).clamp(0.0, 1.0);
    _dryLevel = (_dryCount / _maxCapacity).clamp(0.0, 1.0);
    _wetLevel = (_wetCount / _maxCapacity).clamp(0.0, 1.0);
  }

  Future<void> _resetCounts() async {
    if (_logDocument == null) return;
    try {
      await _logDocument!.update({
        'metalCount': 0,
        'dryCount': 0,
        'waterCount': 0,
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('All counts have been reset to zero'),
        backgroundColor: Colors.green,
      ));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Reset failed: $e'),
        backgroundColor: Colors.red,
      ));
    }
  }

  @override
  void dispose() {
    _metalController.dispose();
    _dryController.dispose();
    _wetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Segregation Dashboard'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const NotificationsScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0), // Reduced padding
                child: Column(
                  children: [
                    // Gauge with reduced height
                    _buildIRGauge(),
                    const SizedBox(height: 10),
                    // Stats summary
                    _buildStatsSummary(),
                    const SizedBox(height: 15),
                    // Buckets with reduced height
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.30,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          _buildBucket(
                            context: context,
                            label: 'Metal',
                            fillLevel: _metalLevel,
                            color: Colors.blueGrey,
                            controller: _metalController,
                            count: _metalCount,
                          ),
                          _buildBucket(
                            context: context,
                            label: 'Dry',
                            fillLevel: _dryLevel,
                            color: Colors.orange,
                            controller: _dryController,
                            count: _dryCount,
                          ),
                          _buildBucket(
                            context: context,
                            label: 'Wet',
                            fillLevel: _wetLevel,
                            color: Colors.lightBlue,
                            controller: _wetController,
                            count: _wetCount,
                          ),
                        ],
                      ),
                    ),
                    // Reset button with reduced height
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50, // Reduced height
                        child: FilledButton.icon(
                          onPressed: _resetCounts,
                          icon: const Icon(Icons.restart_alt),
                          label: const Text(
                            'RESET ALL COUNTS',
                            style: TextStyle(
                                fontSize: 16, // Reduced font size
                                fontWeight: FontWeight.bold),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildIRGauge() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Column(
          children: [
            const Text(
              'IR Sensor Status',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 120,
              child: SfRadialGauge(
                axes: <RadialAxis>[
                  RadialAxis(
                    minimum: 0,
                    maximum: 100,
                    showLabels: false,
                    showTicks: false,
                    axisLineStyle: const AxisLineStyle(
                      thickness: 0.1,
                      cornerStyle: CornerStyle.bothCurve,
                    ),
                    ranges: <GaugeRange>[
                      GaugeRange(
                        startValue: 0,
                        endValue: _irValue,
                        color: _irValue > 0 ? Colors.green : Colors.grey,
                        startWidth: 20,
                        endWidth: 20,
                      ),
                    ],
                    pointers: <GaugePointer>[
                      NeedlePointer(
                        value: _irValue,
                        needleLength: 0.6,
                        needleStartWidth: 1,
                        needleEndWidth: 5,
                        knobStyle: const KnobStyle(
                          knobRadius: 0.08,
                          color: Colors.black,
                        ),
                      ),
                    ],
                    annotations: <GaugeAnnotation>[
                      GaugeAnnotation(
                        widget: Text(
                          '${_irValue.toInt()}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        angle: 90,
                        positionFactor: 0.5,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Text(
              _irValue > 0 ? 'Object Detected' : 'No Object Detected',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _irValue > 0 ? Colors.green : Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSummary() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Metal', _metalCount, Colors.blueGrey),
            _buildStatItem('Dry', _dryCount, Colors.orange),
            _buildStatItem('Wet', _wetCount, Colors.lightBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    String displayText = count > _maxCapacity ? 'Full' : count.toString();
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Text(
            displayText,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildBucket({
    required BuildContext context,
    required String label,
    required double fillLevel,
    required Color color,
    required AnimationController controller,
    required int count,
  }) {
    final double bucketHeight = MediaQuery.of(context).size.height * 0.20;
    final double bucketWidth = MediaQuery.of(context).size.width * 0.20;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${count > _maxCapacity ? _maxCapacity : count}/$_maxCapacity',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Stack(
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              width: bucketWidth,
              height: bucketHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade400, width: 3),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(10),
                  bottom: Radius.circular(4),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: controller,
              builder: (context, child) {
                return Container(
                  width: bucketWidth - 6,
                  height: (bucketHeight - 6) * fillLevel * controller.value,
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.7),
                    borderRadius: BorderRadius.vertical(
                      bottom: const Radius.circular(2),
                      top: Radius.circular(controller.isAnimating ? 20 : 2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                );
              },
            ),
            Positioned(
              top: 10,
              child: Container(
                width: bucketWidth * 0.6,
                height: 15,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade500, width: 3),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications'));
          }
          final notifications = snapshot.data!.docs;
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final message = doc['message'] ?? '';
              final timestamp = (doc['timestamp'] as Timestamp?)?.toDate();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: const Icon(Icons.notifications),
                  title: Text(message),
                  subtitle:
                      timestamp != null ? Text('${timestamp.toLocal()}') : null,
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () async {
                      await doc.reference.delete();
                    },
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
