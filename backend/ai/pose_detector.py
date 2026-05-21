import cv2
import mediapipe as mp

class PoseDetector:
    def __init__(self, static_image_mode=False, model_complexity=1, 
                 smooth_landmarks=True, min_detection_confidence=0.5, 
                 min_tracking_confidence=0.5):
        
        # Initialize MediaPipe Pose tools
        self.mp_draw = mp.solutions.drawing_utils
        self.mp_pose = mp.solutions.pose
        
        # Setup the pose model with standard config
        self.pose = self.mp_pose.Pose(
            static_image_mode=static_image_mode,
            model_complexity=model_complexity,
            smooth_landmarks=smooth_landmarks,
            min_detection_confidence=min_detection_confidence,
            min_tracking_confidence=min_tracking_confidence
        )

    def find_pose(self, img, draw=True):
        """Processes the image and draws the pose landmarks."""
        # MediaPipe requires RGB images, but OpenCV reads in BGR.
        img_rgb = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)
        
        # Run the AI model
        self.results = self.pose.process(img_rgb)
        
        # Draw the skeleton on the image if requested
        if self.results.pose_landmarks and draw:
            self.mp_draw.draw_landmarks(
                img, 
                self.results.pose_landmarks, 
                self.mp_pose.POSE_CONNECTIONS
            )
        return img

    def get_position(self, img):
        """Extracts all 33 landmark positions into a clean list [id, x, y]."""
        lm_list = []
        if self.results.pose_landmarks:
            for id, lm in enumerate(self.results.pose_landmarks.landmark):
                h, w, c = img.shape
                # Convert normalized coordinates (0.0 - 1.0) to actual pixel coordinates
                cx, cy = int(lm.x * w), int(lm.y * h)
                lm_list.append([id, cx, cy])
        return lm_list
