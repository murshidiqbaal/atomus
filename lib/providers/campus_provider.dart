import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/campus_model.dart';
import '../repositories/campus_repository.dart';
import '../services/campus_geofence_service.dart';

class CampusProvider with ChangeNotifier {
  final CampusRepository _campusRepo;
  final CampusGeofenceService _geofenceService;

  List<Campus> _assignedCampuses = [];
  Campus? _selectedCampus; // Manually selected/switched campus
  Campus? _workingCampus;  // Automatically matched campus from geofence

  List<Campus> get assignedCampuses => _assignedCampuses;
  Campus? get selectedCampus => _selectedCampus;
  Campus? get workingCampus => _workingCampus;

  CampusProvider({
    required CampusRepository campusRepository,
    required CampusGeofenceService geofenceService,
  }) : _campusRepo = campusRepository,
       _geofenceService = geofenceService {
    _loadCachedCampuses();
  }

  // Load from cache (SharedPreferences)
  Future<void> _loadCachedCampuses() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final workingCampusJson = prefs.getString('working_campus');
      if (workingCampusJson != null) {
        _workingCampus = Campus.fromMap(jsonDecode(workingCampusJson) as Map<String, dynamic>);
      }

      final selectedCampusJson = prefs.getString('selected_campus');
      if (selectedCampusJson != null) {
        _selectedCampus = Campus.fromMap(jsonDecode(selectedCampusJson) as Map<String, dynamic>);
      }
      
      notifyListeners();
    } catch (_) {}
  }

  // Load assigned campuses from DB
  Future<void> loadAssignedCampuses(List<String> campusIds) async {
    if (campusIds.isEmpty) {
      _assignedCampuses = [];
      notifyListeners();
      return;
    }
    
    try {
      _assignedCampuses = await _campusRepo.fetchCampusesByIds(campusIds);
      
      // If selectedCampus is not in assignedCampuses, reset it
      if (_selectedCampus != null && !_assignedCampuses.any((c) => c.id == _selectedCampus!.id)) {
        _selectedCampus = null;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('selected_campus');
      }

      notifyListeners();
    } catch (e) {
      print('CampusProvider: Error loading assigned campuses: $e');
    }
  }

  // Detect and set working campus based on geofence
  Future<Campus?> detectWorkingCampus() async {
    try {
      final matched = await _geofenceService.detectCurrentCampus();
      if (matched != null) {
        _workingCampus = matched;
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('working_campus', jsonEncode(matched.toMap()));
        
        // Also default selectedCampus to working campus if not set
        if (_selectedCampus == null) {
          _selectedCampus = matched;
          await prefs.setString('selected_campus', jsonEncode(matched.toMap()));
        }
        
        notifyListeners();
      }
      return matched;
    } catch (e) {
      print('CampusProvider: Error detecting working campus: $e');
      rethrow;
    }
  }

  // Manually select/switch campus
  Future<void> selectCampus(Campus campus) async {
    // Verify Selected Campus belongs to assignedCampuses. Otherwise reject.
    final exists = _assignedCampuses.any((c) => c.id == campus.id);
    if (!exists) {
      throw Exception('Selected campus is not in assigned campuses.');
    }

    _selectedCampus = campus;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_campus', jsonEncode(campus.toMap()));
    
    notifyListeners();
  }

  // Clean state (e.g. on logout)
  Future<void> clear() async {
    _assignedCampuses = [];
    _selectedCampus = null;
    _workingCampus = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('working_campus');
    await prefs.remove('selected_campus');
    notifyListeners();
  }
}
