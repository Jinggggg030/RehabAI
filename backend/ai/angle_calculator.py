import numpy as np

def calculate_angle(a, b, c):
    """
    Calculates the angle between three points (a, b, c).
    'b' is the middle point (the joint).
    Points should be given as [x, y] coordinates.
    """
    a = np.array(a) # First point (e.g. Shoulder)
    b = np.array(b) # Mid point (e.g. Elbow)
    c = np.array(c) # End point (e.g. Wrist)
    
    # Calculate the angle using arctangent
    radians = np.arctan2(c[1]-b[1], c[0]-b[0]) - np.arctan2(a[1]-b[1], a[0]-b[0])
    angle = np.abs(radians * 180.0 / np.pi)
    
    # Ensure the angle is always between 0 and 180 degrees
    if angle > 180.0:
        angle = 360 - angle
        
    return angle
