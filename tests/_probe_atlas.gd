extends Node
## 宗门舆图（page_atlas）意图 chip 空口诊断探针（headless）。
## 用法：<godot> --headless --path . --scene res://tests/_probe_atlas.tscn
##
## 背景：真实渲染截图显示「我想……」下方 6 个 chip 只有金边圆角框、无文字无图标。
## 本探针直接读运行时节点，判定到底是「text 为空」还是「有 text 但被裁/被同色淹没」。

const 探针账号 := "__probe_atlas__"

var _main: Node = null
var _ui: Node = null


func _ready() -> void:
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	_main._登录_进入({"id": 探针账号})
	await _settle(24)

	_ui = _main.get("新UI")
	if _ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return

	var 常量表: Dictionary = _ui.get_script().get_script_constant_map()
	var 页面表: Dictionary = 常量表.get("ENTRY_SUB_PAGES", {})
	var 命中: String = ""
	for id in 页面表.keys():
		if String(id) == "宗门舆图":
			命中 = String(id)
			break
	if 命中 == "":
		prints(">>>FAIL ENTRY_SUB_PAGES 里没有『宗门舆图』")
		get_tree().quit()
		return

	_ui.call("_show_sub_page", 命中, 页面表[命中])
	await _settle(12)

	var sub: Control = _ui.get("_current_sub")
	if sub == null:
		prints(">>>FAIL _current_sub 为空（页面没打开）")
		get_tree().quit()
		return
	prints("===== 页面已打开：%s =====" % str(sub.name))

	# ① 直接验证表读取
	prints("\n---- 表读取自检 ----")
	var 页: Object = _找脚本宿主(sub)
	if 页 != null and 页.has_method("_读意图表"):
		var 意图: Array = 页.call("_读意图表")
		prints("  _读意图表() 行数=%d" % 意图.size())
		for i in range(意图.size()):
			var r: Dictionary = 意图[i]
			var 目标: Array = r.get("目标", [])
			prints("    [%d] 意图='%s' 目标=%d 项 图标='%s'" % [
				i, String(r.get("意图", "")), 目标.size(), String(r.get("图标", ""))])
	else:
		prints("  ** 找不到 _读意图表（脚本宿主未定位到）")

	# ② 遍历页面树，把所有 Button 的真身打出来
	prints("\n---- 页面内 Button 真身（前 40 个）----")
	var 计数: Dictionary = {"n": 0}
	_扫(sub, 计数)
	prints("\n  按钮总数=%d" % int(计数["n"]))

	get_tree().quit()


func _找脚本宿主(n: Node) -> Object:
	if n.get_script() != null and n.has_method("_读意图表"):
		return n
	for c in n.get_children():
		var r: Object = _找脚本宿主(c)
		if r != null:
			return r
	return null


func _扫(n: Node, 计数: Dictionary) -> void:
	if n is Button:
		var b: Button = n
		计数["n"] = int(计数["n"]) + 1
		if int(计数["n"]) <= 40:
			var 色: Variant = b.get_theme_color("font_color")
			var 字号: Variant = b.get_theme_font_size("font_size")
			var 字体: Variant = b.get_theme_font("font")
			prints("    %-22s text='%s' icon=%s size=%s pos=%s vis=%s flat=%s clip=%s" % [
				str(b.name), b.text, str(b.icon != null),
				str(b.size.round()), str(b.position.round()), str(b.visible),
				str(b.flat), str(b.clip_text)])
			prints("      font_color=%s font_size=%s font=%s min=%s" % [
				str(色), str(字号), str(字体), str(b.get_combined_minimum_size().round())])
			prints("      text_size=%s" % str(b.get_minimum_size().round()))
	for c in n.get_children():
		_扫(c, 计数)


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
