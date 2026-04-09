"""
Heuristic Recipe Parser
Extracts recipes from custom recipe websites using CSS selector patterns
Fallback for sites without Schema.org or WordPress plugins
"""

from typing import Optional, List, Set
from bs4 import BeautifulSoup, Tag
from models import Recipe
import re
import html


class HeuristicParser:
    """Extract recipes using heuristic HTML parsing"""

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

    # CSS selectors for finding recipe sections
    INGREDIENT_SELECTORS = [
        '.ingredients li',
        '[class*="ingredient"] li',
        '[class*="Ingredient"] li',
        '#ingredients li',
        'ul.ingredients li',
        '.recipe-ingredients li',
        '[id*="ingredient"] li',
        '.ingredient-list li',
        'section[class*="ingredient"] li',
        'div[class*="ingredient"] li',
    ]

    INSTRUCTION_SELECTORS = [
        '.instructions li',
        '.directions li',
        '.steps li',
        '[class*="instruction"] li',
        '[class*="Instruction"] li',
        '[class*="direction"] li',
        '[class*="Direction"] li',
        '[class*="step"] li',
        '#instructions li',
        '#directions li',
        'ul.instructions li',
        'ol.instructions li',
        '.recipe-instructions li',
        '.recipe-directions li',
        '[id*="instruction"] li',
        '[id*="direction"] li',
        'section[class*="instruction"] li',
        'section[class*="direction"] li',
        'div[class*="instruction"] li',
        'div[class*="direction"] li',
    ]

    TITLE_SELECTORS = [
        'h1',
        'h1.recipe-title',
        'h1[class*="recipe"]',
        'h1[class*="Recipe"]',
        '.recipe-title',
        '[class*="recipe-title"]',
        '[class*="Recipe-title"]',
        'h2.recipe-title',
        'h2[class*="recipe"]',
    ]

    def extract_from_html(self, html: str, source_url: str) -> Optional[Recipe]:
        """
        Extract recipe using heuristic HTML parsing

        Args:
            html: HTML content
            source_url: Source URL

        Returns:
            Recipe object or None if extraction failed
        """
        soup = BeautifulSoup(html, 'html.parser')

        # Extract title
        title = self._extract_title(soup)
        if not title:
            return None

        # Extract ingredients
        ingredients = self._extract_ingredients(soup)
        if not ingredients or len(ingredients) < 3:
            # Need at least 3 ingredients for valid recipe
            return None

        # Extract instructions
        steps = self._extract_instructions(soup)
        if not steps or len(steps) < 2:
            # Need at least 2 steps for valid recipe
            return None

        # Extract thumbnail
        thumbnail_url = self._extract_thumbnail(soup)

        print(f"DEBUG: Heuristic extraction - Title: {title}")
        print(f"DEBUG: Heuristic extraction - Ingredients count: {len(ingredients)}")
        print(f"DEBUG: Heuristic extraction - Steps count: {len(steps)}")

        return Recipe(
            title=title,
            ingredients=ingredients,
            steps=steps,
            source_url=source_url,
            platform="website",
            language="en",
            thumbnail_url=thumbnail_url,
            author=None
        )

    def _extract_title(self, soup: BeautifulSoup) -> str:
        """
        Extract recipe title from HTML

        Args:
            soup: BeautifulSoup object

        Returns:
            Title string or empty string
        """
        for selector in self.TITLE_SELECTORS:
            elem = soup.select_one(selector)
            if elem:
                title = self._decode_html_entities(elem.get_text(strip=True))
                # Filter out obviously non-recipe titles
                if title and len(title) > 3 and len(title) < 200:
                    return title

        return ''

    def _extract_ingredients(self, soup: BeautifulSoup) -> List[str]:
        """
        Extract ingredients from HTML

        Args:
            soup: BeautifulSoup object

        Returns:
            List of ingredient strings
        """
        ingredients_set = set()  # Use set to avoid duplicates
        all_items = []  # Collect all items for ordering

        for selector in self.INGREDIENT_SELECTORS:
            items = soup.select(selector)
            if items:
                all_items.extend(items)  # Keep track of all items
                for item in items:
                    text = self._decode_html_entities(item.get_text(strip=True))
                    # Validate ingredient text
                    if self._is_valid_ingredient(text):
                        ingredients_set.add(text)

                # If we found ingredients, stop trying other selectors
                if len(ingredients_set) >= 3:
                    break

        # Sort ingredients by their document order, using all_items for reference
        def get_sort_key(ingredient_text):
            found_elem = soup.find(string=re.compile(re.escape(ingredient_text)))
            if found_elem and found_elem.parent in all_items:
                try:
                    return all_items.index(found_elem.parent)
                except ValueError:
                    return 999
            return 999

        return sorted(list(ingredients_set), key=get_sort_key)[:20]  # Limit to 20 ingredients

    def _extract_instructions(self, soup: BeautifulSoup) -> List[str]:
        """
        Extract instructions from HTML

        Args:
            soup: BeautifulSoup object

        Returns:
            List of instruction strings
        """
        steps = []
        seen_steps = set()  # Track unique steps

        for selector in self.INSTRUCTION_SELECTORS:
            items = soup.select(selector)
            if items:
                for item in items:
                    text = self._decode_html_entities(item.get_text(strip=True))
                    # Validate instruction text
                    if self._is_valid_instruction(text) and text not in seen_steps:
                        steps.append(text)
                        seen_steps.add(text)

                # If we found instructions, stop trying other selectors
                if len(steps) >= 2:
                    break

        return steps[:30]  # Limit to 30 steps

    def _is_valid_ingredient(self, text: str) -> bool:
        """
        Validate ingredient text

        Args:
            text: Ingredient text

        Returns:
            True if valid ingredient
        """
        if not text or len(text) < 2:
            return False

        # Too long to be an ingredient
        if len(text) > 200:
            return False

        # Filter out common non-ingredient text
        exclude_patterns = [
            r'^ingredients?:?$',
            r'^for the',
            r'^recipe$',
            r'^print$',
            r'^pin$',
            r'^share$',
            r'^save$',
        ]

        text_lower = text.lower()
        for pattern in exclude_patterns:
            if re.match(pattern, text_lower):
                return False

        return True

    def _is_valid_instruction(self, text: str) -> bool:
        """
        Validate instruction text

        Args:
            text: Instruction text

        Returns:
            True if valid instruction
        """
        if not text or len(text) < 5:
            return False

        # Too long to be a single instruction
        if len(text) > 1000:
            return False

        # Filter out common non-instruction text
        exclude_patterns = [
            r'^instructions?:?$',
            r'^directions?:?$',
            r'^steps?:?$',
            r'^method:?$',
            r'^print$',
            r'^pin$',
            r'^share$',
            r'^save$',
        ]

        text_lower = text.lower()
        for pattern in exclude_patterns:
            if re.match(pattern, text_lower):
                return False

        # Instructions should contain verbs/action words
        action_words = ['add', 'mix', 'stir', 'pour', 'bake', 'cook', 'heat', 'place', 'put', 'remove', 'cut', 'chop', 'slice', 'combine', 'whisk', 'fold', 'blend', 'serve', 'prepare']
        has_action = any(word in text_lower for word in action_words)

        return has_action

    def _extract_thumbnail(self, soup: BeautifulSoup) -> str:
        """
        Extract thumbnail/recipe image from HTML

        Args:
            soup: BeautifulSoup object

        Returns:
            Image URL or empty string
        """
        # Try Open Graph image first
        og_image = soup.find('meta', property='og:image')
        if og_image and og_image.get('content'):
            return og_image['content']

        # Try Twitter card image
        twitter_image = soup.find('meta', {'name': 'twitter:image'})
        if twitter_image and twitter_image.get('content'):
            return twitter_image['content']

        # Try recipe-specific image selectors
        image_selectors = [
            '.recipe-image img',
            '[class*="recipe-image"] img',
            '[class*="Recipe-image"] img',
            'figure img',
            'article img',
            '.entry-content img',
        ]

        for selector in image_selectors:
            img = soup.select_one(selector)
            if img:
                src = img.get('src', img.get('data-src', ''))
                if src and 'http' in src:
                    return src

        return ''


# Singleton instance
heuristic_parser = HeuristicParser()
