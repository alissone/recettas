---
name: quiz
description: Cria quizzes de múltipla escolha (A–E, com explicação para cada alternativa) para o app Recettas e envia para o Supabase. Use quando o usuário pedir para criar, gerar ou montar um quiz, questionário, simulado ou perguntas sobre um tema, uma matéria, um PDF de prova ou um texto, ou para enviar/subir quizzes para o app.
---

# Criar quiz e enviar para o Supabase

O app mostra os quizzes no FAB "Quizzes" da aba Chat (app e web). O formato
do JSON está em `docs/quiz-format.md` — **leia esse arquivo antes de
escrever qualquer quiz**; ele é a fonte de verdade dos campos e regras.

## 1. Entender o pedido

Do pedido, extraia (pergunte só o que não der para inferir):

- **Tema/matéria** e, se houver, o **material-base** (PDF, texto, link).
  Para PDF use `pdftotext -enc UTF-8 arquivo.pdf saida.txt` (está no PATH)
  num diretório de rascunho, não no repositório.
- **Quantidade de perguntas** — padrão 10 por quiz.
- **Um quiz ou vários** — por exemplo, um por matéria de uma prova.
- **Público/nível** — padrão: adulto estudando para concurso. Se for para
  crianças, linguagem simples e explicações curtas e encorajadoras.

## 2. Escrever as perguntas

- 5 alternativas (A–E) por pergunta, salvo pedido diferente.
- **Toda alternativa tem `explanation`**: a certa diz por que está certa;
  cada errada diz por que *aquela* está errada (o conceito que ela confunde,
  o artigo de lei que contradiz). Nada de "errada porque a certa é a C".
- Distratores plausíveis: erros que alguém estudando realmente cometeria.
- Distribua a letra certa entre A–E (o validador avisa se uma letra
  passar de 40%). Escreva primeiro e embaralhe a posição da certa depois.
- Use `context.text` para trechos de texto-base (interpretação, artigo de
  lei) e `context.image_url` só com URL direta de PNG/JPG que você conferiu
  (Wikimedia Commons é a melhor fonte; nada de SVG).
- Conteúdo jurídico/técnico: só afirme o que você tem certeza que está em
  vigor; cite o artigo/lei/súmula na explicação. Na dúvida sobre gabarito
  oficial ou norma alterada, troque a pergunta.
- Provas no estilo Certo/Errado (CESPE) devem ser **convertidas** para A–E:
  a assertiva vira enunciado e as alternativas exploram as variações.
- Texto puro, sem Markdown; português do Brasil.

Campos do quiz: `title` (curto, ex. "Direito Penal — PRF 2019"), `topic`,
`description` (1 frase), `source` quando vier de prova/livro, `color`
opcional (`#RRGGBB`). **Não** coloque `id` em quiz novo: o upload gera e
grava de volta no arquivo.

## 3. Salvar, validar e enviar

1. Salve cada quiz em `quizzes/<slug>.json` na raiz do projeto (um quiz por
   arquivo). **Não** use `assets/quizzes/` — esses vão embutidos no app e
   servem só para testes offline.
2. Valide:
   ```
   python scripts/upload_quiz.py --check quizzes/<slug>.json
   ```
   Corrija todos os `error:` e avalie os `warning:`.
3. Envie (upsert pelo `id`; o script grava o `id` gerado no arquivo):
   ```
   python scripts/upload_quiz.py quizzes/<slug>.json
   ```
   Usa `SUPABASE_SERVICE_ROLE_KEY` do ambiente ou de `transcriber/.env`.
   Se der erro de tabela inexistente, a migração `migrations/044_quizzes.sql`
   ainda não foi rodada no SQL editor do Supabase — avise o usuário.

## 4. Editar um quiz existente

Corrigir textos, explicações ou a letra certa: edite o arquivo e rode o
upload de novo (mesmo `id`). **Nunca reordene, adicione ou remova perguntas
ou alternativas de um quiz que já tem tentativas** — as respostas são
guardadas por posição. Para isso, crie um quiz novo.

## 5. Responder

Diga quantos quizzes/perguntas foram criados, o caminho dos arquivos e se o
upload deu certo. Não cole o JSON inteiro na conversa.
