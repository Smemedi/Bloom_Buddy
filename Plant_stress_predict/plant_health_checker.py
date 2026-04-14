"""
Plant Health Checker
Predicts if a plant is healthy or unhealthy and provides the top reason if unhealthy.
"""

import pandas as pd
import numpy as np
import joblib
import shap
import os

# Load trained model artifacts
MODEL_DIR = "trained_models"

def load_artifacts():
    """Load the trained model, scaler, and label encoder."""
    model = joblib.load(os.path.join(MODEL_DIR, "extratreesclassifier_model.joblib"))
    scaler = joblib.load(os.path.join(MODEL_DIR, "scaler.joblib"))
    label_encoder = joblib.load(os.path.join(MODEL_DIR, "label_encoder.joblib"))
    return model, scaler, label_encoder

def get_top_stress_cause(model, scaler, sample_scaled, model_ex=None):
    """Get the top cause of plant stress using SHAP values."""
    if model_ex is None:
        model_ex = shap.TreeExplainer(model)
    
    sv = model_ex.shap_values(sample_scaled, check_additivity=False)
    pred_class = model.predict(sample_scaled)[0]
    class_index = list(model.classes_).index(pred_class)
    
    # Handle different SHAP output formats
    if isinstance(sv, list):
        values = sv[class_index][0]
    elif len(sv.shape) == 3:
        values = sv[0, :, class_index]
    else:
        values = sv[0]
    
    impact = pd.Series(values, index=scaler.feature_names_in_)
    top_cause = impact.abs().sort_values(ascending=False).head(1)
    return top_cause.index[0], top_cause.values[0]

def check_plant_health(plant_data: dict):
    """
    Check plant health status and return diagnosis.
    
    Parameters:
    -----------
    plant_data : dict
        Dictionary with feature names as keys and values as measurements.
        
    Returns:
    --------
    dict with 'status', 'prediction', and 'top_cause' (if unhealthy)
    """
    model, scaler, label_encoder = load_artifacts()
    
    # Create DataFrame from input
    df = pd.DataFrame([plant_data])
    
    # Ensure columns match expected features
    expected_features = scaler.feature_names_in_.tolist()
    missing = set(expected_features) - set(df.columns)
    if missing:
        raise ValueError(f"Missing required features: {missing}")
    
    # Reorder columns to match scaler
    df = df[expected_features]
    
    # Scale the data
    sample_scaled = scaler.transform(df)
    
    # Make prediction
    prediction = model.predict(sample_scaled)[0]
    
    # Get confidence score (probability of predicted class)
    probabilities = model.predict_proba(sample_scaled)[0]
    confidence = float(probabilities[prediction]) * 100  # Convert to percentage
    
    # Decode prediction
    status = label_encoder.inverse_transform([prediction])[0]
    
    result = {
        "status": status,
        "prediction": int(prediction),
        "confidence": round(confidence, 2),
        "is_healthy": prediction == 0  # Assuming 0 is healthy
    }
    
    # If unhealthy, get the top cause
    if prediction != 0:
        cause_name, cause_impact = get_top_stress_cause(model, scaler, sample_scaled)
        result["top_cause"] = cause_name
        result["cause_impact"] = float(cause_impact)
        result["recommendation"] = f"Adjust {cause_name}"
    
    return result

def interactive_mode():
    """Run interactive mode to input plant data manually."""
    print("=" * 60)
    print("        PLANT HEALTH CHECKER")
    print("=" * 60)
    
    model, scaler, label_encoder = load_artifacts()
    features = scaler.feature_names_in_.tolist()
    
    print(f"\nRequired features ({len(features)}):")
    for i, feat in enumerate(features, 1):
        print(f"  {i}. {feat}")
    
    print("\n" + "-" * 60)
    print("Enter values for each feature (or 'q' to quit):")
    print("-" * 60)
    
    plant_data = {}
    for feat in features:
        while True:
            value = input(f"{feat}: ").strip()
            if value.lower() == 'q':
                print("Exiting...")
                return
            try:
                plant_data[feat] = float(value)
                break
            except ValueError:
                print("  Invalid input. Please enter a numeric value.")
    
    # Check health
    print("\n" + "=" * 60)
    print("DIAGNOSIS RESULT")
    print("=" * 60)
    
    result = check_plant_health(plant_data)
    
    print(f"\nPlant Status: {result['status']}")
    print(f"Confidence: {result['confidence']:.1f}%")
    
    if result['is_healthy']:
        print("\n Your plant is HEALTHY!")
    else:
        print(f"\n Your plant is UNHEALTHY")
        print(f"\nTop Cause: {result['top_cause']}")
        print(f"Recommendation: {result['recommendation']}")

def check_from_csv(csv_path: str, output_path: str = None):
    """
    Check plant health for multiple samples from a CSV file.
    
    Parameters:
    -----------
    csv_path : str
        Path to CSV file with plant data
    output_path : str, optional
        Path to save results CSV
    """
    print(f"Loading data from: {csv_path}")
    df = pd.read_csv(csv_path)
    
    model, scaler, label_encoder = load_artifacts()
    model_ex = shap.TreeExplainer(model)
    
    results = []
    for idx, row in df.iterrows():
        plant_data = row.to_dict()
        
        # Remove target column if present
        plant_data.pop('Crop_Health_Label', None)
        
        try:
            result = check_plant_health(plant_data)
            result['row_index'] = idx
            results.append(result)
        except Exception as e:
            results.append({
                'row_index': idx,
                'status': 'ERROR',
                'error': str(e)
            })
    
    results_df = pd.DataFrame(results)
    
    if output_path:
        results_df.to_csv(output_path, index=False)
        print(f"Results saved to: {output_path}")
    
    return results_df

if __name__ == "__main__":
    import argparse
    
    parser = argparse.ArgumentParser(description="Plant Health Checker")
    parser.add_argument("--csv", type=str, help="Path to CSV file with plant data")
    parser.add_argument("--output", type=str, help="Path to save results (only with --csv)")
    
    args = parser.parse_args()
    
    if args.csv:
        results = check_from_csv(args.csv, args.output)
        print("\nResults:")
        print(results.to_string())
    else:
        interactive_mode()
