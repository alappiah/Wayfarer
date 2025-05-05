import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../models/journal_entry.dart';
import '../services/local_auth_service.dart';

class JournalSecurityService {
  static final JournalSecurityService _instance = JournalSecurityService._internal();
  final LocalAuthService _authService = LocalAuthService();
  
  // Cache of authenticated entries to avoid repeated authentication
  // for the same entry during a session
  final Map<String, DateTime> _authenticatedEntries = {};
  
  // Singleton pattern
  factory JournalSecurityService() {
    return _instance;
  }
  
  JournalSecurityService._internal();
  
  /// Checks if the user can access a locked entry
  /// Returns true if the entry is unlocked or the user has authenticated
  Future<bool> canAccessEntry(JournalEntry entry, BuildContext context) async {
    // If entry is not locked, allow access
    if (!entry.isLocked) return true;
    
    // Check if this entry was recently authenticated (within the last 10 minutes)
    final lastAuth = _authenticatedEntries[entry.id];
    if (lastAuth != null) {
      final difference = DateTime.now().difference(lastAuth);
      if (difference.inMinutes < 10) {
        return true;
      }
    }
    
    // Authenticate user
    final bool authenticated = await _authService.authenticate(
      reason: 'Authenticate to access this locked journal entry',
    );
    
    if (authenticated) {
      // Store successful authentication in cache
      _authenticatedEntries[entry.id] = DateTime.now();
      return true;
    } else {
      // Show failure message if context is provided
      if (context != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed'))
        );
      }
      return false;
    }
  }
  
  /// Toggle the lock status of an entry
  Future<bool> toggleLock(JournalEntry entry, BuildContext context) async {
    bool proceed = !entry.isLocked;
    
    // If we're unlocking, verify identity
    if (entry.isLocked) {
      proceed = await _authService.authenticate(
        reason: 'Authenticate to unlock this journal entry',
      );
      
      if (!proceed) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Authentication failed'))
        );
        return false;
      }
    }
    
    if (proceed) {
      try {
        // Update in Firestore
        await FirebaseFirestore.instance
            .collection('journals')
            .doc(entry.id)
            .update({'isLocked': !entry.isLocked});
        
        // If unlocking, add to authenticated entries
        if (entry.isLocked) {
          _authenticatedEntries[entry.id] = DateTime.now();
        } else {
          // If locking, remove from authenticated entries
          _authenticatedEntries.remove(entry.id);
        }
        
        return true;
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating lock status: $e'),
            backgroundColor: Colors.red,
          ),
        );
        return false;
      }
    }
    
    return false;
  }
  
  /// Returns a query that filters locked entries
  /// Use this for all journal listing screens
  Query<Map<String, dynamic>> getJournalsQuery({bool includeLockedEntries = false}) {
    final query = FirebaseFirestore.instance.collection('journals');
    
    if (!includeLockedEntries) {
      // Only show unlocked entries
      return query.where('isLocked', isEqualTo: false);
    }
    
    return query;
  }
  
  /// Clears the authentication cache
  void clearAuthenticationCache() {
    _authenticatedEntries.clear();
  }
}