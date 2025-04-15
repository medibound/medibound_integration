import 'Integration.dart';
import 'ehrs/epic_integration.dart';
import 'ehrs/cerner_integration.dart';
import 'package:fhir/r4.dart';

class IntegrationInfo {
  final String name;
  final String description;
  final String type;
  final MbIntegration integration;

  const IntegrationInfo({
    required this.name,
    required this.description,
    required this.type,
    required this.integration,
  });
}

class IntegrationRegistry {
  final List<IntegrationInfo> _integrations = [];
  final String? defaultCallbackUrl;

  IntegrationRegistry({this.defaultCallbackUrl}) {
    // Register Epic integration
    _integrations.add(IntegrationInfo(
      name: 'Epic',
      description: 'Epic Systems EHR Integration',
      type: 'epic',
      integration: EpicIntegration(
        redirectUri: defaultCallbackUrl,
      ),
    ));

    // Register Cerner integration
    _integrations.add(IntegrationInfo(
      name: 'Cerner',
      description: 'Cerner EHR Integration',
      type: 'cerner',
      integration: CernerIntegration(
        redirectUri: defaultCallbackUrl,
      ),
    ));
  }

  List<IntegrationInfo> getAvailableIntegrations() => List.unmodifiable(_integrations);

  MbIntegration? getIntegrationByType(String type) {
    try {
      return _integrations
          .firstWhere(
            (info) => info.type.toLowerCase() == type.toLowerCase(),
          )
          .integration;
    } catch (e) {
      throw Exception('Integration not found: $type');
    }
  }

  Map<String, Map<String, dynamic>> getIntegrationsMetadata() {
    return Map.fromEntries(
      _integrations.map(
        (info) => MapEntry(
          info.type,
          {
            'name': info.name,
            'description': info.description,
            'type': info.type,
          },
        ),
      ),
    );
  }
} 