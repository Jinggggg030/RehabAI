# Rep-count movement rules (video-validated)

Implementation status: connected to `MovementAnalyzer` through
`assets/exercise_sources/rep_count_rules.json`. Thresholds are initial
normalized values and should be tuned with on-device trials.

Each repetition is counted only after the detector observes a stable
`start -> end -> start` cycle. Both start and end states must remain stable for
several camera frames to reject landmark jitter.

| ID | Exercise | Camera guidance | Start state | End state | Primary pose landmarks | Expected reliability |
|---:|---|---|---|---|---|---|
| 4 | Side-Lying Clamshell | Side view; hips, both knees and feet visible | Knees together and bent; feet together | Top knee separated upward while feet remain together | Left/right hip, knee, ankle | Medium: overlapping legs can swap landmarks |
| 6 | Straight Leg Raise | Side view; entire body and active leg visible | Active leg straight and close to the mat | Active straight leg raised; knee remains extended | Shoulder, hip, knee, ankle | Medium: horizontal-body pose detection must be tested |
| 9 | Step-Up | Side view as demonstrated; entire step and both feet visible | Both feet on floor | Lead foot is on step and body has risen onto it | Hips, knees, ankles | High |
| 18 | Standing Heel Raise | Front view; knees and complete feet visible | Both feet flat | Both heels raised while forefeet remain grounded | Knees, heels, foot-index landmarks | Low/medium: heel displacement is small from the front |
| 19 | Seated Toe Raise | Front/diagonal; chair, knees and complete feet visible | Forefeet flat | Toes/forefeet raised while heels remain grounded | Knees, heels, foot-index landmarks | Low/medium: foot landmarks are small and may jitter |
| 23 | Supine Wand Flexion | Side view as demonstrated; hips through hands visible | Wand at hips/thighs with arms lowered | Wand raised above the chest/head with arms elevated | Shoulders, elbows, wrists | Medium: lying pose and wand are not directly detected |
| 37 | Prone Back Extension (`Back Curl`) | Side view; hips and upper body visible | Chest and shoulders lowered near mat | Chest and shoulders lifted while hips remain down | Ears/nose, shoulders, hips | Medium: horizontal-body pose detection must be tested |
| 42 | Push-Up | Side view; wrists through ankles visible | Arms extended and body elevated | Chest lowered and elbows bent | Shoulders, elbows, wrists, hips, ankles | High |
| 53 | Sit-to-Stand | Side/diagonal; chair and full body visible | Seated, hips near chair and knees bent | Fully standing with hips and knees extended | Shoulders, hips, knees, ankles | High |
| 57 | Seated Knee Extension | Side/diagonal; active leg completely visible | Active knee bent and foot below knee | Active lower leg extended forward | Hip, knee, ankle | High |
| 59 | Sitting External Rotation | Front view; both elbows and hands visible | Hands closer together; elbows held beside torso | Both hands move outward while elbows remain beside torso | Shoulders, elbows, wrists | High |
| 61 | Low Row | Side view; torso and both arms visible | Arms extended forward | Elbows and hands pulled back beside torso | Shoulders, elbows, wrists, hips | High |
| 66 | Single-Arm Wall Press | Side view; wall hand and whole body visible | Arm straight and body away from wall | Elbow bent and aligned torso moves toward wall | Wrist, elbow, shoulder, hip, knee, ankle | High |
| 71 | Shoulder Press | Front view; hips through hands visible | Hands at shoulder height | Both hands extended overhead | Shoulders, elbows, wrists | High |

## Counting safeguards

- Require at least five consecutive frames in each movement state.
- Count only on the return to the start state.
- Require the same detected body side throughout one repetition.
- Add a short post-count cooldown to prevent duplicate counts.
- Pause counting when required landmarks are missing or have low likelihood.
- Normalize distances using torso or limb length instead of raw pixels.

## Exercises needing device testing first

IDs 4, 6, 18, 19, 23 and 37 need on-device trials before final thresholds are
chosen. They contain overlapping legs, small foot movements, or a horizontal
body orientation, all of which can be less stable in a phone pose detector.
