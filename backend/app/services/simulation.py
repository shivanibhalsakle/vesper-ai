from abc import ABC, abstractmethod

from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import SimulationRequest, SimulationResponse

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
    request: SimulationRequest, provider: ImageGenProvider | None = None
) -> SimulationResponse:
    provider = provider or UnavailableImageProvider()
    prompt = build_simulation_prompt(request)

    try:
        image_url = provider.generate_image(prompt)
        status = "generated"
    except NotImplementedError:
        image_url = None
        status = "not_configured"
    except Exception:
        image_url = None
        status = "error"

    return SimulationResponse(prompt=prompt, image_url=image_url, provider_status=status)
