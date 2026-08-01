/// Rule-based auto-categorization of purchases, originally ported from
/// the desktop categorizer (Projetos/Gastos/categorizar.py): item-name
/// normalization, ordered keyword/regex rules (first match wins), an
/// accent-stripped second pass, then store hints.
///
/// The taxonomy has since diverged from categorizar.py on purpose:
/// Alimentacao/Farmacia/Higiene are gone (folded into Comida/Saude/
/// Pessoal), Comida was split into Comida, Frutas and "Aumentador de
/// Tecido Adiposo", cleaning products moved out of Casa into Limpeza,
/// and Lazer was renamed. [nameKey] maps the retired names onto their
/// replacements so lists that still carry them are reused instead of
/// duplicated.
///
/// Unlike the Python pipeline, an item no rule recognizes returns null
/// (instead of 'Outros') so it stays visible as "sem categoria" for
/// manual review.
class PurchaseCategorizer {
  PurchaseCategorizer._();

  /// Long category names, kept as constants so the rule table stays
  /// readable.
  static const lazer = 'Lazer, beleza e brinquedos';
  static const junk = 'Dieta de Engorda';

  /// Default colors when auto-creating a missing category.
  static const categoryColors = <String, int>{
    'Comida': 0xFF10B981,
    'Frutas': 0xFFF97316,
    junk: 0xFFB91C1C,
    'Casa': 0xFFF59E0B,
    'Limpeza': 0xFF14B8A6,
    'Construcao': 0xFF06B6D4,
    'Saude': 0xFF3B82F6,
    'Veiculos': 0xFFEF4444,
    'Servicos': 0xFF6366F1,
    'Pessoal': 0xFFA855F7,
    lazer: 0xFFEC4899,
    'Pet': 0xFF84CC16,
    'Tecnologia': 0xFF0EA5E9,
    'Papelaria': 0xFFD97706,
    'Outros': 0xFF94A3B8,
  };

  /// Returns the category name for a purchase, or null when no rule
  /// matches.
  static String? categorize(String item, String? local) {
    final normalized = _normalize(_normalizeItemName(item));
    final store = _normalize(local ?? '');
    if (normalized.isEmpty) return null;

    final exact = _exactMatches[normalized];
    if (exact != null) return exact;

    for (final (match, cat) in _rules) {
      if (match(normalized, store)) return cat;
    }
    final noAccents = _stripAccents(normalized);
    for (final (match, cat) in _rules) {
      if (match(noAccents, store)) return cat;
    }
    for (final entry in _storeHints.entries) {
      if (store.contains(entry.key)) return entry.value;
    }
    return null;
  }

  /// Accent-insensitive lowercase key for matching a rule's category
  /// name against the user's existing categories. Retired names collapse
  /// onto their replacement, so a list that still has "Alimentação" or
  /// "Farmácia" is reused instead of getting a duplicate.
  static String nameKey(String name) {
    final key = _stripAccents(_normalize(name));
    return _nameAliases[key] ?? key;
  }

  static const _nameAliases = <String, String>{
    'alimentacao': 'comida',
    'farmacia': 'saude',
    'higiene': 'pessoal',
    'lazer': 'lazer, beleza e brinquedos',
  };

  // ── Normalization ─────────────────────────────────────────────────
  static String _normalize(String text) =>
      text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  static String _stripAccents(String text) {
    const replacements = {
      'ã': 'a', 'á': 'a', 'â': 'a', 'à': 'a',
      'é': 'e', 'ê': 'e', 'è': 'e',
      'í': 'i', 'ì': 'i', 'î': 'i',
      'ó': 'o', 'ô': 'o', 'õ': 'o', 'ò': 'o',
      'ú': 'u', 'ù': 'u', 'û': 'u',
      'ç': 'c',
    };
    var result = text;
    replacements.forEach((src, dst) {
      result = result.replaceAll(src, dst);
    });
    return result;
  }

  /// Normalizes item-name variants to a canonical form (for matching
  /// only): strips a quantity prefix, then first matching pattern wins.
  static String _normalizeItemName(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return raw;
    final stripped = text.replaceFirst(RegExp(r'^\d+\s+'), '').trim();
    final lower = stripped.toLowerCase();
    for (final (pattern, canonical) in _normalizationRules) {
      if (pattern.hasMatch(lower)) return canonical;
    }
    return text;
  }

  static final _normalizationRules = <(RegExp, String)>[
    // Linguiça frango (BEFORE generic linguiça)
    (RegExp(r'lingu?[ií][cç]as?\s+frango'), 'Linguiça frango'),
    (RegExp(r'lingu?[ií][cç]as?(\s+calabresa)?(\s+\w+)*$'),
        'Linguiça calabresa'),
    (RegExp(r'linugica'), 'Linguiça calabresa'),
    (RegExp(r'p[aã][oe]s?\s+de\s+queijo'), 'Pão de queijo'),
    (RegExp(r'p[aã]o\s+de\s+forma'), 'Pão de forma'),
    (RegExp(r'p[aã][oe]s?\s+(de\s+)?hamb[uú]rguer'), 'Pão hambúrguer'),
    (RegExp(r'p[aã]o\s+hot\s*dog'), 'Pão hot dog'),
    (RegExp(r'presunto(\s+fatiado)?$'), 'Presunto'),
    (RegExp(r'macarr[aã]o(\s+(espaguete|penne)\s*\w*)?$'), 'Macarrão'),
    (RegExp(r'leite\s+em\s+p[oó]'), 'Leite em pó'),
    (RegExp(r'leite\s+po\b'), 'Leite em pó'),
    (RegExp(r'leite\s+\d+g'), 'Leite em pó'),
    (RegExp(r'leite\s+condensad?[so]'), 'Leite condensado'),
    (RegExp(r'leite\s+(1l|piracanjuba|ccgl)'), 'Leite 1L'),
    (RegExp(r'leite\s+fermentad'), 'Leite fermentado'),
    (RegExp(r'cre[ae]me?\s+de\s+leite'), 'Creme de leite'),
    (RegExp(r'(fatias\s+de\s+)?queijo\s+mussarela'), 'Queijo mussarela'),
    (RegExp(r'maionese\s+heinz'), 'Maionese Heinz'),
    (RegExp(r'maionese(\s+hellmans?)?$'), 'Maionese Hellmans'),
    (RegExp(r'sab[aã]o\s+em\s+p[oó]'), 'Sabão em pó'),
    (RegExp(r'papel\s+higi[eê]nico'), 'Papel higiênico'),
    (RegExp(r'ama[cz]iante'), 'Amaciante'),
    (RegExp(r'[aá]gua\s+mineral'), 'Água mineral'),
    (RegExp(r'detergente$'), 'Detergente'),
    (RegExp(r'carne\s+mo[ií]da'), 'Carne moída'),
    (RegExp(r'carne\s+patinho'), 'Carne patinho'),
    (RegExp(r'patinho\s+\d+g'), 'Carne patinho'),
  ];

  // ── Rules ─────────────────────────────────────────────────────────
  static _Matcher _kw(List<String> keywords) =>
      (item, store) => keywords.any((k) => item.contains(k));

  static _Matcher _rx(String pattern) {
    final re = RegExp(pattern);
    return (item, store) => re.hasMatch(item);
  }

  /// Checked in order, first match wins. Keywords match anywhere in the
  /// item, so "Trufado de Nutella com fritas" hits the first of
  /// trufado/nutella/frit in this list. Short words that live inside
  /// unrelated ones are anchored with \b (e.g. "cano" must not eat
  /// "canoeiro", "uva" must not eat "luvas").
  static final _rules = <(_Matcher, String)>[
    // Serviços / pagamentos (check first - high priority overrides)
    (_kw(['divida uninter', 'dívida uninter']), 'Servicos'),
    (_kw(['cartao mercado pago', 'cartão mercado pago']), 'Servicos'),
    (_kw(['conta internet', 'internet']), 'Servicos'),
    (_kw(['conta carol']), 'Servicos'),
    (_kw(['pix carol']), 'Servicos'),
    (_rx(r'cr[eé]dito carol'), 'Servicos'),
    (_kw(['inscri', 'indicado injet']), 'Servicos'),
    (_kw(['dentista']), 'Servicos'),
    (_kw(['jiujitsu', 'jiu jitsu', 'jiu-jitsu']), 'Servicos'),
    (_kw(['muaythai', 'muay thai']), 'Servicos'),

    // Veículos (specific — before Construção, "tinta preto fosco" is
    // paint for the moto, not for the house)
    (_kw(['gasolina']), 'Veiculos'),
    (_rx(r'c[aâ]mara.*moto'), 'Veiculos'),
    (_kw(['corrente da moto', 'corrente moto']), 'Veiculos'),
    (_kw(['pedaleira moto']), 'Veiculos'),
    (_kw(['camera de re', 'câmera de ré']), 'Veiculos'),
    (_kw(['tinta preto fosco']), 'Veiculos'),

    // Farmácia / saúde — BEFORE Construção, so "luvas descartáveis" and
    // "máscara descartável" don't fall into the construction "luvas".
    (_kw(['ritalina']), 'Saude'),
    (_kw(['depakene']), 'Saude'),
    (_kw(['neosoro']), 'Saude'),
    (_kw(['histamin']), 'Saude'),
    (_kw(['kronel']), 'Saude'),
    (_kw(['sepurin']), 'Saude'),
    (_kw(['allegra']), 'Saude'),
    (_kw(['predisona', 'prednisona']), 'Saude'),
    (_kw(['melatonina']), 'Saude'),
    (_rx(r'pasta d.agua'), 'Saude'),
    (_kw(['soro fisiol']), 'Saude'),
    (_kw(['seringa']), 'Saude'),
    (_kw(['coletor']), 'Saude'),
    (_rx(r'term[oô]metro'), 'Saude'),
    (_rx(r'm[aá]scara descart'), 'Saude'),
    (_kw(['luvas descart', 'pacote luvas']), 'Saude'),
    (_kw(['luvas gleice']), 'Saude'),
    (_kw(['absorvente']), 'Saude'),
    (_kw(['lubrificante']), 'Saude'),

    // Construção / encanamento / elétrica / ferragens
    (_kw(['suporte tv']), 'Casa'), // exception to the generic "suporte"
    (_kw(["caixa d'agua", "caixa d'água", 'caixa dagua']), 'Construcao'),
    (_rx(r'conex[oõ]'), 'Construcao'),
    (_rx(r'encana[cç][aã]o'), 'Construcao'),
    (_kw(['vara de cano', 'vara cano']), 'Construcao'),
    (_kw(['cola de cano']), 'Construcao'),
    (_rx(r'veda\s*rosca'), 'Construcao'),
    (_kw(['vedacit']), 'Construcao'),
    (_rx(r'luva.*mm'), 'Construcao'),
    (_kw(['luva lr']), 'Construcao'),
    (_rx(r'\bluvas?\b'), 'Construcao'),
    (_kw(['registro']), 'Construcao'),
    (_rx(r'\bjoelhos?\b'), 'Construcao'),
    (_rx(r'\d+\s*curva|\bcurvas?\b'), 'Construcao'),
    (_kw(['exaustor']), 'Construcao'),
    (_kw(['tomada', 'interruptor', 'desligador', 'disjuntor']),
        'Construcao'),
    (_rx(r'\bfios?\b(?!\s*dental)'), 'Construcao'),
    (_rx(r'\bcanos?\b'), 'Construcao'),
    (_rx(r'\bcaps\b'), 'Construcao'),
    // Standalone "T" is the pipe fitting, not a t-shirt.
    (_rx(r'^t$|^t\s+(\d|pvc|mm|soldav|rosc)'), 'Construcao'),
    (_kw(['serra copo']), 'Construcao'),
    (_kw(['kit chaves', 'chave 10']), 'Construcao'),
    (_kw(['coluna']), 'Construcao'),
    (_rx(r'lixa.*parede'), 'Construcao'),
    (_kw(['irrigador', 'mangueira']), 'Construcao'),
    (_kw(['prateleira']), 'Construcao'),
    (_kw(['painel de led']), 'Construcao'),
    (_rx(r'\bleds?\b'), 'Construcao'),
    (_kw(['disco de corte', 'talhadeira', 'broca']), 'Construcao'),
    (_kw(['nylon ro']), 'Construcao'),
    (_kw(['parafus']), 'Construcao'), // parafuso(s), parafusadeira
    (_rx(r'dobradi[cç]'), 'Construcao'),
    (_kw(['presilha', 'emenda', 'ferrolho']), 'Construcao'),
    (_kw(['ferro']), 'Construcao'),
    (_kw(['cimento', 'tijolo', 'areia', 'brita', 'madeirite',
      'compensado']), 'Construcao'),
    (_rx(r'\bbarros?\b|\bterras?\b'), 'Construcao'),
    (_rx(r'\bpregos?\b'), 'Construcao'),
    (_rx(r'\bb[oó]ias?\b'), 'Construcao'),
    (_rx(r'\bportas?\b|port[aã]o'), 'Construcao'),
    (_kw(['pedreiro', 'benildo']), 'Construcao'),
    (_rx(r'\bajudante\b'), 'Construcao'),
    (_kw(['corda de varal', 'varal']), 'Construcao'),
    (_kw(['fita isolante']), 'Construcao'),
    (_rx(r'massa pl[aá]stica'), 'Construcao'),
    (_rx(r'fog[aã]o.*lenha'), 'Construcao'),
    (_kw(['graxa']), 'Construcao'),
    (_kw(['tinta']), 'Construcao'),
    (_kw(['constru']), 'Construcao'),
    (_kw(['suporte']), 'Construcao'),

    // Pessoal — higiene pessoal, presentes e acessórios
    (_kw(['creme dental']), 'Pessoal'),
    (_kw(['fio dental']), 'Pessoal'),
    (_kw(['enxaguante']), 'Pessoal'),
    (_kw(['shampoo', 'condicionador']), 'Pessoal'),
    (_kw(['sabonete']), 'Pessoal'),
    (_kw(['desodorante']), 'Pessoal'),
    (_kw(['escova de dente']), 'Pessoal'),
    (_kw(['gilete', 'aparelho de barbear']), 'Pessoal'),
    (_kw(['hidratante', 'cotonete']), 'Pessoal'),
    (_rx(r'papel higi[eê]nico'), 'Pessoal'),
    (_kw(['esmalte']), 'Pessoal'),
    (_rx(r'presente m[aã]e'), 'Pessoal'),
    (_rx(r'flor.*m[aã]e'), 'Pessoal'),
    (_kw(['caneca']), 'Pessoal'),
    (_rx(r'saquinhos lembran'), 'Pessoal'),
    (_kw(['chaveiro']), 'Pessoal'),
    (_rx(r'chap[eé]u'), 'Pessoal'),
    (_kw(['brinco']), 'Pessoal'),
    (_rx(r'l[aá]pis helena'), 'Pessoal'),
    (_kw(['top carol']), 'Pessoal'),

    // Pet
    (_rx(r'ra[cç][aã]o\s*rico'), 'Pet'),
    (_kw(['sache rico', 'sachê rico']), 'Pet'),
    (_kw(['sache cachorro', 'sachê cachorro']), 'Pet'),

    // Limpeza — produtos de limpeza da casa
    (_rx(r'sab[aã]o em p[oó]'), 'Limpeza'),
    (_rx(r'sab[aã]o l[ií]quido'), 'Limpeza'),
    (_rx(r'sab[aã]o em pedra'), 'Limpeza'),
    (_rx(r'sab[aã]o lava'), 'Limpeza'),
    (_rx(r'\bsab[aã]o\b'), 'Limpeza'),
    (_kw(['finish']), 'Limpeza'),
    (_kw(['lava loucas', 'lava louças']), 'Limpeza'),
    (_kw(['amaciante', 'amaziante']), 'Limpeza'),
    (_kw(['desinfetante']), 'Limpeza'),
    (_rx(r'[aá]gua sanit'), 'Limpeza'),
    (_rx(r'[aá]lcool\b(?!.*gel)'), 'Limpeza'),
    (_kw(['limpador alcool', 'limpador álcool']), 'Limpeza'),
    (_kw(['limpa vidro', 'lustra movel', 'lustra móvel']), 'Limpeza'),
    (_kw(['desengordurante', 'multiuso']), 'Limpeza'),
    (_rx(r'\bcloros?\b'), 'Limpeza'),
    (_kw(['detergente']), 'Limpeza'),
    (_kw(['esponja']), 'Limpeza'),
    (_kw(['papel toalha']), 'Limpeza'),
    (_kw(['flanela']), 'Limpeza'),
    (_kw(['barata']), 'Limpeza'),
    (_kw(['palito mosquito']), 'Limpeza'),
    (_kw(['cabo de vassoura', 'cabo vassoura', 'vassoura']), 'Limpeza'),
    (_rx(r'\brodos?\b'), 'Limpeza'),
    (_rx(r'pano de ch[aã]o'), 'Limpeza'),
    (_rx(r'sacos? de lixo'), 'Limpeza'),

    // Casa
    (_rx(r'esp[aá]tula'), 'Casa'),
    (_kw(['bacia cozinha']), 'Casa'),
    (_kw(['lixeira']), 'Casa'),
    (_kw(['forma de gelo']), 'Casa'),
    (_kw(['vasilha']), 'Casa'),
    // Só quando o copo é o item, senão "Iogurte Nestlé Mel Copo" vira
    // utensílio de casa em vez de comida.
    (_rx(r'^copos?\b'), 'Casa'),
    (_rx(r'el[aá]sticos dinheiro'), 'Casa'),
    (_kw(['petisqueira']), 'Casa'),
    (_kw(['sacos plastico', 'sacos plástico']), 'Casa'),
    (_kw(['cola super bonder']), 'Casa'),
    (_rx(r'l[aâ]mpada'), 'Casa'),
    (_kw(['pilha']), 'Casa'),
    (_kw(['toalha de banho']), 'Casa'),
    (_kw(['plaquinha decorativa']), 'Casa'),
    (_kw(['vela dourada']), 'Casa'),
    (_rx(r'pote.*acad'), 'Casa'),
    (_rx(r'pote.*[aá]gua'), 'Casa'),
    (_kw(['pote spray']), 'Casa'),
    (_rx(r'oleo singer|óleo singer'), 'Casa'),
    (_rx(r'g[aá]s ma[cç]arico'), 'Casa'),
    (_rx(r'ma[cç]arico cul'), 'Casa'),

    // Tecnologia
    (_kw(['cabo usb']), 'Tecnologia'),
    (_kw(['cabo iphone']), 'Tecnologia'),
    (_rx(r'pel[ií]cula'), 'Tecnologia'),
    (_rx(r'v[aá]lvula.*solen'), 'Tecnologia'),

    // Papelaria / escritório
    (_kw(['papel crepom']), 'Papelaria'),
    (_kw(['banner papel']), 'Papelaria'),
    (_kw(['tela pintura']), 'Papelaria'),
    (_kw(['tecido quadriculado']), 'Papelaria'),

    // Veiculos / carro e moto (whole words only — bare substrings
    // misfire: "carro" is inside "macarronada")
    (_rx(r'\bcarros?\b|\bmotos?\b'), 'Veiculos'),
    (_rx(r'\bpneus?\b|\bfor[cç]as?\b'), 'Veiculos'),

    // Lazer, beleza e brinquedos (whole words where needed — "entrada"
    // is inside "concentrada", "uva" inside "luvas")
    (_rx(r'\bingressos?\b|\bentradas?\b|\btickets?\b'), lazer),
    (_kw(['circo', 'pula pula', 'rodeio', 'vaquejada', 'cachoeira']),
        lazer),
    (_rx(r'\bparques?\b'), lazer),
    (_kw(['festival do milho', 'festival milho']), lazer),
    (_rx(r'baix[aã]o encantado'), lazer),
    (_rx(r'trilogia|triologia'), lazer),
    (_rx(r'jo[aã]o bobo'), lazer),
    (_kw(['brinquedo']), lazer),
    (_rx(r'c[ií]lios'), lazer),
    (_rx(r'\bunhas?\b'), lazer),
    (_kw(['expoagra', 'bob goodies', 'shopee', 'adega']), lazer),
    (_rx(r'\bbolsas?\b'), lazer),
    (_kw(['garrafa', 'banquinho']), lazer),
    (_rx(r'\buno\b'), lazer),
    (_rx(r'\bfestas?\b|anivers'), lazer),
    (_kw(['restaurante']), lazer),
    (_rx(r'almo[cç]o'), lazer),

    // Jardim / sementes
    (_kw(['semente']), 'Casa'),
    (_kw(['sementes']), 'Casa'),

    // Comida — exceções que precisam vencer o bloco de junk abaixo:
    // guaraná em pó é suplemento (não refrigerante) e "batata doce" /
    // "páprica doce" não são doces.
    (_rx(r'guaran[aá] maca'), 'Comida'),
    (_rx(r'batata doce|p[aá]prica'), 'Comida'),

    // Dieta de Engorda — ultraprocessados, doces, frituras,
    // refrigerantes, salgados e laticínios industrializados. Vem antes
    // de Frutas e Comida: "Monster laranja" é refrigerante, não fruta.
    (_kw(['pizza', 'pastel', 'coxinha', 'salgadinho', 'canudinho']),
        junk),
    (_rx(r'\bsalgados?\b'), junk),
    (_kw(['espetinho', 'churros', 'pipoca', 'miojo']), junk),
    (_kw(['cachorro quente', 'cachorros quentes', 'cachorrinho']), junk),
    (_rx(r'hamb[uú]rgu?er'), junk),
    (_rx(r'\bfrit'), junk), // frita, fritas, fritar, batata frita
    (_kw(['batata palha', 'batata palito', 'batata crony']), junk),
    (_rx(r'a[cç]a[ií]'), junk),
    (_kw(['sorvete', 'picolé', 'picole', 'milk shake', 'milkshake']),
        junk),
    (_kw(['trufado', 'nutella', 'chocolate', 'granulado']), junk),
    (_kw(['bombom', 'bombinha', 'jujuba', 'jellybean', 'mentos',
      'trident']), junk),
    (_rx(r'\bbalas?\b'), junk),
    (_kw(['pacoquita']), junk),
    (_rx(r'pa[cç]oca'), junk),
    (_kw(['gelatina', 'chantilly', 'confeitado']), junk),
    (_rx(r'\bdoces?\b'), junk),
    (_rx(r'\bbolos?\b|bolinho'), junk),
    (_kw(['biscoito', 'bauducco', 'amori', 'maizena', 'passatempo',
      'nikito', 'stuks', 'ruffles', 'barra de cereal']), junk),
    (_rx(r'prest[ií]gio|\bgaroto\b|bis hershey|imita[cç][aã]o m&m'),
        junk),
    (_kw(['monster', 'energetico', 'energético', 'latinha']), junk),
    (_rx(r'guaran[aá]'), junk),
    (_rx(r'\brefri'), junk), // refri, refrigerante
    (_kw(['sprite', 'pepsi', 'sukita', 'schweppes', 'pringle', 'finni']),
        junk),
    (_kw(['coca zero', 'coca-cola', 'coca cola']), junk),
    (_kw(['suco', 'capuccino', 'cappuccino']), junk),
    (_rx(r'a[cç][uú]car'), junk),
    (_rx(r'p[aã][oe]s? de queijo'), junk),
    (_kw(['queijo', 'mussarela', 'ricota']), junk),
    (_rx(r'requeij[aã]o'), junk),
    (_kw(['presunto', 'mortadela', 'bacon', 'margarina']), junk),
    (_rx(r'lingu?[ií][cç]a|linugica'), junk),
    (_rx(r'leite condensa|leite ferment'), junk),
    (_rx(r'mistura l[aá]ctea|farinha l[aá]ctea'), junk),
    (_kw(['nescau', 'mucilon', 'neston', 'danone', 'chamyto']), junk),
    (_kw(['iogurte']), junk),
    (_rx(r'\bjesus\b'), junk),

    // Frutas
    (_rx(r'\bma[cç][aã]s?\b(?!\s*peru)'), 'Frutas'),
    (_rx(r'\buvas?\b'), 'Frutas'),
    (_rx(r'\bperas?\b'), 'Frutas'),
    (_rx(r'lim[oõ]'), 'Frutas'),
    (_kw(['banana', 'melancia', 'abacaxi', 'ameixa', 'morango']),
        'Frutas'),
    (_rx(r'mam[aã]o|\bmangas?\b|\bmel[aã]o\b'), 'Frutas'),
    (_kw(['laranja', 'goiaba', 'tangerina', 'mexerica', 'acerola',
      'graviola', 'abacate', 'kiwi', 'jabuticaba']), 'Frutas'),
    (_rx(r'maracuj|p[eê]ssego|\bcaj[au]s?\b|\bfigos?\b'), 'Frutas'),
    (_kw(['polpa']), 'Frutas'),

    // Comida — fast food / restaurante
    (_kw(['x tudo']), 'Comida'),
    (_kw(['macarronada casa']), 'Comida'),
    (_kw(['padaria']), 'Comida'),

    // Comida — suplementos
    (_rx(r'whey\s*sach'), 'Comida'),
    (_kw(['creatina']), 'Comida'),
    (_rx(r'vitamina az|vitamina omega'), 'Comida'),
    (_kw(['whey piracanjuba']), 'Comida'),
    (_kw(['mix sementes']), 'Comida'),

    // Comida — bebidas
    (_rx(r'[aá]gua mineral'), 'Comida'),
    (_rx(r'[aá]gua c[/ ]g[aá]s'), 'Comida'),
    (_rx(r'^[aá]gua\s'), 'Comida'),
    (_rx(r'ch[aá] de camomila'), 'Comida'),
    (_kw(['vinho']), 'Comida'),
    (_kw(['leite de coco']), 'Comida'),

    // Comida — carnes
    (_kw(['peito de frango']), 'Comida'),
    (_kw(['carne moida', 'carne moída']), 'Comida'),
    (_kw(['carne patinho']), 'Comida'),
    (_kw(['peito de peru']), 'Comida'),
    (_rx(r'camar[aã]o'), 'Comida'),
    (_kw(['peixe', 'merluza']), 'Comida'),
    (_rx(r'pat[eê] de atum'), 'Comida'),

    // Comida — padaria / pães
    (_rx(r'p[aã]o de forma'), 'Comida'),
    (_rx(r'p[aã]o.*hot\s*dog'), 'Comida'),
    (_rx(r'p[aã]o\b|p[aã]es|dois p[aã]es'), 'Comida'),

    // Comida — laticínios
    (_kw(['creme de leite']), 'Comida'),
    (_kw(['creame de leite']), 'Comida'),
    (_rx(r'leite em p[oó]'), 'Comida'),
    (_rx(r'leite\s+(1l|piracanjuba|ccgl|integral|\d)'), 'Comida'),
    (_rx(r'^leite\s*$'), 'Comida'),
    (_kw(['leite']), 'Comida'),

    // Comida — ovos
    (_kw(['ovo', 'ovos', 'cartela de ovo', 'meia cartela']), 'Comida'),
    (_kw(['tapioca']), 'Comida'),

    // Comida — legumes e verduras
    (_kw(['tomate']), 'Comida'),
    (_rx(r'piment[aãoõ]'), 'Comida'),
    (_kw(['cenoura']), 'Comida'),
    (_kw(['cebola']), 'Comida'),
    (_kw(['repolho']), 'Comida'),
    (_kw(['alface']), 'Comida'),
    (_kw(['maxixe']), 'Comida'),
    (_kw(['batata inglesa']), 'Comida'),
    (_rx(r'cabe[cç]a de alho'), 'Comida'),
    (_kw(['alho']), 'Comida'),

    // Comida — grãos / cereais
    (_kw(['arroz']), 'Comida'),
    (_rx(r'feij[aã]o'), 'Comida'),
    (_rx(r'macarr[aã]o'), 'Comida'),
    (_kw(['farinha de trigo']), 'Comida'),
    (_rx(r'floc[aã]o'), 'Comida'),
    (_kw(['aveia']), 'Comida'),
    (_kw(['milho verde']), 'Comida'),
    (_kw(['cuscuz']), 'Comida'),
    (_kw(['massa tapioca']), 'Comida'),

    // Comida — condimentos / temperos
    (_kw(['maionese']), 'Comida'),
    (_kw(['ketchup']), 'Comida'),
    (_kw(['molho de tomate', 'molho tomate']), 'Comida'),
    (_kw(['extrato de tomate']), 'Comida'),
    (_kw(['molho shoyu']), 'Comida'),
    (_kw(['tempero']), 'Comida'),
    (_rx(r'a[cç]afr[aã]o'), 'Comida'),
    (_rx(r'p[aá]prica'), 'Comida'),
    (_kw(['chimichurri']), 'Comida'),
    (_kw(['vinagre']), 'Comida'),
    (_kw(['farofa']), 'Comida'),
    (_kw(['corante']), 'Comida'),
    (_kw(['sazon']), 'Comida'),
    (_rx(r'sele[cç][aã]o churrasco'), 'Comida'),
    (_kw(['bicarbonato']), 'Comida'),
    (_kw(['sal ']), 'Comida'),
    (_kw(['super liga neutra']), 'Comida'),
    (_kw(['mel']), 'Comida'),

    // Comida — óleos
    (_kw(['azeite de oliva', 'azeite oliva']), 'Comida'),
    (_rx(r'[oó]leo de soja'), 'Comida'),

    // Comida — diversos
    (_kw(['castanha']), 'Comida'),
    (_kw(['farinha']), 'Comida'),
    (_rx(r'ra[cç][aã]o\b(?!\s*rico)'), 'Pet'),
  ];

  /// Store-based overrides for items without good keyword matches.
  static const _storeHints = <String, String>{
    'plastilandia': 'Casa',
    'larissa construc': 'Construcao',
    'goncalves': 'Construcao',
    'gonçalves': 'Construcao',
    'torres': 'Construcao',
  };

  /// Exact item matches for tricky items.
  static const _exactMatches = <String, String>{
    '?': 'Outros',
    'pix carol': 'Servicos',
    'tatu': lazer,
    'patinho 498g': 'Comida',
  };
}

typedef _Matcher = bool Function(String item, String store);
