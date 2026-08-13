# knowledge-vault-generation コンテキストノート

**作成日**: 2026-08-13
**対象リポジトリ**: `intrahub-mastra`（パスはこのリポジトリのルート基準）

## 技術スタック

| 項目 | 内容 |
|---|---|
| ランタイム | Node.js >= 22.13.0、ESM（`"type": "module"`） |
| フレームワーク | `@mastra/core` ^1.51.0 |
| 言語 | TypeScript ^7.0.2 |
| スキーマ | zod ^4.4.3 |
| ストレージ | `@mastra/libsql`（default）+ `@mastra/duckdb`（observability domain）を `MastraCompositeStore` で合成 |
| 可観測性 | `@mastra/observability`（`MastraStorageExporter` / `MastraPlatformExporter` / `SensitiveDataFilter`） |
| 評価 | `@mastra/evals` ^1.5.1 |
| メモリ | `@mastra/memory` ^1.23.0（未使用） |
| LLM接続 | `@ai-sdk/openai-compatible` 経由で LiteLLM（`LITELLM_BASE_URL` / `LITELLM_MASTER_KEY`） |
| MCPクライアント | `@mastra/mcp` **未導入**（MVP-0で追加が必要） |

## 開発ルール（AGENTS.md / CLAUDE.md）

- **Mastra作業の前に必ず `mastra` skill をロードする。** キャッシュされた知識に依存しない（バージョン間でAPIが変わる）。
- すべての agent / tool / workflow / scorer を `src/mastra/index.ts` へ登録する。
- `mastra dev` / `mastra build` を直接叩かず、`package.json` の `dev` / `build` スクリプトを使う。
- 参考: [Mastra Documentation](https://mastra.ai/llms.txt) / [Skills Discovery](https://mastra.ai/.well-known/skills/index.json)

## 既存実装の状況

現在の `src/mastra/` は create-mastra の weather サンプルほぼそのままである。

```text
src/mastra/
├── index.ts                      # Mastra インスタンス。storage/observability/logger は構成済み
├── agents/weather-agent.ts       # 置き換え対象
├── models/litellm.ts             # litellm クライアント + wikiModel のみ
├── scorers/weather-scorer.ts     # 置き換え対象（3 scorer）
├── tools/weather-tool.ts         # 置き換え対象
└── workflows/weather-workflow.ts # 置き換え対象
```

**再利用できるもの**: `index.ts` の storage / observability / logger 構成、`models/litellm.ts` の `createOpenAICompatible` 呼び出しパターン。
**置き換えるもの**: weather 系の agent / tool / workflow / scorer 一式（PRD §22 の構成へ）。

`models/litellm.ts` は `wikiModel`（論理モデル `wiki-model`）1本のみをexportしている。PRD §11 が要求する Agent別モデル割当（`vllm` / `anthropic` / `openai`）に対応していないため、FR-013 対応で最初に手を入れる箇所になる。

## 設計文書

| 文書 | 位置づけ |
|---|---|
| [PRD.md](../../PRD.md) | 要求定義の正本。本要件定義の主たる出典 |
| [codex-chat.md](../../codex-chat.md) | PRDの原案 |
| MediaVault-mcp PRD | `../../intrahub-mediavault/docs/backend/mediavault-mcp/PRD.md` |
| mastra-integration.md | `../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mastra-integration.md` — `get_item_text` の連携設計 |
| mcp-tools.md | `../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mcp-tools.md` — MCPツール仕様 |

`docs/rule`、`docs/rule/kairo`、`docs/rule/kairo/requirements` はいずれも存在しない（追加ルールなし）。

## 環境変数

現状 `.env.example` は2件のみ。本要件で追加が必要な変数は [prep.md](prep.md) を参照。

```dotenv
LITELLM_BASE_URL=http://litellm:4000/v1
LITELLM_MASTER_KEY=
```

その他コード内で参照されている変数: `TURSO_DATABASE_URL`、`TURSO_AUTH_TOKEN`、`DUCKDB_PATH`、`MASTRA_PLATFORM_ACCESS_TOKEN`。

## 注意事項

- **`VLLM_API_KEY` を Mastra へ渡してはいけない**（README）。LLMアクセスは必ず LiteLLM 経由に統一する。
- コンテナは固定名の外部Dockerネットワーク `llm-net` へ参加する。
- `mastra` コンテナの `/workspace` はナレッジ領域**全体**を指す。`hermes-agent` と `open-deep-research` の `/workspace` は `AI_WORKSPACE_SOURCE` だけを指し、**同名だが範囲が違う**（PRD §15.3）。
- 非推奨の `Agent.network()` を新規採用しない。Supervisorは `agents` を設定した Agent を `generate()` / `stream()` で使う（PRD §8-5）。
- LiteLLM配下のモデルが tool calling と structured output の併用に対応しない可能性がある。その場合はツール利用Stepと構造化Stepを分離する（PRD §12.1、§23）。

## 関連文書

- [要件定義書](requirements.md)
- [ヒアリング記録](interview-record.md)
- [ユーザストーリー](user-stories.md)
- [受け入れ基準](acceptance-criteria.md)
- [準備タスク](prep.md)
