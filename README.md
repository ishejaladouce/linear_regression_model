# Reading Fluency Predictor

## Mission
My mission is to nurture compassionate, responsible young leaders by equipping
children with practical life skills, character and opportunities to discover their talents.
Reading is the foundation of all of this, so this project predicts a child's reading
speed to help find children who need reading support early.

## Problem
Many early-grade pupils in East Africa cannot yet read fluently, and teachers often
find out too late. This model predicts how many words per minute (wpm) a child can
read correctly, using a few simple details about the child and their reading skills.

## Dataset
Early-grade reading assessment data on more than 200,000 pupils from **Ethiopia, Malawi,
Rwanda and Tanzania** (cleaned to 24,360 children aged 5 to 14).
Inputs: country, test language, school location, gender, age, grade,
familiar words per minute and listening comprehension (%).
Target: words read correctly per minute.

Source: [ https://doi.org/10.25828/2287-mw84 ]

## Model
I compared Linear Regression (SGD), Decision Tree and Random Forest using MSE and
Huber loss. The **Random Forest** had the lowest test error, so it is saved and used by the API.

## API (live)
- Swagger UI: https://reading-fluency-api-srxu.onrender.com/docs
- `POST /predict`: returns the predicted words per minute for one child
- `POST /retrain`: upload a CSV with new data to retrain the model

Note: the API is on Render's free plan, so the first request can take up to a minute while it wakes up.

## Video demo
[]

## How to run the mobile app
1. Install Flutter and start an Android emulator (or connect a phone).
2. Clone this repository:
   `git clone https://github.com/ishejaladouce/linear_regression_model.git`
3. Go to the app folder:
   `cd linear_regression_model/summative/FlutterApp`
4. Install the packages: `flutter pub get`
5. Run the app: `flutter run`
6. Fill in all 8 fields (e.g. Rwanda, Kinyarwanda, Rural, Female, 9, 3, 25, 60)
   and tap **Predict**.

## Repository structure

linear_regression_model/
├── README.md
├── .gitignore
└── summative/
    ├── .python-version
    ├── pyproject.toml                       # Python packages (uv)
    ├── uv.lock
    ├── data/
    │   ├── ahead_reading_fluency.csv        # cleaned dataset
    │   └── new_data_sample.csv              # 30 new rows to test /retrain
    ├── linear_regression/
    │   └── multivariate.ipynb               # data, charts, models, best model
    ├── API/
    │   ├── prediction.py                    # FastAPI app (predict + retrain)
    │   ├── requirements.txt                 # packages for Render
    │   ├── best_model.pkl                   # saved Random Forest
    │   └── training_data.csv                # data used when retraining
    └── FlutterApp/
        ├── lib/main.dart                    # the mobile app
        └── pubspec.yaml
