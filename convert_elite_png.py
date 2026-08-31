from PIL import Image
import os
import glob

depth_dir = r'E:\Xiuxian\taixuanzongmenlu\art\characters\disciples\弟子立绘\depth'

# 找到所有精英版文件
elite_files = glob.glob(os.path.join(depth_dir, '*_elite.png'))
print(f'Found {len(elite_files)} elite files to convert')

converted = 0
failed = 0

for filepath in elite_files:
    try:
        img = Image.open(filepath)
        # 转换为RGBA模式（真正的PNG格式）
        if img.mode != 'RGBA':
            img = img.convert('RGBA')
        # 重新保存为真正的PNG格式
        img.save(filepath, 'PNG')
        converted += 1
        if converted % 10 == 0:
            print(f'  Converted {converted}/{len(elite_files)}...')
    except Exception as e:
        print(f'  FAILED: {os.path.basename(filepath)} - {e}')
        failed += 1

print(f'\nDone! Converted: {converted}, Failed: {failed}')

# 验证转换结果
test_file = os.path.join(depth_dir, 'depth_huo2_男_halfbody_elite.png')
if os.path.exists(test_file):
    img = Image.open(test_file)
    print(f'\nVerification: {os.path.basename(test_file)}')
    print(f'  size={img.size}, mode={img.mode}, format={img.format}')
