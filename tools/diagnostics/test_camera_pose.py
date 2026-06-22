import cv2
from backend.ai.pose_detector import PoseDetector
from backend.ai.angle_calculator import calculate_angle

def main():
    # 0 is usually the default built-in webcam
    cap = cv2.VideoCapture(0)
    
    # Initialize our custom AI engine
    detector = PoseDetector()

    while True:
        # Read the live frame from the webcam
        success, img = cap.read()
        if not success:
            print("Failed to access the webcam.")
            break
            
        # Optional: Flip the image horizontally like a mirror for a better user experience
        img = cv2.flip(img, 1)

        # 1. Feed the image into the AI to find the pose and draw the skeleton
        img = detector.find_pose(img, draw=True)
        
        # 2. Extract all the landmark coordinates
        lm_list = detector.get_position(img)
        
        # 3. Calculate the Right Arm (Elbow) Angle
        if len(lm_list) != 0:
            # MediaPipe Landmark IDs for the Right Arm:
            # 12: Right Shoulder, 14: Right Elbow, 16: Right Wrist
            
            # Extract only the X,Y coordinates [1:3] from the list
            shoulder = lm_list[12][1:3]
            elbow = lm_list[14][1:3]
            wrist = lm_list[16][1:3]
            
            # Use our custom math function
            angle = calculate_angle(shoulder, elbow, wrist)
            
            # 4. Display the angle directly on the screen near the elbow
            # cv2.putText(image, text, (x, y), font, fontScale, color(BGR), thickness)
            cv2.putText(img, f"{int(angle)} deg", (elbow[0] + 15, elbow[1] - 15), 
                        cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 0, 255), 3)

        # Show the video window
        cv2.imshow("Rehab AI - Live Posture Detection", img)

        # Press 'q' on your keyboard to quit the window
        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    main()
