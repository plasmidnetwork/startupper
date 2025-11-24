import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'feed/feed_screen.dart';

// Allow test runs to bypass form validation when launched with:
// flutter run --dart-define=BYPASS_VALIDATION=true
const bool kBypassValidation =
    bool.fromEnvironment('BYPASS_VALIDATION', defaultValue: false);

// ============================================
// MAIN ENTRY POINT
// ============================================
// This is where our Flutter app starts running
void main() {
  runApp(const StartupperApp());
}

// ============================================
// ROOT APP WIDGET
// ============================================
// This is the root of our application.
// It sets up the MaterialApp with all our routes.
class StartupperApp extends StatelessWidget {
  const StartupperApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Startupper',
      theme: ThemeData(
        // Using Material 3 design system
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      // The app always starts at the auth screen
      initialRoute: '/auth',
      // Named routes map - connects route names to screen widgets
      routes: {
        '/auth': (context) => const AuthScreen(),
        '/onboarding/reason': (context) => const ReasonScreen(),
        '/onboarding/common': (context) => const CommonOnboardingScreen(),
        '/onboarding/founder': (context) => const FounderOnboardingScreen(),
        '/onboarding/investor': (context) => const InvestorOnboardingScreen(),
        '/onboarding/end_user': (context) => const EndUserOnboardingScreen(),
        '/feed': (context) => const FeedScreen(),
      },
    );
  }
}

// ============================================
// AUTH SCREEN
// ============================================
// This is the login/signup screen where users enter credentials
class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers manage the text in our TextFields
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  // Cleanup: Always dispose controllers to prevent memory leaks
  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Handle login button press
  void _handleLogin() {
    if (kBypassValidation || (_formKey.currentState?.validate() ?? false)) {
      // TODO: Add Supabase authentication logic here
      // For now, just navigate to role selection
      Navigator.pushReplacementNamed(context, '/onboarding/reason');
    }
  }

  // Handle signup button press
  void _handleSignup() {
    if (kBypassValidation || (_formKey.currentState?.validate() ?? false)) {
      // TODO: Add Supabase signup logic here
      // For now, just navigate to role selection
      Navigator.pushReplacementNamed(context, '/onboarding/reason');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Startupper'),
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Welcome text
                    const Text(
                      'Welcome to Startupper',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),
                    
                    // Email input field
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.email),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        final trimmed = value?.trim() ?? '';
                        if (trimmed.isEmpty) {
                          return 'Email is required';
                        }
                        final emailRegex =
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                        if (!emailRegex.hasMatch(trimmed)) {
                          return 'Enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    
                    // Password input field
                    TextFormField(
                      controller: _passwordController,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.lock),
                      ),
                      obscureText: true, // Hides password characters
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Use at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Login button
                    ElevatedButton(
                      onPressed: _handleLogin,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text(
                        'Login',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                    const SizedBox(height: 12),
                    
                    // Switch to signup button
                    TextButton(
                      onPressed: _handleSignup,
                      child: const Text('Don\'t have an account? Sign up'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================
// REASON SCREEN (Role Selection)
// ============================================
// Users choose their role: Founder, Investor, or End-user
class ReasonScreen extends StatefulWidget {
  const ReasonScreen({Key? key}) : super(key: key);

  @override
  State<ReasonScreen> createState() => _ReasonScreenState();
}

class _ReasonScreenState extends State<ReasonScreen> {
  // Track which role is selected (null means nothing selected yet)
  String? _selectedRole;

  // Handle continue button press
  void _handleContinue() {
    if (_selectedRole != null) {
      // Navigate to common onboarding and pass the selected role
      Navigator.pushNamed(
        context,
        '/onboarding/common',
        arguments: _selectedRole, // Pass role to next screen
      );
    }
  }

  // Build a selectable role card
  Widget _buildRoleCard(String role, IconData icon, String description) {
    final isSelected = _selectedRole == role;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        // Subtle gradient for depth
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Theme.of(context).colorScheme.primaryContainer,
                  Theme.of(context).colorScheme.primaryContainer.withOpacity(0.8),
                ],
              )
            : null,
        color: isSelected ? null : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        // Polished border and glow effect
        border: Border.all(
          color: isSelected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline.withOpacity(0.2),
          width: isSelected ? 2 : 1,
        ),
        // Soft shadow to lift the card
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? Theme.of(context).colorScheme.primary.withOpacity(0.3)
                : Colors.black.withOpacity(0.08),
            blurRadius: isSelected ? 12 : 8,
            offset: const Offset(0, 4),
            spreadRadius: isSelected ? 2 : 0,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedRole = role;
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 48,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurface,
                ),
                const SizedBox(height: 12),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Join Startupper'),
        // No back button - user came from login via pushReplacementNamed
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Main title
            const Text(
              'Why are you joining?',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            // Role cards
            _buildRoleCard(
              'Founder',
              Icons.rocket_launch,
              'Build and grow your startup',
            ),
            const SizedBox(height: 16),
            _buildRoleCard(
              'Investor',
              Icons.attach_money,
              'Discover and fund startups',
            ),
            const SizedBox(height: 16),
            _buildRoleCard(
              'End-user',
              Icons.people,
              'Join startups or test products',
            ),
            const SizedBox(height: 32),
            
            // Continue button (disabled if no role selected)
            ElevatedButton(
              onPressed: _selectedRole != null ? _handleContinue : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Continue',
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// COMMON ONBOARDING SCREEN
// ============================================
// Shared onboarding fields for all user types
class CommonOnboardingScreen extends StatefulWidget {
  const CommonOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<CommonOnboardingScreen> createState() => _CommonOnboardingScreenState();
}

class _CommonOnboardingScreenState extends State<CommonOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  // Controllers for text fields
  final _nameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _locationController = TextEditingController();
  
  // Track freelancing availability
  bool _availableForFreelancing = false;
  
  // Profile picture
  File? _profileImage;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _locationController.dispose();
    super.dispose();
  }
  
  // Pick profile picture from gallery or camera
  Future<void> _pickProfileImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      
      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      // Handle error - show snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking image: $e')),
        );
      }
    }
  }
  
  // Show options to pick from camera or gallery
  void _showImageSourceOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickProfileImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Handle back button
  void _handleBack() {
    Navigator.pop(context);
  }

  // Handle next button
  void _handleNext() {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    // Get the selected role from the route arguments
    final role = ModalRoute.of(context)!.settings.arguments as String;
    
    // TODO: Save common onboarding data to Supabase here
    // TODO: Upload profile picture to Supabase Storage and save URL to profile
    
    // Navigate to role-specific onboarding
    String nextRoute;
    switch (role) {
      case 'Founder':
        nextRoute = '/onboarding/founder';
        break;
      case 'Investor':
        nextRoute = '/onboarding/investor';
        break;
      case 'End-user':
        nextRoute = '/onboarding/end_user';
        break;
      default:
        nextRoute = '/feed';
    }
    
    Navigator.pushNamed(context, nextRoute);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 32),
              
              // Profile picture section
              Center(
                child: Column(
                  children: [
                    // Profile picture circle
                    GestureDetector(
                      onTap: _showImageSourceOptions,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primaryContainer,
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                          image: _profileImage != null
                              ? DecorationImage(
                                  image: FileImage(_profileImage!),
                                  fit: BoxFit.cover,
                                )
                              : null,
                        ),
                        child: _profileImage == null
                            ? Icon(
                                Icons.add_a_photo,
                                size: 40,
                                color: Theme.of(context).colorScheme.primary,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // "Add photo" text
                    TextButton.icon(
                      onPressed: _showImageSourceOptions,
                      icon: const Icon(Icons.camera_alt, size: 18),
                      label: Text(
                        _profileImage == null ? 'Add profile picture' : 'Change picture',
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              // Full name field
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Full name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Headline field
              TextFormField(
                controller: _headlineController,
                decoration: const InputDecoration(
                  labelText: 'Headline *',
                  hintText: 'e.g., Product Designer • Ex-Google',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.text_fields),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Headline is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Location field
              TextFormField(
                controller: _locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  hintText: 'e.g., San Francisco, CA',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Location is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Freelancing availability switch
              SwitchListTile(
                title: const Text('Available for freelancing?'),
                subtitle: const Text('Let startups know you\'re open to projects'),
                value: _availableForFreelancing,
                onChanged: (value) {
                  setState(() {
                    _availableForFreelancing = value;
                  });
                },
                contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              const SizedBox(height: 32),
              
              // Navigation buttons
              Row(
                children: [
                  // Back button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Next button
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleNext,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Next'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// FOUNDER ONBOARDING SCREEN
// ============================================
// Collect founder-specific information
class FounderOnboardingScreen extends StatefulWidget {
  const FounderOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<FounderOnboardingScreen> createState() =>
      _FounderOnboardingScreenState();
}

class _FounderOnboardingScreenState extends State<FounderOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _startupNameController = TextEditingController();
  final _pitchController = TextEditingController();
  
  // Product details controllers (optional section)
  final _websiteController = TextEditingController();
  final _videoController = TextEditingController();
  final _appStoreIdController = TextEditingController();
  final _playStoreIdController = TextEditingController();
  
  // Stage dropdown
  String _selectedStage = 'Idea';
  final List<String> _stages = ['Idea', 'Pre-seed', 'Seed', 'Series A+'];
  
  // Multi-select for what they're looking for
  final Map<String, bool> _lookingFor = {
    'Investors': false,
    'Co-founder': false,
    'First hires': false,
    'Freelancers': false,
    'Beta users': false,
    'Advisors': false,
  };
  
  // Track if product details section is expanded
  bool _isProductDetailsExpanded = false;

  @override
  void dispose() {
    _startupNameController.dispose();
    _pitchController.dispose();
    _websiteController.dispose();
    _videoController.dispose();
    _appStoreIdController.dispose();
    _playStoreIdController.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleFinish() {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    // TODO: Save founder-specific data to Supabase here
    // Navigate to feed screen (replace so user can't go back)
    Navigator.pushReplacementNamed(context, '/feed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Founder Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about your startup',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Startup name
              TextFormField(
                controller: _startupNameController,
                decoration: const InputDecoration(
                  labelText: 'Startup Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.business),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Startup name is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // One-liner pitch
              TextFormField(
                controller: _pitchController,
                decoration: const InputDecoration(
                  labelText: 'One-liner Pitch *',
                  hintText: 'Describe your startup in one sentence',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lightbulb),
                ),
                maxLines: 2,
                maxLength: 300, // Character limit with counter
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Pitch is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Stage dropdown
              DropdownButtonFormField<String>(
                value: _selectedStage,
                decoration: const InputDecoration(
                  labelText: 'Stage *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.trending_up),
                ),
                items: _stages.map((stage) {
                  return DropdownMenuItem(
                    value: stage,
                    child: Text(stage),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedStage = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select a stage';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // What are you looking for section
              const Text(
                'What are you looking for?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Multi-select chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lookingFor.keys.map((item) {
                  return FilterChip(
                    label: Text(item),
                    selected: _lookingFor[item]!,
                    onSelected: (selected) {
                      setState(() {
                        _lookingFor[item] = selected;
                      });
                    },
                    showCheckmark: false, // Remove checkmark
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              
              // Product details section (optional, expandable)
              ProductDetailsSection(
                isExpanded: _isProductDetailsExpanded,
                onToggle: () {
                  setState(() {
                    _isProductDetailsExpanded = !_isProductDetailsExpanded;
                  });
                },
                websiteController: _websiteController,
                videoController: _videoController,
                appStoreIdController: _appStoreIdController,
                playStoreIdController: _playStoreIdController,
              ),
              const SizedBox(height: 32),
              
              // Navigation buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleFinish,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// PRODUCT DETAILS SECTION (Question-based)
// ============================================
// Optional section for founders to add product links
// Uses a Yes/No question instead of dropdown
class ProductDetailsSection extends StatelessWidget {
  final bool isExpanded;
  final VoidCallback onToggle;
  final TextEditingController websiteController;
  final TextEditingController videoController;
  final TextEditingController appStoreIdController;
  final TextEditingController playStoreIdController;

  const ProductDetailsSection({
    Key? key,
    required this.isExpanded,
    required this.onToggle,
    required this.websiteController,
    required this.videoController,
    required this.appStoreIdController,
    required this.playStoreIdController,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Question text
        const Text(
          'Do you have a product ready?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        
        // Yes/No selection chips (matching "what are you looking for?" style)
        Wrap(
          spacing: 8,
          children: [
            // No option (on the left)
            FilterChip(
              label: const Text('No'),
              selected: !isExpanded,
              onSelected: (selected) {
                if (selected && isExpanded) {
                  onToggle();
                }
              },
              showCheckmark: false, // No checkmark
            ),
            // Yes option (on the right)
            FilterChip(
              label: const Text('Yes'),
              selected: isExpanded,
              onSelected: (selected) {
                if (selected && !isExpanded) {
                  onToggle();
                }
              },
              showCheckmark: false, // No checkmark
            ),
          ],
        ),
        
        // Animated expandable product fields
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: isExpanded
              ? Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Website field
                      TextField(
                        controller: websiteController,
                        decoration: const InputDecoration(
                          labelText: 'Website',
                          hintText: 'https://yourstartup.com',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.language),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      
                      // Demo video field
                      TextField(
                        controller: videoController,
                        decoration: const InputDecoration(
                          labelText: 'Demo video',
                          hintText: 'https://youtu.be/...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.play_circle_outline),
                        ),
                        keyboardType: TextInputType.url,
                      ),
                      const SizedBox(height: 16),
                      
                      // iOS App Store ID field
                      TextField(
                        controller: appStoreIdController,
                        decoration: const InputDecoration(
                          labelText: 'iOS App Store ID',
                          hintText: 'e.g., 1234567890',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.apple),
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 16),
                      
                      // Google Play Store package name field
                      TextField(
                        controller: playStoreIdController,
                        decoration: const InputDecoration(
                          labelText: 'Google Play package name',
                          hintText: 'e.g., com.myapp.mobile',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.android),
                        ),
                        keyboardType: TextInputType.text,
                      ),
                      
                      // TODO: Save product details to Supabase when founder finishes
                    ],
                  ),
                )
              : const SizedBox.shrink(), // Hidden when "No" is selected
        ),
      ],
    );
  }
}

// ============================================
// INVESTOR ONBOARDING SCREEN
// ============================================
// Collect investor-specific information
class InvestorOnboardingScreen extends StatefulWidget {
  const InvestorOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<InvestorOnboardingScreen> createState() =>
      _InvestorOnboardingScreenState();
}

class _InvestorOnboardingScreenState extends State<InvestorOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ticketSizeController = TextEditingController();
  
  // Investor type dropdown
  String _investorType = 'Angel';
  final List<String> _investorTypes = [
    'Angel',
    'VC',
    'Syndicate',
    'Accelerator',
    'Family office',
    'Corporate VC',
  ];
  
  // Multi-select for stages interested in
  final Map<String, bool> _stagesInterested = {
    'Idea': false,
    'Pre-seed': false,
    'Seed': false,
    'Series A+': false,
  };

  @override
  void dispose() {
    _ticketSizeController.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleFinish() {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    if (!kBypassValidation) {
      final selectedStage = _stagesInterested.values.any((v) => v);
      if (!selectedStage) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one stage')),
        );
        return;
      }
    }
    // TODO: Save investor-specific data to Supabase here
    Navigator.pushReplacementNamed(context, '/feed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Investor Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about your investment focus',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Investor type dropdown
              DropdownButtonFormField<String>(
                value: _investorType,
                decoration: const InputDecoration(
                  labelText: 'Investor Type *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
                items: _investorTypes.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(type),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _investorType = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select an investor type';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Ticket size
              TextFormField(
                controller: _ticketSizeController,
                decoration: const InputDecoration(
                  labelText: 'Typical Ticket Size *',
                  hintText: 'e.g., \$25K - \$100K',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.monetization_on),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ticket size is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // Stages interested in
              const Text(
                'Stages interested in',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Multi-select chips for stages
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _stagesInterested.keys.map((stage) {
                  return FilterChip(
                    label: Text(stage),
                    selected: _stagesInterested[stage]!,
                    onSelected: (selected) {
                      setState(() {
                        _stagesInterested[stage] = selected;
                      });
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 32),
              
              // Navigation buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleFinish,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// END-USER ONBOARDING SCREEN
// ============================================
// Collect end-user-specific information
class EndUserOnboardingScreen extends StatefulWidget {
  const EndUserOnboardingScreen({Key? key}) : super(key: key);

  @override
  State<EndUserOnboardingScreen> createState() =>
      _EndUserOnboardingScreenState();
}

class _EndUserOnboardingScreenState extends State<EndUserOnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  // Main role dropdown
  String _mainRole = 'Developer';
  final List<String> _roles = [
    'Developer',
    'Designer',
    'Product',
    'Growth',
    'Sales',
    'Ops',
    'Student',
    'Other',
  ];
  
  // Experience level dropdown
  String _experienceLevel = 'Mid';
  final List<String> _experienceLevels = [
    'Junior',
    'Mid',
    'Senior',
    'Lead',
    'Student',
  ];
  
  // Multi-select for what they're looking for
  final Map<String, bool> _lookingFor = {
    'Join a startup': false,
    'Freelance for startups': false,
    'Test products': false,
    'Maybe co-found later': false,
  };

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleFinish() {
    if (!(kBypassValidation || (_formKey.currentState?.validate() ?? false))) {
      return;
    }
    if (!kBypassValidation) {
      final hasInterest = _lookingFor.values.any((v) => v);
      if (!hasInterest) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select at least one interest')),
        );
        return;
      }
    }
    // TODO: Save end-user-specific data to Supabase here
    Navigator.pushReplacementNamed(context, '/feed');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Your Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tell us about your interests',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              
              // Main role dropdown
              DropdownButtonFormField<String>(
                value: _mainRole,
                decoration: const InputDecoration(
                  labelText: 'Main Role *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.work),
                ),
                items: _roles.map((role) {
                  return DropdownMenuItem(
                    value: role,
                    child: Text(role),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _mainRole = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select a role';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              
              // Experience level dropdown
              DropdownButtonFormField<String>(
                value: _experienceLevel,
                decoration: const InputDecoration(
                  labelText: 'Experience Level *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.bar_chart),
                ),
                items: _experienceLevels.map((level) {
                  return DropdownMenuItem(
                    value: level,
                    child: Text(level),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _experienceLevel = value;
                    });
                  }
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Select an experience level';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              
              // What are you looking for section
              const Text(
                'What are you looking for?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              
              // Checkboxes for interests
              ..._lookingFor.keys.map((interest) {
                return CheckboxListTile(
                  title: Text(interest),
                  value: _lookingFor[interest],
                  onChanged: (value) {
                    setState(() {
                      _lookingFor[interest] = value ?? false;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                );
              }).toList(),
              const SizedBox(height: 32),
              
              // Navigation buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _handleBack,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _handleFinish,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Finish'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
