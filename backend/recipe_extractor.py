import json
import re
from google import genai
from google.genai import types
from typing import Optional, Dict, Any, Tuple, List
from config import config
from models import Recipe


class RecipeExtractor:
    """Extract recipes from videos using Gemini API"""

    def __init__(self):
        """Initialize Gemini API client"""
        if not config.GEMINI_API_KEY:
            raise ValueError("GEMINI_API_KEY is required")

        self.client = genai.Client(api_key=config.GEMINI_API_KEY)
        self.model_id = 'models/gemini-2.0-flash'  # Stable model with better free tier than 2.5

    def _parse_tiktok_description(self, text: str) -> Tuple[str, List[str]]:
        """
        Parse TikTok description to extract caption and hashtags

        Args:
            text: TikTok description text

        Returns:
            Tuple of (caption_text, list_of_hashtags)
        """
        # Split by hashtag symbol
        parts = text.split('#')
        caption = parts[0].strip()

        # Extract hashtags (words after # symbols)
        hashtags = []
        for part in parts[1:]:
            # Take the word(s) before any space or special character
            tag = re.match(r'[\w]+', part)
            if tag:
                hashtags.append('#' + tag.group(0))

        return caption, hashtags

    def extract_from_text(self, text: str, title: str, url: str, platform: str, thumbnail_url: Optional[str] = None, author: str = "") -> Optional[Recipe]:
        """
        Extract recipe from text (description or comment)

        Args:
            text: Recipe text from description or comment
            title: Video title
            url: Original video URL
            platform: Platform name
            thumbnail_url: Video thumbnail URL
            author: Video author/channel name

        Returns:
            Recipe object or None if extraction failed
        """
        try:
            # For TikTok, parse description to extract caption and hashtags
            if platform.lower() == "tiktok":
                caption, hashtags = self._parse_tiktok_description(text)
                hashtags_str = " ".join(hashtags) if hashtags else "none"

                prompt = f"""You are a recipe extraction AI. Extract the recipe from this TikTok video description.

Video Caption: {caption}
Hashtags: {hashtags_str}

Extract the following information:
1. Recipe title - Create a clear, descriptive recipe title based on the caption and hashtags. DO NOT use the caption as-is. Generate a proper recipe name (e.g., if hashtags include #cryingtiger #steak, create a title like "Crying Tiger Steak Recipe").
2. Ingredients list (with exact quantities if stated in the caption)
3. Cooking steps/instructions (if mentioned in the caption)
4. Language of the content (en for English, zh for Chinese, etc.)

Return the information in the following JSON format:
{{
  "title": "Descriptive Recipe Name",
  "ingredients": ["ingredient 1 with quantity", "ingredient 2 with quantity", ...],
  "steps": ["step 1", "step 2", ...],
  "language": "en"
}}

Important guidelines:
- Generate a professional recipe title from the hashtags and caption context
- Keep all quantities EXACTLY as stated in the caption
- ONLY extract ingredients that are explicitly written in the caption text. Do NOT infer or fabricate ingredients from the title, hashtags, or recipe name alone.
- If no ingredients/steps are explicitly listed in the caption, return empty arrays [] — the recipe may be in the video itself.
- Be concise but complete
- CRITICAL: Keep ALL content (title, ingredients, steps) in the ORIGINAL language. Do NOT translate to English or any other language. Output exactly as it appears in the source.
- If the content is in Chinese, keep it in Chinese. If in Korean, keep it in Korean. Never translate.
- If the content is bilingual/multilingual, use the primary language (not English).
- Set the "language" field to the ISO 639-1 code (e.g., "en", "zh", "ko", "ja", "es").
- If this is not a recipe, return: {{"error": "Not a recipe"}}

Return ONLY the JSON object, no other text.
"""
            else:
                # For other platforms, use the original prompt
                prompt = f"""You are a recipe extraction AI. Extract the recipe from this text.

Video Title: {title}

Recipe Text:
{text}

Extract the following information:
1. Recipe title (create a clear title if not explicitly stated, or use the video title if appropriate)
2. Ingredients list (with exact quantities as stated)
3. Cooking steps/instructions (in order, if available)
4. Language of the content (en for English, zh for Chinese, etc.)

Return the information in the following JSON format:
{{
  "title": "Recipe Name",
  "ingredients": ["ingredient 1 with quantity", "ingredient 2 with quantity", ...],
  "steps": ["step 1", "step 2", ...],
  "language": "en"
}}

Important guidelines:
- Keep all quantities EXACTLY as stated
- ONLY extract ingredients that are explicitly listed in the text. Do NOT infer or fabricate ingredients from the video title or recipe name alone.
- If no ingredients/steps are explicitly listed in the text, return empty arrays [] — the recipe may be in the video itself.
- Be concise but complete
- CRITICAL: Keep ALL content (title, ingredients, steps) in the ORIGINAL language. Do NOT translate to English or any other language. Output exactly as it appears in the source.
- If the content is in Chinese, keep it in Chinese. If in Korean, keep it in Korean. Never translate.
- If the content is bilingual/multilingual, use the primary language (not English).
- Set the "language" field to the ISO 639-1 code (e.g., "en", "zh", "ko", "ja", "es").
- If this is not a recipe, return: {{"error": "Not a recipe"}}

Return ONLY the JSON object, no other text.
"""

            response = self.client.models.generate_content(
                model=self.model_id,
                contents=prompt
            )

            return self._parse_response(response.text, url, platform, thumbnail_url, author)

        except Exception as e:
            error_msg = str(e)
            print(f"Error extracting recipe from text: {error_msg}")

            # Check for quota exceeded error
            if "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg or "quota" in error_msg.lower():
                raise Exception("QUOTA_EXCEEDED: Gemini API daily quota exceeded. Please wait until midnight PT for reset or upgrade to pay-as-you-go.")

            return None

    def extract_from_video_file(self, video_path: str, url: str, platform: str, thumbnail_url: Optional[str] = None, author: str = "") -> Optional[Recipe]:
        """
        Extract recipe from downloaded video file

        Args:
            video_path: Path to video file
            url: Original video URL
            platform: Platform name
            thumbnail_url: Video thumbnail URL
            author: Video author/channel name

        Returns:
            Recipe object or None if extraction failed
        """
        try:
            prompt = self._build_prompt()

            # Upload video file to Gemini
            with open(video_path, 'rb') as f:
                video_file = self.client.files.upload(file=f, config={"mime_type": "video/mp4"})

            # Wait for file processing
            import time
            while video_file.state == types.FileState.PROCESSING:
                time.sleep(1)
                video_file = self.client.files.get(name=video_file.name)

            if video_file.state == types.FileState.FAILED:
                print(f"File upload failed: {video_file}")
                return None

            # Generate content from video
            response = self.client.models.generate_content(
                model=self.model_id,
                contents=[prompt, video_file]
            )

            return self._parse_response(response.text, url, platform, thumbnail_url, author)

        except Exception as e:
            error_msg = str(e)
            print(f"Error extracting recipe from video file: {error_msg}")
            import traceback
            traceback.print_exc()

            # Check for quota exceeded error
            if "429" in error_msg or "RESOURCE_EXHAUSTED" in error_msg or "quota" in error_msg.lower():
                raise Exception("QUOTA_EXCEEDED: Gemini API daily quota exceeded. Please wait until midnight PT for reset or upgrade to pay-as-you-go.")

            return None

    def _build_prompt(self) -> str:
        """Build the extraction prompt for Gemini"""
        return """You are a recipe extraction AI. Analyze this cooking video and extract the recipe information.

Extract the following information:
1. Recipe title (create a descriptive name if not explicitly stated)
2. Ingredients list (with quantities if mentioned)
3. Cooking steps/instructions (in order)
4. Language of the content (en for English, zh for Chinese, etc.)

Return the information in the following JSON format:
{
  "title": "Recipe Name",
  "ingredients": ["ingredient 1 with quantity", "ingredient 2 with quantity", ...],
  "steps": ["step 1", "step 2", ...],
  "language": "en"
}

Important guidelines:
- If ingredients appear as text overlays in the video, extract them
- If ingredients are spoken, transcribe them
- Keep ingredient quantities and units
- Number steps in order
- Be concise but complete
- CRITICAL: Keep ALL content (title, ingredients, steps) in the ORIGINAL language. Do NOT translate to English or any other language. Output exactly as it appears in the source.
- If the content is in Chinese, keep it in Chinese. If in Korean, keep it in Korean. Never translate.
- If the content is bilingual/multilingual, use the primary language (not English).
- Set the "language" field to the ISO 639-1 code (e.g., "en", "zh", "ko", "ja", "es").
- If this is not a cooking/recipe video, return: {"error": "Not a recipe video"}

Return ONLY the JSON object, no other text.
"""

    def _parse_response(self, response_text: str, source_url: str, platform: str, thumbnail_url: Optional[str] = None, author: str = "") -> Optional[Recipe]:
        """
        Parse Gemini response into Recipe object

        Args:
            response_text: Raw response from Gemini
            source_url: Original video URL
            platform: Platform name
            thumbnail_url: Video thumbnail URL
            author: Video author/channel name

        Returns:
            Recipe object or None if parsing failed
        """
        try:
            # Clean up response text (remove markdown code blocks if present)
            cleaned_text = response_text.strip()
            if cleaned_text.startswith("```json"):
                cleaned_text = cleaned_text[7:]
            if cleaned_text.startswith("```"):
                cleaned_text = cleaned_text[3:]
            if cleaned_text.endswith("```"):
                cleaned_text = cleaned_text[:-3]
            cleaned_text = cleaned_text.strip()

            # Parse JSON
            data = json.loads(cleaned_text)

            # Check for error
            if "error" in data:
                print(f"Gemini detected non-recipe video: {data['error']}")
                return None

            # Create Recipe object
            recipe = Recipe(
                title=data.get("title", "Untitled Recipe"),
                ingredients=data.get("ingredients", []),
                steps=data.get("steps", []),
                source_url=source_url,
                platform=platform,
                language=data.get("language", "en"),
                thumbnail_url=thumbnail_url,
                author=author
            )

            return recipe

        except json.JSONDecodeError as e:
            print(f"Error parsing JSON response: {str(e)}")
            print(f"Raw response: {response_text}")
            return None
        except Exception as e:
            print(f"Error creating Recipe object: {str(e)}")
            return None


# Singleton instance
recipe_extractor = RecipeExtractor()
