# Bloom Buddy

An application to optimize your garden and take care of your plants. Features include a plant scanner to detect the health of the plant, a task calendar to monitor and organize tasks, a statistics dashboard that uploads live data from our companion sensor device, and a chat forum to engage in a community of other gardeners.

## How It's Made:

**Tech Used**: 
Training model: ExtraTrees, SHAP, [Elijah's P model]
Database: [Elijah's H Database]
Backend: 
Frontend:

## Optimizations

Training model: Optimized the ML pipeline through feature engineering, class balancing (SMOTE/ADASYN/Random Resampling comparison), model benchmarking (11 classifiers), hyperparameter tuning via grid search, and accuracy-storage trade-off analysis. Final model uses ExtraTreesClassifier with optimized parameters for edge deployment.

## Lessons Learned

- Eileen Garay: learned how to address class imbalance by comparing popular oversampling techniques (SMOTE, ADASYN, Random Resampling). Additionally, I gained experience in hyperparameter optimization through grid search, testing various combinations of n_estimators and max_depth to balance model accuracy and storage efficiency.

## Team
<a href="https://github.com/Smemedi/Bloom_Buddy/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=Smemedi/Bloom_Buddy" />
</a>

Co-lead: Victoria Li
Co-lead: Zuha Ansari

Database: Elijah Hoedl
Training Models: Eileen Garay & Elijah Perez

Backend: Sokol Memedi
UI/UX: Ariah Pittman

## Arduino Instructions
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
