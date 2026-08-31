# -*- coding: utf-8 -*-
"""
静态校准：调整P0和P1的数值
P0（4项）：仙阶战力、道阶战力、天品灵根速度、道阶突破成功率
P1（3项）：高阶稳固期、仙阶寿元、道阶寿元
"""

import os

file_path = r"E:\Xiuxian\taixuanzongmenlu\disciple.gd"

# 读取文件
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

original_content = content

# ========== P0-1: 仙阶战力 35000 → 80000 ==========
old_xianjie_zhanli = '"仙阶": {"品阶": "xian_jie", "战力": 35000, "寿元": 5000}'
new_xianjie_zhanli = '"仙阶": {"品阶": "xian_jie", "战力": 80000, "寿元": 6000}'  # 同时调整P1-仙阶寿元
if old_xianjie_zhanli in content:
    content = content.replace(old_xianjie_zhanli, new_xianjie_zhanli)
    print("✅ P0-1: 仙阶战力 35000 → 80000")
    print("✅ P1-2: 仙阶寿元 5000 → 6000")
else:
    print("❌ P0-1: 未找到仙阶战力配置")

# ========== P0-2: 道阶战力 40000 → 200000 ==========
old_daojie_zhanli = '"道阶": {"品阶": "dao_jie", "战力": 40000, "寿元": 8000}'
new_daojie_zhanli = '"道阶": {"品阶": "dao_jie", "战力": 200000, "寿元": 12000}'  # 同时调整P1-道阶寿元
if old_daojie_zhanli in content:
    content = content.replace(old_daojie_zhanli, new_daojie_zhanli)
    print("✅ P0-2: 道阶战力 40000 → 200000")
    print("✅ P1-3: 道阶寿元 8000 → 12000")
else:
    print("❌ P0-2: 未找到道阶战力配置")

# ========== P0-3: 天品灵根速度 2.5 → 3.0 ==========
old_tianpin_speed = 'const 灵根品阶速度: Dictionary = {"凡品":1.0, "良品":1.3, "上品":1.8, "极品":2.5, "天品":2.5}'
new_tianpin_speed = 'const 灵根品阶速度: Dictionary = {"凡品":1.0, "良品":1.3, "上品":1.8, "极品":2.5, "天品":3.0}'
if old_tianpin_speed in content:
    content = content.replace(old_tianpin_speed, new_tianpin_speed)
    print("✅ P0-3: 天品灵根速度 2.5 → 3.0")
else:
    print("❌ P0-3: 未找到天品灵根速度配置")

# ========== P0-4: 仙阶→道阶突破成功率 0 → 0.05 ==========
old_tupo_rate = 'const 突破成功率: Dictionary = {"练气":1.00, "筑基":0.70, "金丹":0.50, "元婴":0.35, "化神":0.20, "仙阶":0.10, "道阶":0.00}'
new_tupo_rate = 'const 突破成功率: Dictionary = {"练气":1.00, "筑基":0.70, "金丹":0.50, "元婴":0.35, "化神":0.20, "仙阶":0.10, "道阶":0.05}'
if old_tupo_rate in content:
    content = content.replace(old_tupo_rate, new_tupo_rate)
    print("✅ P0-4: 仙阶→道阶突破成功率 0% → 5%")
else:
    print("❌ P0-4: 未找到突破成功率配置")

# ========== P1-1: 高阶稳固期 ==========
old_wengu = 'const 稳固期天数: Dictionary = {"筑基":365.0, "金丹":1095.0, "元婴":0.0, "化神":0.0, "仙阶":0.0, "道阶":0.0}'
new_wengu = 'const 稳固期天数: Dictionary = {"筑基":365.0, "金丹":1095.0, "元婴":730.0, "化神":1460.0, "仙阶":2920.0, "道阶":0.0}'
if old_wengu in content:
    content = content.replace(old_wengu, new_wengu)
    print("✅ P1-1: 高阶稳固期调整")
    print("   - 元婴: 0天 → 730天（2年）")
    print("   - 化神: 0天 → 1460天（4年）")
    print("   - 仙阶: 0天 → 2920天（8年）")
else:
    print("❌ P1-1: 未找到稳固期配置")

# 检查是否有修改
if content != original_content:
    # 保存文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("\n✅ 所有调整已保存到 disciple.gd")
else:
    print("\n❌ 没有任何修改，可能是配置格式不匹配")

# 验证修改
print("\n" + "=" * 60)
print("验证修改结果")
print("=" * 60)

with open(file_path, 'r', encoding='utf-8') as f:
    verify_content = f.read()

# 验证仙阶战力
if '"战力": 80000, "寿元": 6000' in verify_content:
    print("✅ 仙阶战力和寿元已更新")
else:
    print("❌ 仙阶战力和寿元未更新")

# 验证道阶战力
if '"战力": 200000, "寿元": 12000' in verify_content:
    print("✅ 道阶战力和寿元已更新")
else:
    print("❌ 道阶战力和寿元未更新")

# 验证天品灵根速度
if '"天品":3.0' in verify_content:
    print("✅ 天品灵根速度已更新")
else:
    print("❌ 天品灵根速度未更新")

# 验证突破成功率
if '"道阶":0.05' in verify_content:
    print("✅ 道阶突破成功率已更新")
else:
    print("❌ 道阶突破成功率未更新")

# 验证稳固期
if '"元婴":730.0, "化神":1460.0, "仙阶":2920.0' in verify_content:
    print("✅ 高阶稳固期已更新")
else:
    print("❌ 高阶稳固期未更新")

print("\n🎉 P0（4项）和P1（3项）调整完成！")
