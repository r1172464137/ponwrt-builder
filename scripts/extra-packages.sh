#!/bin/bash
# 固件额外带的插件：在 ponwrt 源码根目录、写好 feeds.conf 之后、prepare.sh 之前运行。
# 要选中的包写在 config/firmware.config，两边要一起改。
set -euo pipefail

# feed 形式的插件（不锁版本，跟最新）
echo 'src-git easytier https://github.com/EasyTier/luci-app-easytier.git;main' >>feeds.conf

# 单个包的仓库直接放进 package/
clone() { rm -rf "package/$2" && git clone -q --depth 1 "https://github.com/$1.git" "package/$2"; }
clone r1172464137/luci-app-handoff luci-app-handoff
clone eamonxg/luci-theme-shadcn luci-theme-shadcn
clone eamonxg/luci-theme-aurora luci-theme-aurora
clone eamonxg/luci-app-aurora-config luci-app-aurora-config
# 这个仓库根目录和子目录各有一份同名包，只取子目录那份，免得重名
t=$(mktemp -d)
git clone -q --depth 1 https://github.com/rchen14b/luci-app-airoha-npu.git "$t"
rm -rf package/luci-app-airoha-npu && mv "$t/luci-app-airoha-npu" package/ && rm -rf "$t"
# 子目录那份是按放在 luci feed 里写的（include ../../luci.mk），放到 package/ 下要改成绝对路径
sed -i 's|^include \.\./\.\./luci\.mk$|include $(TOPDIR)/feeds/luci/luci.mk|' package/luci-app-airoha-npu/Makefile
grep -q '^include $(TOPDIR)/feeds/luci/luci.mk$' package/luci-app-airoha-npu/Makefile

# 默认主题 shadcn：主题包各自的 uci-defaults 都会抢 mediaurlbase，这里最后执行，定为 shadcn
mkdir -p files/etc/uci-defaults
cat >files/etc/uci-defaults/99-default-theme <<'EOF'
uci set luci.main.mediaurlbase=/luci-static/shadcn
uci commit luci
exit 0
EOF
