"""Generate the same sky preview at different quality levels, to compare them.

Every image is a real OpenAI call and costs money: roughly $0.006 at low and
$0.05 at medium, so a run of the defaults is about six cents. Run it inside the
backend container, then copy the pictures out to look at them side by side:

  docker exec sunset_api python -m scripts.compare_image_quality
  docker cp sunset_api:/tmp/quality-test ./quality-test

  ... --location "Brighton Beach" --type beach   a different scene
  ... --quality low medium high                  which levels to make

If low looks good enough, set IMAGE_QUALITY=low on Render.
"""

import argparse
import base64
import sys
import time
from pathlib import Path

from openai import OpenAI

from app.core.config import get_settings
from app.schemas.location import LocationType
from app.schemas.scoring import ColorProbabilities
from app.schemas.session import SunEvent
from app.schemas.simulation import SimulationRequest
from app.services.simulation import build_simulation_prompt


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--location", default="Brooklyn Bridge Park")
    parser.add_argument(
        "--type", choices=[t.value for t in LocationType], default=LocationType.PARK.value
    )
    parser.add_argument(
        "--quality", nargs="+", choices=["low", "medium", "high"], default=["low", "medium"]
    )
    parser.add_argument("--out", type=Path, default=Path("/tmp/quality-test"))
    args = parser.parse_args(argv)

    api_key = get_settings().openai_api_key
    if not api_key:
        print("OPENAI_API_KEY is not set, so no images can be made.")
        return 1

    request = SimulationRequest(
        location_name=args.location,
        location_type=LocationType(args.type),
        event=SunEvent.SUNSET,
        cloud_cover_summary="light cloud cover (high clouds)",
        visibility_likelihood=0.85,
        color_probabilities=ColorProbabilities(
            pink=0.55, purple=0.3, orange=0.8, red=0.2, golden=0.7
        ),
    )
    prompt = build_simulation_prompt(request)
    args.out.mkdir(parents=True, exist_ok=True)
    (args.out / "prompt.txt").write_text(prompt, encoding="utf-8")
    print(f"Prompt: {prompt}\n")

    client = OpenAI(api_key=api_key)
    for quality in args.quality:
        started = time.monotonic()
        result = client.images.generate(
            model="gpt-image-2", prompt=prompt, size="1024x1024", quality=quality
        )
        image = base64.b64decode(result.data[0].b64_json)
        path = args.out / f"{quality}.png"
        path.write_bytes(image)
        print(f"{quality:>6}: {len(image) / 1024:,.0f} KB in {time.monotonic() - started:.0f}s")

    print(f"\nSaved to {args.out}. Copy them out with:")
    print(f"  docker cp sunset_api:{args.out} ./quality-test")
    return 0


if __name__ == "__main__":
    sys.exit(main())
