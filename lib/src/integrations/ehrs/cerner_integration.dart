import 'package:flutter/services.dart';
import '../Integration.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:oauth2_client/oauth2_client.dart';
import 'package:oauth2_client/oauth2_helper.dart';

class CernerIntegration extends MbIntegration {
  late OAuth2Helper _oauth2Helper;

  CernerIntegration({
    String? redirectUri,
  }) : super(
          clientId: 'f2281c3d-a1a3-47f8-8834-2ceece46c09a',
          clientSecret: 'cerner_secret',  // Cerner may use confidential clients
          redirectUri: redirectUri ?? 'medibound://',
          scope: 'patient/Patient.read patient/Medication.read patient/MedicationRequest.read patient/Condition.read offline_access',
          fhirEndpoint: 'https://fhir-open.cerner.com/r4/ec2458f2-1e24-41c8-b71b-0e701af7583d',
          tokenUrl: 'https://authorization.cerner.com/tenants/ec2458f2-1e24-41c8-b71b-0e701af7583d/protocols/oauth2/profiles/smart-v1/token',
          authUrl: 'https://authorization.cerner.com/tenants/ec2458f2-1e24-41c8-b71b-0e701af7583d/protocols/oauth2/profiles/smart-v1/personas/provider/authorize',
          type: IntegrationType.cerner,
        ) {
    final client = OAuth2Client(
      authorizeUrl: authUrl,
      tokenUrl: tokenUrl,
      redirectUri: redirectUri ?? 'medibound://',
      customUriScheme: 'medibound',
    );
    
    _oauth2Helper = OAuth2Helper(
      client,
      clientId: clientId,
      clientSecret: clientSecret,
      scopes: scope.split(' '),
      authCodeParams: {
        'aud': fhirEndpoint,
      },
    );
  }

  @override
  Future<Map<String, dynamic>> launchOAuth() async {
    try {
      final token = await _oauth2Helper.getToken();
      if (token == null) {
        throw Exception('Failed to obtain token');
      }
      
      final tokenData = {
        'access_token': token.accessToken,
        'refresh_token': token.refreshToken,
        'expires_in': token.expiresIn,
        'token_type': token.tokenType,
      };
      
      // Update the parent class token state
      updateTokens(tokenData);
      
      return tokenData;
    } catch (e) {
      // For demo/testing, return mock tokens if OAuth fails
      if (kDebugMode) {
        print('OAuth failed, using mock tokens: $e');
        final mockTokens = {
          'access_token': 'mock_cerner_access_token',
          'refresh_token': 'mock_cerner_refresh_token',
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