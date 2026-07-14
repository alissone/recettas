/// Rule-based auto-categorization of purchases, ported 1:1 from the
/// desktop categorizer (Projetos/Gastos/categorizar.py): item-name
/// normalization, ordered keyword/regex rules (first match wins), an
/// accent-stripped second pass, then store hints. Only the category is
/// kept — subcategoria/saudável/tipo need columns the app doesn't have.
///
/// Unlike the Python pipeline, an item no rule recognizes returns null
/// (instead of 'Outros') so it stays visible as "sem categoria" for
/// manual review.
class PurchaseCategorizer {
  PurchaseCategorizer._();

  /// Default colors when auto-creating a missing category
  /// (same as CAT_COLORS in generate.py).
  static const categoryColors = <String, int>{
    'Comida': 0xFF10B981,
    'Casa': 0xFFF59E0B,
    'Construcao': 0xFF06B6D4,
    'Saude': 0xFF3B82F6,
    'Veiculos': 0xFFEF4444,
    'Servicos': 0xFF6366F1,
    'Pessoal': 0xFFA855F7,
    'Lazer': 0xFFEC4899,
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

  /// Accent-insensitive lowercase key, for matching rule category names
  /// against existing user categories (e.g. "Alimentação" ≡ "Comida").
  static String nameKey(String name) => _stripAccents(_normalize(name));

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

  /// Checked in order, first match wins.
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

    // Veículos
    (_kw(['gasolina']), 'Veiculos'),
    (_rx(r'c[aâ]mara.*moto'), 'Veiculos'),
    (_kw(['corrente da moto', 'corrente moto']), 'Veiculos'),
    (_kw(['pedaleira moto']), 'Veiculos'),
    (_kw(['camera de re', 'câmera de ré']), 'Veiculos'),
    (_kw(['tinta preto fosco']), 'Veiculos'),

    // Construção / encanamento
    (_kw(["caixa d'agua", "caixa d'água", 'caixa dagua']), 'Construcao'),
    (_rx(r'conex[oõ]'), 'Construcao'),
    (_rx(r'encana[cç][aã]o'), 'Construcao'),
    (_kw(['vara de cano', 'vara cano']), 'Construcao'),
    (_kw(['cola de cano']), 'Construcao'),
    (_kw(['fita veda rosca']), 'Construcao'),
    (_rx(r'luva.*mm'), 'Construcao'),
    (_kw(['luva lr']), 'Construcao'),
    (_kw(['registro escrit']), 'Construcao'),
    (_rx(r'joelho.*rosca'), 'Construcao'),
    (_rx(r'\d+\s*curva'), 'Construcao'),
    (_kw(['exaustor']), 'Construcao'),
    (_kw(['tomada']), 'Construcao'),
    (_kw(['serra copo']), 'Construcao'),
    (_kw(['coluna 8mm']), 'Construcao'),
    (_rx(r'lixa.*parede'), 'Construcao'),
    (_kw(['irrigador']), 'Construcao'),
    (_kw(['suporte de prateleira', 'suporte prateleira']), 'Construcao'),
    (_kw(['painel de led']), 'Construcao'),
    (_kw(['disco de corte']), 'Construcao'),
    (_kw(['talhadeira']), 'Construcao'),
    (_kw(['chave 10']), 'Construcao'),
    (_kw(['nylon ro']), 'Construcao'),

    // Farmácia / saúde
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

    // Higiene pessoal
    (_kw(['creme dental']), 'Pessoal'),
    (_kw(['enxaguante']), 'Pessoal'),
    (_kw(['shampoo']), 'Pessoal'),
    (_kw(['sabonete']), 'Pessoal'),
    (_kw(['esmalte']), 'Pessoal'),
    (_rx(r'c[ií]lios'), 'Pessoal'),

    // Pet
    (_rx(r'ra[cç][aã]o\s*rico'), 'Pet'),
    (_kw(['sache rico', 'sachê rico']), 'Pet'),
    (_kw(['sache cachorro', 'sachê cachorro']), 'Pet'),

    // Casa / limpeza
    (_rx(r'sab[aã]o em p[oó]'), 'Casa'),
    (_rx(r'sab[aã]o l[ií]quido'), 'Casa'),
    (_rx(r'sab[aã]o em pedra'), 'Casa'),
    (_rx(r'sab[aã]o lava'), 'Casa'),
    (_kw(['finish']), 'Casa'),
    (_kw(['lava loucas', 'lava louças']), 'Casa'),
    (_kw(['amaciante', 'amaziante']), 'Casa'),
    (_kw(['desinfetante']), 'Casa'),
    (_rx(r'[aá]gua sanit'), 'Casa'),
    (_rx(r'[aá]lcool\b(?!.*gel)'), 'Casa'),
    (_kw(['limpador alcool', 'limpador álcool']), 'Casa'),
    (_kw(['detergente']), 'Casa'),
    (_kw(['esponja']), 'Casa'),
    (_rx(r'papel higi[eê]nico'), 'Casa'),
    (_kw(['papel toalha']), 'Casa'),
    (_kw(['flanela']), 'Casa'),
    (_kw(['barata']), 'Casa'),
    (_kw(['palito mosquito']), 'Casa'),
    (_kw(['cabo de vassoura', 'cabo vassoura']), 'Casa'),
    (_rx(r'esp[aá]tula'), 'Casa'),
    (_kw(['bacia cozinha']), 'Casa'),
    (_kw(['lixeira']), 'Casa'),
    (_kw(['forma de gelo']), 'Casa'),
    (_kw(['vasilha']), 'Casa'),
    (_kw(['copo']), 'Casa'),
    (_rx(r'el[aá]sticos dinheiro'), 'Casa'),
    (_kw(['petisqueira']), 'Casa'),
    (_kw(['sacos plastico', 'sacos plástico']), 'Casa'),
    (_kw(['cola super bonder']), 'Casa'),
    (_rx(r'l[aâ]mpada'), 'Casa'),
    (_kw(['pilha']), 'Casa'),
    (_kw(['suporte tv']), 'Casa'),
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

    // Pessoal / presentes
    (_rx(r'presente m[aã]e'), 'Pessoal'),
    (_rx(r'flor.*m[aã]e'), 'Pessoal'),
    (_kw(['caneca', '2 canecas']), 'Pessoal'),
    (_rx(r'saquinhos lembran'), 'Pessoal'),
    (_kw(['chaveiro']), 'Pessoal'),
    (_rx(r'chap[eé]u'), 'Pessoal'),
    (_kw(['brinco']), 'Pessoal'),
    (_rx(r'l[aá]pis helena'), 'Pessoal'),
    (_kw(['top carol']), 'Pessoal'),
    (_rx(r'trilogia|triologia'), 'Lazer'),
    (_rx(r'jo[aã]o bobo'), 'Lazer'),

    // Lazer / entretenimento (whole words — "entrada" is inside
    // "concentrada")
    (_rx(r'\bingressos?\b|\bentradas?\b'), 'Lazer'),
    (_kw(['circo']), 'Lazer'),
    (_kw(['pula pula']), 'Lazer'),
    (_kw(['festival do milho', 'festival milho']), 'Lazer'),
    (_rx(r'baix[aã]o encantado'), 'Lazer'),
    (_kw(['tatu']), 'Lazer'),

    // Jardim / sementes
    (_kw(['semente']), 'Casa'),
    (_kw(['sementes']), 'Casa'),

    // Alimentação — fast food / restaurante
    (_kw(['pizza']), 'Comida'),
    (_kw(['x tudo']), 'Comida'),
    (_rx(r'hamb[uú]rguer canoeiro'), 'Comida'),
    (_kw(['cachorro quente', 'cachorros quentes', 'cachorrinho']),
        'Comida'),
    (_kw(['coxinha']), 'Comida'),
    (_rx(r'\bsalgados?\b'), 'Comida'),
    (_kw(['espetinho']), 'Comida'),
    (_rx(r'almo[cç]o'), 'Comida'),
    (_kw(['macarronada casa']), 'Comida'),
    (_kw(['padaria']), 'Comida'),
    (_rx(r'batata frita com'), 'Comida'),
    (_rx(r'a[cç]a[ií]'), 'Comida'),
    (_kw(['sorvete', 'picolé', 'picole']), 'Comida'),
    (_rx(r'trufado.*nutella'), 'Comida'),

    // Alimentação — suplementos
    (_rx(r'whey\s*sach'), 'Comida'),
    (_kw(['creatina']), 'Comida'),
    (_rx(r'vitamina az|vitamina omega'), 'Comida'),
    (_rx(r'guaran[aá] maca'), 'Comida'),
    (_kw(['whey piracanjuba']), 'Comida'),
    (_kw(['mix sementes']), 'Comida'),

    // Alimentação — bebidas
    (_kw(['monster']), 'Comida'),
    (_kw(['energetico', 'energético']), 'Comida'),
    (_rx(r'guaran[aá](?!.*maca)'), 'Comida'),
    (_kw(['refrigerante', 'refri ']), 'Comida'),
    (_kw(['sprite']), 'Comida'),
    (_kw(['coca zero', 'coca-cola', 'coca cola']), 'Comida'),
    (_kw(['sukita']), 'Comida'),
    (_kw(['pepsi']), 'Comida'),
    (_kw(['schweppes']), 'Comida'),
    (_rx(r'guaran[aá] jesus'), 'Comida'),
    (_rx(r'[aá]gua mineral'), 'Comida'),
    (_rx(r'[aá]gua c[/ ]g[aá]s'), 'Comida'),
    (_rx(r'^[aá]gua\s'), 'Comida'),
    (_kw(['suco']), 'Comida'),
    (_kw(['polpa de caj', 'polpa caj']), 'Comida'),
    (_kw(['capuccino', 'cappuccino']), 'Comida'),
    (_rx(r'ch[aá] de camomila'), 'Comida'),
    (_kw(['vinho']), 'Comida'),
    (_kw(['leite de coco']), 'Comida'),

    // Alimentação — doces / guloseimas
    (_kw(['nutella']), 'Comida'),
    (_kw(['bis hershey']), 'Comida'),
    (_kw(['bombom']), 'Comida'),
    (_kw(['chocolate']), 'Comida'),
    (_kw(['chocolate granulado']), 'Comida'),
    (_kw(['barra de chocolate']), 'Comida'),
    (_kw(['doce de leite']), 'Comida'),
    (_kw(['leite condensado', 'leite condensaso']), 'Comida'),
    (_kw(['gelatina']), 'Comida'),
    (_kw(['chantilly']), 'Comida'),
    (_rx(r'massa.*bolo'), 'Comida'),
    (_rx(r'prest[ií]gio recheado'), 'Comida'),

    // Alimentação — snacks
    (_kw(['jujuba']), 'Comida'),
    (_kw(['jellybean']), 'Comida'),
    (_kw(['mentos']), 'Comida'),
    (_kw(['trident']), 'Comida'),
    (_kw(['bala']), 'Comida'),
    (_kw(['pacoquita']), 'Comida'),
    (_rx(r'imita[cç][aã]o m&m'), 'Comida'),
    (_kw(['salgadinho']), 'Comida'),
    (_kw(['ruffles']), 'Comida'),
    (_kw(['batata palha']), 'Comida'),
    (_kw(['batata frita']), 'Comida'),
    (_kw(['batata palito']), 'Comida'),
    (_kw(['batata crony']), 'Comida'),
    (_kw(['biscoito recheado']), 'Comida'),
    (_rx(r'biscoito.*passatempo'), 'Comida'),
    (_kw(['bolinho bauducco']), 'Comida'),
    (_kw(['barra de cereal']), 'Comida'),
    (_kw(['stuks']), 'Comida'),
    (_kw(['nikito']), 'Comida'),
    (_kw(['amendoim confeitado']), 'Comida'),
    (_kw(['doce palitos']), 'Comida'),
    (_kw(['bombinha']), 'Lazer'),

    // Alimentação — biscoitos / cereais
    (_kw(['biscoito maizena']), 'Comida'),
    (_kw(['biscoito amori']), 'Comida'),

    // Alimentação — frutas e verduras
    (_rx(r'lim[oõ]'), 'Comida'),
    (_kw(['tomate']), 'Comida'),
    (_kw(['banana']), 'Comida'),
    (_rx(r'piment[aãoõ]'), 'Comida'),
    (_kw(['cenoura']), 'Comida'),
    (_kw(['cebola']), 'Comida'),
    (_kw(['repolho']), 'Comida'),
    (_kw(['alface']), 'Comida'),
    (_kw(['melancia']), 'Comida'),
    (_kw(['maxixe']), 'Comida'),
    (_rx(r'ma[cç][aã](?!\s*peru)'), 'Comida'),
    (_kw(['pera']), 'Comida'),
    (_kw(['ameixa']), 'Comida'),
    (_kw(['abacaxi']), 'Comida'),
    (_kw(['batata inglesa']), 'Comida'),
    (_rx(r'cabe[cç]a de alho'), 'Comida'),
    (_kw(['alho']), 'Comida'),

    // Alimentação — carnes
    (_kw(['peito de frango']), 'Comida'),
    (_kw(['carne moida', 'carne moída']), 'Comida'),
    (_kw(['carne patinho']), 'Comida'),
    (_rx(r'lingu[ií][cç]a\s+frango'), 'Comida'),
    (_rx(r'lingu?[ií][cç]a|linugica'), 'Comida'),
    (_kw(['presunto']), 'Comida'),
    (_kw(['peito de peru']), 'Comida'),
    (_kw(['bacon']), 'Comida'),
    (_rx(r'carne hamb[uú]rguer'), 'Comida'),
    (_rx(r'camar[aã]o'), 'Comida'),
    (_kw(['peixe', 'merluza']), 'Comida'),
    (_rx(r'pat[eê] de atum'), 'Comida'),

    // Alimentação — padaria / pães (before laticínios — "pão de
    // queijo" contains "queijo")
    (_rx(r'p[aã]o de forma'), 'Comida'),
    (_rx(r'p[aã]o de queijo'), 'Comida'),
    (_rx(r'p[aã]o.*hamb'), 'Comida'),
    (_rx(r'p[aã]o.*hot\s*dog'), 'Comida'),
    (_rx(r'p[aã]o\b|p[aã]es|dois p[aã]es'), 'Comida'),

    // Alimentação — laticínios (queijo mussarela before generic queijo)
    (_kw(['queijo mussarela']), 'Comida'),
    (_rx(r'mussarela'), 'Comida'),
    (_rx(r'requeij[aã]o'), 'Comida'),
    (_kw(['creme de ricota']), 'Comida'),
    (_rx(r'queijo'), 'Comida'),
    (_rx(r'leite ferment'), 'Comida'),
    (_rx(r'mistura l[aá]ctea'), 'Comida'),
    (_rx(r'iogurte natural'), 'Comida'),
    (_rx(r'iogurte'), 'Comida'),
    (_kw(['danone']), 'Comida'),
    (_kw(['chamyto']), 'Comida'),
    (_kw(['creme de leite']), 'Comida'),
    (_kw(['creame de leite']), 'Comida'),
    (_kw(['margarina']), 'Comida'),
    (_kw(['neston']), 'Comida'),
    (_rx(r'leite em p[oó]'), 'Comida'),
    (_rx(r'leite\s+(1l|piracanjuba|ccgl|integral|\d)'), 'Comida'),
    (_rx(r'^leite\s*$'), 'Comida'),
    (_kw(['farinha lactea', 'farinha láctea']), 'Comida'),
    (_kw(['leite']), 'Comida'),

    // Alimentação — ovos
    (_kw(['ovo', 'ovos', 'cartela de ovo', 'meia cartela']),
        'Comida'),
    (_kw(['bolo']), 'Comida'),
    (_rx(r'peda[cç]o.*bolo'), 'Comida'),
    (_kw(['tapioca']), 'Comida'),

    // Alimentação — grãos / cereais
    (_kw(['arroz']), 'Comida'),
    (_rx(r'feij[aã]o'), 'Comida'),
    (_rx(r'macarr[aã]o'), 'Comida'),
    (_kw(['miojo']), 'Comida'),
    (_kw(['farinha de trigo']), 'Comida'),
    (_rx(r'floc[aã]o'), 'Comida'),
    (_kw(['aveia']), 'Comida'),
    (_kw(['milho verde']), 'Comida'),
    (_kw(['cuscuz']), 'Comida'),
    (_kw(['massa tapioca']), 'Comida'),

    // Alimentação — condimentos / temperos
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
    (_rx(r'a[cç][uú]car'), 'Comida'),
    (_kw(['bicarbonato']), 'Comida'),
    (_kw(['sal ']), 'Comida'),
    (_kw(['super liga neutra']), 'Comida'),
    (_kw(['mel']), 'Comida'),

    // Alimentação — óleos
    (_kw(['azeite de oliva', 'azeite oliva']), 'Comida'),
    (_rx(r'[oó]leo de soja'), 'Comida'),

    // Alimentação — diversos
    (_kw(['castanha']), 'Comida'),
    (_kw(['farinha']), 'Comida'),
    (_rx(r'ra[cç][aã]o\b(?!\s*rico)'), 'Pet'),

    // Alimentação — polpa de frutas
    (_kw(['polpa']), 'Comida'),

    // Alimentação — catch-all
    (_kw(['sorvete']), 'Comida'),
    (_rx(r'biscoito'), 'Comida'),
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
    'tatu': 'Lazer',
    'patinho 498g': 'Comida',
  };
}

typedef _Matcher = bool Function(String item, String store);
