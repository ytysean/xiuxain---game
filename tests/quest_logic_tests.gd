# tests/quest_logic_tests.gd —— 奇遇引擎纯函数单测（GDScript headless；有引擎/CI 跑）
# 运行：godot --headless --script tests/quest_logic_tests.gd
# 断言与 tests/quest_logic_mirror.py 保持一致（TEST_FRAMEWORK §2.2 / §2.3）。
extends SceneTree

func _init():
	_测性格四维查表()
	_测稀有度仅在普通稀有()
	_测是否需干预()
	_测抽取契约键()
	print("quest_logic_tests: 全部断言通过")
	quit()

func _测性格四维查表():
	# 12 标准性格均应在表内且含四维、数值 0-100
	for 性格 in Disciple.性格表:
		var v: Dictionary = Quest.性格四维(性格)
		assert(v.has("激进度") and v.has("利他度") and v.has("聪慧度") and v.has("贪欲度"), "四维键缺失: " + 性格)
		assert(v["激进度"] >= 0 and v["激进度"] <= 100, "激进度越界: " + 性格)
		assert(v["利他度"] >= 0 and v["利他度"] <= 100, "利他度越界: " + 性格)
		assert(v["聪慧度"] >= 0 and v["聪慧度"] <= 100, "聪慧度越界: " + 性格)
		assert(v["贪欲度"] >= 0 and v["贪欲度"] <= 100, "贪欲度越界: " + 性格)
	# 抽样核对 [DESIGN_BASELINE] 基线值
	assert(Quest.性格四维("狂傲绝世")["激进度"] == 95, "狂傲绝世激进度应 95")
	assert(Quest.性格四维("仁心济世")["利他度"] == 90, "仁心济世利他度应 90")
	assert(Quest.性格四维("贪心逐缘")["贪欲度"] == 95, "贪心逐缘贪欲度应 95")
	assert(Quest.性格四维("恬淡悟道")["聪慧度"] == 75, "恬淡悟道聪慧度应 75")
	# 未知性格回退中性
	var 未知: Dictionary = Quest.性格四维("不存在的性格")
	assert(未知["激进度"] == 50 and 未知["贪欲度"] == 50, "未知性格应回退中性 50")

func _测稀有度仅在普通稀有():
	# 兜底期仅产出 普通/稀有（占位权重 _兜底稀有度权重 不含 优秀/稀有/传说）
	for i in 1000:
		var d := Disciple.new()
		var q: Dictionary = Quest.抽取(d)
		assert(q["稀有度"] in ["普通", "稀有"], "兜底稀有度越界: " + q["稀有度"])

func _测是否需干预():
	assert(Quest.是否需干预("普通") == false, "普通不干预")
	assert(Quest.是否需干预("稀有") == false, "稀有不干预")
	assert(Quest.是否需干预("优秀") == false, "优秀不干预")
	assert(Quest.是否需干预("传说") == true, "传说需干预")
	assert(Quest.是否需干预("传说") == true, "传说需干预")

func _测抽取契约键():
	var d := Disciple.new()
	var q: Dictionary = Quest.抽取(d)
	assert(q.has("文案") and q.has("稀有度") and q.has("需干预") and q.has("奖励"), "抽取缺契约键")
	assert(q["奖励"] == null, "兜底期奖励应 null")
	assert(q["需干预"] == false, "兜底期需干预应 false")
	assert(q["文案"] != "", "文案不应空")
	assert(Quest.干预选项.size() == 3, "干预选项应 3 档")
