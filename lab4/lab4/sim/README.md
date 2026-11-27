# 功能自检

两套测试均使用Verilog-2001，不依赖外部向量、Vivado IP或板卡。核心测试顶层为tb_alu_core，板级逻辑测试顶层为tb_lab4_top。

| 测试 | 覆盖与通过标记 |
| --- | --- |
| core | CLU4和CLA4各512组穷举，CLA16定向与固定随机、32位算术、ALU固定/随机/未用控制；18160项检查 |
| board | 20条预置、显示选择、字节装载、按键过滤及单次触发、复位、逻辑段码；166项检查 |

在Vivado中分别将两套顶层Set as Top，运行Behavioral Simulation后执行run all。初始骨架可编译，但应报告功能FAIL；补齐后才应得到最终PASS。

核心通过标记为PASS: ALL CORE TESTS PASSED (18160 checks)，状态文件lab4_sim_status.txt。
板级通过标记为PASS: BOARD LOGIC TESTS PASSED (166 checks)，状态文件lab4_board_status.txt。
状态文件位于build/lab4.sim/sim_1/behav/xsim，脚本每次清除对应旧状态并检查本轮errors=0。

core失败编号：10000段CLU4、20000段CLA4、30000段CLA16、40000段32位算术、1至20固定ALU、50000段随机ALU、60000段非法控制。先修复最底层失败。固定ALU波形从2565ns开始，原始core在3621ns结束，board在11930ns结束。

板级测试使用缩短的扫描与过滤参数以加速仿真；它验证逻辑行为，不等同于测试真实按键的物理抖动或实板电气参数。
