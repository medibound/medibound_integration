import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:medibound_integration/src/integrations/integration_registry.dart';
import 'package:fhir/r4.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EHR Integration Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const EHRIntegrationPage(),
    );
  }
}

class EHRIntegrationPage extends StatefulWidget {
  const EHRIntegrationPage({super.key});

  @override
  State<EHRIntegrationPage> createState() => _EHRIntegrationPageState();
}

class _EHRIntegrationPageState extends State<EHRIntegrationPage> {
  final Map<String, bool> _connectionStatus = {};
  final Map<String, bool> _isLoading = {};
  String? _activeIntegrationType;
  late final IntegrationRegistry _registry;
  String? _currentPatientId;
  Patient? _currentPatient;
  Bundle? _currentMedications;

  @override
  void initState() {
    super.initState();
    // Initialize registry with appropriate callback URL based on platform
    _registry = IntegrationRegistry(
      defaultCallbackUrl: kIsWeb 
        ? 'http://localhost:58398/redirect.html'
        : 'medibound://'
    );
    
    // Initialize status for all available integrations
    for (final info in _registry.getAvailableIntegrations()) {
      _connectionStatus[info.type] = false;
      _isLoading[info.type] = false;
    }
  }

  Future<void> _connectToEHR(String type) async {
    setState(() {
      _isLoading[type] = true;
      _activeIntegrationType = type;
    });

    try {
      final integration = _registry.getIntegrationByType(type);
      if (integration == null) {
        throw Exception('Integration not found for type: $type');
      }
      
      // Launch the OAuth flow
      final tokens = await integration.launchOAuth();
      
      print('=== OAuth Response for $type ===');
      print('Access Token: ${tokens['access_token']}');
      print('Refresh Token: ${tokens['refresh_token']}');
      print('Expires In: ${tokens['expires_in']}');
      print('Token Type: ${tokens['token_type']}');
      print('============================');

      setState(() {
        _connectionStatus[type] = true;
      });
      
      // In a real app, you would get the patient ID from the token response
      // or from a separate patient selection screen
      _currentPatientId = "example-patient-id";
      
      // After successful connection, fetch patient data
      await _fetchPatientData(type);
    } catch (e) {
      print('Failed to connect to $type: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Connection failed: $e')),
      );
      setState(() {
        _activeIntegrationType = null;
      });
    } finally {
      setState(() {
        _isLoading[type] = false;
      });
    }
  }
  
  Future<void> _fetchPatientData(String type) async {
    if (_currentPatientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No patient ID available')),
      );
      return;
    }
    
    setState(() {
      _isLoading[type] = true;
    });
    
    try {
      final integration = _registry.getIntegrationByType(type);
      if (integration == null) {
        throw Exception('Integration not found for type: $type');
      }
      
      // Fetch patient demographics
      _currentPatient = await integration.getPatient(_currentPatientId!);
      
      // Fetch medications - the focus of this demo
      _currentMedications = await integration.getMedications(_currentPatientId!);
      
      setState(() {});
    } catch (e) {
      print('Failed to fetch patient data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to fetch patient data: $e')),
      );
    } finally {
      setState(() {
        _isLoading[type] = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final integrations = _registry.getAvailableIntegrations();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EHR Integration Demo'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // Top section: EHR connection options
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              'Connect to your Electronic Health Record',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 1,
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: integrations.length,
              itemBuilder: (context, index) {
                final info = integrations[index];
                final isConnected = _connectionStatus[info.type] ?? false;
                final isLoading = _isLoading[info.type] ?? false;
                final isActive = _activeIntegrationType == info.type;
  
                return Card(
                  elevation: 4,
                  color: isActive ? Colors.blue.shade50 : null,
                  child: InkWell(
                    onTap: isLoading ? null : () => _connectToEHR(info.type),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _getIconForType(info.type),
                            size: 48,
                            color: isConnected ? Colors.green : Colors.grey,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            info.name,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            info.description,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          if (isLoading)
                            const CircularProgressIndicator()
                          else if (isConnected)
                            ElevatedButton(
                              onPressed: () => _fetchPatientData(info.type),
                              child: const Text('Refresh Data'),
                            )
                          else
                            const Chip(
                              label: Text('Connect'),
                              backgroundColor: Colors.blue,
                              labelStyle: TextStyle(color: Colors.white),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Bottom section: Patient data display with focus on medications
          if (_currentPatient != null)
            Expanded(
              flex: 2,
              child: Container(
                color: Colors.grey.shade100,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.blue.shade100,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Patient Information',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Name: ${_currentPatient?.name?.first?.given?.join(' ')} ${_currentPatient?.name?.first?.family}',
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                          Text(
                            'DOB: ${_currentPatient?.birthDate}',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Current Medications',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Expanded(
                      child: _currentMedications?.entry != null && 
                             _currentMedications!.entry!.isNotEmpty
                        ? ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            itemCount: _currentMedications!.entry!.length,
                            itemBuilder: (context, index) {
                              final entry = _currentMedications!.entry![index];
                              final medication = entry.resource as MedicationRequest?;
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        medication?.medicationCodeableConcept?.text ?? 
                                          medication?.medicationCodeableConcept?.coding?.first.display ?? 
                                          'Unknown Medication',
                                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      if (medication?.dosageInstruction?.isNotEmpty == true)
                                        Text(
                                          'Dosage: ${medication!.dosageInstruction!.first.text ?? ""}',
                                          style: Theme.of(context).textTheme.bodyMedium,
                                        ),
                                      if (medication?.authoredOn != null)
                                        Text(
                                          'Prescribed: ${medication!.authoredOn}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      if (medication?.status != null)
                                        Text(
                                          'Status: ${medication!.status?.value ?? ""}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          )
                        : const Center(
                            child: Text('No medications found'),
                          ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Helper to get an icon for each integration type
  IconData _getIconForType(String type) {
    switch (type.toLowerCase()) {
      case 'epic':
        return Icons.local_hospital;
      case 'cerner':
        return Icons.health_and_safety;
      default:
        return Icons.medical_services;
    }
  }
} 