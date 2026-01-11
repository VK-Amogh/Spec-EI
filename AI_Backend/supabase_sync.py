"""
SpecEI Supabase Media Sync Service
Fetches media from Supabase, analyzes with Groq, stores in Supermemory.
"""

import os
import logging
import tempfile
import httpx
from typing import List, Dict, Any, Optional
from datetime import datetime

# Load environment
try:
    from dotenv import load_dotenv
    env_path = os.path.join(os.path.dirname(__file__), '.env')
    load_dotenv(env_path)
except ImportError:
    pass

logger = logging.getLogger("SpecEI.SupabaseSync")

# Supabase config
SUPABASE_URL = os.environ.get("SUPABASE_URL", "")
SUPABASE_ANON_KEY = os.environ.get("SUPABASE_ANON_KEY", "")


class SupabaseSyncService:
    """
    Syncs media from Supabase storage to AI analysis pipeline.
    - Fetches media metadata from Supabase DB
    - Downloads files from Supabase storage
    - Runs Groq analysis (Whisper for audio/video, LLaVA for images)
    - Stores results in local DB and Supermemory
    """
    
    def __init__(self):
        self.supabase_url = SUPABASE_URL
        self.supabase_key = SUPABASE_ANON_KEY
        self.client = httpx.AsyncClient(timeout=120.0)
        
        if self.supabase_url and self.supabase_key:
            logger.info(f"[OK] Supabase Sync initialized: {self.supabase_url[:30]}...")
        else:
            logger.warning("[WARN] Supabase credentials not configured")
    
    async def get_user_media(self, user_id: str) -> List[Dict]:
        """Fetch all media records for a user from Supabase"""
        if not self.supabase_url:
            return []
        
        try:
            url = f"{self.supabase_url}/rest/v1/media"
            headers = {
                "apikey": self.supabase_key,
                "Authorization": f"Bearer {self.supabase_key}",
                "Content-Type": "application/json"
            }
            params = {"user_id": f"eq.{user_id}", "select": "*"}
            
            response = await self.client.get(url, headers=headers, params=params)
            
            if response.status_code == 200:
                media_list = response.json()
                logger.info(f"[DATA] Found {len(media_list)} media items for user {user_id[:8]}...")
                return media_list
            else:
                logger.error(f"[ERR] Supabase query failed: {response.status_code}")
                return []
                
        except Exception as e:
            logger.error(f"[ERR] Supabase fetch error: {e}")
            return []
    
    async def download_media(self, file_url: str) -> Optional[bytes]:
        """Download media file from Supabase storage"""
        if not file_url:
            return None
        
        try:
            response = await self.client.get(file_url)
            if response.status_code == 200:
                return response.content
            else:
                logger.error(f"Download failed: {response.status_code}")
                return None
        except Exception as e:
            logger.error(f"Download error: {e}")
            return None
    
    async def analyze_media(self, file_bytes: bytes, media_type: str, filename: str) -> Dict:
        """
        Analyze media using Groq:
        - Audio/Video: Whisper transcription
        - Image: LLaVA vision analysis
        """
        from groq_cloud_service import get_groq_cloud_service
        groq = get_groq_cloud_service()
        
        result = {
            "transcript": None,
            "tags": [],
            "description": None,
            "analyzed_at": datetime.now().isoformat()
        }
        
        if not groq.available:
            logger.warning("[WARN] Groq not available for analysis")
            return result
        
        # Save temp file for analysis
        suffix = os.path.splitext(filename)[1] or ".tmp"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as f:
            f.write(file_bytes)
            temp_path = f.name
        
        try:
            if media_type in ['audio', 'video']:
                # Whisper transcription
                transcript_result = groq.transcribe_audio(temp_path)
                if transcript_result and not transcript_result.get("error"):
                    result["transcript"] = transcript_result.get("text", "")
                    result["segments"] = transcript_result.get("segments", [])
                    logger.info(f"[AUDIO] Transcribed: {len(result['transcript'])} chars")
            
            if media_type in ['image', 'video']:
                # LLaVA vision analysis
                try:
                    from vision_api_service import get_vision_api_service
                    vision = get_vision_api_service()
                    vision_result = await vision.analyze_frame(temp_path)
                    
                    if vision_result and not vision_result.get("error"):
                        # Convert forensic JSON to simple tags
                        tags_list = vision.convert_to_tags(vision_result)
                        result["tags"] = tags_list
                        
                        # Get description
                        result["description"] = vision_result.get("visual_summary") or vision_result.get("summary", "")
                        
                        logger.info(f"[VISION] Vision: {len(tags_list)} tags")
                except Exception as e:
                    logger.warning(f"Vision analysis failed: {e}")
            
        finally:
            # Cleanup temp file
            try:
                os.unlink(temp_path)
            except:
                pass
        
        return result
    
    async def store_to_supermemory(
        self, 
        media_id: str, 
        user_id: str, 
        analysis: Dict,
        media_type: str,
        filename: str = ""
    ) -> bool:
        """Store analysis results in Supermemory"""
        from supermemory_service import get_supermemory_service
        sm = get_supermemory_service()
        
        # Build content for memory
        content_parts = [f"[FILE] {filename}" if filename else f"[MEDIA] {media_type}"]
        
        if analysis.get("transcript"):
            content_parts.append(f"[TRANSCRIPT] {analysis['transcript']}")
        
        if analysis.get("description"):
            content_parts.append(f"[VISUAL] {analysis['description']}")
        
        if analysis.get("tags"):
            tag_names = [t.get("name", t) if isinstance(t, dict) else str(t) for t in analysis["tags"]]
            content_parts.append(f"[TAGS] {', '.join(tag_names)}")
        
        # Always store something (at minimum the file info)
        content = f"Media ID: {media_id}\nUser: {user_id}\nType: {media_type}\nFile: {filename}\n\n" + "\n\n".join(content_parts)
        
        try:
            sm.add_memory(
                content=content,
                user_id=user_id,
                media_id=media_id
            )
            logger.info(f"[CLOUD] Stored in Supermemory: {media_id}")
            return True
        except Exception as e:
            logger.error(f"Supermemory store failed: {e}")
            return False
    
    async def sync_user_media(self, user_id: str) -> Dict:
        """
        Full sync: Fetch → Analyze → Store
        Returns summary of processed items.
        """
        logger.info(f"[SYNC] Starting sync for user: {user_id[:8]}...")
        
        media_list = await self.get_user_media(user_id)
        
        if not media_list:
            return {"status": "no_media", "processed": 0, "total": 0}
        
        processed = 0
        errors = 0
        
        for media in media_list:
            media_id = media.get("id", "")
            file_url = media.get("file_url", "")
            media_type = media.get("type", "image")
            filename = media.get("file_name", "file")
            
            if not file_url:
                continue
            
            try:
                # Download
                file_bytes = await self.download_media(file_url)
                if not file_bytes:
                    errors += 1
                    continue
                
                # Analyze
                analysis = await self.analyze_media(file_bytes, media_type, filename)
                
                # Store
                success = await self.store_to_supermemory(media_id, user_id, analysis, media_type, filename)
                
                if success:
                    processed += 1
                else:
                    errors += 1
                    
            except Exception as e:
                logger.error(f"[ERR] Failed to process {media_id}: {e}")
                errors += 1
        
        logger.info(f"[OK] Sync complete: {processed}/{len(media_list)} processed, {errors} errors")
        
        return {
            "status": "completed",
            "processed": processed,
            "total": len(media_list),
            "errors": errors
        }


# Singleton
_sync_service = None


def get_supabase_sync_service() -> SupabaseSyncService:
    """Get singleton sync service"""
    global _sync_service
    if _sync_service is None:
        _sync_service = SupabaseSyncService()
    return _sync_service
