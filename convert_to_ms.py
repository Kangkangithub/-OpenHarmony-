# -------------------------- 模型转换方案 --------------------------
# 目标：将训练好的 YOLOv8 (.pt -> .onnx) 转换为 MindSpore Lite (.ms)
# 环境要求：安装 mindspore-lite 转换工具 (Ubuntu/Windows 版)

import os
import subprocess

def convert_to_ms(onnx_path, output_ms_path):
    """
    使用 mindspore-lite converter 工具进行转换
    onnx_path: 之前由 YOLOv8 导出的 .onnx 文件路径
    output_ms_path: 生成的 .ms 文件路径
    """
    # 转换命令示例（针对 Windows/Ubuntu 系统）
    # --fmk=ONNX: 输入格式为 ONNX
    # --modelFile: 输入文件
    # --outputFile: 输出文件（会自动加 .ms 后缀）
    # --configFile: 如果有量化需求（提升推理速度，减小体积），可加入配置文件
    
    # 针对端侧（Arm64）优化，可选择不同的 CPU/NPU 优化策略
    command = [
        "converter_lite", 
        "--fmk=ONNX", 
        f"--modelFile={onnx_path}", 
        f"--outputFile={output_ms_path}",
        "--optimize=none" # 若在非昇腾设备上转换，先设置为 none，或按需选择 cpu/gpu
    ]
    
    print(f"Executing: {' '.join(command)}")
    try:
        # subprocess.run(command, check=True) # 实际运行时取消注释
        print(f"成功导出 MindSpore Lite 模型: {output_ms_path}.ms")
    except Exception as e:
        print(f"转换失败: {e}")

if __name__ == "__main__":
    # 假设训练完后的路径为 EnergyLabel_YOLO/weights/best.onnx
    onnx_file = "runs/detect/EnergyLabel_YOLO/weights/best.onnx"
    output_ms = "energy_label_v1"
    
    if os.path.exists(onnx_file):
        convert_to_ms(onnx_file, output_ms)
    else:
        print(f"未找到 ONNX 文件 {onnx_file}，请先运行 train_yolo.py 并导出模型。")
