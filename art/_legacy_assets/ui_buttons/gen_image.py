#!/usr/bin/env python3
# /// script
# requires-python = ">=3.10"
# dependencies = [
#     "google-genai>=1.0.0",
#     "pillow>=10.0.0",
# ]
# ///
"""
Generate UI button images via Google Nano Banana Pro (Gemini 3 Pro Image) API.

FIX vs upstream skill script:
  - PRESERVES alpha channel (transparent PNG). Upstream composited RGBA onto
    a white background, which destroys transparency needed for UI buttons.
  - Saves directly as RGBA PNG when the model returns an alpha channel.

Usage:
    uv run gen_image.py --prompt "..." --filename "out.png" [--resolution 1K|2K|4K] --api-key KEY
"""
import argparse
import os
import sys
from pathlib import Path


def get_api_key(provided_key: str | None) -> str | None:
    if provided_key:
        return provided_key
    return os.environ.get("GEMINI_API_KEY")


def main():
    parser = argparse.ArgumentParser(
        description="Generate UI button images (transparent PNG) via Gemini 3 Pro Image"
    )
    parser.add_argument("--prompt", "-p", required=True, help="Image description/prompt")
    parser.add_argument("--filename", "-f", required=True, help="Output PNG filename")
    parser.add_argument("--input-image", "-i", help="Optional input image for editing")
    parser.add_argument("--resolution", "-r", choices=["1K", "2K", "4K"], default="1K")
    parser.add_argument("--api-key", "-k", help="Gemini API key (overrides GEMINI_API_KEY)")
    args = parser.parse_args()

    api_key = get_api_key(args.api_key)
    if not api_key:
        print("Error: No API key provided.", file=sys.stderr)
        print("  Provide --api-key or set GEMINI_API_KEY", file=sys.stderr)
        sys.exit(1)

    from google import genai
    from google.genai import types
    from PIL import Image as PILImage

    client = genai.Client(api_key=api_key)
    output_path = Path(args.filename)
    output_path.parent.mkdir(parents=True, exist_ok=True)

    input_image = None
    output_resolution = args.resolution
    if args.input_image:
        try:
            input_image = PILImage.open(args.input_image)
            if args.resolution == "1K":
                w, h = input_image.size
                mx = max(w, h)
                output_resolution = "4K" if mx >= 3000 else ("2K" if mx >= 1500 else "1K")
        except Exception as e:
            print(f"Error loading input image: {e}", file=sys.stderr)
            sys.exit(1)

    contents = [input_image, args.prompt] if input_image else args.prompt
    print(f"Generating ({output_resolution})...")

    try:
        response = client.models.generate_content(
            model="gemini-3-pro-image-preview",
            contents=contents,
            config=types.GenerateContentConfig(
                response_modalities=["TEXT", "IMAGE"],
                image_config=types.ImageConfig(image_size=output_resolution),
            ),
        )

        image_saved = False
        for part in response.parts:
            if part.text is not None:
                print(f"Model: {part.text}")
            elif part.inline_data is not None:
                from io import BytesIO
                data = part.inline_data.data
                if isinstance(data, str):
                    import base64
                    data = base64.b64decode(data)
                image = PILImage.open(BytesIO(data))
                # FIX: keep transparency. Save as RGBA PNG directly.
                if image.mode in ("RGBA", "LA"):
                    image.save(str(output_path), "PNG")
                elif image.mode == "P":
                    image.convert("RGBA").save(str(output_path), "PNG")
                else:
                    image.convert("RGBA").save(str(output_path), "PNG")
                image_saved = True

        if image_saved:
            print(f"\nImage saved: {output_path.resolve()}")
        else:
            print("Error: No image generated.", file=sys.stderr)
            sys.exit(1)
    except Exception as e:
        print(f"Error generating image: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
