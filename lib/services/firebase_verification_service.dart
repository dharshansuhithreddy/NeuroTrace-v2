// lib/services/firebase_verification_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirebaseVerificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Executes the Phase 2 verification lifecycle: Write -> Read -> Delete.
  Future<void> runFullVerification() async {
    final String testDocId = 'verification_${DateTime.now().millisecondsSinceEpoch}';
    final CollectionReference testCollection = _firestore.collection('neurotrace_verification');

    debugPrint('==================================================');
    debugPrint('🚀 NEUROTRACE V2: STARTING FIREBASE VERIFICATION');
    debugPrint('==================================================');

    // 1. WRITE TEST DOCUMENT
    try {
      debugPrint('⏳ 1. Attempting to write test document ($testDocId)...');
      await testCollection.doc(testDocId).set({
        'status': 'verified',
        'timestamp': FieldValue.serverTimestamp(),
        'platform': 'Android',
        'message': 'NeuroTrace V2 architecture verification successful.',
      });
      debugPrint('✅ 1. Write successful.');
    } catch (e) {
      debugPrint('❌ 1. Write FAILED. Error: $e');
      _diagnoseError(e);
      return; // Abort remaining steps if write fails
    }

    // 2. READ TEST DOCUMENT
    try {
      debugPrint('⏳ 2. Attempting to read back test document...');
      DocumentSnapshot docSnapshot = await testCollection.doc(testDocId).get();

      if (docSnapshot.exists) {
        Map<String, dynamic> data = docSnapshot.data() as Map<String, dynamic>;
        debugPrint('✅ 2. Read successful. Retrieved Data:');
        debugPrint('   - Status: ${data['status']}');
        debugPrint('   - Message: ${data['message']}');
      } else {
        debugPrint('❌ 2. Read FAILED: Document does not exist on server.');
      }
    } catch (e) {
      debugPrint('❌ 2. Read FAILED. Error: $e');
      return;
    }

    // 3. DELETE TEST DOCUMENT
    try {
      debugPrint('⏳ 3. Attempting to clean up (delete) test document...');
      await testCollection.doc(testDocId).delete();
      debugPrint('✅ 3. Delete successful.');
    } catch (e) {
      debugPrint('❌ 3. Delete FAILED. Error: $e');
      return;
    }

    debugPrint('==================================================');
    debugPrint('🎉 NEUROTRACE V2: FIREBASE CONNECTIVITY FULLY VERIFIED');
    debugPrint('==================================================');
  }

  /// Helper to diagnose common Firebase setup bottlenecks
  void _diagnoseError(Object error) {
    String errorStr = error.toString().toLowerCase();
    if (errorStr.contains('permission-denied') || errorStr.contains('permission denied')) {
      debugPrint('💡 DIAGNOSIS: Firestore Rules are blocking the write. Ensure your Cloud Firestore rules are set to "Test Mode" or allow public writes for the current date.');
    } else if (errorStr.contains('network-request-failed') || errorStr.contains('unavailable')) {
      debugPrint('💡 DIAGNOSIS: Network timeout or connection unavailable. Verify the device has internet access and targetSdk configurations permit traffic.');
    } else {
      debugPrint('💡 DIAGNOSIS: Possible mismatched google-services.json file or incomplete Firebase initialization in main.dart.');
    }
  }
}