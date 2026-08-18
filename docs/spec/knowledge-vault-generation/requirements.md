# Knowledge Vault Generation 要件定義書

**作成日**: 2026-08-18 ／ **作業規模**: フル機能開発 ／ **対象**: PRD §5 MVP

## 概要

`intrahub-mastra` を、MediaVault と外部資料から Knowledge Vault を生成・維持する知識処理層にする。本要件定義は PRD §5 の **MVP 6項目**を対象とする。

1. Knowledge Vault のディレクトリ構成とノート規約
2. `summarizeDocumentWorkflow`（論文・専門書の階層要約 — MVP の中核）
3. Vault 操作（5操作）
4. MediaVault MCP からの資料取得（Read Only）
5. 役割別の論理モデル名による LLM 切り替え
6. 書き込みポリシー（新規は自動、更新は差分確認）

フェーズ2以降の Workflow（`generateWorkKnowledgeWorkflow` / `generateEpisodeKnowledgeWorkflow` / `researchTopicWorkflow` / `curateTaxonomyWorkflow` / `refreshStaleSourcesWorkflow` / `digestNewItemsWorkflow` / `knowledgeOrchestrator`）は本書では見出しのみとし、詳細化しない。

**要件ID体系について**: 本書の REQ-006 / REQ-016a / REQ-101 / REQ-105 / REQ-202 / REQ-401 / REQ-402 / NFR-031 / NFR-101 / EDGE-006 は、`intrahub-mediavault` 側の設計文書が参照している既存番号を継承したものである。番号と意味を変更してはならない。

## 関連文書

- **ヒアリング記録**: [💬 interview-record.md](interview-record.md)
- **ユーザストーリー**: [📖 user-stories.md](user-stories.md)
- **受け入れ基準**: [✅ acceptance-criteria.md](acceptance-criteria.md)
- **コンテキストノート**: [📝 note.md](note.md)
- **準備タスク**: [🔧 prep.md](prep.md)
- **PRD**: [PRD.md](../../PRD.md)
- **設計方針**: [codex-chat.md](../../codex-chat.md)

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 **青信号**: PRD・設計文書・ユーザヒアリングを参考にしてほぼ推測していない要件
- 🟡 **黄信号**: PRD・設計文書・ユーザヒアリングから妥当な推測による要件
- 🔴 **赤信号**: PRD・設計文書・ユーザヒアリングにない推測による要件

### 通常要件

- **REQ-001**: システムは Knowledge Vault を `00 Inbox` / `10 Sources` / `20 Knowledge` / `30 Syntheses` / `40 Maps` / `90 Meta` / `Attachments` の7大分類で構成しなければならない 🔵 *PRD §5・codex-chat.md「Knowledge Vaultの構成」より*
- **REQ-002**: システムはノート種別をディレクトリではなく frontmatter の `type` で管理しなければならない。`type` の値は `work` / `episode` / `paper` / `academic_book` / `chapter` / `concept` / `theme` / `person` / `comparison` / `timeline` / `essay` の11種とする 🔵 *codex-chat.md「ノート種別」より*
- **REQ-003**: システムは全ノートに共通 frontmatter（`id` / `title` / `type` / `aliases` / `categories` / `tags` / `status` / `sources` / `source_refs` / `provenance`）を付与しなければならない 🔵 *PRD §5・codex-chat.md「メタデータと出典」より*
- **REQ-004**: システムは `status` を `draft` / `review_needed` / `reviewed` / `human_verified` / `stale` の5値で管理しなければならない 🔵 *codex-chat.md `status` 表より*
- **REQ-005**: システムは `summarizeDocumentWorkflow` において、抽出済みテキストをチャンク → 章 → 文献全体の順に階層要約しなければならない 🔵 *PRD §5「MVPの中核」より*
- **REQ-006**: システムは出典参照を `(itemId, fileId, chunkIndex)` の0起点連番インデックス形式で統一して保持しなければならない。ページ・章の表示は `chunk.label` を任意の付属情報として扱い、構造として解釈してはならない 🔵 *mediavault-mcp design/api-tool-mapping.md D-08 で合意済み・既存REQ-006より*
- **REQ-007**: システムは論文を `10 Sources/Papers/{著者}-{年}-{短縮タイトル}/`、専門書を `10 Sources/Academic Books/{著者}-{年}-{短縮タイトル}/` に配置し、`index.md` と章ノート（`Sections/` または `Chapters/`）に分けて出力しなければならない 🔵 *PRD §5・codex-chat.md「論文・専門書」より*
- **REQ-008**: システムは Vault 操作を汎用ファイル操作ではなく `search_notes` / `read_note` / `create_note` / `update_note` / `find_related_notes` の5操作として提供しなければならない 🔵 *PRD §5・codex-chat.md「ToolとMCPの境界」より*
- **REQ-009**: システムは LLM を役割別の論理モデル名（例: 要約・批評・分類）で指定し、実体モデルの割り当ては LiteLLM の config 側で行わなければならない。Mastra 側のコードは論理モデル名だけを知る 🔵 *PRD §5・ヒアリング2026-08-18（役割別の論理名を新設）より*
- **REQ-010**: システムは新規ノートを `status: draft` として自動作成しなければならない 🔵 *PRD §5「書き込みポリシー」より*
- **REQ-011**: システムは出典として `extraction_version` を記録しなければならない 🔵 *PRD §5・mediavault-mcp design/api-tool-mapping.md D-08 より*
- **REQ-012**: システムは生成ノートに `provenance`（`workflow` / `run_id` / `model`）を記録しなければならない 🔵 *codex-chat.md frontmatter 例より*
- **REQ-013**: システムは Agent 間で Markdown を直接受け渡さず、出典・主張・概念・関係・不確実性を含む構造化データで受け渡さなければならない 🔵 *PRD §7・codex-chat.md「Agentの責務」より*
- **REQ-014**: システムは章ノートに、章の目的・要約・主要な主張・根拠と事例・重要語・疑問と反論・出典を含めなければならない 🔵 *codex-chat.md「論文・専門書」より*
- **REQ-015**: システムは中間データ（章分割結果、下書き、レビュー結果）を `ai-workspace` へ置き、Vault 正本（`second-brain`）へは検証を通った成果だけを書かなければならない 🔵 *PRD §1・§7 より*
- **REQ-016a**: システムはシリーズ情報を `get_item_context` の `series` から取得し、資料の階層決定に用いなければならない 🔵 *mediavault-mcp design/api-tool-mapping.md D-07・既存REQ-016aより*
- **REQ-017**: システムは MediaVault の対象 Item を `search_library` で解決し、Item 本体・関連・ファイル一覧を `get_item_context` で、抽出済み全文を `get_item_text` で取得しなければならない 🔵 *PRD §5「MediaVault MCPからの資料取得」より*

### 条件付き要件

- **REQ-101**: `get_item_text` が `tools/list` に存在しない場合、システムはこれを**ツール不在**として検出し、`mode: metadata_only` へフォールバックしなければならない。暗黙のフォールバックや、未抽出との混同をしてはならない 🔵 *mediavault-mcp design/api-tool-mapping.md D-09・既存REQ-101より*
- **REQ-102**: `get_item_text` が `not_extracted` を返した場合、システムは抽出を依頼せず、当該資料の処理を中断して抽出依頼待ちとして人へ通知しなければならない 🔵 *ヒアリング2026-08-18（人へ通知するのみ）・PRD §6「OCR・テキスト抽出そのものを実装しない」より*
- **REQ-103**: チャンクの `label` が `null` で章境界を確定できない場合、システムは章境界を推定して章ノートを生成したうえで、当該ノートの `status` を `review_needed` にしなければならない 🔵 *ヒアリング2026-08-18（推定しreview_needed）・PRD §5 より*
- **REQ-104**: 既存ノートの出典が参照する `extraction_version` が現在の値と異なる場合、システムは参照を自動で読み替えず、当該ノートの `status` を `stale` にしなければならない 🔵 *PRD §5・codex-chat.md「メタデータと出典」より*
- **REQ-105**: 既存ノートへの更新において競合を検出した場合、システムは上書きしてはならない。競合内容は `90 Meta` の検証レポートへ送る 🔵 *PRD §5・既存REQ-105より。ただし競合検出の実装方式は REQ-411 を参照*
- **REQ-106**: 生成結果が出典不足・推定・競合のいずれかを含む場合、システムは当該ノートの `status` を `review_needed` にし、`reviewed` と混在させてはならない 🔵 *PRD §3 成功指標より*
- **REQ-107**: MediaVault MCP への接続に失敗した場合、システムは Vault への書き込みを一切行わずに処理を中断しなければならない 🟡 *PRD §6「原本を複製しない」と NFR-031 から妥当な推測*
- **REQ-108**: 対象資料に対応する Vault ノートが既に存在する場合、システムは新規作成せず更新経路（REQ-201）へ回さなければならない 🔵 *codex-chat.md「検索と更新」より*

### 状態要件

- **REQ-201**: 既存ノートがある状態では、システムは上書き・タグ削除・taxonomy 統合を自動確定させず、`00 Inbox`（ノート本体）または `90 Meta`（差分・検証レポート）へ送って人の承認を得なければならない 🔵 *PRD §5「書き込みポリシー」・ヒアリング2026-08-18（用途で分ける）より*
- **REQ-202**: 人間が追加したタグが存在する状態では、システムは既定でそれを保護し、再生成されなかったことだけを理由に削除してはならない 🔵 *PRD §5・codex-chat.md「タグ・カテゴリの管理」・既存REQ-202より*
- **REQ-203**: ノートが `status: human_verified` の状態にある場合、システムは自動で本文を上書きしてはならない 🟡 *`status` 表と書き込みポリシーから妥当な推測*
- **REQ-204**: `90 Meta` の taxonomy に登録されていない語が候補として生成された状態では、システムはそれを正式タグにせず、提案として蓄積するに留めなければならない 🔵 *PRD §3 成功指標・codex-chat.md「タグ・カテゴリの管理」より*

### オプション要件

- **REQ-301**: システムは章ノートに加えて、文献全体の `index.md` に章一覧と全体要約を含めてもよい 🔵 *codex-chat.md「ノート種別」`paper` / `academic_book` より*
- **REQ-302**: システムは 1 資料あたりの所要時間とトークン消費量を `ai-workspace` へ記録してもよい 🟡 *PRD §8「生成コストと処理時間の許容範囲」未実測から妥当な推測*
- **REQ-303**: システムは `find_related_notes` により既存ノートとの関連を提示し、Wikilink 候補としてもよい 🔵 *PRD §5・codex-chat.md より*

### 制約要件

- **REQ-401**: システムは `mediaResearchAgent` に対し、`search_library` / `get_item_context` / `get_item_text` の3ツールのみを渡さなければならない 🔵 *PRD §5・既存REQ-401より*
- **REQ-402**: システムは mediavault-mcp の書き込み系7ツール（`import_external_item` / `create_item` / `update_consumption` / `organize_item` / `relate_items` / `add_access_link` / `add_citation`）をいかなる Agent にも渡してはならない 🔵 *PRD §6・既存REQ-402より*
- **REQ-403**: システムは知識生成の副作用として MediaVault の Item・評価・視聴読了状況・タグ・カテゴリ・関連を変更してはならない 🔵 *PRD §6 より*
- **REQ-404**: システムは PDF・映像・OCR全文を Knowledge Vault へ複製してはならない。Vault に置くのは生成した知識と出典参照だけとする 🔵 *PRD §1・§6 より*
- **REQ-405**: システムは Vault 専用の embedding 生成・ベクトルDB を持ってはならない 🔵 *PRD §6 より*
- **REQ-406**: システムは OCR・テキスト抽出そのものを実装してはならない 🔵 *PRD §6 より*
- **REQ-407**: システムは専用の Web UI を作ってはならない。起動は Mastra Studio、閲覧は Obsidian と Samba とする 🔵 *PRD §6 より*
- **REQ-408**: システムは LLM 接続を LiteLLM（`http://litellm:4000/v1`）へ統一し、`VLLM_API_KEY` を Mastra へ渡してはならない 🔵 *PRD §5・§7・README より*
- **REQ-409**: システムは Agent・Tool・Workflow・Scorer をすべて `src/mastra/index.ts` へ登録し、`npm run dev` / `npm run build` を使わなければならない 🔵 *AGENTS.md より*
- **REQ-410**: MVP において Workflow の起動方式は Mastra Studio（`:4111`）からの手動実行に限る。スケジューラによる定期実行はフェーズ2で検討する 🔵 *ヒアリング2026-08-18（Mastra Studio手動のみ）より*
- **REQ-411**: システムは書き込み前の内容一致確認（ハッシュ／mtime 比較）を実装しない。人手編集・Samba 経由編集との競合からの回復は `knowledge-vault-commit.sh` による git 履歴に委ねる 🔵 *ヒアリング2026-08-18（gitに任せる）より。PRD §7 の「書き込み前一致確認」記述を本要件で上書きする*
- **REQ-412**: システムは Vault 操作を Mastra 内部の Tool として実装する。独立した MCP サーバーとしては立てない 🔵 *ヒアリング2026-08-18（Mastra内部Tool）より*
- **REQ-413**: システムは Knowledge Vault 側の分類（`categories` / `tags`）を MediaVault とは別体系として扱い、Vault 側の整理結果を MediaVault へ反映してはならない 🔵 *PRD §6・codex-chat.md より*
- **REQ-414**: システムは MediaVault MCP へ Streamable HTTP（`http://mediavault-mcp:8081/mcp`）で接続し、`Authorization: Bearer <token>` を付けなければならない。stdio は使わない 🔵 *PRD §7 より*

## 非機能要件

### パフォーマンス

- **NFR-001**: 章10章前後の専門書1冊の章要約は、バッチ処理として一晩（8時間）以内に完了しなければならない。ローカルモデルでの完結を優先する 🔵 *ヒアリング2026-08-18（一晩放置でOK）より*
- **NFR-002**: システムは文献の全文を一度に LLM へ渡してはならない。チャンク単位の入力に分割する 🔵 *PRD §5・codex-chat.md「主要Workflow」より*
- **NFR-003**: 1 資料あたりの所要時間とトークン消費量を計測・記録し、ローカルモデルで完結できるかの判断材料を残す 🟡 *PRD §8 未確定事項から妥当な推測*

### 信頼性・エラー処理

- **NFR-031**: システムは以下7つの失敗を互いに区別して扱わなければならない 🔵 *既存NFR-031・mediavault-mcp design/api-tool-mapping.md「失敗クラスの対応」より*

  | 失敗 | 責務 | 検出手段 |
  |---|---|---|
  | MediaVault MCP 接続失敗 | mcp | MCPプロトコル層 |
  | MediaVault API 到達失敗 | mcp | `outcome: error` / `MCP_API_UNREACHABLE` |
  | 抽出未実行 | mcp | `outcome: not_extracted` |
  | Vault 書き込み失敗 | Vault | Tool の例外 |
  | 競合検出 | Vault | REQ-105 |
  | 保護による拒否 | Vault | REQ-202 |
  | スキーマ検証失敗 | mastra | zod 検証 |

- **NFR-032**: システムは失敗時に Vault 正本へ中途半端なノートを残してはならない 🟡 *REQ-015「検証を通った成果だけ」から妥当な推測*

### セキュリティ

- **NFR-101**: システムは MediaVault MCP へ読み取り専用トークン（`MCP_READONLY_TOKEN`）で接続し、書き込みツールが `tools/list` に見えない状態で運用しなければならない。本要件は mediavault-mcp 側で readonly トークンのスコープに `get_item_text` が追加されていることを前提とする 🔵 *PRD §5・ヒアリング2026-08-18（readonlyスコープ拡張を前提）より。既存NFR-101はMVP単一トークン運用としていたが本要件で更新*
- **NFR-102**: システムは `VLLM_API_KEY` を保持・参照してはならない。LLM 認証は `LITELLM_MASTER_KEY` のみとする 🔵 *README・PRD §7 より*
- **NFR-103**: 単一ユーザーのセルフホスト環境を前提とし、認証・マルチテナント・権限分離を実装しない 🔵 *PRD §4 より*

### 運用・ユーザビリティ

- **NFR-201**: 生成ノートは Obsidian でそのまま開ける Markdown + YAML frontmatter でなければならない 🔵 *PRD §3・§7 より*
- **NFR-202**: Vault 配下のファイル所有者は IntraHub の `LIBRARY_UID` と人間の編集者で揃え、Samba 経由の読み書きを妨げてはならない 🔵 *PRD §7 より*
- **NFR-203**: 人間は生成物をゼロから書くのではなく、`00 Inbox` と差分を確認する側に回れなければならない 🔵 *PRD §3 ビジョンより*

## Edgeケース

### エラー処理

- **EDGE-001**: MediaVault MCP へ接続できない（コンテナ停止・トークン不正）→ 処理を中断し、Vault へ書き込まない 🔵 *NFR-031 より*
- **EDGE-002**: LiteLLM へ到達できない、または論理モデル名が LiteLLM config に未定義 → 処理を中断し、どの論理モデル名で失敗したかを記録する 🟡 *PRD §7・§8 から妥当な推測*
- **EDGE-003**: `get_item_text` が `outcome: ambiguous`（ファイル特定不能）を返す → 推測でファイルを選ばず確認対象にする 🔵 *mediavault-mcp design/api-tool-mapping.md「その他の失敗」・codex-chat.md「推測で確定せず」より*
- **EDGE-004**: Item に著者または刊行年が無くパス（`{著者}-{年}-{短縮タイトル}`）を構成できない → 欠落部分を既定値で埋めたうえで `review_needed` にする 🟡 *REQ-007 と EDGE-006 から妥当な推測*
- **EDGE-005**: 既存ノートの frontmatter が破損しており `type` / `status` を読めない → 上書きせず `90 Meta` の検証レポートへ送る 🟡 *REQ-105・REQ-201 から妥当な推測*
- **EDGE-006**: `get_item_context` の `series` が `state: "empty"` を返す（シリーズ解決不能）→ 未分類階層で受ける 🔵 *mediavault-mcp design/api-tool-mapping.md D-07・既存EDGE-006より*

### 境界値

- **EDGE-101**: チャンクが0件（抽出結果が空）→ `not_extracted` とは区別し、抽出結果の異常として記録する 🟡 *NFR-031 の失敗分類から妥当な推測*
- **EDGE-102**: 章が1つしか検出されない文献 → `index.md` と章ノート1件を生成する。章分割の失敗と区別するため `review_needed` にする 🟡 *REQ-103 から妥当な推測*
- **EDGE-103**: チャンク数が極端に多い文献（数千チャンク規模）→ NFR-001 の時間内に収まらない可能性があるため、処理前にチャンク数と推定所要時間を記録する 🟡 *NFR-001・NFR-003 から妥当な推測*
- **EDGE-104**: 章タイトルがファイル名として使えない文字（`/` `:` 等）を含む → サニタイズし、原タイトルは frontmatter の `title` に保持する 🟡 *Obsidian/POSIX の制約から妥当な推測*

## フェーズ2以降（本書では詳細化しない）

- `generateWorkKnowledgeWorkflow` / `generateEpisodeKnowledgeWorkflow` — 作品全体ノートと話数ごとの要約・批評
- `researchTopicWorkflow` — テーマ・専門用語の横断調査
- `curateTaxonomyWorkflow` — タグ・カテゴリ・リンクの整理
- `refreshStaleSourcesWorkflow` — 失効した出典参照の再調査
- `digestNewItemsWorkflow` — MediaVault へ追加された資料の定期処理
- `knowledgeOrchestrator` — 要求の解釈と Workflow の選択・組み合わせ
- Web 検索の経路（直接 API / Open Deep Research への委譲）
- 動画・音声の文字起こし

## 信頼性レベル分布（本ファイル）

| レベル | 件数 | 割合 |
|---|---|---|
| 🔵 青信号 | 46 | 79% |
| 🟡 黄信号 | 12 | 21% |
| 🔴 赤信号 | 0 | 0% |

**品質評価**: ✅ 高品質（🟡はいずれも既存文書からの妥当な演繹であり、🔴の純粋な推測は無い）
