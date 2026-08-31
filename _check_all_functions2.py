import re
import os

def get_functions(filepath):
    functions = set()
    try:
        with open(filepath, 'r', encoding='utf-8') as f:
            for line in f:
                # 匹配 func 和 static func
                match = re.match(r'^(static\s+)?func\s+(\w+)', line)
                if match:
                    functions.add(match.group(2))
    except Exception as e:
        print(f'读取文件 {filepath} 出错: {e}')
    return functions

# 核心文件列表
core_files = [
    'game_state.gd',
    'main.gd',
    'disciple.gd',
    'item.gd',
    'beast.gd',
    'quest.gd',
    'lore.gd',
    'recruit.gd',
    'expedition.gd',
    'forge.gd',
    'alchemy.gd',
    'zhenfa.gd',
    'zhifa.gd',
    'gongxun.gd',
    'xichi.gd',
    'zongmen_battle.gd',
    'faction_system.gd',
    'period_settlement.gd',
    'economy_balance.gd',
    'SkinManager.gd',
    'red_dot_manager.gd',
    'BattleManager.gd',
    'BattleCalculator.gd',
    'battle_util.gd',
    'ui_theme.gd',
    'ui/game_ui.gd',
    'ui/sect_home_page.gd',
    'ui/top_bar.gd',
    'ui/bottom_tab_bar.gd',
]

print('核心文件函数数量统计（含static func）:')
print('=' * 60)
total_funcs = 0
for f in core_files:
    if os.path.exists(f):
        funcs = get_functions(f)
        total_funcs += len(funcs)
        print(f'{f}: {len(funcs)} 个函数')
    else:
        print(f'{f}: 不存在')

print('=' * 60)
print(f'核心文件总函数数量: {total_funcs}')
