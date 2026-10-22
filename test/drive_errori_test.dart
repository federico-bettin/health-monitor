import 'package:flutter_test/flutter_test.dart';
import 'package:salute_bettin/data/services/drive_errori.dart';

void main() {
  test('niente rete: messaggio chiaro, senza testo tecnico', () {
    final m = messaggioErroreDrive(
        "ClientException with SocketException: Failed host lookup: 'www.googleapis.com' "
        '(OS Error: No address associated with hostname, errno = 7), '
        'uri=https://www.googleapis.com/drive/v3/files?q=name%3D%27HealthMonitor%27');
    expect(m, 'Nessuna connessione a internet. Riproverò appena torna la rete.');
    expect(m.contains('googleapis'), isFalse);
  });

  test('timeout e connessione interrotta contano come rete assente', () {
    expect(messaggioErroreDrive('TimeoutException after 0:00:30'),
        contains('connessione'));
    expect(messaggioErroreDrive('Connection reset by peer'),
        contains('connessione'));
  });

  test('accesso scaduto', () {
    expect(
        messaggioErroreDrive(
            'DetailedApiRequestError(status: 401, message: Invalid Credentials)'),
        contains('Accedi e sincronizza'));
  });

  test('403 generico: accesso negato', () {
    expect(
        messaggioErroreDrive('DetailedApiRequestError(status: 403, message: Forbidden)'),
        contains('Accedi e sincronizza'));
  });

  test('spazio esaurito', () {
    expect(
        messaggioErroreDrive(
            "DetailedApiRequestError(status: 403, message: The user's Drive storage quota has been exceeded.)"),
        'Lo spazio su Google Drive è esaurito.');
  });

  test('troppe richieste: sovraccarico, non accesso negato', () {
    expect(
        messaggioErroreDrive(
            'DetailedApiRequestError(status: 403, message: User Rate Limit Exceeded)'),
        contains('sovraccarico'));
  });

  test('errore del server', () {
    expect(messaggioErroreDrive('DetailedApiRequestError(status: 503)'),
        contains('non risponde'));
  });

  test('errore sconosciuto: messaggio generico', () {
    expect(messaggioErroreDrive(StateError('boh')),
        'Sincronizzazione non riuscita. Riproverò più tardi.');
  });
}
