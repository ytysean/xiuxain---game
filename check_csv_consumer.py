# -*- coding: utf-8 -*-
# check_csv_consumer.py —— 《太玄宗门录》CSV 消费链路自动校验（CSV-GOV-GATE-002）
#
# 治理目标：治理「摆设型 CSV」（有配置/校验但零运行时消费者）。
#   遍历 config/*.csv，检索业务代码库（所有 .gd/.py，排除 csv_validator.gd / validate_all.py）
#   对该文件名的字面引用；据此判定每张表的消费状态：
#     [OK]       有业务代码字面引用 -> 正常。
#     [RESERVED] 无引用、但在 docs/csv_预留白名单.md 的 RESERVED_LIST 内 -> 黄色提醒（预留表），非阻断。
#     [BAK]      无引用、且是 .bak/.tmp 临时/备份文件 -> 橙色提醒（建议删除），非阻断（报告单列）。
#     [ORPHAN]   无引用、不在白名单、非临时文件 -> 红色提醒（摆设型未授权），报告标红，当前非阻断。
#
# 上线策略（主理人游承峰裁定）：
#   ★ 当前以「非阻断 + 报告模式」上线，默认 exit 0（绝不改变调用方退出码）★
#   待白名单与消费者映射表经主理人批准后，再切 --strict（ORPHAN>0 即 exit 1）阻断提交。
#   本脚本被 pre_f5_check.py 以「报告模式」（不带 --strict）调用，故 pre_f5 永远 exit 0。
#
# 用法（项目根目录执行）：
#   python check_csv_consumer.py                  # 报告模式，exit 0（默认 runtime scope）
#   python check_csv_consumer.py --strict         # 阻断模式，ORPHAN>0 则 exit 1（供将来切换用，本次不启用）
#   python check_csv_consumer.py --scope all      # 扫描所有 .gd/.py（含 dev 工具/测试），对齐差事字面范围
#   python check_csv_consumer.py --scope runtime  # 仅扫 Godot 运行时 .gd（默认，对齐《三位一体》核定的 28）
#   python check_csv_consumer.py --no-color       # 关闭 ANSI 颜色（适合写入日志/CI 纯文本）
#
# 消费者扫描 scope（关键边界，CSV-GOV-GATE-002 已向主理人报备）：
#   本工程是 Godot 4 项目，游戏运行时只执行 .gd；仓库内所有 .py 均为外部 dev/CI 工具
#   （pre_f5_check.py / check_resource_redline.py / validate_all.py 等），不会在 Godot 内运行。
#   若把"仅被 .py 工具或 tests/ 引用"也算作消费者，会复活「系统已落地错觉」
#   （如 item_id_registry.csv / 新功能冲击声明.csv / resource_flow.csv 仅被 dev 工具/测试打开，已迁 tools/config/ 脱离运行时闸门；config/ 内零引用表方为真摆设）。
#   故默认 scope=runtime：只扫 .gd 运行时消费者 -> 对齐《三位一体》核定的「真实被消费 28 张」。
#   若主理人要求按差事字面"所有 .gd+.py"全扫，可用 --scope all（会多计 3 张工具/测试引用为 OK）。
#   两种 scope 的 RESERVED/BAK/ORPHAN 判定规则一致，仅消费者来源不同。
#
# 实现约束：
#   - 纯 Python 标准库，无 Godot 引擎依赖，无第三方依赖（仅 os/re/sys）。
#   - 中文文件名/路径用标准库 open(encoding="utf-8") 处理（仓库已踩过 NFC 幽灵坑，无需 git 操作）。
#   - 扫描消费者时排除 csv_validator.gd（TABLE_RULES 用键注册、且注释里会字面提到表名，会误判预留表为已消费）
#     与 validate_all.py；并排除 .bak/.tmp 临时源文件。
import os
import re
import sys

ROOT = os.path.dirname(os.path.abspath(__file__))
CONFIG_DIR = os.path.join(ROOT, "config")
WHITELIST_MD = os.path.join(ROOT, "docs", "csv_预留白名单.md")

# 扫描消费者时排除的文件（按文件名，防 csv_validator 注释/字符串误判预留表为已消费）
EXCLUDED_SOURCE_FILES = {"csv_validator.gd", "validate_all.py"}

# 引号包裹的 .csv 字面引用：["'](...*.csv)["']
CSV_LITERAL_RE = re.compile(r'''["']([^"']*\.csv)["']''')

# ANSI 颜色
C_OK = "\033[92m"      # 绿
C_RESERVED = "\033[93m"  # 亮黄
C_BAK = "\033[33m"     # 橙（普通黄）
C_ORPHAN = "\033[91m"  # 红
C_RESET = "\033[0m"
C_DIM = "\033[90m"


def use_color():
    if "--no-color" in sys.argv:
        return False
    return sys.stdout.isatty() or ("FORCE_COLOR" in os.environ)


_COLOR_ON = use_color()


def color(code, text):
    if not _COLOR_ON:
        return text
    return code + text + C_RESET


def is_valid_csv_name(base):
    """校验提取出的 basename 是否像一个真实的 CSV 文件名（过滤 .csv / *.csv / .bak.csv 等噪声）。"""
    if not base.endswith(".csv"):
        return False
    stem = base[:-4]
    if not stem or stem.startswith("."):
        return False
    if any(ch in stem for ch in "*?<>|"):
        return False
    return True


def is_backup_or_temp(name):
    """判定文件名是否为 .bak/.tmp 临时/备份文件（含 xxx.bak.csv / xxx.tmp.csv 形态）。"""
    low = name.lower()
    if low.endswith(".bak") or low.endswith(".tmp"):
        return True
    if low.endswith(".csv"):
        stem = low[:-4]
        if stem.endswith(".bak") or stem.endswith(".tmp"):
            return True
    return False


def parse_reserved_list(md_path):
    """解析 docs/csv_预留白名单.md 中 RESERVED_LIST_START/END 之间的机器可读清单。
    每行格式：文件名.csv|Sx|理由（| 分隔）。返回 {文件名: (Sx, 理由)}。
    文件缺失或区块缺失时返回空字典（不阻断，仅导致更多 ORPHAN）。"""
    reserved = {}
    if not os.path.exists(md_path):
        sys.stderr.write("[warn] 白名单文件不存在: %s（按空集处理）\n" % md_path)
        return reserved
    try:
        text = open(md_path, "r", encoding="utf-8").read()
    except Exception as e:
        sys.stderr.write("[warn] 白名单读取失败: %s（按空集处理）\n" % e)
        return reserved
    m = re.search(
        r"<!--\s*RESERVED_LIST_START\s*-->(.*?)<!--\s*RESERVED_LIST_END\s*-->",
        text, re.DOTALL)
    if not m:
        sys.stderr.write("[warn] 未找到 RESERVED_LIST_START/END 区块（按空集处理）\n")
        return reserved
    for line in m.group(1).splitlines():
        line = line.strip()
        if not line or line.startswith("<!--"):
            continue
        parts = line.split("|")
        name = parts[0].strip()
        if not name.endswith(".csv"):
            continue
        sx = parts[1].strip() if len(parts) > 1 else ""
        reason = parts[2].strip() if len(parts) > 2 else ""
        reserved[name] = (sx, reason)
    return reserved


def scan_consumers(root, scope="runtime"):
    """扫描业务代码库，返回 {csv_basename: set(引用它的相对路径)}。

    scope:
      "runtime" (默认): 仅扫 .gd 运行时脚本（Godot 游戏真正执行的代码），
                        跳过 tests/ 目录与 EXCLUDED_SOURCE_FILES。
                        对齐《三位一体》核定的「真实被消费 28 张」——.py 工具不在 Godot 内运行。
      "all":     扫所有 .gd + .py（排除 csv_validator.gd / validate_all.py 及 .bak/.tmp 临时源），
                对齐差事字面"所有 .gd + .py"范围（会多计工具/测试引用为 OK）。
    通用：跳过隐藏/缓存目录（.git/.godot/.workbuddy/__pycache__ 等）。"""
    referenced = {}
    for dirpath, dirs, files in os.walk(root):
        # 跳过隐藏/缓存目录（.git/.godot/.workbuddy/__pycache__ 等），避免扫到缓存副本误报
        dirs[:] = [d for d in dirs
                   if not d.startswith(".")
                   and d not in ("__pycache__",)]
        rel_dir = os.path.relpath(dirpath, root)
        in_tests = rel_dir == "tests" or rel_dir.startswith("tests" + os.sep)
        for fn in files:
            is_gd = fn.endswith(".gd")
            is_py = fn.endswith(".py")
            if scope == "runtime":
                if not is_gd:
                    continue
                if in_tests:
                    continue
            else:  # all
                if not (is_gd or is_py):
                    continue
                if is_py and fn in EXCLUDED_SOURCE_FILES:
                    continue
                low = fn.lower()
                if low.endswith(".bak") or low.endswith(".tmp"):
                    continue
                stem = low[:-3]  # .gd / .py 均为 3 字节后缀
                if stem.endswith(".bak") or stem.endswith(".tmp"):
                    continue
            if is_gd and fn in EXCLUDED_SOURCE_FILES:
                continue
            fp = os.path.join(dirpath, fn)
            rel = os.path.relpath(fp, root)
            try:
                with open(fp, "r", encoding="utf-8", errors="replace") as f:
                    text = f.read()
            except Exception:
                continue
            for mm in CSV_LITERAL_RE.finditer(text):
                inside = mm.group(1)
                # 取路径末尾的文件名作为 basename
                base = inside.replace("\\", "/").rsplit("/", 1)[-1]
                if not is_valid_csv_name(base):
                    continue
                referenced.setdefault(base, set()).add(rel)
    return referenced


def classify(csv_files, referenced, reserved):
    """返回 list of (name, status, detail) —— status ∈ OK/RESERVED/BAK/ORPHAN。"""
    out = []
    for name in csv_files:
        consumers = referenced.get(name)
        if consumers:
            out.append((name, "OK", "消费者: " + ", ".join(sorted(consumers))))
        elif name in reserved:
            sx, reason = reserved[name]
            out.append((name, "RESERVED", "[%s] %s" % (sx, reason)))
        elif is_backup_or_temp(name):
            out.append((name, "BAK", "临时/备份文件，建议删除备份文件"))
        else:
            out.append((name, "ORPHAN", "无业务消费者引用，且未入白名单"))
    return out


def main():
    strict = "--strict" in sys.argv
    scope = "runtime"
    if "--scope" in sys.argv:
        i = sys.argv.index("--scope")
        if i + 1 < len(sys.argv):
            scope = sys.argv[i + 1]
    if scope not in ("runtime", "all"):
        sys.stderr.write("[warn] 未知 --scope=%s，回退为 runtime\n" % scope)
        scope = "runtime"
    csv_files = sorted(
        f for f in os.listdir(CONFIG_DIR)
        if f.lower().endswith(".csv") and os.path.isfile(os.path.join(CONFIG_DIR, f))
    ) if os.path.isdir(CONFIG_DIR) else []

    reserved = parse_reserved_list(WHITELIST_MD)
    referenced = scan_consumers(ROOT, scope)
    rows = classify(csv_files, referenced, reserved)

    counts = {"OK": 0, "RESERVED": 0, "BAK": 0, "ORPHAN": 0}
    for _, status, _ in rows:
        counts[status] += 1

    total = len(csv_files)
    print("=" * 72)
    print("  CSV 消费链路校验（check_csv_consumer.py）— %s"
          % ("阻断模式 --strict" if strict else "报告模式（非阻断）"))
    print("=" * 72)
    print("  扫描目录 : config/  (%d 张 *.csv)" % total)
    scope_desc = ("Godot 运行时 .gd（排除 tests/ 与 csv_validator.gd）"
                  if scope == "runtime"
                  else "所有 .gd/.py（排除 csv_validator.gd / validate_all.py）")
    print("  消费者范围: %s" % scope_desc)
    print("  预留白名单: docs/csv_预留白名单.md（RESERVED_LIST）解析到 %d 条" % len(reserved))
    print("-" * 72)

    # 逐 CSV 状态表
    for name, status, detail in rows:
        if status == "OK":
            tag = color(C_OK, "[OK]      ")
        elif status == "RESERVED":
            tag = color(C_RESERVED, "[RESERVED] ")
        elif status == "BAK":
            tag = color(C_BAK, "[BAK]     ")
        else:
            tag = color(C_ORPHAN, "[ORPHAN]  ")
        # detail 截断，避免单行过长
        d = detail
        if len(d) > 52:
            d = d[:52] + "..."
        print("  %s %s  %s" % (tag, name.ljust(28), color(C_DIM, d)))

    print("-" * 72)
    print("  汇总: OK=%d  RESERVED=%d  BAK=%d  ORPHAN=%d  总计=%d"
          % (counts["OK"], counts["RESERVED"], counts["BAK"], counts["ORPHAN"], total))

    orphans = [name for name, status, _ in rows if status == "ORPHAN"]
    if orphans:
        print("")
        print(color(C_ORPHAN, "  若切阻断模式(--strict)，以下 %d 张 ORPHAN 将阻断提交:" % len(orphans)))
        for name in orphans:
            print("    - %s" % name)

    print("")
    if strict:
        if orphans:
            print(color(C_ORPHAN, "  [阻断模式] 存在 %d 张 ORPHAN -> exit 1" % len(orphans)))
        else:
            print(color(C_OK, "  [阻断模式] 无 ORPHAN -> exit 0"))
    else:
        print(color(C_RESERVED, "  [报告模式] 本脚本 exit 0（非阻断）；需阻断时请用 --strict。"))
    print("=" * 72)

    # 退出码：默认 0（非阻断报告模式）。--strict 下 ORPHAN>0 才 exit 1。
    return 1 if (strict and counts["ORPHAN"] > 0) else 0


if __name__ == "__main__":
    sys.exit(main())
