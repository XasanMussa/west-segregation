// import 'package:flutter/material.dart';
// import 'package:firebase_core/firebase_core.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_database/firebase_database.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Waste Segregation Dashboard',
//       theme: ThemeData(
//         colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
//         useMaterial3: true,
//       ),
//       home: const HomeScreen(),
//     );
//   }
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   DocumentReference? _logDocument;
//   final DatabaseReference _rtdbRef = FirebaseDatabase.instance.ref();

//   int _metalCount = 0;
//   int _dryCount = 0;
//   int _wetCount = 0;

//   late AnimationController _metalController;
//   late AnimationController _dryController;
//   late AnimationController _wetController;

//   double _metalLevel = 0.0;
//   double _dryLevel = 0.0;
//   double _wetLevel = 0.0;

//   final int _maxCapacity = 10;
//   bool _isLoading = true;

//   @override
//   void initState() {
//     super.initState();

//     _metalController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _dryController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );
//     _wetController = AnimationController(
//       vsync: this,
//       duration: const Duration(milliseconds: 800),
//     );

//     _initializeFirestore();
//   }

//   void _initializeFirestore() async {
//     try {
//       _logDocument = _firestore.collection('logs').doc('6GEWdLfRumCQ7gqv3JrH');
//       DocumentSnapshot snapshot = await _logDocument!.get();

//       if (snapshot.exists) {
//         setState(() {
//           _metalCount = snapshot['metalCount'] ?? 0;
//           _dryCount = snapshot['dryCount'] ?? 0;
//           _wetCount = snapshot['waterCount'] ?? 0;
//           _updateFillLevels();
//         });
//       }

//       // Firestore listener to keep counts in sync and animate on increments
//       _logDocument!.snapshots().listen((snapshot) {
//         if (snapshot.exists) {
//           setState(() {
//             final newMetal = snapshot['metalCount'] ?? 0;
//             final newDry = snapshot['dryCount'] ?? 0;
//             final newWet = snapshot['waterCount'] ?? 0;

//             // Animate only if Firestore count increased (to keep animation consistent)
//             if (newMetal > _metalCount) {
//               _metalController.forward(from: 0);
//             }
//             if (newDry > _dryCount) {
//               _dryController.forward(from: 0);
//             }
//             if (newWet > _wetCount) {
//               _wetController.forward(from: 0);
//             }

//             _metalCount = newMetal;
//             _dryCount = newDry;
//             _wetCount = newWet;
//             _updateFillLevels();
//           });
//         }
//       });

//       _setupRealtimeListeners();
//     } catch (e) {
//       print("Error initializing Firestore: $e");
//     } finally {
//       setState(() => _isLoading = false);
//     }
//   }

//   void _setupRealtimeListeners() {
//     _rtdbRef.child('detectionEvent').onValue.listen((event) {
//       final value = event.snapshot.value as String?;
//       if (value != null && value.isNotEmpty) {
//         _handleRealtimeDetection(value);
//         // Reset after handling
//         _rtdbRef.child('detectionEvent').set("");
//       }
//     });
//   }

//   void _handleRealtimeDetection(String type) {
//     // Update UI immediately & animate
//     setState(() {
//       switch (type) {
//         case 'metal':
//           _metalCount++;
//           _metalController.forward(from: 0);
//           break;
//         case 'dry':
//           _dryCount++;
//           _dryController.forward(from: 0);
//           break;
//         case 'wet':
//           _wetCount++;
//           _wetController.forward(from: 0);
//           break;
//         default:
//           print('Unknown detection type from RTDB: $type');
//           return;
//       }
//       _updateFillLevels();
//     });

//     // Update Firestore counts
//     _handleDetection(type);
//   }

//   void _updateFillLevels() {
//     _metalLevel = (_metalCount / _maxCapacity).clamp(0.0, 1.0);
//     _dryLevel = (_dryCount / _maxCapacity).clamp(0.0, 1.0);
//     _wetLevel = (_wetCount / _maxCapacity).clamp(0.0, 1.0);
//   }

//   void _handleDetection(String type) async {
//     if (_logDocument == null) return;

//     try {
//       Map<String, dynamic> updateData = {};

//       switch (type) {
//         case 'metal':
//           updateData['metalCount'] = FieldValue.increment(1);
//           break;
//         case 'dry':
//           updateData['dryCount'] = FieldValue.increment(1);
//           break;
//         case 'wet':
//           updateData['waterCount'] = FieldValue.increment(1);
//           break;
//         default:
//           throw Exception('Invalid detection type: $type');
//       }

//       await _logDocument!.update(updateData);
//     } catch (e) {
//       print("Error updating Firestore: $e");
//     }
//   }

//   Future<void> _resetCounts() async {
//     if (_logDocument == null) return;

//     try {
//       await _logDocument!.update({
//         'metalCount': 0,
//         'dryCount': 0,
//         'waterCount': 0,
//       });

//       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
//         content: Text('All counts have been reset to zero'),
//         backgroundColor: Colors.green,
//       ));
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(SnackBar(
//         content: Text('Reset failed: $e'),
//         backgroundColor: Colors.red,
//       ));
//     }
//   }

//   @override
//   void dispose() {
//     _metalController.dispose();
//     _dryController.dispose();
//     _wetController.dispose();
//     super.dispose();
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Waste Segregation Dashboard'),
//         centerTitle: true,
//         elevation: 0,
//         backgroundColor: Theme.of(context).colorScheme.primaryContainer,
//       ),
//       body: _isLoading
//           ? const Center(child: CircularProgressIndicator())
//           : Padding(
//               padding: const EdgeInsets.all(20.0),
//               child: Column(
//                 children: [
//                   _buildStatsSummary(),
//                   const SizedBox(height: 30),
//                   Expanded(
//                     child: Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//                       crossAxisAlignment: CrossAxisAlignment.end,
//                       children: [
//                         _buildBucket(
//                           context: context,
//                           label: 'Metal',
//                           fillLevel: _metalLevel,
//                           color: Colors.blueGrey,
//                           controller: _metalController,
//                           count: _metalCount,
//                         ),
//                         _buildBucket(
//                           context: context,
//                           label: 'Dry',
//                           fillLevel: _dryLevel,
//                           color: Colors.orange,
//                           controller: _dryController,
//                           count: _dryCount,
//                         ),
//                         _buildBucket(
//                           context: context,
//                           label: 'Wet',
//                           fillLevel: _wetLevel,
//                           color: Colors.lightBlue,
//                           controller: _wetController,
//                           count: _wetCount,
//                         ),
//                       ],
//                     ),
//                   ),
//                   Padding(
//                     padding: const EdgeInsets.symmetric(vertical: 30),
//                     child: SizedBox(
//                       width: double.infinity,
//                       height: 60,
//                       child: FilledButton.icon(
//                         onPressed: _resetCounts,
//                         icon: const Icon(Icons.restart_alt),
//                         label: const Text(
//                           'RESET ALL COUNTS',
//                           style: TextStyle(
//                               fontSize: 18, fontWeight: FontWeight.bold),
//                         ),
//                         style: FilledButton.styleFrom(
//                           backgroundColor: Colors.red,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(15),
//                           ),
//                         ),
//                       ),
//                     ),
//                   )
//                 ],
//               ),
//             ),
//     );
//   }

//   Widget _buildStatsSummary() {
//     return Card(
//       elevation: 4,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(20),
//       ),
//       child: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceAround,
//           children: [
//             _buildStatItem('Metal', _metalCount, Colors.blueGrey),
//             _buildStatItem('Dry', _dryCount, Colors.orange),
//             _buildStatItem('Wet', _wetCount, Colors.lightBlue),
//           ],
//         ),
//       ),
//     );
//   }

//   Widget _buildStatItem(String label, int count, Color color) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(10),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.2),
//             shape: BoxShape.circle,
//           ),
//           child: Text(
//             count.toString(),
//             style: TextStyle(
//               fontSize: 20,
//               fontWeight: FontWeight.bold,
//               color: color,
//             ),
//           ),
//         ),
//         const SizedBox(height: 8),
//         Text(
//           label,
//           style: const TextStyle(fontWeight: FontWeight.w500),
//         ),
//       ],
//     );
//   }

//   Widget _buildBucket({
//     required BuildContext context,
//     required String label,
//     required double fillLevel,
//     required Color color,
//     required AnimationController controller,
//     required int count,
//   }) {
//     final double bucketHeight = MediaQuery.of(context).size.height * 0.25;
//     final double bucketWidth = MediaQuery.of(context).size.width * 0.25;

//     return Column(
//       mainAxisSize: MainAxisSize.min,
//       children: [
//         Text(
//           '$count/$_maxCapacity',
//           style: const TextStyle(fontWeight: FontWeight.bold),
//         ),
//         const SizedBox(height: 10),
//         Stack(
//           alignment: Alignment.bottomCenter,
//           children: [
//             Container(
//               width: bucketWidth,
//               height: bucketHeight,
//               decoration: BoxDecoration(
//                 border: Border.all(color: Colors.grey.shade400, width: 3),
//                 borderRadius: const BorderRadius.vertical(
//                   top: Radius.circular(10),
//                   bottom: Radius.circular(4),
//                 ),
//               ),
//             ),
//             AnimatedBuilder(
//               animation: controller,
//               builder: (context, child) {
//                 return Container(
//                   width: bucketWidth - 6,
//                   height: (bucketHeight - 6) * fillLevel * controller.value,
//                   decoration: BoxDecoration(
//                     color: color.withOpacity(0.7),
//                     borderRadius: BorderRadius.vertical(
//                       bottom: const Radius.circular(2),
//                       top: Radius.circular(controller.isAnimating ? 20 : 2),
//                     ),
//                     boxShadow: [
//                       BoxShadow(
//                         color: color.withOpacity(0.4),
//                         blurRadius: 6,
//                         spreadRadius: 1,
//                       ),
//                     ],
//                   ),
//                 );
//               },
//             ),
//             Positioned(
//               top: 10,
//               child: Container(
//                 width: bucketWidth * 0.6,
//                 height: 15,
//                 decoration: BoxDecoration(
//                   border: Border.all(color: Colors.grey.shade500, width: 3),
//                   borderRadius: BorderRadius.circular(10),
//                 ),
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 10),
//         Text(
//           label,
//           style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//         ),
//       ],
//     );
//   }
// }
