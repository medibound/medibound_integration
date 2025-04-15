import 'package:flutter/services.dart';
import '../Integration.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class EpicIntegration extends MbIntegration {
  late OAuth2Helper _oauth2Helper;

  EpicIntegration({
    String? redirectUri,
  }) : super(
          clientId: 'e403f2cb-eb7d-4a8b-b6e3-5e408371766f',
          clientSecret: '',  // Epic uses public clients, so client secret is empty
          redirectUri: redirectUri ?? (kIsWeb ? 'http://localhost:58398/redirect.html' : 'medibound://'),
          scope: 'launch/patient patient/Patient.read patient/Medication.read patient/MedicationRequest.read patient/Condition.read fhirUser',
          fhirEndpoint: 'https://fhir.epic.com/interconnect-fhir-oauth/api/fhir/r4',
          tokenUrl: 'https://fhir.epic.com/interconnect-fhir-oauth/oauth2/token',
          authUrl: 'https://fhir.epic.com/interconnect-fhir-oauth/oauth2/authorize',
          type: IntegrationType.epic,
        ) {
    
    // Choose the correct OAuth client based on platform
    OAuth2Client client;

      // Use app redirect for mobile
      client = OAuth2Client(
        authorizeUrl: authUrl,
        tokenUrl: tokenUrl,
        redirectUri: redirectUri ?? 'medibound://',
        customUriScheme: 'medibound',
      );
    
    
    _oauth2Helper = OAuth2Helper(
      enablePKCE: false,
      enableState: false,
      client,
      clientId: clientId,
      scopes: scope.split(' '),
      authCodeParams: {
        'response_type': 'code',
        'aud': fhirEndpoint,
      },
      accessTokenParams: {
        'client_id': clientId,
      }
    );
  }

  @override
  Future<Map<String, dynamic>> launchOAuth() async {
    try {
      final token = await _oauth2Helper.getToken();
      if (token == null) {
        throw Exception('Failed to obtain token');
      }
      
      // Update internal token state
      updateTokens({
        'access_token': token.accessToken,
        'refresh_token': token.refreshToken,
        'expires_in': token.expiresIn,
        'token_type': token.tokenType,
      });
      
      return {
        'access_token': token.accessToken,
        'refresh_token': token.refreshToken,
        'expires_in': token.expiresIn,
        'token_type': token.tokenType,
      };
    } catch (e) {
      print('OAuth error: $e');
      
      // For demo/testing, return mock tokens if OAuth fails
      if (kDebugMode) {
        print('Using mock tokens after OAuth failure');
        final mockTokens = {
          'access_token': 'mock_access_token',
          'refresh_token': 'mock_refresh_token',
          'expires_in': 3600,
          'token_type': 'Bearer',
          'scope': scope,
        };
        updateTokens(mockTokens);
        return mockTokens;
      }
      throw Exception('OAuth failed: $e');
    }
  }
  
  @override
  Future<String?> getAccessToken() async {
    try {
      final token = await _oauth2Helper.getToken();
      return token?.accessToken;
    } catch (e) {
      // Fall back to stored token or handle the error
      print('Error getting access token from OAuth2Helper: $e');
      return super.getAccessToken();
    }
  }
}

