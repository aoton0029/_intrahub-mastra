# knowledge-vault-generation 要件定義書

## 概要

MediaVault（一次情報の正本）を材料に、出典付きの Knowledge Note を生成して Knowledge Vault（二次知識の正本）へ安全に反映する知識処理層を `intrahub-mastra` 上に構築する。

対象範囲は **MVP-0（メタデータ縦切り）+ MVP-1（原典全文対応）** とする。第2段階の `knowledgeCriticAgent` / `knowledgeOrchestrator` / `researchTopicWorkflow` / `updateItemKnowledgeWorkflow` は本要件の対象外だが、それらを後から追加できる形（`status` 昇格条件、Workflow Step の分離）を MVP 時点で維持する。

中核となる成果物は次の4つである。

| 種別 | 名前 | 責務 |
|---|---|---|
| Agent | `mediaResearchAgent` | Itemコンテキストと原典チャンクを出典付き `ResearchResult` へ変換する |
| Agent | `knowledgeWriterAgent` | `ResearchResult` から Knowledge Note 候補（`KnowledgeDraft[]`）を生成する |
| Agent | `vaultCuratorAgent` | 既存照合、新規・更新判定、frontmatter、配置、保存を行う |
| Workflow | `generateItemKnowledgeWorkflow` | 取得・調査・執筆・編成・保存を型付きで順に実行する |

## 関連文書

- **ヒアリング記録**: [💬 interview-record.md](interview-record.md)
- **ユーザストーリー**: [📖 user-stories.md](user-stories.md)
- **受け入れ基準**: [✅ acceptance-criteria.md](acceptance-criteria.md)
- **コンテキストノート**: [📝 note.md](note.md)
- **準備タスク**: [🔧 prep.md](prep.md)
- **PRD**: [intrahub-mastra プロダクト要求定義書](../../PRD.md)

## 機能要件（EARS記法）

**【信頼性レベル凡例】**:
- 🔵 **青信号**: PRD・設計文書・ユーザヒアリングを参考にしてほぼ推測していない要件
- 🟡 **黄信号**: PRD・設計文書・ユーザヒアリングから妥当な推測による要件
- 🔴 **赤信号**: PRD・設計文書・ユーザヒアリングにない推測による要件

### 通常要件

#### 調査（Research）

- REQ-001: システムは、Item ID を受け取り MediaVault MCP の `get_item_context` から作品情報と関連情報を取得しなければならない 🔵 *PRD §10 FR-001*
- REQ-002: システムは、調査結果を Zod で検証済みの `ResearchResult`（`topic` / `sources` / `claims` / `concepts` / `relationships` / `uncertainties`）として返さなければならない 🔵 *PRD §10 FR-002・§13.1*
- REQ-003: システムは、`claims` の各主張に `fact` / `interpretation` / `inference` / `opinion` の区分と `sourceRefs` と `confidence` を付与しなければならない 🔵 *PRD §4-4・§13.1*
- REQ-004: システムは、`mode: full_text` の実行において、MediaVault MCP の `get_item_text` から抽出済みテキストをページまたはチャンク単位で取得しなければならない 🔵 *PRD §10 FR-008（MVP-1）*
- REQ-005: システムは、取得したチャンクについて file ID、チャンク位置、`extracted_at` を出典情報へ保持しなければならない 🔵 *PRD §10 FR-009（MVP-1）*
- REQ-006: システムは、`sourceRefs` を `(itemId, fileId, chunkIndex)` の連番インデックス形式で統一して保持しなければならない。PDFページ・EPUB章・固定文字数チャンクの差は MediaVault 側が吸収するものとし、表示用ラベルは任意の付属情報として扱う 🔵 *ユーザヒアリング 2026-08-13（PRD §24-1 の決定）*

#### 執筆（Writer）

- REQ-007: システムは、`ResearchResult` から Knowledge Note 候補（`KnowledgeDraft[]`）を生成しなければならない 🔵 *PRD §10 FR-003*
- REQ-008: システムは、MVP において `source` / `work` / `concept` の3種別のノートテンプレートを実装しなければならない 🔵 *ユーザヒアリング 2026-08-13・PRD §13.2*
- REQ-009: システムは、生成した各ノートに `id` / `title` / `type` / `aliases` / `tags` / `sources` / `related` / `provenance` / `status` の frontmatter を付与しなければならない 🔵 *PRD §14*
- REQ-010: システムは、すべての生成・更新ノートに `sources` と `provenance` を必須で付与し、MediaVault Item を追跡可能にしなければならない 🔵 *PRD §10 FR-006・§8-8*
- REQ-011: システムは、`provenance` に `generated_by` / `curated_by` / `model` / `generated_at` を記録しなければならない 🔵 *PRD §14*

#### 編成・保存（Curator）

- REQ-012: システムは、保存前に既存ノートを title、alias、種別、出典の4観点で照合しなければならない 🔵 *PRD §10 FR-004・§23*
- REQ-013: システムは、処理結果を `created` / `updated` / `unchanged` / `ambiguous` / `errors` に区別した `WorkflowResult` として返さなければならない 🔵 *PRD §10 FR-005・§13.3*
- REQ-014: システムは、Knowledge Vault への書き込みを `createNote`（排他作成）、`updateNote`（一致確認付き置換）、`moveNote`（配置再算出と移動）の3ツールに限定して提供しなければならない 🔵 *PRD §15*
- REQ-015: システムは、Knowledge Vault からの読み取りを専用ツールではなくファイル走査とパターン検索で行わなければならない 🔵 *PRD §15.1*
- REQ-016: システムは、`calculateNotePath` により `second-brain/{type}/{topic}/{slug}.md` の2階層で配置先を算出しなければならない 🔵 *ユーザヒアリング 2026-08-13（PRD §24-5 の決定）*
- REQ-016a: システムは、`topic` を MediaVault Item の作品名（シリーズがある場合はシリーズ名）から決定しなければならない。LLM の推測による `topic` 生成を行ってはならない 🔵 *ユーザヒアリング 2026-08-13（確認事項1の決定）*
- REQ-017: システムは、生成物の出力先を「`ai-workspace` 配下（既定）」と「`second-brain` 配下（明示指定時）」の2モードで切り替えられなければならない 🔵 *ユーザヒアリング 2026-08-13（PRD §24-6 の決定）*
- REQ-017a: システムは、`ai-workspace` から `second-brain` への昇格を `moveNote` で行えなければならない。`moveNote` は配置先を REQ-016・REQ-016a の規則で再算出し、frontmatter の整合を確認する。実行の起点は人間とする 🔵 *ユーザヒアリング 2026-08-13（確認事項2の決定）*
- REQ-018: システムは、ノートの版識別子を読み取り時にファイル内容から導出し、書き込み前に同じ導出を行って一致を確認しなければならない 🔵 *PRD §14・§10 FR-014*
- REQ-019: システムは、Knowledge Vault を git 管理し、定期的に commit して上書き事故を事後回復可能にしなければならない 🔵 *ユーザヒアリング 2026-08-13（PRD §24-9 の決定）*

#### Workflow

- REQ-020: システムは、`generateItemKnowledgeWorkflow` を `itemId` / `mode`（`metadata_only` | `full_text`）/ `dryRun` を入力として実行できなければならない 🔵 *PRD §12.1*
- REQ-021: システムは、Workflow を getItemContext → getItemText → researchItem → writeKnowledgeDrafts → planCuration → applyCuration の順で実行しなければならない 🔵 *PRD §12.1（critiqueDrafts は第2段階のため対象外）*
- REQ-022: システムは、各 Step に `inputSchema` と `outputSchema` を定義しなければならない 🔵 *PRD §12.1*
- REQ-023: システムは、Agent 呼び出しに構造化出力を利用し、スキーマ検証失敗を黙って自然文へフォールバックさせてはならない 🔵 *PRD §12.1*
- REQ-024: システムは、Agent ごとに固定の論理モデルを割り当て、実行時に Agent 自身がモデルを変更できないようにしなければならない 🔵 *PRD §10 FR-013・§11*
- REQ-025: システムは、Agent 別の論理モデル名を環境変数で上書き可能にし、既定値をコード内に持たなければならない 🔵 *ユーザヒアリング 2026-08-13（PRD §24-8 の決定）*
- REQ-026: システムは、実際に使用した論理モデル名を `provenance.model` と observability trace の双方へ記録しなければならない 🟡 *PRD §14・NFR-002 と REQ-025 の決定から妥当な推測（.env切替可にした結果、評価と実行モデルの対応を追う手段が必要になるため）*

### 条件付き要件

- REQ-101: `mode: metadata_only` の場合、システムは `get_item_text` が未実装であっても Workflow を完了できなければならない 🔵 *PRD §9.1・§20*
- REQ-102: `mode: metadata_only` において内容の深い要約ができない場合、システムはメタデータから推測せず `insufficient_source` として明示しなければならない 🔵 *PRD §9.1*
- REQ-103: 原典が未抽出の場合、システムは `not_extracted` を返し、知識生成を部分完了または保留にしなければならない 🔵 *PRD §9.2*
- REQ-104: 既存ノート候補を一意に解決できない場合、システムは保存を行わず候補を `ambiguous` へ格納し、`status: partial` で完了しなければならない 🔵 *PRD §10 FR-007・§17、ユーザヒアリング 2026-08-13*
- REQ-105: 更新対象ノートの現在の内容が読み取り時の内容と一致しない場合、システムは上書きせず処理を停止し、競合として返さなければならない 🔵 *PRD §10 FR-014・§23*
- REQ-106: 生成内容と既存ノートに差分がない場合、システムは `unchanged` を返さなければならない 🔵 *PRD §12.2*
- REQ-107: `dryRun: true` の場合、システムは Vault へ一切の変更を加えず、保存計画と予定差分のみを返さなければならない 🔵 *PRD §17・§20*
- REQ-108: NFR-005 の取得上限に達した場合、システムは取得を打ち切り、打ち切った対象と理由を `warnings` へ含めて返さなければならない 🔵 *PRD NFR-005*
- REQ-109: 出典なしの主張を保存候補へ含める場合、システムは警告を出し、当該ノートを `verified` へ昇格させてはならない 🔵 *PRD §17*
- REQ-110: 部分失敗が発生した場合、システムは成功済みのノートIDと失敗した操作の両方を返さなければならない 🔵 *PRD §12.2*
- REQ-111: 同一 Item・同一原典バージョン・同一生成設定で再実行された場合、システムは不要な新規ノートを作成してはならない 🔵 *PRD §12.2・§19*

### 状態要件

- REQ-201: ノートが `status: draft` にある場合、システムは本文の更新と frontmatter への追加を行えなければならない 🔵 *PRD §14*
- REQ-202: ノートが `status: reviewed` または `verified` にある場合、システムは本文の更新をツール側で拒否しなければならない 🔵 *PRD §10 FR-015・§14*
- REQ-203: ノートが `status: reviewed` または `verified` にある場合、システムは `sources` / `related` / `tags` / `aliases` への追加のみを許可しなければならない 🔵 *PRD §14*
- REQ-204: いずれの状態においても、システムは `status` の昇格および降格をツールから行えてはならない 🔵 *PRD §14*
- REQ-205: 保護により更新を拒否された場合、システムは元ノートを変更せず、修正内容を別ファイルとして書き出さなければならない 🔵 *PRD §14・§17*
- REQ-206: Critic 未通過の状態にあるノートについて、システムは `status: draft` として Vault へ保存してよい。保存を Critic の実行に依存させてはならない 🔵 *PRD §14*

### オプション要件

- REQ-301: システムは、対話経由の実行に限り、曖昧な既存ノート候補を Workflow の suspend / resume で解決してもよい 🟡 *PRD §8-9・§13.3 の `suspended` から妥当な推測。MVPの既定は REQ-104 の ambiguous 終了*
- REQ-302: システムは、MediaVault 側の jobs 系 MCP ツールが利用可能になった段階で `extract_text` ジョブの起動と監視を追加してもよい 🔵 *PRD §9.2・§16*
- REQ-303: システムは、`person` / `topic` / `comparison` / `timeline` / `essay` のノート種別テンプレートを MVP 後に追加してもよい 🔵 *PRD §13.2*
- REQ-304: システムは、`@mastra/memory` を用いた会話メモリを MVP では使用しなくてもよい 🟡 *PRD §24-4 が第2段階の未決事項であることから妥当な推測*

### 制約要件

#### 権限とツール境界

- REQ-401: システムは、`mediaResearchAgent` に MediaVault MCP の Read Only ツール（`search_library` / `get_item_context` / `get_item_text`）のみを渡さなければならない 🔵 *PRD §8-6・§15*
- REQ-402: システムは、MediaVault MCP の `create_item` / `update_consumption` / `organize_item` / `relate_items` / `add_access_link` をいかなる Agent にも渡してはならない 🔵 *PRD §15*
- REQ-403: システムは、Knowledge Vault の書き込みツールを `vaultCuratorAgent` にのみ渡さなければならない 🔵 *PRD §8-6・§15.1・§17*
- REQ-404: システムは、`write_file` のような低レベルファイル操作ツールを Agent へ公開してはならない 🔵 *PRD §8-7*
- REQ-405: システムは、中間ファイル用の自由書き込みツールのパスを `ai-workspace` 配下だけに制限しなければならない 🔵 *PRD §15.1*
- REQ-406: システムは、`second-brain` へ到達できるツールを `createNote` / `updateNote` / `moveNote` の3つに限り、いずれも REQ-018 と REQ-202 を通さなければならない 🔵 *PRD §15.1*
- REQ-407: システムは、Vault 書き込みにおいてマウント範囲外への書き込みを拒否し、相対パスによる脱出、絶対パス、symlink 経由の脱出のいずれも拒否しなければならない 🔵 *PRD §17*
- REQ-408: システムは、ノート削除ツールを MVP で提供してはならない 🔵 *PRD §17*
- REQ-409: システムは、Knowledge Vault への読み書きに専用の MCP サーバーを立ててはならない 🔵 *PRD §15.1*

#### データと副作用

- REQ-410: システムは、MediaVault 内の視聴・読了状況、評価、タグ、関連、Item を知識生成の副作用として変更してはならない 🔵 *PRD §5・§19*
- REQ-411: システムは、MediaVault 内へ要約・Wiki・embedding を保存してはならない 🔵 *PRD §5*
- REQ-412: システムは、Knowledge Vault ノートの自動削除、破壊的な統合、履歴を残さない上書きを行ってはならない 🔵 *PRD §5*
- REQ-413: システムは、ノートの版識別子を frontmatter に持たせてはならず、また mtime を競合検出に用いてはならない 🔵 *PRD §14*

#### 実装構成

- REQ-414: システムは、すべての Agent、Workflow、Tool、Scorer を `src/mastra/index.ts` へ登録しなければならない 🔵 *AGENTS.md・PRD §20・§22*
- REQ-415: システムは、LLM アクセスを LiteLLM へ統一し、`VLLM_API_KEY` を Mastra へ渡してはならない 🔵 *README.md*
- REQ-416: システムは、`npm run build` が成功する状態を維持しなければならない 🔵 *PRD §20・AGENTS.md*
- REQ-417: システムは、LiteLLM 配下のモデルが tool calling と structured output を併用できない場合、ツール利用 Step と構造化 Step を分離しなければならない 🔵 *PRD §12.1・§23*

#### 安全性

- REQ-418: システムは、外部資料の本文を信頼できない入力として扱い、本文中の命令を Agent への指示として実行してはならない 🔵 *PRD §17・§23*
- REQ-419: システムは、トークン、APIキー、原典本文をログへ出力してはならない 🔵 *PRD §17*

## 非機能要件

### パフォーマンス

- NFR-001: 1回の Workflow 実行における取得上限を次の既定値で固定し、値は設定で変更できるようにする。コード内へ直接埋め込まない 🔵 *PRD NFR-005*

  | 対象 | 既定の上限 |
  |---|---|
  | Item数 | 5 |
  | Itemあたりのファイル数 | 3 |
  | チャンク数（実行合計） | 50 |
  | `mediaResearchAgent` への入力累計トークン | 120,000 |

- NFR-002: 原典全文はチャンク単位で取得し、単一の Agent コンテキストまたは Workflow 出力へ無制限に蓄積しない 🔵 *PRD NFR-005*
- NFR-003: 上限超過を無言で切り捨てず、必ず `warnings` として返す 🔵 *PRD NFR-005*

### 型安全性

- NFR-011: Agent、Workflow、Tool の境界を Zod または互換 Standard JSON Schema で検証する 🔵 *PRD NFR-001*
- NFR-012: `ResearchResult`、`KnowledgeDraft`、`CurationPlan`、`WorkflowResult` の Zod スキーマを実装の最初に確定させる 🔵 *PRD §21-1*

### 可観測性

- NFR-021: Workflow run ID、各 Step の状態、利用 Agent、モデル、レイテンシ、失敗種別、作成・更新件数を追跡できるようにする 🔵 *PRD NFR-002*
- NFR-022: 原典本文と秘密値を trace へ保存しないか、保存前にマスクする。既存の `SensitiveDataFilter` を利用する 🔵 *PRD NFR-002・`src/mastra/index.ts`*
- NFR-023: 既存の `@mastra/observability`、`@mastra/libsql`、`@mastra/duckdb` による基盤を再利用し、本プロダクト固有の観測項目だけを追加する 🔵 *PRD NFR-002*

### 障害分離

- NFR-031: 次の失敗を区別して返す 🔵 *PRD NFR-003*
  - MediaVault MCP 接続失敗
  - MediaVault API 到達失敗
  - 抽出未実行（`not_extracted`）
  - Vault 書き込み失敗
  - 競合検出（REQ-105）
  - 保護による拒否（REQ-202）
  - スキーマ検証失敗
  - LLM 失敗

### 再実行可能性

- NFR-041: 同じ入力の安全な再実行を可能にし、部分成功後の再実行で重複ノートを作らない 🔵 *PRD NFR-004・§12.2*
- NFR-042: 更新前後の差分を監査可能な形式で保持する。git 管理（REQ-019）をその主たる手段とする 🔵 *PRD §12.2、ユーザヒアリング 2026-08-13*

### セキュリティ

- NFR-101: MediaVault MCP は Bearer トークンで認証する 🔵 *PRD §17*
- NFR-102: Knowledge Vault は bind mount で到達し、マウント範囲をアクセス境界とする 🔵 *PRD §17*
- NFR-103: Agent へ渡すツールを責務ごとに allowlist 化する。MCP トークン自体が書き込み権限を持つ間は、Mastra 側のツール選別を必須の防御線とする 🔵 *PRD §15・§17*
- NFR-104: `status` による保護判定は Vault 書き込みツールの実装が行い、Agent への指示に依存しない 🔵 *PRD §14・§10 FR-015*

### ユーザビリティ

- NFR-201: 処理後に、作成ノート、更新ノート、未変更ノート、使用した出典、警告、失敗箇所を利用者が確認できる 🔵 *PRD US-06・§13.3*
- NFR-202: 各主張の出典を MediaVault Item またはファイルまで追跡でき、事実と解釈を区別できる 🔵 *PRD US-04*
- NFR-203: `dryRun` により保存計画と差分を事前確認できる 🔵 *PRD §17*
- NFR-204: メインPC の AI クライアントからは Samba の `Knowledge` 共有経由で Vault を扱える。この経路では一致確認と保護が効かないことを明示する 🔵 *PRD §15.2*

### 品質評価

- NFR-301: 少なくとも次の評価軸の scorer を用意する 🔵 *PRD NFR-006*
  - citation grounding / faithfulness
  - hallucination
  - knowledge completeness
  - duplicate avoidance
  - vault structure validity
  - workflow trajectory accuracy
- NFR-302: `@mastra/evals` を利用し、Agent / Workflow Step へのライブ評価と、CI での固定データセットによる回帰評価を使い分ける 🔵 *PRD NFR-006*
- NFR-303: 10件以上の代表 Item からなる評価データセットを作成した後に品質の基準値を確定する 🔵 *PRD §19*

### 成功指標

| 指標 | MVP目標 | 信頼性 |
|---|---|---|
| 生成ノートの出典付与率 | 100% | 🔵 *PRD §19* |
| 同一Itemの再実行による重複ノート | 0件 | 🔵 *PRD §19* |
| Workflow結果から作成・更新対象を特定できる割合 | 100% | 🔵 *PRD §19* |
| 曖昧な既存ノートへの無確認上書き | 0件 | 🔵 *PRD §19* |
| schema validation を通らない Agent 間データの次工程流入 | 0件 | 🔵 *PRD §19* |
| MediaVault への意図しない書き込み | 0件 | 🔵 *PRD §19* |

## Edgeケース

### エラー処理

- EDGE-001: MediaVault MCP へ接続できない場合、`errors` に接続失敗として記録し、スキーマ検証失敗と区別して返す 🔵 *PRD §20・NFR-003*
- EDGE-002: `get_item_context` が Item を返さない（存在しない Item ID）場合、Workflow を `failed` で終了し、Vault へ書き込まない 🟡 *PRD NFR-003 から妥当な推測*
- EDGE-003: Agent の構造化出力が Zod 検証を通らない場合、自然文へフォールバックせず当該 Step を失敗として返す 🔵 *PRD §12.1・§19*
- EDGE-004: `createNote` の排他作成が既存ファイルと衝突した場合、上書きせず失敗として返し、`updateNote` 経路へは自動遷移しない 🟡 *PRD §15（排他作成）から妥当な推測*
- EDGE-005: Vault の git commit に失敗した場合、ノート保存自体は成功として扱いつつ `warnings` へ記録する 🟡 *ユーザヒアリング 2026-08-13 の git管理決定から妥当な推測*
- EDGE-006: MediaVault Item に作品名・シリーズ名がなく `topic` を決定できない場合、推測で階層を作らず既定の未分類階層へ配置し `warnings` へ記録する 🔵 *ユーザヒアリング 2026-08-13（確認事項1の決定）と PRD §8-9「曖昧な対象を推測で上書きしない」より*
- EDGE-007: LLM 呼び出しがタイムアウトまたはレート制限で失敗した場合、LLM 失敗として区別し、部分成功済みのノートを保持したまま返す 🔵 *PRD NFR-003・§12.2*
- EDGE-008: 原典本文に「これまでの指示を無視して」等の命令文が含まれる場合、指示として実行せず本文データとして扱う 🔵 *PRD §17・§23*
- EDGE-009: 環境変数で指定された論理モデル名が LiteLLM に存在しない場合、起動時または初回呼び出し時に明示的に失敗させ、別モデルへ暗黙にフォールバックしない 🟡 *ユーザヒアリング 2026-08-13（.env切替採用）と PRD §11 から妥当な推測*

### 境界値

- EDGE-101: 取得 Item 数が上限 5 に達した時点で取得を打ち切り、6件目以降を `warnings` へ記録する 🔵 *PRD NFR-005*
- EDGE-102: Item あたりのファイル数が上限 3 に達した時点で打ち切る 🔵 *PRD NFR-005*
- EDGE-103: 実行合計チャンク数が上限 50 に達した時点で打ち切る 🔵 *PRD NFR-005*
- EDGE-104: `mediaResearchAgent` への入力累計トークンが 120,000 に達した時点で追加取得を行わない 🔵 *PRD NFR-005*
- EDGE-105: `ResearchResult.claims` が空（原典から何も言えない）場合、ノートを生成せず `insufficient_source` として返す 🔵 *PRD §9.1*
- EDGE-106: 既存ノート候補がちょうど1件で完全一致する場合は `updated` または `unchanged`、2件以上該当する場合は `ambiguous` とする 🔵 *PRD §10 FR-007、ユーザヒアリング 2026-08-13*
- EDGE-107: 更新差分が空白・改行のみの場合は `unchanged` として扱い、git commit を発生させない 🟡 *PRD §12.2 から妥当な推測*

## 信頼性レベル分布（本ファイル）

| レベル | 件数 |
|---|---|
| 🔵 青信号 | 83 |
| 🟡 黄信号 | 9 |
| 🔴 赤信号 | 0 |

**品質評価**: ✅ 高品質（🔵 が 90%）

**更新履歴**:
- 2026-08-13 初版
- 2026-08-13 prep.md 確認事項の決定を反映（REQ-016a, REQ-017a を追加、EDGE-006 を 🟡 → 🔵 へ）
