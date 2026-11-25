#!/bin/bash
# 在 ponwrt 源码根目录执行：prepare.sh <core|firmware>
# 做三件事：装 feeds、固定 vermagic、生成 .config（只选 XG-040G-MD 两个变体）
set -euo pipefail
MODE=${1:?用法：prepare.sh core|firmware}
B=$(cd "$(dirname "$0")/.." && pwd) # builder 仓库根

./scripts/feeds update -a
./scripts/feeds install -a

# 固定 vermagic（学 sbwml）：kmod 不再随「这次选了哪些包」变，固件和 core 分开编也能互相装。
# 但 ponwrt 常在内核版本不变时改 airoha / generic 补丁，所以把这两个目录的内容也算进去，补丁一变就换一个 vermagic
pv=$(sed -n 's/^KERNEL_PATCHVER:=//p' target/linux/airoha/Makefile)
khash=$(sed -n "s/^LINUX_KERNEL_HASH-$pv\.[0-9]* = //p" "target/linux/generic/kernel-$pv")
[ -n "$khash" ] || { echo "找不到内核 $pv 的 HASH" >&2; exit 1; }
thash=$(find target/linux/airoha target/linux/generic -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum | sha256sum | cut -d' ' -f1)
printf '%s %s\n' "$khash" "$thash" | md5sum | cut -d' ' -f1 >.vermagic
sed -i 's|^\(\t\)grep .=\[ym\]. $(LINUX_DIR)/.config.set .*> $(LINUX_DIR)/.vermagic$|\1cp $(TOPDIR)/.vermagic $(LINUX_DIR)/.vermagic|' include/kernel-defaults.mk
grep -q 'cp $(TOPDIR)/.vermagic $(LINUX_DIR)/.vermagic' include/kernel-defaults.mk || { echo "vermagic 没改上：include/kernel-defaults.mk 变了" >&2; exit 1; }
echo "kernel $pv.$(sed -n "s/^LINUX_VERSION-$pv = \.//p" "target/linux/generic/kernel-$pv") vermagic $(cat .vermagic)"

# 配置：ponwrt 自己的 an7581 + release 配置，去掉所有设备，只留 XG-040G-MD 两个变体，再叠本模式的配置
cat configs/an7581.config configs/release.config >.config
sed -i '/_DEVICE_/d; /^CONFIG_PACKAGE_u-boot-an7581_/d; /^# CONFIG_PACKAGE_u-boot-an7581_/d' .config
cat >>.config <<'EOF'
CONFIG_TARGET_MULTI_PROFILE=y
CONFIG_TARGET_PER_DEVICE_ROOTFS=y
CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi=y
CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi-usb-sfp=y
EOF
# ponwrt 的配置是完整 .config，显式写了几百行「kmod-xxx is not set」，会压过 ALL_KMODS：core 模式先删掉
[ "$MODE" = core ] && sed -i '/^# CONFIG_PACKAGE_kmod-.* is not set$/d' .config
cat "$B/config/$MODE.config" >>.config
make defconfig >/dev/null
if [ "$MODE" = core ]; then
	n=$(grep -c '^CONFIG_PACKAGE_kmod-.*=[ym]$' .config)
	echo "选中 kmod：$n 个"
	[ "$n" -gt 500 ] || { echo "kmod 选得太少，ALL_KMODS 没生效？" >&2; exit 1; }
fi
grep -q '^CONFIG_TARGET_DEVICE_airoha_an7581_DEVICE_nokia_xg-040g-md-ubi=y' .config || { echo "设备没选上" >&2; exit 1; }

# apk 签名：和 ponwrt 一样放在源码根目录，构建时自动给索引签名
if [ -n "${APK_PRIVATE_KEY:-}" ]; then
	(umask 077 && printf '%s\n' "$APK_PRIVATE_KEY" >private-key.pem)
	openssl ec -in private-key.pem -pubout -out public-key.pem 2>/dev/null
fi
