# -*- coding: utf-8 -*-
# pre_f5_check.py —— 《太玄宗门录》F5 前必跑检查（一键编排 · 二十四道闸门）
#
# 把验证闸门串起来，输出一份统一总判定，让你 F5 之前一眼看清能不能放心开：
#   1) GDScript 4.x 类型推断扫描  (gdscript_type_check.py)
#   2) 配置表全量校验             (validate_all.py)
#   3) 战斗数值红线断言           (tests/combat/test_combat.py)
#   4) 命格数值断言               (tests/destiny/destiny_math.py)
#   5) 灵兽数值红线断言           (tests/beast/test_beast.py：双槽战力/双层适配加成/本体战力镜像)
#   6) 弟子终局机制断言           (tests/disciple/test_disciple.py：资质天花板/坐化触发/资产回收镜像)
#   7) 废弃字段引用扫描           (内联：grep 已改名/已删除字段的 `.属性` 点访问)
#   6) GDScript 缩进结构扫描      (indent_scan.py：开块后紧跟同级/降级行的结构性缩进错误)
#   7) 裸全角字符/跨行未闭字符串扫描 (内联：拦 Godot 真机才报、类型/缩进闸都漏的语法类错误)
#   8) GDScript 静态扫描          (static_check.py：孤立缩进/class body 裸语句/跨作用域引用
#                                  三类「只有 Godot 真机才报」的崩溃，纯文本零误报兜底)
#   9) GDScript 真实语法解析       (gdtoolkit_check.py：用 gdtoolkit 真 parser 拦缩进错位/
#                                  lambda 提前结束/match case 错位等只有 Godot 才报的语法灾难)
#   17) 底部导航 Tab 数校验         (内联：页名 数组 == ["宗门","弟子","殿阁","历练","纪事"] 且长度 5)
#   18) 按钮色值/裸 hex 校验        (内联：全文件裸 #xxxxxx 比对顶部常量+四类锁定 hex，未定义即 FAIL)
#   19) 背景透明度校验             (内联：BG_SCENE_ALPHA≤0.35 / BG_OVERLAY_ALPHA==0.50 / #16221D)
#   20) 阵法拆解经济校验           (内联：复刻 `_阵法拆解返还数`，拆解产出≤投入 且 L1=0，防零投入白嫖漏洞)
#   21) Python 工具脚本编译检查     (内联：py_compile 全量编译所有 *.py，任一 SyntaxError 直接 FAIL)
#   22) GDScript 存档键名对称检查   (内联：抓 `目标 = data.get("_键")` 目标缺前导下划线的反模式)
#   23) 事件赏赐 item 引用校验      (内联：event_quest opt1/2/3_reward 的 item:item_id:count，断言 item_id ∈ array_items.csv|item_id_registry.csv 且 count>0)
#   24) 零战斗触碰红线校验
#   25) CSV 消费链路校验           (subprocess：check_csv_consumer.py；CSV-GOV-GATE-002，当前非阻断·报告模式)
#                                  摆设型 CSV 自动校验：逐 config/*.csv 检索业务代码字面引用，
#                                  输出 OK/RESERVED/BAK/ORPHAN 报告；当前非阻断，永远 [PASS]，不改退出码。         (内联：git diff HEAD 比对 BattleCalculator.gd / BattleManager.gd 无改动)
#
# 用法（在项目根目录执行）：
#   python pre_f5_check.py
# 退出码：全部通过 -> 0；任一失败 -> 1（可直接挂 pre-commit / CI）。
#
# 说明：本脚本用 sys.executable 启动子进程，保证与运行它的解释器一致；
#       各子工具自带路径解析逻辑，cwd 统一设为项目根目录即可。
import os
import re
import sys
import subprocess
import py_compile
import tempfile

ROOT = os.path.dirname(os.path.abspath(__file__))

# (展示名, 相对根目录的脚本路径, cwd)
CHECKS = [
    ("GDScript 类型推断扫描", "gdscript_type_check.py", ROOT),
    ("配置表全量校验",       "validate_all.py",        ROOT),
    ("战斗数值红线断言",     "tests/combat/test_combat.py",  ROOT),
    ("命格数值断言",         "tests/destiny/destiny_math.py", ROOT),
    ("灵兽数值红线断言",     "tests/beast/test_beast.py", ROOT),
    ("弟子终局机制断言",     "tests/disciple/test_disciple.py", ROOT),
    ("彩蛋数值红线断言",     "tests/easter_egg/test_easter_egg.py", ROOT),
    ("资源产耗闭环断言",     "tests/resource_flow/test_resource_flow.py", ROOT),
    ("增益数值红线断言",     "tests/buff_redline/test_buff_redline.py", ROOT),
    ("七载赏赐零通胀校验",   "check_rating_inflation.py", ROOT),
    ("产耗±15%红线校验",     "check_resource_redline.py", ROOT),   # ECON-01 新增：零通胀基线锁（第11道 subprocess 闸）
]

# 第九道闸门依赖 gdtoolkit（真实 GDScript parser），它装在 managed Python venv 里，
# 不在 sys.executable（运行本脚本的解释器）里。故第九道单独用这个 venv 的 python 启动。
# 若此 venv 不存在（如换机/未装 gdtoolkit），第九道自动 SKIP 不阻断。
GD_VENV_PY = os.path.join(
    os.path.expanduser("~"),
    ".workbuddy", "binaries", "python", "envs", "default", "Scripts", "python.exe",
)

# 废弃字段引用护栏：命格重构(2026-07-19)把字段 `命格:String` 改名为 `destiny_id`，
# 漏改的 `d.命格` 属性访问会在 F5 运行期崩（Invalid access to property '命格'）。
# 在此列所有「已改名/已删除」的字段名；脚本扫全部 .gd 里 `.字段名` 形式的属性点访问，命中即 FAIL。
# 注意：`.get("字段名")` 字典读旧档写法是安全的（from_dict 兼容），正则只匹配「.字段名」点访问，
#       不匹配 `.get("...")`，也不匹配注释/显示串里的字面 `命格`（无前导点）。
# 以后再做字段改名，直接往这里加一行即可。
DEPRECATED_FIELD_ACCESS = [
    ("命格", "destiny_id", "命格重构：字段改名 destiny_id（2026-07-19）"),
]

PASS_MARK = "\033[92m[PASS]\033[0m"
FAIL_MARK = "\033[91m[FAIL]\033[0m"
LINE_W = 60  # 名称与判定之间的填充宽度


def run_check(name, rel_path, cwd):
    """返回 (ok: bool, summary: str)"""
    script = os.path.join(ROOT, rel_path)
    if not os.path.exists(script):
        return False, "脚本缺失: %s" % rel_path, ""
    try:
        proc = subprocess.run(
            [sys.executable, script],
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
    except Exception as e:  # pragma: no cover
        return False, "启动失败: %s" % e

    out = (proc.stdout or "") + (proc.stderr or "")
    ok = (proc.returncode == 0)

    # 从输出里提炼一行摘要
    summary = ""
    for line in out.splitlines():
        s = line.strip()
        if not s:
            continue
        # 各工具的关键摘要行
        if "ALL CLEAN" in s or "校验完成" in s or ("通过" in s and "失败" in s) \
           or "ALL ASSERTIONS PASSED" in s or "可疑结构" in s:
            summary = s
            break
    if not summary:
        # 退化：取最后一行非空输出
        nonempty = [l.strip() for l in out.splitlines() if l.strip()]
        summary = nonempty[-1] if nonempty else ("returncode=%d" % proc.returncode)
    return ok, summary, out


def check_deprecated_fields():
    """内联扫描：禁止对已废弃字段做属性点访问（如 `.命格`）。
    返回 (ok: bool, summary: str, detail: str) —— detail 为命中行的可读明细。"""
    hits = []  # (rel_path, lineno, line_text, old, new)
    for root, dirs, files in os.walk(ROOT):
        # 跳过隐藏/缓存目录（.godot、.workbuddy 等），避免扫到缓存副本误报
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        for fn in files:
            if not fn.endswith(".gd"):
                continue
            fp = os.path.join(root, fn)
            rel = os.path.relpath(fp, ROOT)
            try:
                with open(fp, "r", encoding="utf-8") as f:
                    lines = f.readlines()
            except Exception:
                continue
            for idx, raw in enumerate(lines, 1):
                for old, new, _note in DEPRECATED_FIELD_ACCESS:
                    # 匹配 `.命格` 或 `. 命格`（点后可选空白）；`.get("命格")` 不在点后紧跟命格，不会命中
                    if re.search(r"\.\s*" + re.escape(old) + r"\b", raw):
                        hits.append((rel, idx, raw.rstrip("\n"), old, new))
    if not hits:
        return True, "未检出废弃字段属性访问", ""
    detail = "\n".join(
        "%s:%d  .%s -> 应改为 .%s  | %s" % (rel, ln, old, new, text.strip())
        for rel, ln, text, old, new in hits
    )
    return False, "检出 %d 处废弃字段属性访问" % len(hits), detail


def check_fullwidth_strings():
    """内联扫描：拦『裸代码区的全角/非法字符』与『跨行未闭合字符串』。
    这类问题只有 Godot 真机才报——gdscript_type_check 只查 :=、indent_scan 只查缩进，
    都会漏（2026-07-20 game_state.gd L306 一处跨行未闭字符串，Godot 真机报 307~742 一长串
    Invalid character 级联，六道闸门全绿却没拦住）。本道在 F5 前即可发现。
    返回 (ok, summary, detail)。"""
    # 代码裸区绝不该出现的中文/全角标点（普通汉字不在内，合法中文变量名如 弟子 不报）
    illegal = set('（）：，！。·【】×｜═「」《》？；、‘’…—')
    hits = []  # (rel, ln, flag, ctx)
    for root, dirs, files in os.walk(ROOT):
        dirs[:] = [d for d in dirs if not d.startswith('.')]
        for fn in files:
            if not fn.endswith('.gd'):
                continue
            fp = os.path.join(root, fn)
            rel = os.path.relpath(fp, ROOT)
            try:
                with open(fp, 'r', encoding='utf-8') as f:
                    lines = f.readlines()
            except Exception:
                continue
            in_str = False
            for ln, raw in enumerate(lines, 1):
                line = raw.rstrip('\n')
                in_comment = False
                i = 0
                while i < len(line):
                    c = line[i]
                    if in_comment:
                        i += 1
                        continue
                    if c == '#' and not in_str:
                        in_comment = True
                        i += 1
                        continue
                    if c == '"':
                        if in_str and i + 1 < len(line) and line[i + 1] == '"':
                            i += 2
                            continue
                        in_str = not in_str
                        i += 1
                        continue
                    if not in_str and (c in illegal or c == '?'):
                        # GDScript 4.x 不支持 C 风格三元 (a) ? b : c，字符串外的 ASCII '?' 一律非法；
                        # 字符串/注释内的 '?' 已被 in_str / in_comment 跳过，不会误报。
                        flag = ('裸全角 ' + c) if c in illegal else '非法字符 ?（GDScript 不支持三元 ? :）'
                        hits.append((rel, ln, flag, line.strip()[:70]))
                    i += 1
                if in_str:
                    hits.append((rel, ln, '跨行未闭字符串', line.strip()[:60]))
                    in_str = False  # 标记为 bug 后重置，避免后续行持续误累积
    if not hits:
        return True, "未检出裸全角字符/未闭字符串", ""
    detail = "\n".join(
        ("%s:%d  裸全角 %s | %s" % (rel, ln, ch, ctx)
         if ch.startswith('裸全角') else
         "%s:%d  %s" % (rel, ln, ctx))
        for rel, ln, ch, ctx in hits
    )
    return False, "检出 %d 处裸全角/未闭字符串" % len(hits), detail


# ── UI 整改「三」新增校验（闸门 17/18/19）────────────────────────────────
# 17) 底部主导航 Tab 数恒为 5（宗门/弟子/殿阁/历练/纪事）
# 18) 按钮色值 / 裸 hex：全文件裸 #xxxxxx 比对顶部常量 + 四类锁定 hex，未定义即 FAIL
# 19) 背景透明度：BG_SCENE_ALPHA ≤ 0.35、BG_OVERLAY_ALPHA == 0.50、BG_OVERLAY_COLOR == #16221D
NEW_UI_GATES = ("底部导航 Tab 数校验", "按钮色值/裸 hex 校验", "背景透明度校验",
                "状态色 token 漂移校验", "品阶色单一数据源校验")


# ── P1-A 方案 C：状态色 token 漂移校验 ────────────────────────────────
# 背景：P1-A 评审裁定「运行时不强求单一来源，改用 CI 等值断言锁死双写」。
#   ui_theme.gd 的 COLOR_STATUS_SUCCESS / COLOR_TEXT_RED 与 ui_theme_config.gd 的
#   STATE_COLOR.success / danger 是同一设计 token 的两处表达（前者 float Color 字面，
#   后者 hex 字符串）。保留双写可零风险规避 Autoload 初始化顺序问题
#   （project.godot 中 UITheme 先于 UIThemeConfig 实例化，@onready 跨单例取值会崩），
#   但必须由本闸门保证两者永不悄悄漂移。
# 范围红线：本闸门【仅】覆盖上述 2 组 status 常量。
#   main.gd 的品阶色（原第三硬编码源）已于 P1 收口至 UIThemeConfig，
#   由独立的 check_rarity_color_single_source() 闸门看守，不混入本闸门。
COLOR_DRIFT_PAIRS = (
    # (ui_theme.gd 常量名, ui_theme_config.gd STATE_COLOR 键, 语义)
    ("COLOR_STATUS_SUCCESS", "success", "成功/增益"),
    ("COLOR_TEXT_RED", "danger", "警示/异常"),
)


def check_color_token_drift():
    """闸门：ui_theme.gd status 色常量 与 ui_theme_config.gd STATE_COLOR 等值断言。
    解析两侧色值统一换算为 #RRGGBB 后逐对比对，任一不等即 FAIL；
    任一侧常量/键缺失（误删、改名）同样 FAIL。
    仅覆盖 COLOR_DRIFT_PAIRS 声明的 2 组（见上方范围红线）。

    精度语义（刻意设计，非缺陷）：
      比对基准是 8bit #RRGGBB，而非原始 float。因为 UIThemeConfig 侧只存 hex
      （精度上限即 8bit），hex `#E0` 反解为 float 是 0.87843…，与 ui_theme.gd 侧
      的字面 0.878 永不精确相等 —— 若改用 float 等值比对，每一对都会假阳性。
      故 hex 是两侧唯一共同精度基准。
      推论：小于 1/255 的 float 漂移（如 0.878→0.879，两者均量化为 0xE0）
      不会被本闸门拦截 —— 但该量级漂移渲染结果逐像素相同，无视觉影响，
      属可接受盲区。任何达到 1/255 及以上的真实漂移均会被捕获。

    返回 (ok, summary, detail)。"""
    theme_fp = os.path.join(ROOT, "ui_theme.gd")
    config_fp = os.path.join(ROOT, "ui_theme_config.gd")
    for fp in (theme_fp, config_fp):
        if not os.path.exists(fp):
            return False, "%s 缺失" % os.path.basename(fp), ""
    try:
        theme_src = open(theme_fp, "r", encoding="utf-8").read()
        config_src = open(config_fp, "r", encoding="utf-8").read()
    except Exception as e:
        return False, "读取失败: %s" % e, ""

    def to_hex(r, g, b):
        return "#%02X%02X%02X" % (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))

    # 左侧：ui_theme.gd 的 const NAME: Color = Color(r, g, b[, a])
    theme_colors = {}
    for m in re.finditer(
            r"const\s+(COLOR_\w+)\s*:\s*Color\s*=\s*Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*(?:,\s*[\d.]+\s*)?\)",
            theme_src):
        theme_colors[m.group(1)] = to_hex(float(m.group(2)), float(m.group(3)), float(m.group(4)))

    # 右侧：ui_theme_config.gd 的 STATE_COLOR 字典 "key": Color.from_string("#RRGGBB", ...)
    state_block = re.search(r"STATE_COLOR\s*:\s*Dictionary\s*=\s*\{(.*?)\}", config_src, re.DOTALL)
    if not state_block:
        return False, "ui_theme_config.gd 未找到 STATE_COLOR 字典", ""
    state_colors = {}
    for m in re.finditer(r'"(\w+)"\s*:\s*Color\.from_string\(\s*"(#[0-9A-Fa-f]{6})"',
                         state_block.group(1)):
        state_colors[m.group(1)] = m.group(2).upper()

    drift, missing = [], []
    for const_name, state_key, semantic in COLOR_DRIFT_PAIRS:
        left = theme_colors.get(const_name)
        right = state_colors.get(state_key)
        if left is None:
            missing.append("ui_theme.gd 未找到常量 %s（%s）" % (const_name, semantic))
            continue
        if right is None:
            missing.append("ui_theme_config.gd STATE_COLOR 缺键 '%s'（%s）" % (state_key, semantic))
            continue
        if left != right:
            drift.append("%s[%s] = %s  ≠  STATE_COLOR['%s'] = %s"
                         % (const_name, semantic, left, state_key, right))

    if missing or drift:
        detail = "\n".join(missing + drift)
        n = len(missing) + len(drift)
        return False, "状态色 token 漂移/缺失 %d 处" % n, detail
    pairs = " / ".join("%s=%s" % (k, theme_colors[c]) for c, k, _ in COLOR_DRIFT_PAIRS)
    return True, "status 色 token 双写一致（%d 组：%s）" % (len(COLOR_DRIFT_PAIRS), pairs), ""


def check_rarity_color_single_source():
    """闸门：品阶色单一数据源校验（P1 收口 · P0 决议补全）。
    历史问题：main.gd 曾以 `const 品阶色` 自持第三份品阶色表，7 档全部与
    UIThemeConfig.QUALITY_COLOR 冲突（灵=绿/王=紫/圣=橙/道=暗红），导致
    P0「灵品改青蓝 #3FA9C9」的决议在真机上从未生效。
    本闸门断言两件事：
      1) main.gd 不得再出现 `const 品阶色` 硬编码字典定义（负向：防回归）；
      2) main.gd 的 get_rarity_color() 必须委托 UIThemeConfig（正向：防「改名后
         重新硬编码」绕过 —— 只查缺失会让换个变量名重新写死的情形漏网）。
    返回 (ok, summary, detail)。"""
    fp = os.path.join(ROOT, "main.gd")
    if not os.path.exists(fp):
        return True, "main.gd 不存在，跳过", ""
    try:
        src = open(fp, "r", encoding="utf-8").read()
    except Exception as e:
        return False, "读取失败: %s" % e, ""

    problems = []
    # 1) 负向：不得残留硬编码品阶色字典
    if re.search(r"const\s+品阶色", src):
        problems.append("main.gd 仍定义硬编码 `const 品阶色` 字典，违反单一数据源"
                        "（应委托 UIThemeConfig.get_quality_color）")

    # 2) 正向：get_rarity_color 必须存在且委托 UIThemeConfig
    #    注意：必须先剥注释再判断 —— 本函数的说明注释里就含 "UIThemeConfig" 字样，
    #    若带注释匹配，则「函数体改回硬编码但注释没删」的回归会漏网（已由负向测试证实）。
    m = re.search(r"func\s+get_rarity_color\s*\([^)]*\)[^:]*:(.*?)(?=\n(?:func|const|var|@)|\Z)",
                  src, re.DOTALL)
    if not m:
        problems.append("main.gd 未找到 get_rarity_color()（全局品阶染色入口缺失）")
    else:
        body_code = "\n".join(re.sub(r"#.*$", "", ln) for ln in m.group(1).splitlines())
        if "UIThemeConfig" not in body_code:
            problems.append("get_rarity_color() 未委托 UIThemeConfig，品阶色可能被重新硬编码")

    if problems:
        return False, "品阶色单一数据源校验未通过（%d 项）" % len(problems), "\n".join(problems)
    return True, "品阶色已收口至 UIThemeConfig（main.gd 无硬编码字典，入口已委托）", ""


def check_progress_bar_single_source():
    """闸门：ProgressBar 进度条样式单源化校验（D2 收口）。

    断言 ui/*.gd 中【非白名单】文件不再出现 in-code 重建 ProgressBar fill/background
    的 StyleBoxFlat 覆盖（即 add_theme_stylebox_override("fill"/"background", ...)）。
    进度条 fill/bg 必须统一继承 main_theme.tres 的 ProgressBar/styles/* 默认，
    禁止在页面里手写重建（避免与 .tres 漂移、规避 G8 颜色指纹改动）。

    白名单 page_disciple.gd：修炼/瓶颈/丹毒/道心等进度条 fill 为动态状态色
    （gold/success/red/aux，均取自 UITheme.color_* getter，无裸 Color() 字面量），
    属合法语义例外，允许保留 in-code 机制。

    返回 (ok, summary, detail)。"""
    ui_dir = os.path.join(ROOT, "ui")
    if not os.path.isdir(ui_dir):
        return False, "ui/ 目录缺失", ""
    whitelist = {"page_disciple.gd"}
    violations = []
    for fn in sorted(os.listdir(ui_dir)):
        if not fn.endswith(".gd"):
            continue
        if fn in whitelist:
            continue
        fp = os.path.join(ui_dir, fn)
        try:
            src = open(fp, "r", encoding="utf-8").read()
        except Exception as e:
            violations.append("%s 读取失败: %s" % (fn, e))
            continue
        for m in re.finditer(r'add_theme_stylebox_override\(\s*"(fill|background)"', src):
            line_no = src[:m.start()].count("\n") + 1
            violations.append("%s:%d 仍存在 in-code ProgressBar 样式覆盖（应继承 .tres 默认）"
                              % (fn, line_no))
    if violations:
        detail = "\n".join(violations)
        return False, "ProgressBar 单源化违规 %d 处（非白名单文件不得手写 fill/background 覆盖）" % len(violations), detail
    return True, "ProgressBar 进度条全部继承 .tres 默认样式（白名单 page_disciple.gd 动态色除外）", ""


def check_tab_count():
    """闸门17：底部主导航 Tab 数量恒为 5（宗门/弟子/殿阁/历练/纪事）。
    扫描 main.gd 的 `页名` 常量数组，须精确等于该 5 项，否则 FAIL。
    返回 (ok, summary, detail)。"""
    fp = os.path.join(ROOT, "main.gd")
    if not os.path.exists(fp):
        return False, "main.gd 缺失", ""
    try:
        src = open(fp, "r", encoding="utf-8").read()
    except Exception as e:
        return False, "读取失败: %s" % e, ""
    m = re.search(r"页名\s*:?=\s*\[(.*?)\]", src, re.DOTALL)
    if not m:
        return False, "未找到 页名 常量定义", ""
    items = re.findall(r'"([^"]*)"', m.group(1))
    expected = ["宗门", "弟子", "殿阁", "历练", "纪事"]
    if items == expected and len(items) == 5:
        return True, "页名 = 5 Tab（宗门/弟子/殿阁/历练/纪事）", ""
    detail = "页名 = %s（应为 %s）" % (items, expected)
    return False, "页名 Tab 数/项不匹配（实为 %d 项）" % len(items), detail


def check_button_hex():
    """闸门18：扫描 main.gd 中「规范色表外裸 hex」。
    FAIL 触发条件（用户指定）：存在未定义为顶部常量、且不属于四类按钮锁定 hex 的裸 `#xxxxxx` 字面。
    另对 `Color(r,g,b[,a])` 裸色字面做非阻断扫描：列出现行非常量裸 Color 供复查（不阻断）。
    返回 (ok, summary, detail)。"""
    fp = os.path.join(ROOT, "main.gd")
    if not os.path.exists(fp):
        return False, "main.gd 缺失", ""
    try:
        lines = open(fp, "r", encoding="utf-8").readlines()
    except Exception as e:
        return False, "读取失败: %s" % e, ""

    # 1) 收集「已定义」颜色 hex：顶部 const 直接定义 + 字典条目（如 品阶色）中的 Color 字面
    defined_hex = set()
    color_re = re.compile(
        r"Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+)\s*)?\)")
    for raw in lines:
        is_const = ("const " in raw) or raw.strip().startswith("const")
        is_dict_entry = bool(re.search(r'["\w\u4e00-\u9fff]+"\s*:\s*Color\(', raw))
        if not (is_const or is_dict_entry):
            continue
        for cm in color_re.finditer(raw):
            r, g, b = float(cm.group(1)), float(cm.group(2)), float(cm.group(3))
            a = cm.group(4)
            hx = "%02X%02X%02X" % (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))
            defined_hex.add(hx.lower())
            if a is not None:
                av = int(round(float(a) * 255))
                defined_hex.add(("%08X" % ((int(hx, 16) << 8) | av)).lower())

    # 2) 四类按钮锁死 hex（终裁 · 写实规范 §7.1.1 / 绘图强制规范 §3.2）
    locked = {
        "2c5f52", "b89b5a", "f0e6d2",          # 主按钮
        "4a3b2a", "3e6b5e", "e8dcc8",          # 次按钮
        "3a6f6080", "5a8b7d", "d4e5de",        # 标签/筛选
        "5c3333", "8b5a5a", "e8c8c8",          # 危险按钮
    }
    allowed = defined_hex | locked

    hex_hits = []       # 未定义裸 hex（FAIL）
    color_hits = []     # 非阻断：裸 Color(...) 非常量（供复查）
    for idx, raw in enumerate(lines, 1):
        # 裸 #xxxxxx / #xxxxxxxx
        for hx in re.findall(r"#([0-9A-Fa-f]{6,8})", raw):
            if hx.lower() not in allowed:
                hex_hits.append((idx, "#" + hx))
        # 裸 Color(r,g,b[,a])：仅四通道全为数字字面才算真裸色（引用常量/变量者跳过）
        for cm in color_re.finditer(raw):
            r, g, b = float(cm.group(1)), float(cm.group(2)), float(cm.group(3))
            a = cm.group(4)
            comps = [r, g, b] + ([float(a)] if a else [])
            if all(c in (0.0, 1.0) for c in comps):   # 跳过白/黑/透明等运行期调制色
                continue
            hx = "%02X%02X%02X" % (int(round(r * 255)), int(round(g * 255)), int(round(b * 255)))
            if hx.lower() in defined_hex:
                continue
            if a is not None and ("%08X" % ((int(hx, 16) << 8) | int(round(float(a) * 255)))).lower() in defined_hex:
                continue
            color_hits.append((idx, "Color(%s,%s,%s%s)" % (
                cm.group(1), cm.group(2), cm.group(3), ("," + a) if a else "")))

    if hex_hits:
        detail = "\n".join("%s:%d 未定义裸 hex %s" % (os.path.relpath(fp, ROOT), ln, h)
                           for ln, h in hex_hits)
        return False, "检出 %d 处规范色表外裸 hex" % len(hex_hits), detail
    note = ""
    if color_hits:
        note = "（非阻断：%d 处裸 Color 未收口常量，建议复查：%s）" % (
            len(color_hits),
            ", ".join("%d:%s" % (ln, c) for ln, c in color_hits[:5]),
        )
    return True, "未检出规范色表外裸 hex" + note, ""


def check_bg_alpha():
    """闸门19：背景透明度校验。
    BG_SCENE_ALPHA ≤ 0.35；BG_OVERLAY_ALPHA == 0.50；BG_OVERLAY_COLOR == #16221D。
    任一不满足即 FAIL。返回 (ok, summary, detail)。"""
    fp = os.path.join(ROOT, "main.gd")
    if not os.path.exists(fp):
        return False, "main.gd 缺失", ""
    try:
        src = open(fp, "r", encoding="utf-8").read()
    except Exception as e:
        return False, "读取失败: %s" % e, ""
    detail = []
    m = re.search(r"const\s+BG_SCENE_ALPHA\s*:?\s*float\s*=\s*([\d.]+)", src)
    if not m:
        return False, "未找到 BG_SCENE_ALPHA", ""
    scene_a = float(m.group(1))
    if not (scene_a <= 0.35):
        detail.append("BG_SCENE_ALPHA=%s > 0.35" % scene_a)
    m = re.search(r"const\s+BG_OVERLAY_ALPHA\s*:?\s*float\s*=\s*([\d.]+)", src)
    if not m:
        return False, "未找到 BG_OVERLAY_ALPHA", ""
    overlay_a = float(m.group(1))
    if overlay_a != 0.50:
        detail.append("BG_OVERLAY_ALPHA=%s != 0.50" % overlay_a)
    m = re.search(r"const\s+BG_OVERLAY_COLOR\s*:?\s*Color\s*=\s*Color\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)\s*\)", src)
    if not m:
        return False, "未找到 BG_OVERLAY_COLOR", ""
    rh = "%02X%02X%02X" % (int(round(float(m.group(1)) * 255)),
                           int(round(float(m.group(2)) * 255)),
                           int(round(float(m.group(3)) * 255)))
    if rh.lower() != "16221d":
        detail.append("BG_OVERLAY_COLOR=#%s != #16221D" % rh)
    if detail:
        return False, "背景透明度校验未通过", "; ".join(detail)
    return True, "BG_SCENE_ALPHA=%.2f(≤0.35) / BG_OVERLAY_ALPHA=%.2f / #16221D" % (scene_a, overlay_a), ""


def check_array_disassemble_economy():
    """闸门20：阵法拆解经济校验（P0 防通胀修复 P2-D5-①）。
    纯静态复刻 GDScript `_阵法拆解返还数` / `_阵法升级总耗`，断言对所有
    可拆解阵法（array_type ∈ {person,sect,team}）：
      1) 任意 L1 阵法拆解产出恒为 0 —— 对应公式层 `投入<=0 → 0` 堵死；
      2) 级 >= 2 时 拆解返还 <= 升级总耗（防净赚 / 同类零投入白嫖漏洞）。
    不依赖 Godot，直接读 config/array_config.csv。返回 (ok, summary, detail)。"""
    import csv
    import math
    csv_path = os.path.join(ROOT, "config", "array_config.csv")
    if not os.path.exists(csv_path):
        return False, "array_config.csv 缺失", ""
    # rank -> (比值, 阶底) 须与 game_state.gd `_阵法拆解返还数` 完全同步
    RANK_MAP = {"common": (0.40, 3), "spirit": (0.50, 6), "treasure": (0.60, 8)}

    def 升级消耗(cost_base, cost_growth, lv):
        return max(1, int(math.ceil(cost_base * (cost_growth ** (lv - 1)))))

    def 升级总耗(cost_base, cost_growth, 至级):
        return sum(升级消耗(cost_base, cost_growth, lv) for lv in range(1, max(1, 至级)))

    def 拆解返还(总耗, 比值, 阶底):
        if 总耗 <= 0:
            return 0
        return int(math.floor(总耗 * 比值)) + 阶底

    violations = []
    try:
        with open(csv_path, "r", encoding="utf-8-sig") as f:
            reader = csv.DictReader(f)
            for row in reader:
                atype = (row.get("array_type") or "").strip()
                if atype not in ("person", "sect", "team"):
                    continue
                aid = (row.get("array_id") or "").strip()
                rank = (row.get("rank") or "common").strip()
                比值, 阶底 = RANK_MAP.get(rank, RANK_MAP["common"])
                try:
                    cost_base = float(row.get("cost_base") or 0)
                    cost_growth = float(row.get("cost_growth") or 1.0)
                    max_level = int(float(row.get("max_level") or 1))
                except (ValueError, TypeError):
                    violations.append("FAIL %s 数值解析失败 rank=%s cost_base=%s cost_growth=%s max_level=%s"
                                      % (aid, rank, row.get("cost_base"), row.get("cost_growth"), row.get("max_level")))
                    continue
                for 级 in range(1, max_level + 1):
                    总耗 = 升级总耗(cost_base, cost_growth, 级)
                    返 = 拆解返还(总耗, 比值, 阶底)
                    if 级 == 1:
                        if 返 != 0:
                            violations.append("FAIL %s 级=1 拆解返还=%d 应=0（L1 零投入白嫖漏洞）" % (aid, 返))
                    else:
                        if 返 > 总耗:
                            violations.append("FAIL %s 级=%d 拆解返还=%d > 升级总耗=%d（净赚漏洞）" % (aid, 级, 返, 总耗))
    except Exception as e:
        return False, "校验异常: %s" % e, ""
    if violations:
        detail = "\n".join(violations)
        return False, "检出 %d 处拆解净赚/白嫖漏洞" % len(violations), detail
    return True, "全部可拆解阵法 拆解返还≤投入 且 L1 产出=0", ""


def check_python_compile():
    """闸门21：项目内全部工具 .py 编译检查（py_compile）。
    覆盖 pre_f5_check.py / validate_all.py 等所有 *.py（递归子目录，排除 .git/__pycache__）。
    任一 SyntaxError → 该 gate FAIL，打印具体文件名 + 错误行。
    这比「等 pre_f5 跑 validate_all 时再崩」更早、更广——任何 .py 语法错都直接 FAIL，
    不依赖运行时才发现（2026-07 曾因残留花括号致 validate_all.py SyntaxError）。
    返回 (ok, summary, detail)。"""
    bad = []      # (loc, msg)
    scanned = 0
    for root, dirs, files in os.walk(ROOT):
        # 排除 .git / __pycache__ 及所有隐藏目录，避免扫缓存副本误报
        dirs[:] = [d for d in dirs if d not in (".git", "__pycache__") and not d.startswith(".")]
        for fn in files:
            if not fn.endswith(".py"):
                continue
            fp = os.path.join(root, fn)
            rel = os.path.relpath(fp, ROOT)
            scanned += 1
            # 编译产物写到系统临时目录，避免往项目里生成 __pycache__ 污染
            cfile = os.path.join(tempfile.gettempdir(), os.path.basename(fp) + ".pre_f5_compile")
            try:
                py_compile.compile(fp, cfile=cfile, doraise=True)
            except py_compile.PyCompileError as e:
                syn = getattr(e, "__cause__", None)
                if isinstance(syn, SyntaxError) and syn.lineno:
                    bad.append(("%s:%d" % (rel, syn.lineno), syn.msg or "SyntaxError"))
                else:
                    bad.append((rel, str(e).strip()))
            except SyntaxError as e:  # 兜底（doraise 通常抛 PyCompileError）
                bad.append(("%s:%d" % (rel, e.lineno or 0), e.msg or "SyntaxError"))
    if bad:
        detail = "\n".join("%s  %s" % (loc, msg) for loc, msg in bad)
        return False, "检出 %d 个 .py 存在 SyntaxError" % len(bad), detail
    return True, "编译通过：%d 个 .py 全部无语法错误" % scanned, ""


def check_save_key_symmetry():
    r"""闸门22：GDScript 存档键名对称检查（反模式抓取）。
    扫描 game_state.gd（及 main.gd）的 load 段，正则找 `目标 = data.get("_键")` 写法：
        (\w+)\s*=\s*data\.get\(\s*"_(\w+)"
    判定违规：若「赋值目标名」≠ "_" + 键名（即目标少了前导下划线，
    如 `上次出战弟子 = data.get("_上次出战弟子"`），→ 该 gate FAIL，
    打印 `文件:行号 目标=XXX 但键=_XXX（缺少前导下划线，与模块变量不匹配）`。
    不误杀：正常非下划线键（如 data.get("门派等级")）不匹配此正则，不检查；
    仅抓「load 目标与键名的前导下划线不一致」这一明确反模式（2026-07 game_state.gd
    存档 load 误用 `上次出战弟子 = data.get("_上次出战弟子"` 致读不回/建局部变量）。
    返回 (ok, summary, detail)。"""
    targets = ["game_state.gd", "main.gd"]
    pat = re.compile(r'(\w+)\s*=\s*data\.get\(\s*"_(\w+)"')
    hits = []
    scanned = 0
    for fn in targets:
        fp = os.path.join(ROOT, fn)
        if not os.path.exists(fp):
            continue
        scanned += 1
        try:
            lines = open(fp, "r", encoding="utf-8").readlines()
        except Exception:
            continue
        for idx, raw in enumerate(lines, 1):
            m = pat.search(raw)
            if not m:
                continue
            target, key = m.group(1), m.group(2)
            if target != ("_" + key):
                hits.append((fn, idx, target, key))
    if hits:
        detail = "\n".join(
            "%s:%d 目标=%s 但键=_%s（缺少前导下划线，与模块变量不匹配）" % (fn, ln, t, k)
            for fn, ln, t, k in hits
        )
        return False, "检出 %d 处存档键名不对称（load 目标缺前导下划线）" % len(hits), detail
    return True, "存档 load 键名对称（目标均含前导下划线，%d 文件已扫）" % scanned, ""


def check_event_reward_item_ref():
    """闸门23：事件赏赐 item 引用校验（D5④ 新增 item:item_id:count 赏赐语义）。
    event_quest.csv 的 opt1/2/3_reward 列若出现 `item:item_id:count` 形式赏赐，必须断言：
      1) item_id 存在于 array_items.csv 或 item_id_registry.csv（跨表引用合法性）；
      2) count 为正整数（count>0）。
    缺失/非正的 count 视为 count=1（与 game_state.gd `_解析并发放奇遇赏赐` 的 item: 分支默认一致）。
    任一不合法即 FAIL，打印 event_id/行号 + 违规明细。返回 (ok, summary, detail)。"""
    import csv as _csv
    eq_path = os.path.join(ROOT, "config", "event_quest.csv")
    ai_path = os.path.join(ROOT, "config", "array_items.csv")
    reg_path = os.path.join(ROOT, "tools", "config", "item_id_registry.csv")

    # 1) 收集合法 item_id 集合（两表主键列均为 item_id）
    valid_ids = set()
    def _collect(path, id_cols):
        if not os.path.exists(path):
            return
        try:
            with open(path, "r", encoding="utf-8-sig") as f:
                reader = _csv.DictReader(f)
                for row in reader:
                    for col in id_cols:
                        v = (row.get(col) or "").strip()
                        if v:
                            valid_ids.add(v)
        except Exception:
            return
    _collect(ai_path, ("item_id", "id", "item"))
    _collect(reg_path, ("item_id", "id", "item"))

    if not os.path.exists(eq_path):
        return False, "event_quest.csv 缺失", ""
    if not valid_ids:
        return False, "array_items.csv / item_id_registry.csv 均未提供合法 item_id", ""

    # 2) 扫描赏赐列中的 item: 引用
    OPT_COLS = ("opt1_reward", "opt2_reward", "opt3_reward")
    violations = []
    scanned = 0
    try:
        with open(eq_path, "r", encoding="utf-8-sig") as f:
            reader = _csv.DictReader(f)
            for ln, row in enumerate(reader, start=2):  # 标题行占 1
                eid = (row.get("event_id") or "").strip()
                for col in OPT_COLS:
                    val = (row.get(col) or "").strip()
                    if not val.startswith("item:"):
                        continue
                    scanned += 1
                    parts = val.split(":")
                    item_id = parts[1].strip() if len(parts) > 1 else ""
                    cnt = 1
                    if len(parts) > 2:
                        try:
                            cnt = int(parts[2].strip())
                        except ValueError:
                            cnt = -1  # 标记为非法
                    if item_id == "" or item_id not in valid_ids:
                        violations.append("FAIL %s 行%d [%s] item_id=%r 不在 array_items.csv/registry" % (eid, ln, col, item_id))
                    elif cnt <= 0:
                        violations.append("FAIL %s 行%d [%s] count=%s 须为正整数" % (eid, ln, col, cnt))
    except Exception as e:
        return False, "校验异常: %s" % e, ""
    if violations:
        detail = "\n".join(violations)
        return False, "检出 %d 处 item 赏赐引用不合法" % len(violations), detail
    return True, "事件赏赐 item 引用全部合法（扫描 %d 处 item: 赏赐，均存在且 count>0）" % scanned, ""


def check_zero_battle_touch():
    """闸门24：零战斗触碰红线校验（D5④ 铁律）。
    D5④ 事件赏赐落地的所有改动必须在经营/配置层，严禁触碰战斗结算：
    BattleCalculator.gd / BattleManager.gd。
    运行 `git diff --name-only HEAD`（cwd=ROOT）取改动清单，按 basename 比对；
    若任一战斗文件被改 → FAIL，打印其相对路径。返回 (ok, summary, detail)。"""
    forbidden = {"BattleCalculator.gd", "BattleManager.gd"}
    try:
        proc = subprocess.run(
            ["git", "diff", "--name-only", "HEAD"],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
        )
    except Exception as e:
        return False, "git diff 启动失败: %s" % e, ""
    changed = [l.strip().replace("\\", "/") for l in (proc.stdout or "").splitlines() if l.strip()]
    hit = [c for c in changed if c.rsplit("/", 1)[-1] in forbidden]
    if hit:
        # 明细行以 FAIL 开头，确保落入 main() 失败明细打印分支
        detail = "\n".join("FAIL 检测到战斗结算文件被改动（铁律红线）：%s" % h for h in hit)
        return False, "检出 %d 个战斗结算文件改动（铁律红线）" % len(hit), detail
    return True, "零战斗触碰：BattleCalculator.gd / BattleManager.gd 均未改动", ""


def run_csv_consumer_gate():
    """第 25 闸：CSV 消费链路校验（CSV-GOV-GATE-002，摆设型 CSV 自动治理）。

    调用 check_csv_consumer.py（纯标准库静态扫描，无 Godot 依赖），打印其完整报告。
    该脚本默认「报告模式」exit 0，本闸额外强制 ok=True 双重保险。

    ⚠️ 非阻断保护（主理人游承峰裁定）：本闸当前永远返回 ok=True，
       无论 ORPHAN 多少都【不改变 pre_f5 的退出码】——pre_f5 始终 exit 0。
       待白名单与消费者映射表经主理人批准后，移除非阻断保护、改为 ORPHAN 即 fail：
       届时此处改为 ok = (proc.returncode == 0)，并以 --strict 调用脚本
       （check_csv_consumer.py 在 --strict 下 ORPHAN>0 即 exit 1）。"""
    script = os.path.join(ROOT, "check_csv_consumer.py")
    if not os.path.exists(script):
        # 脚本缺失也不阻断（仅警告），保持 pre_f5 退出码不变
        return True, "check_csv_consumer.py 缺失（跳过，不阻断）", ""
    try:
        proc = subprocess.run(
            [sys.executable, script],   # 注意：不带 --strict，故脚本必 exit 0（报告模式）
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
        )
    except Exception as e:
        return True, "启动失败，跳过: %s" % e, ""
    out = (proc.stdout or "") + (proc.stderr or "")
    # 非阻断：即便未来脚本在 --strict 下 exit 1，本闸也强制 PASS，绝不污染 pre_f5 退出码
    return True, "报告模式·非阻断（ORPHAN 仅提醒，不阻断 F5）", out



def main():
    print("=" * 64)
    print("  太玄宗门录 · F5 前必跑检查（一键编排 · 必跑闸门）")
    print("=" * 64)

    results = []
    total_steps = len(CHECKS) + 5  # 4 子进程 + 废弃字段 + 缩进结构 + 全角/未闭字符串 + 静态扫描 + gdtoolkit解析
    for i, (name, path, cwd) in enumerate(CHECKS, 1):
        print("  运行中 [%d/%d] %s ..." % (i, total_steps, name), end="\r")
        ok, summary, full = run_check(name, path, cwd)
        results.append((name, ok, summary, full))
        mark = PASS_MARK if ok else FAIL_MARK
        # 名称右侧填充到 LINE_W，再接判定 + 摘要
        pad = LINE_W - len(name)
        if pad < 1:
            pad = 1
        print("  [%d/%d] %s%s %s  %s" % (i, len(CHECKS), name, " " * pad, mark, summary))

    # 第五道：废弃字段引用护栏（内联，不依赖外部脚本）
    d_ok, d_sum, d_detail = check_deprecated_fields()
    total = len(CHECKS) + 1
    results.append(("废弃字段引用扫描", d_ok, d_sum, d_detail))
    mark = PASS_MARK if d_ok else FAIL_MARK
    pad = LINE_W - len("废弃字段引用扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "废弃字段引用扫描", " " * pad, mark, d_sum))

    # 第六道：GDScript 缩进结构扫描（subprocess：indent_scan.py，全量扫 .gd）
    #   gdscript_type_check 只查 `:=` 不查缩进/语法，故此类灾难会漏网直到 F5；
    #   此道专门拦"开块后紧跟同级/降级行"的结构性缩进错误。
    i_ok, i_sum, i_full = run_check("GDScript 缩进结构扫描", "indent_scan.py", ROOT)
    total = total + 1
    results.append(("GDScript 缩进结构扫描", i_ok, i_sum, i_full))
    mark = PASS_MARK if i_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 缩进结构扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 缩进结构扫描", " " * pad, mark, i_sum))

    # 第七道：裸全角字符 / 跨行未闭字符串扫描（内联）
    #   gdscript_type_check 只查 :=、indent_scan 只查缩进，二者都漏语法/全角类错误；
    #   2026-07-20 L306 一处跨行未闭字符串，Godot 真机报 307~742 一长串 Invalid character 级联，
    #   六道闸门全绿却没拦住。本道专门拦此类，F5 前即可发现。
    fw_ok, fw_sum, fw_detail = check_fullwidth_strings()
    total = total + 1
    results.append(("裸全角/未闭字符串扫描", fw_ok, fw_sum, fw_detail))
    mark = PASS_MARK if fw_ok else FAIL_MARK
    pad = LINE_W - len("裸全角/未闭字符串扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "裸全角/未闭字符串扫描", " " * pad, mark, fw_sum))

    # 第八道：GDScript 静态扫描（subprocess：static_check.py，全量扫 .gd）
    #   gdscript_type_check 只查 :=、indent_scan 只查开块词后同级/降级；二者都漏
    #   「孤立缩进 / class body 裸语句 / 跨作用域变量引用」这类 Godot 才报的崩溃
    #   （2026-07-20 战斗结算面板连环 class body 崩溃 + 离山汇总面板 7 个 not declared）。
    #   本道基于缩进栈 + 跨行括号追踪，纯文本零误报兜底。
    s_ok, s_sum, s_full = run_check("GDScript 静态扫描", "static_check.py", ROOT)
    total = total + 1
    results.append(("GDScript 静态扫描", s_ok, s_sum, s_full))
    mark = PASS_MARK if s_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 静态扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 静态扫描", " " * pad, mark, s_sum))

    # 第九道：GDScript 真实语法解析（gdtoolkit，需 managed venv）
    #   pre_f5_check 既有八道闸门都不调真解析器，对 GDScript 语法错（缩进错位 / lambda 提前结束 /
    #   match case 错位）完全失明，三次被 F5 当人肉解析器才抓到（2026-07-21~22）。
    #   本道用 gdtoolkit 真 parser 兜底；venv 不存在/未装则自动 SKIP 不阻断。
    g_ok = None
    if os.path.exists(GD_VENV_PY):
        try:
            proc = subprocess.run(
                [GD_VENV_PY, os.path.join(ROOT, "gdtoolkit_check.py")],
                cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
            )
            g_out = (proc.stdout or "") + (proc.stderr or "")
            g_ok = (proc.returncode == 0)
            g_sum = ""
            for line in g_out.splitlines():
                s = line.strip()
                if s.startswith("ALL GDScript PARSE OK") or s.startswith("SKIP"):
                    g_sum = s
                    break
            if not g_sum:
                nonempty = [l.strip() for l in g_out.splitlines() if l.strip()]
                g_sum = nonempty[-1] if nonempty else ("returncode=%d" % proc.returncode)
            g_full = g_out
        except Exception as e:
            g_ok = True  # 解析器自身故障不阻断
            g_sum = "gdtoolkit 启动失败，跳过: %s" % e
            g_full = ""
    else:
        g_ok = True
        g_sum = "venv 未检测到，跳过 gdtoolkit 解析（不阻断）"
        g_full = ""
    total = total + 1
    results.append(("GDScript 语法解析(gdtoolkit)", g_ok, g_sum, g_full))
    mark = PASS_MARK if g_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 语法解析(gdtoolkit)")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 语法解析(gdtoolkit)", " " * pad, mark, g_sum))

    # 第十道：GDScript 类型名存在性扫描（gdscript_type_resolve.py，纯标准库，无需 venv）
    #   gdtoolkit（第9道）只做语法解析、不解析类型；而 Godot 编辑器一打开 .gd 就跑静态类型检查，
    #   显式注解里写了「语法合法但作用域不存在的类型名」（如 SceneTreeTween，正确是 Tween）会实时标红、
    #   F5 直接崩溃。本道模拟编辑器类型存在性检查：KNOWN_BAD 硬拦，未知大写类型名 WARN 不阻断。
    try:
        proc = subprocess.run(
            [sys.executable, os.path.join(ROOT, "gdscript_type_resolve.py")],
            cwd=ROOT, capture_output=True, text=True, encoding="utf-8",
        )
        tr_full = (proc.stdout or "") + (proc.stderr or "")
        tr_ok = (proc.returncode == 0)
        nonempty = [l.strip() for l in tr_full.splitlines() if l.strip()]
        tr_sum = nonempty[-1] if nonempty else ("returncode=%d" % proc.returncode)
    except Exception as e:
        tr_ok = True
        tr_sum = "类型扫描启动失败，跳过: %s" % e
        tr_full = ""
    total = total + 1
    results.append(("GDScript 类型名存在性扫描", tr_ok, tr_sum, tr_full))
    mark = PASS_MARK if tr_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 类型名存在性扫描")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 类型名存在性扫描", " " * pad, mark, tr_sum))
    if tr_ok and "WARN" in tr_full:
        print("    \033[93m[WARN] 存在未知类型名（WARN），请人工确认是否拼错/为内部类型，不阻断 F5\033[0m")

    # 第十七~十九道：UI 整改「三」新增校验（Tab 数 / 按钮裸色 / 背景透明度）
    for fn, name in (
        (check_tab_count, "底部导航 Tab 数校验"),
        (check_button_hex, "按钮色值/裸 hex 校验"),
        (check_bg_alpha, "背景透明度校验"),
        (check_color_token_drift, "状态色 token 漂移校验"),
        (check_rarity_color_single_source, "品阶色单一数据源校验"),
        (check_progress_bar_single_source, "进度条单源化校验"),
    ):
        ok, summary, detail = fn()
        total = total + 1
        results.append((name, ok, summary, detail))
        mark = PASS_MARK if ok else FAIL_MARK
        pad = LINE_W - len(name)
        if pad < 1:
            pad = 1
        print("  [%d/%d] %s%s %s  %s" % (total, total, name, " " * pad, mark, summary))

    # 第二十道：阵法拆解经济校验（P0 防通胀修复 P2-D5-①）
    #   复刻 GDScript `_阵法拆解返还数`，断言拆解产出价值 <= 投入物品价值，且 L1 产出恒为 0，
    #   覆盖所有可拆解阵法物品（person/sect/team），防同类零投入白嫖漏洞。
    ec_ok, ec_sum, ec_detail = check_array_disassemble_economy()
    total = total + 1
    results.append(("阵法拆解经济校验", ec_ok, ec_sum, ec_detail))
    mark = PASS_MARK if ec_ok else FAIL_MARK
    pad = LINE_W - len("阵法拆解经济校验")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "阵法拆解经济校验", " " * pad, mark, ec_sum))

    # 第二十一道：Python 工具脚本编译检查（py_compile 全量覆盖，防 SyntaxError 漏网）
    #   2026-07 validate_all.py 曾因残留花括号致 SyntaxError，pre_f5 执行它才抓到；
    #   本道显式对所有 *.py（含 pre_f5_check.py 自身）做 py_compile，任何语法错直接 FAIL，
    #   不依赖运行时才发现，覆盖更广。
    pc_ok, pc_sum, pc_detail = check_python_compile()
    total = total + 1
    results.append(("Python 工具脚本编译检查", pc_ok, pc_sum, pc_detail))
    mark = PASS_MARK if pc_ok else FAIL_MARK
    pad = LINE_W - len("Python 工具脚本编译检查")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "Python 工具脚本编译检查", " " * pad, mark, pc_sum))

    # 第二十二道：GDScript 存档键名对称检查（反模式抓取）
    #   抓 `目标 = data.get("_键")` 中目标缺前导下划线的反模式（如 game_state.gd 曾误写
    #   `上次出战弟子 = data.get("_上次出战弟子"` → 新建局部变量、存档读不回）。当前代码已修，须 PASS。
    sk_ok, sk_sum, sk_detail = check_save_key_symmetry()
    total = total + 1
    results.append(("GDScript 存档键名对称检查", sk_ok, sk_sum, sk_detail))
    mark = PASS_MARK if sk_ok else FAIL_MARK
    pad = LINE_W - len("GDScript 存档键名对称检查")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "GDScript 存档键名对称检查", " " * pad, mark, sk_sum))

    # 第二十三道：事件赏赐 item 引用校验（D5④ 新增 item:item_id:count 赏赐语义）
    #   断言 event_quest opt1/2/3_reward 的 item:item_id:count 中 item_id 合法且 count>0，
    #   防止跨表引用悬空 / 非法 count 在 F5 运行期炸（_按id造 找不到 item_id）。
    ir_ok, ir_sum, ir_detail = check_event_reward_item_ref()
    total = total + 1
    results.append(("事件赏赐 item 引用校验", ir_ok, ir_sum, ir_detail))
    mark = PASS_MARK if ir_ok else FAIL_MARK
    pad = LINE_W - len("事件赏赐 item 引用校验")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "事件赏赐 item 引用校验", " " * pad, mark, ir_sum))

    # 第二十四道：零战斗触碰红线校验（D5④ 铁律）
    #   git diff HEAD 比对 BattleCalculator.gd / BattleManager.gd 无改动；
    #   任一被改即判定违规，守住「经营/配置层零战斗触碰」铁律。
    zb_ok, zb_sum, zb_detail = check_zero_battle_touch()
    total = total + 1
    results.append(("零战斗触碰红线校验", zb_ok, zb_sum, zb_detail))
    mark = PASS_MARK if zb_ok else FAIL_MARK
    pad = LINE_W - len("零战斗触碰红线校验")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "零战斗触碰红线校验", " " * pad, mark, zb_sum))

    # 第二十五道：CSV 消费链路校验（CSV-GOV-GATE-002，摆设型 CSV 自动治理）
    #   调用 check_csv_consumer.py（报告模式，不带 --strict），打印其完整报告。
    #   ★ 非阻断保护：本闸 ok 恒为 True，无论 ORPHAN 多少都绝不改变 pre_f5 退出码（保持当前全绿不变）。
    #     待白名单与映射表经主理人批准后，移除非阻断保护、改为 ORPHAN 即 fail（见 run_csv_consumer_gate 注释）。
    cc_ok, cc_sum, cc_full = run_csv_consumer_gate()
    total = total + 1
    results.append(("CSV 消费链路校验", cc_ok, cc_sum, cc_full))
    mark = PASS_MARK if cc_ok else FAIL_MARK
    pad = LINE_W - len("CSV 消费链路校验")
    if pad < 1:
        pad = 1
    print("  [%d/%d] %s%s %s  %s" % (total, total, "CSV 消费链路校验", " " * pad, mark, cc_sum))
    if cc_full.strip():
        print("")  # 空行分隔，下面原样打印 check_csv_consumer.py 的完整报告
        for line in cc_full.splitlines():
            if line.strip():
                print("    " + line)

    print("-" * 64)
    all_ok = all(ok for _, ok, _, _ in results)
    if not all_ok:
        # 展开各失败项的问题明细（含文件名/行号/原因）
        print("  \033[91m未通过项明细：\033[0m")
        for name, ok, summary, full in results:
            if ok:
                continue
            print("  --- %s ---" % name)
            if name in NEW_UI_GATES:
                for line in full.splitlines():
                    if line.strip():
                        print("    \033[91m%s\033[0m" % line.strip())
                continue
            if name in ("Python 工具脚本编译检查", "GDScript 存档键名对称检查"):
                for line in full.splitlines():
                    if line.strip():
                        print("    \033[91m%s\033[0m" % line.strip())
                continue
            for line in full.splitlines():
                s = line.strip()
                if not s:
                    continue
                # gdscript 扫描器的逐条问题行形如 "L123 | TAG | name := val"
                # 或 validate_all 的 "ERR ..."；其余跳过以保持精简
                if s.startswith("L") and "|" in s and ":=" in s:
                    print("    \033[91m%s\033[0m" % s)
                elif s.startswith("ERR") or "FAIL" in s or "Error" in s or "AssertionError" in s:
                    print("    \033[91m%s\033[0m" % s)
                elif "-> 应改为" in s:   # 废弃字段护栏的明细行
                    print("    \033[91m%s\033[0m" % s)
                elif "开块缩进" in s or "开块:" in s or "后继:" in s:  # 缩进结构扫描明细
                    print("    \033[91m%s\033[0m" % s)
                elif "裸全角" in s or "跨行未闭" in s:                # 第7道明细
                    print("    \033[91m%s\033[0m" % s)
                elif "孤立缩进" in s or "class body" in s or "跨作用域引用" in s or "未声明" in s:  # 第8道明细
                    print("    \033[91m%s\033[0m" % s)
                elif "PARSE ERROR" in s or "读取失败" in s:  # 第9道明细
                    print("    \033[91m%s\033[0m" % s)
        print("")
    if all_ok:
        print("  \033[92m总判定: [PASS] 全部通过，可放心 F5\033[0m")
    else:
        failed = [n for n, ok, _, _ in results if not ok]
        print("  \033[91m总判定: [FAIL] 有 %d 项未通过，先修再 F5：%s\033[0m" % (len(failed), "、".join(failed)))
    print("=" * 64)

    return 0 if all_ok else 1


if __name__ == "__main__":
    sys.exit(main())
