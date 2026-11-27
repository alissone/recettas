"""Chats with the local assistant (Chat tab -> robot button in the app).

The app stores each chat in public.bot_chats / public.bot_messages
(migrations/047_bot_chats.sql). A user message arrives with status
'requested'; worker.py claims it, this module builds the prompt from the
chat's history and asks the local model (C:\\dev\\locallama, same as
agent.py), and the worker saves the reply as a role='assistant' message.

A message may carry `context`: data the app attached that the user doesn't
see in the bubble, e.g. their todo list in the app's order for "Resumir meus
afazeres". It is sent to the model right before the message text.

The model stays loaded for BOT_IDLE_SECONDS after the last answer, so a
conversation doesn't wait for a model load on every message; worker.py
unloads it before WhisperX needs the GPU.

Dry run, no database:

    .venv\\Scripts\\python.exe bot_chat.py "qual a capital da Austrália?"
"""
from __future__ import annotations

import os
import sys
from datetime import datetime

import agent
from locallm import LocalLLM

BOT_MODEL = os.environ.get("BOT_MODEL") or agent.AGENT_MODEL
BOT_CTX = int(os.environ.get("BOT_CTX") or 16384)
# "", "low", "medium", "high": thinking answers better but takes longer.
BOT_THINK = os.environ.get("BOT_THINK") or ""
BOT_IDLE_SECONDS = int(os.environ.get("BOT_IDLE_SECONDS") or 300)
BOT_MAX_TOKENS = int(os.environ.get("BOT_MAX_TOKENS") or 2048)
# Rough budget for the history, in characters (~3.5 chars per token),
# leaving room for the system prompt and the answer.
HISTORY_CHARS = int((BOT_CTX - BOT_MAX_TOKENS - 1024) * 3.5)

WEEKDAYS_PT = ["segunda-feira", "terça-feira", "quarta-feira", "quinta-feira",
               "sexta-feira", "sábado", "domingo"]


def system_prompt(now: datetime) -> str:
    return f"""Você é o assistente pessoal do usuário dentro do app Recettas, \
rodando localmente no PC dele. Converse de forma natural, direta e amigável, \
como um bom assistente de chat.

Agora: {now:%Y-%m-%d %H:%M} ({WEEKDAYS_PT[now.weekday()]}).

- Responda no idioma em que ele escrever (normalmente português do Brasil).
- Seja breve: a resposta aparece num balão de chat no celular. Use listas \
curtas quando ajudarem; evite títulos e tabelas.
- Às vezes a mensagem vem com dados do app anexados entre <dados> e </dados> \
(por exemplo a lista de afazeres, na ordem em que aparece no app: quem está \
mais acima costuma ser mais importante; itens marcados como "hoje" foram \
fixados para hoje e "!" no fim indica urgência). Use esses dados para \
responder e não invente itens que não estão lá.
- Você não consegue alterar nada no app por aqui; se ele pedir para criar \
tarefas, gastos etc., diga que dá para fazer pelas notas de voz."""


def user_text(msg: dict) -> str:
    context = (msg.get("context") or "").strip()
    content = (msg.get("content") or "").strip()
    return f"<dados>\n{context}\n</dados>\n\n{content}" if context else content


VOICE_NOTE = """

Esta mensagem foi falada (transcrição automática, pode ter erros) e a sua resposta será lida em voz alta por um sintetizador: responda em frases curtas e naturais, como numa conversa, sem markdown, listas, emojis ou links. Use o mesmo idioma em que ele falou."""


def build_messages(history: list[dict], now: datetime, spoken: bool = False) -> list[dict]:
    """history: the chat's messages, oldest first, ending with the one to
    answer. Older turns are dropped (and their attached data first) to fit
    the context."""
    turns: list[dict] = []
    for i, m in enumerate(history):
        if m["role"] == "assistant":
            turns.append({"role": "assistant", "content": m["content"]})
            continue
        # Earlier messages whose answer failed would leave two user turns in
        # a row; merge them so the template stays user/assistant alternating.
        latest = i == len(history) - 1
        text = user_text(m) if latest or m.get("status") == "done" else m["content"]
        if turns and turns[-1]["role"] == "user":
            turns[-1]["content"] += "\n\n" + text
        else:
            turns.append({"role": "user", "content": text})

    # Keep the newest turns that fit; an old snapshot of the todo list is
    # the first thing to go.
    kept, used = [], 0
    for t in reversed(turns):
        size = len(t["content"])
        if kept and used + size > HISTORY_CHARS:
            break
        kept.append(t)
        used += size
    kept.reverse()
    while kept and kept[0]["role"] != "user":
        kept.pop(0)
    system = system_prompt(now) + (VOICE_NOTE if spoken else "")
    return [{"role": "system", "content": system}, *kept]


def answer(llm: LocalLLM, history: list[dict], now: datetime | None = None,
           spoken: bool = False) -> str:
    reply = llm.complete(
        build_messages(history, now or datetime.now().astimezone(), spoken),
        think=BOT_THINK or False,
        max_tokens=BOT_MAX_TOKENS,
    )
    text = reply.content.strip()
    if not text:
        raise RuntimeError("o modelo respondeu vazio")
    return text


def server() -> agent.ModelServer:
    return agent.ModelServer(BOT_MODEL, ctx=BOT_CTX, timeout=600)


def main() -> None:
    if len(sys.argv) < 2:
        sys.exit('uso: bot_chat.py "mensagem"')
    srv = server()
    try:
        print(answer(srv.start(), [{"role": "user", "content": " ".join(sys.argv[1:])}]))
    finally:
        srv.stop()


if __name__ == "__main__":
    main()
