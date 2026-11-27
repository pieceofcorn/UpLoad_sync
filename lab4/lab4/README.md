# 实验四：ALU设计与上板验证

本目录是 Vivado + Verilog + FPGA 版本的实验工程。建议将整个 lab4 文件夹放在英文短路径下，例如 D:/lab4。先阅读 docs/实验四_上板实验.pdf；安装说明见 docs/vivado安装教程.pdf。

## 目录

| 位置 | 内容 |
| --- | --- |
| rtl/core | CLU4、CLA4、CLA16、32位加减法器和ALU核心 |
| rtl/board | 输入装载、按键处理、显示和预置用例 |
| sim | 核心与板级逻辑自检 |
| constraints/lab4.xdc | 本实验板引脚与100MHz时钟约束 |
| scripts | Vivado工程创建、仿真和批处理构建脚本 |
| docs | 实验手册、安装教程与电路原理图 |

lab4-work 分支已补齐 rtl/core 中的五个待实现模块，保留原模块接口、CLA/CLU层次和课程测试文件。alu_core.v 是已提供的接口适配模块。

## 创建工程

可在 Vivado Tcl Console 执行：

    source {D:/lab4/scripts/create_project.tcl}

也可以直接使用批处理脚本。工程保存为 build/lab4.xpr，设计顶层为 lab4_top，初始仿真顶层为 tb_alu_core。

## 功能仿真

在本目录打开 PowerShell，将 $vivado 设置为本机 Vivado 启动路径：

    $vivado = 'D:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
    & $vivado -mode batch -source scripts/run_sim.tcl -tclargs core
    & $vivado -mode batch -source scripts/run_sim.tcl -tclargs board

core 测试核心运算逻辑，预期至少18160项检查通过；board 测试板级输入、按键和显示逻辑，预期至少166项检查通过。出现FAIL时先处理最底层错误，不要修改测试期望值来绕过失败。

## 综合、实现与生成比特流

两套仿真均通过后，在本目录运行：

    $vivado = 'D:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
    & $vivado -mode batch -source scripts/run_build.tcl -tclargs 4

最后的 4 表示并行作业数，可以根据电脑资源调整。脚本会重新运行综合和实现，生成时序、资源利用率及DRC报告，并生成 Bitstream。脚本只生成比特流，不会连接或烧录开发板。

默认输出位置：

- 工程：build/lab4.xpr
- Bitstream：build/lab4.runs/impl_1/lab4_top.bit
- 报告：build/reports/

重点查看 implementation_timing_summary.rpt、implementation_utilization.rpt 和 implementation_drc.rpt。本工程 XDC 定义了100MHz主时钟，但没有为所有外部输入/输出指定延迟约束；时序报告应结合这一限制解读，不能将其视为完整的板级I/O时序签核。

## 上板前检查

constraints/lab4.xdc 的目标板标注为 EDK-A7-Minisys-I V3.2-100T，器件为 XC7A100T FGG484。烧录前必须确认实际开发板型号、PCB版本、FPGA封装和引脚映射与该约束文件一致。不要仅凭 FPGA 系列相同就使用该 XDC。

完成比特流生成后，按照实验手册通过 Vivado Hardware Manager 连接目标板并执行 Program Device。批处理构建脚本不会自动烧录。

## 提交

课程 README 要求每组将整个电路工程归档为 ZIP，在下次实验课前发送至助教邮箱，并在下次实验课进行小组线下验收。归档方法及推荐分工见实验手册。
