from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
import re


class AnalyzeRequest(BaseModel):
    text: str = Field(..., min_length=1, description="Text to analyze")


class AnalyzeResponse(BaseModel):
    original_text: str
    word_count: int
    character_count: int


app = FastAPI(title="Insight-Agent", version="1.0.0")


@app.get("/")
def health() -> dict:
    return {"status": "ok"}


@app.post("/analyze", response_model=AnalyzeResponse)
def analyze(payload: AnalyzeRequest) -> AnalyzeResponse:
    if payload.text is None:
        raise HTTPException(status_code=400, detail="Missing 'text' field")

    original_text = payload.text
    word_count = len(original_text.split())
    # Character count excluding whitespace to match common expectations
    character_count = len(re.sub(r"\s+", "", original_text))

    return AnalyzeResponse(
        original_text=original_text,
        word_count=word_count,
        character_count=character_count,
    )
