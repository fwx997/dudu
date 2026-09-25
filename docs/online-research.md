# 香色闺阁复刻的公开资料交叉验证

本项目以仓库根目录提供的 `香色闺阁_2.56.1.ipa` 为主证据。公开资料只用于补充书源格式、版本线索和缺失状态，不替代 IPA 中的配置与资源。

| 来源 | 用途 | 结论 |
|---|---|---|
| [woloveloli/StandarReader](https://github.com/woloveloli/StandarReader) | 同版本 IPA 交叉核对 | 仓库公开了 2.56.1 的多个 IPA 变体；本项目不直接依赖远程二进制 |
| [xiaohucode/xiangse](https://github.com/xiaohucode/xiangse) | 内容类型和示例结构 | 按 novel、manga、audio、TV、img 分目录，和原版四色书架类型一致 |
| [haitang-blossoms/xiangsesource](https://github.com/haitang-blossoms/xiangsesource) | `.xbs` / 书源资料 | 可用于书源导入、解析和测试样本的交叉验证 |
| [LinShengwzp/source-reader](https://github.com/LinShengwzp/source-reader) | 书源工作台参考 | 仅作为规则工作台和调试流程参考，不作为香色闺阁 UI 依据 |

## 采用规则

- 版本、菜单顺序、默认值和资源优先读取 IPA 解包结果。
- 公开仓库只有在与本地 IPA 不冲突时才进入实现。
- 网页截图和第三方实现只作为缺失状态的候选证据，必须经过本地截图或行为测试确认。
