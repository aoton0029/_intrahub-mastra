# intrahub-mastra プロダクト要求定義書（草案）

> ステータス: 草案・要求定義の正本  
> 最終更新: 2026-08-12  
> 原案: [codex-chat.md](./codex-chat.md)  
> 対象実装: `intrahub-mastra` 0.1.x / `@mastra/core` 1.51.x

本ファイルを`intrahub-mastra`の要求定義の正本とする。設計・実装・関連リポジトリからの参照は本ファイルへ統一する。

## 1. 概要

`intrahub-mastra` は、MediaVaultを情報源としてKnowledge Vaultを生成・維持する知識処理層である。MediaVaultそのものをAI化するのではなく、MediaVaultに集約された作品、資料、メタデータ、抽出済みテキストを材料に、再利用可能な二次知識を生成する。

責務の境界は次のとおりとする。

```text
MediaVault       = 一次情報とメタデータの正本
intrahub-mastra  = 調査、知識生成、検証、編成のロジック
Knowledge Vault  = 生成された二次知識の正本
```

MediaVault MCPは材料の取得に徹し、要約、Wiki、embedding、Knowledge Noteを所有しない。生成物はKnowledge Vaultへ保存し、MediaVault Item IDとファイルIDから原典を追跡できる状態を維持する。

## 2. 背景と課題

- MediaVaultには映画、ドラマ、アニメ、漫画、小説、ゲーム、学術書、論文など異種の資料が集約されているが、資料を横断した概念整理や関係付けは手作業に依存している。
- AIが毎回原典を読み直して回答するだけでは知識が蓄積されず、同じ調査を繰り返す。
- 単一Agentに調査、執筆、重複判定、ファイル配置まで任せると、出典の欠落、責務の混在、重複ノートの増加が起きやすい。
- 現在の`intrahub-mastra`はweatherサンプルを中心とする初期構成である一方、LiteLLM接続、storage、observability、scorerを利用できる基盤は存在する。
- MediaVault MCPにはメタデータ取得用の`search_library`と`get_item_context`が実装済みだが、全文取得用の`get_item_text`とその下位APIは未実装である。
- Knowledge Vaultを安全に操作する意味論的な`vault-mcp`は未設計・未実装である。

## 3. ビジョン

利用者との会話や定期処理を通じて、原典に立脚したKnowledge Vaultが継続的に育つ状態を作る。

検索と生成の基本順序は次のとおりとする。

```text
1. Knowledge Vaultの整理済み知識を探す
2. 不足している場合だけMediaVaultを調査する
3. 必要な場合だけ原典の抽出済み全文を読む
4. 得られた知識を検証し、Knowledge Vaultへ反映する
5. 回答と変更内容を利用者へ返す
```

Knowledge Vaultは単なる応答キャッシュではなく、人間が閲覧・編集できる整理済み二次知識として扱う。

## 4. 目的

1. MediaVault Itemから、出典付きのKnowledge Noteを一気通貫で生成できるようにする。
2. 調査、執筆、構造管理を専門Agentへ分離し、それらを型付きWorkflowで接続する。
3. 新規ノート作成前に既存ノートを照合し、重複や無制限なファイル増加を防ぐ。
4. 事実、解釈、推論、意見を区別し、原典から言えない断定を検出できるようにする。
5. 対話的な要求はSupervisor Agentが適切なAgentまたはWorkflowへ委譲する。
6. 既存のMastra storage、observability、scorer基盤を利用して品質と失敗箇所を追跡できるようにする。

## 5. 対象外

MVPでは次を行わない。

- MediaVault内の視聴・読了状況、評価、タグ、関連、Itemを知識生成の副作用として変更すること
- MediaVault内への要約、Wiki、embeddingの保存
- Knowledge Vaultノートの自動削除、破壊的な統合、履歴を残さない上書き
- メディア種別ごとの専用Agentの量産
- Knowledge Vault全体のベクトル索引およびRAG基盤の構築
- Knowledge VaultをMCP Resourcesとして外部公開すること
- 外部Webを一次情報として自動収集する汎用Webリサーチ
- 複数ユーザー、ロール、共有Vaultの権限管理

## 6. 対象ユーザー

### 6.1 Vault所有者

MediaVaultとKnowledge Vaultを所有する単一ユーザー。対話またはItem指定で知識生成を依頼し、生成・更新されたMarkdownノートを閲覧、修正する。

### 6.2 自動化トリガー

新規Itemの取り込み、定期ダイジェスト、リンク再構築などを起点にWorkflowを実行するスケジューラ。MVP後に対象とする。

## 7. ユーザーストーリー

### US-01: 所有資料からトピックを整理する

Vault所有者として、「攻殻機動隊について自分の持っている資料から整理して」のように依頼し、既存ノートとMediaVault内の複数資料を横断した知識を得たい。

### US-02: 特定Itemを知識化する

Vault所有者として、MediaVault Item IDを指定し、その作品や資料からWork、Concept、PersonなどのKnowledge Noteを生成したい。

### US-03: 既存ノートを再利用する

Vault所有者として、同じ概念のノートを重複作成せず、既存ノートへの追記または更新として扱ってほしい。

### US-04: 出典と根拠を確認する

Vault所有者として、各主張の出典をMediaVault Itemまたはファイルまで追跡し、事実と解釈を区別したい。

### US-05: 資料を横断して問いに答える

Vault所有者として、「押井守の映画で身体性にどのような傾向があるか」のような問いに、既存知識を優先し、不足分だけを追加調査した回答を得たい。

### US-06: Vaultへの変更内容を確認する

Vault所有者として、処理後に作成ノート、更新ノート、未変更ノート、使用した出典、警告、失敗箇所を確認したい。

## 8. プロダクト原則

1. **原典と派生知識を分離する**: MediaVaultを原典の正本、Knowledge Vaultを派生知識の正本とする。
2. **Research、Writer、Curatorを分離する**: 「何が書かれているか」「どう表現するか」「どこへどう保存するか」を別責務にする。
3. **Agent間は構造化データで接続する**: 自由形式Markdownを次のAgentへの契約にせず、Zodで検証した構造を渡す。
4. **決定的な処理はWorkflowにする**: 手順が決まる処理はAgentの自由裁量に任せない。
5. **対話的な委譲はSupervisor Agentにする**: 非推奨の`Agent.network()`を新規採用せず、`agents`を設定したSupervisor Agentを`generate()`または`stream()`で利用する。
6. **最小権限にする**: Research AgentにはMediaVaultのRead Onlyツールだけを渡し、Vault書き込みはCuratorだけに許可する。
7. **低レベルファイル操作を公開しない**: `write_file`ではなく、`create_note`、`update_note`などの意味論的ツールを使う。
8. **provenanceを必須にする**: すべての生成・更新ノートから使用したMediaVault Itemを追跡可能にする。
9. **曖昧な対象を推測で上書きしない**: 重複候補を一意に解決できない場合は処理を停止またはsuspendし、利用者の判断を求める。
10. **メディア差分はinstructionまたはskillで吸収する**: 専用Agentへの分割は、共通Agentで品質を満たせないことが評価で確認された場合だけ行う。

## 9. スコープと段階

### 9.1 MVP-0: メタデータ縦切り

全文抽出を待たず、`get_item_context`から取得できる作品情報と関連情報だけで最小経路を成立させる。

| 種別 | 名前 | 責務 |
|---|---|---|
| Agent | `mediaResearchAgent` | Itemコンテキストを出典付きの`ResearchResult`へ変換する |
| Agent | `knowledgeWriterAgent` | `ResearchResult`からKnowledge Note候補を生成する |
| Agent | `vaultCuratorAgent` | 既存照合、新規・更新判定、frontmatter、配置、保存を行う |
| Workflow | `generateItemKnowledgeWorkflow` | 取得、調査、執筆、編成、保存を順に実行する |

MVP-0では、内容の深い要約ができない場合にメタデータから推測せず、`insufficient_source`として明示する。

### 9.2 MVP-1: 原典全文対応

- MediaVault MCPの`get_item_text`を接続する。
- 必要なチャンクだけを取得し、取得元ファイル、チャンク、抽出日時を記録する。
- 未抽出の場合は`not_extracted`を返し、知識生成を部分完了または保留にする。
- `extract_text`ジョブの起動・監視は、MediaVault側のjobsツールが利用可能になった段階で追加する。

### 9.3 第2段階: 検証と対話

| 種別 | 名前 | 責務 |
|---|---|---|
| Agent | `knowledgeCriticAgent` | 出典整合性、事実と解釈の混同、矛盾、過度な一般化を検査する |
| Agent | `knowledgeOrchestrator` | Supervisorとして利用者の意図を解釈し、AgentまたはWorkflowへ委譲する |
| Workflow | `researchTopicWorkflow` | Vault検索、不足判定、複数Item調査、ノート更新を行う |
| Workflow | `updateItemKnowledgeWorkflow` | 原典または既存ノートの変更に応じて差分更新する |

### 9.4 将来候補

- `digestNewItemsWorkflow`
- `rebuildLinksWorkflow`
- Knowledge VaultのBM25、ベクトル、ハイブリッド検索
- 定期実行と長時間Workflowの再開
- Criticの判定を品質ゲートとして保存前に強制する運用
- MCP Resourcesを用いたKnowledge Vaultの読み取り専用公開

## 10. 機能要求

| ID | 要求 | 対象段階 |
|---|---|---|
| FR-001 | Item IDから`get_item_context`を取得できる | MVP-0 |
| FR-002 | 調査結果をスキーマ検証済みの`ResearchResult`として返す | MVP-0 |
| FR-003 | Research結果から複数種別のKnowledge Note候補を生成できる | MVP-0 |
| FR-004 | 保存前に既存ノートをタイトル、alias、種別、出典で照合する | MVP-0 |
| FR-005 | 新規作成、更新、未変更、曖昧、失敗を区別して返す | MVP-0 |
| FR-006 | ノートにsourcesとprovenanceを必須で付与する | MVP-0 |
| FR-007 | 一意に解決できない既存ノートへ自動上書きしない | MVP-0 |
| FR-008 | Itemに紐づく抽出済みテキストをページまたはチャンク単位で取得する | MVP-1 |
| FR-009 | 取得チャンクのfile ID、位置、抽出日時を出典情報へ保持する | MVP-1 |
| FR-010 | Criticが主張と出典の対応を検査し、指摘を構造化して返す | 第2段階 |
| FR-011 | Supervisorが利用者の要求をAgentまたはWorkflowへ委譲する | 第2段階 |
| FR-012 | 回答に利用した知識とVault変更結果を同時に提示する | 第2段階 |

## 11. Agent構成

| Agent | 入力 | 出力 | MediaVault | Knowledge Vault |
|---|---|---|---|---|
| `mediaResearchAgent` | Itemコンテキスト、必要に応じて全文チャンク | `ResearchResult` | Read | 原則なし |
| `knowledgeWriterAgent` | `ResearchResult` | `KnowledgeDraft[]` | なし | Read |
| `vaultCuratorAgent` | Draftと既存ノート候補 | `CurationPlan`、保存結果 | なし | Read/Write |
| `knowledgeCriticAgent` | Research結果、Draft、出典 | `CritiqueResult` | Read | Read |
| `knowledgeOrchestrator` | 利用者の要求と会話履歴 | 回答、委譲結果 | 間接 | 間接 |

上位Agentに低レベルMCPツールを直接渡さない。Supervisorが利用する各subagentには、委譲判断に必要な明確な`description`、入出力形式、利用条件を定義する。

## 12. 主要Workflow

### 12.1 `generateItemKnowledgeWorkflow`

```text
input: itemId, mode(metadata_only | full_text), dryRun
  ↓
1. getItemContext
  ↓
2. getItemText（full_text時。未実装・未抽出なら部分完了へ分岐）
  ↓
3. researchItem
  ↓
4. writeKnowledgeDrafts
  ↓
5. critiqueDrafts（第2段階）
  ↓
6. planCuration
  ↓
7. applyCuration（dryRun=falseの場合のみ）
  ↓
output: created, updated, unchanged, ambiguous, sources, warnings, errors
```

各Stepは`inputSchema`と`outputSchema`を持つ。Agent呼び出しは構造化出力を利用し、スキーマ検証失敗を黙って自然文へフォールバックさせない。LiteLLM配下のモデルがtool callingとstructured outputの併用に対応しない場合は、ツール利用Stepと構造化Stepを分離する。

### 12.2 冪等性

- 同一Item、同一原典バージョン、同一生成設定で再実行した場合、不要な新規ノートを作成しない。
- 内容差分がない場合は`unchanged`を返す。
- 部分失敗時は成功済みのノートIDと失敗した操作を両方返す。
- 更新前後の差分を監査可能な形式で保持する。

## 13. データ契約

### 13.1 ResearchResult

```ts
type ResearchResult = {
  topic: string;
  sources: Array<{
    itemId: string;
    title: string;
    mediaType: string;
    fileId?: string;
    chunks?: Array<{ index: number; extractedAt?: string }>;
  }>;
  claims: Array<{
    statement: string;
    kind: "fact" | "interpretation" | "inference" | "opinion";
    sourceRefs: string[];
    confidence: number;
  }>;
  concepts: Array<{
    name: string;
    description: string;
    sourceRefs: string[];
  }>;
  relationships: Array<{
    from: string;
    to: string;
    relation: string;
    evidence: string;
    sourceRefs: string[];
  }>;
  uncertainties: string[];
};
```

`sourceRefs`は`itemId`だけでなく、利用可能な場合はfile IDとチャンク位置を解決できる安定した参照にする。

### 13.2 KnowledgeDraft

生成可能な種別は`source`、`work`、`person`、`concept`、`topic`、`comparison`、`timeline`、`essay`とする。MVPで全種別のテンプレート実装を必須にはせず、`source`、`work`、`concept`から開始する。

### 13.3 WorkflowResult

```ts
type WorkflowResult = {
  status: "success" | "partial" | "suspended" | "failed";
  created: NoteChange[];
  updated: NoteChange[];
  unchanged: NoteRef[];
  ambiguous: AmbiguousTarget[];
  sources: SourceRef[];
  warnings: WorkflowIssue[];
  errors: WorkflowIssue[];
};
```

## 14. Knowledge Vaultデータモデル

最低限、すべての管理対象ノートに次のfrontmatterを持たせる。

```yaml
---
id: kh_01...
title: ゴースト
type: concept
aliases:
  - ghost
tags:
  - philosophy
  - ghost-in-the-shell
sources:
  - type: mediavault
    item_id: "..."
    file_id: "..."
    chunks: [0, 1]
related:
  - "[[攻殻機動隊]]"
  - "[[電脳化]]"
provenance:
  generated_by: knowledge-writer
  curated_by: vault-curator
  reviewed_by: knowledge-critic
  model: wiki-model
  generated_at: 2026-08-12T00:00:00Z
status: draft
---
```

`status`は少なくとも`draft`、`reviewed`、`verified`を持つ。Critic未実行のノートを自動的に`verified`にしない。

## 15. ToolおよびMCP境界

```text
intrahub-mastra
├─ MediaVault MCP
│  ├─ search_library       # Read
│  ├─ get_item_context     # Read
│  └─ get_item_text        # Read、MVP-1、未実装
├─ Vault MCP
│  ├─ search_notes         # Read
│  ├─ read_note            # Read
│  ├─ create_note          # Write
│  ├─ update_note          # Write
│  ├─ move_note            # Write
│  ├─ list_links           # Read
│  └─ get_backlinks        # Read
└─ Internal Tools
   ├─ normalizeKnowledge
   ├─ validateSources
   ├─ validateFrontmatter
   ├─ calculateNotePath
   └─ diffNote
```

`mediaResearchAgent`にMediaVault MCPの`create_item`、`update_consumption`、`organize_item`、`relate_items`、`add_access_link`を渡さない。MCPトークン自体が書き込み権限を持つ間は、Mastra側のツール選別を必須の防御線とする。

## 16. MediaVault側への依存要求

既存の[mediavault-mcp × intrahub-mastra 連携エンドポイント設計](../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mastra-integration.md)に、必要な追加要求がすでに定義されているため、本草案では新規エンドポイントを追加しない。

| 依存 | 現状 | 本プロダクトへの影響 |
|---|---|---|
| `search_library` | 実装済み | トピックからItem候補を解決できる |
| `get_item_context` | 実装済み | MVP-0のメタデータ縦切りに利用できる |
| `get_item_text` | 設計済み、未実装 | MVP-1の開始条件 |
| `GET /api/v1/items/{id}/text` | 要求済み、未実装 | `get_item_text`の下位依存 |
| `extract_text`ジョブ | API/worker側に設計あり | 未抽出原典を利用するための依存 |
| jobs系MCPツール | 将来枠 | 自動抽出依頼と進捗監視の依存 |

`get_item_text`は1回の応答へ全文を詰め込まず、file IDを明示でき、チャンク単位で取得でき、`extracted_at`を返すことを必須とする。

## 17. セキュリティと安全性

- MediaVault MCPとVault MCPは認証済みの内部経路からのみ接続する。
- トークン、APIキー、原典本文をログへ出力しない。
- Agentへ渡すツールを責務ごとにallowlist化する。
- Curator以外のAgentにVault書き込みツールを渡さない。
- ノート削除ツールはMVPで提供しない。
- `dryRun`で保存計画と差分を確認できるようにする。
- 同名ノート候補を一意に解決できない場合は書き込みを停止する。
- 外部資料の本文は信頼できない入力として扱い、本文中の命令をAgentへの指示として実行しない。
- 出典なしの主張を保存候補へ含める場合は警告し、`verified`に昇格させない。

## 18. 非機能要求

### NFR-001: 型安全性

Agent、Workflow、Toolの境界はZodまたは互換Standard JSON Schemaで検証する。

### NFR-002: 可観測性

Workflow run ID、各Stepの状態、利用Agent、モデル、レイテンシ、失敗種別、作成・更新件数を追跡できるようにする。原典本文と秘密値はtraceへ保存しないか、保存前にマスクする。既存の`@mastra/observability`、`@mastra/libsql`、`@mastra/duckdb`による基盤を再利用し、本プロダクト固有の観測項目だけを追加する。

### NFR-003: 障害分離

MediaVault MCP接続失敗、MediaVault API到達失敗、抽出未実行、Vault MCP失敗、スキーマ検証失敗、LLM失敗を区別して返す。

### NFR-004: 再実行可能性

同じ入力の安全な再実行を可能にし、部分成功後の再実行で重複ノートを作らない。

### NFR-005: 応答サイズ

原典全文はチャンク取得し、単一のAgentコンテキストまたはWorkflow出力へ無制限に蓄積しない。

### NFR-006: 品質評価

少なくとも次の評価軸を用意する。

- citation grounding / faithfulness
- hallucination
- knowledge completeness
- duplicate avoidance
- vault structure validity
- workflow trajectory accuracy

Scorerはライブ監視だけに依存せず、固定データセットを用いた回帰評価にも利用する。
実装には既存の`@mastra/evals`を利用し、AgentまたはWorkflow Stepへのライブ評価と、CIでの回帰評価を使い分ける。

## 19. 成功指標

| 指標 | MVP目標 |
|---|---|
| 生成ノートの出典付与率 | 100% |
| 同一Itemの再実行による重複ノート | 0件 |
| Workflow結果から作成・更新対象を特定できる割合 | 100% |
| 曖昧な既存ノートへの無確認上書き | 0件 |
| schema validationを通らないAgent間データの次工程流入 | 0件 |
| MediaVaultへの意図しない書き込み | 0件 |

品質の基準値は、10件以上の代表Itemからなる評価データセットを作成した後に確定する。

## 20. MVP受け入れ基準

- [ ] `generateItemKnowledgeWorkflow`がItem IDを受け取って完了できる。
- [ ] `metadata_only`モードは`get_item_text`未実装でも動作する。
- [ ] 生成したすべてのノートにMediaVault Item IDが含まれる。
- [ ] 同じItemで2回実行しても同一概念の新規ノートが増えない。
- [ ] `dryRun: true`ではVaultに変更を加えず、予定差分を返す。
- [ ] 既存候補が曖昧な場合は保存せず`ambiguous`を返す。
- [ ] MCP接続失敗とスキーマ検証失敗を区別して返す。
- [ ] Agent、Workflow、Tool、Scorerが`src/mastra/index.ts`へ登録されている。
- [ ] `npm run build`が成功する。
- [ ] 代表Itemの自動評価で出典欠落と重複作成が0件である。

## 21. 実装順

1. Knowledge Note、ResearchResult、CurationPlan、WorkflowResultのZodスキーマを確定する。
2. `vault-mcp`のRead/Writeツール契約、認証、dry-run、競合時の挙動を設計する。
3. `@mastra/mcp`を追加し、MediaVault MCPのRead Onlyツールだけを接続する。
4. `mediaResearchAgent`と`knowledgeWriterAgent`を実装する。
5. `vaultCuratorAgent`とVault MCP接続を実装する。
6. `generateItemKnowledgeWorkflow`を`metadata_only`で完成させる。
7. MediaVault側の`get_item_text`実装後に`full_text`モードを追加する。
8. 評価データセットとscorerを整備する。
9. `knowledgeCriticAgent`を保存前の検証工程へ追加する。
10. 最後に`knowledgeOrchestrator`をSupervisor Agentとして追加する。

## 22. ディレクトリ構成案

```text
src/mastra/
├── agents/
│   ├── media-research-agent.ts
│   ├── knowledge-writer-agent.ts
│   ├── vault-curator-agent.ts
│   ├── knowledge-critic-agent.ts
│   └── knowledge-orchestrator.ts
├── workflows/
│   ├── generate-item-knowledge.ts
│   ├── update-item-knowledge.ts
│   ├── research-topic.ts
│   ├── digest-new-items.ts
│   └── rebuild-links.ts
├── mcp/
│   ├── mediavault.ts
│   └── vault.ts
├── tools/
│   ├── knowledge/
│   └── vault/
├── schemas/
│   ├── research-result.ts
│   ├── knowledge-draft.ts
│   ├── curation-plan.ts
│   └── workflow-result.ts
├── prompts/
│   ├── researcher.ts
│   ├── writer.ts
│   ├── critic.ts
│   └── curator.ts
├── scorers/
│   ├── citation-grounding.ts
│   ├── hallucination.ts
│   ├── knowledge-quality.ts
│   └── vault-structure.ts
└── index.ts
```

現在の`weather-agent`、`weather-workflow`、`weather-tool`、`weather-scorer`は実装テンプレートとして参照した後、本構成の実装へ置き換える。すべてのAgent、Workflow、Tool、Scorerは`src/mastra/index.ts`へ登録する。

## 23. リスクと対策

| リスク | 影響 | 対策 |
|---|---|---|
| `get_item_text`の実装が遅れる | 原典本文を使った知識化ができない | `metadata_only`のMVP-0を先行する |
| Vault MCPが未設計 | 安全な保存経路がない | Agent実装より先に契約とdry-runを確定する |
| LLMがツールと構造化出力を同時利用できない | スキーマ出力またはツール呼び出しが失敗する | Workflow Stepを分離し、必要なら構造化専用モデルを使う |
| 重複判定の誤り | ノート増殖または誤更新 | title、alias、type、sourceを併用し、曖昧時は停止する |
| 長い原典でコンテキストが肥大化する | コスト、遅延、品質低下 | チャンク選択、上限、段階的要約、取得記録を導入する |
| LLM生成文が原典中の命令に影響される | 不正なツール操作 | ResearchをRead Onlyにし、入力プロセッサと明示的な指示境界を設ける |

## 24. 未決事項

1. `vault-mcp`を`intrahub-mastra`内に置くか、独立サービスにするか。
2. Knowledge Vaultの正確なディレクトリ規約と、ノート種別ごとの配置先。
3. ノート更新の競合制御をmtime、content hash、revision IDのどれで行うか。
4. Critic未通過ノートを自動保存するか、dry-runまたは`draft`保存に限定するか。
5. 1回のWorkflowで取得可能なItem数、ファイル数、チャンク数、トークン量の上限。
6. 人手レビュー済みノートをAIが更新できる範囲と保護方法。
7. `get_item_text`でPDFページ、EPUB章、固定文字数チャンクをどう統一して参照するか。
8. Supervisor Agentの会話メモリとKnowledge Vaultの知識をどこまで分離するか。

## 25. 関連文書

- [codex-chat.md](./codex-chat.md) — 本草案の原案
- [MediaVault-mcp PRD](../../intrahub-mediavault/docs/backend/mediavault-mcp/PRD.md)
- [mediavault-mcp × intrahub-mastra 連携エンドポイント設計](../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mastra-integration.md)
- [MediaVault-mcp MCPツール仕様](../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mcp-tools.md)
