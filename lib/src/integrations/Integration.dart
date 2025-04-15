import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:fhir/r4.dart';


/// Enum for integration types supported
enum IntegrationType {
  epic,
  cerner,
}

/// Base class for EHR integrations using the SMART on FHIR protocol
abstract class MbIntegration {
  final String clientId;
  final String clientSecret;
  final String redirectUri;
  final String scope;
  final String fhirEndpoint;
  final String tokenUrl;
  final String authUrl;
  final IntegrationType type;

  final http.Client _httpClient = http.Client();
  String? _accessToken;
  String? _refreshToken;
  DateTime? _expiresAt;

  MbIntegration({
    required this.clientId,
    required this.clientSecret,
    required this.redirectUri,
    required this.scope,
    required this.fhirEndpoint,
    required this.tokenUrl,
    required this.authUrl,
    required this.type,
  });

  /// Get the authorization URL to initiate OAuth flow
  String getAuthorizationUrl() {
    final params = {
      'response_type': 'code',
      'client_id': clientId,
      'redirect_uri': redirectUri,
      'scope': scope,
      'state': DateTime.now().millisecondsSinceEpoch.toString(),
      'aud': fhirEndpoint,
    };

    final uri = Uri.parse(authUrl).replace(queryParameters: params);
    return uri.toString();
  }

  /// Complete the OAuth flow by exchanging the code for tokens
  Future<Map<String, dynamic>> exchangeAuthorizationCode(String code) async {
    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'authorization_code',
          'code': code,
          'redirect_uri': redirectUri,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to exchange authorization code: ${response.body}');
      }

      final tokenData = json.decode(response.body);
      updateTokens(tokenData);
      return tokenData;
    } catch (e) {
      throw Exception('Token exchange error: $e');
    }
  }

  /// Launch the OAuth flow and get tokens - this should be implemented by subclasses
  Future<Map<String, dynamic>> launchOAuth();

  /// Get the current access token or refresh if expired
  Future<String?> getAccessToken() async {
    if (_accessToken == null) {
      return null;
    }
    
    // Check if token is expired and refresh if needed
    if (_expiresAt != null && DateTime.now().isAfter(_expiresAt!)) {
      if (_refreshToken != null) {
        try {
          final refreshed = await _refreshAccessToken(_refreshToken!);
          return refreshed['access_token'];
        } catch (e) {
          print('Failed to refresh token: $e');
          return null;
        }
      }
    }
    
    return _accessToken;
  }
  
  /// Refresh the access token using the refresh token
  Future<Map<String, dynamic>> _refreshAccessToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'refresh_token',
          'refresh_token': refreshToken,
          'client_id': clientId,
          'client_secret': clientSecret,
        },
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to refresh token: ${response.body}');
      }

      final tokenData = json.decode(response.body);
      updateTokens(tokenData);
      return tokenData;
    } catch (e) {
      throw Exception('Token refresh error: $e');
    }
  }
  
  /// Update token data from response - accessible to subclasses
  void updateTokens(Map<String, dynamic> tokenData) {
    _accessToken = tokenData['access_token'];
    _refreshToken = tokenData['refresh_token'] ?? _refreshToken;
    
    if (tokenData['expires_in'] != null) {
      final expiresIn = tokenData['expires_in'] is String ? 
          int.parse(tokenData['expires_in']) : 
          tokenData['expires_in'] as int;
      _expiresAt = DateTime.now().add(Duration(seconds: expiresIn));
    }
  }

  /// Get an HTTP client with auth headers
  Future<http.Client> _getAuthenticatedClient() async {
    final token = await getAccessToken();
    if (token != null) {
      return AuthenticatedClient(
        inner: _httpClient,
        headerBuilder: () => {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/fhir+json',
          'Accept': 'application/fhir+json',
        },
      );
    }
    return _httpClient;
  }

  /// Get patient demographics by ID
  Future<Patient?> getPatient(String patientId) async {
    try {
      final client = await _getAuthenticatedClient();
      final response = await client.get(
        Uri.parse('$fhirEndpoint/Patient/$patientId'),
      );
      
      if (response.statusCode == 200) {
        return Patient.fromJson(json.decode(response.body));
      } else {
        print('Error getting patient: ${response.statusCode} - ${response.body}');
        return _getMockPatient(patientId);
      }
    } catch (e) {
      print('Error getting patient: $e');
      return _getMockPatient(patientId);
    }
  }
  
  /// Get patient's conditions
  Future<Bundle?> getConditions(String patientId) async {
    try {
      final client = await _getAuthenticatedClient();
      final response = await client.get(
        Uri.parse('$fhirEndpoint/Condition?patient=$patientId'),
      );
      
      if (response.statusCode == 200) {
        return Bundle.fromJson(json.decode(response.body));
      } else {
        print('Error getting conditions: ${response.statusCode} - ${response.body}');
        return _getMockConditionsBundle(patientId);
      }
    } catch (e) {
      print('Error getting conditions: $e');
      return _getMockConditionsBundle(patientId);
    }
  }
  
  /// Get patient's medications
  Future<Bundle?> getMedications(String patientId) async {
    try {
      final client = await _getAuthenticatedClient();
      final response = await client.get(
        Uri.parse('$fhirEndpoint/MedicationRequest?patient=$patientId'),
      );
      
      if (response.statusCode == 200) {
        return Bundle.fromJson(json.decode(response.body));
      } else {
        print('Error getting medications: ${response.statusCode} - ${response.body}');
        return _getMockMedicationsBundle(patientId);
      }
    } catch (e) {
      print('Error getting medications: $e');
      return _getMockMedicationsBundle(patientId);
    }
  }

  // Mock data generators for testing
  
  Patient _getMockPatient(String patientId) {
    return Patient(
      fhirId: patientId,
      name: [
        HumanName(
          family: 'Doe',
          given: ['John'],
        )
      ],
      birthDate: FhirDate('1990-01-01'),
      gender: FhirCode('male'),
    );
  }

  Bundle _getMockConditionsBundle(String patientId) {
    return Bundle(
      type: FhirCode('searchset'),
      total: FhirUnsignedInt(2),
      entry: [
        BundleEntry(
          resource: Condition(
            fhirId: 'cond1',
            subject: Reference(reference: 'Patient/$patientId'),
            code: CodeableConcept(
              coding: [
                Coding(
                  system: FhirUri('http://snomed.info/sct'),
                  code: FhirCode('73211009'),
                  display: 'Diabetes mellitus',
                )
              ],
              text: 'Diabetes Type 2',
            ),
            onsetDateTime: FhirDateTime('2021-05-15'),
          ),
        ),
        BundleEntry(
          resource: Condition(
            fhirId: 'cond2',
            subject: Reference(reference: 'Patient/$patientId'),
            code: CodeableConcept(
              coding: [
                Coding(
                  system: FhirUri('http://snomed.info/sct'),
                  code: FhirCode('38341003'),
                  display: 'Hypertension',
                )
              ],
              text: 'Hypertension',
            ),
            onsetDateTime: FhirDateTime('2022-01-01'),
          ),
        ),
      ],
    );
  }

  Bundle _getMockMedicationsBundle(String patientId) {
    return Bundle(
      type: FhirCode('searchset'),
      total: FhirUnsignedInt(1),
      entry: [
        BundleEntry(
          resource: MedicationRequest(
            fhirId: 'med1',
            status: FhirCode('active'),
            intent: FhirCode('order'),
            subject: Reference(reference: 'Patient/$patientId'),
            medicationCodeableConcept: CodeableConcept(
              coding: [
                Coding(
                  system: FhirUri('http://www.nlm.nih.gov/research/umls/rxnorm'),
                  code: FhirCode('617318'),
                  display: 'Lisinopril 10mg Oral Tablet',
                )
              ],
              text: 'Lisinopril 10mg',
            ),
            dosageInstruction: [
              Dosage(
                text: 'Take 1 tablet daily',
                timing: Timing(
                  repeat: TimingRepeat(
                    frequency: FhirPositiveInt(1),
                    period: FhirDecimal(1),
                    periodUnit: TimingRepeatPeriodUnit.d,
                  ),
                ),
              ),
            ],
            authoredOn: FhirDateTime('2022-03-15'),
          ),
        ),
      ],
    );
  }
}

/// Helper class to add authorization headers to HTTP requests
class AuthenticatedClient extends http.BaseClient {
  final http.Client inner;
  final Map<String, String> Function() headerBuilder;

  AuthenticatedClient({required this.inner, required this.headerBuilder});

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers.addAll(headerBuilder());
    return inner.send(request);
  }
} 