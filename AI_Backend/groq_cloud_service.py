"""
SpecEI Groq Cloud Services
Unified service for Groq's cloud-based AI:
- Whisper Large v3 Turbo (transcription)
- GPT-oss-120b (reasoning)
- LLaVA (vision)
"""

import os
import logging
from typing import List, Dict, Any, Optional
from groq import Groq

# Load environment from AI_Backend directory
try:
    from dotenv import load_dotenv
    # Load from current file's directory
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    load_dotenv(env_path)
    print(f"✅ Loaded .env from: {env_path}")
except ImportError:
    pass

logger = logging.getLogger("SpecEI.GroqCloud")

# Initialize Groq client - read AFTER loading dotenv
GROQ_API_KEY = os.environ.get("GROQ_API_KEY", "")
print(f"🔑 GROQ_API_KEY: {'Found (' + GROQ_API_KEY[:10] + '...)' if GROQ_API_KEY else 'NOT FOUND'}")


class GroqCloudService:
    """
    Unified Groq cloud service for all AI operations.
    Replaces local Whisper and Mistral with cloud-based alternatives.
    """
    
    def __init__(self):
        self.api_key = GROQ_API_KEY
        self.client = None
        self.available = False
        
        if self.api_key:
            try:
                self.client = Groq(api_key=self.api_key)
                self.available = True
                logger.info("✅ Groq Cloud Service initialized")
                print(f"✅ Groq Cloud initialized with key: {self.api_key[:10]}...")
            except Exception as e:
                logger.error(f"❌ Failed to initialize Groq client: {e}")
                print(f"❌ Groq init failed: {e}")
        else:
            logger.warning("⚠️ GROQ_API_KEY not set - Groq services unavailable")
            print("⚠️ GROQ_API_KEY not found in environment!")
    
    # ==========================================
    # WHISPER TRANSCRIPTION (Cloud)
    # ==========================================
    
    def transcribe_audio(self, audio_path: str) -> Dict[str, Any]:
        """
        Transcribe audio using Groq's Whisper Large v3 Turbo.
        
        Args:
            audio_path: Path to audio file
            
        Returns:
            Dictionary with text, segments, and language
        """
        if not self.available:
            return {"error": "Groq service not available", "text": "", "segments": []}
        
        try:
            with open(audio_path, "rb") as file:
                transcription = self.client.audio.transcriptions.create(
                    file=(os.path.basename(audio_path), file.read()),
                    model="whisper-large-v3-turbo",
                    temperature=0,
                    response_format="verbose_json",
                )
            
            # Parse response
            result = {
                "text": transcription.text,
                "language": getattr(transcription, 'language', 'unknown'),
                "segments": []
            }
            
            # Extract segments if available
            if hasattr(transcription, 'segments') and transcription.segments:
                for seg in transcription.segments:
                    result["segments"].append({
                        "text": seg.get('text', ''),
                        "start": seg.get('start', 0),
                        "end": seg.get('end', 0)
                    })
            else:
                # Single segment fallback
                result["segments"] = [{
                    "text": transcription.text,
                    "start": 0,
                    "end": None
                }]
            
            logger.info(f"🎙️ Groq Whisper: Transcribed {len(result['text'])} chars")
            return result
            
        except Exception as e:
            logger.error(f"❌ Groq Whisper error: {e}")
            return {"error": str(e), "text": "", "segments": []}
    
    # ==========================================
    # LLM REASONING (Cloud - replaces Mistral)
    # ==========================================
    
    def chat_completion(
        self,
        messages: List[Dict[str, str]],
        temperature: float = 0.7,
        max_tokens: int = 2048,
        stream: bool = False
    ) -> Dict[str, Any]:
        """
        Generate chat completion using Groq's GPT-oss-120b model.
        
        Args:
            messages: List of message dicts with 'role' and 'content'
            temperature: Sampling temperature
            max_tokens: Maximum tokens to generate
            stream: Whether to stream response
            
        Returns:
            Dictionary with response content
        """
        if not self.available:
            return {"error": "Groq service not available", "content": ""}
        
        try:
            if stream:
                # Streaming response
                completion = self.client.chat.completions.create(
                    model="openai/gpt-oss-120b",
                    messages=messages,
                    temperature=temperature,
                    max_completion_tokens=max_tokens,
                    top_p=1,
                    reasoning_effort="medium",
                    stream=True,
                    stop=None
                )
                
                # Collect streamed content
                content = ""
                for chunk in completion:
                    delta = chunk.choices[0].delta.content
                    if delta:
                        content += delta
                
                return {"content": content, "model": "openai/gpt-oss-120b"}
            else:
                # Non-streaming response
                completion = self.client.chat.completions.create(
                    model="openai/gpt-oss-120b",
                    messages=messages,
                    temperature=temperature,
                    max_completion_tokens=max_tokens,
                    top_p=1,
                    reasoning_effort="medium",
                    stream=False,
                    stop=None
                )
                
                content = completion.choices[0].message.content
                return {"content": content, "model": "openai/gpt-oss-120b"}
                
        except Exception as e:
            logger.error(f"❌ Groq LLM error: {e}")
            return {"error": str(e), "content": ""}
    
    def generate_forensic_analysis(
        self,
        evidence_text: str,
        media_id: str,
        user_id: str
    ) -> Optional[Dict]:
        """
        Generate forensic memory log using GPT-oss-120b.
        
        Args:
            evidence_text: Formatted evidence from visual/audio analysis
            media_id: Unique media identifier
            user_id: User who owns the media
            
        Returns:
            Structured forensic log dictionary
        """
        system_prompt = """You are a VIDEO FORENSIC REASONING ENGINE.

Your task is to analyze the provided evidence with MAXIMUM CAUTION and ZERO GUESSING.

ABSOLUTE RULES:
1. NEVER assume the identity of small objects unless they are visually clear.
2. If an object is uncertain, label it as "unverified_object".
3. Separate FACTS from INFERENCES strictly.
4. Everything you output MUST be structured as JSON.
5. If something is not visible, say "not visible".
6. If something is inferred, mark it as "inference".

OUTPUT FORMAT (STRICT JSON):
{
  "media_id": "<provided_media_id>",
  "location": {
    "room_type": "<office / room / corridor / unknown>",
    "room_color": "<color or unknown>",
    "building_type": "<office-like / residential / unknown>"
  },
  "objects_detected": [
    {
      "label": "<object name or unverified_object>",
      "confidence": "<high / medium / low>",
      "position": "<on table / in hand / unknown>",
      "verification": "<visual / inferred>"
    }
  ],
  "audio_content": {
    "transcript": "<full transcript if available>",
    "key_phrases": ["phrase1", "phrase2"]
  },
  "facts_only_summary": "<ONLY what is 100% verified>",
  "inference_notes": "<clearly marked reasoning>"
}

Output ONLY valid JSON, nothing else."""

        user_prompt = f"""Analyze this evidence and generate a forensic memory log.

MEDIA ID: {media_id}
USER ID: {user_id}

{evidence_text}

Generate the forensic memory JSON now."""

        result = self.chat_completion(
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": user_prompt}
            ],
            temperature=0.1,
            max_tokens=2048
        )
        
        if "error" in result:
            return None
        
        try:
            import json
            content = result.get("content", "")
            
            # Clean markdown wrapping
            if "```json" in content:
                content = content.split("```json")[1].split("```")[0]
            elif "```" in content:
                content = content.split("```")[1].split("```")[0]
            
            forensic_log = json.loads(content.strip())
            forensic_log["media_id"] = media_id
            forensic_log["user_id"] = user_id
            
            logger.info(f"🔬 Forensic analysis generated for {media_id}")
            return forensic_log
            
        except Exception as e:
            logger.error(f"Failed to parse forensic JSON: {e}")
            return None


# Singleton instance
_service_instance = None


def get_groq_cloud_service() -> GroqCloudService:
    """Get singleton Groq cloud service instance"""
    global _service_instance
    if _service_instance is None:
        _service_instance = GroqCloudService()
    return _service_instance
