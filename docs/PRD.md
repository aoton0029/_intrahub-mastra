# intrahub-mastra PRD（草案）

> ステータス: 草案。[docs/codex-chat.md](./codex-chat.md) の設計方針を土台に、エージェント構成・スコープ・MediaVault/Vault連携の要求をまとめる。API・スキーマの最終確定は各Agent/Workflow実装時の詳細設計に委ねる。

## 1. 概要

`intrahub-mastra` は、MediaVaultを情報源として **Knowledge Vault を生成・維持する知識処理層** である。MediaVaultをAI化する層ではなく、MediaVaultに集約された作品・資料を材料に、構造化された二次知識（Wiki的ノート）を作り、育てる。

役割分担:

```text
MediaVault   = 一次情報の正本（作品・ファイル・メタデータ）
intrahub-mastra = 知識生成ロジック（Agent / Workflow）
Knowledge Vault = 生成された知識の正本（Markdownノート）
```

MediaVault側のMCP（`mediavault-mcp`）は要約・Wiki・embeddingを所有せず、材料提供に徹する。生成物の正本は常にKnowledge Vaultに置く。

## 2. 背景と課題

- MediaVaultには映画・アニメ・書籍・論文・ゲームなど異種の資料が集約されているが、内容の横断的な整理・関連付けは手作業に依存している。
- 「攻殻機動隊について資料から整理して」のような依頼に対し、都度AIが資料を集めて回答するだけでは知識が蓄積されず、同じ調査を繰り返すことになる。
- 現在の `intrahub-mastra` はMastraの初期テンプレート（weather agent/workflow/tool）のままで、ストレージ・observability・LiteLLM経由のモデル接続基盤のみが整備済みの状態である。
- MediaVaultのMCPは目的単位ツールを志向しており（REST APIの単純な複製を避ける）、Vault側も同様に低レベルなfilesystem MCPではなく意味論を持ったツール設計が求められる。

## 3. 目的

- ユーザーの調査依頼を、資料収集・分析・執筆・構造管理という責務に分解し、それぞれ専門化したAgent/Workflowで処理する。
- MediaVaultの資料をKnowledge Vaultの知識ノートへ変換し、出典（MediaVault Item ID）を失わない。
- Vaultの肥大化・重複を防ぐため、知識の「内容生成」と「構造管理（新規/更新判定・配置・リンク）」を分離する。
- 決定的な手順で実行できる処理はWorkflowに、実行経路をAIが選ぶべき処理はAgentに分離する。
- 会話を重ねるほどKnowledge Vaultが自己成長する構造を作る。

## 4. 対象ユーザー

### 4.1 Vault所有者（ユーザー本人）

MediaVaultとKnowledge Vaultの両方を持つ単一ユーザー。チャットで調査・整理を依頼し、生成されたノートを閲覧・修正する。

### 4.2 スケジューラ／自動化トリガー

新規MediaVault Itemの取り込みや定期的なリンク再構築など、非対話的にWorkflowを起動する経路。MVP後の対象とする。

## 5. ユーザーストーリー

### US-01: トピックについてVaultの資料を整理してほしい

Vault所有者として、「攻殻機動隊について自分の持っている資料から整理して」のように依頼すると、既存Vaultノートを踏まえた上で、不足があればMediaVaultから資料を収集し、知識ノートとして整理してほしい。

期待する体験:

- 既にVaultに関連ノートがあれば重複調査せず、不足分だけを補う。
- MediaVault内の複数Item（原作・映画・論文など）を横断して事実・概念・関係を抽出する。
- 生成されたノートには出典（MediaVault Item ID）が付与される。

### US-02: 特定作品の知識ノートを生成してほしい

Vault所有者として、特定のMediaVault Item（例: ある映画）を指定し、その内容からWork/Concept/Personノートを生成してほしい。

期待する体験:

- 決定的な手順（取得→分析→執筆→検証→配置）で実行され、毎回同じ品質で処理される。
- 生成・更新されたノート一覧と出典が結果として返る。

### US-03: 既存ノートと重複しないでほしい

Vault所有者として、AIが生成するノートでVaultが同じ概念について何枚も似たファイルを作らないでほしい。

期待する体験:

- 新規作成前に既存ノートの検索・重複判定が行われる。
- 既存ノートがあればセクション追記や更新として扱われ、新規ファイルは作られない。
- 新規作成したノートと更新したノートが区別される。

### US-04: 出典のない断定を書かないでほしい

Vault所有者として、生成されたノートが資料に基づかない断定や、事実と解釈の混同を含まないでほしい。

期待する体験:

- 各主張に出典（MediaVault Item ID）が紐づく。
- 事実（Fact）・解釈（Interpretation）・推論（Inference）・意見（Opinion）が区別される。
- 出典から言えないことが書かれていないかが検証される。

### US-05: 資料を横断して関係性を尋ねたい

Vault所有者として、「押井守の映画で身体性についてどういう傾向がある？」のような、複数作品・複数資料を横断する問いに答えてほしい。

期待する体験:

- まずKnowledge Vault内の既存ノートを検索し、情報が不足していればMediaVaultから追加調査する。
- 回答と同時に、新たに得られた知見がVaultへ反映される（会話がVaultを育てる）。

## 6. プロダクト原則

1. **Research/Writer/Curatorを分離する**: 「資料に何が書かれているか」「どう知識単位に整理するか」「Vault構造をどう管理するか」を別々の責務にする。
2. **構造化データで受け渡す**: Agent間の連携はMarkdown本文ではなく、Zodスキーマで検証された構造化データ（`ResearchResult`等）で行う。
3. **決定的な処理はWorkflowにする**: 実行手順が固定できる処理（Item単位の知識生成など）はAgent Networkに任せず、Mastra Workflowとして実装する。
4. **低レベルツールを上位Agentに渡さない**: `knowledgeOrchestrator` のような対話窓口のAgentには、ファイル操作やAPI呼び出しの低レベルツールを直接持たせない。専門Agent/Workflow経由にする。
5. **MediaVaultへは書き込まない**: 知識生成の結果としてMediaVault側のデータ（視聴記録・タグ等）を変更しない。書き込みが必要な操作はユーザーの明示的な指示に基づく別経路とする。
6. **Vaultは意味論を持ったMCPで操作する**: `write_file` のような低レベル操作をAgentに渡さず、`create_note` / `update_note` / `find_related_notes` 等、目的単位のツールを介して操作する。
7. **provenanceを失わない**: MediaVault Item → Knowledge Note → 他Knowledge Note の追跡関係を、frontmatterのsourcesとしてノートに保持する。
8. **メディア種別ごとにAgentを増やさない**: `mediaResearchAgent` を種別ごとに分割せず、instruction/skillの差分で対応する。

## 7. スコープ

### 7.1 MVP

| 種別 | 名前 | 責務 | MediaVault | Vault |
|---|---|---|---|---|
| Agent | `mediaResearchAgent` | MediaVaultから資料収集・構造化分析（`ResearchResult`を出力） | Read | — |
| Agent | `knowledgeWriterAgent` | 構造化データから知識ノート本文を生成 | — | Read |
| Agent | `vaultCuratorAgent` | 既存ノート検索・重複判定・配置・frontmatter/リンク生成 | — | Read/Write |
| Workflow | `generateItemKnowledgeWorkflow` | Item指定→取得→調査→執筆→配置までを決定的に実行 | Read | Write |

MVPの完了条件:

- US-02（特定Itemからの知識ノート生成）が `generateItemKnowledgeWorkflow` として一気通貫で動作する。
- 生成ノートに出典（MediaVault Item ID）とprovenance（generated_by等）が付与される。
- 既存ノートがある場合に重複作成せず更新される（US-03）。
- MediaVault MCP・Vault MCPへの接続は認証済み経路のみで行われる。

### 7.2 第2段階

| 種別 | 名前 | 責務 |
|---|---|---|
| Agent | `knowledgeCriticAgent` | 出典整合性・事実/解釈混同・過度な一般化のチェック（Writer→Critic→Curatorの間に挿入） |
| Agent | `knowledgeOrchestrator` | ユーザーとの対話窓口。意図を解析しWorkflow/Agentへ委譲（US-01, US-05） |
| Workflow | `researchTopicWorkflow` | トピック単位でVault検索→不足分をMediaVault調査→複数ノート更新 |
| Workflow | `updateItemKnowledgeWorkflow` | 既存ノートの差分更新 |
| Workflow | `digestNewItemsWorkflow` | 新規MediaVault Itemの定期的な知識化 |

### 7.3 将来候補

- `filmAnalysisAgent` / `literatureAnalysisAgent` 等、メディア種別特化の分析（instruction/skill方式が限界に達した場合のみ検討）
- Knowledge Vaultのベクトル検索（RAG）基盤の整備
- `rebuildLinksWorkflow` によるVault全体のリンク・backlink再構築
- MCP Resourcesを用いたKnowledge Vaultの読み取り専用公開

## 8. Agent間データ連携

`mediaResearchAgent` の出力はMarkdownではなく構造化データとする。

```ts
type ResearchResult = {
  topic: string;
  sources: {
    itemId: string;
    title: string;
    mediaType: string;
    fileId?: string;
    extractedAt?: string;
  }[];
  facts: { statement: string; sourceItemIds: string[]; confidence: number }[];
  concepts: { name: string; description: string; sourceItemIds: string[] }[];
  relationships: { from: string; to: string; relation: string; evidence: string }[];
  uncertainties: string[];
};
```

`knowledgeWriterAgent` はこれを受け取り、ノート種別（SourceNote/ConceptNote/WorkNote/PersonNote/TopicNote/ComparisonNote/TimelineNote/EssayNote）に応じた本文を生成する。`vaultCuratorAgent` は生成された本文と既存Vaultの状態を突き合わせ、新規作成/更新/配置/リンクを決定する。

## 9. Knowledge Vaultのデータモデル（共通frontmatter）

```yaml
---
id: kh_01...
title: ゴースト
type: concept
aliases: [ghost]
tags: [philosophy, ghost-in-the-shell]
sources:
  - type: mediavault
    item_id: "..."
    file_id: "..."
related: ["[[攻殻機動隊]]", "[[電脳化]]"]
provenance:
  generated_by: knowledge-writer
  reviewed_by: knowledge-critic
  generated_at: 2026-08-11T00:00:00Z
status: verified
---
```

## 10. Tool/MCPの境界

```text
Mastra
├─ MediaVault MCP（外部、既存の mediavault-mcp）
│   ├─ search_library / get_item_context / get_item_text（Read Only）
│   └─ jobs系（第2段階、必要な場合のみ）
│
├─ Vault MCP（新設、intrahub-mastra側または別リポジトリで実装）
│   ├─ search_notes / read_note
│   ├─ create_note / update_note / move_note
│   └─ list_links / get_backlinks
│
└─ Internal Tools（intrahub-mastra内）
    ├─ normalizeKnowledge / validateFrontmatter
    └─ calculateNotePath / diffNote
```

`mediaResearchAgent` にはMediaVault MCPのうちRead系ツールのみを渡す。`create_item` / `update_consumption` / `organize_item` / `relate_items` 等の書き込み系ツールは、知識生成の文脈では一切渡さない（§6原則5）。

## 11. RAGの位置づけ

Knowledge VaultとMediaVaultの検索優先順位:

```text
1. Knowledge Vault（既に整理済みの二次知識）
2. 不足時のみMediaVault（一次情報）
3. 必要なら全文取得（get_item_text）
4. 新しい知見が得られたらVaultへ反映
```

Knowledge Vaultはsemantic cacheではなく「整理済み二次知識」として扱う。`Vault = derived knowledge`、`MediaVault = source of truth` の関係を維持する。ベクトルDBによる索引化はMVP後の検討事項とする。

## 12. 安全性と権限に関する要求

- MediaVault MCP・Vault MCPへの接続は認証必須の経路のみを用いる。
- `mediaResearchAgent` にMediaVaultの書き込み系ツールを渡さない。
- Vault側の書き込み（`create_note`/`update_note`/`move_note`）は `vaultCuratorAgent` のみが実行し、他のAgentが直接ファイル操作しない。
- 生成ノートには必ずsources（出典）とprovenance（生成元Agent・レビュー有無）を持たせ、出典のない断定を許可しない。
- 曖昧な対象（同名ノート・同名概念）への上書きは行わず、Curatorが候補を提示して処理を止める。

## 13. 非機能要求

- Agent間のやり取りはZodスキーマで検証し、自由形式のMarkdownをそのまま次のAgentへ渡さない。
- 生成・更新されたノート数、出典数、失敗した部分をWorkflowの出力として構造化して返す。
- 既存のscorer/observability/storage基盤（`@mastra/evals`, `@mastra/observability`, `@mastra/libsql`）を活用し、`citation-grounding` / `hallucination` / `knowledge-quality` / `vault-structure` のスコアラーを実装する。
- MediaVault MCPまたはVault MCPが利用不能な場合、接続エラーとツール実行エラーを区別してWorkflow呼び出し元へ返す。

## 14. 成功指標（初期案）

- Item指定の知識ノート生成（`generateItemKnowledgeWorkflow`）が、資料取得から配置まで人手を介さず完結する。
- 生成ノートの100%に出典（MediaVault Item ID）が付与される。
- 同一概念に対する重複ノート作成が自動テスト上0件である。
- Writerが生成した文章のうち、出典から言えない断定がCriticにより検出される（第2段階導入後）。

## 15. やらないこと（MVP）

- MediaVault側のデータ変更（視聴記録・タグ・関連付け等）
- Knowledge VaultのベクトルDB/RAG基盤構築
- メディア種別ごとの専用Agent分割
- `knowledgeOrchestrator` によるマルチターン対話の意図解析（MVPは `generateItemKnowledgeWorkflow` の単発実行が対象）
- Vaultノートの削除・統合の自動化

## 16. 実装順

1. `vault-mcp` のRead/Write API（ツール）を決める。
2. MediaVault MCP Client（`@mastra/mcp`、現状未依存のため追加が必要）をMastraへ接続する。
3. `mediaResearchAgent` を実装する。
4. `knowledgeWriterAgent` を実装する。
5. `generateItemKnowledgeWorkflow` を実装する（MVPの完成形）。
6. `vaultCuratorAgent` を追加する。
7. `knowledgeCriticAgent` を追加する。
8. `knowledgeOrchestrator` を追加し、各Workflow/Agentを束ねる。

## 17. ディレクトリ構成（案）

```text
src/mastra/
├── agents/
│   ├── media-research-agent.ts
│   ├── knowledge-writer-agent.ts
│   ├── vault-curator-agent.ts
│   ├── knowledge-critic-agent.ts        # 第2段階
│   └── knowledge-orchestrator.ts        # 第2段階
├── workflows/
│   ├── generate-item-knowledge.ts
│   ├── update-item-knowledge.ts         # 第2段階
│   ├── research-topic.ts                # 第2段階
│   └── digest-new-items.ts              # 第2段階
├── mcp/
│   ├── mediavault.ts
│   └── vault.ts
├── tools/
│   ├── knowledge/
│   │   ├── normalize-knowledge.ts
│   │   ├── validate-sources.ts
│   │   └── diff-knowledge.ts
│   └── vault/
│       └── validate-frontmatter.ts
├── schemas/
│   ├── research-result.ts
│   ├── knowledge-note.ts
│   └── provenance.ts
├── prompts/
│   ├── researcher.ts
│   ├── writer.ts
│   ├── critic.ts                        # 第2段階
│   └── curator.ts
├── scorers/
│   ├── citation-grounding.ts
│   ├── hallucination.ts
│   ├── knowledge-quality.ts
│   └── vault-structure.ts
└── index.ts
```

現在の `weather-*` テンプレート（agent/workflow/tool）はこの構成へ置き換える。

## 関連文書

- [docs/codex-chat.md](./codex-chat.md) — 本PRDの検討過程となった設計メモ
- [../intrahub-mediavault/docs/backend/mediavault-mcp/PRD.md](../../intrahub-mediavault/docs/backend/mediavault-mcp/PRD.md) — MediaVault-mcp PRD
- [mediavault-mcp向け連携エンドポイント設計](../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mastra-integration.md)
