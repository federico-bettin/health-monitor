import 'dart:convert';

import 'package:flutter/material.dart' as m;
import 'package:salute_bettin/core/i18n_en.dart';
import 'package:salute_bettin/data/services/settings_service.dart';

/// Traduzione dell'interfaccia (italiano = lingua di origine nel codice).
///
/// - Il widget [Text] di questo file sostituisce quello di Flutter
///   (`import 'package:flutter/material.dart' hide Text;`) e traduce da solo
///   il testo quando la lingua è inglese.
/// - [tr] serve per le stringhe che non passano da un Text
///   (tooltip, etichette dei campi, notifiche...).
/// - Le traduzioni sono in i18n_en.dart: chiave = testo italiano,
///   `{0}`, `{1}`... = valori inseriti a runtime.

String get _lingua {
  try {
    return SettingsService.instance.languageCode;
  } catch (_) {
    return 'it';
  }
}

final Map<String, String> _cache = {};

/// Traduzioni (generate dall'AI) dei testi salvati dall'utente: nomi esami,
/// note, diagnosi, terapie... Chiave = testo originale in italiano.
final Map<String, String> _dati = {};

/// Cambia a ogni nuova traduzione: i Text si ricostruiscono da soli.
final m.ValueNotifier<int> datiVersione = m.ValueNotifier<int>(0);

/// Carica da SharedPreferences le traduzioni già fatte.
void caricaTraduzioniDati() {
  try {
    final m = jsonDecode(SettingsService.instance.datiTradEn) as Map;
    _dati
      ..clear()
      ..addAll(m.map((k, v) => MapEntry('$k', '$v')));
    _cache.clear();
  } catch (_) {}
}

/// Aggiunge nuove traduzioni e le salva.
Future<void> aggiungiTraduzioniDati(Map<String, String> nuove) async {
  if (nuove.isEmpty) return;
  _dati.addAll(nuove);
  _cache.clear();
  datiVersione.value++;
  try {
    await SettingsService.instance.setDatiTradEn(jsonEncode(_dati));
  } catch (_) {}
}

/// True se [s] è già traducibile (dizionari statici o traduzioni salvate).
bool haTraduzioneEn(String s) =>
    kTraduzioniEn.containsKey(s) ||
    kTraduzioniMedEn.containsKey(s) ||
    (_dati[s] != null && _dati[s] != s);
List<_Template>? _templates;

class _Template {
  final RegExp re;
  final String en;
  _Template(this.re, this.en);
}

List<_Template> _buildTemplates() {
  final out = <_Template>[];
  void add(String it, String en) {
    if (!it.contains('{0}')) return;
    final parts = it.split(RegExp(r'\{\d\}'));
    final buf = StringBuffer('^');
    for (var i = 0; i < parts.length; i++) {
      buf.write(RegExp.escape(parts[i]));
      if (i < parts.length - 1) buf.write('(.+?)');
    }
    buf.write(r'$');
    out.add(_Template(RegExp(buf.toString(), dotAll: true), en));
  }

  kTraduzioniEn.forEach(add);
  kTraduzioniMedEn.forEach(add);
  kTemplateEn.forEach(add);
  // Più specifici (più testo fisso) per primi
  out.sort((a, b) => b.re.pattern.length.compareTo(a.re.pattern.length));
  return out;
}

String _traduciEn(String s) {
  final exact = kTraduzioniEn[s] ?? kTraduzioniMedEn[s];
  if (exact != null) return exact;
  final dato = _dati[s] ?? _dati[s.trim()];
  if (dato != null) return dato;

  _templates ??= _buildTemplates();
  for (final t in _templates!) {
    final mt = t.re.firstMatch(s);
    if (mt == null) continue;
    return t.en.replaceAllMapped(RegExp(r'\{(\d)\}'), (x) {
      final i = int.parse(x.group(1)!);
      final g = i + 1 <= mt.groupCount ? mt.group(i + 1) ?? '' : '';
      return _traduciEn(g);
    });
  }

  // Testi su più righe: traduce riga per riga
  if (s.contains('\n')) {
    final righe = s.split('\n');
    final tradotte = righe.map(_traduciEn).toList();
    return tradotte.join('\n');
  }
  return s;
}

/// Traduce [it] nella lingua corrente. [args] sostituisce {0}, {1}...
String translate(String it, String lingua, [List<Object?> args = const []]) {
  var s = it;
  if (args.isNotEmpty) {
    for (var i = 0; i < args.length; i++) {
      s = s.replaceAll('{$i}', '${args[i]}');
    }
  }
  if (lingua != 'en') return s;
  return _cache.putIfAbsent(s, () => _traduciEn(s));
}

/// Traduzione per stringhe fuori dai widget Text. Accetta null.
String tr(String? it, [List<Object?> args = const []]) =>
    it == null ? '' : translate(it, _lingua, args);

/// Applica la traduzione a un InputDecoration (etichette, suggerimenti...).
m.InputDecoration trDeco(m.InputDecoration d) => d.copyWith(
      labelText: d.labelText == null ? null : tr(d.labelText),
      hintText: d.hintText == null ? null : tr(d.hintText),
      helperText: d.helperText == null ? null : tr(d.helperText),
      suffixText: d.suffixText == null ? null : tr(d.suffixText),
    );

/// Sostituto di Flutter `Text`: traduce il testo se la lingua è l'inglese.
/// Si ricostruisce da solo quando cambia la lingua dell'app.
class Text extends m.StatelessWidget {
  final String data;
  final m.TextStyle? style;
  final m.StrutStyle? strutStyle;
  final m.TextAlign? textAlign;
  final m.TextDirection? textDirection;
  final m.Locale? locale;
  final bool? softWrap;
  final m.TextOverflow? overflow;
  final m.TextScaler? textScaler;
  final int? maxLines;
  final String? semanticsLabel;
  final m.TextWidthBasis? textWidthBasis;
  final m.TextHeightBehavior? textHeightBehavior;
  final m.Color? selectionColor;

  const Text(
    this.data, {
    super.key,
    this.style,
    this.strutStyle,
    this.textAlign,
    this.textDirection,
    this.locale,
    this.softWrap,
    this.overflow,
    this.textScaler,
    this.maxLines,
    this.semanticsLabel,
    this.textWidthBasis,
    this.textHeightBehavior,
    this.selectionColor,
  });

  @override
  m.Widget build(m.BuildContext context) {
    // Dipendenza dalla lingua: ricostruisce il widget quando cambia
    final lingua = m.Localizations.maybeLocaleOf(context)?.languageCode ?? _lingua;
    return m.ValueListenableBuilder<int>(
      valueListenable: datiVersione,
      builder: (ctx, _, __) => m.Text(
        translate(data, lingua),
        style: style,
        strutStyle: strutStyle,
        textAlign: textAlign,
        textDirection: textDirection,
        locale: locale,
        softWrap: softWrap,
        overflow: overflow,
        textScaler: textScaler,
        maxLines: maxLines,
        semanticsLabel: semanticsLabel,
        textWidthBasis: textWidthBasis,
        textHeightBehavior: textHeightBehavior,
        selectionColor: selectionColor,
      ),
    );
  }
}
