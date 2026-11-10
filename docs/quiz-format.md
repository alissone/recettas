# Formato dos quizzes (JSON)

Cada quiz é **um objeto JSON**. Ele é guardado inteiro na coluna
`quizzes.content` (jsonb, migração `044_quizzes.sql`) ou, para testes, como
arquivo em `assets/quizzes/*.json` (um objeto ou uma lista de objetos por
arquivo). O app lê ambos — `lib/models/quiz.dart` espelha este formato.

## Exemplo mínimo

```json
{
  "id": "6f1c1d3e-8a51-4c51-9d0a-2b1f7c1e0a01",
  "title": "Legislação de Trânsito — PRF 2019",
  "topic": "Legislação de Trânsito",
  "description": "Crimes de trânsito, infrações e medidas administrativas do CTB.",
  "source": "Baseado na prova CESPE/CEBRASPE PRF 2019",
  "color": "#4C8BF5",
  "questions": [
    {
      "prompt": "Qual é o órgão máximo normativo e coordenador do Sistema Nacional de Trânsito?",
      "context": {
        "text": "Art. 7º Compõem o Sistema Nacional de Trânsito os seguintes órgãos e entidades: I - o Conselho Nacional de Trânsito - CONTRAN...",
        "image_url": "https://upload.wikimedia.org/.../placa.png",
        "image_caption": "Placa R-1"
      },
      "options": [
        { "text": "DENATRAN/SENATRAN", "explanation": "Errada: é o órgão máximo EXECUTIVO de trânsito da União, não o normativo." },
        { "text": "CONTRAN",           "explanation": "Certa: o art. 7º, I, do CTB o define como coordenador do SNT e órgão máximo normativo e consultivo." },
        { "text": "DNIT",              "explanation": "Errada: é órgão executivo rodoviário da União." },
        { "text": "PRF",               "explanation": "Errada: integra o SNT, mas como órgão de fiscalização nas rodovias federais." },
        { "text": "CETRAN",            "explanation": "Errada: é órgão normativo, consultivo e coordenador no âmbito estadual." }
      ],
      "correct": "B"
    }
  ]
}
```

## Campos

### Quiz

| Campo         | Tipo            | Obrigatório | Descrição |
|---------------|-----------------|-------------|-----------|
| `id`          | string (UUID)   | não         | Fixa a identidade do quiz. O upload gera um se faltar e o grava de volta no arquivo. **Os quizzes em `assets/` precisam de `id`** — é por ele que as tentativas são ligadas ao quiz. |
| `title`       | string          | sim         | Título exibido na lista. |
| `topic`       | string          | não         | Matéria/tópico. Define a cor e as iniciais do card quando `color` não vem. |
| `description` | string          | não         | Uma ou duas frases sobre o quiz. |
| `source`      | string          | não         | De onde vieram as questões (prova, livro, lei). |
| `color`       | string `#RRGGBB`| não         | Cor de destaque do quiz. |
| `questions`   | array           | sim         | Uma ou mais perguntas, **na ordem em que são feitas**. |

`title`, `topic`, `description` e a contagem de perguntas são colunas
geradas a partir do JSON no Supabase, então a lista do app busca só elas e
o resto (`content`) é carregado ao abrir o quiz.

### Pergunta

| Campo     | Tipo   | Obrigatório | Descrição |
|-----------|--------|-------------|-----------|
| `prompt`  | string | sim         | O enunciado. |
| `context` | objeto | não         | Base da pergunta: `text` (texto de apoio — trecho, artigo de lei…), `image_url` (imagem da internet, `https://`) e `image_caption`. Qualquer combinação dos três. |
| `options` | array  | sim         | De 2 a 5 alternativas; a posição define a letra (0 = A … 4 = E). O padrão é **5 (A–E)**. |
| `correct` | string | sim         | Letra da alternativa certa, `"A"`–`"E"`, dentro do número de opções. |

### Alternativa

| Campo         | Tipo   | Obrigatório | Descrição |
|---------------|--------|-------------|-----------|
| `text`        | string | sim         | Texto da alternativa. |
| `explanation` | string | sim         | **Por que ela está certa ou errada.** Toda alternativa tem a sua: a certa explica o acerto, cada errada explica o erro dela especificamente (não "porque a certa é a B"). |

## Regras

- **Não reordene nem remova perguntas/alternativas de um quiz que já tem
  tentativas.** As respostas são guardadas por posição (veja abaixo); mudar
  a ordem embaralha o histórico. Corrigir texto, explicação ou até a letra
  certa é seguro — o placar é recalculado. Para mudar a estrutura, crie um
  quiz novo (outro `id`).
- Distribua a letra certa entre A–E; evite padrões.
- Textos em português, sem Markdown (o app mostra texto puro). Quebras de
  linha com `\n` são respeitadas.
- Imagens: URL direta de arquivo `.png`, `.jpg`, `.webp` ou `.gif` (SVG
  não é suportado — no Wikimedia, use a versão rasterizada `.../thumb/...px-`),
  de hosts estáveis. No web, hosts sem CORS ainda funcionam pelo fallback de
  `<img>`, mas prefira Wikimedia.

## Tentativas (`quiz_attempts`)

Cada tentativa **concluída** vira uma linha:

| Coluna             | Exemplo                  |
|--------------------|--------------------------|
| `quiz_id`          | UUID do quiz             |
| `user_id`          | `auth.uid()`             |
| `user_email`       | e-mail de quem fez       |
| `answers`          | `"ABADCEBBAD"`           |
| `duration_seconds` | `312`                    |
| `created_at`       | `now()`                  |

`answers` tem uma letra por pergunta, na ordem, e `-` para uma pergunta em
branco. O acerto não é gravado: o app compara `answers[i]` com
`questions[i].correct` em tempo de execução (`Quiz.score`), e com isso
monta o gráfico de evolução antes de começar o quiz.

## Validar e enviar

```
python scripts/upload_quiz.py --check assets/quizzes/*.json   # só valida
python scripts/upload_quiz.py assets/quizzes/*.json           # valida e faz upsert
```

O upload usa `SUPABASE_SERVICE_ROLE_KEY` (do ambiente ou de
`transcriber/.env`), porque os clientes só têm permissão de leitura em
`quizzes`. Para criar quizzes novos com o Claude, use a skill `/quiz`.
