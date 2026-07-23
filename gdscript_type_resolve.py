"""GDScript 4.x 显式类型名存在性扫描（第10道闸门）。

Godot 编辑器一打开 .gd 就会做静态类型检查；凡是显式注解里写了
「语法合法但当前作用域不存在的类型名」（如 SceneTreeTween，正确是 Tween），
编辑器实时标红、F5 直接崩溃。而 pre_f5_check 既有闸门（含 gdtoolkit）只做
语法解析，不解析类型，所以这类错误会漏到用户编辑器才暴露。

本脚本模拟 Godot 编辑器的「类型名存在性」检查：
  - 扫描所有显式类型注解：var/const : Type、func -> Type、func 参数 : Type、is/as Type
  - 已知错误类型名（KNOWN_BAD，如 SceneTreeTween）→ 直接 FAIL 硬拦
  - 白名单（Godot 4 引擎类型 + 项目 class_name 自定义类型）→ OK
  - 其它大写类型名 → UNKNOWN（WARN，不阻断，但提示人工确认是否拼错/是内部类型）

返回码：有 KNOWN_BAD → 1（FAIL）；否则 0（含 UNKNOWN 仅 WARN）。

Run: python gdscript_type_resolve.py
"""
import re, os, sys

# ---------- 已知错误类型名（确定 FAIL，附正确写法） ----------
KNOWN_BAD = {
    "SceneTreeTween": "Tween",          # Godot 4 公开类型名是 Tween，SceneTreeTween 是内部名
    # 后续发现其它误写继续往这里加
}

# ---------- Godot 4 引擎类型白名单（大写开头的公开类型） ----------
_WHITELIST_CORE = {
    # 变体 / 基础
    "bool", "int", "float", "String", "StringName", "NodePath", "Variant", "Object",
    "Array", "Dictionary", "Callable", "Signal", "Resource", "RefCounted",
    "PackedStringArray", "PackedInt32Array", "PackedInt64Array", "PackedFloat32Array",
    "PackedFloat64Array", "PackedByteArray", "PackedVector2Array", "PackedVector3Array",
    "PackedColorArray", "PackedVector4Array",
    # 数学 / 几何
    "Vector2", "Vector2i", "Vector3", "Vector3i", "Vector4", "Vector4i",
    "Rect2", "Rect2i", "Transform2D", "Transform3D", "Quaternion", "Basis",
    "AABB", "Plane", "Color", "RID", "Projection",
    # 节点树
    "Node", "CanvasItem", "Control", "Node2D", "Node3D", "CanvasLayer", "CanvasModulate",
    # 控件
    "Button", "Label", "Panel", "PanelContainer", "VBoxContainer", "HBoxContainer",
    "GridContainer", "ScrollContainer", "TextureRect", "TextureButton", "MarginContainer",
    "CenterContainer", "AspectRatioContainer", "BoxContainer", "Container", "Window",
    "Popup", "PopupPanel", "PopupMenu", "AcceptDialog", "ConfirmationDialog", "LineEdit",
    "TextEdit", "RichTextLabel", "OptionButton", "ItemList", "Tree", "TabContainer",
    "ColorRect", "GraphNode", "GraphEdit", "MenuButton", "CheckButton", "ColorPicker",
    "ColorPickerButton", "FileDialog", "HSplitContainer", "VSplitContainer", "SplitContainer",
    "SpinBox", "Slider", "HSlider", "VSlider", "TextureProgressBar", "ProgressBar",
    "VideoStreamPlayer", "SubViewport", "SubViewportContainer", "ViewPanner", "LinkButton",
    # 2D / 3D 视觉
    "Sprite2D", "Sprite3D", "AnimatedSprite2D", "AnimatedSprite3D", "Polygon2D",
    "MeshInstance2D", "MeshInstance3D", "MultiMeshInstance2D", "MultiMeshInstance3D",
    "GPUParticles2D", "GPUParticles3D", "CPUParticles2D", "CPUParticles3D",
    "Particles2D", "Particles3D", "Camera2D", "Camera3D", "Light2D", "Light3D",
    "DirectionalLight3D", "OmniLight3D", "SpotLight3D", "ReflectionProbe", "Decal",
    "WorldEnvironment", "Skeleton2D", "Skeleton3D", "Bone2D", "Bone3D", "Joint2D",
    "VisibleOnScreenNotifier2D", "VisibleOnScreenNotifier3D", "VisibleOnScreenEnabler2D",
    "VisibleOnScreenEnabler3D", "RemoteTransform2D", "RemoteTransform3D",
    # 物理
    "CharacterBody2D", "CharacterBody3D", "RigidBody2D", "RigidBody3D",
    "StaticBody2D", "StaticBody3D", "AnimatableBody2D", "AnimatableBody3D",
    "Area2D", "Area3D", "CollisionShape2D", "CollisionShape3D",
    "CollisionPolygon2D", "CollisionPolygon3D", "KinematicCollision2D",
    "KinematicCollision3D", "PhysicsBody2D", "PhysicsBody3D", "RayCast2D", "RayCast3D",
    "ShapeCast2D", "ShapeCast3D", "VehicleBody3D", "VehicleWheel3D",
    "NavigationAgent2D", "NavigationAgent3D", "NavigationObstacle2D",
    "NavigationObstacle3D", "NavigationLink2D", "NavigationLink3D", "Path2D", "Path3D",
    "PathFollow2D", "PathFollow3D", "NavigationRegion2D", "NavigationRegion3D", "NavigationMesh",
    "PhysicsMaterial", "World2D", "World3D", "Environment", "CameraAttributes",
    "CameraAttributesPractical", "CameraAttributesPhysical",
    # 资源 / 数据
    "Texture2D", "Texture3D", "Texture", "Image", "ImageTexture", "AtlasTexture",
    "CompressedTexture2D", "PortableCompressedTexture2D", "CurveTexture", "GradientTexture1D",
    "GradientTexture2D", "NoiseTexture2D", "TextureProgressBar", "Font", "FontFile",
    "FontVariation", "StyleBox", "StyleBoxFlat", "StyleBoxTexture", "StyleBoxEmpty",
    "StyleBoxLine", "Theme", "ThemeDB", "Material", "ShaderMaterial", "CanvasItemMaterial",
    "StandardMaterial3D", "ORMMaterial3D", "ParticlesMaterial", "PhysicsMaterial",
    "Shader", "ShaderInclude", "Gradient", "Curve", "Curve2D", "Curve3D", "Path",
    "Animation", "AnimationLibrary", "AnimationNode", "AnimationNodeStateMachine",
    "AnimationNodeAnimation", "AnimationNodeBlendTree", "AnimationNodeBlendSpace1D",
    "AnimationNodeBlendSpace2D", "AnimationNodeTimeScale", "AnimationNodeTimeSeek",
    "AnimationPlayer", "AnimationTree", "AudioStream", "AudioStreamWAV",
    "AudioStreamOggVorbis", "AudioStreamMP3", "AudioStreamPolyphonic",
    "AudioStreamMicrotone", "AudioStreamPlayer", "AudioStreamPlayer2D",
    "AudioStreamPlayer3D", "AudioEffect", "AudioBusLayout", "AudioStreamGenerator",
    "Mesh", "ArrayMesh", "PrimitiveMesh", "BoxMesh", "SphereMesh", "CapsuleMesh",
    "CylinderMesh", "PlaneMesh", "QuadMesh", "TextMesh", "ImmediateMesh", "Skin",
    "SkeletonProfile", "BoneMap", "TileSet", "TileMap", "TileMapLayer", "TileData",
    "PackedScene", "SceneState", "SceneTree", "SceneTreeTimer", "SceneTreeTweenPlaceholder",
    "MultiplayerSpawner", "MultiplayerSynchronizer", "EditorResourcePreview",
    "EditorFileSystem", "ResourceLoader", "ResourceSaver", "ResourceUID",
    # 脚本 / 系统
    "Script", "GDScript", "CSharpScript", "ScriptExtension", "EditorScript",
    "OS", "Engine", "ProjectSettings", "DisplayServer", "Time", "IP", "RendererServer",
    "RenderingServer", "PhysicsServer2D", "PhysicsServer3D", "NavigationServer2D",
    "NavigationServer3D", "AudioServer", "CameraServer", "Input", "InputMap",
    "InputEvent", "InputEventKey", "InputEventMouseButton", "InputEventMouseMotion",
    "InputEventMouse", "InputEventScreenTouch", "InputEventScreenDrag",
    "InputEventJoypadButton", "InputEventJoypadMotion", "InputEventMagnifyGesture",
    "InputEventPanGesture", "InputEventAction", "InputEventMIDI", "InputEventFromWindow",
    "Shortcut", "ShortcutInputEvent", "Gesture", "GDExtension", "GDExtensionManager",
    # IO / 工具
    "FileAccess", "DirAccess", "JSON", "JSONRPC", "Marshalls", "RegEx", "RegExMatch",
    "Mutex", "Semaphore", "Thread", "WorkerThreadPool", "Timer", "Tween", "RandomNumberGenerator",
    "HTTPRequest", "StreamPeer", "StreamPeerTCP", "StreamPeerBuffer", "StreamPeerGZIP",
    "StreamPeerTLS", "PacketPeer", "PacketPeerStream", "PacketPeerUDP", "UDPServer",
    "MultiplayerPeer", "MultiplayerAPI", "MultiplayerPeerExtension", "NetworkedMultiplayerPeer",
    "Crypto", "CryptoKey", "X509Certificate", "HashingContext", "HMACContext",
    "ConfigFile", "XMLParser", "XMLDocument", "Compression", "z_handle",
    "PCKPacker", "PackedDataContainer", "PackedDataContainerRef", "Translation",
    "TranslationServer", "PHashTranslation", "OptimizedTranslation", "MovieWriter",
    "Upnp", "DTLSServer", "PacketPeerDTLS", "WebSocketPeer", "WebSocketServer",
    "WebSocketMultiplayerPeer", "WebRTCDataChannel", "WebRTCPeerConnection",
    "WebRTCMultiplayerPeer", "EditorInterface", "EditorInspectorPlugin", "EditorPlugin",
    "EditorExportPlugin", "EditorImportPlugin", "EditorSceneFormatImporter",
    "EditorFileSystemImportFormatSupportQuery", "OpenXRAction", "OpenXRActionSet", "OpenXRIPBinding",
    # 音频 / 视觉特效
    "AudioEffectAmplify", "AudioEffectBandLimitFilter", "AudioEffectBandPassFilter",
    "AudioEffectCapture", "AudioEffectChorus", "AudioEffectCompressor", "AudioEffectDelay",
    "AudioEffectDistortion", "AudioEffectEQ", "AudioEffectEQ6", "AudioEffectEQ10",
    "AudioEffectEQ21", "AudioEffectFilter", "AudioEffectHighPassFilter",
    "AudioEffectHighShelfFilter", "AudioEffectLimiter", "AudioEffectLowPassFilter",
    "AudioEffectLowShelfFilter", "AudioEffectNotchFilter", "AudioEffectPanner",
    "AudioEffectPhaser", "AudioEffectPitchShift", "AudioEffectRecord", "AudioEffectReverb",
    "AudioEffectStereoEnhance", "VisualShader", "VisualShaderNode", "VisualShaderNodeCustom",
    "VisualShaderNodeGroupBase", "EditorVisualShaderNode",
}
WHITELIST = set(_WHITELIST_CORE)


# ---------- 提取工具 ----------
def collect_custom_types(root):
    """从 class_name X 收集项目自定义类型。"""
    types = set()
    for dirpath, _, filenames in os.walk(root):
        if ".godot" in dirpath:
            continue
        for fn in filenames:
            if fn.endswith(".gd") and not fn.startswith("test_"):
                fp = os.path.join(dirpath, fn)
                try:
                    with open(fp, "r", encoding="utf-8") as f:
                        for line in f:
                            m = re.match(r"\s*class_name\s+([A-Z]\w+)", line)
                            if m:
                                types.add(m.group(1))
                except Exception:
                    pass
    return types


# 匹配：var/const 显式类型注解（排除 := 推断）
RE_VAR_TYPE = re.compile(r"(?:var|const)\s+\w+\s*:\s*([A-Z]\w+)")
# 匹配：函数返回类型 -> Type
RE_RET_TYPE = re.compile(r"\)\s*->\s*([A-Z]\w+)")
# 匹配：函数签名括号内的参数串
RE_FUNC_SIG = re.compile(r"func\s+\w+\s*\(([^)]*)\)")
# 匹配：参数里的类型注解  name: Type
RE_PARAM_TYPE = re.compile(r"(?:^|[\s,(])([A-Za-z_]\w*)\s*:\s*([A-Z]\w+)")
# 匹配：is / as 后的类型名
RE_IS_AS = re.compile(r"\b(?:is|as)\s+([A-Z]\w+)")


def judge(typ, custom):
    if typ in KNOWN_BAD:
        return "BAD"
    if typ in WHITELIST or typ in custom:
        return "OK"
    return "UNKNOWN"


def scan_file(filepath, custom):
    bad, unknown = [], []
    try:
        with open(filepath, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except Exception as e:
        return [], [], "读取失败: %s" % e

    for i, raw in enumerate(lines, 1):
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        # 跳过纯推断 := （冒号后是等号，不会匹配下面 : Type）
        # 1) var/const 注解
        for m in RE_VAR_TYPE.finditer(line):
            typ = m.group(1)
            r = judge(typ, custom)
            if r == "BAD":
                bad.append((i, "var/const", typ, KNOWN_BAD[typ]))
            elif r == "UNKNOWN":
                unknown.append((i, "var/const", typ, ""))
        # 2) 函数返回类型
        m = RE_RET_TYPE.search(line)
        if m:
            typ = m.group(1)
            r = judge(typ, custom)
            if r == "BAD":
                bad.append((i, "return", typ, KNOWN_BAD[typ]))
            elif r == "UNKNOWN":
                unknown.append((i, "return", typ, ""))
        # 3) 函数参数类型
        msig = RE_FUNC_SIG.search(line)
        if msig:
            params = msig.group(1)
            for pm in RE_PARAM_TYPE.finditer(params):
                typ = pm.group(2)
                r = judge(typ, custom)
                if r == "BAD":
                    bad.append((i, "param", typ, KNOWN_BAD[typ]))
                elif r == "UNKNOWN":
                    unknown.append((i, "param", typ, ""))
        # 4) is / as 类型
        for m in RE_IS_AS.finditer(line):
            typ = m.group(1)
            r = judge(typ, custom)
            if r == "BAD":
                bad.append((i, "is/as", typ, KNOWN_BAD[typ]))
            elif r == "UNKNOWN":
                unknown.append((i, "is/as", typ, ""))
    return bad, unknown, ""


def main():
    root = "."
    custom = collect_custom_types(root)
    gd_files = []
    for dirpath, _, filenames in os.walk(root):
        if ".godot" in dirpath:
            continue
        for fn in filenames:
            if fn.endswith(".gd") and not fn.startswith("test_"):
                gd_files.append(os.path.join(dirpath, fn))

    all_bad, all_unknown = [], []
    for fp in sorted(gd_files):
        bad, unknown, err = scan_file(fp, custom)
        rel = os.path.relpath(fp, ".").replace("\\", "/")
        for b in bad:
            all_bad.append((rel,) + b)
        for u in unknown:
            all_unknown.append((rel,) + u)

    print("=== GDScript 类型名存在性扫描（第10道闸门） ===")
    print("自定义类型(class_name): %s" % (", ".join(sorted(custom)) if custom else "无"))
    print("扫描: %d 文件" % len(gd_files))

    if all_bad:
        print("\n❌ 命中已知错误类型名（必须修正）：")
        for rel, ln, ctx, typ, sug in all_bad:
            print("   [%s] L%d | %s | %s → 应改为 %s" % (rel, ln, ctx, typ, sug))
    if all_unknown:
        print("\n⚠️ 未知类型名（WARN，需人工确认是否拼错/为内部类型）：")
        for rel, ln, ctx, typ, _ in all_unknown:
            print("   [%s] L%d | %s | %s" % (rel, ln, ctx, typ))

    if not all_bad and not all_unknown:
        print("\n✅ 全部类型名合法（白名单/自定义类型命中）")
    if all_bad:
        print("\n总判定: FAIL（%d 处已知错误类型名）" % len(all_bad))
        return 1
    if all_unknown:
        print("\n总判定: PASS（含 %d 处 WARN，不阻断，请人工确认）" % len(all_unknown))
    else:
        print("\n总判定: PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
