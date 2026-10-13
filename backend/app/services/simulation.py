import hashlib
import logging
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
from app.services.preview_storage import (
    PreviewStorage,
    decode_data_uri,
    get_default_storage,
    shrink_data_uri,
)
from app.services.previews import find_by_prompt, save_preview

logger = logging.getLogger(__name__)

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


_DEFAULT_STORAGE = object()


def generate_simulation(
    request: SimulationRequest,
    user_id: str,
    db: Session,
    provider: ImageGenProvider | None = None,
    cache: Cache | None = None,
    storage: PreviewStorage | None | object = _DEFAULT_STORAGE,
) -> SimulationResponse:
    provider = provider or _get_default_provider()
    cache = cache if cache is not None else RedisCache()
    if storage is _DEFAULT_STORAGE:
        storage = get_default_storage()
    prompt = build_simulation_prompt(request)
    prompt_hash = hashlib.sha256(prompt.encode()).hexdigest()
    cache_key = f"simulation:{prompt_hash}"

    # The user already generated this exact sky: show the saved one. No
    # provider call and no use of today's allowance.
    if storage is not None:
        existing = find_by_prompt(db, user_id, prompt_hash)
        if existing is not None:
            try:
                return SimulationResponse(
                    prompt=prompt,
                    image_url=storage.signed_url(existing.storage_path),
                    provider_status="generated",
                    remaining_today=remaining_today(db, user_id),
                    preview_id=existing.id,
                    saved=True,
                )
            except Exception:
                logger.warning("Saved preview %s could not be read", existing.id, exc_info=True)

    cached_image = _cache_get(cache, cache_key)
    if cached_image is not None:
        # Someone generated this sky already today: costs us nothing, so it
        # doesn't count — but it still lands in this user's gallery.
        image_url, preview_id = _keep(db, storage, user_id, prompt_hash, prompt, request, cached_image)
        return SimulationResponse(
            prompt=prompt,
            image_url=image_url,
            provider_status="generated",
            remaining_today=remaining_today(db, user_id),
            preview_id=preview_id,
            saved=preview_id is not None,
        )

    # Raises ImageLimitExceeded if today's cap is already hit — checked here,
    # before paying for a generation, not recorded until it actually succeeds.
    ensure_within_daily_limit(db, user_id)

    preview_id = None
    try:
        # Shrunk once, up front: the response, the cache and the stored copy
        # are all the small WebP, not the multi-megabyte PNG.
        image_url = shrink_data_uri(provider.generate_image(prompt))
        status = "generated"
        _cache_set(cache, cache_key, image_url)
        record_usage(db, user_id)
    except NotImplementedError:
        image_url = None
        status = "not_configured"
    except Exception:
        image_url = None
        status = "error"

    if image_url is not None:
        image_url, preview_id = _keep(db, storage, user_id, prompt_hash, prompt, request, image_url)

    return SimulationResponse(
        prompt=prompt,
        image_url=image_url,
        provider_status=status,
        remaining_today=remaining_today(db, user_id),
        preview_id=preview_id,
        saved=preview_id is not None,
    )


def _keep(
    db: Session,
    storage: PreviewStorage | None,
    user_id: str,
    prompt_hash: str,
    prompt: str,
    request: SimulationRequest,
    image_url: str,
) -> tuple[str, str | None]:
    """Saves the image to the user's gallery. Returns (url to show, saved
    preview id). Never raises: if it can't be kept, the user still gets the
    image they generated, just not saved."""
    if storage is None:
        return image_url, None
    data = decode_data_uri(image_url)
    if data is None:
        return image_url, None  # a hosted URL, nothing we can re-encode
    try:
        row = save_preview(db, storage, user_id, prompt_hash, prompt, request, data)
        return storage.signed_url(row.storage_path), row.id
    except Exception:
        logger.warning("Could not save sky preview for %s", user_id, exc_info=True)
        db.rollback()
        return image_url, None


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
