# 运算核心

依次补齐clu4、cla4、cla16、addsub32、alu_datapath中的TODO，alu_core接口适配已提供。cla16的最低4位和addsub32的低16位实例可作连接示范。新增实例后删除对应PLACEHOLDERS零驱动，组合case中的安全default保留。

| 模块 | 输入 | 输出 |
| --- | --- | --- |
| clu4 | P[3:0]、G[3:0]、C0 | C[4:1]、Gg、Pg |
| cla4 | A[3:0]、B[3:0]、C0 | S[3:0]、C4、Gg、Pg |
| cla16 | A[15:0]、B[15:0]、C0 | S[15:0]、C16、Gg、Pg |
| addsub32 | A[31:0]、B[31:0]、SUB | F[31:0]、CF、OF、SF、ZF |
| alu_datapath | A[31:0]、B[31:0]、ALUctr[3:0] | RESULT、ZERO及调试标志 |
| alu_core | A[31:0]、B[31:0]、ALUctr[3:0] | RESULT[31:0]、ZERO |

位级约定p=A或B、g=A与B、h=A异或B。求和使用h与输入进位，不能把p代作h。CF在加法时表示进位、减法时表示借位；OF表示有符号溢出。slt使用内部算术SF XOR OF，sltu使用减法CF，比较均输出32位0或1。

ALUctr为0/add、2/slt、3/sltu、6/or、8/sub、F/srcB。FLAGS_VALID只对0/2/3/8为1；ZERO=内部算术ZF，不能替换为RESULT的零检测。逻辑或、传送B及未用控制的观测F、四标志与ZERO为0。

波形和板上操作见docs/实验四_上板实验.pdf，原理图见docs/原理图。
