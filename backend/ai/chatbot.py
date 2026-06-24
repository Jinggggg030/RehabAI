import os
import json
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")

if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

class RehabChatbot:
    def __init__(self):
        self.system_prompt = """
You are a professional Physiotherapy Triage Assistant for the Rehab AI clinic.

Your task is to help collect:
- Pain Area
- Pain Point (e.g., sharp, dull, aching, or specific trigger)
- Severity
- Duration

Rules:
- Ask ONLY ONE question at a time.
- Be empathetic and concise.
- Extract information whenever the patient provides it.
- Do not ask for information that is already known.
- If the patient mentions chest pain, difficulty breathing, stroke symptoms, paralysis, severe trauma, loss of consciousness, or any life-threatening condition, set is_emergency to true.
- Do NOT ask for final confirmation.
- Do NOT decide when triage is complete.

Return ONLY valid JSON:
{
"response_message": "string",
"pain_area": "string or null",
"pain_point": "string or null",
"severity": "string or null",
"duration": "string or null",
"is_emergency": false
}
"""
        self.generation_config = {
            "temperature": 0.2,
            "response_mime_type": "application/json"
        }

    def classify_discipline(self, state):
        area = (state.get("pain_area") or "").lower()
        point = (state.get("pain_point") or "").lower()
        combined = f"{area} {point}"

        sports_keywords = [
            "ankle", "acl", "hamstring", "runner", "football", "basketball", 
            "sport", "sprain", "strain", "ligament", "meniscus", "knee sprain",
            "tennis elbow", "golfers elbow", "acl tear", "runner's knee", "tendinitis",
            "shin splints", "injury", "soccer", "tennis", "badminton", "gym",
            "workout", "muscle pull", "cramp", "achilles", "calf", "groin",
            "dislocation", "runner knee", "athletic", "exercise injury"
        ]

        neurological_keywords = [
            "numbness", "tingling", "stroke", "nerve", "sciatica", 
            "paralysis", "parkinson", "tremor", "hemiparesis", "burning",
            "numb", "tingle", "pins and needles", "pins & needles", "neuropathy",
            "stroke rehab", "paralyzed", "balance issue", "dizziness", "coordination",
            "weakness", "brain", "spine injury", "bell's palsy", "bells palsy",
            "carpal tunnel syndrome", "pinched nerve", "radiculopathy"
        ]

        cardiorespiratory_keywords = [
            "breathing", "breath", "lung", "chest tightness", "asthma", 
            "pneumonia", "copd", "post-covid", "cardiac", "heart", "pulse",
            "shortness of breath", "sob", "cough", "respiratory", "ventilator",
            "oxygen", "cardiac rehab", "heart rate", "fatigue", "exhaustion",
            "aerobic", "inhalation", "exhalation", "deep breathing", "dyspnea"
        ]

        ergonomic_keywords = [
            "posture", "ergonomic", "cervical", "stiffness", "sit long", 
            "neck pain", "neck stiffness", "shoulder stiffness", "carpal tunnel",
            "repetitive strain", "rsi", "back stiffness", "desk job", "computer",
            "mouse elbow", "hunchback", "thoracic", "lower back stiffness",
            "desk sitting", "poor posture", "ergonomics", "text neck", "sitting long"
        ]

        if any(word in combined for word in neurological_keywords):
            return "Neurological"

        if any(word in combined for word in sports_keywords):
            return "Sports"

        if any(word in combined for word in cardiorespiratory_keywords):
            return "Cardiorespiratory"

        if any(word in combined for word in ergonomic_keywords):
            return "Ergonomic"

        return "Orthopaedic"

    def process_message(self, user_message: str, current_state: dict):
        if not GEMINI_API_KEY:
            return (
                current_state,
                "System: Gemini API Key is missing.",
                "Triage"
            )

        if not current_state:
            current_state = {
                "pain_area": None,
                "pain_point": None,
                "severity": None,
                "duration": None,
                "discipline": None,
                "history": [],
                "confirmed": False,
                "awaiting_confirmation": False
            }

        # Convert old history format if necessary (to prevent crashes with old chats)
        new_history = []
        for msg in current_state.get("history", []):
            if isinstance(msg, str):
                new_history.append({"role": "user", "content": msg})
            else:
                new_history.append(msg)
        current_state["history"] = new_history

        # -----------------------------
        # Store user message
        # -----------------------------
        current_state["history"].append({
            "role": "user",
            "content": user_message
        })

        # -----------------------------
        # Confirmation Stage
        # -----------------------------
        if current_state.get("awaiting_confirmation"):
            yes_words = [
                "yes",
                "y",
                "correct",
                "that's correct",
                "that's right",
                "right",
                "yup",
                "yeah"
            ]

            msg_clean = user_message.lower().strip()
            if any(word in msg_clean for word in yes_words):
                current_state["confirmed"] = True
                discipline = self.classify_discipline(current_state)
                current_state["discipline"] = discipline

                return (
                    current_state,
                    f"System: Thank you for confirming. You will now be connected to a physiotherapist specializing in {discipline}.",
                    "Active"
                )

            current_state["awaiting_confirmation"] = False

            return (
                current_state,
                "Thank you. Let's correct the information. Which area of your body is causing pain?",
                "Triage"
            )

        # -----------------------------
        # Build state context
        # -----------------------------
        state_context = f'''
Current patient information:
Pain Area: {current_state.get("pain_area")}
Pain Point: {current_state.get("pain_point")}
Severity: {current_state.get("severity")}
Duration: {current_state.get("duration")}

Only ask for missing information.
'''

        messages = [
            {
                "role": "user",
                "parts": [self.system_prompt]
            },
            {
                "role": "user",
                "parts": [state_context]
            }
        ]

        for msg in current_state["history"]:
            role = (
                "user"
                if msg["role"] == "user"
                else "model"
            )
            messages.append({
                "role": role,
                "parts": [msg["content"]]
            })

        try:
            model = genai.GenerativeModel("gemini-2.5-flash")
            response = model.generate_content(
                messages,
                generation_config=self.generation_config
            )

            result = json.loads(response.text)

            # -----------------------------
            # Update State
            # -----------------------------
            if result.get("pain_area"):
                current_state["pain_area"] = result["pain_area"]
                
            if result.get("pain_point"):
                current_state["pain_point"] = result["pain_point"]

            if result.get("severity"):
                current_state["severity"] = result["severity"]

            if result.get("duration"):
                current_state["duration"] = result["duration"]

            # -----------------------------
            # Emergency Detection
            # -----------------------------
            if result.get("is_emergency"):
                return (
                    current_state,
                    "System: Emergency symptoms detected. Please seek immediate medical attention or call emergency services immediately.",
                    "Emergency"
                )

            # -----------------------------
            # Check Completion
            # -----------------------------
            triage_complete = all([
                current_state.get("pain_area"),
                current_state.get("pain_point"),
                current_state.get("severity"),
                current_state.get("duration")
            ])

            if triage_complete:
                current_state["awaiting_confirmation"] = True

                summary = (
                    "System: Triage complete. Here is my assessment:\n\n"
                    f"- Pain Area: {current_state['pain_area']}\n"
                    f"- Pain Point: {current_state['pain_point']}\n"
                    f"- Severity: {current_state['severity']}\n"
                    f"- Duration: {current_state['duration']}\n\n"
                    "Is this correct? (Please reply 'Yes' to confirm or 'No' to restart)"
                )

                return (
                    current_state,
                    summary,
                    "Triage"
                )

            bot_reply = result.get(
                "response_message",
                "Could you tell me more?"
            )

            current_state["history"].append({
                "role": "assistant",
                "content": bot_reply
            })

            return (
                current_state,
                bot_reply,
                "Triage"
            )

        except Exception as e:
            print("LLM Error:", e)
            return (
                current_state,
                "System: Sorry, I am experiencing technical difficulties. Please try again.",
                "Triage"
            )

chatbot_instance = RehabChatbot()
