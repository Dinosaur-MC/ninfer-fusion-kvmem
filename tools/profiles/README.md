# NInfer 启动 profile

两个已验证的启动档位，统一由 `ninfer-serve.exe` 启动 27B ternary + MTP 模型。
两者共用：设备 KV 池 4096 token、64 token/页、rk4v4-e8、prefill chunk 512、
`--max-concurrency 1` + `--max-shared-prefixes 0`（KVMem 环的硬约束）、
MTP（draft 1 / window 8）、`--default-max-tokens 32768`。

| profile | 逻辑上下文 | host KV | host state 槽位 | private continuations | 适用场景 |
|---|---:|---:|---:|---:|---|
| `start-64k.sh` | 65,536 | 4,096 MiB | 1 | 2 | 日常与 ≤40K 输入；速度最快、尾延迟最稳 |
| `start-128k.sh` | 131,072 | 8,192 MiB | 4 | 8 | 60K–120K 长文档；prefill 更慢且波动更大 |

## 用法

```bash
bash tools/profiles/start-64k.sh
bash tools/profiles/start-128k.sh
```

常用覆盖项（环境变量）：

| 变量 | 默认值 | 说明 |
|---|---|---|
| `NINFER_MODEL` | `/h/Models/LLM/bonsai2_27b_ternary_ptq1_native_mtp.ninfer` | 模型件路径 |
| `NINFER_PORT` | `8091` | 监听端口 |
| `NINFER_RUN_DIR` | `<repo>/.deps/build-89/apps/Release` | 引擎可执行文件目录 |
| `NINFER_LOG_DIR` | `<repo>/.temp/ninfer-analysis/logs/run` | 日志目录 |
| `NINFER_ATTEMPTS` | `5` | 显存预留重试次数 |

仓库在 Windows 上按 `core.fileMode=false` 检出，可执行位不入库；Git Bash 里用 `bash <script>` 调用，Unix 上先 `chmod +x`。

脚本会先结束已运行的 `ninfer-serve.exe`，再循环重试启动，成功后在
`/v1/models` 返回 200 时打印 capacity 行与显存占用。

也可以直接传参：

```bash
bash tools/profiles/start-64k.sh --model /path/to/model.ninfer --port 8091
```

## 实测数据（2026-10-28，同一台 RTX 3090，流式，max_tokens=64）

| 输入 token | 64K profile TTFT / prefill | 128K profile TTFT / prefill |
|---:|---|---|
| 4,418 | 8.05 s / 548.5 tok/s | 9.0 s / 492 tok/s |
| 18,542 | 35.6 s / 520.3 tok/s | 43.2 s / 429 tok/s |
| 37,066 | 80.0 s / 463.2 tok/s | 96.4 s / 384 tok/s（波动大） |
| 64,852 | 248.7 s / 260.7 tok/s | 179.3 s / 361.8 tok/s |
| ~119,700 | 不支持（max_context 65,536） | 411.3 s / 291.3 tok/s（历史实测） |

容量边界：64K profile 接受 64,852 token 的 prepared prompt，约 69K 时报
`context_length_exceeded`；128K profile 约 120K 可用，约 134K 时报错。
两档显存占用都接近 8 GB（7.7–7.8 GB / 8.19 GB），不要与其它 GPU 任务并行。

## 选择建议

- ≤40K：用 `start-64k.sh`，更快更稳。
- 60K–65K：用 `start-128k.sh`；64K profile 在这个区间 prefill 会掉到 220–261 tok/s。
- >65K：只能用 `start-128k.sh`，预期 prefill 300–360 tok/s、TTFT 3–7 分钟。
- 多会话并发会串行排队（单 lane），排队时间计入 TTFT。