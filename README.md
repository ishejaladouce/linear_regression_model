# Reading Fluency Predictor

## Mission and Problem
My mission is to nurture compassionate, responsible young leaders by equipping children aged 7-12 with life skills, character and talent discovery through hands-on learning, mentorship and community service, so they grow into confident individuals who positively impact their families, communities and the world.

**Problem:** many children cannot read fluently, and it is noticed too late, so this app predicts reading speed to help mentors support them early.

## Dataset
I used early-grade reading assessment data from **Ethiopia, Malawi, Rwanda and Tanzania**. After cleaning, it has **24,360 children** aged 5 to 14.
Each row describes one child: country, test language, school location, gender, age, grade, familiar words read per minute and listening comprehension (%).
The target is the number of **words a child reads correctly per minute**.

Source: https://doi.org/10.25828/2287-mw84 

## API (Swagger UI)
Test the API here: https://reading-fluency-api-srxu.onrender.com/docs

- `POST /predict`: send one child's details and get the predicted words per minute.
- `POST /retrain`: upload a CSV of new data and the model retrains straight away.
  You can try it with `summative/data/new_data_sample.csv`.

The API runs on Render's free plan, so the first request may take up to a minute while it wakes up.

## Video Demo
https://youtu.be/djErljtTemI?si=g7qDf7U4KWeiJDvp

## How to Run the Mobile App
1. Install [Flutter](https://docs.flutter.dev/get-started/install) and start an Android emulator, or connect your phone.
2. Clone this repository:
   ```
   git clone https://github.com/ishejaladouce/linear_regression_model.git
   ```
3. Open the app folder:
   ```
   cd linear_regression_model/summative/FlutterApp
   ```
4. Install the packages:
   ```
   flutter pub get
   ```
5. Run the app:
   ```
   flutter run
   ```
6. Fill in all 8 fields and tap **Predict**. For example: Rwanda, Kinyarwanda, Rural, Female, 9, 3, 25, 60.

## Model
I compared four types of models: Linear Regression with gradient descent (SGDRegressor), Linear Regression (closed form), Decision Tree and Random Forest. I trained SGD with both MSE and Huber loss, and I tuned the two tree models to stop them from overfitting.

| Model | Train MSE | Test MSE |
|---|---|---|
| **Random Forest (max_depth=12)** | 38.7 | **47.0** |
| Decision Tree (max_depth=8) | 47.6 | 53.0 |
| Linear Regression | 56.2 | 53.6 |
| SGD (MSE loss) | 56.2 | 53.7 |
| SGD (Huber loss) | 56.5 | 54.1 |
| Random Forest (untuned) | 13.8 | 56.8 |
| Decision Tree (untuned) | 7.7 | 94.7 |

The tuned **Random Forest** has the lowest test MSE (47.0, about 7 words per minute of error), so it is the model the API uses.

## Repository Structure

```
linear_regression_model/
├── README.md
└── summative/
    ├── pyproject.toml
    ├── uv.lock
    ├── data/
    │   ├── ahead_reading_fluency.csv      # cleaned dataset
    │   └── new_data_sample.csv            # new rows to test /retrain
    ├── linear_regression/
    │   └── multivariate.ipynb             # data, charts, models, best model
    ├── API/
    │   ├── prediction.py                  # FastAPI app (/predict and /retrain)
    │   ├── retrain.py                     # retraining logic
    │   ├── uv.lock
    │   ├── pyproject.toml
    │   ├── requirements.txt               # packages for Render
    │   ├── best_model.pkl                 # saved Random Forest
    │   └── training_data.csv              # data used when retraining
    └── FlutterApp/                        # Flutter mobile app
    ```