---
title: 'RV64ILP32 裸机工具链与 profile 现已可用'
---

# RV64ILP32 裸机工具链与 profile 现已可用

为了您的跟踪前沿开发动态方便，RuyiSDK 团队现已打包了 RV64ILP32 这一实验性 ABI 的裸机工具链供您使用。
由于是裸机工具链，此工具链不自带 sysroot，且未开启 multilib：可用的 ABI 为 `ilp32d`。

## 使用示例

给定如下的 C 程序 `test.c`：

> long long add(long long \*a, long long b) { return \*a + b; }
>
> void check(int);
>
> void checkSizes(void) {
>    check(sizeof(int));
>    check(sizeof(long));
>    check(sizeof(long long));
>    check(sizeof(void \*));
> }

使用相应的工具链包与 profile，我们将可编译出符合 RV64ILP32 ABI 的目标代码：

> ruyi update
>
> ruyi install gnu-plct-rv64ilp32-elf
>
> ruyi venv -t gnu-plct-rv64ilp32-elf --without-sysroot baremetal-rv64ilp32 /tmp/venv
>
> source /tmp/venv/bin/ruyi-activate
>
> /tmp/venv11/bin/riscv64-plct-elf-gcc -O2 -c -o test.o test.c

检查目标代码是否符合预期：

> $ riscv64-plct-elf-readelf -h test.o | grep 32
>
>   Class:                             ELF32
>
>   Flags:                             0x25, RVC, X32, double-float ABI

> $ riscv64-plct-elf-objdump -dw test.o | grep a0
>
>    0:   6108                    ld      a0,0(a0)
>
>    2:   952e                    add     a0,a0,a1
>
>    8:   4511                    li      a0,4
>
>   14:   4511                    li      a0,4
>
>   1e:   4521                    li      a0,8
>
>   2a:   4511                    li      a0,4

可见，此工具链确实生成了指针宽度为 32 位，但利用了 RV64 能力的目标代码。
