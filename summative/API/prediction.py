"""Reading Fluency Prediction API.

Predicts how many words per minute an early-grade pupil in East Africa
can read correctly, using the best model trained in multivariate.ipynb.
"""

import io
from pathlib import Path
from typing import Literal

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, Field
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

BASE_DIR = Path(__file__).resolve().parent
MODEL_PATH = BASE_DIR / "best_model.pkl"
DATA_PATH = BASE_DIR / "training_data.csv"

CATEGORICAL_FEATURES = ["country", "language", "location", "gender"]
NUMERIC_FEATURES = ["age", "grade", "familiar_words_per_min", "listening_comprehension_pct"]
FEATURES = CATEGORICAL_FEATURES + NUMERIC_FEATURES
TARGET = "words_per_minute"

# Load the saved model and the original training data once, when the API starts.
model = joblib.load(MODEL_PATH)
training_data = pd.read_csv(DATA_PATH)

app = FastAPI(
    title="Reading Fluency Prediction API",
    description="Predicts how many words per minute a primary school child can read, "
                "so mentorship programmes can find children who need reading support early.",
    version="1.0.0",
)

# ---------------------------------------------------------------
# CORS settings
# Allowed origins : only our Render URL and local test addresses.
#                   No "*" wildcard, so other websites are blocked.
# Allowed methods : GET and POST, the only ones this API uses.
# Allowed headers : Content-Type, needed to send JSON and CSV files.
# Credentials     : False, because the API uses no cookies or logins.
# The Flutter mobile app is not a browser, so CORS does not limit it.
# ---------------------------------------------------------------

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "https://YOUR-SERVICE-NAME.onrender.com",
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


def build_pipeline() -> Pipeline:
    """Same preprocessing and Random Forest settings as the best model in the notebook."""
    preprocessor = ColumnTransformer([
        ("categorical", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL_FEATURES),
        ("numeric", StandardScaler(), NUMERIC_FEATURES),
    ])
    forest = RandomForestRegressor(
        n_estimators=200, max_depth=12, min_samples_leaf=5, random_state=42, n_jobs=-1)
    return Pipeline([("preprocessor", preprocessor), ("model", forest)])


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
        new_data = pd.read_csv(io.BytesIO(await file.read()))
    except Exception:
        raise HTTPException(status_code=400, detail="The file could not be read as a CSV.")

    missing = [col for col in FEATURES + [TARGET] if col not in new_data.columns]
    if missing:
        raise HTTPException(status_code=400, detail=f"Missing columns: {missing}")

    new_data = new_data[FEATURES + [TARGET]].dropna()
    if new_data.empty:
        raise HTTPException(status_code=400, detail="The file has no complete rows.")

    # The best model is a Random Forest, so we refit it on the original data plus the new rows.
    combined = pd.concat([training_data, new_data], ignore_index=True)
    new_model = build_pipeline()
    new_model.fit(combined[FEATURES], combined[TARGET])

    model = new_model
    training_data = combined
    joblib.dump(model, MODEL_PATH, compress=3)

    return {
        "message": "Model retrained and now in use.",
        "new_rows_added": len(new_data),
        "total_training_rows": len(combined),
    }