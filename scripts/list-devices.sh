#!/bin/bash
# 列出已连接 iPhone 的 UDID，用于在 developer.apple.com 登记设备
echo "Connected devices:"
xcrun xctrace list devices 2>/dev/null || xcrun simctl list devices available 2>/dev/null
echo ""
echo "或在 Finder 中选中 iPhone，点击序列号区域切换显示 UDID。"
