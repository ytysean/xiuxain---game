@echo off
REM ============================================================
REM 本地超分：把宗门背景 A 版源图(832x1216) 放大 4x 到约 3328x4864
REM 用法：
REM   1. 下载 realesrgan-ncnn-vulkan Release，把 realesrgan-ncnn-vulkan.exe
REM      放到本文件同目录（或把它所在目录加进系统 PATH）
REM   2. 确认 sect_bg_a_source_832.png 在本文件同目录
REM   3. 双击本文件
REM 注意：
REM   - 模型用 realesrgan-x4plus（真实照片模型），别用 anime 模型
REM     （本图是写实国漫厚涂+油画质感，anime 会把写实纹理糊掉）
REM   - 若源图带 AI 平台水印，务必先去水印再超分，否则水印被放大
REM ============================================================
SETLOCAL
SET REAL_ESRGAN=realesrgan-ncnn-vulkan.exe
SET IN=sect_bg_a_source_832.png
SET OUT=sect_bg_a_4x.png

IF NOT EXIST "%IN%" (
    echo [ERROR] 找不到源图 %IN%，请确认它和本脚本在同一目录
    pause
    EXIT /B 1
)

"%REAL_ESRGAN%" -i "%IN%" -o "%OUT%" -s 4 -n realesrgan-x4plus

IF EXIST "%OUT%" (
    echo [DONE] 超分完成：%OUT%
) ELSE (
    echo [FAIL] 未生成输出，请检查 realesrgan-ncnn-vulkan.exe 是否在 PATH 或同目录
)
pause
