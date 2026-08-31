# -*- coding: utf-8 -*-
"""
修改炼丹系统UI调用，使用封装函数
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\ui\page_building.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

old_code = '''func _on_炼丹_pressed(fid: String, 丹堂等级: int) -> void:
	var 背包: Array = Game.仓库
	var 结果 = AlchemySystem.炼丹(fid, 背包, 丹堂等级)
	Game.set("仓库", 背包)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "炼丹", str(结果.get("原因","")))
	_show_detail.call_deferred("dantang")'''

new_code = '''func _on_炼丹_pressed(fid: String, 丹堂等级: int) -> void:
	# 使用封装函数，自动更新仓库、统计和事件触发
	var 结果 = Game.执行炼丹(fid, 丹堂等级)
	if UIHint != null and UIHint.has_method("show_hint"):
		UIHint.show_hint(null, "炼丹", str(结果.get("原因","")))
	_show_detail.call_deferred("dantang")'''

if old_code in content:
    content = content.replace(old_code, new_code)
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    print("✅ 炼丹系统UI调用修改成功")
else:
    print("❌ 未找到炼丹系统UI调用代码")
    # 尝试查找部分匹配
    if "AlchemySystem.炼丹" in content:
        print("  找到 AlchemySystem.炼丹 调用")
    if "_on_炼丹_pressed" in content:
        print("  找到 _on_炼丹_pressed 函数")
