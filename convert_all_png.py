from PIL import Image
import os
import glob

depth_dir = r'E:\Xiuxian\taixuanzongmenlu\art\characters\disciples\弟子立绘\depth'

# 扫描所有.png文件，把实际是JPEG格式的转换为真正的PNG
all_png_files = glob.glob(os.path.join(depth_dir, '*.png'))
print(f'Found {len(all_png_files)} .png files total')

converted = 0
already_png = 0
failed = 0

for filepath in all_png_files:
    try:
        img = Image.open(filepath)
        if img.format == 'JPEG' or img.mode != 'RGBA':
            # 转换为RGBA模式的真正PNG
            if img.mode != 'RGBA':
                img = img.convert('RGBA')
            img.save(filepath, 'PNG')
            converted += 1
            if converted % 20 == 0:
                print(f'  Converted {converted} files...')
        else:
            already_png += 1
    except Exception as e:
        print(f'  FAILED: {os.path.basename(filepath)} - {e}')
        failed += 1

print(f'\nDone! Converted: {converted}, Already PNG: {already_png}, Failed: {failed}')

# 验证
test_files = [
    'depth_feng_男_stand.png',
    'depth_huo2_男_halfbody_elite.png',
    'depth_mo_女_battle.png'
]
for f in test_files:
    filepath = os.path.join(depth_dir, f)
    if os.path.exists(filepath):
        img = Image.open(filepath)
        print(f'Verify {f}: size={img.size}, mode={img.mode}, format={img.format}')
