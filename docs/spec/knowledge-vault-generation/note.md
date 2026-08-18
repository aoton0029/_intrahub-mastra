# Knowledge Vault Generation コンテキストノート

**作成日**: 2026-08-18
**対象リポジトリ**: `intrahub-mastra`

## 技術スタック

| 項目 | 内容 | 出典 |
|---|---|---|
| 言語 | TypeScript（`"type": "module"`, Node >= 22.13.0） | `package.json` 🔵 |
| フレームワーク | Mastra `@mastra/core` ^1.51.0 | `package.json` 🔵 |
| 主要依存 | `@mastra/mcp` ^1.16.0 / `@mastra/memory` / `@mastra/libsql` / `@mastra/duckdb` / `@mastra/evals` / `@mastra/observability` / `zod` ^4 | `package.json` 🔵 |
| LLMクライアント | `@ai-sdk/openai-compatible`（LiteLLM を OpenAI互換として利用） | `package.json` 🔵 |
| 実行 | `npm run dev`（`mastra dev`）/ `npm run build` | `package.json`・`AGENTS.md` 🔵 |
| テスト | 未設定（`npm test` はエラー終了） | `package.json` 🔵 |
| 実行環境 | IntraHub Docker Compose 上の `mastra` コンテナ（`:4111`）／Debian trixie・RTX 5060 Ti 16GB | PRD §7 🔵 |

## 開発ルール

- **Mastra skill を必ず先に読む**（キャッシュされた API 知識に依存しない） — `AGENTS.md` 🔵
- Agent・Tool・Workflow・Scorer は**すべて `src/mastra/index.ts` へ登録する** — `AGENTS.md` 🔵
- `mastra dev` / `mastra build` を直接叩かず `package.json` のスクリプトを使う — `AGENTS.md` 🔵
- 参照: [Mastra Documentation](https://mastra.ai/llms.txt) / [Skills Discovery](https://mastra.ai/.well-known/skills/index.json)

## 現在の実装状況

`src/` はテンプレート（scaffold）の状態で、Knowledge Vault 関連の実装は存在しない。🔵

```text
src/mastra/index.ts
src/mastra/agents/weather-agent.ts
src/mastra/tools/weather-tool.ts
src/mastra/workflows/weather-workflow.ts
src/mastra/scorers/weather-scorer.ts
```

つまり本要件は**全面的な新規実装**であり、既存実装との差分調整は発生しない。

## 関連実装・外部依存

| 依存先 | 位置づけ | 参照 |
|---|---|---|
| mediavault-mcp | 実装済み。Streamable HTTP `http://mediavault-mcp:8081/mcp`、Bearer 認証。公開ツール17個（読み取り専用8・書き込み9） | `intrahub-mediavault/docs/backend/mediavault-mcp/` 🔵 |
| mediavault-api | mcp の背後。停止していても mcp コンテナは起動を維持する | PRD §7 🔵 |
| LiteLLM | `http://litellm:4000/v1`、外部Dockerネットワーク `llm-net` | PRD §7・README 🔵 |
| Knowledge Vault | `/srv/knowledge`（物理 `/mnt/hdd4/knowledge`）を `/workspace` としてマウント | PRD §7 🔵 |
| knowledge-vault-commit.sh | systemd timer による git commit。復旧手段 | `インフラ設計/デバイス/ミニPC/scripts/` 🔵 |

## 設計文書

- [PRD.md](../../PRD.md) — 本要件の上位文書
- [codex-chat.md](../../codex-chat.md) — Vault構成・ノート種別・frontmatter・Workflow一覧の詳細
- [mediavault-mcp README](../../../../intrahub-mediavault/docs/backend/mediavault-mcp/README.md) — 提供ツール、readonly トークンのスコープ
- [design/mcp-tools.md](../../../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mcp-tools.md) — `outcome` とエラー形式
- [design/mastra-integration.md](../../../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mastra-integration.md) — `get_item_text` 仕様、チャンク連番、`extraction_version`
- [design/api-tool-mapping.md](../../../../intrahub-mediavault/docs/backend/mediavault-mcp/design/api-tool-mapping.md) — D-08〜D-10、失敗クラス対応表

## 注意事項

1. **要件ID体系は継承である** 🔵
   mediavault-mcp 側の設計文書は、旧 `intrahub-mastra/docs/spec/knowledge-vault-generation/requirements.md` の REQ-006 / REQ-016a / REQ-101 / REQ-105 / REQ-202 / REQ-401 / REQ-402 / NFR-031 / NFR-101 / EDGE-006 / TC-004-E02 を名指しで参照している。当該ファイルは現存しないが、**これらの番号と意味は本要件定義で維持する**。番号の意味を変えると MediaVault 側の設計根拠が崩れる。

2. **PRD の版差** 🟡
   mediavault-mcp 側は「intrahub-mastra PRD §15」を参照するが、現行 PRD は §9 までしかない。PRD は書き直されている。MediaVault 側文書のリンク先修正は当該リポジトリの管轄であり、本要件では扱わない。

3. **`get_item_text` は readonly トークンで見えない** 🔵
   mediavault-mcp README L63 が定める `MCP_READONLY_TOKEN` の公開ツールは6個（`health` / `search_library` / `search_external_catalog` / `get_item_context` / `collection_overview` / `list_citations`）で、`get_item_text` は含まれない。`readOnlyHint: true` は付与済み（design/mastra-integration.md L148）だが、トークンスコープには未反映。MVP 中核の章要約が成立しないため、**MediaVault 側へのスコープ拡張依頼が前提条件**。→ [prep.md](prep.md)

4. **書き込み前一致確認は行わない**（PRD からの方針変更） 🔵
   ヒアリングにより、競合検出は Mastra 側で実装せず `knowledge-vault-commit.sh` の git 履歴を事後回復手段とする方針に決定。PRD §7「Mastraの書き込み前一致確認」の記述は本要件で上書きされる。

5. **テスト基盤が無い** 🟡
   `npm test` が未設定のため、受け入れ基準を自動テストとして実行するにはテストランナーの導入が別途必要。
