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
          clientId: '8754fac7-08cc-48f8-be35-1bcfe7da68b8',
          clientSecret: 'EdH2a7u1/a+rrQQDhH/rKLekvTC5yrEUuTapbpa9GyyvEk8BSefc4AAeB81Q9HgylEhfiSv/Md6xCModP4UFSg==',  // Epic uses public clients, so client secret is empty
          redirectUri: redirectUri ?? (kIsWeb ? 'http://localhost:58398/redirect.html' : 'medibound://'),
          scope: 'launch/patient patient/Patient.read patient/Medication.read patient/MedicationRequest.read patient/Condition.read fhirUser',
          fhirEndpoint: 'https://ssrx.ksnet.com/FhirProxy/api/fhir/r4/',
          tokenUrl: 'https://ssrx.ksnet.com/FhirProxy/oauth2/token',
          authUrl: 'https://ssrx.ksnet.com/FhirProxy/oauth2/authorize',
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
        'grant_type': 'authorization_code',
        
      },
      accessTokenHeaders: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$clientId:$clientSecret'))}',
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


      final tokenData = {
        'access_token': token.accessToken,
        'refresh_token': token.refreshToken,
        'expires_in': token.expiresIn,
        'expiration_date': token.expirationDate,
        'token_type': token.tokenType,
        'patient_id': token.respMap['patient'],
      };

      updateTokens(tokenData);
      
      return tokenData;
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

}

