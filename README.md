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
