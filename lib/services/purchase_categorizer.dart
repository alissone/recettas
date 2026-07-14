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
    'Alimentacao': 0xFF10B981,
    'Casa': 0xFFF59E0B,
    'Construcao': 0xFF06B6D4,
    'Farmacia': 0xFF3B82F6,
    'Veiculos': 0xFFEF4444,
    'Servicos': 0xFF6366F1,
    'Higiene': 0xFF8B5CF6,
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
  /// against existing user categories (e.g. "Alimentação" ≡ "Alimentacao").
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
    (_kw(['ritalina']), 'Farmacia'),
    (_kw(['depakene']), 'Farmacia'),
    (_kw(['neosoro']), 'Farmacia'),
    (_kw(['histamin']), 'Farmacia'),
    (_kw(['kronel']), 'Farmacia'),
    (_kw(['sepurin']), 'Farmacia'),
    (_kw(['allegra']), 'Farmacia'),
    (_kw(['predisona', 'prednisona']), 'Farmacia'),
    (_kw(['melatonina']), 'Farmacia'),
    (_rx(r'pasta d.agua'), 'Farmacia'),
    (_kw(['soro fisiol']), 'Farmacia'),
    (_kw(['seringa']), 'Farmacia'),
    (_kw(['coletor']), 'Farmacia'),
    (_rx(r'term[oô]metro'), 'Farmacia'),
    (_rx(r'm[aá]scara descart'), 'Farmacia'),
    (_kw(['luvas descart', 'pacote luvas']), 'Farmacia'),
    (_kw(['luvas gleice']), 'Farmacia'),
    (_kw(['absorvente']), 'Farmacia'),
    (_kw(['lubrificante']), 'Farmacia'),

    // Higiene pessoal
    (_kw(['creme dental']), 'Higiene'),
    (_kw(['enxaguante']), 'Higiene'),
    (_kw(['shampoo']), 'Higiene'),
    (_kw(['sabonete']), 'Higiene'),
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

    // Veiculos / carro e moto
    (_kw(['carro', 'moto']), 'Veiculos'),
    (_kw(['pneu', 'forca', 'força']), 'Veiculos'),

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

    // Lazer / entretenimento
    (_kw(['circo']), 'Lazer'),
    (_kw(['pula pula']), 'Lazer'),
    (_kw(['festival do milho', 'festival milho']), 'Lazer'),
    (_rx(r'baix[aã]o encantado'), 'Lazer'),
    (_kw(['tatu']), 'Lazer'),

    // Jardim / sementes
    (_kw(['semente']), 'Casa'),
    (_kw(['sementes']), 'Casa'),

    // Alimentação — fast food / restaurante
    (_kw(['pizza']), 'Alimentacao'),
    (_kw(['x tudo']), 'Alimentacao'),
    (_rx(r'hamb[uú]rguer canoeiro'), 'Alimentacao'),
    (_kw(['cachorro quente', 'cachorros quentes', 'cachorrinho']),
        'Alimentacao'),
    (_kw(['coxinha']), 'Alimentacao'),
    (_kw(['espetinho']), 'Alimentacao'),
    (_rx(r'almo[cç]o'), 'Alimentacao'),
    (_kw(['macarronada casa']), 'Alimentacao'),
    (_kw(['padaria']), 'Alimentacao'),
    (_rx(r'batata frita com'), 'Alimentacao'),
    (_rx(r'a[cç]a[ií]'), 'Alimentacao'),
    (_kw(['sorvete', 'picolé', 'picole']), 'Alimentacao'),
    (_rx(r'trufado.*nutella'), 'Alimentacao'),

    // Alimentação — suplementos
    (_rx(r'whey\s*sach'), 'Alimentacao'),
    (_kw(['creatina']), 'Alimentacao'),
    (_rx(r'vitamina az|vitamina omega'), 'Alimentacao'),
    (_rx(r'guaran[aá] maca'), 'Alimentacao'),
    (_kw(['whey piracanjuba']), 'Alimentacao'),
    (_kw(['mix sementes']), 'Alimentacao'),

    // Alimentação — bebidas
    (_kw(['monster']), 'Alimentacao'),
    (_kw(['energetico', 'energético']), 'Alimentacao'),
    (_rx(r'guaran[aá](?!.*maca)'), 'Alimentacao'),
    (_kw(['refrigerante', 'refri ']), 'Alimentacao'),
    (_kw(['sprite']), 'Alimentacao'),
    (_kw(['coca zero', 'coca-cola', 'coca cola']), 'Alimentacao'),
    (_kw(['sukita']), 'Alimentacao'),
    (_kw(['pepsi']), 'Alimentacao'),
    (_kw(['schweppes']), 'Alimentacao'),
    (_rx(r'guaran[aá] jesus'), 'Alimentacao'),
    (_rx(r'[aá]gua mineral'), 'Alimentacao'),
    (_rx(r'[aá]gua c[/ ]g[aá]s'), 'Alimentacao'),
    (_rx(r'^[aá]gua\s'), 'Alimentacao'),
    (_kw(['suco']), 'Alimentacao'),
    (_kw(['polpa de caj', 'polpa caj']), 'Alimentacao'),
    (_kw(['capuccino', 'cappuccino']), 'Alimentacao'),
    (_rx(r'ch[aá] de camomila'), 'Alimentacao'),
    (_kw(['vinho']), 'Alimentacao'),
    (_kw(['leite de coco']), 'Alimentacao'),

    // Alimentação — doces / guloseimas
    (_kw(['nutella']), 'Alimentacao'),
    (_kw(['bis hershey']), 'Alimentacao'),
    (_kw(['bombom']), 'Alimentacao'),
    (_kw(['chocolate']), 'Alimentacao'),
    (_kw(['chocolate granulado']), 'Alimentacao'),
    (_kw(['barra de chocolate']), 'Alimentacao'),
    (_kw(['doce de leite']), 'Alimentacao'),
    (_kw(['leite condensado', 'leite condensaso']), 'Alimentacao'),
    (_kw(['gelatina']), 'Alimentacao'),
    (_kw(['chantilly']), 'Alimentacao'),
    (_rx(r'massa.*bolo'), 'Alimentacao'),
    (_rx(r'prest[ií]gio recheado'), 'Alimentacao'),

    // Alimentação — snacks
    (_kw(['jujuba']), 'Alimentacao'),
    (_kw(['jellybean']), 'Alimentacao'),
    (_kw(['mentos']), 'Alimentacao'),
    (_kw(['trident']), 'Alimentacao'),
    (_kw(['bala']), 'Alimentacao'),
    (_kw(['pacoquita']), 'Alimentacao'),
    (_rx(r'imita[cç][aã]o m&m'), 'Alimentacao'),
    (_kw(['salgadinho']), 'Alimentacao'),
    (_kw(['ruffles']), 'Alimentacao'),
    (_kw(['batata palha']), 'Alimentacao'),
    (_kw(['batata frita']), 'Alimentacao'),
    (_kw(['batata palito']), 'Alimentacao'),
    (_kw(['batata crony']), 'Alimentacao'),
    (_kw(['biscoito recheado']), 'Alimentacao'),
    (_rx(r'biscoito.*passatempo'), 'Alimentacao'),
    (_kw(['bolinho bauducco']), 'Alimentacao'),
    (_kw(['barra de cereal']), 'Alimentacao'),
    (_kw(['stuks']), 'Alimentacao'),
    (_kw(['nikito']), 'Alimentacao'),
    (_kw(['amendoim confeitado']), 'Alimentacao'),
    (_kw(['doce palitos']), 'Alimentacao'),
    (_kw(['bombinha']), 'Lazer'),

    // Alimentação — biscoitos / cereais
    (_kw(['biscoito maizena']), 'Alimentacao'),
    (_kw(['biscoito amori']), 'Alimentacao'),

    // Alimentação — frutas e verduras
    (_rx(r'lim[oõ]'), 'Alimentacao'),
    (_kw(['tomate']), 'Alimentacao'),
    (_kw(['banana']), 'Alimentacao'),
    (_rx(r'piment[aãoõ]'), 'Alimentacao'),
    (_kw(['cenoura']), 'Alimentacao'),
    (_kw(['cebola']), 'Alimentacao'),
    (_kw(['repolho']), 'Alimentacao'),
    (_kw(['alface']), 'Alimentacao'),
    (_kw(['melancia']), 'Alimentacao'),
    (_kw(['maxixe']), 'Alimentacao'),
    (_rx(r'ma[cç][aã](?!\s*peru)'), 'Alimentacao'),
    (_kw(['pera']), 'Alimentacao'),
    (_kw(['ameixa']), 'Alimentacao'),
    (_kw(['abacaxi']), 'Alimentacao'),
    (_kw(['batata inglesa']), 'Alimentacao'),
    (_rx(r'cabe[cç]a de alho'), 'Alimentacao'),
    (_kw(['alho']), 'Alimentacao'),

    // Alimentação — carnes
    (_kw(['peito de frango']), 'Alimentacao'),
    (_kw(['carne moida', 'carne moída']), 'Alimentacao'),
    (_kw(['carne patinho']), 'Alimentacao'),
    (_rx(r'lingu[ií][cç]a\s+frango'), 'Alimentacao'),
    (_rx(r'lingu?[ií][cç]a|linugica'), 'Alimentacao'),
    (_kw(['presunto']), 'Alimentacao'),
    (_kw(['peito de peru']), 'Alimentacao'),
    (_kw(['bacon']), 'Alimentacao'),
    (_rx(r'carne hamb[uú]rguer'), 'Alimentacao'),
    (_rx(r'camar[aã]o'), 'Alimentacao'),
    (_kw(['peixe', 'merluza']), 'Alimentacao'),
    (_rx(r'pat[eê] de atum'), 'Alimentacao'),

    // Alimentação — padaria / pães (before laticínios — "pão de
    // queijo" contains "queijo")
    (_rx(r'p[aã]o de forma'), 'Alimentacao'),
    (_rx(r'p[aã]o de queijo'), 'Alimentacao'),
    (_rx(r'p[aã]o.*hamb'), 'Alimentacao'),
    (_rx(r'p[aã]o.*hot\s*dog'), 'Alimentacao'),
    (_rx(r'p[aã]o\b|p[aã]es|dois p[aã]es'), 'Alimentacao'),

    // Alimentação — laticínios (queijo mussarela before generic queijo)
    (_kw(['queijo mussarela']), 'Alimentacao'),
    (_rx(r'mussarela'), 'Alimentacao'),
    (_rx(r'requeij[aã]o'), 'Alimentacao'),
    (_kw(['creme de ricota']), 'Alimentacao'),
    (_rx(r'queijo'), 'Alimentacao'),
    (_rx(r'leite ferment'), 'Alimentacao'),
    (_rx(r'mistura l[aá]ctea'), 'Alimentacao'),
    (_rx(r'iogurte natural'), 'Alimentacao'),
    (_rx(r'iogurte'), 'Alimentacao'),
    (_kw(['danone']), 'Alimentacao'),
    (_kw(['chamyto']), 'Alimentacao'),
    (_kw(['creme de leite']), 'Alimentacao'),
    (_kw(['creame de leite']), 'Alimentacao'),
    (_kw(['margarina']), 'Alimentacao'),
    (_kw(['neston']), 'Alimentacao'),
    (_rx(r'leite em p[oó]'), 'Alimentacao'),
    (_rx(r'leite\s+(1l|piracanjuba|ccgl|integral|\d)'), 'Alimentacao'),
    (_rx(r'^leite\s*$'), 'Alimentacao'),
    (_kw(['farinha lactea', 'farinha láctea']), 'Alimentacao'),
    (_kw(['leite']), 'Alimentacao'),

    // Alimentação — ovos
    (_kw(['ovo', 'ovos', 'cartela de ovo', 'meia cartela']),
        'Alimentacao'),
    (_kw(['bolo']), 'Alimentacao'),
    (_rx(r'peda[cç]o.*bolo'), 'Alimentacao'),
    (_kw(['tapioca']), 'Alimentacao'),

    // Alimentação — grãos / cereais
    (_kw(['arroz']), 'Alimentacao'),
    (_rx(r'feij[aã]o'), 'Alimentacao'),
    (_rx(r'macarr[aã]o'), 'Alimentacao'),
    (_kw(['miojo']), 'Alimentacao'),
    (_kw(['farinha de trigo']), 'Alimentacao'),
    (_rx(r'floc[aã]o'), 'Alimentacao'),
    (_kw(['aveia']), 'Alimentacao'),
    (_kw(['milho verde']), 'Alimentacao'),
    (_kw(['cuscuz']), 'Alimentacao'),
    (_kw(['massa tapioca']), 'Alimentacao'),

    // Alimentação — condimentos / temperos
    (_kw(['maionese']), 'Alimentacao'),
    (_kw(['ketchup']), 'Alimentacao'),
    (_kw(['molho de tomate', 'molho tomate']), 'Alimentacao'),
    (_kw(['extrato de tomate']), 'Alimentacao'),
    (_kw(['molho shoyu']), 'Alimentacao'),
    (_kw(['tempero']), 'Alimentacao'),
    (_rx(r'a[cç]afr[aã]o'), 'Alimentacao'),
    (_rx(r'p[aá]prica'), 'Alimentacao'),
    (_kw(['chimichurri']), 'Alimentacao'),
    (_kw(['vinagre']), 'Alimentacao'),
    (_kw(['farofa']), 'Alimentacao'),
    (_kw(['corante']), 'Alimentacao'),
    (_kw(['sazon']), 'Alimentacao'),
    (_rx(r'sele[cç][aã]o churrasco'), 'Alimentacao'),
    (_rx(r'a[cç][uú]car'), 'Alimentacao'),
    (_kw(['bicarbonato']), 'Alimentacao'),
    (_kw(['sal ']), 'Alimentacao'),
    (_kw(['super liga neutra']), 'Alimentacao'),
    (_kw(['mel']), 'Alimentacao'),

    // Alimentação — óleos
    (_kw(['azeite de oliva', 'azeite oliva']), 'Alimentacao'),
    (_rx(r'[oó]leo de soja'), 'Alimentacao'),

    // Alimentação — diversos
    (_kw(['castanha']), 'Alimentacao'),
    (_kw(['farinha']), 'Alimentacao'),
    (_rx(r'ra[cç][aã]o\b(?!\s*rico)'), 'Pet'),

    // Alimentação — polpa de frutas
    (_kw(['polpa']), 'Alimentacao'),

    // Alimentação — catch-all
    (_kw(['sorvete']), 'Alimentacao'),
    (_rx(r'biscoito'), 'Alimentacao'),
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
    'patinho 498g': 'Alimentacao',
  };
}

typedef _Matcher = bool Function(String item, String store);
