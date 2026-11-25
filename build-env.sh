#!/bin/bash
# macOS OpenWrt Build Environment Setup for Jesswjj
if [ ! -d "/Users/jesswu/Gitrepos/openwrt-env/immortalwrt-mt798x" ]; then
    hdiutil attach /Users/jesswu/Gitrepos/OpenWrtBuild.sparseimage -mountpoint /Users/jesswu/Gitrepos/openwrt-env
fi
export PATH="/opt/homebrew/opt/coreutils/libexec/gnubin:/opt/homebrew/opt/findutils/libexec/gnubin:/opt/homebrew/opt/gnu-tar/libexec/gnubin:/opt/homebrew/opt/gnu-sed/libexec/gnubin:/opt/homebrew/opt/gawk/libexec/gnubin:/opt/homebrew/opt/grep/libexec/gnubin:/opt/homebrew/opt/gnu-getopt/bin:/opt/homebrew/opt/make/libexec/gnubin:/opt/homebrew/opt/gpatch/libexec/gnubin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export FORCE_UNSAFE_CONFIGURE=1
export GIT_AUTHOR_NAME="Jesswjj"
export GIT_AUTHOR_EMAIL="317417277@qq.com"
export GIT_COMMITTER_NAME="Jesswjj"
export GIT_COMMITTER_EMAIL="317417277@qq.com"
export DOWNLOAD_MIRROR="https://sources-cdn.immortalwrt.org;https://sources.openwrt.org;https://sources.cdn.openwrt.org"
echo "✅ OpenWrt macOS Build Environment Activated (Cores: $(nproc))"
