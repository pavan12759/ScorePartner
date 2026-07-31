import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';
import '../../../data/models/user_model.dart';
import '../main/main_navigation.dart';

class UserOnboardingScreen extends StatefulWidget {
  const UserOnboardingScreen({super.key});

  @override
  State<UserOnboardingScreen> createState() => _UserOnboardingScreenState();
}

class _UserOnboardingScreenState extends State<UserOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _locationController = TextEditingController();
  final _instagramController = TextEditingController();

  String _selectedRole = 'Batsman';
  String _selectedGender = 'Male';
  String _selectedBattingStyle = 'Right-hand';
  String _selectedBowlingStyle = 'Medium';
  DateTime? _selectedDate;

  final List<String> _genders = ['Male', 'Female', 'Other'];

  final List<String> _roles = [
    'Batsman',
    'Bowler',
    'All-rounder',
    'Wicket Keeper',
  ];
  final List<String> _battingStyles = ['Right-hand', 'Left-hand'];
  final List<String> _bowlingStyles = ['Fast', 'Medium', 'Spin', 'None'];

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _locationController.dispose();
    _instagramController.dispose();
    super.dispose();
  }

  void _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final currentUser = authProvider.user; // Firebase User

      if (currentUser == null) return;

      try {
        // Get current user model and update it
        UserModel? currentUserModel = authProvider.user;

        if (currentUserModel != null) {
          UserModel updatedUser = currentUserModel.copyWith(
            name: _nameController.text.trim(),
            role: _selectedRole.toLowerCase(),
            gender: _selectedGender,
            dob: _selectedDate,
            battingStyle: _selectedBattingStyle.toLowerCase(),
            bowlingStyle: _selectedBowlingStyle.toLowerCase(),
            age: _calculateAge(_selectedDate),
            location: _locationController.text.trim(),
            instagramUrl: _instagramController.text.trim(),
            isVerified: true,
            isProfileComplete: true,
          );

          await authProvider.updateUserProfile(updatedUser);
        }

        if (!mounted) return;

        // Navigate directly to main app, clearing all previous screens
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigation()),
          (route) => false,
        );
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to ScorePartner! 🏏'),
            backgroundColor: Color(0xFFFF6B35),
          ),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save profile: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.0.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100.w,
                      height: 100.h,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.primaryOrange,
                          width: 2.w,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: 60.sp,
                        color: Colors.grey[400],
                      ),
                    ),
                    Positioned(
                      bottom: 0.h,
                      right: 0.w,
                      child: Container(
                        padding: EdgeInsets.all(4.w),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryOrange,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.white,
                          size: 20.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 32.h),

              Text(
                'Basic Details',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) =>
                    value!.isEmpty ? 'Please enter your name' : null,
              ),
              SizedBox(height: 16.h),

              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: const InputDecoration(
                  labelText: 'Gender',
                  prefixIcon: Icon(Icons.people_outline),
                ),
                items: _genders
                    .map(
                      (gender) =>
                          DropdownMenuItem(value: gender, child: Text(gender)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedGender = val!),
              ),
              SizedBox(height: 16.h),

              Row(
                children: [
                 Expanded(
                    child: InkWell(
                      onTap: () async {
                        final DateTime? picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime(2000),
                          firstDate: DateTime(1950),
                          lastDate: DateTime.now(),
                        );
                        if (picked != null && picked != _selectedDate) {
                          setState(() {
                            _selectedDate = picked;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date of Birth',
                          prefixIcon: Icon(Icons.calendar_today),
                        ),
                        child: Text(
                          _selectedDate == null
                              ? 'Select Date'
                              : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location / City',
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (value) => value!.isEmpty ? 'Required' : null,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _instagramController,
                decoration: const InputDecoration(
                  labelText: 'Instagram ID (Optional)',
                  prefixIcon: Icon(Icons.camera_alt),
                  hintText: '@your_username',
                ),
              ),

              SizedBox(height: 32.h),
              Text(
                'Cricket Profile',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 16.h),

              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  labelText: 'Playing Role',
                  prefixIcon: Icon(Icons.sports_cricket),
                ),
                items: _roles
                    .map(
                      (role) =>
                          DropdownMenuItem(value: role, child: Text(role)),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              SizedBox(height: 16.h),

              DropdownButtonFormField<String>(
                initialValue: _selectedBattingStyle,
                decoration: const InputDecoration(
                  labelText: 'Batting Style',
                  prefixIcon: Icon(Icons.sports_baseball),
                ), // energetic icon
                items: _battingStyles
                    .map(
                      (style) =>
                          DropdownMenuItem(value: style, child: Text(style)),
                    )
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedBattingStyle = val!),
              ),
              SizedBox(height: 16.h),

              DropdownButtonFormField<String>(
                initialValue: _selectedBowlingStyle,
                decoration: const InputDecoration(
                  labelText: 'Bowling Style',
                  prefixIcon: Icon(Icons.sports_handball),
                ), // close enough
                items: _bowlingStyles
                    .map(
                      (style) =>
                          DropdownMenuItem(value: style, child: Text(style)),
                    )
                    .toList(),
                onChanged: (val) =>
                    setState(() => _selectedBowlingStyle = val!),
              ),

              SizedBox(height: 48.h),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saveProfile,
                  child: Text(
                    'Save Profile & Continue',
                    style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  int _calculateAge(DateTime? dob) {
    if (dob == null) return 18;
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month || (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }
}
