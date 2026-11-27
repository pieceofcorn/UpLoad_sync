# 实验四：ALU设计与上板验证

将整个lab4文件夹放在英文短路径，例如D:/lab4。先阅读docs/实验四_上板实验.pdf；安装说明见docs/vivado安装教程.pdf。

## 目录

| 位置 | 内容 |
| --- | --- |
| rtl/core | 6个运算模块，其中5个待补齐，接口适配已提供 |
| rtl/board | 已提供的输入装载、按键处理、显示和预置用例 |
| sim | 核心与板级逻辑自检 |
| constraints/lab4.xdc | 本板引脚与100MHz时钟约束 |
| scripts | 可选的工程创建和仿真脚本 |
| docs | 实验手册、安装教程与电路原理图 |

初次仿真允许编译成功，但未补齐的零占位不能通过功能自检。依次完成CLU4、CLA4、CLA16、32位加减及ALU，保留模块接口和CLA/CLU层次，加入真实驱动时删除对应占位。

## 创建与仿真

图形界面步骤见实验手册；也可在Vivado Tcl Console执行以下命令创建工程：

    source {D:/lab4/scripts/create_project.tcl}

脚本只创建lab4工程，自动加入本包的12个Verilog文件和lab4.xdc。工程保存为build/lab4.xpr，设计顶层lab4_top，初始仿真顶层tb_alu_core。

命令行仿真为可选方式。在lab4目录打开PowerShell，将$vivado设为本机完整启动路径，然后运行：

    $vivado = 'D:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
    & $vivado -mode batch -source scripts/run_sim.tcl -tclargs core
    & $vivado -mode batch -source scripts/run_sim.tcl -tclargs board

core与board分别表示两种测试。出现FAIL时先处理最底层错误；两套测试通过后，按手册进行综合、实现、生成比特流及Program Device。

## 提交

无需完整实验报告。每组将整个电路工程归档为ZIP，在下次实验课前发送至助教邮箱。下次实验课以小组为单位线下验收。归档方法及推荐分工见实验手册。
