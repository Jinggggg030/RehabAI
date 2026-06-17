import numpy as np
import pandas as pd
import os
import json
import math

def calculate_angle(p1, p2, p3):
    # p1, p2, p3 are (x,y) coordinates. p2 is the vertex.
    # Angle between p1-p2 and p3-p2
    v1 = p1 - p2
    v2 = p3 - p2
    
    dot = np.sum(v1 * v2, axis=-1)
    mag1 = np.linalg.norm(v1, axis=-1)
    mag2 = np.linalg.norm(v2, axis=-1)
    
    # Avoid division by zero
    mag_product = mag1 * mag2
    # Where mag_product is zero, angle is 0
    safe_mag_product = np.where(mag_product == 0, 1.0, mag_product)
    cos_angle = dot / safe_mag_product
    # Clip to avoid numerical issues outside [-1, 1]
    cos_angle = np.clip(cos_angle, -1.0, 1.0)
    
    angles = np.arccos(cos_angle)
    return np.degrees(angles)

# Joint mappings from joints_names.txt
J = {
    'Hips': 0, 'Spine': 1, 'Neck': 3,
    'LShoulder': 6, 'LArm': 7, 'LForeArm': 8, 'LHand': 9,
    'RShoulder': 11, 'RArm': 12, 'RForeArm': 13, 'RHand': 14,
    'LUpLeg': 16, 'LLeg': 17, 'LFoot': 18,
    'RUpLeg': 21, 'RLeg': 22, 'RFoot': 23
}

def extract_features(data_chunk):
    # data_chunk is (Frames, 26, 2)
    # Extract mean, min, max of important angles
    if len(data_chunk) == 0:
        return None
        
    angles = {
        'L_Elbow': calculate_angle(data_chunk[:, J['LArm']], data_chunk[:, J['LForeArm']], data_chunk[:, J['LHand']]),
        'R_Elbow': calculate_angle(data_chunk[:, J['RArm']], data_chunk[:, J['RForeArm']], data_chunk[:, J['RHand']]),
        'L_Knee': calculate_angle(data_chunk[:, J['LUpLeg']], data_chunk[:, J['LLeg']], data_chunk[:, J['LFoot']]),
        'R_Knee': calculate_angle(data_chunk[:, J['RUpLeg']], data_chunk[:, J['RLeg']], data_chunk[:, J['RFoot']]),
        'L_Hip': calculate_angle(data_chunk[:, J['Spine']], data_chunk[:, J['Hips']], data_chunk[:, J['LUpLeg']]),
        'R_Hip': calculate_angle(data_chunk[:, J['Spine']], data_chunk[:, J['Hips']], data_chunk[:, J['RUpLeg']]),
        'L_Shoulder': calculate_angle(data_chunk[:, J['Hips']], data_chunk[:, J['LShoulder']], data_chunk[:, J['LArm']]),
        'R_Shoulder': calculate_angle(data_chunk[:, J['Hips']], data_chunk[:, J['RShoulder']], data_chunk[:, J['RArm']])
    }
    
    features = {}
    for k, v in angles.items():
        features[f"{k}_min"] = float(np.min(v))
        features[f"{k}_max"] = float(np.max(v))
        features[f"{k}_mean"] = float(np.mean(v))
        
    return features

def main():
    print("Loading segmentation data...")
    df = pd.read_csv('assets/exercise_sources/Segmentation.csv', sep=';')
    
    # We will store aggregate stats per exercise_id
    # exercise_id -> { 'correct': [features1, features2], 'incorrect': [...] }
    results = {}
    
    print("Processing .npy files...")
    base_dir = 'assets/exercise_sources/2d joints'
    
    # Map video_id to actual files. Files are like Ex1\PM_000-c17-120fps.npy
    # Let's find all npy files first
    npy_files = {}
    for root, dirs, files in os.walk(base_dir):
        for file in files:
            if file.endswith('.npy'):
                # Extract video_id, e.g., 'PM_000' from 'PM_000-c17-120fps.npy'
                vid_id = file.split('-')[0]
                npy_files[vid_id] = os.path.join(root, file)

    count = 0
    for idx, row in df.iterrows():
        vid = row['video_id']
        ex_id = row['exercise_id']
        first = row['first_frame']
        last = row['last_frame']
        correct = row['correctness']
        
        if vid in npy_files:
            try:
                # To save memory, we could load file once per video, but since we are iterating
                # Let's just load it. 5k frames is small (~2MB).
                data = np.load(npy_files[vid])
                
                # Check bounds
                if last < data.shape[0]:
                    chunk = data[first:last+1]
                    feats = extract_features(chunk)
                    
                    if feats:
                        if ex_id not in results:
                            results[ex_id] = {'correct': [], 'incorrect': []}
                            
                        if correct == 1:
                            results[ex_id]['correct'].append(feats)
                        else:
                            results[ex_id]['incorrect'].append(feats)
                            
                        count += 1
            except Exception as e:
                pass
                
        if count % 100 == 0 and count > 0:
            print(f"Processed {count} repetitions...")

    print(f"Total repetitions processed: {count}")
    
    # Calculate global thresholds for each exercise
    heuristics = {}
    for ex_id, stats in results.items():
        heuristics[ex_id] = {}
        
        # Aggregate correct
        if len(stats['correct']) > 0:
            df_c = pd.DataFrame(stats['correct'])
            heuristics[ex_id]['correct_avg_min'] = df_c.mean().to_dict()
        
        # Aggregate incorrect
        if len(stats['incorrect']) > 0:
            df_i = pd.DataFrame(stats['incorrect'])
            heuristics[ex_id]['incorrect_avg_min'] = df_i.mean().to_dict()
            
    with open('assets/exercise_sources/heuristics.json', 'w') as f:
        json.dump(heuristics, f, indent=2)
        
    print("Saved heuristics to assets/exercise_sources/heuristics.json")

if __name__ == '__main__':
    main()
