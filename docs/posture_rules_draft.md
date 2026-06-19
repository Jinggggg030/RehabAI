# Posture-detection rules (video-validated)

These rules use the supplied `reference_joint_angle` as a clinical hint, but
map it to the actual pose-landmark geometry seen by the camera. A posture is
accepted only after all required checks remain valid for several consecutive
frames.

| ID | Exercise | Camera guidance | Required posture checks | Initial accepted range | Video status |
|---:|---|---|---|---|---|
| 1 | Half-Kneel Hip Flexor Stretch | Side view; front hip, knee and ankle visible | Front knee angle only | Front knee 80–100° | Validated |
| 3 | Bridging | Side view; hips, both knees and feet visible | Left/right knee angle only | Knee angle 80–100° | Validated |
| 7 | Side-Lying Hip Abduction | Side view; both whole legs visible from hip to ankle | Angle between the raised whole-leg line and lower whole-leg line; raised leg remains straight | Whole-leg separation 35–55°; raised knee 155–180° | Validated |
| 41 | Wall Sit | Side or diagonal view; both knees visible | Left/right knee angle only | Knee angle 80–100° | Validated |
| 62 | Bicep Curl Hold | Side/diagonal view; active arm and wrist visible | Shoulder–elbow–wrist angle; wrist raised toward shoulder | Active arm angle 35–55°; wrist above elbow and near shoulder | Validated |
| 69 | Bodyweight Squat | Side/diagonal view; hips, knees and ankles visible | Left/right knee angle; thigh position | Knee angle 80–100°; hip-to-knee thigh line within 20° of horizontal | Draft—no video supplied |

## How the stored reference values are interpreted

- IDs 1, 3 and 41: `90°` is the knee target.
- ID 7: `45°` is the angle between the two whole-leg lines (hip to ankle).
- ID 62: `45°` is the shoulder–elbow–wrist angle, with wrist position used as
  an additional direction check.
- ID 69: `90°` is the knee target; thigh position is checked separately.

## Scoring and safety rules

- Require every mandatory landmark to have adequate detection likelihood.
- Require 8 consecutive correct frames before reporting a correct posture.
- Use separate feedback for each failed check, including measured and target
  angles.
- Never average away a failed required joint. A required joint outside its
  range makes the posture incorrect.
- Allow either elbow for the unilateral bicep curl, but keep the chosen side
  consistent while evaluating a hold.
- Do not score while required body parts are outside the frame.
- Treat the ranges above as initial values that require on-device calibration.

## Implementation status

These checks are connected to `PostureAnalyzer` through
`assets/exercise_sources/posture_rules.json`. The analyzer requires every
configured check to pass and stabilizes the result over eight frames.
