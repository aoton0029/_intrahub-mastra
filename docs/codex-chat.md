# Knowledge Vault設計方針

## 目的

`intrahub-mastra`を、MediaVaultや外部資料からKnowledge Vaultを生成・維持する知識処理層とする。

主な用途は次のとおり。

- 作品全体および話数ごとの要約・批評
- 論文・専門書の章ごとの要約
- 作品、論文、専門書、Webを横断したテーマ・専門用語の整理
- タグ、カテゴリ、リンクの生成と整理
- Knowledge Vaultを利用した検索・回答と継続的な更新

## 責務の境界

| 対象 | 責務 |
|---|---|
| MediaVault | 作品・文献のメタデータ、ファイル参照、抽出済みテキストを管理するサービス |
| intrahub-mastra | 資料収集、分析、要約、批評、知識統合、Vault更新の制御 |
| Knowledge Vault (`second-brain`) | 作品・文献など外部資料に由来する整理済み知識の正本 |
| `tech-notes` | 開発を通じて得た技術知識と設計判断の正本 |
| `ai-workspace` | 章分割、下書き、レビュー結果など再生成可能な中間データ |

`second-brain`と`tech-notes`は目的も出典の形も異なるため、単一Vaultに統合しない。`second-brain`の出典は書誌情報とMediaVaultの抽出結果であり、`tech-notes`の出典はコミット、変更差分、実際に観測した挙動である。横断検索はディレクトリの統合ではなく、Vault MCPが複数のVaultルートを対象にすることで実現する。

PDF、映像、OCR全文はKnowledge Vaultへ複製しない。Vaultには、それらから生成した知識と出典参照を保存する。Knowledge生成を理由にMediaVaultのItem、評価、視聴状況、タグ、カテゴリを変更しない。

## 全体構成

```text
User / Scheduler
        │
        ▼
Knowledge Orchestrator
        │
        ├── Media Research ── MediaVault MCP
        ├── Knowledge Writer
        ├── Knowledge Critic
        └── Vault Curator ─── Knowledge Vault
```

決まった手順を持つ処理はWorkflowとし、ユーザー要求に応じたWorkflowの選択と組み合わせをOrchestratorが担当する。

## Agentの責務

| Agent | 責務 |
|---|---|
| `knowledgeOrchestrator` | 要求の解釈、既存知識の確認、Workflowの選択 |
| `mediaResearchAgent` | MediaVaultや外部資料の検索、出典付き調査結果の作成 |
| `knowledgeWriterAgent` | 調査結果をノート種別に応じた知識へ変換 |
| `knowledgeCriticAgent` | 出典、事実と解釈、矛盾、過度な一般化の検証 |
| `vaultCuratorAgent` | 重複判定、配置、frontmatter、タグ、リンク、更新差分の管理 |

Agent間ではMarkdownを直接受け渡さず、出典、主張、概念、関係、不確実性を含む構造化データを使用する。

## ToolとMCPの境界

```text
Mastra
├── MediaVault MCP
│   ├── search_library
│   ├── get_item_context
│   └── get_item_text
├── Vault MCP
│   ├── search_notes
│   ├── read_note
│   ├── create_note
│   ├── update_note
│   └── find_related_notes
└── Internal Tools
    ├── frontmatter検証
    ├── 出典検証
    ├── パス決定
    └── 差分生成
```

Media ResearchにはMediaVaultのRead Onlyツールだけを渡す。Vault操作は汎用ファイル操作ではなく、ノートの作成・更新・検索という意味を持つ操作として公開する。

Vault MCPは`second-brain`と`tech-notes`の両方をVaultルートとして扱う。`search_notes`と`find_related_notes`は既定で両方を横断し、`create_note`と`update_note`は対象Vaultの明示を必須とする。

# Knowledge Vaultの構成

Vaultのディレクトリ構成、命名ルール、編集領域の分離、ノート種別、frontmatter、タグ・カテゴリの規約は、Vault側のリポジトリが正本として持つ。

- `KnowledgeVault/README.md`（実環境では`/srv/knowledge/README.md`）

本書はそれを生成・更新する側の設計を扱う。Vaultの規約を変更する場合はREADMEを更新し、本書には写さない。二箇所に同じ規約を置くと、必ず片方が古くなる。

# 主要Workflow

| Workflow | 用途 |
|---|---|
| `generateWorkKnowledgeWorkflow` | 作品全体ノートの生成・更新 |
| `generateEpisodeKnowledgeWorkflow` | 話数ごとの要約・批評 |
| `summarizeDocumentWorkflow` | 論文・専門書の章分割と階層要約 |
| `researchTopicWorkflow` | テーマ・専門用語の横断調査 |
| `curateTaxonomyWorkflow` | タグ、カテゴリ、リンクの整理 |
| `refreshStaleSourcesWorkflow` | 失効した出典参照の再調査 |
| `digestNewItemsWorkflow` | MediaVaultへ追加された資料の処理 |

OCR文献は、全文を一度にLLMへ渡さず、チャンク、章、文献全体の順で階層的に要約する。各段階で元の出典参照を維持する。

# 検索と更新

回答時は、Knowledge Vault、MediaVault、必要に応じてWebなどの外部資料の順で検索する。新しい知識は検証後にKnowledge Vaultへ反映する。

Vault更新時は既存ノートとの重複、出典、frontmatter、リンク、編集競合を確認する。競合や低信頼な結果は上書きせず`00-Inbox`または検証レポートへ送る。

`/srv/knowledge`は既存運用どおりGitで履歴を保存し、人手編集やAI更新から復旧できるようにする。

