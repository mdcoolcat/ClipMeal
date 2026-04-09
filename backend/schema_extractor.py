"""
Schema.org JSON-LD Recipe Extractor
Extracts recipe data from Schema.org Recipe markup embedded in HTML
"""

import json
import re
import html
from typing import Optional, Dict, Any, List
from bs4 import BeautifulSoup
from models import Recipe


class SchemaExtractor:
    """Extract recipe data from Schema.org JSON-LD markup"""

    def _decode_html_entities(self, text: str) -> str:
        """
        Decode HTML entities like &#039; &quot; &amp; etc.

        Args:
            text: Text with HTML entities

        Returns:
            Decoded text
        """
        if not text:
            return text
        return html.unescape(text)

    def extract_from_html(self, html_content: str, source_url: str) -> Optional[Recipe]:
        """
        Extract recipe from Schema.org JSON-LD markup in HTML

        Args:
            html_content: HTML content of the webpage
            source_url: URL of the source webpage

        Returns:
            Recipe object or None if not found
        """
        soup = BeautifulSoup(html_content, 'html.parser')

        # Find all JSON-LD script tags
        json_ld_scripts = soup.find_all('script', type='application/ld+json')

        for script in json_ld_scripts:
            try:
                data = json.loads(script.string)

                # Handle both direct Recipe objects and @graph arrays
                recipe_data = self._find_recipe_in_data(data)

                if recipe_data:
                    recipe = self._parse_recipe(recipe_data, source_url)
                    if recipe:
                        return recipe

            except (json.JSONDecodeError, AttributeError, TypeError) as e:
                # Skip malformed JSON-LD
                continue

        return None

    def _find_recipe_in_data(self, data: Any) -> Optional[Dict[str, Any]]:
        """
        Find Recipe object in JSON-LD data structure

        Handles:
        - Direct Recipe object: {"@type": "Recipe", ...}
        - Recipe in @graph: {"@graph": [{"@type": "Recipe", ...}, ...]}
        - Recipe nested in other structures

        Args:
            data: Parsed JSON-LD data

        Returns:
            Recipe dictionary or None
        """
        if not isinstance(data, (dict, list)):
            return None

        # Handle list of objects
        if isinstance(data, list):
            for item in data:
                recipe = self._find_recipe_in_data(item)
                if recipe:
                    return recipe
            return None

        # Handle dictionary
        if isinstance(data, dict):
            # Check if this is a Recipe object
            type_value = data.get('@type', '')
            if isinstance(type_value, str) and type_value == 'Recipe':
                return data
            if isinstance(type_value, list) and 'Recipe' in type_value:
                return data

            # Check @graph array
            if '@graph' in data:
                return self._find_recipe_in_data(data['@graph'])

            # Recursively check nested objects
            for value in data.values():
                if isinstance(value, (dict, list)):
                    recipe = self._find_recipe_in_data(value)
                    if recipe:
                        return recipe

        return None

    def _parse_recipe(self, recipe_data: Dict[str, Any], source_url: str) -> Optional[Recipe]:
        """
        Parse Recipe JSON-LD object into Recipe model

        Args:
            recipe_data: Recipe dictionary from JSON-LD
            source_url: Source URL

        Returns:
            Recipe object or None if invalid
        """
        try:
            # Extract title
            title = self._decode_html_entities(recipe_data.get('name', '')).strip()
            if not title:
                return None

            # Extract ingredients
            ingredients = self._extract_ingredients(recipe_data)
            if not ingredients or len(ingredients) < 2:
                return None

            # Extract steps/instructions
            steps = self._extract_instructions(recipe_data)
            if not steps or len(steps) < 2:
                return None

            # Extract thumbnail
            thumbnail_url = self._extract_image(recipe_data)

            # Extract language (default to English)
            language = recipe_data.get('inLanguage', 'en')
            if isinstance(language, dict):
                language = language.get('@value', 'en')

            # Extract author
            author_data = recipe_data.get('author')
            author = None
            if author_data:
                if isinstance(author_data, dict):
                    author = author_data.get('name', '')
                elif isinstance(author_data, str):
                    author = author_data
                elif isinstance(author_data, list) and len(author_data) > 0:
                    first_author = author_data[0]
                    if isinstance(first_author, dict):
                        author = first_author.get('name', '')
                    else:
                        author = str(first_author)

            print(f"DEBUG: Schema.org extraction - Title: {title}")
            print(f"DEBUG: Schema.org extraction - Author from JSON-LD: {author}")
            print(f"DEBUG: Schema.org extraction - Ingredients count: {len(ingredients)}")
            print(f"DEBUG: Schema.org extraction - Steps count: {len(steps)}")

            return Recipe(
                title=title,
                ingredients=ingredients,
                steps=steps,
                source_url=source_url,
                platform="website",
                language=language,
                thumbnail_url=thumbnail_url,
                author=author
            )

        except (KeyError, AttributeError, TypeError) as e:
            return None

    def _extract_ingredients(self, recipe_data: Dict[str, Any]) -> List[str]:
        """
        Extract ingredients from Recipe JSON-LD

        Handles:
        - recipeIngredient: ["ingredient 1", "ingredient 2"]
        - recipeIngredients: ["ingredient 1", "ingredient 2"]
        - ingredients: ["ingredient 1", "ingredient 2"]

        Args:
            recipe_data: Recipe dictionary

        Returns:
            List of ingredient strings
        """
        ingredients = []

        # Try different field names
        for field in ['recipeIngredient', 'recipeIngredients', 'ingredients']:
            if field in recipe_data:
                raw_ingredients = recipe_data[field]

                # Handle array of strings
                if isinstance(raw_ingredients, list):
                    for item in raw_ingredients:
                        if isinstance(item, str):
                            cleaned = self._decode_html_entities(item).strip()
                            if cleaned:
                                ingredients.append(cleaned)
                        elif isinstance(item, dict):
                            # Handle structured ingredient objects
                            text = item.get('text', item.get('name', ''))
                            if text:
                                ingredients.append(self._decode_html_entities(text).strip())

                # Handle single string
                elif isinstance(raw_ingredients, str):
                    cleaned = self._decode_html_entities(raw_ingredients).strip()
                    if cleaned:
                        ingredients.append(cleaned)

                if ingredients:
                    break

        return ingredients

    def _extract_instructions(self, recipe_data: Dict[str, Any]) -> List[str]:
        """
        Extract instructions/steps from Recipe JSON-LD

        Handles multiple formats:
        - recipeInstructions: ["step 1", "step 2"]
        - recipeInstructions: "step 1\nstep 2"
        - recipeInstructions: [{"@type": "HowToStep", "text": "step 1"}, ...]
        - recipeInstructions: [{"@type": "HowToSection", "itemListElement": [...]}]

        Args:
            recipe_data: Recipe dictionary

        Returns:
            List of instruction strings
        """
        steps = []

        # Try different field names
        for field in ['recipeInstructions', 'instructions']:
            if field in recipe_data:
                raw_instructions = recipe_data[field]
                steps = self._parse_instructions(raw_instructions)
                if steps:
                    break

        return steps

    def _parse_instructions(self, raw_instructions: Any) -> List[str]:
        """
        Parse instructions in various formats

        Args:
            raw_instructions: Raw instruction data (string, list, or dict)

        Returns:
            List of instruction strings
        """
        steps = []

        # Handle list
        if isinstance(raw_instructions, list):
            for item in raw_instructions:
                if isinstance(item, str):
                    # Plain string step
                    cleaned = self._clean_instruction_text(item)
                    if cleaned:
                        steps.append(cleaned)
                elif isinstance(item, dict):
                    # HowToStep or HowToSection object
                    step_text = self._extract_step_from_object(item)
                    if step_text:
                        if isinstance(step_text, list):
                            steps.extend(step_text)
                        else:
                            steps.append(step_text)

        # Handle single string (possibly multi-line)
        elif isinstance(raw_instructions, str):
            # Split by newlines or numbered steps
            lines = raw_instructions.split('\n')
            for line in lines:
                cleaned = self._clean_instruction_text(line)
                if cleaned:
                    steps.append(cleaned)

        # Handle single object
        elif isinstance(raw_instructions, dict):
            step_text = self._extract_step_from_object(raw_instructions)
            if step_text:
                if isinstance(step_text, list):
                    steps.extend(step_text)
                else:
                    steps.append(step_text)

        return steps

    def _extract_step_from_object(self, step_obj: Dict[str, Any]) -> Optional[str | List[str]]:
        """
        Extract step text from HowToStep or HowToSection object

        Args:
            step_obj: Step or section dictionary

        Returns:
            Step text or list of step texts, or None
        """
        step_type = step_obj.get('@type', '')

        # HowToStep
        if step_type == 'HowToStep':
            text = step_obj.get('text', step_obj.get('itemListElement', ''))
            if isinstance(text, str):
                cleaned = self._clean_instruction_text(text)
                return cleaned if cleaned else None

        # HowToSection (contains multiple steps)
        elif step_type == 'HowToSection':
            item_list = step_obj.get('itemListElement', [])
            if isinstance(item_list, list):
                section_steps = []
                for item in item_list:
                    if isinstance(item, dict):
                        text = item.get('text', '')
                        if text:
                            cleaned = self._clean_instruction_text(text)
                            if cleaned:
                                section_steps.append(cleaned)
                    elif isinstance(item, str):
                        cleaned = self._clean_instruction_text(item)
                        if cleaned:
                            section_steps.append(cleaned)
                return section_steps if section_steps else None

        # Fallback: try to extract 'text' field
        text = step_obj.get('text', step_obj.get('name', ''))
        if isinstance(text, str):
            cleaned = self._clean_instruction_text(text)
            return cleaned if cleaned else None

        return None

    def _clean_instruction_text(self, text: str) -> str:
        """
        Clean instruction text (remove numbering, extra whitespace, decode HTML entities)

        Args:
            text: Raw instruction text

        Returns:
            Cleaned text
        """
        if not text:
            return ''

        # Decode HTML entities first
        text = self._decode_html_entities(text)

        # Remove leading numbering (e.g., "1. ", "1) ", "Step 1: ")
        text = re.sub(r'^\s*(?:step\s*)?\d+[\.\):\s]+', '', text, flags=re.IGNORECASE)

        # Remove extra whitespace
        text = ' '.join(text.split())

        return text.strip()

    def _extract_image(self, recipe_data: Dict[str, Any]) -> str:
        """
        Extract image URL from Recipe JSON-LD

        Handles:
        - image: "url"
        - image: ["url1", "url2"]
        - image: {"@type": "ImageObject", "url": "url"}

        Args:
            recipe_data: Recipe dictionary

        Returns:
            Image URL string or empty string
        """
        image = recipe_data.get('image', '')

        if isinstance(image, str):
            return image
        elif isinstance(image, list) and image:
            # Take first image
            first_image = image[0]
            if isinstance(first_image, str):
                return first_image
            elif isinstance(first_image, dict):
                return first_image.get('url', '')
        elif isinstance(image, dict):
            return image.get('url', '')

        return ''


# Singleton instance
schema_extractor = SchemaExtractor()
