from dataclasses import dataclass

import anthropic

from app.schemas.location import LocationRecord, LocationType
from app.schemas.preferences import PreferenceProfile
from app.schemas.scoring import ScoringResult
from app.schemas.simulation import clean_prompt_text

# Haiku is plenty for a short, templated writeup from structured data — no
# need for Opus/Sonnet-level reasoning here, and it's both cheaper and faster
# per call.
MODEL = "claude-haiku-4-5-20251001"
MAX_TOKENS = 100
# One note of ~20 words is about 30 tokens; five of them plus the JSON around
# them fit comfortably in this.
COMBINED_MAX_TOKENS = 700

# What the notes should be. The hard cap is looser than the target on purpose:
# it only rejects a runaway answer, never a slightly long one.
NOTE_WORDS = "15-20"
MAX_NOTE_WORDS = 45

# How much places must differ before we call it a difference worth mentioning.
MIN_DISTANCE_SPREAD_KM = 0.5
MIN_MATCH_SPREAD = 0.03
MIN_VISIBILITY_SPREAD = 0.1

_client: anthropic.Anthropic | None = None

TYPE_LABELS = {
    LocationType.BEACH: "beach",
    LocationType.PARK: "park",
    LocationType.WATERFRONT: "waterfront",
    LocationType.PROMENADE: "promenade",
    LocationType.ELEVATED_VIEWPOINT: "viewpoint",
}

# Plain facts about each kind of place, so the model has something true to say
# about it without inventing details.
TYPE_SETTINGS = {
    LocationType.BEACH: "a beach with an open horizon over the water",
    LocationType.PARK: "a green park",
    LocationType.WATERFRONT: "a waterfront with views over the water",
    LocationType.PROMENADE: "a waterfront promenade",
    LocationType.ELEVATED_VIEWPOINT: "an elevated viewpoint with a wide view",
}

NOTES_TOOL = {
    "name": "submit_notes",
    "description": "Submit one short note for each place.",
    "input_schema": {
        "type": "object",
        "properties": {
            "notes": {
                "type": "array",
                "items": {
                    "type": "object",
                    "properties": {"id": {"type": "string"}, "text": {"type": "string"}},
                    "required": ["id", "text"],
                },
            }
        },
        "required": ["notes"],
    },
}


@dataclass(frozen=True)
class PlaceFacts:
    place: LocationRecord
    setting: str
    # What genuinely sets this place apart from the others; empty if nothing does.
    sets_apart: list[str]


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


def describe_differences(
    places: list[tuple[LocationRecord, ScoringResult]],
) -> list[PlaceFacts]:
    """What actually distinguishes each place from the others, worked out in
    code so the model never has to guess. Nearby places share one forecast, so
    often the only real differences are distance and kind of place.
    """
    distances = [place.distance_km for place, _ in places]
    matches = [score.preference_match_score for _, score in places]
    visibilities = [score.visibility_likelihood for _, score in places]
    types = [place.type for place, _ in places]
    shared_summary = places[0][1].cloud_cover_summary

    facts = []
    for place, score in places:
        notes: list[str] = []

        if max(distances) - min(distances) >= MIN_DISTANCE_SPREAD_KM:
            if place.distance_km == min(distances) and distances.count(min(distances)) == 1:
                notes.append("the closest of these places")
            elif place.distance_km == max(distances) and distances.count(max(distances)) == 1:
                notes.append("the farthest of these places")

        if len(set(types)) > 1 and types.count(place.type) == 1:
            notes.append(f"the only {TYPE_LABELS[place.type]} among these places")

        match = score.preference_match_score
        if max(matches) - min(matches) >= MIN_MATCH_SPREAD:
            if match == max(matches) and matches.count(match) == 1:
                notes.append("the best match for the user's taste of these places")
            elif match == min(matches) and matches.count(match) == 1:
                notes.append("a weaker match for the user's taste than the others")

        visibility = score.visibility_likelihood
        if max(visibilities) - min(visibilities) >= MIN_VISIBILITY_SPREAD:
            if visibility == max(visibilities) and visibilities.count(visibility) == 1:
                notes.append("the clearest view of the sun of these places")
            elif visibility == min(visibilities) and visibilities.count(visibility) == 1:
                notes.append("a less clear view of the sun than the others")

        if score.cloud_cover_summary != shared_summary:
            notes.append(f"its own forecast there is {score.cloud_cover_summary}")

        facts.append(PlaceFacts(place=place, setting=TYPE_SETTINGS[place.type], sets_apart=notes))
    return facts


def generate_comparative_explanations(
    places: list[tuple[LocationRecord, ScoringResult]],
    preferences: PreferenceProfile,
    client: anthropic.Anthropic | None = None,
) -> dict[str, str]:
    """One short note per place from a single request, so the model can see all
    of them and avoid repeating itself. Returns {location id: note}. Raises
    ValueError if the answer doesn't cover exactly these places with usable
    text; the caller then falls back to one request per place.
    """
    client = client or _get_client()
    facts = describe_differences(places)

    response = client.messages.create(
        model=MODEL,
        max_tokens=COMBINED_MAX_TOKENS,
        messages=[
            {
                "role": "user",
                "content": _build_comparative_prompt(facts, places[0][1], preferences),
            }
        ],
        tools=[NOTES_TOOL],
        tool_choice={"type": "tool", "name": NOTES_TOOL["name"]},
    )
    submitted = next(
        (block.input for block in response.content if block.type == "tool_use"), None
    )
    return _validated_notes(submitted, [place.id for place, _ in places])


def _validated_notes(submitted: object, expected_ids: list[str]) -> dict[str, str]:
    notes = submitted.get("notes") if isinstance(submitted, dict) else None
    if not isinstance(notes, list):
        raise ValueError("no notes in the response")

    by_id: dict[str, str] = {}
    for note in notes:
        if not isinstance(note, dict) or not isinstance(note.get("id"), str):
            raise ValueError("malformed note")
        text = note.get("text")
        if not isinstance(text, str) or not text.strip():
            raise ValueError("empty note")
        if note["id"] in by_id:
            raise ValueError("duplicate id")
        if len(text.split()) > MAX_NOTE_WORDS:
            raise ValueError("note too long")
        by_id[note["id"]] = text.strip()

    if set(by_id) != set(expected_ids):
        raise ValueError("notes don't match the places asked about")
    if len(set(by_id.values())) < len(by_id):
        raise ValueError("identical notes")  # the very repetition this exists to avoid
    return by_id


def _preferences_text(preferences: PreferenceProfile) -> str:
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
    return (
        ", ".join(f"{label} ({value:.1f})" for label, value in top_preferences)
        if top_preferences
        else "no strong sky-color preference stated"
    )


def _forecast_text(score: ScoringResult) -> str:
    colors = score.color_probabilities
    return f"""- Cloud cover: {score.cloud_cover_summary}
- Sun visibility likelihood: {score.visibility_likelihood:.0%}
- Color chances: pink {colors.pink:.0%}, purple {colors.purple:.0%}, \
orange {colors.orange:.0%}, red {colors.red:.0%}, golden {colors.golden:.0%}
- Overall match to this user's taste: {score.preference_match_score:.0%}"""


_STYLE_RULES = """Write directly to the user ("you"). Do not use technical jargon, do not \
mention "cloud effect" or internal scoring terms, and do not print raw \
numbers/percentages verbatim — translate them into plain language (e.g. "high odds of \
catching golden light" rather than "golden: 88%"). Do not mention a time of day (no \
"tonight", "this evening" or "this morning"): it may be a sunrise or a sunset."""


def _place_name(location: LocationRecord) -> str:
    # Names come from OpenStreetMap, i.e. from anyone: keep them plain text.
    return clean_prompt_text(location.name) or "this place"


def _build_prompt(
    location: LocationRecord, score: ScoringResult, preferences: PreferenceProfile
) -> str:
    return f"""Write one short, warm sentence ({NOTE_WORDS} words, no preamble) saying why \
this location and forecast were recommended to a user for their sunset/sunrise viewing, \
mentioning briefly how the forecast suits their taste.

Location: {_place_name(location)} ({location.type.value}), {location.distance_km} km away
User's stated preferences (0-1 scale): {_preferences_text(preferences)}

Forecast:
{_forecast_text(score)}

{_STYLE_RULES}"""


def _build_comparative_prompt(
    facts: list[PlaceFacts], shared_score: ScoringResult, preferences: PreferenceProfile
) -> str:
    lines = []
    for number, fact in enumerate(facts, start=1):
        place = fact.place
        apart = "; ".join(fact.sets_apart) or "nothing in particular"
        lines.append(
            f'{number}. id={place.id} | {_place_name(place)} | {fact.setting}, '
            f"{place.distance_km} km away | sets it apart: {apart}"
        )
    places_text = "\n".join(lines)

    return f"""Write one short note for each of these places, recommended to a user for their \
sunset/sunrise viewing. Submit them with the submit_notes tool, one note per place, using \
each place's id exactly as given.

Each note is ONE sentence of {NOTE_WORDS} words, written to the user ("you"):
- Lead with what sets that place apart, using ONLY the "sets it apart" facts and the \
place's setting.
- Then add a few words on how the forecast suits the user's taste.
- If a place has nothing that sets it apart, write one plain sentence on how the forecast \
fits what the user likes, in different words from the other places' notes.
- Never repeat the same wording across notes, and never invent details (no benches, \
crowds, facilities, and no assuming it is the ocean or sea: say "water" unless told \
otherwise).

User's stated preferences (0-1 scale): {_preferences_text(preferences)}

Forecast (the same for all these places unless a place says otherwise):
{_forecast_text(shared_score)}

Places, best match first:
{places_text}

{_STYLE_RULES}"""
