import re
import json

class RehabChatbot:
    def __init__(self):
        # Phase 5: Emergency Keywords
        self.emergency_keywords = [
            r'\b(cannot breathe|can\'t breathe|shortness of breath|not breathing)\b',
            r'\b(chest pain|heart attack|stroke)\b',
            r'\b(paralysed|paralyzed|paralysis)\b',
            r'\b(lost consciousness|passed out|faint|fainted)\b',
            r'\b(emergency|urgent|ambulance)\b'
        ]

        # Phase 3 Categories (for Scoring)
        self.categories = {
            "Musculoskeletal": [
                r'\b(shoulder|arm|elbow|wrist|hand|knee|ankle|foot|bone|fracture|joint|muscle|back|neck|spine)\b',
                r'\b(sprain|strain|ache|aching|hurt|pain|stiff)\b'
            ],
            "Neurological": [
                r'\b(stroke|paralysis|nerve|brain|spinal cord|balance|dizzy|parkinson|multiple sclerosis|numbness|tingling|twitch)\b'
            ],
            "Cardiopulmonary": [
                r'\b(breathing|lung|asthma|chest|coughing|copd|heart)\b'
            ],
            "Sports": [
                r'\b(sports|running|athlete|athletic|torn|acl|meniscus|game|match|gym|workout)\b'
            ],
            "Geriatric": [
                r'\b(elderly|old|aging|fall|arthritis|osteoporosis|weakness|mobility|senior)\b'
            ],
            "Pediatric": [
                r'\b(child|baby|kid|infant|toddler|cerebral palsy|development|growth)\b'
            ],
            "Pelvic Floor": [
                r'\b(pelvic|pregnancy|bladder|incontinence|postpartum|women)\b'
            ]
        }

        # Extraction logic patterns
        self.severity_patterns = {
            "High": r'\b(severe|unbearable|extremely|very bad|10|9|8|sharp|extreme)\b',
            "Moderate": r'\b(moderate|some|a bit|7|6|5|4|dull|annoying)\b',
            "Low": r'\b(mild|low|little|1|2|3|slight)\b'
        }
        
        self.duration_patterns = {
            "Acute": r'\b(today|yesterday|suddenly|just now|days|week)\b',
            "Sub-acute": r'\b(weeks|month|a while)\b',
            "Chronic": r'\b(months|years|long time|always|forever)\b'
        }

    def process_message(self, user_message: str, current_state: dict) -> tuple[dict, str, str]:
        """
        Takes the user message and the current triage_data (dict).
        Returns updated_state (dict), response_message (str), and session_status (str: 'Triage', 'Active', 'Emergency').
        """
        if not current_state:
            current_state = {
                "pain_area": None,
                "severity": None,
                "duration": None,
                "discipline": None,
                "history": [] # stores all user messages for final scoring
            }
        
        msg_lower = user_message.lower()
        current_state["history"].append(msg_lower)

        # Phase 5: Check for Emergency
        for pattern in self.emergency_keywords:
            if re.search(pattern, msg_lower):
                return current_state, "System: Your symptoms may require urgent medical attention. Please contact emergency services or visit the nearest healthcare facility immediately.", "Emergency"

        # Phase 1: Extract Data
        # Extract pain area (by checking all body part words)
        if not current_state["pain_area"]:
            for cat, patterns in self.categories.items():
                for pat in patterns:
                    match = re.search(pat, msg_lower)
                    if match:
                        current_state["pain_area"] = match.group(0).title()
                        break
                if current_state["pain_area"]:
                    break

        if not current_state["severity"]:
            for sev, pattern in self.severity_patterns.items():
                if re.search(pattern, msg_lower):
                    current_state["severity"] = sev
                    break
                    
            # Check for generic pain words without severity modifier
            if not current_state["severity"] and re.search(r'\b(pain|hurt)\b', msg_lower):
                pass # Still unknown, need to ask

        if not current_state["duration"]:
            for dur, pattern in self.duration_patterns.items():
                if re.search(pattern, msg_lower):
                    current_state["duration"] = dur
                    break

        # Phase 2: Clarification Questions (Ask one at a time)
        if not current_state["pain_area"]:
            return current_state, "System: I understand you are seeking help. Which specific body part is affected? (e.g., Neck, Shoulder, Back, Knee, Ankle)", "Triage"
        
        if not current_state["duration"]:
            return current_state, f"System: How long have you experienced this {current_state['pain_area'].lower()} issue? (e.g., less than a week, a few weeks, or more than a month)", "Triage"
            
        if not current_state["severity"]:
            return current_state, f"System: How severe is the issue on a scale of 1 to 10? (Or describe it as mild, moderate, or severe)", "Triage"

        # Phase 3: All information gathered, check for confirmation
        if not current_state.get("confirmed"):
            scores = {cat: 0 for cat in self.categories.keys()}
            full_text = " ".join(current_state["history"])
            
            for cat, patterns in self.categories.items():
                for pat in patterns:
                    matches = re.findall(pat, full_text)
                    scores[cat] += len(matches)
                    
            best_discipline = max(scores, key=scores.get)
            if scores[best_discipline] == 0:
                best_discipline = "Musculoskeletal"
                
            current_state["discipline"] = best_discipline
            
            # Ask for confirmation
            if msg_lower in ['yes', 'yeah', 'yep', 'correct', 'right', 'ok']:
                current_state["confirmed"] = True
                final_msg = (
                    f"System: Thank you for confirming. "
                    f"Based on your symptoms, we are assigning you to a **{best_discipline}** physiotherapist. Please wait while we connect you."
                )
                return current_state, final_msg, "Active"
            elif msg_lower in ['no', 'nope', 'incorrect', 'wrong']:
                # Reset extraction
                current_state["pain_area"] = None
                current_state["severity"] = None
                current_state["duration"] = None
                current_state["history"] = []
                return current_state, "System: Let's try again. Which specific body part is affected?", "Triage"
            else:
                # If first time reaching here, or user typed something else
                final_msg = (
                    f"System: Triage complete. Here is my assessment:\n"
                    f"- Area: {current_state['pain_area']}\n"
                    f"- Severity: {current_state['severity']}\n"
                    f"- Duration: {current_state['duration']}\n\n"
                    f"Is this correct? (Please reply 'Yes' to confirm or 'No' to restart)"
                )
                # Keep status as Triage until confirmed
                return current_state, final_msg, "Triage"
        else:
            return current_state, "System: You are already connected. Please wait for the physiotherapist.", "Active"

chatbot_instance = RehabChatbot()
