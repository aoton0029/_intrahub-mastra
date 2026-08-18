# Knowledge Vault Generation 準備タスク（ユーザー作業）

> **仕様**: [requirements.md](requirements.md)
> **生成日**: 2026-08-18

**【信頼性レベル凡例】**:
- 🔵 **青信号**: 要件定義書・設計文書・ユーザヒアリングで明確に必要と判明したタスク
- 🟡 **黄信号**: 要件定義書・設計文書から妥当に推測されるタスク
- 🔴 **赤信号**: 推測による予防的タスク（実装時に不要と判明する可能性あり）

## 必須（実装開始前に完了が必要）

以下が完了していないと、実装フェーズでブロッカーになります。

- [ ] **mediavault-mcp の readonly トークンスコープへ `get_item_text` を追加する** 🔵 *ヒアリング2026-08-18 Q2・mediavault-mcp README L63・design/api-tool-mapping.md D-10 より*
  - **これが本要件の最大のブロッカー**。現状 `MCP_READONLY_TOKEN` の公開ツールは6個（`health` / `search_library` / `search_external_catalog` / `get_item_context` / `collection_overview` / `list_citations`）で `get_item_text` を含まないため、MVP の中核である章要約が成立しない
  - `get_item_text` には `readOnlyHint: true` が既に付与済み（design/mastra-integration.md L148）なので、トークンスコープの許可リストへ加える作業になる
  - 作業場所: `intrahub-mediavault` リポジトリ（別リポジトリのため本要件の実装では触れない）
  - 完了確認: readonly トークンで接続したセッションの `tools/list` に `get_item_text` が現れること（TC-NFR-101-01）
  - 関連要件: NFR-101, REQ-017, REQ-101

- [ ] **`MCP_READONLY_TOKEN` を発行し、Mastra コンテナへ環境変数として渡す** 🔵 *PRD §5・§7・NFR-101 より*
  - mediavault-mcp 側で `MCP_AUTH_TOKEN` と**異なる値**を設定する（同値だと mcp が起動に失敗する仕様）
  - Mastra 側の compose 定義に環境変数を追加する
  - 関連要件: NFR-101, REQ-414

- [ ] **LiteLLM config に役割別の論理モデル名を定義する** 🔵 *ヒアリング2026-08-18 Q5・PRD §8 未確定事項より*
  - 役割ごとの論理名（要約・批評・分類など）を決め、それぞれに実体モデル（vLLM のローカルモデル／外部API）を割り当てる
  - 既存の `wiki-model` および intrahub 側の `anthropic` / `openai` / `vllm` との関係を整理する
  - Mastra 側のコードは論理名しか知らないため、**この定義が無いと LLM 呼び出しが一切通らない**（EDGE-002）
  - 関連要件: REQ-009, REQ-408, EDGE-002

- [ ] **Mastra コンテナを外部Dockerネットワーク `llm-net` へ参加させる** 🔵 *PRD §7・README より*
  - `LITELLM_BASE_URL=http://litellm:4000/v1` と `LITELLM_MASTER_KEY` を設定する
  - **`VLLM_API_KEY` は渡さない**（NFR-102）
  - 関連要件: REQ-408, NFR-102

- [ ] **`/srv/knowledge` を Mastra へ `/workspace` としてマウントし、`ai-workspace` と `second-brain` を用意する** 🔵 *PRD §7・REQ-015 より*
  - `second-brain` 配下に7大分類（`00 Inbox` / `10 Sources` / `20 Knowledge` / `30 Syntheses` / `40 Maps` / `90 Meta` / `Attachments`）を作成する
  - 所有者を `LIBRARY_UID` と人間の編集者で揃える（NFR-202）
  - 関連要件: REQ-001, REQ-015, NFR-202

## 推奨（実装中に用意できればOK）

- [ ] **テストランナーを導入する** 🟡 *`package.json` の `test` が未設定であることより*
  - 現在 `npm test` はエラー終了する。[acceptance-criteria.md](acceptance-criteria.md) の40件を自動テストとして回すには vitest 等の導入が必要
  - 必要になるフェーズ: Phase 1（規約と境界の検証）
  - 関連要件: 受け入れ基準全般

- [ ] **`90 Meta` の taxonomy（正規カテゴリ・タグの語彙）の初期版を用意する** 🔵 *PRD §3 成功指標・codex-chat.md「タグ・カテゴリの管理」より*
  - 未登録語を提案に留める判定（REQ-204）には、登録済み語彙の実体が必要
  - 空で始めて育てる運用でもよいが、その場合は初回生成のタグがすべて提案扱いになることを了解しておく
  - 必要になるフェーズ: Phase 3
  - 関連要件: REQ-204, REQ-201

- [ ] **`knowledge-vault-commit.sh` の systemd timer が稼働していることを確認する** 🔵 *ヒアリング2026-08-18 Q10・PRD §7 より*
  - REQ-411 により Mastra 側で書き込み前一致確認を実装しないため、**git 履歴が唯一の競合回復手段**になる
  - commit 間隔が長いと、その間の人手編集が AI の上書きで失われうる
  - 必要になるフェーズ: Phase 3（書き込みポリシーの検証前）
  - 関連要件: REQ-411, REQ-105

- [ ] **テスト用の OCR 済み専門書 Item を1件 MediaVault に用意する** 🟡 *NFR-001・TC-NFR-001-01 から妥当な推測*
  - 章10章前後、抽出済み、`chunk.label` が有効なもの
  - NFR-001（8時間以内）の実測に使う
  - 必要になるフェーズ: Phase 2
  - 関連要件: NFR-001, NFR-003

- [ ] **`chunk.label` が `null` になる資料を1件用意する** 🟡 *TC-103-01 から妥当な推測*
  - REQ-103（推定して `review_needed`）を実際に検証するために必要
  - 必要になるフェーズ: Phase 2
  - 関連要件: REQ-103

## 確認事項（判断が必要）

- [ ] **MediaVault 側設計文書の参照先修正を依頼するか** 🔵 *note.md 注意事項2より*
  - `intrahub-mediavault/docs/backend/mediavault-mcp/design/api-tool-mapping.md` 等が「intrahub-mastra PRD §15」を参照しているが、現行 PRD は §9 までしかない（PRD が書き直されている）
  - 本要件定義の作成により `docs/spec/knowledge-vault-generation/requirements.md` は復活したため、REQ 番号の参照は再び有効になった。残るずれは PRD の節番号のみ
  - 修正は `intrahub-mediavault` リポジトリの管轄
  - 関連要件: なし（文書整合性）

- [ ] **NFR-101 の更新を MediaVault 側へ伝えるか** 🔵 *ヒアリング2026-08-18 Q2 より*
  - MediaVault 側 D-10 は「MVP では現行どおり単一トークンで運用する（NFR-101）」と記録しているが、本要件で NFR-101 は **readonly トークン運用が前提**へ変更された
  - D-10 が「第2段階」としている readonly スコープ限定が、本要件では MVP の前提条件に繰り上がる
  - 関連要件: NFR-101

- [ ] **`list_citations` を許可リストへ加えるか** 🟡 *design/api-tool-mapping.md L309 より*
  - MediaVault 側は「`readOnlyHint: true` であり REQ-402 にも抵触しないため、mastra 側が許可リストを拡張すれば追加できる」と余地を記録している
  - 現状 REQ-401 は3ツール限定。引用情報が章要約に有用と判明したら拡張を検討する
  - 関連要件: REQ-401

- [ ] **章ノートの粒度（章単位か節単位か）** 🟡 *REQ-007 の `Sections/` と `Chapters/` の使い分けより*
  - codex-chat.md は論文を `Sections/`、専門書を `Chapters/` としているが、章がさらに節に分かれる専門書でどこまで分割するかは未定
  - ノート数と可読性のトレードオフになるため、実資料1冊を処理してから決めるのが妥当
  - 関連要件: REQ-007, REQ-014

---

## サマリー

| 優先度 | 件数 | 🔵 | 🟡 | 🔴 |
|--------|------|-----|-----|-----|
| 必須 | 5 | 5 | 0 | 0 |
| 推奨 | 5 | 2 | 3 | 0 |
| 確認事項 | 4 | 2 | 2 | 0 |
| **合計** | **14** | **9** | **5** | **0** |

**最大のブロッカー**: `get_item_text` の readonly トークンスコープ追加（別リポジトリ `intrahub-mediavault` の作業）。これが完了するまで MVP の中核である `summarizeDocumentWorkflow` は動作しない。

## 関連文書

- **要件定義書**: [requirements.md](requirements.md)
- **ヒアリング記録**: [interview-record.md](interview-record.md)
- **コンテキストノート**: [note.md](note.md)
