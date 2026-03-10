# plant_stress_predictor.py
"""
Plant Stress Detection Module
Load trained model and make predictions with explanations.
"""

import pandas as pd
import joblib
import shap
from sklearn.preprocessing import StandardScaler


class PlantStressPredictor:
    def __init__(self, model_path="trained_models/Random_Forest.pkl"):
        """Initialize the predictor with a trained model."""
        self.model = joblib.load(model_path)
        self.explainer = shap.TreeExplainer(self.model)
        self.scaler = StandardScaler()
        self.feature_columns = None
        self.is_fitted = False
        
    def fit_scaler(self, X_train):
        """Fit the scaler on training data."""
        self.scaler.fit(X_train)
        self.feature_columns = list(X_train.columns)
        self.is_fitted = True
        
    def preprocess_input(self, data):
        """
        Preprocess raw input data.
        
        Args:
            data: dict or DataFrame with plant sensor readings
            
        Returns:
            Scaled numpy array ready for prediction
        """
        if isinstance(data, dict):
            data = pd.DataFrame([data])
        
        df = data.copy()
        
        # Parse timestamp and create time features if present
        if "Timestamp" in df.columns:
            df["Timestamp"] = pd.to_datetime(df["Timestamp"], errors="coerce")
            df["Hour"] = df["Timestamp"].dt.hour
            df["DayOfWeek"] = df["Timestamp"].dt.dayofweek
            df["Month"] = df["Timestamp"].dt.month
            df["WeekOfYear"] = df["Timestamp"].dt.isocalendar().week.astype(int)
            df["IsWeekend"] = (df["DayOfWeek"] >= 5).astype(int)
        
        # Drop non-feature columns
        drop_cols = ["Plant_Health_Status", "Timestamp", "Plant_ID", "Week", "Nitrogen_Level"]
        df = df.drop(columns=[c for c in drop_cols if c in df.columns], errors="ignore")
        
        # Ensure columns match training features
        if self.feature_columns:
            for col in self.feature_columns:
                if col not in df.columns:
                    df[col] = 0
            df = df[self.feature_columns]
        
        # Scale the data
        if self.is_fitted:
            return self.scaler.transform(df)
        else:
            raise ValueError("Scaler not fitted. Call fit_scaler() first or load a fitted scaler.")
    
    def predict(self, data):
        """
        Predict plant health status.
        
        Args:
            data: dict or DataFrame with plant sensor readings
            
        Returns:
            str: Predicted health status
        """
        scaled = self.preprocess_input(data)
        prediction = self.model.predict(scaled)
        return prediction[0]
    
    def predict_proba(self, data):
        """
        Get prediction probabilities for each class.
        
        Args:
            data: dict or DataFrame with plant sensor readings
            
        Returns:
            dict: Class probabilities
        """
        scaled = self.preprocess_input(data)
        probs = self.model.predict_proba(scaled)[0]
        return dict(zip(self.model.classes_, probs))
    
    def get_stress_causes(self, data, top_n=3):
        """
        Get top features causing the predicted stress level.
        
        Args:
            data: dict or DataFrame with plant sensor readings
            top_n: Number of top causes to return
            
        Returns:
            dict: Feature names and their SHAP impact values
        """
        scaled = self.preprocess_input(data)
        shap_values = self.explainer(scaled)
        
        pred_class = self.model.predict(scaled)[0]
        class_index = list(self.model.classes_).index(pred_class)
        
        # Get SHAP values for predicted class
        values = shap_values.values[0, :, class_index]
        
        # Create impact series
        impact = pd.Series(values, index=self.feature_columns)
        
        # Get top causes by absolute impact
        top_causes = impact.abs().sort_values(ascending=False).head(top_n)
        
        # Return with actual SHAP values (not absolute)
        return {feat: float(impact[feat]) for feat in top_causes.index}
    
    def generate_recommendations(self, data):
        """
        Generate recommendations based on stress causes.
        
        Args:
            data: dict or DataFrame with plant sensor readings
            
        Returns:
            list: Actionable recommendations
        """
        causes = self.get_stress_causes(data)
        prediction = self.predict(data)
        
        recommendations = []
        
        if prediction == "Healthy":
            recommendations.append("Plant is healthy. Maintain current conditions.")
        else:
            for feature, impact in causes.items():
                if impact > 0:
                    recommendations.append(f"Consider adjusting {feature} (currently contributing to stress)")
                else:
                    recommendations.append(f"Monitor {feature} levels")
        
        return recommendations
    
    def analyze(self, data):
        """
        Full analysis: prediction, probabilities, causes, and recommendations.
        
        Args:
            data: dict or DataFrame with plant sensor readings
            
        Returns:
            dict: Complete analysis results
        """
        return {
            "prediction": self.predict(data),
            "probabilities": self.predict_proba(data),
            "stress_causes": self.get_stress_causes(data),
            "recommendations": self.generate_recommendations(data)
        }
    
    def save_scaler(self, path="trained_models/scaler.pkl"):
        """Save the fitted scaler."""
        joblib.dump(self.scaler, path)
        
    def load_scaler(self, path="trained_models/scaler.pkl"):
        """Load a pre-fitted scaler."""
        self.scaler = joblib.load(path)
        self.is_fitted = True


# Example usage
if __name__ == "__main__":
    # Initialize predictor
    predictor = PlantStressPredictor("trained_models/Random_Forest.pkl")
    
    # Example: You would fit the scaler with your training data
    # predictor.fit_scaler(X_train)
    # predictor.save_scaler()
    
    # Or load a pre-saved scaler
    # predictor.load_scaler()
    
    # Example input
    sample_input = {
        "Timestamp": "2024-01-15 10:30:00",
        "Soil_Moisture": 45.2,
        "Temperature": 25.5,
        "Humidity": 60.0,
        "Light_Intensity": 800,
        "Phosphorus_Level": 30.5,
        "Potassium_Level": 25.0,
        "Chlorophyll_Content": 40.0,
        "Electrochemical_Signal": 0.5
    }
    
    # Get full analysis
    # result = predictor.analyze(sample_input)
    # print(result)