import anthropic

from app.schemas.location import LocationRecord
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ScoringResult

MODEL = "claude-opus-4-8"
MAX_TOKENS = 200

_client: anthropic.Anthropic | None = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        _client = anthropic.Anthropic()
    return _client


def generate_explanation(
    location: LocationRecord,
    score: ScoringResult,
    preferences: PreferenceProfile,
    client: anthropic.Anthropic | None = None,
) -> str:
    client = client or _get_client()

    response = client.messages.create(
        model=MODEL,
        max_tokens=MAX_TOKENS,
        messages=[{"role": "user", "content": _build_prompt(location, score, preferences)}],
    )
    return next(block.text for block in response.content if block.type == "text").strip()


def _build_prompt(
    location: LocationRecord, score: ScoringResult, preferences: PreferenceProfile
) -> str:
    top_preferences = sorted(
        (
            (label, value)
            for label, value in [
                ("clear sky / visible sun", preferences.clear_sky),
                ("dramatic clouds", preferences.dramatic_clouds),
                ("pink/purple tones", preferences.pink_purple),
                ("golden/orange light", preferences.golden_orange),
                ("red skies", preferences.red_sky),
            ]
            if value > 0
        ),
        key=lambda item: item[1],
        reverse=True,
    )
    preferences_text = (
        ", ".join(f"{label} ({value:.1f})" for label, value in top_preferences)
        if top_preferences
        else "no strong sky-color preference stated"
    )
    colors = score.color_probabilities

    return f"""Write a short, warm explanation (2-3 sentences, no preamble) of why \
this location and forecast were recommended to a user for their sunset/sunrise viewing.

Location: {location.name} ({location.type.value}), {location.distance_km} km away
User's stated preferences (0-1 scale): {preferences_text}

Forecast:
- Cloud cover: {score.cloud_cover_summary}
- Sun visibility likelihood: {score.visibility_likelihood:.0%}
- Color chances: pink {colors.pink:.0%}, purple {colors.purple:.0%}, \
orange {colors.orange:.0%}, red {colors.red:.0%}, golden {colors.golden:.0%}
- Overall match to this user's taste: {score.preference_match_score:.0%}

Write directly to the user ("you"). Reference the specific colors/conditions they care \
about. Do not use technical jargon, do not mention "cloud effect" or internal scoring \
terms, and do not print raw numbers/percentages verbatim — translate them into plain \
language (e.g. "high odds of catching golden light" rather than "golden: 88%")."""
