---
project: 数字逻辑与计算机组成 - 实验四
status: 待完成实体 FPGA 烧录与验收
title: ALU 实验项目交接说明
---

# ALU 实验项目交接说明（供 Codex 使用）

> 本文件是项目交接材料。它记录了当前已知环境、历史执行结果、未完成事项和工作边界。**本机工程、最新源码、日志和实验手册优先于本文件中的历史记录。**
> Codex 必须先审计再行动，不得把历史日志自动视为当前源码对应的最新结果。

## 1. 项目目标与需求

完成《数字逻辑与计算机组成》实验四：**32 位 ALU 设计与 FPGA 上板验证**。

项目最终应实现并交付：

1.  使用 Verilog 实现 32 位算术逻辑单元（ALU）。
2.  按课程要求构建 CLU4、CLA4、CLA16、32 位加减法器和 ALU
    datapath，保留指定模块层次和接口。
3.  使用 Vivado 自带 XSim 完成核心仿真和板级逻辑仿真。
4.  使用 Vivado
    完成综合（Synthesis）、布局布线/实现（Implementation）、时序与 DRC
    检查。
5.  生成适用于目标 FPGA 的 Bitstream。
6.  在确认开发板型号、PCB 修订版本、FPGA 器件和 XDC 引脚约束匹配后，通过
    JTAG 临时配置 FPGA。
7.  按实验手册完成人工上板功能测试。
8.  交付两份中文 Markdown 文档：
    -   `docs/项目构建与运行报告.md`
    -   `docs/项目原理与代码解析.md`

ALU
支持的操作、控制码、标志位定义和开发板交互方法，必须以本地实验手册、模块
README、测试平台和实际源码为准，不得仅凭通用教材推断。

## 2. 本地工程环境

  项目                         当前信息
  ---------------------------- --------------------------------------------------
  操作系统                     Windows
  终端                         PowerShell
  本地实验工程根目录           `E:\projects\github\lab4\lab4`
  Git 工作树根目录（如存在）   `E:\projects\github\lab4`
  Vivado 启动程序              `D:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat`
  Vivado 版本                  2025.2 64-bit
  Vivado Edition               ML Standard
  仿真器                       Vivado 自带 XSim
  工程器件设置                 `xc7a100tfgg484-1`
  设计顶层                     `lab4_top`
  时钟约束                     `clk`，100 MHz，XDC 标注引脚 Y18
  目标板 XDC 注释              `EDK-A7-Minisys-I V3.2-100T`

### 2.1 本机常用命令

``` powershell
cd E:\projects\github\lab4\lab4
$vivado = 'D:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat'
```

Core 仿真：

``` powershell
& $vivado -mode batch -source scripts/run_sim.tcl -tclargs core
```

Board 仿真：

``` powershell
& $vivado -mode batch -source scripts/run_sim.tcl -tclargs board
```

综合、实现和 Bitstream 构建：

``` powershell
& $vivado -mode batch -source scripts/run_build.tcl -tclargs 4 2>&1 | Tee-Object .\build.log
```

最后的 `4` 是并行作业数。构建脚本不负责烧录 FPGA。

## 3. 开发板与 JTAG 信息

用户已连接开发板，并通过 Vivado Hardware Manager 成功执行 JTAG 扫描。

历史扫描结果（来自 `board_info.log`）：

  字段                 读取结果
  -------------------- ----------------------------------------------
  JTAG target          `localhost:3121/xilinx_tcf/Xilinx/1234-tulA`
  Target identifier    `jsn-TUL-1234-tulA`
  FPGA device          `xc7a100t_0`
  JTAG PART            `xc7a100t`
  IDCODE               `13631093`
  IR_LENGTH            `6`
  UNKNOWN_DEVICE       `0`
  扫描到的 FPGA 数量   1

开发板照片中可辨认品牌/系列为 E-ELEMENTS MINISYS / Artix-7，FPGA
芯片丝印可辨认为 `XC7A100T`、`FGG484`。

**仍需核实：** - PCB 的准确型号和硬件修订版本。 - 是否确实为 XDC
注释中的 `EDK-A7-Minisys-I V3.2-100T`。 - 芯片完整速度等级是否与 `-1`
一致（JTAG 的 `xc7a100t` 读数本身不提供完整封装和速度等级信息）。 - XDC
中每一个按键、拨码开关、LED、数码管引脚及 I/O 电压标准是否适用于当前 PCB
版本。

不能仅凭 FPGA 家族/芯片型号相同就断言外围引脚约束一定匹配。JTAG
扫描成功也不能证明 PCB 修订版本。

## 4. 工程目录与关键文件

以下为预期结构，Codex 必须检查本机实际文件和内容，不要仅按文件名推断：

``` text
lab4/
├── README.md
├── rtl/
│   ├── core/
│   │   ├── clu4.v
│   │   ├── cla4.v
│   │   ├── cla16.v
│   │   ├── addsub32.v
│   │   ├── alu_datapath.v
│   │   ├── alu_core.v
│   │   └── README.md（如存在）
│   └── board/
│       ├── lab4_top.v
│       ├── button_clean.v
│       ├── hex8_scan.v
│       └── preset_vectors.v
├── sim/
│   ├── tb_alu_core.v
│   └── tb_lab4_top.v
├── constraints/
│   └── lab4.xdc
├── scripts/
│   ├── create_project.tcl
│   ├── run_sim.tcl
│   └── run_build.tcl
├── docs/
│   ├── 实验四_上板实验.pdf
│   ├── vivado安装教程.pdf
│   └── 原理图及其他资料
└── build/
    ├── lab4.xpr
    ├── lab4.runs/
    └── reports/
```

### 4.1 核心模块预期职责

-   `clu4.v`：4 位先行进位逻辑单元，计算位进位和组进位信号。
-   `cla4.v`：4 位先行进位加法器，调用 CLU4。
-   `cla16.v`：由四个 CLA4 组合成 16 位先行进位加法器。
-   `addsub32.v`：由两个 CLA16 组成 32 位加减法器，并生成标志位。
-   `alu_datapath.v`：根据控制信号选择 ALU 操作及结果。
-   `alu_core.v`：课程提供的核心接口适配模块，是否有特殊逻辑以源码为准。

### 4.2 板级模块预期职责

-   `lab4_top.v`：开发板顶层，连接输入、运算核心和输出。
-   `button_clean.v`：按键消抖/单次触发等逻辑，具体行为以源码为准。
-   `hex8_scan.v`：八位数码管扫描和显示。
-   `preset_vectors.v`：预置测试数据或测试向量。

### 4.3 仿真、约束和脚本

-   `tb_alu_core.v`：核心运算测试平台。
-   `tb_lab4_top.v`：板级逻辑测试平台。
-   `lab4.xdc`：引脚分配、电气标准和时钟约束。
-   `create_project.tcl`：创建/打开 Vivado
    工程并加入设计源、仿真源和约束。
-   `run_sim.tcl`：运行 core 或 board 仿真。
-   `run_build.tcl`：运行综合、实现、报告生成和 Bitstream 生成。

## 5. 已完成工作与结果证据

以下数据来自用户本机运行日志。Codex
必须核对这些文件是否存在、时间戳是否与当前源码匹配。

### 5.1 Core 核心仿真：已通过

日志输出：

``` text
PASS: ALL CORE TESTS PASSED (18160 checks)
LAB4_SIM_STATUS=PASS checks=18160 errors=0
```

日志中的覆盖摘要：

``` text
CLU4=512 exhaustive
CLA4=512 exhaustive
CLA16=4 directed+512 random
ADDSUB32=1024 random
ALU=20 fixed+1024 random+12 invalid
```

### 5.2 Board 板级逻辑仿真：已通过

日志输出：

``` text
PASS: BOARD LOGIC TESTS PASSED (166 checks)
LAB4_SIM_STATUS=PASS checks=166 errors=0
```

该结果表示板级 RTL
在测试平台中的仿真通过，不代表实体开发板已经完成验收。

### 5.3 FPGA 综合、实现和 Bitstream：已完成

用户运行的构建命令：

``` powershell
cd E:\projects\github\lab4\lab4
& 'D:\AMDDesignTools\2025.2\Vivado\bin\vivado.bat' -mode batch -source scripts/run_build.tcl -tclargs 4 2>&1 | Tee-Object .\build.log
```

`build.log` 中的关键结果：

-   `synth_design completed successfully`
-   `SYNTH_STATUS=synth_design Complete!`
-   `route_design completed successfully`
-   路由结束时 `Failed Nets = 0`、`Unrouted Nets = 0`
-   DRC：`0 Errors`
-   `write_bitstream completed successfully`
-   `Bitgen Completed Successfully`
-   `IMPL_STATUS=write_bitstream Complete!`
-   `IMPL_PROGRESS=100%`
-   `WORST_SETUP_SLACK_NS=4.912`
-   `WORST_HOLD_SLACK_NS=0.148`

Bitstream 路径：

``` text
E:\projects\github\lab4\lab4\build\lab4.runs\impl_1\lab4_top.bit
```

日志路径：

``` text
E:\projects\github\lab4\lab4\build.log
```

报告目录：

``` text
E:\projects\github\lab4\lab4\build\reports
```

预期报告文件： - `synthesis_utilization.rpt` -
`synthesis_timing_summary.rpt` - `implementation_utilization.rpt` -
`implementation_timing_summary.rpt` - `implementation_drc.rpt`

### 5.4 已知警告与限制

1.  综合日志提示 `sw[23]` 未连接或无负载，相关寄存器被裁剪；XDC 注释称
    `sw[23]` 为 reserved。请检查 RTL、XDC
    和实验手册并解释其影响，不要擅自修改端口或约束。
2.  Vivado 启动时出现若干本机 Board Store 中其他板卡定义不可用的
    WARNING，以及 `Board part '' ... is not found`。当前工程使用显式
    PART `xc7a100tfgg484-1`，综合与实现仍成功。区分这些环境警告与
    DRC/实现错误。
3.  当前 XDC 有 100 MHz 主时钟约束，但没有为所有外部输入/输出定义完整
    I/O delay。WNS/WHS 只代表当前约束集合下的结果，不能宣称完整板级 I/O
    时序签核。
4.  Bitstream 已生成；**尚无证据表明已经执行 FPGA
    下载，也没有实体开发板功能测试结果。**
5.  初次编译曾因五个 Verilog 文件第一行缺少 `` `timescale ``
    的反引号而失败。该问题在远程代码中修复，之后本机 core/board
    仿真和构建均成功。请核对本地源码，不要把旧错误版本覆盖回来。
6.  先前构建日志显示综合和实现无 Critical Warnings/Errors，但存在普通
    WARNING；文档应如实说明，不得简单写成"零警告"。

## 6. Codex 工作边界

用户明确要求：**Codex 接管后续本地工作，不再需要用户管理 GitHub。**

-   只在 `E:\projects\github\lab4\lab4` 本地工程中工作。
-   不访问 GitHub，不执行 `git fetch`、`git pull`、`git push`，不创建
    PR，不要求用户同步远程分支。
-   可以只读执行 `git status`
    检查本地未提交修改；不得丢弃、重置或覆盖用户更改。
-   不删除课程源码、测试平台、实验资料、日志和报告。
-   不修改测试期望值来掩盖错误。
-   不擅自改变模块接口、端口位宽、顶层名和 ALU 控制码。
-   不擅自修改 XDC 引脚、I/O 标准和时钟约束。
-   不猜测按键、拨码开关、数码管操作方式，必须阅读实验手册和原理图。
-   不写入或擦除板载 Flash，不执行任何持久化配置存储器操作。
-   `program_hw_devices` 是真实硬件操作。只有在板卡 PCB 版本、XDC
    和实验手册有充分证据匹配后，才准备执行；执行前必须向用户展示 JTAG
    target、FPGA PART、Bitstream
    完整路径和操作影响，并等待用户明确确认。
-   未实际执行的工作必须标记为"待完成"；不得把仿真通过或 Bitstream
    生成成功写成实体板卡验收通过。
-   所有报告内容以真实源码、实验手册、日志和报告为依据；不确定内容标注"待核实"。

## 7. Codex 必须检查和阅读的文件

先检查存在性，再逐项阅读：

1.  `README.md`
2.  `rtl/core/README.md`（如存在）
3.  `docs/实验四_上板实验.pdf`
4.  `docs/vivado安装教程.pdf`
5.  `docs/` 下全部原理图、原理图说明及其他实验资料
6.  `rtl/core/` 下全部 Verilog 文件
7.  `rtl/board/` 下全部 Verilog 文件
8.  `sim/` 下全部测试平台和辅助文件
9.  `constraints/lab4.xdc` 及相关说明
10. `scripts/create_project.tcl`
11. `scripts/run_sim.tcl`
12. `scripts/run_build.tcl`
13. `build.log`
14. `build/reports/` 下全部报告
15. `build/lab4.runs/synth_1/runme.log`（如存在）
16. `build/lab4.runs/impl_1/runme.log`（如存在）
17. `board_info.log`、`program.log`（如存在）
18. 用户提供的开发板照片（若未保存在项目中，向用户索取或让用户在 Codex
    对话中附加）。

PDF
无法读取时，必须说明无法读取的具体文件，并尝试本机可用的文本提取工具；不得假装已阅读。

## 8. 后续工作路线

### 阶段 A：本地工程审计（先做，不修改 RTL/XDC）

1.  检查工作目录、文件树、源文件、脚本、工程、日志和报告。
2.  核对五个核心模块与当前本地源码。
3.  核对 Bitstream、报告是否存在，以及文件时间是否晚于源码修改。
4.  阅读实验手册、原理图、XDC，梳理实际板级接口。
5.  汇总已完成、未完成、警告、风险和需要用户确认的事项。
6.  如果当前源码与日志一致且产物完整，不要无意义地重复完整构建。

### 阶段 B：开发板与 XDC 匹配核实

1.  从实验手册、原理图、XDC 注释、PCB
    丝印/背面标签确认板卡型号和修订版本。
2.  核对 FPGA
    完整器件、封装、速度等级、时钟、按键、拨码、LED、数码管引脚和 I/O
    电压标准。
3.  如果仍无法确认，向用户提出具体核实请求并暂停烧录；不要猜测。

### 阶段 C：烧录前检查与实体测试

1.  确认 Bitstream 确实由当前源码和当前 XDC 构建生成。
2.  确认 Bitstream 文件存在且路径准确。
3.  仅准备 JTAG 临时配置 FPGA；禁止操作 Flash。
4.  执行 `program_hw_devices` 前，向用户展示 JTAG target、FPGA
    PART、Bitstream 路径和操作影响，等待明确确认。
5.  用户确认后才执行烧录。
6.  按实验手册操作开发板，记录每项测试的输入、控制码、预期结果、实际显示和异常。
7.  只有实际观察到结果后才能写"实体上板测试通过"。

### 阶段 D：文档交付

必须在 `docs/` 下创建两份中文 Markdown 文档。

#### 文档一：`docs/项目构建与运行报告.md`

简洁、专业、可复现，至少包含：

1.  项目目标和功能范围。
2.  开发环境、Vivado 版本、FPGA 器件和开发板信息。
3.  工程目录与主要文件构成。
4.  从 Verilog 源码到 Bitstream 的构建过程。
5.  可直接复制的 PowerShell 命令：Core 仿真、Board
    仿真、综合/实现/Bitstream 构建。
6.  Core/Board 测试结果、测试数量和日志证据。
7.  综合、实现、资源利用率、DRC、路由、WNS/WHS 结果。
8.  Bitstream 准确路径。
9.  JTAG 烧录步骤和板上运行方式（仅写实验手册确认且实际完成的部分）。
10. 当前结果、未完成事项、警告、限制和风险。
11. 从本地工程复现构建的步骤。

不得把仿真通过写成实体上板通过；不得将未执行的操作写成已完成。

#### 文档二：`docs/项目原理与代码解析.md`

面向学过数字逻辑基础、正在学习 Verilog
的本科生。必须阅读真实源码，逐模块解释：

1.  系统总体架构、模块依赖关系图和完整数据流。
2.  CLU4：P、G、h
    的定义（以实验要求和源码为准）、展开进位方程、C1～C4、Gg、Pg。
3.  CLA4：端口、位传播/产生信号、求和、进位输出，以及如何例化 CLU4。
4.  CLA16：四个 CLA4 的连接方式、组间先行进位逻辑和最终输出。
5.  addsub32：两个 CLA16 如何组成 32 位加法器；SUB 如何控制 B
    取反和初始进位；CF、SF、OF、ZF 在本项目中的精确定义。
6.  alu_datapath：ALUctr 控制码、六种操作、加减法器复用、MUX
    结果选择、slt/sltu 的实际实现。
7.  alu_core：接口适配和信号连接。
8.  lab4_top：板级顶层、输入装载、操作数寄存、控制信号和结果输出。
9.  button_clean、hex8_scan、preset_vectors：各自代码职责、时序逻辑及与顶层的连接。
10. 每个模块的端口方向、位宽、输入输出和上下游模块。
11. 结合本项目代码解释 Verilog
    语法：module、input/output、wire/reg、assign、always
    @*、case、模块例化、位选、拼接、参数等。
12. 测试平台怎样驱动输入、检查输出；18160 项和 166 项分别覆盖什么。
13. 从拨码/按键输入到 ALU 运算，再到数码管/LED 显示的完整过程。
14. 对关键代码逐段解释，尽可能标注文件名和真实行号。
15. 解释项目实现过程中修改了哪些代码、各自作用、遇到过什么问题以及如何修复。

技术定义必须与项目实际代码和实验手册一致。若源码与实验手册冲突，列出冲突并说明依据，不要静默修正。无法确定的内容标注"待核实"。

## 9. 最终验收与汇报

完成后向用户汇报：

-   已审计的文件和结论。
-   当前项目状态。
-   板卡与 XDC 是否确认匹配。
-   是否已烧录、实体测试是否完成。
-   新增/修改文件清单及原因。
-   Core、Board、综合、实现、时序和 DRC 结果及证据路径。
-   Bitstream 的准确路径。
-   两份报告的准确路径。
-   未解决问题和风险。
-   用户下一步需要执行的最少人工操作。

**不得把"仿真通过"或"Bitstream 生成成功"表述为"实体板卡验收通过"。**
