import json
import os
import re

import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

FIELDS = ("pain_point", "severity", "duration")


class RehabChatbot:
    def __init__(self):
        self.system_prompt = """
You are a professional Physiotherapy Triage Assistant. Extract facts from ONLY
the patient's latest message. The application controls which question is asked.

Rules:
- Keep each body area as a separate symptom. Never combine areas into one string.
- If the message only answers the current question (such as "dull" or "7"),
  associate the answer with current_area.
- If it explicitly names another body area, return a separate update for it.
- Never copy a detail from one symptom to another or infer unanswered details.
- Chest pain (not chest tightness), difficulty breathing, stroke symptoms,
  paralysis, severe trauma, or loss of consciousness is an emergency.

Return ONLY JSON:
{"updates":[{"area":"body area","pain_point":null,"severity":null,
"duration":null}],"is_emergency":false}
"""
        self.generation_config = {
            "temperature": 0.1,
            "response_mime_type": "application/json",
        }

    @staticmethod
    def _blank(area):
        return {"area": str(area).strip(), "pain_point": None,
                "severity": None, "duration": None}

    @staticmethod
    def _key(value):
        return re.sub(r"[^a-z0-9]+", " ", str(value or "").lower()).strip()

    def _init_state(self, state):
        state = state or {}
        if "symptoms" not in state:
            state["symptoms"] = []
            if state.get("pain_area"):
                symptom = self._blank(state["pain_area"])
                for field in FIELDS:
                    symptom[field] = state.get(field)
                state["symptoms"].append(symptom)
        defaults = {
            "history": [], "active_symptom_index": 0,
            "pending_symptoms": [], "awaiting_symptom_confirmation": False,
            "awaiting_symptom_selection": False, "confirmed": False,
            "awaiting_confirmation": False, "pending_field_corrections": [],
            "awaiting_field_correction_confirmation": False,
        }
        for key, value in defaults.items():
            state.setdefault(key, value)
        state["history"] = [
            {"role": "user", "content": item} if isinstance(item, str) else item
            for item in state["history"]
        ]
        self._sync_legacy(state)
        return state

    @staticmethod
    def _sync_legacy(state):
        """Preserve fields consumed by existing screens and appointment code."""
        symptoms = state.get("symptoms", [])
        state["pain_area"] = ", ".join(x["area"] for x in symptoms) or None
        for field in FIELDS:
            values = [f"{x['area']}: {x[field]}" for x in symptoms if x.get(field)]
            state[field] = "; ".join(values) or None

    def _find(self, state, area):
        wanted = self._key(area)
        for index, symptom in enumerate(state["symptoms"]):
            if self._key(symptom["area"]) == wanted:
                return index
        return None

    def _remove_generic_pain_point(self, update):
        """`leg pain` identifies an area; it does not answer pain type."""
        point = self._key(update.get("pain_point"))
        area_words = set(self._key(update.get("area")).split())
        remaining = [word for word in point.split()
                     if word not in area_words and word not in {"in", "my", "the"}]
        if not remaining or set(remaining) <= {
                "pain", "pains", "painful", "hurt", "hurts", "hurting",
                "symptom", "symptoms", "discomfort"}:
            update["pain_point"] = None
        return update

    @staticmethod
    def _yes(message):
        return message.strip().lower() in {
            "yes", "y", "correct", "that's correct", "thats correct",
            "right", "yup", "yeah", "both",
        }

    @staticmethod
    def _no(message):
        return message.strip().lower() in {"no", "n", "nope", "incorrect"}

    @staticmethod
    def _is_correction(message):
        text = message.strip().lower()
        return any(phrase in text for phrase in (
            "sorry", "actually", "correction", "correct that", "i mean",
            "meant", "not only", "rather", "instead", "change it",
            "change that",
        ))

    def _next_missing(self, state):
        for index, symptom in enumerate(state["symptoms"]):
            for field in FIELDS:
                if not symptom.get(field):
                    state["active_symptom_index"] = index
                    return symptom, field
        return None, None

    @staticmethod
    def _question(symptom, field):
        area = symptom["area"]
        return {
            "pain_point": f"How would you describe the {area} symptom (for example, sharp, dull, or aching)?",
            "severity": (
                f"On a scale of 1 to 10, where 1 is very mild and 10 is the "
                f"worst pain imaginable, how would you rate your {area} symptom?"
            ),
            "duration": f"How long have you had the {area} symptom?",
        }[field]

    def classify_discipline(self, state):
        text = " ".join(
            f"{x.get('area', '')} {x.get('pain_point', '')}"
            for x in state.get("symptoms", [])
        ).lower()
        groups = [
            ("Neurological", ["numb", "tingl", "stroke", "nerve", "sciatica", "paralysis", "burning", "weakness"]),
            ("Sports", ["ankle", "acl", "hamstring", "sport", "sprain", "strain", "ligament", "meniscus", "workout", "achilles", "calf"]),
            ("Cardiorespiratory", ["breath", "lung", "chest", "asthma", "copd", "cardiac", "heart", "oxygen"]),
            ("Ergonomic", ["posture", "ergonomic", "sit long", "desk", "computer", "text neck"]),
        ]
        for discipline, words in groups:
            if any(word in text for word in words):
                return discipline
        return "Orthopaedic"

    def _accept_pending(self, state):
        for update in state["pending_symptoms"]:
            if self._find(state, update["area"]) is None:
                symptom = self._blank(update["area"])
                for field in FIELDS:
                    if update.get(field):
                        symptom[field] = update[field]
                state["symptoms"].append(symptom)
        state["pending_symptoms"] = []
        state["awaiting_symptom_confirmation"] = False
        state["awaiting_symptom_selection"] = False

    def process_message(self, user_message: str, current_state: dict):
        if not GEMINI_API_KEY:
            return current_state, "System: Gemini API Key is missing.", "Triage"

        state = self._init_state(current_state)
        state["history"].append({"role": "user", "content": user_message})

        if state["awaiting_field_correction_confirmation"]:
            corrections = state["pending_field_corrections"]
            if self._yes(user_message):
                for correction in corrections:
                    index = self._find(state, correction["area"])
                    if index is not None:
                        state["symptoms"][index][correction["field"]] = correction["value"]
                state["pending_field_corrections"] = []
                state["awaiting_field_correction_confirmation"] = False
                self._sync_legacy(state)
                symptom, field = self._next_missing(state)
                if symptom:
                    return state, self._question(symptom, field), "Triage"
            elif self._no(user_message):
                state["pending_field_corrections"] = []
                state["awaiting_field_correction_confirmation"] = False
                symptom, field = self._next_missing(state)
                if symptom:
                    return state, self._question(symptom, field), "Triage"
            else:
                return state, "Please confirm the updated information (Yes/No).", "Triage"

        if state["awaiting_symptom_confirmation"]:
            if self._yes(user_message):
                self._accept_pending(state)
                symptom, field = self._next_missing(state)
                self._sync_legacy(state)
                return state, self._question(symptom, field), "Triage"
            if self._no(user_message):
                state["awaiting_symptom_confirmation"] = False
                state["awaiting_symptom_selection"] = True
                areas = [x["area"] for x in state["symptoms"] + state["pending_symptoms"]]
                return state, f"Which symptom should I assess: {' or '.join(areas)}?", "Triage"
            return state, "Please confirm whether you have both symptoms (Yes/No).", "Triage"

        if state["awaiting_symptom_selection"]:
            selected = next((x for x in state["symptoms"] + state["pending_symptoms"]
                             if self._key(x["area"]) in self._key(user_message)), None)
            if not selected:
                return state, "Please name the body area you want me to assess.", "Triage"
            state["symptoms"] = [selected]
            state["pending_symptoms"] = []
            state["awaiting_symptom_selection"] = False
            symptom, field = self._next_missing(state)
            self._sync_legacy(state)
            return state, self._question(symptom, field), "Triage"

        if state["awaiting_confirmation"]:
            if self._yes(user_message):
                state["confirmed"] = True
                discipline = self.classify_discipline(state)
                state["discipline"] = discipline
                return state, ("System: Thank you for confirming. You will now be "
                               f"connected to a physiotherapist specializing in {discipline}."), "Active"
            state["awaiting_confirmation"] = False
            return state, "Thank you. Which body area should I correct?", "Triage"

        active = None
        expected_field = None
        if state["symptoms"]:
            index = min(state["active_symptom_index"], len(state["symptoms"]) - 1)
            active = state["symptoms"][index]["area"]
            _, expected_field = self._next_missing(state)
        context = json.dumps({"known_symptoms": state["symptoms"],
                              "current_area": active,
                              "expected_field": expected_field,
                              "latest_message": user_message})
        messages = [{"role": "user", "parts": [self.system_prompt]},
                    {"role": "user", "parts": [context]}]

        try:
            model = genai.GenerativeModel("gemini-2.5-flash")
            response = model.generate_content(messages, generation_config=self.generation_config)
            result = json.loads(response.text)
            if result.get("is_emergency"):
                return state, ("System: Emergency symptoms detected. Please seek immediate "
                               "medical attention or call emergency services immediately."), "Emergency"

            updates = [self._remove_generic_pain_point(x)
                       for x in result.get("updates", []) if x.get("area")]
            is_correction = self._is_correction(user_message)
            # Short answers refer to the symptom currently being questioned.
            if active and len(updates) == 1:
                returned_area = self._key(updates[0]["area"])
                if returned_area not in self._key(user_message):
                    updates[0]["area"] = active
            new_updates = [x for x in updates if self._find(state, x["area"]) is None]
            if not state["symptoms"] and len(new_updates) > 1:
                state["pending_symptoms"] = new_updates
                state["awaiting_symptom_confirmation"] = True
                areas = ", ".join(x["area"] for x in new_updates)
                return state, (f"You mentioned {areas}. Are you experiencing all of "
                               "these symptoms?"), "Triage"
            if state["symptoms"] and new_updates:
                state["pending_symptoms"] = new_updates
                state["awaiting_symptom_confirmation"] = True
                old = ", ".join(x["area"] for x in state["symptoms"])
                new = ", ".join(x["area"] for x in new_updates)
                return state, (f"You previously mentioned {old}, and now you mentioned {new}. "
                               "Are you experiencing both symptoms?"), "Triage"

            # If the patient adds to or changes a field that was already
            # answered, confirm the complete revised value before saving it.
            proposed_corrections = []
            for update in updates:
                index = self._find(state, update["area"])
                if index is None:
                    continue
                for field in FIELDS:
                    old_value = state["symptoms"][index].get(field)
                    new_value = update.get(field)
                    if (old_value and new_value and
                            self._key(old_value) != self._key(new_value)):
                        proposed_corrections.append({
                            "area": state["symptoms"][index]["area"],
                            "field": field,
                            "old_value": old_value,
                            "value": new_value,
                        })
            if proposed_corrections:
                state["pending_field_corrections"] = proposed_corrections
                state["awaiting_field_correction_confirmation"] = True
                labels = {"pain_point": "pain type", "severity": "severity",
                          "duration": "duration"}
                descriptions = [
                    f"the {item['area']} {labels[item['field']]} from "
                    f"{item['old_value']} to {item['value']}"
                    for item in proposed_corrections
                ]
                return state, ("Should I update " + " and ".join(descriptions) +
                               "? (Yes/No)"), "Triage"

            for update in updates:
                index = self._find(state, update["area"])
                if index is None:
                    state["symptoms"].append(self._blank(update["area"]))
                    index = len(state["symptoms"]) - 1
                for field in FIELDS:
                    # Revisions to completed fields are handled by the explicit
                    # confirmation stage above.
                    if update.get(field) and not state["symptoms"][index].get(field):
                        state["symptoms"][index][field] = update[field]

            # Bind concise answers deterministically to the pending question.
            # Do not do this for corrections: they may correct an earlier field
            # while a different question is currently displayed.
            extracted_detail = any(
                update.get(field) for update in updates for field in FIELDS
            )
            if active and expected_field and not extracted_detail and not is_correction:
                active_index = self._find(state, active)
                if active_index is not None and user_message.strip():
                    state["symptoms"][active_index][expected_field] = user_message.strip()

            self._sync_legacy(state)
            symptom, field = self._next_missing(state)
            if symptom:
                reply = self._question(symptom, field)
                state["history"].append({"role": "assistant", "content": reply})
                return state, reply, "Triage"

            if state["symptoms"]:
                state["awaiting_confirmation"] = True
                lines = [f"- {x['area']}: {x['pain_point']}, severity {x['severity']}, for {x['duration']}"
                         for x in state["symptoms"]]
                summary = ("System: Triage complete. Here is my assessment:\n\n" +
                           "\n".join(lines) + "\n\nIs this correct? (Yes/No)")
                return state, summary, "Triage"
            return state, "Which area of your body is causing pain?", "Triage"
        except Exception as exc:
            print("LLM Error:", exc)
            return state, "System: Sorry, I am experiencing technical difficulties. Please try again.", "Triage"


chatbot_instance = RehabChatbot()
