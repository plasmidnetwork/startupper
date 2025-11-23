import 'package:flutter/material.dart';

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
    // TODO: Add Supabase authentication logic here
    // For now, just navigate to role selection
    Navigator.pushReplacementNamed(context, '/onboarding/reason');
  }

  // Handle signup button press
  void _handleSignup() {
    // TODO: Add Supabase signup logic here
    // For now, just navigate to role selection
    Navigator.pushReplacementNamed(context, '/onboarding/reason');
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
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  
                  // Password input field
                  TextField(
                    controller: _passwordController,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    obscureText: true, // Hides password characters
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
    
    return Card(
      elevation: isSelected ? 8 : 2,
      color: isSelected ? Theme.of(context).colorScheme.primaryContainer : null,
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedRole = role;
          });
        },
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
  // Controllers for text fields
  final _nameController = TextEditingController();
  final _headlineController = TextEditingController();
  final _locationController = TextEditingController();
  final _skillsController = TextEditingController();
  
  // Track freelancing availability
  bool _availableForFreelancing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _headlineController.dispose();
    _locationController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  // Handle back button
  void _handleBack() {
    Navigator.pop(context);
  }

  // Handle next button
  void _handleNext() {
    // Get the selected role from the route arguments
    final role = ModalRoute.of(context)!.settings.arguments as String;
    
    // TODO: Save common onboarding data to Supabase here
    
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
            const SizedBox(height: 24),
            
            // Full name field
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            const SizedBox(height: 16),
            
            // Headline field
            TextField(
              controller: _headlineController,
              decoration: const InputDecoration(
                labelText: 'Headline *',
                hintText: 'e.g., Product Designer • Ex-Google',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.text_fields),
              ),
            ),
            const SizedBox(height: 16),
            
            // Location field
            TextField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location *',
                hintText: 'e.g., San Francisco, CA',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
            ),
            const SizedBox(height: 16),
            
            // Skills field
            TextField(
              controller: _skillsController,
              decoration: const InputDecoration(
                labelText: 'Skills *',
                hintText: 'Enter comma-separated skills',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.stars),
              ),
              maxLines: 2,
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
  final _startupNameController = TextEditingController();
  final _pitchController = TextEditingController();
  
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

  @override
  void dispose() {
    _startupNameController.dispose();
    _pitchController.dispose();
    super.dispose();
  }

  void _handleBack() {
    Navigator.pop(context);
  }

  void _handleFinish() {
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
            TextField(
              controller: _startupNameController,
              decoration: const InputDecoration(
                labelText: 'Startup Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
            ),
            const SizedBox(height: 16),
            
            // One-liner pitch
            TextField(
              controller: _pitchController,
              decoration: const InputDecoration(
                labelText: 'One-liner Pitch *',
                hintText: 'Describe your startup in one sentence',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lightbulb),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            
            // Stage dropdown
            DropdownButtonFormField<String>(
              initialValue: _selectedStage,
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
              initialValue: _investorType,
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
            ),
            const SizedBox(height: 16),
            
            // Ticket size
            TextField(
              controller: _ticketSizeController,
              decoration: const InputDecoration(
                labelText: 'Typical Ticket Size *',
                hintText: 'e.g., \$25K - \$100K',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.monetization_on),
              ),
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
              initialValue: _mainRole,
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
            ),
            const SizedBox(height: 16),
            
            // Experience level dropdown
            DropdownButtonFormField<String>(
              initialValue: _experienceLevel,
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
    );
  }
}

// ============================================
// FEED SCREEN
// ============================================
// Main feed screen after onboarding is complete
class FeedScreen extends StatelessWidget {
  const FeedScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feed'),
        // Remove back button since we used pushReplacementNamed
        automaticallyImplyLeading: false,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.celebration,
              size: 64,
              color: Colors.blue,
            ),
            SizedBox(height: 24),
            Text(
              'Welcome to Startupper feed!',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your journey begins here',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

