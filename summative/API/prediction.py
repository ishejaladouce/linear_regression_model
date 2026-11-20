"""API that predicts how many words per minute a child can read."""

from pathlib import Path
from typing import Literal

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field

from retrain import FEATURES, retrain_model

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"
DATA_PATH = BASE_DIR / "training_data.csv"

# Load the saved model and the original training data once, when the API starts.
model = joblib.load(MODEL_PATH)
training_data = pd.read_csv(DATA_PATH)

app = FastAPI(
    title="Reading Fluency Prediction API",
    description="Predicts how many words per minute a primary school child can read, "
                "so mentorship programmes can find children who need reading support early.",
    version="1.0.0",
)

# CORS: I only allow my Render URL and two local test addresses, not "*",
# so other websites can't call my API from a browser.
# I allow only GET and POST because those are the only methods I use,
# and only the Content-Type header, which is needed to send JSON and CSV files.
# Credentials are off because the API has no logins or cookies.
# The Flutter app is not a browser, so CORS doesn't block it.

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://reading-fluency-api-srxu.onrender.com",
        "http://localhost:8080",
        "http://localhost:3000",
    ],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type"],
    allow_credentials=False,
)


class ChildData(BaseModel):
    """Information about one child. Each field has a type and a realistic range."""

    country: Literal["Ethiopia", "Malawi", "Rwanda", "Tanzania"]
    language: Literal[
        "Amharic", "Afan Oromo", "Tigrinya", "Somaligna", "Sidaamu Afoo",
        "Hararigna", "Chichewa", "Kinyarwanda", "Kiswahili",
    ]
    location: Literal["Rural", "Urban"]
    gender: Literal["Male", "Female"]
    age: int = Field(ge=5, le=14, description="Age in years")
    grade: int = Field(ge=1, le=4, description="School grade")
    familiar_words_per_min: float = Field(ge=0, le=200, description="Familiar words read correctly per minute")
    listening_comprehension_pct: float = Field(ge=0, le=100, description="Listening comprehension score in percent")


@app.get("/", include_in_schema=False)
def home():
    return RedirectResponse(url="/docs")


@app.post("/predict")
def predict(child: ChildData):
    row = pd.DataFrame([child.model_dump()])[FEATURES]
    prediction = max(float(model.predict(row)[0]), 0.0)
    return {"predicted_words_per_minute": round(prediction, 1)}


@app.post("/retrain")
async def retrain(file: UploadFile = File(...)):
    global model, training_data

    if not file.filename.lower().endswith(".csv"):
        raise HTTPException(status_code=400, detail="Please upload a .csv file.")

    try:
        model, training_data, rows_added = retrain_model(await file.read(), training_data, MODEL_PATH)
    except ValueError as error:
        raise HTTPException(status_code=400, detail=str(error))

    return {
        "message": "Model retrained and now in use.",
        "new_rows_added": rows_added,
        "total_training_rows": len(training_data),
    }