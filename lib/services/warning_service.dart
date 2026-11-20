import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:palturo/models/account_warning.dart';

/// Reads and acknowledges the signed-in user's visible account warnings.
class WarningService {
  Future<List<AccountWarning>> fetchMyWarnings() async {
    final response = await Supabase.instance.client.rpc('get_my_warnings');
    if (response is! List) return const [];
    return response
        .whereType<Map>()
        .map((row) => AccountWarning.fromRow(Map<String, dynamic>.from(row)))
        .where((warning) => warning.id.isNotEmpty && warning.message.isNotEmpty)
        .toList(growable: false);
  }

  Future<bool> acknowledge(String warningId) async {
    if (warningId.isEmpty) return false;
    final response = await Supabase.instance.client.rpc(
      'acknowledge_warning',
      params: {'p_warning': warningId},
    );
    return response == true;
  }
}
