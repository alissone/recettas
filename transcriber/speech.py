"""Speech for the assistant chat: Parakeet (speech -> text) and Kokoro
(text -> speech), both ONNX on the CPU, so they never compete with the
local LLM or WhisperX for the GPU.

- Parakeet TDT 0.6B v3 (onnx_asr, same family as C:\\dev\\speak\\speak.py,
  which uses the English-only v2): 25 European languages incl. Portuguese
  and English, language detected by itself. Fast; models download to the
  Hugging Face cache on first use.
- Kokoro 82M (kokoro-onnx): models/kokoro-v1.0.onnx + models/voices-v1.0.bin
  (setup.bat downloads them). The voice's first letter picks the language:
  a = American English, b = British English, p = Brazilian Portuguese.

Both load lazily and stay in RAM (~1 GB together).

Try it, no database:

    .venv\\Scripts\\python.exe speech.py say pf_dora "Olá! Tudo bem?" out.m4a
    .venv\\Scripts\\python.exe speech.py hear out.m4a
"""
from __future__ import annotations

import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
PARAKEET_MODEL = os.environ.get("PARAKEET_MODEL") or "nemo-parakeet-tdt-0.6b-v3"
KOKORO_DIR = Path(os.environ.get("KOKORO_DIR") or SCRIPT_DIR / "models")
DEFAULT_VOICE = os.environ.get("KOKORO_VOICE") or "pf_dora"
FFMPEG = os.environ.get("FFMPEG") or shutil.which("ffmpeg") or r"C:\dev\ffmpeg.exe"

# Voice prefix -> espeak language for Kokoro's phonemizer.
KOKORO_LANGS = {"a": "en-us", "b": "en-gb", "p": "pt-br", "e": "es", "f": "fr-fr",
                "i": "it", "h": "hi"}

_lock = threading.Lock()
_parakeet = None
_kokoro = None


def _ffmpeg(*args: str) -> None:
    proc = subprocess.run([FFMPEG, "-hide_banner", "-loglevel", "error", "-y", *args],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                          creationflags=getattr(subprocess, "CREATE_NO_WINDOW", 0))
    if proc.returncode != 0:
        raise RuntimeError("ffmpeg: " + proc.stdout.decode("utf-8", "replace")[-300:])


def to_wav16k(src: Path, dst: Path) -> None:
    """Any audio (the phone sends AAC/m4a) -> 16 kHz mono WAV."""
    _ffmpeg("-i", str(src), "-ar", "16000", "-ac", "1", str(dst))


def transcribe_parakeet(audio: Path) -> str:
    global _parakeet
    import onnx_asr
    with _lock:
        if _parakeet is None:
            _parakeet = onnx_asr.load_model(PARAKEET_MODEL, quantization="int8")
        with tempfile.TemporaryDirectory(prefix="parakeet_") as tmp:
            wav = Path(tmp) / "in.wav"
            to_wav16k(audio, wav)
            return str(_parakeet.recognize(str(wav))).strip()


def _kokoro_model():
    global _kokoro
    if _kokoro is None:
        from kokoro_onnx import Kokoro
        model, voices = KOKORO_DIR / "kokoro-v1.0.onnx", KOKORO_DIR / "voices-v1.0.bin"
        if not model.exists() or not voices.exists():
            raise RuntimeError(f"Kokoro não instalado: faltam arquivos em {KOKORO_DIR} "
                               "(rode setup.bat)")
        _kokoro = Kokoro(str(model), str(voices))
    return _kokoro


def voices() -> list[str]:
    with _lock:
        return sorted(_kokoro_model().get_voices())


_MD = [
    (re.compile(r"```.*?```", re.S), " "),           # code blocks aren't read aloud
    (re.compile(r"`([^`]*)`"), r"\1"),
    (re.compile(r"!?\[([^\]]*)\]\([^)]*\)"), r"\1"),  # links -> their text
    (re.compile(r"^\s{0,3}#{1,6}\s*", re.M), ""),
    (re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+", re.M), ""),
    (re.compile(r"[*_~]{1,3}([^*_~]+)[*_~]{1,3}"), r"\1"),
    (re.compile(r"[ \t]+"), " "),
]


def speakable(text: str) -> str:
    for pattern, repl in _MD:
        text = pattern.sub(repl, text)
    # Each line becomes a sentence so the list items get a pause.
    lines = [ln.strip() for ln in text.splitlines() if ln.strip()]
    return " ".join(ln if ln[-1] in ".!?:;" else ln + "." for ln in lines)


def synthesize(text: str, voice: str | None, out: Path) -> float:
    """Speak text with Kokoro into an AAC .m4a; returns its length in seconds."""
    import soundfile as sf
    voice = voice or DEFAULT_VOICE
    lang = KOKORO_LANGS.get(voice[:1], "en-us")
    text = speakable(text)
    if not text:
        raise RuntimeError("nada para falar")
    with _lock:
        kokoro = _kokoro_model()
        if voice not in kokoro.get_voices():
            voice, lang = DEFAULT_VOICE, KOKORO_LANGS.get(DEFAULT_VOICE[:1], "en-us")
        samples, rate = kokoro.create(text, voice=voice, speed=1.0, lang=lang)
    with tempfile.TemporaryDirectory(prefix="kokoro_") as tmp:
        wav = Path(tmp) / "out.wav"
        sf.write(str(wav), samples, rate)
        _ffmpeg("-i", str(wav), "-c:a", "aac", "-b:a", "64k", "-ac", "1", str(out))
    return len(samples) / rate


def main() -> None:
    if len(sys.argv) >= 5 and sys.argv[1] == "say":
        secs = synthesize(sys.argv[3], sys.argv[2], Path(sys.argv[4]))
        print(f"{sys.argv[4]}: {secs:.1f}s")
    elif len(sys.argv) >= 3 and sys.argv[1] == "hear":
        print(transcribe_parakeet(Path(sys.argv[2])))
    elif len(sys.argv) >= 2 and sys.argv[1] == "voices":
        print(" ".join(voices()))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main()
