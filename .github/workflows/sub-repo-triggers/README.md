# 子仓库 CI 触发配置

## 概述

当子仓库（arceos、arm-gic、axcpu 等）提交 PR 时，需要在 StarryOS 的完整环境中测试。这些配置文件应该放在**子仓库**中，用于触发 StarryOS 的 CI。

## 使用方法

### 1. 在子仓库中添加 workflow

将对应的 workflow 文件复制到子仓库的 `.github/workflows/` 目录：

```bash
# 例如：在 arceos 仓库中
cp trigger-starryos-ci-arceos.yml /path/to/arceos/.github/workflows/trigger-starryos-ci.yml
```

### 2. 配置 GitHub Token

在子仓库的 Settings → Secrets and variables → Actions 中添加：

- `STARRYOS_CI_TOKEN`: 有权限触发 StarryOS workflow 的 Personal Access Token
  - 需要 `repo` 权限
  - 需要 `workflow` 权限

### 3. 触发条件

- **分支**: 只在 `dev` 分支的 PR 触发（子仓库的主开发分支）
- **事件**: `pull_request` (opened, synchronize, reopened)

### 4. 触发流程

```
子仓库 PR (dev 分支)
  ↓
触发 workflow
  ↓
repository_dispatch → StarryOS
  ↓
StarryOS CI 运行
  - repo sync (所有子项目默认分支)
  - 替换触发的子项目到 PR commit
  - bitbake starry-ci-image
  - QEMU 测试
```

## 支持的子仓库

从 `base.xml` 获取：

| 仓库 | 路径 | 默认分支 |
|------|------|---------|
| arceos | StarryOS/arceos | dev |
| arm-gic | StarryOS/local_crates/arm-gic | main |
| axcpu | StarryOS/local_crates/axcpu | dev |
| axdriver_crates | StarryOS/local_crates/axdriver_crates | dev |
| axplat_crates | StarryOS/local_crates/axplat_crates | dev |
| page_table_multiarch | StarryOS/local_crates/page_table_multiarch | dev |
| kernel_guard | StarryOS/local_crates/kernel_guard | main |
| fdtree-rs | StarryOS/local_crates/fdtree-rs | main |
| axplat-aarch64-crosvm-virt | StarryOS/local_crates/axplat-aarch64-crosvm-virt | main |

## 工作流程示例

### arceos 提交 PR

1. 开发者在 `arceos` 仓库的 `dev` 分支提交 PR
2. `trigger-starryos-ci.yml` 触发
3. 向 StarryOS 发送 `repository_dispatch` 事件：
   ```json
   {
     "event_type": "sub-repo-pr",
     "client_payload": {
       "trigger_repo": "arceos",
       "trigger_sha": "abc123...",
       "trigger_ref": "refs/pull/42/head"
     }
   }
   ```
4. StarryOS CI 运行：
   - repo sync 所有子项目（arceos 使用默认 dev 分支）
   - 检测到 `trigger_repo=arceos`
   - 在 `StarryOS/arceos` 中执行 `git checkout abc123...`
   - 继续构建和测试

## 注意事项

1. **Token 安全**: 
   - 使用 organization secret 或 repository secret
   - 定期轮换 token
   - 使用最小权限原则

2. **分支保护**:
   - 建议为 `dev` 分支设置 branch protection
   - 要求 CI 通过才能合并

3. **并发控制**:
   - StarryOS CI 使用 `concurrency` 避免同一 PR 的多次运行
   - 同一子仓库的不同 PR 会排队执行

4. **调试**:
   - 查看 StarryOS 的 Actions 页面查看 CI 结果
   - 检查 artifacts 中的详细日志
