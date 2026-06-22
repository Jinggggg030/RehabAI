import numpy as np
import pandas as pd
import os

print("--- Segmentation.csv ---")
try:
    df = pd.read_csv('assets/exercise_sources/Segmentation.csv', sep=';')
    print(df.head())
    print("Shape:", df.shape)
except Exception as e:
    print("Error reading CSV:", e)

print("\n--- .npy Files ---")
found = False
for root, dirs, files in os.walk('assets/exercise_sources'):
    for file in files:
        if file.endswith('.npy'):
            path = os.path.join(root, file)
            try:
                data = np.load(path)
                print(f"File: {path}")
                print(f"Shape: {data.shape}")
                print(f"Data type: {data.dtype}")
                found = True
                break
            except Exception as e:
                print("Error reading npy:", e)
    if found:
        break
