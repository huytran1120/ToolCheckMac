# 发布说明

## 版本号

当前版本号在 `Sources/App/Info.plist` 中维护：

- `CFBundleShortVersionString`: 对外版本号，例如 `1.0`
- `CFBundleVersion`: 构建号，例如 `1`

发布前请同步更新 `scripts/build_and_notarize.sh` 中的 `VERSION`。

## 本地打包

```bash
./scripts/build_and_notarize.sh
```

输出文件：

```text
~/Desktop/ToolCheckMacBook-1.2.dmg
```

## 签名和公证

如需正式分发，需要：

1. Apple Developer 账号
2. 钥匙串中安装 `Developer ID Application` 证书
3. 保存 notarytool 凭证

```bash
xcrun notarytool store-credentials "toolcheckmacbook-notary" \
  --apple-id "YOUR_APPLE_ID" \
  --team-id "YOUR_TEAM_ID" \
  --password "APP_SPECIFIC_PASSWORD"
```

可选环境变量：

```bash
export TOOLCHECKMACBOOK_SIGN_ID="Developer ID Application: Your Name (TEAMID)"
export TOOLCHECKMACBOOK_NOTARY_PROFILE="toolcheckmacbook-notary"
```

## GitHub Release

```bash
gh release create v1.2 ~/Desktop/ToolCheckMacBook-1.2.dmg \
  --title "ToolCheckMacBook 1.2" \
  --notes "First release: Local Mac hardware check, interactive tests, report export."
```

## 发布后检查

- Release 页面能看到 DMG 附件
- 下载 DMG 后 `hdiutil verify` 通过
- App 可以启动并完成首页扫描
- README 中的安装和使用说明仍然准确

## 用户安装疑难排查

如果用户首次打开 ad-hoc 或未公证版本时被 macOS Gatekeeper 拦截，优先建议右键点击 `ToolCheckMacBook.app`，选择“打开”。

如需在系统设置中显示“任何来源”选项，可在终端执行：

```bash
sudo spctl --master-disable
```

如果提示 App“已损坏，无法打开”，可在确认 App 来源可信、且 App 已放入 `/Applications` 后执行：

```bash
sudo xattr -rd com.apple.quarantine /Applications/ToolCheckMacBook.app
```
