from fastapi import FastAPI
from pydantic import BaseModel
from .rules_br import scan, decide

app = FastAPI(title="GovAI Shield DLP Engine", version="0.1.0")


class InspectReq(BaseModel):
    text: str
    block_threshold: float = 0.85
    anonymize_threshold: float = 0.50


@app.get("/health")
def health():
    return {"status": "ok"}


@app.post("/inspect")
def inspect(req: InspectReq):
    findings = scan(req.text)
    action = decide(findings, req.block_threshold, req.anonymize_threshold)
    return {
        "action": action,
        "entities_found": [
            {"type": f.entity, "score": f.score, "start": f.start, "end": f.end, "masked": f.masked}
            for f in findings
        ],
    }
