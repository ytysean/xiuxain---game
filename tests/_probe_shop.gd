extends Node
## 坊市页真实渲染探针（2026-09-15）—— 验证本轮改造，全部走**真实渲染 + 真实节点取证**。
## 用法：<godot> --path . res://tests/_probe_shop.tscn
##
## 验什么（对应老大四条反馈）：
##   ④a 商品图标放大：72 → 104（「坊市里的图标更放大跟框体一样大吗？」）
##   ④b 每日特供数据源换成仙缘阁商品库：真图标 / 仙玉图标替代"钻石 emoji" / 4 件 / 每日轮换
##   ④c 「仙玉刷新」按钮存在且可点
##   ④d faction_shop.csv 字段错配修复（灵石商品价格不再显示 0）
##   ⑤  「VIP」→「客卿」文案修真化（分类 Tab + 商品名/描述）
##
## 坐标坑（与 _probe_route 同源）：画布 1080×1920 / 窗口 720×1280 ⇒ 缩放 0.6667；
##   push_input 要传**窗口坐标**，故先做 get_final_transform() * 画布点。
## 窗口移出屏幕（-6000,-6000），不弹窗打扰。

const 探针账号 := "__probe_shop__"

## ★ 2026-09-15：文件日志设施。
## 为什么需要：探针跑真实渲染，所以**不能**用 --headless（dummy 渲染取不到 get_image）；
## 而真身 exe 是 GUI 子系统程序，stdout 不会进 bash 管道 ⇒ 日志拿不到。
## 旧做法是套 console 版转发壳，但真身 quit() 后壳容易不退（留 32K 幽灵条目）。
## 现改为探针自己写文件：直调真身 exe，零残留 + 日志完整。
const 日志路径 := "res://.scratch_backup/_probe_shop_r11.log"
var _日志: FileAccess = null

func _P(s: String) -> void:
	print(s)
	if _日志 == null:
		_日志 = FileAccess.open(日志路径, FileAccess.WRITE)
	if _日志 != null:
		_日志.store_line(s)
		_日志.flush()


var _main: Node = null
var _ui: Node = null
var _shop: Control = null


func _ready() -> void:
	if DisplayServer.get_name() != "headless":
		var w: Window = get_window()
		if w != null:
			w.position = Vector2i(-6000, -6000)
	_main = load("res://main.tscn").instantiate()
	add_child(_main)
	await _settle(6)
	if Game.has_method("删除账号"):
		Game.删除账号(探针账号)
	_main._登录_进入({"id": 探针账号})
	await _settle(24)
	_ui = _main.get("新UI")
	if _ui == null:
		_P(">>>FAIL 新UI 为空")
		get_tree().quit()
		return

	# ── ① 静态核对：分类名修真化 + 特供抽样 ──────────────────────
	_P("\n========== ① 分类名与特供抽样 ==========")
	_P("分类列表 = %s" % str(XianyuShop.分类列表))
	_P("  含「VIP」= %s    含「客卿」= %s  （期望 false / true）" % [
		str(XianyuShop.分类列表.has("VIP")), str(XianyuShop.分类列表.has("客卿"))])

	var 特供: Array = Game.取商城特供()
	_P("取商城特供() 返回 %d 件（期望 4）：" % 特供.size())
	for p in 特供:
		_P("    %-20s 价=%-5d 原价=%-5d icon=%s" % [
			str(p.get("name", "")), int(p.get("price", 0)), int(p.get("original_price", 0)),
			"有" if str(p.get("icon", "")) != "" else ">>>无"])
	var 二次: Array = Game.取商城特供()
	_P("  确定性（同日两次调用结果一致）= %s  （期望 true）" % str(str(二次) == str(特供)))

	# ── ② 静态核对：faction_shop 字段错配修复 ────────────────────
	_P("\n========== ② 坊市灵石商品字段错配修复 ==========")
	var 表: Array = Game._坊市表()
	_P("坊市表 %d 行；抽查前 5 行的 shop_id / price_lingjing：" % 表.size())
	var 空键: int = 0
	var 零价: int = 0
	for r in 表:
		if str(r.get("shop_id", "")) == "":
			空键 += 1
		if int(r.get("price_lingjing", 0)) <= 0:
			零价 += 1
	for i in range(mini(5, 表.size())):
		_P("    shop_id=%-20s price=%-6s name=%s" % [
			str(表[i].get("shop_id", "«空»")), str(表[i].get("price_lingjing", "«无»")),
			str(表[i].get("item_name", ""))])
	_P("  空 shop_id 行数 = %d / %d   （期望 0）" % [空键, 表.size()])
	_P("  price<=0 行数   = %d / %d   （期望 0）" % [零价, 表.size()])
	# ★ 2026-09-15（P0-C）：约定式图标寻址覆盖率 —— _坊市表() 按 item_id 推导 icon 全路径
	var 有图: int = 0
	for r in 表:
		if str(r.get("icon", "")) != "":
			有图 += 1
	_P("  带 icon 键行数 = %d / %d   （期望 20 / 20 —— art/icons/shop/ 已落 20 张）" % [有图, 表.size()])
	for i in range(mini(3, 表.size())):
		var ico: String = str(表[i].get("icon", ""))
		_P("      %-22s -> %s" % [str(表[i].get("item_id", "")), ico])
		# ★ 关键判据：新建目录 art/icons/shop/ 对 ResourceLoader 是否可达（.ctex 是否已生成）
		if ico != "":
			var 可达: bool = ResourceLoader.exists(ico)
			_P("         ResourceLoader.exists = %s ; load() = %s" % [
				可达, ("Texture2D 可取" if (可达 and (load(ico) is Texture2D)) else ">>>null / 不可载")])

	# ── ③ 打开坊市页 ────────────────────────────────────────────
	_P("\n========== ③ 打开坊市页（真实渲染）==========")
	_ui.call("_show_sub_page", "坊市", load("res://ui/page_shop.tscn"))
	await _settle(22)
	_shop = _ui.get("_current_sub")
	_P("坊市页 = %s" % str(_shop))
	if _shop == null:
		_P(">>>FAIL 坊市页未打开")
		get_tree().quit()
		return
	_P("_当前分类 = %s    _特供id = %s" % [
		str(_shop.get("_当前分类")), str(_shop.get("_特供id"))])
	_P("_特供id 条目数 = %d （期望 4，且下方列表应排除它们）" % (_shop.get("_特供id") as Dictionary).size())

	await _dump_特供卡()
	await _shot("_probe_shop_1_推荐.png")

	# ── ④ 切「收购」（灵石商品价格）────────────────────────────
	_P("\n========== ④ 切「收购」Tab（灵石商品）==========")
	_shop.call("_on_tab_pressed", "收购")
	await _settle(20)
	await _dump_坊市特惠卡()
	await _dump_商品卡()
	# ★ 上架集映射层的产物 —— 这才是 _make_product_card 真正吃到的字典
	#   注意：必须走 call() 动态调用 —— 该函数定义在 page_shop.gd，探针里直接写函数名
	#   会被闸门「类型名存在性扫描 / 未声明标识符扫描」判为裸中文方法未定义（本轮踩过）。
	var 在售: Array = []
	if _shop != null and _shop.has_method("_取灵石坊市在售"):
		在售 = _shop.call("_取灵石坊市在售")
	_P("---- 上架集映射层产物（验 icon 键是否被带上）----")
	_P("  _取灵石坊市在售() 返回 %d 件" % 在售.size())
	for i in range(mini(3, 在售.size())):
		var p: Dictionary = 在售[i]
		var ip: String = str(p.get("icon", ""))
		_P("    %-24s icon=%-50s exists=%s" % [
			str(p.get("id", "")), (ip if ip != "" else ">>>«无 icon 键»"),
			str(ResourceLoader.exists(ip)) if ip != "" else "—"])
	await _shot("_probe_shop_2_收购.png")

	# ── ⑤ 切「客卿」（VIP→客卿 文案）───────────────────────────
	_P("\n========== ⑤ 切「客卿」Tab（原 VIP）==========")
	_shop.call("_on_tab_pressed", "客卿")
	await _settle(20)
	await _dump_商品卡()
	await _shot("_probe_shop_3_客卿.png")

	_P("\n>>>PROBE_SHOP_DONE")
	if _日志 != null:
		_日志.flush()
		_日志.close()
		_日志 = null
	get_tree().quit()


func _dump_特供卡() -> void:
	_P("---- 特供卡结构（验：真图标 / 仙玉图标 / 刷新按钮 / 无 emoji 前缀）----")
	var 刷: Node = _shop.find_child("RefreshTehuiBtn", true, false)
	_P("  仙玉刷新按钮 = %s%s" % [
		"找到" if 刷 != null else ">>>缺失",
		("  text=「%s」" % (刷 as Button).text) if 刷 is Button else ""])
	var 卡们: Array = []
	_收集名含(_shop, "DailySpecial_", 卡们)
	_P("  特供卡 %d 张（期望 4）：" % 卡们.size())
	for c in 卡们:
		var cc: Control = c
		var 图: Node = cc.find_child("TehuiIcon", true, false)
		var 占位: Node = cc.find_child("TehuiIconPlaceholder", true, false)
		var 币: Node = cc.find_child("TehuiCoin", true, false)
		var 名: Node = cc.find_child("TehuiName", true, false)
		var 价: Node = cc.find_child("TehuiPrice", true, false)
		var 买: Node = cc.find_child("TehuiBuy_*", true, false)
		_P("    %s" % str(cc.name))
		_P("      名称「%s」 现价「%s」" % [
			(名 as Label).text if 名 is Label else "«缺»",
			(价 as Label).text if 价 is Label else "«缺»"])
		_P("      真图标=%s  首字占位=%s  仙玉图标=%s  购入钮=%s" % [
			"有" if 图 != null else ">>>无", "有" if 占位 != null else "无",
			"有" if 币 != null else ">>>无", "有" if 买 != null else ">>>无"])


func _dump_商品卡() -> void:
	_P("---- 商品卡（验：图标尺寸 104 / 价格非 0 / 无 VIP 字样）----")
	var 容器: Node = _shop.get("_scroll_vbox")
	var 卡们: Array = []
	_收集名含(容器 if 容器 != null else _shop, "Card_", 卡们)
	_P("  商品卡 %d 张" % 卡们.size())
	var n: int = 0
	for c in 卡们:
		if n >= 4:
			break
		var cc: Control = c
		var 图: Node = cc.find_child("Icon", true, false)
		var 名: Node = cc.find_child("CardName", true, false)
		var 价: Node = cc.find_child("CardPrice", true, false)
		var 名文: String = (名 as Label).text if 名 is Label else "«缺»"
		var 价文: String = (价 as Label).text if 价 is Label else "«缺»"
		var 贴图: String = "«缺»"
		if 图 is TextureRect:
			贴图 = "有" if (图 as TextureRect).texture != null else ">>>空"
		_P("    %-28s 名「%s」 价「%s」 图标min=%s 贴图=%s%s" % [
			str(cc.name), 名文, 价文,
			str((图 as Control).custom_minimum_size) if 图 is Control else "«缺»", 贴图,
			"  >>>含VIP!" if (名文.contains("VIP") or 价文.contains("VIP")) else ""])
		n += 1


## ★ 2026-09-15（P0-C）新增：坊市「每日特惠 · 限时折扣」卡的图标位断言。
## 该卡原先整行只有文字（名称 + 价格 + 抢购钮），同屏的「今日特供」卡却有图标 ⇒ 图文/纯文字混排。
## 本卡展示的正是 faction_shop 的同一批 shop_id 商品，故复用 art/icons/shop/ 那 20 张、零新增资产。
func _dump_坊市特惠卡() -> void:
	_P("---- 坊市「每日特惠 · 限时折扣」卡（验：图标位已接入）----")
	var 卡们: Array = []
	_收集名含(_shop, "Tehui_", 卡们)
	_P("  特惠卡 %d 张（窗内应有货；0 张 = 当日无特惠随机项）:" % 卡们.size())
	for c in 卡们:
		var cc: Control = c
		var 图: Node = cc.find_child("TehuiIcon_*", true, false)
		var 占位: Node = cc.find_child("TehuiIconPlaceholder_*", true, false)
		var 名: Node = cc.find_child("TehuiName", true, false)
		var 价: Node = cc.find_child("TehuiPrice", true, false)
		_P("    %-26s 名「%s」 价「%s」" % [
			str(cc.name), (名 as Label).text if 名 is Label else "«缺»",
			(价 as Label).text if 价 is Label else "«缺»"])
		_P("      商品图标=%s  首字占位=%s" % [
			"有" if 图 != null else ">>>无", "有" if 占位 != null else "无"])


func _收集名含(n: Node, 关键字: String, 出: Array) -> void:
	if str(n.name).contains(关键字):
		出.append(n)
	for c in n.get_children():
		_收集名含(c, 关键字, 出)


func _shot(名: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		_P(">>>FAIL 截图为空 %s" % 名)
		return
	var err: int = img.save_png("res://accept_shots_full/" + 名)
	_P(">>>SAVED %s err=%d" % [名, err])


func _settle(n: int) -> void:
	for i in range(n):
		await get_tree().process_frame
