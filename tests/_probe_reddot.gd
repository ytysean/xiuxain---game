extends Node
## 顶栏未读角标探针（纯逻辑校验，headless 可跑）。
## 用法：<godot> --headless --path . --scene res://tests/_probe_reddot.tscn
## 目的：确认 `top_bar._消息红点` 的 可见性 / 缩放 / 尺寸 / 落点 在「入场动画」前后是否收敛，
##       并把「未读数量」与红点状态并列打印，用于区分「本来就没有未读」与「渲染没出来」。

const 探针账号 := "__probe_reddot__"

var _tb: Node = null

func _ready() -> void:
	# 传入 -- 之后的第一个用户参数 = 账号 id；不传则用一次性探针账号（先删后建）。
	# 目的：既能测「全新账号无未读」，也能测「验收账号 acc_full 的真实未读数」。
	var 账号: String = 探针账号
	var 先删: bool = true
	var ua: PackedStringArray = OS.get_cmdline_user_args()
	if ua.size() > 0 and ua[0] != "":
		账号 = ua[0]
		先删 = false
	var main: Node = load("res://main.tscn").instantiate()
	add_child(main)
	await _settle(6)
	if 先删 and Game.has_method("删除账号"):
		Game.删除账号(账号)
	main._登录_进入({"id": 账号})
	await _settle(20)
	prints(">>> 账号 = %s（先删=%s）" % [账号, str(先删)])

	var ui: Node = main.get("新UI")
	if ui == null:
		prints(">>>FAIL 新UI 为空")
		get_tree().quit()
		return
	_tb = ui.get("_top_bar")
	if _tb == null:
		prints(">>>FAIL _top_bar 为空")
		get_tree().quit()
		return

	prints(">>> 未读数 = %d" % int(Game.消息系统.获取总未读数()))
	_dump("登录后 20 帧")
	await _save("res://_probe_reddot_home.png")
	Game.消息系统.发送宗门传令("探针传令甲", "探针正文")
	Game.消息系统.发送宗门传令("探针传令乙", "探针正文")
	_tb.call("refresh")
	_dump("推送 2 条后")
	await _settle(40)
	_dump("再等 40 帧（动画应已收敛）")
	prints(">>>PROBE_REDDOT_DONE")
	get_tree().quit()

func _dump(tag: String) -> void:
	var dot: Control = _tb.get("_消息红点")
	if dot == null:
		prints(">>> [%s] _消息红点 = null" % tag)
		return
	var num: Label = dot.get_node_or_null("Num") as Label
	prints(">>> [%s] visible=%s scale=%s pos=%s size=%s cms=%s txt=%s pivot=%s" % [
		tag, str(dot.visible), str(dot.scale), str(dot.position), str(dot.size),
		str(dot.custom_minimum_size), (num.text if num != null else "<无 Num>"),
		str(dot.pivot_offset)])

func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame

func _save(path: String) -> void:
	if DisplayServer.get_name() == "headless":
		prints(">>> 跳过截图（headless 无 frame_post_draw）")
		return
	await RenderingServer.frame_post_draw
	var vp: Viewport = get_viewport()
	var img: Image = vp.get_texture().get_image()
	if img == null:
		prints(">>>WARN 截图失败 %s" % path)
		return
	img.save_png(path)
	prints(">>> 截图 %s size=%s" % [path, str(img.get_size())])
