class_name MailSystem extends RefCounted

# ===== 邮件系统状态变量 =====
var 邮件列表: Array = []

# 取邮件列表
func 取邮件列表() -> Array:
	return 邮件列表

# 标记邮件已读
func 标记邮件已读(idx: int) -> void:
	if idx >= 0 and idx < 邮件列表.size():
		邮件列表[idx]["未读"] = false
		Game.邮件变动.emit()
		Game.save_game()

# 邮件全部已读
func 邮件全部已读() -> void:
	for m in 邮件列表:
		m["未读"] = false
	Game.邮件变动.emit()
	Game.save_game()

# 领取指定邮件附件：真发放资源并标记已领
func 领取邮件(idx: int) -> Dictionary:
	if idx < 0 or idx >= 邮件列表.size():
		return {"ok": false, "msg": "邮件不存在"}
	var m: Dictionary = 邮件列表[idx]
	if m.get("已领") if "已领" in m else false:
		return {"ok": false, "msg": "该邮件已领取"}
	var 附件: Dictionary = m.get("附件") if "附件" in m else {}
	if 附件.is_empty():
		return {"ok": false, "msg": "该邮件无附件"}
	var 明细: Array = []
	if 附件.has("灵石"):
		var v: int = int(附件["灵石"]); Game.灵石 += v; 明细.append("灵石+%d" % v)
	if 附件.has("灵气"):
		var v: int = int(附件["灵气"]); Game.灵气 += v; 明细.append("灵气+%d" % v)
	if 附件.has("灵草"):
		var v: int = int(附件["灵草"]); Game.灵草 += v; 明细.append("灵草+%d" % v)
	if 附件.has("矿石"):
		var v: int = int(附件["矿石"]); Game.矿石 += v; 明细.append("矿石+%d" % v)
	if 附件.has("声望"):
		var v: int = int(附件["声望"]); Game.声望 += v; 明细.append("声望+%d" % v)
	if 附件.has("绑定仙玉"):
		var v: int = int(附件["绑定仙玉"]); Game.仙玉_绑定 += v; 明细.append("绑定仙玉+%d" % v)
	if 附件.has("皮肤"):
		var skin_id: String = str(附件["皮肤"]); Game.当前皮肤 = skin_id; 明细.append("外观·%s" % skin_id)
	m["已领"] = true
	m["未读"] = false
	Game.邮件变动.emit()
	Game.save_game()
	return {"ok": true, "msg": "%s 附件：%s" % [str(m.get("标题") if "标题" in m else ""), "·".join(明细)], "明细": 明细}

# 种子化初始邮件
func _种子化初始邮() -> void:
	if not 邮件列表.is_empty():
		return
	邮件列表 = [
		{"发件人": "宗门长老", "标题": "宗门大比公告", "内容": Game.文案表["mail_sect_contest"], "时间": "08-09 09:24", "附件": {"灵石": 200}, "未读": true, "已领": false},
		{"发件人": "游方道人", "标题": "论道邀约", "内容": Game.文案表["mail_daoist_invite"], "时间": "08-08 21:10", "附件": {}, "未读": true, "已领": false},
		{"发件人": "丹器师公会", "标题": "材料淬炼返还", "内容": Game.文案表["mail_forge_return"], "时间": "08-08 18:02", "附件": {"灵草": 30}, "未读": false, "已领": false},
		{"发件人": "系统", "标题": "每日补给已发放", "内容": Game.文案表["mail_daily_supply"], "时间": "08-08 00:05", "附件": {"绑定仙玉": 20}, "未读": false, "已领": false},
	]

# 序列化
func to_dict() -> Dictionary:
	return {
		"邮件列表": 邮件列表,
	}

# 反序列化
func from_dict(data: Dictionary) -> void:
	邮件列表 = data.get("邮件列表", [])
