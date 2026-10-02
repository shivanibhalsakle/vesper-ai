import hashlib
from abc import ABC, abstractmethod

import redis
from openai import OpenAI
from sqlalchemy.orm import Session

from app.core.config import get_settings
from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import SimulationRequest, SimulationResponse
from app.services.cache import Cache, RedisCache
from app.services.image_limits import ensure_within_daily_limit, record_usage, remaining_today

# Identical prompts (same location, event, sky conditions) reuse the same
# generated image for a day instead of paying for another OpenAI call —
# this doesn't count against the user's daily limit, since it costs us
# nothing (see generate_simulation).
SIMULATION_CACHE_TTL_SECONDS = 60 * 60 * 24


LOCATION_TYPE_FOREGROUND = {
    LocationType.BEACH: "a sandy beach with the horizon over open water",
    LocationType.PARK: "a green park landscape",
    LocationType.WATERFRONT: "a waterfront promenade with calm water reflecting the sky",
    LocationType.PROMENADE: "a paved waterfront promenade",
    LocationType.ELEVATED_VIEWPOINT: "an elevated vantage point overlooking the skyline and horizon",
}


class ImageGenProvider(ABC):
    @abstractmethod
    def generate_image(self, prompt: str) -> str:
        """Returns an image URL (or data URI) for the given prompt."""


class UnavailableImageProvider(ImageGenProvider):
    """Placeholder until a real provider (Imagen/Stability/OpenAI) is chosen
    and wired in here — deliberately deferred per the product brief until the
    Scoring Engine and prompt structure could be tested against real forecasts.
    """

    def generate_image(self, prompt: str) -> str:
        raise NotImplementedError("No image-generation provider configured yet.")

class OpenAIImageProvider(ImageGenProvider):
    """Generates images via OpenAI's gpt-image-2 model. The API only returns
    base64-encoded image data (no hosted URL), so this returns a data: URI —
    the Flutter client needs Image.memory (not Image.network) to render it.
    """

    def __init__(self, client: OpenAI | None = None):
        self._client = client or OpenAI(api_key=get_settings().openai_api_key)

    def generate_image(self, prompt: str) -> str:
        result = self._client.images.generate(
            model="gpt-image-2",
            prompt=prompt,
            size="1024x1024",
            quality="medium",
        )
        b64_data = result.data[0].b64_json
        return f"data:image/png;base64,{b64_data}"


def _get_default_provider() -> ImageGenProvider:
    if get_settings().openai_api_key:
        return OpenAIImageProvider()
    return UnavailableImageProvider()


def build_simulation_prompt(request: SimulationRequest) -> str:
    foreground = LOCATION_TYPE_FOREGROUND.get(
        request.location_type, "a scenic outdoor viewpoint"
    )
    event_word = "sunrise" if request.event == SunEvent.SUNRISE else "sunset"

    return (
        f"A realistic photograph-style illustration of a {event_word} at "
        f"{request.location_name}, viewed from {foreground}. "
        f"Sky condition: {request.cloud_cover_summary}. "
        f"{_color_description(request.color_probabilities)} "
        f"{_sun_visibility_description(request.visibility_likelihood)} "
        "Wide-angle landscape composition, natural lighting, no people, no text overlays."
    )


def _color_description(colors: ColorProbabilities) -> str:
    ranked = sorted(
        [
            ("pink", colors.pink),
            ("purple", colors.purple),
            ("orange", colors.orange),
            ("red", colors.red),
            ("golden", colors.golden),
        ],
        key=lambda item: item[1],
        reverse=True,
    )
    dominant = [name for name, p in ranked if p >= 0.5]
    hints = [name for name, p in ranked if 0.25 <= p < 0.5]

    parts = []
    if dominant:
        parts.append(f"Vivid {', '.join(dominant)} tones dominate the sky.")
    if hints:
        parts.append(f"Subtle hints of {', '.join(hints)} are visible.")
    if not parts:
        parts.append("The sky shows soft, muted tones.")
    return " ".join(parts)


def _sun_visibility_description(visibility_likelihood: float) -> str:
    if visibility_likelihood >= 0.7:
        return "The sun is clearly visible as a bright disc."
    if visibility_likelihood >= 0.3:
        return "The sun is partially visible, glowing through the clouds."
    return "The sun is obscured, its light diffusing through the clouds."


def generate_simulation(
    request: SimulationRequest,
    user_id: str,
    db: Session,
    provider: ImageGenProvider | None = None,
    cache: Cache | None = None,
) -> SimulationResponse:
    provider = provider or _get_default_provider()
    cache = cache if cache is not None else RedisCache()
    prompt = build_simulation_prompt(request)
    cache_key = f"simulation:{hashlib.sha256(prompt.encode()).hexdigest()}"

    cached_image = _cache_get(cache, cache_key)
    if cached_image is not None:
        return SimulationResponse(
            prompt=prompt,
            image_url=cached_image,
            provider_status="generated",
            remaining_today=remaining_today(db, user_id),
        )

    # Raises ImageLimitExceeded if today's cap is already hit — checked here,
    # before paying for a generation, not recorded until it actually succeeds.
    ensure_within_daily_limit(db, user_id)

    try:
        image_url = provider.generate_image(prompt)
        status = "generated"
        _cache_set(cache, cache_key, image_url)
        record_usage(db, user_id)
    except NotImplementedError:
        image_url = None
        status = "not_configured"
    except Exception:
        image_url = None
        status = "error"

    return SimulationResponse(
        prompt=prompt,
        image_url=image_url,
        provider_status=status,
        remaining_today=remaining_today(db, user_id),
    )


def _cache_get(cache: Cache, key: str) -> str | None:
    try:
        return cache.get(key)
    except redis.RedisError:
        return None


def _cache_set(cache: Cache, key: str, value: str) -> None:
    try:
        cache.set(key, value, SIMULATION_CACHE_TTL_SECONDS)
    except redis.RedisError:
        pass
