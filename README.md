# ponwrt-builder

在 GitHub Actions 上编译 [pbs05/ponwrt](https://github.com/pbs05/ponwrt) 的 **Nokia XG-040G-MD**（Airoha AN7581）固件和**全部内核模块**。做法学 [sbwml/builder](https://github.com/sbwml/builder)：固件和 kmod 分开编、分开放。

| 工作流 | 做什么 | 产物 |
|---|---|---|
| **Core** | 每天看一次上游，内核相关文件有变化就编：内核 + `CONFIG_ALL_KMODS=y` | Release `kmod` 里的 tarball；推送到 [ponwrt-core](https://github.com/r1172464137/ponwrt-core) 软件源（GitHub Pages） |
| **Firmware** | 编 `nokia_xg-040g-md-ubi` 和 `-ubi-usb-sfp` 两个变体 | 固件 Release；固件里预置 ponwrt-core 软件源 |

## 为什么固件和 kmod 能分开编

OpenWrt 默认按内核 `.config` 算 vermagic，选的包不同，vermagic 就不同，单独编的 kmod 装不上。这里把 vermagic 固定为：

```
md5( 内核源码 tarball 的 hash + target/linux/airoha 与 target/linux/generic 全部文件内容的 hash )
```

只和「内核源码 + 内核补丁」有关。ponwrt 常在内核版本不变时改 airoha 补丁，补丁一变 vermagic 就变，不会把新旧 kmod 混在一起。见 `scripts/prepare.sh`。

## 目录

- `scripts/prepare.sh`：在 ponwrt 源码根目录运行，装 feeds、固定 vermagic、生成配置（只选 XG-040G-MD 两个变体）。
- `config/core.config`、`config/firmware.config`：两种构建在 ponwrt 默认配置之上追加的选项。
- `keys/ponwrt-builder.pem`：apk 索引签名公钥。

## Secrets

- `APK_PRIVATE_KEY`：apk 签名私钥（EC P-256）。
- `CORE_DEPLOY_KEY`：推送 ponwrt-core 的部署密钥（私钥）。
