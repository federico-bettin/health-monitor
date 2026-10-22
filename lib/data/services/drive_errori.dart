import 'package:flutter/foundation.dart';

/// Messaggio comprensibile per un errore di Google Drive.
/// Il testo tecnico completo resta nel log (debugPrint), non nell'interfaccia.
String messaggioErroreDrive(Object e) {
  final t = e.toString();
  debugPrint('Errore Drive: $t');
  final minuscolo = t.toLowerCase();

  bool ha(List<String> parole) => parole.any(minuscolo.contains);

  // Niente rete (modalità aereo, Wi-Fi senza internet, DNS...)
  if (ha([
    'failed host lookup',
    'socketexception',
    'network is unreachable',
    'connection refused',
    'connection reset',
    'connection closed',
    'connection timed out',
    'timeoutexception',
    'handshakeexception',
  ])) {
    return 'Nessuna connessione a internet. Riproverò appena torna la rete.';
  }

  // Spazio dell'account esaurito (prima di 403 generico)
  if (ha(['storagequotaexceeded', 'storage quota'])) {
    return 'Lo spazio su Google Drive è esaurito.';
  }

  // Troppe richieste o server in difficoltà (prima di 403 generico)
  if (ha(['ratelimit', 'rate limit', 'quota exceeded'])) {
    return 'Google Drive è sovraccarico al momento. Riproverò più tardi.';
  }

  // Accesso scaduto o negato
  if (ha([
    '401',
    '403',
    'invalid_token',
    'invalid credentials',
    'unauthenticated',
    'sign_in',
    'permission',
  ])) {
    return 'Accesso a Google scaduto o negato: tocca "Accedi e sincronizza".';
  }

  // Server di Google in difficoltà
  if (ha(['500', '502', '503', '504', 'backenderror'])) {
    return 'Google Drive non risponde al momento. Riproverò più tardi.';
  }

  return 'Sincronizzazione non riuscita. Riproverò più tardi.';
}
