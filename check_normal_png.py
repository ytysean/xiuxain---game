from PIL import Image
import os

depth_dir = r'E:\Xiuxian\taixuanzongmenlu\art\characters\disciples\弟子立绘\depth'

# 检查新增10种类型的普通版文件格式
new_types = ['feng', 'shuang', 'lei', 'shan', 'he', 'xing', 'yue', 'yun', 'hai', 'mo']
jpeg_count = 0
png_count = 0

for t in new_types:
    for g in ['男', '女']:
        for p in ['stand', 'halfbody', 'battle']:
            filepath = os.path.join(depth_dir, f'depth_{t}_{g}_{p}.png')
            if os.path.exists(filepath):
                img = Image.open(filepath)
                if img.format == 'JPEG':
                    jpeg_count += 1
                    print(f'JPEG: {os.path.basename(filepath)} (mode={img.mode})')
                else:
                    png_count += 1

print(f'\nNew types normal files: JPEG={jpeg_count}, PNG={png_count}')
