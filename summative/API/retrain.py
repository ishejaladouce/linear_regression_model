"""Retrains the model when new data is uploaded."""

import io
from pathlib import Path

import joblib
import pandas as pd
from sklearn.compose import ColumnTransformer
from sklearn.ensemble import RandomForestRegressor
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import OneHotEncoder, StandardScaler

CATEGORICAL_FEATURES = ["country", "language", "location", "gender"]
NUMERIC_FEATURES = ["age", "grade", "familiar_words_per_min", "listening_comprehension_pct"]
FEATURES = CATEGORICAL_FEATURES + NUMERIC_FEATURES
TARGET = "words_per_minute"


def build_pipeline() -> Pipeline:
    """Same preprocessing and Random Forest settings as the best model in the notebook."""
    preprocessor = ColumnTransformer([
        ("categorical", OneHotEncoder(handle_unknown="ignore"), CATEGORICAL_FEATURES),
        ("numeric", StandardScaler(), NUMERIC_FEATURES),
    ])
    forest = RandomForestRegressor(
        n_estimators=200, max_depth=12, min_samples_leaf=5, random_state=42, n_jobs=-1)
    return Pipeline([("preprocessor", preprocessor), ("model", forest)])


def retrain_model(csv_bytes: bytes, training_data: pd.DataFrame, model_path: Path):
    """Refit the model on the old data plus the new CSV rows.

    Returns the new model, the combined data and the number of new rows.
    Raises ValueError with a readable message if the file is not usable.
    """
    try:
        new_data = pd.read_csv(io.BytesIO(csv_bytes))
    except Exception as error:
        raise ValueError("The file could not be read as a CSV.") from error

    missing = [col for col in FEATURES + [TARGET] if col not in new_data.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")

    new_data = new_data[FEATURES + [TARGET]].dropna()
    if new_data.empty:
        raise ValueError("The file has no complete rows.")

    # The best model is a Random Forest, so we refit it on the original data plus the new rows.
    combined = pd.concat([training_data, new_data], ignore_index=True)
    new_model = build_pipeline()
    new_model.fit(combined[FEATURES], combined[TARGET])
    joblib.dump(new_model, model_path, compress=3)

    return new_model, combined, len(new_data)