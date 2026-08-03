import re

path = "E:/Xiuxian/taixuanzongmenlu/ui/top_bar.tscn"
with open(path, "r", encoding="utf-8") as f:
    text = f.read()

# Capsule height 40 -> 44 (offset_top=6, offset_bottom=50)
text = text.replace(
    "[node name=\"Capsule\" type=\"Panel\" parent=\".\"]\nlayout_mode = 0\noffset_left = 12.0\noffset_top = 8.0\noffset_right = 468.0\noffset_bottom = 48.0",
    "[node name=\"Capsule\" type=\"Panel\" parent=\".\"]\nlayout_mode = 0\noffset_left = 12.0\noffset_top = 6.0\noffset_right = 468.0\noffset_bottom = 50.0",
)

# Title vertically centered in 44px capsule
text = text.replace(
    "[node name=\"Title\" type=\"Label\" parent=\"Capsule\"]\nlayout_mode = 0\noffset_left = 16.0\noffset_top = 5.0\noffset_right = 160.0\noffset_bottom = 35.0",
    "[node name=\"Title\" type=\"Label\" parent=\"Capsule\"]\nlayout_mode = 0\noffset_left = 16.0\noffset_top = 7.0\noffset_right = 160.0\noffset_bottom = 37.0",
)

# Icons: 20x20 centered vertically (top=12, bottom=32)
text = re.sub(
    r"offset_left = (\d+\.0)\noffset_top = 10\.0\noffset_right = (\d+\.0)\noffset_bottom = 30\.0",
    r"offset_left = \1\noffset_top = 12.0\noffset_right = \2\noffset_bottom = 32.0",
    text,
)

# Names: 14px high, top=10, bottom=24
text = re.sub(
    r"(\[node name=\"Name_\w+\" type=\"Label\" parent=\"Capsule\"\]\nlayout_mode = 0\noffset_left = \d+\.0\n)offset_top = 9\.0\n(offset_right = \d+\.0\n)offset_bottom = 23\.0",
    r"\1offset_top = 10.0\n\2offset_bottom = 24.0",
    text,
)

# Values: 20px high (top=24, bottom=44), leaving 2px buffer for 18px font
text = re.sub(
    r"(\[node name=\"Value_\w+\" type=\"Label\" parent=\"Capsule\"\]\nlayout_mode = 0\noffset_left = \d+\.0\n)offset_top = 23\.0\n(offset_right = \d+\.0\n)offset_bottom = 41\.0",
    r"\1offset_top = 24.0\n\2offset_bottom = 44.0",
    text,
)

with open(path, "w", encoding="utf-8") as f:
    f.write(text)

print("patched")
