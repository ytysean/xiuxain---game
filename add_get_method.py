# -*- coding: utf-8 -*-
"""
在disciple.gd中添加get()方法，用于获取属性值
这样所有的d.get(key, default)调用都可以正常工作
"""

file_path = r"E:\Xiuxian\taixuanzongmenlu\disciple.gd"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 查找第一个func定义的位置，在它前面添加get()方法
lines = content.split('\n')
insert_pos = -1
for i in range(len(lines)):
    if lines[i].strip().startswith("func "):
        insert_pos = i
        break

if insert_pos > 0:
    # 在insert_pos位置插入get()方法
    get_method = [
        "",
        "# 获取属性值（兼容Dictionary风格的get()调用）",
        "func get(key: String, default = null):",
        "\tif has_property(key):",
        "\t\treturn get(property_list().find(key) if property_list().find(key) >= 0 else 0)",
        "\treturn default",
        "",
    ]
    # 注意：上面的get()方法实现有问题，让我重新实现
    # 正确的实现应该是：
    get_method = [
        "",
        "# 获取属性值（兼容Dictionary风格的get()调用）",
        "func get(key: String, default = null):",
        "\tvar props = property_list()",
        "\tfor prop in props:",
        "\t\tif prop.name == key:",
        "\t\t\treturn get(property_list().find(prop) if property_list().find(prop) >= 0 else 0)",
        "\treturn default",
        "",
    ]
    # 实际上，上面的实现还是有问题。让我使用更简单的实现：
    get_method = [
        "",
        "# 获取属性值（兼容Dictionary风格的get()调用）",
        "func get(key: String, default = null):",
        "\tvar props = property_list()",
        "\tfor i in range(props.size()):",
        "\t\tif props[i].name == key:",
        "\t\t\treturn get(i)",
        "\treturn default",
        "",
    ]
    
    for j in range(len(get_method)):
        lines.insert(insert_pos + j, get_method[j])
    
    content = '\n'.join(lines)
    
    # 写回文件
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ 已在disciple.gd第{insert_pos+1}行前添加get()方法")
else:
    print("❌ 未找到func定义的位置")
