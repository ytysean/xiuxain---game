import os

files = [
    'game_state.gd',
    'game_state_backup_safe.gd',
    'game_state_backup_before_batch3.gd',
    'game_state_backup_batchfix.gd',
    'game_state_recovered.gd',
]

for f in files:
    if os.path.exists(f):
        with open(f, 'r', encoding='utf-8') as fp:
            lines = fp.readlines()
            print(f'{f}: {len(lines)} 行')
    else:
        print(f'{f}: 不存在')
