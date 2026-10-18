/// Dizionario di sinonimi medici.
class MedicalTerms {
  MedicalTerms._();

  static const Map<String, String> _sinonimi = {
    // ─── Colesterolo ───────────────────────────────────────
    'colesterolo ldl': 'Colesterolo LDL',
    'ldl colesterolo': 'Colesterolo LDL',
    'ldl-colesterolo': 'Colesterolo LDL',
    'colesterolo-ldl': 'Colesterolo LDL',
    'ldl': 'Colesterolo LDL',
    'low density lipoprotein': 'Colesterolo LDL',
    'c-ldl': 'Colesterolo LDL',
    'col ldl': 'Colesterolo LDL',
    'colest ldl': 'Colesterolo LDL',
    'ldl cholesterol': 'Colesterolo LDL',
    'colesterolo hdl': 'Colesterolo HDL',
    'hdl colesterolo': 'Colesterolo HDL',
    'hdl-colesterolo': 'Colesterolo HDL',
    'colesterolo-hdl': 'Colesterolo HDL',
    'hdl': 'Colesterolo HDL',
    'c-hdl': 'Colesterolo HDL',
    'col hdl': 'Colesterolo HDL',
    'hdl cholesterol': 'Colesterolo HDL',
    'colesterolo totale': 'Colesterolo Totale',
    'colesterolo': 'Colesterolo Totale',
    'colest totale': 'Colesterolo Totale',
    'col totale': 'Colesterolo Totale',
    'total cholesterol': 'Colesterolo Totale',
    'tc': 'Colesterolo Totale',
    'trigliceridi': 'Trigliceridi',
    'tg': 'Trigliceridi',
    'triglic': 'Trigliceridi',
    'triglycerides': 'Trigliceridi',
    'trigl': 'Trigliceridi',
    'vldl': 'Colesterolo VLDL',
    'colesterolo vldl': 'Colesterolo VLDL',
    // ─── Glicemia ──────────────────────────────────────────
    'glicemia': 'Glicemia',
    'glucosio': 'Glicemia',
    'glucosio plasmatico': 'Glicemia',
    'glicemia a digiuno': 'Glicemia',
    'glucose': 'Glicemia',
    'glu': 'Glicemia',
    'emoglobina glicata': 'Emoglobina Glicata (HbA1c)',
    'hba1c': 'Emoglobina Glicata (HbA1c)',
    'hb1ac': 'Emoglobina Glicata (HbA1c)',
    'emoglobina glicosilata': 'Emoglobina Glicata (HbA1c)',
    'a1c': 'Emoglobina Glicata (HbA1c)',
    'glicata': 'Emoglobina Glicata (HbA1c)',
    'insulina': 'Insulina',
    'insulinemia': 'Insulina',
    // ─── Emocromo ──────────────────────────────────────────
    'globuli rossi': 'Globuli Rossi (RBC)',
    'eritrociti': 'Globuli Rossi (RBC)',
    'rbc': 'Globuli Rossi (RBC)',
    'gr': 'Globuli Rossi (RBC)',
    'emazie': 'Globuli Rossi (RBC)',
    'globuli bianchi': 'Globuli Bianchi (WBC)',
    'leucociti': 'Globuli Bianchi (WBC)',
    'wbc': 'Globuli Bianchi (WBC)',
    'gb': 'Globuli Bianchi (WBC)',
    'emoglobina': 'Emoglobina',
    'hb': 'Emoglobina',
    'hgb': 'Emoglobina',
    'hemoglobin': 'Emoglobina',
    'ematocrito': 'Ematocrito',
    'hct': 'Ematocrito',
    'ht': 'Ematocrito',
    'piastrine': 'Piastrine',
    'plt': 'Piastrine',
    'platelets': 'Piastrine',
    'trombociti': 'Piastrine',
    'mcv': 'MCV',
    'volume globulare medio': 'MCV',
    'mch': 'MCH',
    'mchc': 'MCHC',
    'rdw': 'RDW',
    // ─── Fegato ────────────────────────────────────────────
    'alt': 'ALT (GPT)',
    'gpt': 'ALT (GPT)',
    'alanina aminotransferasi': 'ALT (GPT)',
    'alanina transaminasi': 'ALT (GPT)',
    'transaminasi alt': 'ALT (GPT)',
    'ast': 'AST (GOT)',
    'got': 'AST (GOT)',
    'aspartato aminotransferasi': 'AST (GOT)',
    'transaminasi ast': 'AST (GOT)',
    'gamma gt': 'Gamma-GT',
    'gamma-gt': 'Gamma-GT',
    'ggt': 'Gamma-GT',
    'gammaglutamiltransferasi': 'Gamma-GT',
    'bilirubina totale': 'Bilirubina Totale',
    'bilirubina': 'Bilirubina Totale',
    'bilirubina diretta': 'Bilirubina Diretta',
    'bilirubina coniugata': 'Bilirubina Diretta',
    'fosfatasi alcalina': 'Fosfatasi Alcalina (ALP)',
    'alp': 'Fosfatasi Alcalina (ALP)',
    // ─── Reni ──────────────────────────────────────────────
    'creatinina': 'Creatinina',
    'creat': 'Creatinina',
    'azotemia': 'Azotemia (BUN)',
    'urea': 'Azotemia (BUN)',
    'bun': 'Azotemia (BUN)',
    'azoto ureico': 'Azotemia (BUN)',
    'acido urico': 'Acido Urico',
    'uricemia': 'Acido Urico',
    'egfr': 'eGFR',
    'gfr': 'eGFR',
    'filtrazione glomerulare': 'eGFR',
    // ─── Tiroide ───────────────────────────────────────────
    'tsh': 'TSH',
    'ormone tireostimolante': 'TSH',
    'tirotropina': 'TSH',
    'ft4': 'FT4',
    'tiroxina libera': 'FT4',
    't4 libera': 'FT4',
    'ft3': 'FT3',
    'triiodotironina libera': 'FT3',
    't3 libera': 'FT3',
    // ─── Infiammazione ─────────────────────────────────────
    'pcr': 'PCR',
    'crp': 'PCR',
    'proteina c reattiva': 'PCR',
    'c reactive protein': 'PCR',
    'hs-crp': 'PCR',
    'ves': 'VES',
    'eritrosedimentazione': 'VES',
    'esr': 'VES',
    // ─── Ferro ─────────────────────────────────────────────
    'ferro': 'Ferro Sierico',
    'sideremia': 'Ferro Sierico',
    'fe': 'Ferro Sierico',
    'ferritina': 'Ferritina',
    'transferrina': 'Transferrina',
    'saturazione transferrina': 'Saturazione Transferrina',
    'tibc': 'TIBC',
    // ─── Vitamine ──────────────────────────────────────────
    'vitamina d': 'Vitamina D',
    'vit d': 'Vitamina D',
    '25-oh vitamina d': 'Vitamina D',
    '25-oh-d3': 'Vitamina D',
    '25 idrossivitamina d': 'Vitamina D',
    'calcifediolo': 'Vitamina D',
    'vitamina b12': 'Vitamina B12',
    'vit b12': 'Vitamina B12',
    'cobalamina': 'Vitamina B12',
    'folati': 'Folati (B9)',
    'acido folico': 'Folati (B9)',
    'vitamina b9': 'Folati (B9)',
    // ─── Elettroliti ───────────────────────────────────────
    'calcio': 'Calcio',
    'calcemia': 'Calcio',
    'sodio': 'Sodio',
    'sodiemia': 'Sodio',
    'potassio': 'Potassio',
    'potassiemia': 'Potassio',
    'magnesio': 'Magnesio',
    'fosforo': 'Fosforo',
    'fosforemia': 'Fosforo',
    // ─── Cardiaco ──────────────────────────────────────────
    'troponina': 'Troponina',
    'troponina t': 'Troponina T',
    'troponina i': 'Troponina I',
    'bnp': 'BNP',
    'nt-probnp': 'NT-proBNP',
    // ─── Coagulazione ──────────────────────────────────────
    'inr': 'INR',
    'pt': 'PT',
    'tempo di protrombina': 'PT',
    'ptt': 'PTT',
    'aptt': 'PTT',
    'fibrinogeno': 'Fibrinogeno',
    'd-dimero': 'D-Dimero',
    'd dimero': 'D-Dimero',
    // ─── PSA ───────────────────────────────────────────────
    'psa': 'PSA',
    'psa totale': 'PSA',
    'antigene prostatico': 'PSA',
    // ─── Proteine ──────────────────────────────────────────
    'proteine totali': 'Proteine Totali',
    'albumina': 'Albumina',
  };

  static const Map<String, List<String>> _categorie = {
    'Lipidi': [
      'Colesterolo LDL', 'Colesterolo HDL', 'Colesterolo Totale',
      'Colesterolo VLDL', 'Trigliceridi',
    ],
    'Glicemia': [
      'Glicemia', 'Emoglobina Glicata (HbA1c)', 'Insulina',
    ],
    'Emocromo': [
      'Globuli Rossi (RBC)', 'Globuli Bianchi (WBC)', 'Emoglobina',
      'Ematocrito', 'Piastrine', 'MCV', 'MCH', 'MCHC', 'RDW',
    ],
    'Fegato': [
      'ALT (GPT)', 'AST (GOT)', 'Gamma-GT',
      'Bilirubina Totale', 'Bilirubina Diretta', 'Fosfatasi Alcalina (ALP)',
    ],
    'Reni': [
      'Creatinina', 'Azotemia (BUN)', 'Acido Urico', 'eGFR',
    ],
    'Tiroide': [
      'TSH', 'FT4', 'FT3',
    ],
    'Infiammazione': [
      'PCR', 'VES', 'Fibrinogeno',
    ],
    'Ferro': [
      'Ferro Sierico', 'Ferritina', 'Transferrina',
      'Saturazione Transferrina', 'TIBC',
    ],
    'Vitamine': [
      'Vitamina D', 'Vitamina B12', 'Folati (B9)',
    ],
    'Elettroliti': [
      'Calcio', 'Sodio', 'Potassio', 'Magnesio', 'Fosforo',
    ],
    'Cardiaco': [
      'Troponina', 'Troponina T', 'Troponina I', 'BNP', 'NT-proBNP',
    ],
    'Coagulazione': [
      'INR', 'PT', 'PTT', 'Fibrinogeno', 'D-Dimero',
    ],
    'PSA / Proteine': [
      'PSA', 'Proteine Totali', 'Albumina',
    ],
  };

  /// Normalizza un nome di valore esame al nome canonico
  static String normalizza(String nome) {
    final cleaned = nome
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'[®™°]'), '')
        .trim();

    if (_sinonimi.containsKey(cleaned)) return _sinonimi[cleaned]!;

    for (final entry in _sinonimi.entries) {
      if (cleaned == entry.key) return entry.value;
    }
    for (final entry in _sinonimi.entries) {
      if (cleaned.contains(entry.key) || entry.key.contains(cleaned)) {
        return entry.value;
      }
    }

    return cleaned.split(' ')
        .map((w) => w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
        .join(' ');
  }

  /// Restituisce la categoria di un valore normalizzato
  static String categoria(String nomeNormalizzato) {
    for (final entry in _categorie.entries) {
      if (entry.value.contains(nomeNormalizzato)) return entry.key;
    }
    return 'Altri';
  }

  /// Tutte le categorie disponibili
  static List<String> get tutteCategorie => _categorie.keys.toList();
}
