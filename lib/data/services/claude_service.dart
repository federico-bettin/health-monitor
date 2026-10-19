import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:salute_bettin/core/constants.dart';
import 'package:salute_bettin/data/models/token_usage.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

class ClaudeResponse {
  final String text;
  final int inputTokens;
  final int outputTokens;

  ClaudeResponse({required this.text, required this.inputTokens, required this.outputTokens});

  TokenUsage toTokenUsage(String operazione) => TokenUsage(
    data: DateTime.now(), tokensInput: inputTokens,
    tokensOutput: outputTokens, operazione: operazione);
}

// ─── Modello analisi salute ───────────────────────────────────
class SaluteAnalysis {
  final int score;
  final String titolo;
  final String sommario;

  /// Confronto con la media italiana per la fascia d'età
  final String benchmark;

  final List<String> puntiForza;
  final List<String> areeAttenzione;

  /// Esattamente 3 azioni di miglioramento prioritarie e concrete
  final List<String> miglioramenti;

  /// Esami o visite consigliati (max 5)
  final List<String> esamiDaFare;

  SaluteAnalysis({
    required this.score,
    required this.titolo,
    required this.sommario,
    this.benchmark = '',
    required this.puntiForza,
    required this.areeAttenzione,
    required this.miglioramenti,
    this.esamiDaFare = const [],
  });

  factory SaluteAnalysis.fromJson(Map<String, dynamic> json) => SaluteAnalysis(
    score: (json['score'] as num?)?.toInt() ?? 5,
    titolo: json['titolo'] ?? 'Analisi salute',
    sommario: json['sommario'] ?? '',
    benchmark: json['benchmark'] ?? '',
    puntiForza: List<String>.from(json['punti_forza'] ?? []),
    areeAttenzione: List<String>.from(json['aree_attenzione'] ?? []),
    // Legge 'miglioramenti', con fallback a 'consigli' per retrocompatibilità cache
    miglioramenti: List<String>.from(
      json['miglioramenti'] ?? json['consigli'] ?? []),
    esamiDaFare: List<String>.from(json['esami_da_fare'] ?? []),
  );

  factory SaluteAnalysis.vuota() => SaluteAnalysis(
    score: 0,
    titolo: 'Dati insufficienti',
    sommario: 'Aggiungi esami e visite per ricevere un\'analisi personalizzata.',
    benchmark: '',
    puntiForza: [],
    areeAttenzione: [],
    miglioramenti: ['Inizia aggiungendo i tuoi esami recenti.'],
    esamiDaFare: [],
  );

  Map<String, dynamic> toJson() => {
    'score': score,
    'titolo': titolo,
    'sommario': sommario,
    'benchmark': benchmark,
    'punti_forza': puntiForza,
    'aree_attenzione': areeAttenzione,
    'miglioramenti': miglioramenti,
    'esami_da_fare': esamiDaFare,
  };
}

// ─── Servizio Claude ──────────────────────────────────────────
class ClaudeService {
  static const String _baseUrl = 'https://api.anthropic.com/v1/messages';

  /// Legge il modello da SettingsService — fallback a Haiku se non disponibile
  /// In inglese chiede a Claude di scrivere tutti i testi in inglese.
  String _noteLingua() {
    try {
      if (SettingsService.instance.languageCode == 'en') {
        return '\n\nIMPORTANT: write ALL free-text values of the JSON '
            '(titles, summaries, descriptions, advice, recommendations) in '
            'English. Keep the JSON keys unchanged and keep proper names, '
            'test names and values exactly as printed in the source document.';
      }
    } catch (_) {}
    return '';
  }

  String _getModel() {
    try {
      return SettingsService.instance.aiModel;
    } catch (_) {
      return 'claude-haiku-4-5-20251001';
    }
  }

  Future<ClaudeResponse> _call({
    required String prompt,
    String? systemPrompt,
    int maxTokens = 1800,
    List<Map<String, dynamic>>? imageData,
    String? pdfBase64,
    String? model,
  }) async {
    final content = <Map<String, dynamic>>[];
    if (pdfBase64 != null) {
      content.add({'type': 'document', 'source': {
        'type': 'base64', 'media_type': 'application/pdf', 'data': pdfBase64}});
    }
    if (imageData != null) {
      for (final img in imageData) {
        content.add({'type': 'image', 'source': {
          'type': 'base64', 'media_type': img['mediaType'], 'data': img['data']}});
      }
    }
    content.add({'type': 'text', 'text': prompt});

    final messages = [
      {'role': 'user', 'content': content.length == 1 ? prompt : content}
    ];

    final body = <String, dynamic>{
      'model': model ?? _getModel(),
      'max_tokens': maxTokens,
      'messages': messages,
    };
    if (systemPrompt != null) body['system'] = systemPrompt + _noteLingua();

    final response = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        'Content-Type': 'application/json',
        'x-api-key': AppConstants.anthropicApiKey,
        'anthropic-version': '2023-06-01',
        'anthropic-beta': 'pdfs-2024-09-25',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception('Errore Claude API: ${response.statusCode} — ${response.body}');
    }

    final json = jsonDecode(response.body);
    final text = (json['content'] as List)
        .where((c) => c['type'] == 'text')
        .map((c) => c['text'] as String)
        .join('\n');

    return ClaudeResponse(
      text: text,
      inputTokens: json['usage']['input_tokens'] ?? 0,
      outputTokens: json['usage']['output_tokens'] ?? 0,
    );
  }

  // ─── Traduce l'analisi salute già calcolata (senza ricalcolarla) ──
  /// Traduce i testi del JSON [jsonData] in [lingua] ('it' o 'en'),
  /// mantenendo chiavi, numeri e struttura. Usa il modello più economico.
  Future<({String json, ClaudeResponse risposta})> traduciAnalisi(
      String jsonData, String lingua) async {
    final target = lingua == 'en' ? 'English' : 'Italian';
    final r = await _call(
      systemPrompt: 'You are a precise medical translator. Translate all '
          'human-readable text values of the JSON into $target. Keep every '
          'JSON key, number, unit and the structure exactly unchanged. '
          'Return ONLY the valid JSON, no markdown, no backticks.',
      prompt: jsonData,
      maxTokens: 1800,
      model: 'claude-haiku-4-5-20251001',
    );
    var t = r.text.trim();
    if (t.startsWith('```')) {
      t = t.replaceAll(RegExp(r'^```(?:json)?', multiLine: false), '')
          .replaceAll('```', '')
          .trim();
    }
    return (json: t, risposta: r);
  }

  /// Traduce una lista di testi (nomi esami, note, diagnosi...) in inglese.
  /// Ritorna una mappa originale → traduzione (solo quelli riusciti).
  Future<({Map<String, String> testi, ClaudeResponse risposta})> traduciTesti(
      List<String> testi) async {
    final r = await _call(
      systemPrompt: 'You are a precise medical translator. The user sends a '
          'JSON array of Italian strings (lab test names, medical specialties, '
          'diagnoses, therapies, clinical notes). Translate each into English '
          'using standard medical terminology. Keep numbers, units, drug names '
          'and abbreviations unchanged. Return ONLY a JSON object whose keys '
          'are the exact original Italian strings and whose values are the '
          'English translations. No markdown, no backticks.',
      prompt: jsonEncode(testi),
      maxTokens: 6000,
      model: 'claude-haiku-4-5-20251001',
    );
    var t = r.text.trim();
    if (t.startsWith('```')) {
      t = t.replaceAll('```json', '').replaceAll('```', '').trim();
    }
    final out = <String, String>{};
    final i = t.indexOf('{');
    final j = t.lastIndexOf('}');
    final li = t.indexOf('[');
    final lj = t.lastIndexOf(']');
    try {
      if (i >= 0 && j > i && (li < 0 || i < li)) {
        final obj = jsonDecode(t.substring(i, j + 1)) as Map;
        final norm = {
          for (final e in obj.entries)
            '${e.key}'.trim().toLowerCase(): e.value
        };
        for (final o in testi) {
          final v = obj[o] ?? norm[o.trim().toLowerCase()];
          if (v is String && v.trim().isNotEmpty) out[o] = v;
        }
      } else if (li >= 0 && lj > li) {
        final lista = jsonDecode(t.substring(li, lj + 1)) as List;
        if (lista.length == testi.length) {
          for (var k = 0; k < testi.length; k++) {
            final v = lista[k];
            if (v is String && v.trim().isNotEmpty) out[testi[k]] = v;
          }
        }
      }
    } catch (_) {}
    if (out.isEmpty) {
      final snip = t.length > 150 ? t.substring(0, 150) : t;
      throw Exception('Risposta non utilizzabile: $snip');
    }
    return (testi: out, risposta: r);
  }

  // ─── Analizza documento ───────────────────────────────────
  Future<ClaudeResponse> analizzaDocumento({
    String? base64Immagine, String? mediaTypeImmagine, String? base64Pdf,
  }) async {
    const systemPrompt = '''
Sei un medico esperto che analizza documenti sanitari italiani.
Restituisci SOLO un JSON valido, senza markdown, senza backtick.
{
  "tipo": "esame|visita|farmaco|altro",
  "data": "YYYY-MM-DD",
  "titolo": "nome documento",
  "esito": "interpretazione clinica sintetica (max 3 frasi)",
  "dati": {
    "valori": [{"nome":"","valore":"","unita":"","riferimentoMin":"","riferimentoMax":"","fuoriRange":false}],
    "specialita":"","medico":"","diagnosi":"","terapia":"","nome":"","dosaggio":"","frequenza":""
  },
  "note": "",
  "laboratorio": ""
}
''';
    return _call(
      prompt: 'Analizza questo documento medico e restituisci il JSON.',
      systemPrompt: systemPrompt, maxTokens: 2000,
      imageData: base64Immagine != null
          ? [{'mediaType': mediaTypeImmagine, 'data': base64Immagine}] : null,
      pdfBase64: base64Pdf,
    );
  }

  // ─── Analizza salute con tutti i dati ────────────────────
  Future<SaluteAnalysis> analizzaSalute({
    required Map<String, dynamic> datiSalute,
  }) async {
    // ignore: prefer_interpolation_to_compose_strings
    const systemPrompt = r'''
Sei un medico di medicina generale esperto. Analizza i dati sanitari del paziente italiano.
Restituisci SOLO un JSON valido, senza markdown, senza backtick, senza spiegazioni.

═══════════════════════════════════════════════════
DATI CHE RICEVI:
- Anagrafica: età, peso, altezza, BMI e categoria
- Stile di vita: fumo (sigarette/giorno), alcool (bicchieri vino/giorno), passi medi/giorno
- Esami: SOLO l'ultimo per tipo (già filtrati dal sistema)
- Visite: SOLO l'ultima per specialità (già filtrate)
- Farmaci attivi
- Patologie croniche
- Anamnesi personale

═══════════════════════════════════════════════════
CALCOLO SCORE — parti da 10 e applica le penalità:

PESO/BMI:
  BMI 25.0–29.9 (sovrappeso): -0.5
  BMI 30.0–34.9 (obesità I): -1.5
  BMI ≥35 (obesità II–III): -2.5

ESAMI (per ogni valore fuori range):
  Scostamento ≤10% dal range: -0.5 (max cumul. -2)
  Scostamento 11–30%: -1.0 (max cumul. -2)
  Scostamento >30%: -1.5 (max cumul. -3)

FUMO:
  1–10 sigarette/giorno: -1.0
  11–20 sigarette/giorno: -1.5
  >20 sigarette/giorno: -2.0

ALCOOL:
  1–2 bicchieri vino/giorno: -0.5
  >2 bicchieri vino/giorno: -1.5

ATTIVITÀ FISICA (passi/giorno):
  <3.000 passi: -1.0
  3.000–5.999 passi: -0.5
  6.000–7.999 passi: nessuna penalità
  ≥8.000 passi: +0.5 (bonus, max +0.5)

SONNO (ore/notte, se disponibile da wearable):
  <5.0 ore: -1.5
  5.0–5.9 ore: -0.5
  6.0–8.5 ore: nessuna penalità
  >9.0 ore (adulti <65): -0.5 (possibile disturbo)
  Se dato non disponibile: ignora la categoria.

PATOLOGIE CRONICHE SERIE (diabete, cardiopatia ischemica,
  insufficienza renale, BPCO, neoplasia attiva, HIV):
  -1.0 per ciascuna (max cumulativo -2.5)

REGOLE FINALI:
  Score minimo 1, massimo 10.
  Arrotonda all'intero più vicino.
  Se dati insufficienti (nessun esame, nessuna visita): score 0.

═══════════════════════════════════════════════════
BENCHMARK: confronta con i dati epidemiologici ISTAT/ISS
  per la stessa fascia d'età (±5 anni) in Italia.
  Cita almeno un dato numerico di riferimento.
  Se età non disponibile, confronta con media adulti italiani.

═══════════════════════════════════════════════════
FORMATO JSON — rispetta esattamente questa struttura:
{
  "score": 7,
  "titolo": "Salute discreta (max 4 parole)",
  "sommario": "Descrizione concreta dello stato fisico in 2-3 frasi. Cita valori specifici con unità di misura. Es: il colesterolo LDL è a 145 mg/dL (riferimento <130), BMI 27.2 in fascia sovrappeso.",
  "benchmark": "Confronto con la media italiana. Es: per un uomo di 45 anni la media LDL italiana è ~130 mg/dL; il tuo valore è superiore del 12%. I trigliceridi rientrano nella norma della fascia d'età.",
  "punti_forza": [
    "max 3 voci — specifiche con valori. Es: Glicemia 89 mg/dL, ottimale per la fascia d'età"
  ],
  "aree_attenzione": [
    "max 3 voci — con valore, range e % scostamento. Es: LDL 145 mg/dL (+12% vs range <130)"
  ],
  "miglioramenti": [
    "esattamente 3 azioni prioritarie, concrete e misurabili. Es: Ridurre i grassi saturi a <7% delle calorie giornaliere per abbassare l'LDL di 10–15%",
    "seconda azione",
    "terza azione"
  ],
  "esami_da_fare": [
    "max 5 esami o visite raccomandati dalle linee guida italiane in base all'età, ai valori riscontrati e alle patologie. Es: ECG a riposo (non eseguito negli ultimi 2 anni, indicato >40 anni con dislipidemia)"
  ]
}
''';

    final response = await _call(
      prompt: 'Analizza questi dati sanitari e restituisci il JSON:\n${jsonEncode(datiSalute)}',
      systemPrompt: systemPrompt,
      maxTokens: 1800,
    );
    final text = response.text.trim()
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();
    return SaluteAnalysis.fromJson(jsonDecode(text));
  }
}
