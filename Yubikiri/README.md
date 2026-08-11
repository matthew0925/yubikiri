# Yubikiri iOS (MVP)

## セットアップ

```bash
brew install xcodegen   # 未導入の場合
cd Yubikiri
xcodegen generate
open Yubikiri.xcodeproj
```

`Yubikiri.xcodeproj` はコミット対象外（`project.yml` から `xcodegen generate` で再生成する運用）。

## 現状の実装範囲

- データモデル（SwiftData）: `Case`（案件）/ `Entry`（記録）
- `HashingService`: 記録内容のSHA-256計算（改行コード等を正規化してから算出）
- SwiftUI画面: 案件一覧・新規案件・案件詳細・新規記録・記録詳細
- `OpenTimestampsClient`: 外部アンカリング用のプロトコル定義のみ（未実装、次のマイルストーン）

## テスト

```bash
xcodebuild -project Yubikiri.xcodeproj -scheme Yubikiri \
  -destination 'platform=iOS Simulator,name=iPhone 17' test
```
