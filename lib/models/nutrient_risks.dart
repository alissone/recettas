/// Base de alertas de deficiência/excesso por nutriente.
///
/// Cada [NutrientRisk] é identificado pelo mesmo `id` usado em NAME_TO_ID
/// (ex: 'calcium', 'vitaminA', 'ala'), então basta buscar pelo id do
/// nutriente para exibir o texto correspondente no app.
///
/// IMPORTANTE:
/// - Os textos são simplificações educativas, não diagnóstico médico.
///   Sugestão de disclaimer fixo no app: "Estes alertas são informativos e
///   não substituem orientação de um médico ou nutricionista."
/// - `excessoReferencia` descreve a dose/contexto usado nos estudos que
///   embasam o alerta de excesso, para você calibrar o threshold (ex: não
///   disparar com 110% da meta diária se o estudo usou 2000%).
/// - Quando não existe toxicidade dietética (alimentar) estabelecida para
///   aquele nutriente isolado, isso é dito explicitamente em vez de inventar
///   um número — nesses casos, considere não exibir alerta de excesso.
library nutrient_risks;

class NutrientRisk {
  /// Mesmo id usado em NAME_TO_ID (ex: 'calcium', 'vitaminA').
  final String id;

  /// Nome de exibição em pt-BR.
  final String nutrient;

  /// Texto de alerta para valores muito abaixo do normal. Null = sem
  /// quadro de deficiência clinicamente relevante por via alimentar.
  final String? deficiencia;

  /// Texto de alerta para valores muito acima do normal. Null = sem
  /// toxicidade alimentar estabelecida (não recomendado disparar alerta).
  final String? excesso;

  /// Contexto/dose usada no(s) estudo(s) que embasam `excesso`, para
  /// evitar falsos positivos com excessos leves.
  final String? excessoReferencia;

  const NutrientRisk({
    required this.id,
    required this.nutrient,
    this.deficiencia,
    this.excesso,
    this.excessoReferencia,
  });
}

final List<NutrientRisk> nutrientRisks = [
  // ==========================================================
  // PRINCIPAIS
  // ==========================================================
  NutrientRisk(
    id: 'water',
    nutrient: 'Água',
    deficiencia: 'Desidratação: fadiga, tontura, redução da função renal, '
        'confusão em casos graves.',
    excesso: 'Hiponatremia por diluição ("intoxicação hídrica"): náusea, '
        'dor de cabeça, confusão, convulsão e edema cerebral em casos '
        'extremos.',
    excessoReferencia: 'Casos documentados envolvem ingestão aguda de '
        '3-6L em poucas horas (maratonistas, hazing universitário), muito '
        'acima da ingestão diária normal de 2-3L distribuída ao longo do '
        'dia.',
  ),
  NutrientRisk(
    id: 'calories',
    nutrient: 'Valor energético (kcal)',
    deficiencia: 'Déficit calórico crônico: perda de massa muscular, '
        'fadiga, queda de imunidade, em casos graves desnutrição '
        'proteico-calórica.',
    excesso: 'Excesso calórico crônico: ganho de peso, risco '
        'cardiometabólico aumentado a longo prazo.',
    excessoReferencia: 'Efeitos relevantes de excesso calórico dependem de '
        'manutenção do superávit por semanas/meses, não de um único dia '
        'acima da meta.',
  ),
  NutrientRisk(
    id: 'protein',
    nutrient: 'Proteína',
    deficiencia: 'Perda de massa muscular, cicatrização lenta, edema, '
        'queda de imunidade; em casos extremos, kwashiorkor.',
    excesso: 'Sobrecarga renal em pessoas com doença renal preexistente; '
        'em indivíduos saudáveis a evidência de dano é fraca.',
    excessoReferencia: 'Estudos de segurança avaliaram ingestões crônicas '
        'acima de 2-2,5g/kg de peso corporal/dia (2-3x a RDA de 0,8g/kg) '
        'sem dano em rins saudáveis; alertas de excesso fazem mais sentido '
        'para quem já tem função renal comprometida.',
  ),
  NutrientRisk(
    id: 'fat',
    nutrient: 'Gorduras totais',
    deficiencia: 'Deficiência de ácidos graxos essenciais: pele seca e '
        'descamativa, má absorção de vitaminas lipossolúveis.',
    excesso: 'Associado a maior risco cardiometabólico quando crônico e '
        'combinado com excesso calórico geral.',
    excessoReferencia: 'Risco relevante é de padrão alimentar sustentado '
        '(dietas com >35-40% do valor calórico total em gordura por longos '
        'períodos), não de um dia isolado acima da meta.',
  ),
  NutrientRisk(
    id: 'ash',
    nutrient: 'Cinzas (minerais totais)',
    deficiencia: null,
    excesso: null,
    excessoReferencia: 'Métrica analítica (resíduo mineral total); não tem '
        'quadro clínico próprio — use os minerais individuais.',
  ),
  NutrientRisk(
    id: 'carbohydrates',
    nutrient: 'Carboidratos',
    deficiencia: 'Fadiga, dificuldade de concentração, cetose não '
        'intencional, catabolismo muscular em restrição severa e '
        'prolongada.',
    excesso: 'Contribui para hiperglicemia e ganho de gordura quando '
        'crônico, especialmente com predomínio de açúcares livres.',
    excessoReferencia: 'Efeitos metabólicos relevantes exigem excesso '
        'calórico sustentado por semanas, não um pico isolado.',
  ),
  NutrientRisk(
    id: 'fiber',
    nutrient: 'Fibra alimentar',
    deficiencia: 'Constipação, maior risco de doença diverticular, pior '
        'controle glicêmico e lipídico a longo prazo.',
    excesso: 'Distensão abdominal, gases, cólica; pode reduzir absorção de '
        'minerais como ferro e zinco.',
    excessoReferencia: 'Efeitos gastrointestinais relatados geralmente '
        'acima de ~70g/dia (a recomendação é ~25-38g/dia), sobretudo com '
        'aumento abrupto sem hidratação adequada.',
  ),
  NutrientRisk(
    id: 'solubleFiber',
    nutrient: 'Fibra solúvel',
    deficiencia: 'Pior controle de colesterol LDL e glicemia pós-prandial.',
    excesso: 'Desconforto gastrointestinal com aumento abrupto e grande.',
    excessoReferencia: 'Sem UL numérico estabelecido; sintomas ligados a '
        'grandes aumentos súbitos (>ex. 20-30g em um único dia) sem '
        'adaptação gradual.',
  ),
  NutrientRisk(
    id: 'insolubleFiber',
    nutrient: 'Fibra insolúvel',
    deficiencia: 'Constipação e trânsito intestinal lento.',
    excesso: 'Desconforto abdominal e má absorção mineral em excesso '
        'extremo.',
    excessoReferencia: 'Mesmo raciocínio da fibra total: sintomas relevantes '
        'geralmente só acima de ~70g de fibra total/dia.',
  ),
  NutrientRisk(
    id: 'starch',
    nutrient: 'Amido',
    deficiencia: null,
    excesso: 'Contribui para hiperglicemia quando consumido em excesso '
        'crônico, especialmente amidos refinados.',
    excessoReferencia: 'Relevante apenas como parte de excesso calórico/'
        'carboidrato sustentado, sem um limiar agudo estabelecido.',
  ),
  NutrientRisk(
    id: 'sugar',
    nutrient: 'Açúcares totais',
    deficiencia: null,
    excesso: 'Associado a maior risco de cárie, resistência à insulina, '
        'esteatose hepática e ganho de peso quando crônico.',
    excessoReferencia: 'OMS recomenda <10% (idealmente <5%) das calorias '
        'diárias vindas de açúcares livres; estudos de risco metabólico '
        'geralmente usam consumo 2-3x acima desse limite por meses/anos.',
  ),
  NutrientRisk(
    id: 'addedSugar',
    nutrient: 'Açúcares adicionados',
    deficiencia: null,
    excesso: 'Mesmos riscos do açúcar total (cárie, resistência à '
        'insulina, ganho de peso), mas cumulativo com açúcares naturais.',
    excessoReferencia: 'Limite de referência AHA/OMS é <10% das calorias; '
        'estudos de dano usam ingestões crônicas 2x+ acima disso.',
  ),
  NutrientRisk(
    id: 'monosaccharides',
    nutrient: 'Monossacarídeos',
    deficiencia: null,
    excesso: null,
    excessoReferencia: 'Sem toxicidade alimentar isolada estabelecida além '
        'do já coberto por "açúcares totais".',
  ),
  NutrientRisk(
    id: 'glucose',
    nutrient: 'Glicose',
    deficiencia: 'Hipoglicemia se ingestão total de carboidrato for muito '
        'baixa: tremores, confusão, desmaio.',
    excesso: 'Pico glicêmico acentuado; risco relevante principalmente em '
        'diabéticos.',
    excessoReferencia: 'Sem UL específico para glicose isolada da dieta; '
        'tratar como parte do açúcar total.',
  ),
  NutrientRisk(
    id: 'fructose',
    nutrient: 'Frutose',
    deficiencia: null,
    excesso: 'Excesso crônico associado a esteatose hepática, aumento de '
        'triglicerídeos e resistência à insulina.',
    excessoReferencia: 'Estudos de dano hepático/metabólico geralmente '
        'usam >100g/dia de frutose (bem acima da média populacional de '
        '~15-50g/dia), muitas vezes na forma de xarope de milho.',
  ),
  NutrientRisk(
    id: 'galactose',
    nutrient: 'Galactose',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética relevante em pessoas sem '
        'galactosemia (condição genética rara de intolerância).',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'sucrose',
    nutrient: 'Sacarose',
    deficiencia: null,
    excesso: 'Mesmos riscos do açúcar total: cárie, ganho de peso, '
        'resistência à insulina.',
    excessoReferencia: 'Ver "açúcares totais" — limite de referência é '
        '<10% das calorias diárias.',
  ),
  NutrientRisk(
    id: 'lactose',
    nutrient: 'Lactose',
    deficiencia: null,
    excesso: 'Em pessoas com má absorção de lactose: gases, distensão e '
        'diarreia. Sem toxicidade em quem digere lactose normalmente.',
    excessoReferencia: 'Sintomas em intolerantes já ocorrem com 12-15g '
        '(equivalente a ~1 copo de leite); não é um limiar de toxicidade, '
        'e sim de intolerância individual.',
  ),
  NutrientRisk(
    id: 'maltose',
    nutrient: 'Maltose',
    deficiencia: null,
    excesso: null,
    excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.',
  ),

  // ==========================================================
  // MINERAIS
  // ==========================================================
  NutrientRisk(
    id: 'calcium',
    nutrient: 'Cálcio',
    deficiencia: 'Perda de densidade óssea, osteopenia/osteoporose, '
        'cãibras musculares, em crianças raquitismo (combinado a déficit '
        'de vitamina D).',
    excesso: 'Hipercalcemia: constipação, cálculos renais; possível '
        'associação com risco cardiovascular quando via suplementos.',
    excessoReferencia: 'UL do IOM é 2.000-2.500mg/dia conforme idade '
        '(RDA é ~1.000-1.200mg/dia); estudos que associaram excesso a '
        'risco cardiovascular usaram doses de suplemento de 1.000mg+ '
        'somadas à dieta, ultrapassando o UL.',
  ),
  NutrientRisk(
    id: 'iron',
    nutrient: 'Ferro',
    deficiencia: 'Anemia ferropriva: fadiga, palidez, falta de ar, unhas '
        'quebradiças.',
    excesso: 'Sobrecarga de ferro: dano hepático, diabetes, problemas '
        'cardíacos (hemocromatose); toxicidade aguda grave em crianças.',
    excessoReferencia: 'UL para adultos é 45mg/dia (RDA é 8-18mg/dia). '
        'Intoxicação aguda grave em crianças foi documentada com doses '
        'próximas de 60mg/kg de peso corporal (overdose de suplemento, '
        'não alimento).',
  ),
  NutrientRisk(
    id: 'magnesium',
    nutrient: 'Magnésio',
    deficiencia: 'Cãibras, fadiga, arritmias, em casos graves convulsões.',
    excesso: 'Diarreia, náusea; em excesso extremo (geralmente só via '
        'suplemento/medicamento) hipotensão e parada cardíaca.',
    excessoReferencia: 'UL de 350mg/dia se refere apenas a magnésio de '
        'suplementos/medicamentos (não do alimento, que não causa '
        'toxicidade); casos graves envolveram doses de laxantes/'
        'antiácidos muito acima disso.',
  ),
  NutrientRisk(
    id: 'phosphorus',
    nutrient: 'Fósforo',
    deficiencia: 'Fraqueza óssea e muscular, raro isoladamente pois é '
        'abundante em alimentos.',
    excesso: 'Pode contribuir para desmineralização óssea e calcificação '
        'vascular, principalmente com baixa ingestão de cálcio.',
    excessoReferencia: 'UL é 3.000-4.000mg/dia (RDA ~700mg/dia); efeitos '
        'ósseos relevantes vistos em consumo crônico 3-4x a RDA, '
        'tipicamente por excesso de aditivos alimentares.',
  ),
  NutrientRisk(
    id: 'potassium',
    nutrient: 'Potássio',
    deficiencia: 'Hipocalemia: fraqueza muscular, cãibras, arritmias.',
    excesso: 'Hipercalemia: arritmias cardíacas graves, principalmente em '
        'quem tem doença renal.',
    excessoReferencia: 'Em pessoas com rins saudáveis o excesso dietético '
        'é normalmente excretado; risco significativo documentado sobretudo '
        'em insuficiência renal com ingestão de 3-4x a meta diária (~4.700mg) '
        'ou uso de suplementos concentrados.',
  ),
  NutrientRisk(
    id: 'sodium',
    nutrient: 'Sódio',
    deficiencia: 'Hiponatremia: náusea, confusão, cãibras, convulsão em '
        'casos graves (geralmente ligada a perda excessiva, não à dieta '
        'baixa em sódio).',
    excesso: 'Pressão arterial elevada e maior risco cardiovascular a '
        'longo prazo.',
    excessoReferencia: 'OMS recomenda <2.000mg/dia; estudos que associam '
        'a hipertensão e risco cardiovascular geralmente comparam consumo '
        'habitual de 3.000-5.000mg/dia (o padrão de boa parte da população) '
        'contra grupos <2.000mg/dia, mantido por meses/anos.',
  ),
  NutrientRisk(
    id: 'zinc',
    nutrient: 'Zinco',
    deficiencia: 'Queda de imunidade, cicatrização lenta, perda de '
        'paladar/olfato, atraso de crescimento em crianças.',
    excesso: 'Náusea, deficiência de cobre induzida, queda de imunidade '
        'com uso crônico em excesso.',
    excessoReferencia: 'UL é 40mg/dia (RDA 8-11mg/dia); deficiência de '
        'cobre foi documentada com uso prolongado de 50-150mg/dia, muito '
        'acima do que se atinge só com alimentos.',
  ),
  NutrientRisk(
    id: 'copper',
    nutrient: 'Cobre',
    deficiencia: 'Anemia, neutropenia, problemas ósseos e neurológicos.',
    excesso: 'Náusea, dano hepático; em doença de Wilson (genética) '
        'acúmulo tóxico grave.',
    excessoReferencia: 'UL é 10mg/dia (RDA ~0,9mg/dia); toxicidade '
        'hepática relevante em pessoas sem doença de Wilson foi vista '
        'com ingestões crônicas próximas ou acima do UL, geralmente via '
        'água contaminada ou suplementos.',
  ),
  NutrientRisk(
    id: 'manganese',
    nutrient: 'Manganês',
    deficiencia: 'Rara; possível fragilidade óssea e problemas de '
        'crescimento.',
    excesso: 'Toxicidade neurológica (sintomas parecidos com Parkinson), '
        'quase sempre por exposição ocupacional/água contaminada, não '
        'dieta comum.',
    excessoReferencia: 'UL é 11mg/dia (RDA ~1,8-2,3mg/dia); os casos '
        'neurológicos documentados envolvem exposição por inalação '
        'industrial ou água com manganês muito acima dos níveis dietéticos '
        'típicos.',
  ),
  NutrientRisk(
    id: 'selenium',
    nutrient: 'Selênio',
    deficiencia: 'Doença de Keshan (cardiomiopatia), disfunção da '
        'tireoide, queda de imunidade.',
    excesso: 'Selenose: queda de cabelo, unhas quebradiças, náusea, hálito '
        'com odor de alho, neuropatia em casos graves.',
    excessoReferencia: 'UL é 400µg/dia (RDA ~55µg/dia). Um caso amplamente '
        'documentado de intoxicação em massa nos EUA envolveu um '
        'suplemento com erro de fabricação que entregava ~200x a dose '
        'rotulada (na faixa de miligramas), muito além do UL.',
  ),
  NutrientRisk(
    id: 'iodine',
    nutrient: 'Iodo',
    deficiencia: 'Bócio, hipotireoidismo, comprometimento do '
        'desenvolvimento neurológico fetal/infantil.',
    excesso: 'Pode induzir hipo ou hipertireoidismo, especialmente em '
        'quem já tem doença tireoidiana.',
    excessoReferencia: 'UL é 1.100µg/dia (RDA ~150µg/dia, 220-290µg em '
        'gestação/lactação); disfunção tireoidiana foi associada a '
        'ingestões crônicas várias vezes acima do UL, comuns em dietas '
        'muito ricas em algas marinhas.',
  ),
  NutrientRisk(
    id: 'chromium',
    nutrient: 'Cromo',
    deficiencia: 'Possível piora do controle glicêmico; deficiência '
        'isolada é rara e controversa.',
    excesso: 'Raramente tóxico pela dieta; picolinato de cromo em altas '
        'doses de suplemento foi associado a dano renal em relatos de '
        'caso.',
    excessoReferencia: 'Não há UL estabelecido para a forma dietética; os '
        'relatos de dano renal envolveram suplementos de picolinato de '
        'cromo em doses de 1.200-2.400µg/dia por meses, muito acima da '
        'ingestão adequada de ~25-35µg/dia.',
  ),
  NutrientRisk(
    id: 'molybdenum',
    nutrient: 'Molibdênio',
    deficiencia: 'Extremamente rara; associada a irritabilidade e '
        'distúrbios neurológicos em nutrição parenteral sem suplementação.',
    excesso: 'Sintomas semelhantes à gota (dores articulares) em exposição '
        'crônica muito alta.',
    excessoReferencia: 'UL é 2.000µg/dia (RDA ~45µg/dia); efeitos tipo '
        'gota descritos em populações com exposição ambiental/'
        'ocupacional de 10-15mg/dia, muito acima da dieta normal.',
  ),
  NutrientRisk(
    id: 'fluoride',
    nutrient: 'Flúor',
    deficiencia: 'Maior risco de cárie dentária.',
    excesso: 'Fluorose dentária (manchas no esmalte) em crianças; '
        'fluorose esquelética em exposição crônica muito alta.',
    excessoReferencia: 'UL é 10mg/dia para adultos (adequada ~3-4mg/dia); '
        'fluorose dentária em crianças já foi associada a ingestões '
        'consistentes acima de ~0,1mg/kg/dia durante a formação dentária, '
        'geralmente por água ou suplementos com flúor mal dosados.',
  ),
  NutrientRisk(
    id: 'chloride',
    nutrient: 'Cloreto',
    deficiencia: 'Alcalose metabólica, geralmente ligada a perdas '
        '(vômito, diuréticos) e não à dieta baixa.',
    excesso: 'Acompanha os riscos do excesso de sódio (hipertensão), pois '
        'andam juntos no sal de cozinha.',
    excessoReferencia: 'UL é 3.600mg/dia (adequada ~2.300mg/dia); '
        'tratar em conjunto com o limiar de sódio.',
  ),

  // ==========================================================
  // VITAMINAS
  // ==========================================================
  NutrientRisk(
    id: 'vitaminC',
    nutrient: 'Vitamina C',
    deficiencia: 'Escorbuto: sangramento gengival, fadiga, má cicatrização, '
        'dores articulares.',
    excesso: 'Diarreia, cólica, náusea; maior risco de cálculo renal em '
        'predispostos.',
    excessoReferencia: 'UL é 2.000mg/dia (RDA ~75-90mg/dia); sintomas '
        'gastrointestinais tipicamente relatados acima de 2-3g/dia, cerca '
        'de 25-30x a RDA, quase sempre via suplemento.',
  ),
  NutrientRisk(
    id: 'vitaminB1',
    nutrient: 'Vitamina B1 (Tiamina)',
    deficiencia: 'Beribéri, síndrome de Wernicke-Korsakoff (comum em '
        'alcoolismo crônico).',
    excesso: 'Sem toxicidade estabelecida pela dieta; sem UL definido.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'vitaminB2',
    nutrient: 'Vitamina B2 (Riboflavina)',
    deficiencia: 'Fissuras nos cantos da boca, dermatite, sensibilidade à '
        'luz.',
    excesso: 'Sem toxicidade estabelecida pela dieta; sem UL definido '
        '(baixa absorção em excesso).',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'vitaminB3',
    nutrient: 'Vitamina B3 (Niacina)',
    deficiencia: 'Pelagra: dermatite, diarreia, demência (em casos '
        'graves).',
    excesso: '"Flush" de niacina (vermelhidão e calor na pele), dano '
        'hepático em uso crônico de altas doses.',
    excessoReferencia: 'UL para forma suplementar é 35mg/dia (RDA '
        '~14-16mg/dia). O flush cutâneo já é sentido perto do UL; dano '
        'hepático foi documentado com formulações de liberação prolongada '
        'em doses de 1.000-3.000mg/dia (60-200x a RDA), usadas para '
        'tratar colesterol.',
  ),
  NutrientRisk(
    id: 'vitaminB5',
    nutrient: 'Vitamina B5 (Ácido pantotênico)',
    deficiencia: 'Rara; fadiga, irritabilidade, formigamento nas mãos/pés.',
    excesso: 'Sem toxicidade estabelecida pela dieta; sem UL definido.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'vitaminB6',
    nutrient: 'Vitamina B6',
    deficiencia: 'Anemia, dermatite, confusão, convulsões em casos graves.',
    excesso: 'Neuropatia periférica sensorial (dormência, dificuldade de '
        'andar), geralmente reversível ao parar.',
    excessoReferencia: 'UL é 100mg/dia (RDA ~1,3-1,7mg/dia); casos de '
        'neuropatia foram documentados com uso crônico de suplementos na '
        'faixa de 1.000-6.000mg/dia (centenas de vezes a RDA); há relatos '
        'também com doses menores (~100-200mg/dia) em uso prolongado por '
        'anos.',
  ),
  NutrientRisk(
    id: 'vitaminB7',
    nutrient: 'Vitamina B7 (Biotina)',
    deficiencia: 'Rara; queda de cabelo, dermatite, formigamento.',
    excesso: 'Sem toxicidade conhecida; pode interferir em exames '
        'laboratoriais de tireoide/cardíacos, gerando falsos resultados.',
    excessoReferencia: 'Sem UL definido; a preocupação principal em doses '
        'de suplemento (5-10mg/dia, dezenas de vezes a ingestão adequada) '
        'é interferência analítica em exames, não toxicidade em si.',
  ),
  NutrientRisk(
    id: 'vitaminB9',
    nutrient: 'Vitamina B9 (Folato)',
    deficiencia: 'Anemia megaloblástica; em gestação, risco de defeitos do '
        'tubo neural no bebê.',
    excesso: 'Pode mascarar deficiência de B12 (atrasando o diagnóstico de '
        'dano neurológico); possível associação com progressão de câncer '
        'preexistente.',
    excessoReferencia: 'UL de 1.000µg/dia se aplica ao ácido fólico '
        'sintético (RDA ~400µg/dia de folato); efeito de mascaramento de '
        'B12 é descrito nesse patamar do UL, geralmente atingido só via '
        'suplemento/fortificação combinados.',
  ),
  NutrientRisk(
    id: 'folicAcid',
    nutrient: 'Ácido fólico (sintético)',
    deficiencia: null,
    excesso: 'Ver "Vitamina B9 (Folato)" — mesmo UL e mesmo risco de '
        'mascarar deficiência de B12.',
    excessoReferencia: 'UL de 1.000µg/dia (forma sintética).',
  ),
  NutrientRisk(
    id: 'foodFolate',
    nutrient: 'Folato (alimento)',
    deficiencia: 'Ver "Vitamina B9 (Folato)".',
    excesso: null,
    excessoReferencia: 'Folato natural do alimento não tem toxicidade '
        'documentada; o risco de excesso é específico do ácido fólico '
        'sintético.',
  ),
  NutrientRisk(
    id: 'folateDfe',
    nutrient: 'Folato (equivalente dietético)',
    deficiencia: 'Ver "Vitamina B9 (Folato)".',
    excesso: 'Ver "Vitamina B9 (Folato)".',
    excessoReferencia: 'UL de 1.000µg DFE/dia, referente à fração '
        'sintética contida no total.',
  ),
  NutrientRisk(
    id: 'choline',
    nutrient: 'Colina',
    deficiencia: 'Acúmulo de gordura no fígado, dano muscular.',
    excesso: 'Hipotensão, sudorese, odor corporal de peixe (por '
        'trimetilamina), possível efeito em risco cardiovascular via '
        'metabólito TMAO.',
    excessoReferencia: 'UL é 3.500mg/dia (adequada ~425-550mg/dia); '
        'sintomas de excesso já relatados perto do UL, geralmente via '
        'suplementação concentrada.',
  ),
  NutrientRisk(
    id: 'betaine',
    nutrient: 'Betaína',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética relevante estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'vitaminB12',
    nutrient: 'Vitamina B12',
    deficiencia: 'Anemia megaloblástica, dano neurológico irreversível se '
        'prolongada, comum em veganos sem suplementação e idosos.',
    excesso: 'Sem toxicidade estabelecida pela dieta; sem UL definido '
        '(excesso é excretado).',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'addedVitaminB12',
    nutrient: 'Vitamina B12 (adicionada)',
    deficiencia: null,
    excesso: 'Ver "Vitamina B12" — sem toxicidade estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'vitaminA',
    nutrient: 'Vitamina A (equivalente de retinol)',
    deficiencia: 'Cegueira noturna, xeroftalmia, queda de imunidade, causa '
        'evitável comum de cegueira infantil no mundo.',
    excesso: 'Hipervitaminose A: dor de cabeça, tontura, dano hepático, '
        'fragilidade óssea; em gestantes, risco de malformação fetal.',
    excessoReferencia: 'UL é 3.000µg/dia de retinol (RDA ~700-900µg/dia). '
        'Teratogenicidade foi associada a doses acima de 10.000UI/dia '
        '(~3.000µg, próximo ao UL); toxicidade hepática crônica '
        'documentada com uso prolongado de 10x+ a RDA, frequentemente por '
        'suplementos ou excesso de fígado animal.',
  ),
  NutrientRisk(
    id: 'retinol',
    nutrient: 'Retinol',
    deficiencia: 'Ver "Vitamina A".',
    excesso: 'Ver "Vitamina A" — a forma pré-formada é a que causa '
        'hipervitaminose (betacaroteno da dieta não causa esse quadro).',
    excessoReferencia: 'UL de 3.000µg/dia de retinol pré-formado.',
  ),
  NutrientRisk(
    id: 'vitaminAIu',
    nutrient: 'Vitamina A (UI)',
    deficiencia: 'Ver "Vitamina A".',
    excesso: 'Ver "Vitamina A".',
    excessoReferencia: 'UL de ~10.000UI/dia de retinol pré-formado '
        '(equivalente a 3.000µg).',
  ),
  NutrientRisk(
    id: 'vitaminE',
    nutrient: 'Vitamina E (alfatocoferol)',
    deficiencia: 'Rara; neuropatia periférica, fraqueza muscular, '
        'problemas de visão em deficiência prolongada.',
    excesso: 'Risco aumentado de sangramento, especialmente combinado com '
        'anticoagulantes; alguns estudos associaram doses altas a maior '
        'risco de acidente vascular hemorrágico.',
    excessoReferencia: 'UL é 1.000mg/dia (RDA ~15mg/dia). O estudo '
        'SELECT, que associou suplementação a maior risco de câncer de '
        'próstata, usou 400UI/dia (~268mg, ~18x a RDA) por vários anos.',
  ),
  NutrientRisk(
    id: 'addedVitaminE',
    nutrient: 'Vitamina E (adicionada)',
    deficiencia: null,
    excesso: 'Ver "Vitamina E".',
    excessoReferencia: 'UL de 1.000mg/dia (forma sintética/suplementar).',
  ),
  NutrientRisk(
    id: 'betaTocopherol',
    nutrient: 'Beta-tocoferol',
    deficiencia: null,
    excesso: 'Sem toxicidade isolada estabelecida; considerar junto do '
        'total de vitamina E.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'gammaTocopherol',
    nutrient: 'Gama-tocoferol',
    deficiencia: null,
    excesso: 'Sem toxicidade isolada estabelecida; considerar junto do '
        'total de vitamina E.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'deltaTocopherol',
    nutrient: 'Delta-tocoferol',
    deficiencia: null,
    excesso: 'Sem toxicidade isolada estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'alphaTocotrienol',
    nutrient: 'Tocotrienol alfa',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética isolada estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'betaTocotrienol',
    nutrient: 'Tocotrienol beta',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética isolada estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'gammaTocotrienol',
    nutrient: 'Tocotrienol gama',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética isolada estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'deltaTocotrienol',
    nutrient: 'Tocotrienol delta',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética isolada estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'vitaminD',
    nutrient: 'Vitamina D',
    deficiencia: 'Raquitismo em crianças, osteomalácia/osteoporose em '
        'adultos, dor óssea e muscular.',
    excesso: 'Hipervitaminose D: hipercalcemia, náusea, cálculos renais, '
        'dano renal em casos graves.',
    excessoReferencia: 'UL é 100µg (4.000UI)/dia (RDA ~15-20µg, 600-800UI/'
        'dia). Casos de intoxicação documentados envolveram doses de '
        'suplemento de 50.000-1.000.000 UI/dia por erro de fabricação ou '
        'prescrição, dezenas a centenas de vezes o UL — não ocorre por '
        'exposição solar ou dieta normal.',
  ),
  NutrientRisk(
    id: 'vitaminD2',
    nutrient: 'Vitamina D2 (Ergocalciferol)',
    deficiencia: 'Ver "Vitamina D".',
    excesso: 'Ver "Vitamina D".',
    excessoReferencia: 'Mesmo UL da vitamina D total: 100µg (4.000UI)/dia.',
  ),
  NutrientRisk(
    id: 'vitaminD3',
    nutrient: 'Vitamina D3 (Colecalciferol)',
    deficiencia: 'Ver "Vitamina D".',
    excesso: 'Ver "Vitamina D".',
    excessoReferencia: 'Mesmo UL da vitamina D total: 100µg (4.000UI)/dia.',
  ),
  NutrientRisk(
    id: 'vitaminDIu',
    nutrient: 'Vitamina D (UI)',
    deficiencia: 'Ver "Vitamina D".',
    excesso: 'Ver "Vitamina D".',
    excessoReferencia: 'UL de 4.000UI/dia (equivalente a 100µg).',
  ),
  NutrientRisk(
    id: 'vitaminK',
    nutrient: 'Vitamina K (Filoquinona)',
    deficiencia: 'Sangramento excessivo, coagulação prejudicada.',
    excesso: 'Sem toxicidade estabelecida pela forma alimentar (K1); '
        'principal cuidado é interação com anticoagulantes como varfarina, '
        'reduzindo seu efeito.',
    excessoReferencia: 'Sem UL definido para vitamina K1 da dieta; a '
        'preocupação clínica é variação abrupta de ingestão (não excesso '
        'em si) em quem usa varfarina.',
  ),
  NutrientRisk(
    id: 'dihydrophylloquinone',
    nutrient: 'Di-hidrofiloquinona',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética isolada estabelecida.',
    excessoReferencia: null,
  ),

  // ==========================================================
  // CAROTENOIDES
  // ==========================================================
  NutrientRisk(
    id: 'betaCarotene',
    nutrient: 'Betacaroteno',
    deficiencia: null,
    excesso: 'Carotenodermia (pele amarelada/alaranjada, reversível e '
        'inofensiva); suplementação em altas doses foi associada a maior '
        'risco de câncer de pulmão em fumantes.',
    excessoReferencia: 'Os estudos CARET e ATBC, que mostraram aumento de '
        'risco de câncer de pulmão em fumantes/ex-fumantes e expostos a '
        'asbesto, usaram suplementos de 20-30mg/dia por vários anos — '
        'muito acima do que se obtém só com alimentos (cenoura, batata-'
        'doce etc.), que não apresenta esse risco.',
  ),
  NutrientRisk(
    id: 'alphaCarotene',
    nutrient: 'Alfacaroteno',
    deficiencia: null,
    excesso: 'Sem toxicidade estabelecida além de possível carotenodermia '
        'em excesso extremo.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'betaCryptoxanthin',
    nutrient: 'Beta-criptoxantina',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética estabelecida.',
    excessoReferencia: null,
  ),
  NutrientRisk(
    id: 'lycopene',
    nutrient: 'Licopeno',
    deficiencia: null,
    excesso: 'Licopenodermia (pele avermelhada, benigna e reversível) em '
        'consumo extremo e prolongado.',
    excessoReferencia: 'Casos descritos com consumo diário de grandes '
        'quantidades de suco de tomate/molho por anos, várias vezes acima '
        'da ingestão típica; não representa risco à saúde além da '
        'estética.',
  ),
  NutrientRisk(
    id: 'luteinZeaxanthin',
    nutrient: 'Luteína + Zeaxantina',
    deficiencia: null,
    excesso: 'Sem toxicidade dietética relevante estabelecida.',
    excessoReferencia: null,
  ),

  // ==========================================================
  // LIPÍDIOS
  // ==========================================================
  NutrientRisk(
    id: 'saturatedFat',
    nutrient: 'Gorduras saturadas',
    deficiencia: null,
    excesso: 'Associada a aumento de LDL e maior risco cardiovascular '
        'quando consumo é cronicamente alto.',
    excessoReferencia: 'Diretrizes recomendam <10% das calorias diárias; '
        'associações de risco cardiovascular geralmente comparam padrões '
        'habituais de 15%+ das calorias mantidos por anos.',
  ),
  NutrientRisk(id: 'butyricAcid', nutrient: 'Ácido butírico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'caproicAcid', nutrient: 'Ácido caproico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'caprylicAcid', nutrient: 'Ácido caprílico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'capricAcid', nutrient: 'Ácido cáprico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(
    id: 'lauricAcid',
    nutrient: 'Ácido láurico',
    excesso: 'Eleva LDL como as demais saturadas de cadeia média/longa; '
        'sem toxicidade aguda própria.',
    excessoReferencia: 'Tratar dentro do total de gordura saturada.',
  ),
  NutrientRisk(id: 'myristicAcid', nutrient: 'Ácido mirístico',
      excesso: 'Um dos ácidos graxos saturados com maior efeito de '
          'elevação do LDL.',
      excessoReferencia: 'Tratar dentro do total de gordura saturada.'),
  NutrientRisk(id: 'heptadecanoicAcid', nutrient: 'Ácido heptadecanoico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'stearicAcid', nutrient: 'Ácido esteárico',
      excesso: 'Diferente de outras saturadas, tem efeito neutro sobre o '
          'LDL na maioria dos estudos.',
      excessoReferencia: 'Sem UL específico.'),
  NutrientRisk(id: 'arachidicAcid', nutrient: 'Ácido araquídico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(
    id: 'monounsaturatedFat',
    nutrient: 'Gorduras monoinsaturadas',
    deficiencia: null,
    excesso: 'Geralmente considerada neutra a benéfica (ex: azeite de '
        'oliva); risco relevante só como parte de excesso calórico geral.',
    excessoReferencia: 'Sem UL específico; risco é de excesso calórico, '
        'não da gordura monoinsaturada em si.',
  ),
  NutrientRisk(id: 'palmitoleicAcid', nutrient: 'Ácido palmitoleico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'palmitoleicAcidCis', nutrient: 'Ácido palmitoleico, cis',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'palmiticAcid', nutrient: 'Ácido palmítico',
      excesso: 'Um dos principais responsáveis pela elevação de LDL entre '
          'as saturadas.',
      excessoReferencia: 'Tratar dentro do total de gordura saturada.'),
  NutrientRisk(
    id: 'oleicAcid',
    nutrient: 'Ácido oleico',
    excesso: 'Considerado neutro/benéfico ao perfil lipídico (principal '
        'ácido graxo do azeite de oliva).',
    excessoReferencia: 'Sem UL específico.',
  ),
  NutrientRisk(id: 'oleicAcidCis', nutrient: 'Ácido oleico, cis',
      excessoReferencia: 'Sem UL específico; ver "Ácido oleico".'),
  NutrientRisk(
    id: 'oleicAcidTrans',
    nutrient: 'Ácido oleico, trans (Elaídico)',
    excesso: 'Comporta-se como gordura trans: eleva LDL e reduz HDL.',
    excessoReferencia: 'Ver "Gorduras trans" — OMS recomenda eliminar '
        'gordura trans industrial da dieta.',
  ),
  NutrientRisk(id: 'gadoleicAcid', nutrient: 'Ácido gadoleico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'erucicAcid', nutrient: 'Ácido erúcico',
      excesso: 'Em estudos com animais, altas doses foram associadas a '
          'acúmulo de gordura no músculo cardíaco.',
      excessoReferencia: 'Efeito visto em estudos animais com dietas ricas '
          'em óleo de colza tradicional (não a variedade canola moderna, '
          'que tem baixo teor); regulação limita óleos comerciais a <2% de '
          'ácido erúcico, nível considerado seguro para humanos.'),
  NutrientRisk(
    id: 'polyunsaturatedFat',
    nutrient: 'Gorduras poli-insaturadas',
    deficiencia: 'Deficiência de ácidos graxos essenciais: pele seca, má '
        'cicatrização, problemas de crescimento em crianças.',
    excesso: 'Em excesso extremo, maior suscetibilidade a oxidação lipídica '
        'e inflamação; risco pouco relevante em dietas comuns.',
    excessoReferencia: 'Sem UL numérico estabelecido para uso alimentar '
        'comum.',
  ),
  NutrientRisk(id: 'linoleicAcid', nutrient: 'Ácido linoleico',
      deficiencia: 'Sintomas de deficiência de ácido graxo essencial: pele '
          'seca e descamativa, má cicatrização.',
      excesso: 'Consumo excessivo em relação ao ômega-3 é associado a '
          'maior estado pró-inflamatório em alguns estudos.',
      excessoReferencia: 'A preocupação é mais sobre a proporção ômega-6/'
          'ômega-3 do que uma dose absoluta de toxicidade; sem UL '
          'estabelecido.'),
  NutrientRisk(id: 'linoleicAcidCis', nutrient: 'Ácido linoleico, cis, n-6',
      excessoReferencia: 'Ver "Ácido linoleico".'),
  NutrientRisk(
    id: 'conjugatedLinoleicAcid',
    nutrient: 'Ácido linoleico conjugado (CLA)',
    excesso: 'Suplementação em altas doses foi associada a resistência à '
        'insulina e inflamação em alguns estudos.',
    excessoReferencia: 'Efeitos adversos relatados com suplementos de '
        '3-6g/dia por meses, muito acima do que se obtém apenas de '
        'laticínios/carne (tipicamente <1g/dia).',
  ),
  NutrientRisk(id: 'linoleicAcidIsomers', nutrient: 'Ácido linoleico, '
      'isômeros',
      excessoReferencia: 'Ver "Ácido linoleico conjugado (CLA)".'),
  NutrientRisk(
    id: 'ala',
    nutrient: 'Ácido alfa-linolênico (ALA, ômega-3)',
    deficiencia: 'Sintomas de deficiência de ácido graxo essencial: '
        'dermatite, prejuízo neurológico em crianças.',
    excesso: 'Em doses muito altas, pode discretamente aumentar o risco '
        'de sangramento.',
    excessoReferencia: 'Sem UL estabelecido; efeito sobre coagulação é '
        'clinicamente relevante principalmente combinado a EPA/DHA em '
        'doses de suplemento (ver "EPA"/"DHA").',
  ),
  NutrientRisk(id: 'parinaricAcid', nutrient: 'Ácido parinárico',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(
    id: 'arachidonicAcid',
    nutrient: 'Ácido araquidônico',
    excesso: 'Precursor de mediadores pró-inflamatórios; excesso crônico '
        'pode favorecer estado inflamatório se desbalanceado com ômega-3.',
    excessoReferencia: 'Sem UL numérico estabelecido para a dieta comum.',
  ),
  NutrientRisk(
    id: 'epa',
    nutrient: 'Ácido eicosapentaenoico (EPA)',
    deficiencia: null,
    excesso: 'Maior risco de sangramento e, em alguns estudos, maior '
        'incidência de fibrilação atrial com doses altas de suplemento.',
    excessoReferencia: 'FDA/EFSA consideram seguro até ~3g/dia de EPA+DHA '
        'combinados via suplemento; o estudo REDUCE-IT, que mostrou '
        'aumento de fibrilação atrial, usou 4g/dia de EPA isolado por '
        'anos — muito acima do que se obtém só com peixe na dieta '
        '(tipicamente <1g/dia).',
  ),
  NutrientRisk(id: 'dpa', nutrient: 'Ácido docosapentaenoico (DPA)',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida; '
          'tratar junto de EPA/DHA em doses de suplemento.'),
  NutrientRisk(
    id: 'dha',
    nutrient: 'Ácido docosa-hexaenoico (DHA)',
    deficiencia: 'Possível prejuízo no desenvolvimento neurológico/visual '
        'infantil se deficiência materna na gestação.',
    excesso: 'Maior risco de sangramento em doses altas de suplemento.',
    excessoReferencia: 'Ver "EPA" — limite de segurança combinado EPA+DHA '
        'é de ~3g/dia via suplemento; risco relevante documentado em '
        'ensaios com 2-4g/dia mantidos por anos.',
  ),
  NutrientRisk(
    id: 'transFat',
    nutrient: 'Gorduras trans',
    deficiencia: null,
    excesso: 'Eleva LDL e reduz HDL; associação bem estabelecida com maior '
        'risco de doença cardiovascular mesmo em pequenas quantidades.',
    excessoReferencia: 'OMS recomenda eliminar (não apenas limitar) '
        'gordura trans industrial; estudos de risco cardiovascular já '
        'mostram efeito com apenas 2% das calorias diárias vindas de '
        'trans, consumido cronicamente — por isso o alerta pode ser mais '
        'sensível que os demais nutrientes.',
  ),
  NutrientRisk(id: 'transMonoenoicFat', nutrient: 'Gorduras trans, '
      'monoenoico',
      excessoReferencia: 'Ver "Gorduras trans".'),
  NutrientRisk(id: 'transPolyenoicFat', nutrient: 'Gorduras trans, '
      'polienoico',
      excessoReferencia: 'Ver "Gorduras trans".'),
  NutrientRisk(
    id: 'cholesterol',
    nutrient: 'Colesterol',
    deficiencia: null,
    excesso: 'Pode elevar LDL em parte da população ("hiper-respondedores"); '
        'efeito sobre risco cardiovascular é menor e mais individual do '
        'que o de gorduras saturadas/trans.',
    excessoReferencia: 'Diretrizes atuais não fixam mais um limite '
        'numérico rígido (antigo limite era 300mg/dia); considerar alerta '
        'apenas em consumo muito acima disso e de forma sustentada.',
  ),
  NutrientRisk(id: 'stigmasterol', nutrient: 'Estigmasterol',
      excessoReferencia: 'Fitosterol; sem toxicidade dietética isolada '
          'estabelecida em quantidades alimentares comuns.'),
  NutrientRisk(id: 'campesterol', nutrient: 'Campesterol',
      excessoReferencia: 'Fitosterol; sem toxicidade dietética isolada '
          'estabelecida em quantidades alimentares comuns.'),
  NutrientRisk(
    id: 'betaSitosterol',
    nutrient: 'Beta-sitosterol',
    excesso: 'Em fitosterolemia (condição genética rara), acúmulo pode '
        'causar aterosclerose precoce.',
    excessoReferencia: 'Risco relevante apenas em portadores da mutação '
        'genética rara; em pessoas saudáveis, mesmo suplementos de '
        '2-3g/dia (usados para reduzir colesterol) são considerados '
        'seguros.',
  ),

  // ==========================================================
  // AMINOÁCIDOS
  // ==========================================================
  NutrientRisk(
    id: 'tryptophan',
    nutrient: 'Triptofano',
    deficiencia: 'Alterações de humor (é precursor de serotonina), '
        'insônia; deficiência isolada é rara.',
    excesso: 'Sonolência excessiva; risco de síndrome serotoninérgica se '
        'combinado a certos medicamentos (não pela dieta isolada).',
    excessoReferencia: 'Sem toxicidade dietética estabelecida; os riscos '
        'descritos vêm de suplementos isolados (1-5g/dia) combinados a '
        'antidepressivos, não de alimentos.',
  ),
  NutrientRisk(id: 'threonine', nutrient: 'Treonina',
      deficiencia: 'Deficiência isolada é rara; pode afetar síntese '
          'proteica e função imune em desnutrição severa.',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'isoleucine', nutrient: 'Isoleucina',
      deficiencia: 'Rara isoladamente; parte do quadro geral de '
          'desnutrição proteica.',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'leucine', nutrient: 'Leucina',
      deficiencia: 'Rara isoladamente; parte do quadro geral de '
          'desnutrição proteica.',
      excesso: 'Em excesso extremo pode competir com outros aminoácidos '
          'ramificados na absorção.',
      excessoReferencia: 'Sem UL definido pela dieta; efeitos de '
          'competição vistos apenas com suplementação isolada muito acima '
          'da ingestão alimentar típica.'),
  NutrientRisk(id: 'lysine', nutrient: 'Lisina',
      deficiencia: 'Rara isoladamente; comum em dietas muito restritas em '
          'proteína (ex: baseadas quase só em cereais).',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'methionine', nutrient: 'Metionina',
      deficiencia: 'Rara isoladamente; parte do quadro geral de '
          'desnutrição proteica.',
      excesso: 'Em excesso extremo pode elevar homocisteína, um marcador '
          'de risco cardiovascular.',
      excessoReferencia: 'Efeito sobre homocisteína documentado em '
          'estudos com carga aguda de suplemento (~100mg/kg de peso '
          'corporal), muito acima do consumo alimentar normal.'),
  NutrientRisk(id: 'cysteine', nutrient: 'Cisteína',
      deficiencia: 'Rara isoladamente.',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'phenylalanine', nutrient: 'Fenilalanina',
      deficiencia: 'Rara isoladamente.',
      excesso: 'Perigosa apenas para pessoas com fenilcetonúria (condição '
          'genética rara), causando dano neurológico se não controlada.',
      excessoReferencia: 'Risco é específico de quem tem fenilcetonúria; '
          'para a população geral, não há toxicidade dietética '
          'estabelecida.'),
  NutrientRisk(id: 'tyrosine', nutrient: 'Tirosina',
      deficiencia: 'Rara isoladamente.',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'valine', nutrient: 'Valina',
      deficiencia: 'Rara isoladamente; parte do quadro geral de '
          'desnutrição proteica.',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(
    id: 'arginine',
    nutrient: 'Arginina',
    deficiencia: 'Rara isoladamente; pode prejudicar cicatrização e '
        'função imune em desnutrição severa.',
    excesso: 'Em suplementação alta pode causar hipotensão e distúrbios '
        'gastrointestinais.',
    excessoReferencia: 'Efeitos relatados com doses de suplemento acima '
        'de 9g/dia (bem acima da ingestão alimentar típica de ~4-6g/dia).',
  ),
  NutrientRisk(id: 'histidine', nutrient: 'Histidina',
      deficiencia: 'Rara isoladamente.',
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'alanine', nutrient: 'Alanina',
      deficiencia: null,
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'asparticAcid', nutrient: 'Ácido aspártico',
      deficiencia: null,
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'glutamicAcid', nutrient: 'Ácido glutâmico',
      deficiencia: null,
      excesso: 'Parte da controvérsia histórica sobre glutamato/MSG '
          '(dores de cabeça em indivíduos sensíveis); evidência científica '
          'atual considera isso raro e não bem estabelecido em doses '
          'alimentares normais.',
      excessoReferencia: 'Estudos que buscaram reproduzir a "síndrome do '
          'restaurante chinês" usaram doses de 3g+ de MSG em jejum, '
          'raramente reproduzindo sintomas de forma consistente.'),
  NutrientRisk(id: 'glycine', nutrient: 'Glicina',
      deficiencia: null,
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida; '
          'inclusive usada como suplemento em doses de vários gramas sem '
          'efeitos adversos relevantes.'),
  NutrientRisk(id: 'proline', nutrient: 'Prolina',
      deficiencia: null,
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),
  NutrientRisk(id: 'serine', nutrient: 'Serina',
      deficiencia: null,
      excessoReferencia: 'Sem toxicidade dietética isolada estabelecida.'),

  // ==========================================================
  // OUTROS
  // ==========================================================
  NutrientRisk(
    id: 'alcohol',
    nutrient: 'Álcool',
    deficiencia: null,
    excesso: 'Dano hepático, risco cardiovascular, dependência, maior '
        'risco de vários tipos de câncer; intoxicação aguda pode ser '
        'fatal.',
    excessoReferencia: 'Diretrizes de baixo risco sugerem até ~1 dose/dia '
        '(mulheres) ou ~2 doses/dia (homens); consumo crônico acima disso '
        '(binge de 4-5+ doses de uma vez, ou uso diário pesado por anos) é '
        'o que embasa os estudos de dano hepático e câncer.',
  ),
  NutrientRisk(
    id: 'caffeine',
    nutrient: 'Cafeína',
    deficiencia: null,
    excesso: 'Ansiedade, taquicardia, insônia, tremores; em doses muito '
        'altas, arritmia grave e convulsões.',
    excessoReferencia: 'FDA/EFSA consideram seguro até ~400mg/dia para '
        'adultos saudáveis (~4 xícaras de café); efeitos cardíacos graves '
        'documentados em casos de ingestão aguda acima de 1.200mg de uma '
        'vez (3x o limite diário), geralmente via cápsulas/pós '
        'concentrados de cafeína, não café/chá comuns.',
  ),
  NutrientRisk(
    id: 'theobromine',
    nutrient: 'Teobromina',
    deficiencia: null,
    excesso: 'Taquicardia, náusea, tremores em doses muito altas '
        '(estrutura similar à cafeína).',
    excessoReferencia: 'Sem UL formal para humanos; sintomas relatados '
        'geralmente acima de 1.000mg/dia, muito além do que se obtém com '
        'consumo normal de chocolate (uma barra costuma ter '
        '<250mg).',
  ),
];