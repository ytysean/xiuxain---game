from PIL import Image
import os

elite_path = r'E:\Xiuxian\taixuanzongmenlu\art\characters\disciples\弟子立绘\depth\depth_huo2_男_halfbody_elite.png'
normal_path = r'E:\Xiuxian\taixuanzongmenlu\art\characters\disciples\弟子立绘\depth\depth_huo2_男_halfbody.png'

for name, path in [('ELITE', elite_path), ('NORMAL', normal_path)]:
    if os.path.exists(path):
        img = Image.open(path)
        print(f'{name}: size={img.size}, mode={img.mode}, format={img.format}')
        print(f'  info keys: {list(img.info.keys())}')
        print(f'  interlace: {img.info.get("interlace", "N/A")}')
    else:
        print(f'{name}: NOT FOUND')
