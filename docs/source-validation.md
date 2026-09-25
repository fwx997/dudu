# `sourceModelList+3.xbs` 验证记录

测试文件：`D:\Downloads\sourceModelList+3.xbs`

## 输出文件

- 原文件备份：`D:\Downloads\sourceModelList+3.before-cleanup.xbs`
- 精简文件：`D:\Downloads\sourceModelList+3.xbs`
- 精简副本：`D:\Downloads\sourceModelList+3.compact.xbs`
- 精简报告：`D:\Downloads\sourceModelList+3.compact.report.json`
- 严格已验证包：`D:\Downloads\sourceModelList+3.verified.xbs`
- Swift 运行时包：`D:\Downloads\sourceModelList+3.runtime.xbs`

## 处理结果

| 项目 | 数量 |
|---|---:|
| 原始站点 | 3355 |
| 原始启用站点 | 935 |
| 精简后站点 | 877 |
| 删除禁用站点 | 2419 |
| 删除硬失败/缺请求配置站点 | 59 |

精简包已重新解密校验，顶层对象为 877 个站点，XBS 编码可读。精简包约 5.7 MB，原文件约 22.4 MB。

另外生成了两个分级包：

- `verified`：225 个本次请求实际返回成功的站点，约 2.0 MB；
- `runtime`：296 个实际成功站点，加上 71 个需要 `@js:`、由 Swift JavaScriptCore 支持的站点，约 2.5 MB。

当前覆盖原文件名的 `sourceModelList+3.xbs` 是 877 个站点的保守精简包；需要更少、更确定的书源时可直接使用 `verified` 包。

## 并发验证结果

验证分成文本和媒体两路，每路最多 12 个并发请求，单站点超时约 12 秒。

文本/小说启用站点 765 个：

- 首次探测成功 50
- 二次重试成功 135
- HTTP 错误/需要重试 84
- DNS/连接失败 125
- 超时 84
- 空结果 31
- 规则解析失败 112
- 明确缺少请求配置 28
- `@js:` 或复杂规则 26

媒体启用站点 171 个：

- 成功 40
- 空结果 5
- `@js:` 请求（由 Swift JavaScriptCore 支持）71
- 明确缺少请求配置 7
- 仅有 requestFunction/requestJavascript 2
- 硬失败 15
- 需要重试或环境不确定 28

## 删除规则

精简时只删除以下情况：

- 原本禁用的站点；
- 明确缺少请求配置且没有可替代请求函数的站点；
- 明确 DNS 失败、连接拒绝、404/410 的站点；
- 验证报告明确标记为硬失败的媒体站点。

403、412、429、SSL、超时、空结果和 `@js:` 规则全部保留，因为一次外部探测不能证明它们永久失效，且 Swift 端具备 JavaScriptCore 执行能力。

重新生成精简包时使用：

```text
python dudu/tools/compact_xbs.py <input.xbs> <output.xbs> \
  --backup <backup.xbs> --enabled-only \
  --report validation_text.jsonl \
  --report validation_text_refined.jsonl \
  --report validation_media.jsonl \
  --report validation_media_refined.jsonl
```
