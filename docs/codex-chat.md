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
| Knowledge Vault | Obsidianで利用する整理済み知識の正本 |
| `ai-workspace` | 章分割、下書き、レビュー結果など再生成可能な中間データ |

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

# Knowledge Vaultの構成

実環境では`/srv/knowledge`をMastraへ`/workspace`としてマウントする。

```text
/srv/knowledge/
├── ai-workspace/               # 中間データ
└── second-brain/               # Obsidian Vault
    ├── 00 Inbox/               # 人手確認が必要なノート
    ├── 10 Sources/             # 資料単位のノート
    │   ├── Works/
    │   ├── Papers/
    │   ├── Academic Books/
    │   └── Web/
    ├── 20 Knowledge/           # 再利用する知識
    │   ├── Concepts/
    │   ├── Themes/
    │   ├── People/
    │   ├── Organizations/
    │   └── Events/
    ├── 30 Syntheses/           # 比較・年表・論考
    ├── 40 Maps/                # MOC・索引
    ├── 90 Meta/                # テンプレート、分類、検証レポート
    └── Attachments/            # Vault固有の小規模な添付
```

ディレクトリは閲覧上の大分類に留め、ノート種別はfrontmatterの`type`で管理する。

## ノート種別

| 種別 | 用途 |
|---|---|
| `work` | 作品全体の概要、構成、主題、関連資料 |
| `episode` | 話数ごとの要約、批評、作品内での位置づけ |
| `paper` | 論文全体の書誌情報、主張、章一覧 |
| `academic_book` | 専門書全体の書誌情報、主張、章一覧 |
| `chapter` | 章・節ごとの要約、根拠、重要語 |
| `concept` | 「唯識」などの専門用語・概念 |
| `theme` | 複数資料を横断する問い・テーマ |
| `person` | 人物と作品・概念との関係 |
| `comparison` | 複数の作品、定義、理論の比較 |
| `timeline` | 出来事や研究史の時系列整理 |
| `essay` | 出典に基づく統合的な論考 |

## 作品と話数

作品全体と話数を分離し、長編作品でもノートが肥大化しない構成にする。

```text
10 Sources/Works/{作品名}/
├── index.md
└── Episodes/
    ├── S01E01 {話数タイトル}.md
    └── S01E02 {話数タイトル}.md
```

話数ノートは、要約、構成、登場人物、主題、批評、作品全体での位置づけ、関連ノート、出典を持つ。要約は原典に明示された内容、批評は解釈として区別する。MediaVault上の話数と原典ファイルを一意に対応づけられない場合は推測で確定せず、確認対象とする。

## 論文・専門書

論文と専門書は資料全体の`index.md`と、章・節単位のノートに分ける。

```text
10 Sources/Papers/{著者}-{年}-{短縮タイトル}/
├── index.md
└── Sections/

10 Sources/Academic Books/{著者}-{年}-{短縮タイトル}/
├── index.md
└── Chapters/
```

章ノートは、章の目的、要約、主要な主張、根拠・事例、重要語、疑問・反論、出典を持つ。章境界は抽出結果のラベルや目次を優先し、OCR本文から推定した場合は人手確認の対象にする。

## テーマ・専門用語

ThemeとConceptは作品、論文、専門書、Web資料を横断する。

Themeノートでは、問い、対象範囲、資料ごとの定義、共通点と相違点、歴史的文脈、作品例、論争点、暫定的な結論を整理する。Conceptノートでは、定義、原語、別名、系譜、主要概念、学説上の相違、用例、誤解しやすい点を整理する。

Web検索結果は補助資料として扱い、検索結果のスニペットだけを根拠にしない。可能な限り一次資料、査読論文、専門書を優先する。

# メタデータと出典

全ノートは共通frontmatterを持つ。

```yaml
---
id: kv_01J...
title: 唯識
type: concept
aliases: []
categories: [philosophy]
tags: [buddhism]
status: reviewed
sources:
  - kind: mediavault
    item_id: "..."
    file_id: "..."
    extraction_version: "pdf-v1"
source_refs:
  - source: 0
    chunk_index: 12
    label: p.42-44
provenance:
  workflow: research-topic
  run_id: "..."
  model: "..."
---
```

出典は`item_id`、`file_id`、`extraction_version`、`chunk_index`の組み合わせで追跡する。`label`はページや章を表示するための補助情報とする。再抽出によって`extraction_version`が変わった場合は既存参照を自動的に読み替えず、再確認対象にする。

| `status` | 意味 |
|---|---|
| `draft` | AI生成直後 |
| `review_needed` | 出典不足、推定、競合などがある |
| `reviewed` | 機械的な検証を通過 |
| `human_verified` | 人間が内容を確認済み |
| `stale` | 出典参照が失効している |

# タグ・カテゴリの管理

- `type`: ノートの構造を決める種別
- `categories`: 少数の大分類
- `tags`: 横断検索に使用する特徴語
- Wikilink: 作品、人物、概念など実体間の関係

正規のカテゴリ・タグと表記揺れは`90 Meta`のtaxonomyで管理する。自動管理は候補生成、既存語彙への正規化、差分検証、適用の順で行う。

- 本文と出典に根拠があるタグだけを追加する。
- 未登録語は直ちに正式タグにせず、提案として蓄積する。
- 同義語はaliasへ統合する。
- 人間が追加したタグは既定で保護する。
- タグが再生成されなかったという理由だけでは削除しない。
- タグ削除やtaxonomyの統合は原則として確認対象にする。

MediaVault側のタグ・カテゴリとは別の分類体系として扱い、Knowledge Vault側の整理結果をMediaVaultへ自動反映しない。

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

Vault更新時は既存ノートとの重複、出典、frontmatter、リンク、編集競合を確認する。競合や低信頼な結果は上書きせず`00 Inbox`または検証レポートへ送る。

`/srv/knowledge`は既存運用どおりGitで履歴を保存し、人手編集やAI更新から復旧できるようにする。

