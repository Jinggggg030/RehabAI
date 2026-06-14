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
        self.system_prompt = """You are a professional Physiotherapy Triage Assistant for the Rehab AI clinic.
Your job is to chat with the patient and collect 3 pieces of information:
1. Pain Area (e.g. Lower back, Right shoulder, Knee)
2. Severity (On a scale of 1-10 or Mild/Moderate/Severe)
3. Duration (How long they have had the pain)

CRITICAL INSTRUCTIONS:
- You MUST respond in valid JSON format ONLY. Do not include markdown code blocks (```json) or any other text outside the JSON object.
- The JSON object must have exactly these keys:
  - "response_message": (string) Your natural language reply to the patient. Ask exactly ONE question at a time.
  - "pain_area": (string or null) The pain area if you have figured it out.
  - "severity": (string or null) The severity if you have figured it out.
  - "duration": (string or null) The duration if you have figured it out.
  - "is_triage_complete": (boolean) Set to true ONLY if you have successfully collected ALL 3 pieces of information AND the user has explicitly confirmed that your summary of their symptoms is correct.
  - "is_emergency": (boolean) Set to true immediately if the user mentions anything life-threatening (e.g., heart attack, stroke, chest pain, inability to breathe, paralysis, extreme trauma).
  - "discipline": (string or null) If is_triage_complete is true, classify the issue into one of these exact strings: "Musculoskeletal", "Neurological", "Cardiopulmonary", "Sports", "Geriatric", "Pediatric", or "Pelvic Floor".

Be empathetic, brief, and clear. 
If you have collected Area, Severity, and Duration, your next response_message MUST summarize their symptoms and ask "Is this correct?". 
If they say yes, set is_triage_complete to true and provide a comforting closing message in response_message saying they will be connected to a physiotherapist.
"""
        self.generation_config = {
            "temperature": 0.2,
            "response_mime_type": "application/json",
        }

    def process_message(self, user_message: str, current_state: dict) -> tuple[dict, str, str]:
        if not GEMINI_API_KEY:
            return current_state, "System: Gemini API Key is missing. Please contact administration.", "Triage"

        if not current_state:
            current_state = {
                "pain_area": None,
                "severity": None,
                "duration": None,
                "discipline": None,
                "history": [],
                "confirmed": False
            }
        
        # Convert old history format if necessary
        new_history = []
        for msg in current_state.get("history", []):
            if isinstance(msg, str):
                new_history.append({"role": "user", "content": msg})
            else:
                new_history.append(msg)
        current_state["history"] = new_history

        # Append user message to history
        current_state["history"].append({"role": "user", "content": user_message})

        # Construct the conversation for the LLM
        messages = [
            {"role": "user", "parts": [self.system_prompt]}
        ]
        
        # We need to map role "user" and "assistant" to Gemini's "user" and "model"
        for msg in current_state["history"]:
            role = "user" if msg["role"] == "user" else "model"
            messages.append({"role": role, "parts": [msg["content"]]})

        try:
            model = genai.GenerativeModel('gemini-2.5-flash')
            response = model.generate_content(
                messages,
                generation_config=self.generation_config
            )
            
            result = json.loads(response.text)
            
            bot_reply = result.get("response_message", "I didn't quite catch that.")
            current_state["history"].append({"role": "assistant", "content": bot_reply})
            
            # Update state
            if result.get("pain_area"): current_state["pain_area"] = result.get("pain_area")
            if result.get("severity"): current_state["severity"] = result.get("severity")
            if result.get("duration"): current_state["duration"] = result.get("duration")
            
            if result.get("is_emergency") is True:
                return current_state, f"System: EMERGENCY TRIGGERED. {bot_reply}", "Emergency"
                
            if result.get("is_triage_complete") is True:
                current_state["confirmed"] = True
                current_state["discipline"] = result.get("discipline")
                
                final_msg = f"System: {bot_reply}\n[Routing to {current_state['discipline']} Specialist...]"
                return current_state, final_msg, "Active"
                
            return current_state, bot_reply, "Triage"
            
        except Exception as e:
            print("LLM Error:", e)
            return current_state, "System: Sorry, I am experiencing technical difficulties. Let's try again.", "Triage"

chatbot_instance = RehabChatbot()
