"""Detecção + validação matemática (módulo 11) de CPF/CNPJ e varredura de texto."""
from __future__ import annotations
import re
from dataclasses import dataclass

CPF_RE = re.compile(r"\b(\d{3})\.?(\d{3})\.?(\d{3})-?(\d{2})\b")
CNPJ_RE = re.compile(r"\b(\d{2})\.?(\d{3})\.?(\d{3})/(\d{4})-?(\d{2})\b")
PROCESSO_RE = re.compile(r"\b\d{7}-\d{2}\.\d{4}\.\d\.\d{2}\.\d{4}\b")
CLASSIFICADO = ["ULTRASSECRETO", "SECRETO", "RESERVADO", "SIGILOSO", "USO INTERNO"]


@dataclass
class Finding:
    entity: str
    score: float
    start: int
    end: int
    masked: str


def _mod11(digits: list[int], weights: list[int]) -> int:
    s = sum(d * w for d, w in zip(digits, weights))
    r = (s * 10) % 11
    return 0 if r == 10 else r


def cpf_valid(cpf: str) -> bool:
    d = [int(c) for c in cpf if c.isdigit()]
    if len(d) != 11 or len(set(d)) == 1:
        return False
    w1 = [10, 9, 8, 7, 6, 5, 4, 3, 2]
    w2 = [11, 10, 9, 8, 7, 6, 5, 4, 3, 2]
    return _mod11(d[:9], w1) == d[9] and _mod11(d[:10], w2) == d[10]


def cnpj_valid(cnpj: str) -> bool:
    d = [int(c) for c in cnpj if c.isdigit()]
    if len(d) != 14:
        return False
    w1 = [5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    w2 = [6, 5, 4, 3, 2, 9, 8, 7, 6, 5, 4, 3, 2]
    return _mod11(d[:12], w1) == d[12] and _mod11(d[:13], w2) == d[13]


def scan(text: str) -> list[Finding]:
    out: list[Finding] = []
    for m in CPF_RE.finditer(text):
        if cpf_valid(m.group(0)):
            out.append(Finding("BR_CPF", 0.97, m.start(), m.end(), "***.***.***-**"))
    for m in CNPJ_RE.finditer(text):
        if cnpj_valid(m.group(0)):
            out.append(Finding("BR_CNPJ", 0.96, m.start(), m.end(), "**.***.***/****-**"))
    for m in PROCESSO_RE.finditer(text):
        out.append(Finding("BR_PROCESSO_JUDICIAL", 0.90, m.start(), m.end(), "*******-**.****.*.**.****"))
    up = text.upper()
    for kw in CLASSIFICADO:
        i = up.find(kw)
        if i >= 0:
            out.append(Finding("BR_DADO_CLASSIFICADO", 1.0, i, i + len(kw), "[CLASSIFICADO]"))
    return out


def decide(findings: list[Finding], block_thr: float = 0.85, anon_thr: float = 0.50) -> str:
    if not findings:
        return "ALLOW"
    mx = max(f.score for f in findings)
    if any(f.entity == "BR_DADO_CLASSIFICADO" for f in findings):
        return "BLOCK"
    if mx >= block_thr:
        return "BLOCK"
    if mx >= anon_thr:
        return "ANONYMIZE"
    return "ALLOW"
