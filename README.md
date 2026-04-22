<p align="center">
  <img src="Images/Plant_Buddy.png" alt="App Logo" width="200">
</p>

# Bloom Buddy 

### Team
[![Contributors](https://contrib.rocks/image?repo=Smemedi/Bloom_Buddy)](https://github.com/Smemedi/Bloom_Buddy/graphs/contributors)

Co-lead: Victoria Li  
Co-lead: Zuha Ansari  
Database: Elijah Hoedl  
Training Models: [Eileen Garay](https://www.linkedin.com/in/eileen1129/) & Elijah Perez  
Backend: Sokol Memedi  
UI/UX: Ariah Pittman  

Course: DS 480 / IPRO 497  
Instructors: [Robert Ellis](https://www.linkedin.com/in/robert-ellis-6914463/) & Ananya Bhooplam Praveen   

## Summary

An application to optimize your garden and take care of your plants. Features include a plant scanner to detect the health of the plant, a task calendar to monitor and organize tasks, a statistics dashboard that uploads live data from our companion sensor device, and a chat forum to engage in a community of other gardeners.

**What problem are you solving?**  
We are solving the problem of the low community of gardeners, we want to bring more attention to the beautiful community by introducing a new way of gardening and farming. Instead of guessing whether the plant is healthy, we have the device to tell the client if their plant is healthy.  
**Why is it important?**  
Indoor and backyard farming improves mental well-being by reducing stress and creating a calming connection to nature. It also helps people grow fresh, healthy food at home, reducing reliance on store-bought produce and lowering food costs.  
**Who is the stakeholder/sponsor?**  
The stakeholders are the Chicagoans. 
**What are your key results?**  
From the machine learning side of the project, the model has a 88% accuracy score with the ability to tell the user why their plant is unhealthy. 

## Introduction
*this is more techinal*

- Background of the problem
- Context and motivation
- Why this problem matters
- Overview of your approach

## Project Structure
```
Bloom_Buddy/  
│── .vscode/                 # Development environment settings for Visual Studio Code  
│── Plant_stress_predict/    # Notebooks and models for plant stress analysis and prediction  
│── app/                     # Main application logic and user interface components  
│── arduino/                 # Embedded system code for sensor data collection  
│── Images/                  # Project images and visualizations  
│── README.md                # Comprehensive project documentation  
│── .gitattributes           # Repository configuration for consistent file handling
```
## Methodology

### Methodology for the ML plant stress prediction:

**1. Data Preprocessing**

- Dataset: Agricultural sensor data loaded from CSV
- Feature Selection: Dropped image-based features (RGB, multispectral, thermal, spatial) and kept edge-deployable sensor readings
- Encoding: Crop types encoded numerically (Wheat=0, Rice=1, Maize=2)  

**2. Exploratory Data Analysis**  

- Target distribution visualization (Crop_Health_Label)
- Feature correlation analysis with target
- Outlier detection using IQR method
- Distribution analysis (skewness, normality via Shapiro-Wilk, multimodality via KDE)
- Pairplots for top correlated features  

**3. Class Imbalance Handling**  
Three resampling strategies compared:  
- SMOTE - Synthetic minority oversampling
- ADASYN - Adaptive synthetic sampling
- Random Resampling - Combined under/oversampling to 300K balanced samples

**4. Model Training & Selection**  
- 80/20 train-test split with stratification
- StandardScaler normalization
- 11 classifiers evaluated: Logistic Regression, KNN, Decision Tree, Random Forest, Gradient Boosting, AdaBoost, ExtraTrees, Gaussian NB, XGBoost, LightGBM, CatBoost
- Metrics: Accuracy, F1-Score, AUC-ROC

**5. Hyperparameter Optimization**  
- Grid search on ExtraTreesClassifier (best performer)
- Parameters: n_estimators (100-250), max_depth (15-30, None)
- Trade-off analysis: accuracy vs model storage size

**6. Model Interpretability**  
- SHAP TreeExplainer for feature importance
- Directional impact analysis (which features push toward healthy/unhealthy)
- Top stress causes identification per sample

**7. Deployment Artifacts**  
- Model, scaler, and label encoder saved via joblib to trained_models/
- Integration with plant_health_checker.py for inference  
Final Model: ExtraTreesClassifier (n_estimators=150, max_depth=20) optimized for edge deployment with SHAP-based recommendations.  

## Result & Visualization

![ExrtaTreesMatrix](Images/ExtraTreesMatrix.png)

## Negative Result

# Software/Hardware Instructions

## Server Startup
```bash
# Open backend directory on current path
cd backend

# Create virtual environment for macOS
py -m venv env

# Activate virtual environment
  .\env\Scripts\activate

# Install packages
pip install -r requirements.txt

# Start server
uvicorn server:app --host 0.0.0.0 --port 8000
```
## App Startup
```bash
# Open app directory 
cd ..
cd app

# Update flutter
flutter doctor

# Grab dependencies
flutter pub get

# Run & choose specified device
flutter run
```

## Arduino Instructions
### Wiring Diagram
<p align="center">
  <img src="Images/wiring_diagram.png" alt="diagram for hardware">
</p>

### Setting Up Device
1. Connect the RS485 shield to the Arduino by slotting the shield's pins on top of the Arduino's slots
2. Use a USB cable to connect the device to a computer
3. Open the Arduino IDE and select the right board and port
### Setting Up Sensors
1. Connect only the soil sensor and use the Arduino IDE to upload the "Set_Soil_Sensor_ID.ino"
2. After running it, power cycle the sensor by turning it off, then on again
3. Disconnect the soil sensor and plug in the light sensor
4. Upload the "Set_Light_BAUD_Rate.ino" and power cycle the device
### Assembling Device
1. Plug in each wire to its respective slot
2. Make sure no wires are touching another port's wires and that every wire is connected in the right place
3. Upload "Sensor_Reading.ino" to device

## Data Access
[Crop Health Dataset](https://www.kaggle.com/datasets/datasetengineer/crop-health-and-environmental-stress-dataset/data)

## Conclusion

## What did we learned?

- Eileen Garay: learned how to address class imbalance by comparing popular oversampling techniques (SMOTE, ADASYN, Random Resampling). Additionally, I gained experience in hyperparameter optimization through grid search, testing various combinations of n_estimators and max_depth to balance model accuracy and storage efficiency.

## Future Work
