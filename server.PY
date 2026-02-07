"""
HIRESPEC AI CALLING AGENT - HACKATHON DEMO v4.1
FIXED: Short messages, Better STT, Longer wait times, Better phrase matching
"""

import asyncio
import base64
import json
import audioop
import numpy as np
import tempfile
import os
import time
import logging
import random
from dataclasses import dataclass, field
from typing import Optional, List, Dict, AsyncIterator
from enum import Enum
from contextlib import asynccontextmanager
from datetime import datetime

from fastapi import FastAPI, WebSocket, Request
from fastapi.responses import PlainTextResponse, JSONResponse
from concurrent.futures import ThreadPoolExecutor

import edge_tts
import soundfile as sf

from faster_whisper import WhisperModel

from langchain_ollama import ChatOllama
from langchain_core.prompts import ChatPromptTemplate
from langchain_core.output_parsers import StrOutputParser

# ================== LOGGING ==================

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s'
)
logger = logging.getLogger(__name__)

logging.getLogger("faster_whisper").setLevel(logging.WARNING)
logging.getLogger("httpx").setLevel(logging.WARNING)

# ================== DEMO QUESTIONS ==================

DEMO_QUESTIONS = {
    "backend_developer": {
        "python": [
            {
                "question": "How have you used decorators in Python?",
                "follow_up": "How do you handle errors in your code?",
                "good_indicators": ["decorator", "wrapper", "function", "logging"],
                "topic": "Python"
            },
            {
                "question": "Tell me about your Django experience.",
                "follow_up": "Have you optimized any slow queries?",
                "good_indicators": ["models", "ORM", "views", "migrations"],
                "topic": "Django"
            },
        ],
        "database": [
            {
                "question": "Explain the difference between INNER JOIN and LEFT JOIN.",
                "follow_up": "How do you optimize slow queries?",
                "good_indicators": ["rows", "null", "match", "index"],
                "topic": "SQL"
            },
        ],
    },
    "frontend_developer": {
        "javascript": [
            {
                "question": "What's the difference between let, const, and var?",
                "follow_up": "Can you explain hoisting?",
                "good_indicators": ["scope", "block", "reassign", "function"],
                "topic": "JavaScript"
            },
        ],
        "react": [
            {
                "question": "How do useState and useEffect work?",
                "follow_up": "When do you use the cleanup function?",
                "good_indicators": ["state", "render", "effect", "dependency"],
                "topic": "React Hooks"
            },
            {
                "question": "How do you manage global state in React?",
                "follow_up": "When would you use Redux vs Context?",
                "good_indicators": ["context", "redux", "props", "provider"],
                "topic": "State Management"
            },
        ],
    },
    "fullstack_developer": {
        "architecture": [
            {
                "question": "What logic goes in frontend vs backend?",
                "follow_up": "Where do you validate forms?",
                "good_indicators": ["security", "API", "validation", "business"],
                "topic": "Architecture"
            },
        ],
        "api": [
            {
                "question": "How do you handle authentication in your apps?",
                "follow_up": "How do you secure your endpoints?",
                "good_indicators": ["JWT", "token", "session", "middleware"],
                "topic": "Authentication"
            },
        ],
    },
    "data_analyst": {
        "sql": [
            {
                "question": "How would you find duplicate records in SQL?",
                "follow_up": "How would you remove them?",
                "good_indicators": ["GROUP BY", "COUNT", "HAVING", "duplicates"],
                "topic": "SQL"
            },
            {
                "question": "What's the difference between WHERE and HAVING?",
                "follow_up": "Give me an example using both.",
                "good_indicators": ["aggregate", "filter", "GROUP BY", "before"],
                "topic": "SQL Filtering"
            },
        ],
        "python_data": [
            {
                "question": "How do you handle missing data in pandas?",
                "follow_up": "When do you fill vs drop missing values?",
                "good_indicators": ["fillna", "dropna", "null", "mean"],
                "topic": "Pandas"
            },
        ],
    },
}

# ============ DEMO CANDIDATES ============

DEMO_CANDIDATES = {
    "demo1": {
        "candidate_id": "DEMO-001",
        "candidate_name": "Rahul Sharma",
        "position": "Backend Developer",
        "assessment_score": 62,
        "priority_skills": ["Python", "Django", "REST APIs"],
        "weak_areas": ["API Design", "Database Optimization"],
        "questions_to_ask": ["python", "database"],
    },
    "demo2": {
        "candidate_id": "DEMO-002",
        "candidate_name": "Priya Patel",
        "position": "Frontend Developer",
        "assessment_score": 58,
        "priority_skills": ["React", "JavaScript"],
        "weak_areas": ["React Hooks", "State Management"],
        "questions_to_ask": ["react", "javascript"],
    },
    "demo3": {
        "candidate_id": "DEMO-003",
        "candidate_name": "Amit Kumar",
        "position": "Full Stack Developer",
        "assessment_score": 65,
        "priority_skills": ["Node.js", "React", "MongoDB"],
        "weak_areas": ["API Authentication", "Architecture"],
        "questions_to_ask": ["architecture", "api"],
    },
    "demo4": {
        "candidate_id": "DEMO-004",
        "candidate_name": "Sneha Reddy",
        "position": "Data Analyst",
        "assessment_score": 55,
        "priority_skills": ["SQL", "Python", "Excel"],
        "weak_areas": ["Advanced SQL", "Pandas"],
        "questions_to_ask": ["sql", "python_data"],
    },
}

# ================== CANDIDATE CONTEXT ==================

@dataclass
class CandidateContext:
    candidate_id: str = ""
    candidate_name: str = ""
    position: str = "Developer"
    assessment_score: float = 0
    priority_skills: List[str] = field(default_factory=list)
    weak_areas: List[str] = field(default_factory=list)
    questions_to_ask: List[str] = field(default_factory=list)
    questions_asked: List[Dict] = field(default_factory=list)
    responses: List[Dict] = field(default_factory=list)


# ================== CALL STATE ==================

class CallPhase(Enum):
    GREETING = "greeting"
    CONFIRM = "confirm"
    QUESTION = "question"
    FOLLOW_UP = "follow_up"
    FEEDBACK = "feedback"
    CLOSING = "closing"
    ENDED = "ended"


class CallState(Enum):
    IDLE = "idle"
    LISTENING = "listening"
    PROCESSING = "processing"
    SPEAKING = "speaking"
    WAITING = "waiting"


@dataclass
class CallSession:
    stream_sid: Optional[str] = None
    state: CallState = CallState.IDLE
    phase: CallPhase = CallPhase.GREETING
    
    audio_buffer: List[np.ndarray] = field(default_factory=list)
    silence_frames: int = 0
    is_interrupted: bool = False
    
    candidate: CandidateContext = field(default_factory=CandidateContext)
    
    call_start_time: float = field(default_factory=time.time)
    phase_start_time: float = field(default_factory=time.time)
    
    question_count: int = 0
    max_questions: int = 2  # Keep demo short
    did_follow_up: bool = False
    
    conversation_log: List[Dict] = field(default_factory=list)
    
    stop_speaking: asyncio.Event = field(default_factory=asyncio.Event)
    
    def reset_audio(self):
        self.audio_buffer.clear()
        self.silence_frames = 0
        self.is_interrupted = False
        self.stop_speaking.clear()
    
    def interrupt(self):
        self.is_interrupted = True
        self.stop_speaking.set()
    
    def log(self, speaker: str, text: str):
        self.conversation_log.append({
            "speaker": speaker,
            "text": text,
            "timestamp": datetime.now().isoformat()
        })


# ================== CONFIG - OPTIMIZED ==================

@dataclass
class AgentConfig:
    tts_voice: str = "en-IN-NeerjaNeural"
    tts_rate: str = "+8%"  # Slightly faster
    whisper_model: str = "small"  # More accurate than base
    
    # IMPORTANT: Longer wait times
    silence_threshold_ms: int = 1000  # Wait 1 second of silence
    min_speech_frames: int = 8
    energy_threshold: int = 250  # More sensitive
    wait_timeout_seconds: int = 15  # Wait 15 seconds for response


SAMPLE_RATE = 8000
FRAME_MS = 20

executor = ThreadPoolExecutor(max_workers=8)

# ================== SHORT SCRIPTS ==================

class Scripts:
    """All agent messages - KEPT SHORT"""
    
    @staticmethod
    def greeting(name: str) -> str:
        first_name = name.split()[0] if name else "Hi"
        return f"Hi {first_name}! This is HireSpec calling about your application. Got 2 minutes for a quick chat?"
    
    @staticmethod
    def confirm_unclear() -> str:
        return "Sorry, could you say yes or no? Is now a good time?"
    
    @staticmethod
    def context(position: str, weak_areas: List[str]) -> str:
        skills = weak_areas[0] if weak_areas else "your skills"
        return f"Great! I have a few quick questions about {skills}."
    
    @staticmethod
    def acknowledge() -> str:
        options = ["Okay.", "Got it.", "Right.", "I see.", "Hmm, okay."]
        return random.choice(options)
    
    @staticmethod
    def feedback(weak_areas: List[str]) -> str:
        skill = weak_areas[0] if weak_areas else "some areas"
        return f"Thanks! Focus on {skill} to improve your score. You can reapply anytime."
    
    @staticmethod
    def closing(name: str) -> str:
        first_name = name.split()[0] if name else ""
        if first_name:
            return f"Thanks {first_name}! Good luck, bye!"
        return "Thanks for your time! Good luck, bye!"
    
    @staticmethod
    def timeout() -> str:
        return "Hello? Are you there?"
    
    @staticmethod
    def busy() -> str:
        return "No problem! We'll call back later. Bye!"
    
    @staticmethod
    def goodbye() -> str:
        return "Okay, thanks! Bye!"


# ================== BETTER STT ==================

class SpeechRecognizer:
    """Improved STT with better accuracy"""
    
    # Filter these hallucinations
    HALLUCINATIONS = {
        "thank you for watching", "thanks for watching", "subscribe",
        "[music]", "(music)", "...", "you", "the", "a", "i",
        "silence", "bye", "um", "uh", "hmm"
    }
    
    def __init__(self, model_size: str = "small"):
        logger.info(f"🧠 Loading STT ({model_size})...")
        self.model = WhisperModel(
            model_size, 
            device="cpu", 
            compute_type="int8",
            num_workers=2
        )
        logger.info("✅ STT ready")
    
    def transcribe(self, audio_8k: np.ndarray) -> str:
        """Transcribe with better preprocessing"""
        
        # Need minimum audio
        if len(audio_8k) < 2400:  # At least 300ms
            return ""
        
        # Preprocess - remove noise, normalize
        audio = audio_8k.astype(np.float32)
        
        # Remove DC offset
        audio = audio - np.mean(audio)
        
        # Noise gate
        threshold = np.max(np.abs(audio)) * 0.03
        audio[np.abs(audio) < threshold] = 0
        
        # Normalize
        max_val = np.max(np.abs(audio))
        if max_val > 0:
            audio = audio / max_val * 28000
        
        audio_8k = audio.astype(np.int16)
        
        # Check if there's actual speech
        rms = np.sqrt(np.mean(audio_8k.astype(np.float32) ** 2))
        if rms < 300:
            return ""
        
        # Resample 8k -> 16k
        audio_16k = np.repeat(audio_8k, 2).astype(np.float32) / 32768.0
        
        # Normalize again
        max_val = np.max(np.abs(audio_16k))
        if max_val > 0:
            audio_16k = audio_16k / max_val * 0.9
        
        # Transcribe with better parameters
        segments, info = self.model.transcribe(
            audio_16k,
            language="en",
            beam_size=5,  # More accurate
            best_of=3,
            temperature=0.0,
            vad_filter=True,
            vad_parameters=dict(
                threshold=0.3,  # More sensitive
                min_speech_duration_ms=150,
                min_silence_duration_ms=400,
                speech_pad_ms=250,
            ),
            without_timestamps=True,
            condition_on_previous_text=False,
            no_speech_threshold=0.4,
        )
        
        # Collect text
        text = " ".join(seg.text.strip() for seg in segments).strip()
        
        # Filter
        if not text or len(text) < 2:
            return ""
        
        if text.lower().strip() in self.HALLUCINATIONS:
            return ""
        
        # Filter single short words
        if len(text.split()) == 1 and len(text) <= 4:
            return ""
        
        logger.info(f"📝 STT: '{text}'")
        return text


# ================== TTS ==================

class TextToSpeech:
    def __init__(self, voice: str, rate: str):
        self.voice = voice
        self.rate = rate
        logger.info(f"🔊 TTS: {voice}")
    
    async def speak(self, text: str) -> bytes:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as f:
            path = f.name
        
        try:
            comm = edge_tts.Communicate(text=text, voice=self.voice, rate=self.rate)
            await comm.save(path)
            
            audio, sr = sf.read(path, dtype="int16")
            if audio.ndim > 1:
                audio = audio[:, 0]
            if sr != 8000:
                audio = audio[::sr // 8000]
            
            return audioop.lin2ulaw(audio.tobytes(), 2)
        finally:
            if os.path.exists(path):
                os.remove(path)
    
    async def speak_chunked(self, text: str, stop_event: asyncio.Event) -> AsyncIterator[bytes]:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".wav") as f:
            path = f.name
        
        try:
            comm = edge_tts.Communicate(text=text, voice=self.voice, rate=self.rate)
            await comm.save(path)
            
            audio, sr = sf.read(path, dtype="int16")
            if audio.ndim > 1:
                audio = audio[:, 0]
            if sr != 8000:
                audio = audio[::sr // 8000]
            
            # 100ms chunks for fast barge-in
            for i in range(0, len(audio), 800):
                if stop_event.is_set():
                    break
                yield audioop.lin2ulaw(audio[i:i+800].tobytes(), 2)
        finally:
            if os.path.exists(path):
                os.remove(path)


# ================== PHRASE MATCHER ==================

class PhraseMatcher:
    """Better matching for user responses"""
    
    # YES phrases
    YES_PHRASES = {
        "yes", "yeah", "yep", "sure", "okay", "ok", "fine", "go ahead",
        "continue", "proceed", "yes please", "sure thing", "alright",
        "haan", "ha", "theek", "theek hai", "chalo", "bol", "bolo",
        "yes i am", "i am", "good time", "yes it is", "it is",
        "please continue", "you can continue", "go on", "carry on",
        "speak", "tell me", "ask", "yes sure", "of course",
        "ready", "i'm ready", "let's go", "start", "begin"
    }
    
    # NO phrases
    NO_PHRASES = {
        "no", "nope", "not now", "busy", "later", "can't", "cannot",
        "not a good time", "call later", "nahi", "bad time", "not right now"
    }
    
    # GOODBYE phrases
    BYE_PHRASES = {
        "bye", "goodbye", "thank you bye", "thanks bye", "ok bye",
        "that's all", "done", "finish", "end", "stop"
    }
    
    @classmethod
    def is_yes(cls, text: str) -> bool:
        text_lower = text.lower().strip()
        
        # Direct match
        if text_lower in cls.YES_PHRASES:
            return True
        
        # Partial match
        for phrase in cls.YES_PHRASES:
            if phrase in text_lower:
                return True
        
        # Check if starts with yes-like word
        first_word = text_lower.split()[0] if text_lower else ""
        if first_word in {"yes", "yeah", "yep", "sure", "okay", "ok", "haan", "ha"}:
            return True
        
        return False
    
    @classmethod
    def is_no(cls, text: str) -> bool:
        text_lower = text.lower().strip()
        
        for phrase in cls.NO_PHRASES:
            if phrase in text_lower:
                return True
        
        # Starts with no
        if text_lower.startswith("no"):
            return True
        
        return False
    
    @classmethod
    def is_bye(cls, text: str) -> bool:
        text_lower = text.lower().strip()
        
        for phrase in cls.BYE_PHRASES:
            if phrase in text_lower:
                return True
        
        return False


# ================== QUESTION SELECTOR ==================

class QuestionSelector:
    @staticmethod
    def get_next_question(candidate: CandidateContext, session: 'CallSession') -> Optional[Dict]:
        """Get next question for candidate"""
        
        # Map position to category
        pos = candidate.position.lower()
        if "backend" in pos:
            category = "backend_developer"
        elif "frontend" in pos:
            category = "frontend_developer"
        elif "full" in pos:
            category = "fullstack_developer"
        elif "data" in pos:
            category = "data_analyst"
        else:
            category = "backend_developer"
        
        questions_db = DEMO_QUESTIONS.get(category, {})
        skills = candidate.questions_to_ask or list(questions_db.keys())
        
        # Get unasked question
        asked = [q["question"] for q in candidate.questions_asked]
        
        for skill in skills:
            if skill in questions_db:
                for q in questions_db[skill]:
                    if q["question"] not in asked:
                        return q
        
        return None


# ================== MAIN AGENT ==================

class HireSpecAgent:
    def __init__(self, config: AgentConfig = None):
        self.config = config or AgentConfig()
        self.stt = SpeechRecognizer(self.config.whisper_model)
        self.tts = TextToSpeech(self.config.tts_voice, self.config.tts_rate)
        logger.info("✅ HireSpec Agent ready")
    
    async def handle_call(self, ws: WebSocket, candidate: CandidateContext = None):
        session = CallSession()
        session.candidate = candidate or CandidateContext()
        
        try:
            async for msg in ws.iter_text():
                data = json.loads(msg)
                event = data.get("event")
                
                if event == "start":
                    await self._on_call_start(ws, data, session)
                elif event == "media":
                    await self._on_audio(ws, data, session)
                elif event == "stop":
                    logger.info(f"📞 Call ended ({time.time()-session.call_start_time:.0f}s)")
                    break
        except Exception as e:
            logger.error(f"Error: {e}")
        
        return {"candidate": session.candidate.candidate_name, "log": session.conversation_log}
    
    async def _on_call_start(self, ws: WebSocket, data: dict, session: CallSession):
        """Call started - send greeting"""
        session.stream_sid = data["start"]["streamSid"]
        session.call_start_time = time.time()
        
        logger.info(f"📞 Call: {session.candidate.candidate_name} | {session.candidate.position}")
        
        # SHORT greeting
        greeting = Scripts.greeting(session.candidate.candidate_name)
        await self._say(ws, session, greeting)
        
        session.phase = CallPhase.CONFIRM
    
    async def _on_audio(self, ws: WebSocket, data: dict, session: CallSession):
        """Handle incoming audio"""
        pcm = audioop.ulaw2lin(base64.b64decode(data["media"]["payload"]), 2)
        chunk = np.frombuffer(pcm, dtype=np.int16)
        
        rms = np.sqrt(np.mean(chunk.astype(np.float32) ** 2))
        is_speech = rms > self.config.energy_threshold
        
        # BARGE-IN
        if is_speech and session.state == CallState.SPEAKING:
            logger.info("✋ Interrupted")
            session.interrupt()
            await self._clear(ws, session.stream_sid)
            session.state = CallState.LISTENING
            session.audio_buffer = [chunk]
            session.silence_frames = 0
            return
        
        # WAITING for response
        if session.state == CallState.WAITING:
            if is_speech:
                session.state = CallState.LISTENING
                session.audio_buffer = [chunk]
                session.silence_frames = 0
            else:
                # Check timeout
                elapsed = time.time() - session.phase_start_time
                if elapsed > self.config.wait_timeout_seconds:
                    await self._on_timeout(ws, session)
            return
        
        # LISTENING - collect audio
        if session.state == CallState.LISTENING:
            if is_speech:
                session.audio_buffer.append(chunk)
                session.silence_frames = 0
            else:
                session.silence_frames += 1
            
            # End of speech?
            silence_needed = int(self.config.silence_threshold_ms / FRAME_MS)
            if session.silence_frames >= silence_needed and len(session.audio_buffer) >= self.config.min_speech_frames:
                await self._on_speech_end(ws, session)
    
    async def _on_speech_end(self, ws: WebSocket, session: CallSession):
        """Process collected speech"""
        session.state = CallState.PROCESSING
        
        audio = np.concatenate(session.audio_buffer)
        session.reset_audio()
        
        # Transcribe
        loop = asyncio.get_event_loop()
        text = await loop.run_in_executor(executor, self.stt.transcribe, audio)
        
        if not text:
            # No valid speech, keep waiting
            session.state = CallState.WAITING
            session.phase_start_time = time.time()
            return
        
        logger.info(f"👤 USER: {text}")
        session.log("user", text)
        
        # Route based on phase
        await self._route(ws, session, text)
    
    async def _route(self, ws: WebSocket, session: CallSession, text: str):
        """Route response based on phase"""
        
        # Check goodbye first
        if PhraseMatcher.is_bye(text):
            await self._say(ws, session, Scripts.goodbye())
            session.phase = CallPhase.ENDED
            return
        
        # CONFIRM phase
        if session.phase == CallPhase.CONFIRM:
            if PhraseMatcher.is_yes(text):
                # Start questions
                context = Scripts.context(session.candidate.position, session.candidate.weak_areas)
                await self._say(ws, session, context)
                
                session.phase = CallPhase.QUESTION
                await self._ask_question(ws, session)
            
            elif PhraseMatcher.is_no(text):
                await self._say(ws, session, Scripts.busy())
                session.phase = CallPhase.ENDED
            
            else:
                # Unclear - ask again
                await self._say(ws, session, Scripts.confirm_unclear())
        
        # QUESTION phase
        elif session.phase == CallPhase.QUESTION:
            # Got answer to question
            session.candidate.responses.append({"question": session.question_count, "answer": text})
            
            # Ask follow-up?
            if not session.did_follow_up and session.candidate.questions_asked:
                last_q = session.candidate.questions_asked[-1]
                follow_up = last_q.get("follow_up")
                if follow_up:
                    session.did_follow_up = True
                    session.phase = CallPhase.FOLLOW_UP
                    ack = Scripts.acknowledge()
                    await self._say(ws, session, f"{ack} {follow_up}")
                    return
            
            # Next question or feedback
            session.did_follow_up = False
            if session.question_count < session.max_questions:
                ack = Scripts.acknowledge()
                await self._say(ws, session, ack)
                await self._ask_question(ws, session)
            else:
                await self._give_feedback(ws, session)
        
        # FOLLOW_UP phase
        elif session.phase == CallPhase.FOLLOW_UP:
            session.candidate.responses.append({"follow_up": True, "answer": text})
            session.did_follow_up = False
            
            if session.question_count < session.max_questions:
                ack = Scripts.acknowledge()
                await self._say(ws, session, ack)
                session.phase = CallPhase.QUESTION
                await self._ask_question(ws, session)
            else:
                await self._give_feedback(ws, session)
        
        # FEEDBACK phase
        elif session.phase == CallPhase.FEEDBACK:
            # They responded to feedback, close
            await self._say(ws, session, Scripts.closing(session.candidate.candidate_name))
            session.phase = CallPhase.ENDED
    
    async def _ask_question(self, ws: WebSocket, session: CallSession):
        """Ask next question"""
        question = QuestionSelector.get_next_question(session.candidate, session)
        
        if question:
            session.candidate.questions_asked.append(question)
            session.question_count += 1
            
            logger.info(f"❓ Q{session.question_count}: {question['topic']}")
            await self._say(ws, session, question["question"])
        else:
            # No more questions
            await self._give_feedback(ws, session)
    
    async def _give_feedback(self, ws: WebSocket, session: CallSession):
        """Give feedback and close"""
        session.phase = CallPhase.FEEDBACK
        
        feedback = Scripts.feedback(session.candidate.weak_areas)
        closing = Scripts.closing(session.candidate.candidate_name)
        
        await self._say(ws, session, feedback)
        await asyncio.sleep(0.3)
        await self._say(ws, session, closing)
        
        session.phase = CallPhase.ENDED
    
    async def _on_timeout(self, ws: WebSocket, session: CallSession):
        """Handle response timeout"""
        logger.info("⏱️ Timeout")
        
        if session.phase == CallPhase.CONFIRM:
            # Ask if they're there
            await self._say(ws, session, Scripts.timeout())
        elif session.phase in [CallPhase.QUESTION, CallPhase.FOLLOW_UP]:
            # Move to next question or end
            session.did_follow_up = False
            if session.question_count < session.max_questions:
                await self._say(ws, session, "Let me ask another question.")
                await self._ask_question(ws, session)
            else:
                await self._give_feedback(ws, session)
        else:
            await self._say(ws, session, Scripts.goodbye())
            session.phase = CallPhase.ENDED
    
    async def _say(self, ws: WebSocket, session: CallSession, text: str):
        """Speak text"""
        session.state = CallState.SPEAKING
        session.stop_speaking.clear()
        session.log("agent", text)
        
        logger.info(f"🤖 AGENT: {text}")
        
        async for chunk in self.tts.speak_chunked(text, session.stop_speaking):
            if session.stop_speaking.is_set():
                break
            await self._send(ws, session.stream_sid, chunk)
        
        if not session.stop_speaking.is_set():
            session.state = CallState.WAITING
            session.phase_start_time = time.time()
    
    async def _send(self, ws: WebSocket, sid: str, audio: bytes):
        await ws.send_json({
            "event": "media",
            "streamSid": sid,
            "media": {"payload": base64.b64encode(audio).decode()}
        })
    
    async def _clear(self, ws: WebSocket, sid: str):
        try:
            await ws.send_json({"event": "clear", "streamSid": sid})
        except:
            pass


# ================== FASTAPI ==================

pending_candidates: Dict[str, CandidateContext] = {}
call_logs: List[Dict] = []


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("🚀 Starting HireSpec Demo...")
    app.state.agent = HireSpecAgent()
    
    # Load demo candidates
    for did, data in DEMO_CANDIDATES.items():
        pending_candidates[did] = CandidateContext(**data)
    
    logger.info(f"📋 Loaded {len(DEMO_CANDIDATES)} demos")
    logger.info("✅ Ready!")
    yield
    executor.shutdown(wait=True)


app = FastAPI(title="HireSpec Demo", version="4.1", lifespan=lifespan)


@app.post("/answer")
async def answer(request: Request):
    host = request.headers.get("host")
    return PlainTextResponse(
        f"""<?xml version="1.0" encoding="UTF-8"?>
<Response><Connect><Stream url="wss://{host}/media"/></Connect></Response>""",
        media_type="application/xml"
    )


@app.websocket("/media")
async def media(ws: WebSocket):
    await ws.accept()
    logger.info("✅ Connected")
    
    candidate = None
    if pending_candidates:
        cid = list(pending_candidates.keys())[-1]
        candidate = pending_candidates.get(cid)
    
    result = await app.state.agent.handle_call(ws, candidate)
    call_logs.append(result)


@app.post("/demo")
async def set_demo(request: Request):
    """Set demo: POST /demo {"id": "demo1"}"""
    data = await request.json()
    demo_id = data.get("id", "demo1")
    
    if demo_id in DEMO_CANDIDATES:
        pending_candidates.clear()
        pending_candidates[demo_id] = CandidateContext(**DEMO_CANDIDATES[demo_id])
        c = pending_candidates[demo_id]
        return {"status": "ok", "name": c.candidate_name, "position": c.position}
    
    return {"error": f"Not found. Available: {list(DEMO_CANDIDATES.keys())}"}


@app.get("/demos")
async def list_demos():
    return {
        "demos": [
            {"id": k, "name": v["candidate_name"], "position": v["position"]}
            for k, v in DEMO_CANDIDATES.items()
        ]
    }


@app.get("/logs")
async def get_logs():
    return {"logs": call_logs}


@app.get("/")
async def root():
    return {
        "service": "HireSpec AI Calling Agent",
        "version": "4.1",
        "demos": list(DEMO_CANDIDATES.keys()),
        "usage": "POST /demo {'id': 'demo1'} then call Twilio number"
    }


if __name__ == "__main__":
    import uvicorn
    
    print("\n" + "=" * 60)
    print("🎯 HIRESPEC DEMO v4.1 - FIXED")
    print("=" * 60)
    print("✅ Shorter messages")
    print("✅ Better STT (small model)")
    print("✅ 15 second wait timeout")
    print("✅ Better phrase matching")
    print("=" * 60)
    print("\nDemos:")
    for did, data in DEMO_CANDIDATES.items():
        print(f"  {did}: {data['candidate_name']} - {data['position']}")
    print("\nUsage:")
    print('  curl -X POST localhost:8000/demo -d \'{"id":"demo1"}\'')
    print("  Then call your Twilio number")
    print("=" * 60 + "\n")
    
    uvicorn.run(app, host="0.0.0.0", port=8000, log_level="info")