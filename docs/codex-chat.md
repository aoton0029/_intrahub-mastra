現状の2リポジトリを見る限り、`intrahub-mastra` は「MediaVaultをAI化する層」ではなく、**MediaVaultを情報源としてKnowledge Vaultを生成・維持する知識処理層**にするのがよいです。

MediaVault側のPRDでも、MCPは要約・Wiki・embeddingを所有せず、生成物の正本はKnowledgeHub Vaultに置く、と明確に分離されています。KnowledgeHubエージェントは `get_item_context` / `get_item_text` で材料を取得し、Vault側へ保存する想定です。 

一方、現在の `intrahub-mastra` はMastraの初期テンプレートに近く、weather agent / workflow / toolが残っている状態です。ストレージ、observability、LiteLLM経由のモデル接続基盤はすでに使える形になっています。 

なので、次の構成を推します。

```text
                     ┌─────────────────────┐
                     │ User / Scheduler    │
                     └──────────┬──────────┘
                                │
                     ┌──────────▼──────────┐
                     │ Knowledge Orchestrator
                     │     Agent           │
                     └──────────┬──────────┘
                                │
            ┌───────────────────┼─────────────────────┐
            │                   │                     │
    ┌───────▼────────┐  ┌──────▼────────┐   ┌───────▼────────┐
    │ Research Agent │  │ Knowledge      │   │ Vault Curator  │
    │                │  │ Writer Agent   │   │ Agent          │
    └───────┬────────┘  └──────┬────────┘   └───────┬────────┘
            │                   │                     │
       MediaVault MCP      structured data        Vault MCP
            │                   │                     │
     ┌──────▼──────┐            │              ┌─────▼─────┐
     │ MediaVault  │            └─────────────►│Knowledge  │
     │ API/files   │                           │Vault      │
     └─────────────┘                           └───────────┘
```

## 1. 最上位は `KnowledgeOrchestratorAgent`

これはユーザーと直接話す唯一のエージェントにします。

役割は「回答する」ことより、**要求を知識処理タスクへ分解すること**です。

例えば、

> 攻殻機動隊について自分の持っている資料から整理して

という入力なら、

```text
KnowledgeOrchestrator

1. Vaultに既存ノートがあるか調査
2. MediaVaultから攻殻機動隊関連Item検索
3. 関連する本・映画・アニメ・論文を取得
4. 必要なら全文取得
5. Research Agentへ分析依頼
6. Knowledge Writerへノート生成依頼
7. Curatorへリンク・タグ・配置依頼
8. ユーザーへ結果を返す
```

と判断します。

重要なのは、このAgent自身にはできるだけ低レベルツールを直接渡さないことです。

Mastraでは複数Agent/Workflowを動的にルーティングする構成が可能で、実行経路が不定な仕事はAgent Network、決まった処理はWorkflowに向いています。 

ただし最初から巨大なAgent Networkにする必要はありません。

むしろ、

```text
Supervisor Agent
   ↓
専門Agent
   ↓
Workflow
   ↓
Tool/MCP
```

という4層にします。

---

## 2. `MediaResearchAgent`

これはMediaVault専属です。

責務：

```text
・作品を探す
・関連作品を辿る
・資料を集める
・全文を取得する
・出典を管理する
・複数資料を比較する
```

使用可能ツールは原則Read Only。

MediaVault PRDにある、

```text
search_library
get_item_context
get_item_text

将来的に
get_job
list_jobs
enqueue_job
```

だけで十分です。MediaVaultのMCPはREST APIをそのまま公開せず、目的単位ツールにする設計なので、このAgentとの相性がよいです。 

逆に、

```text
create_item
update_consumption
organize_item
relate_items
```

などはResearch Agentには渡さない方がいいです。

ResearchAgentの出力は自然文ではなく、例えばこうします。

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

  facts: {
    statement: string;
    sourceItemIds: string[];
    confidence: number;
  }[];

  concepts: {
    name: string;
    description: string;
    sourceItemIds: string[];
  }[];

  relationships: {
    from: string;
    to: string;
    relation: string;
    evidence: string;
  }[];

  uncertainties: string[];
};
```

ここがかなり重要です。

**Research Agent → Writer AgentをMarkdownで繋がない**ことを勧めます。

構造化データで渡します。

---

## 3. `KnowledgeWriterAgent`

Vaultに保存可能な「知識」に変換するAgentです。

Research Agentと役割を分けます。

Research Agent：

```text
資料に何が書かれているか
```

Writer Agent：

```text
それをどういう知識単位に整理するか
```

を担当します。

生成対象は一種類にしない方がよいです。

例えば：

```text
SourceNote
ConceptNote
WorkNote
PersonNote
TopicNote
ComparisonNote
TimelineNote
EssayNote
```

とします。

例えば『攻殻機動隊』なら、

```text
works/
  攻殻機動隊.md

concepts/
  ゴースト.md
  電脳化.md
  義体化.md

people/
  士郎正宗.md
  押井守.md

topics/
  攻殻機動隊における身体と自己.md
```

のようになります。

ここで単なる「作品Wiki」を生成させないのがポイントです。

Knowledge Vaultなので、

```text
作品
人物
概念
出来事
主張
引用
テーマ
関係
```

を知識単位にできるようにします。

---

## 4. `VaultCuratorAgent`

これはかなり重要です。

Writerが文章を書き、Curatorが**Vaultの構造を管理する**ように分離します。

担当：

```text
・既存ノート検索
・重複検出
・新規/更新判定
・ファイル名決定
・ディレクトリ決定
・タグ付与
・frontmatter生成
・wikilink生成
・backlink候補生成
・alias統合
```

例えばWriterが、

```text
ゴーストとは攻殻機動隊世界における……
```

と生成した場合、

Curatorは、

```text
既存:
concepts/ゴースト.md

→ 新規作成しない
→ 既存ノートへsection追加
```

と判断します。

つまり、

```text
Writer = Knowledge Content
Curator = Knowledge Structure
```

です。

この分離によってVaultがAI生成ファイルで爆発するのを防げます。

---

## 5. `KnowledgeCriticAgent`

これはMVP後でもよいですが、かなり有用です。

チェックだけします。

```text
Writer
   ↓
Critic
   ↓
Curator
```

チェック項目：

```text
出典があるか
出典から言えないことを書いていないか
事実と解釈を混同していないか
既存知識と矛盾していないか
過度に一般化していないか
リンク対象が適切か
```

特にあなたのVaultでは映画・漫画・本・論文など異種資料を扱うので、

```text
Fact
Interpretation
Inference
Opinion
```

を区別させるとかなり価値があります。

例えばfrontmatterにも、

```yaml
knowledge_type: concept
confidence: high

sources:
  - mediavault:item:019...
  - mediavault:item:01a...

generated:
  agent: knowledge-writer
  model: wiki-model
  reviewed_by: knowledge-critic
```

のようなprovenanceを残します。

MediaVault PRDでも、生成ノートから元Itemを追跡できることを重視しています。 

---

# AgentよりWorkflowにするべき処理

ここは重要です。

全部Agentにしない方がいいです。

例えば「作品からWikiを作る」は実行手順がほぼ確定しています。

なので、

```text
generateItemKnowledgeWorkflow

input
  itemId

↓ getItemContext

↓ getItemText

↓ researchAgent

↓ knowledgeWriterAgent

↓ criticAgent

↓ vaultCuratorAgent

↓ vault.write

output
  createdNotes
  updatedNotes
  sources
```

と deterministic workflow にします。

Mastra自身も、処理順序が決まっている場合はWorkflow、実行経路をAIに選択させたい場合はAgent Networkを使うという整理をしています。 

同様に、

```text
generateItemKnowledgeWorkflow
updateItemKnowledgeWorkflow
researchTopicWorkflow
digestNewItemsWorkflow
rebuildLinksWorkflow
```

を作ります。

---

# 推奨する最終Agent構成

最初は5体で十分です。

| Agent | 責務 | MediaVault | Vault |
|---|---|---|---|
| `knowledgeOrchestrator` | 意図理解・委譲 | 間接 | 間接 |
| `mediaResearchAgent` | 資料収集・分析 | Read | Read |
| `knowledgeWriterAgent` | 知識文章生成 | なし | Read |
| `vaultCuratorAgent` | Vault構造管理 | なし | Read/Write |
| `knowledgeCriticAgent` | 出典・整合性検証 | Read | Read |

これ以上細分化するのは後からでよいです。

例えば将来的に、

```text
filmAnalysisAgent
literatureAnalysisAgent
gameAnalysisAgent
academicResearchAgent
```

を作ることはできます。

ただし最初からメディア種別ごとにAgentを作るのは避けます。

代わりに、

```text
mediaResearchAgent
   +
media-specific instructions / skills
```

にした方が保守しやすいです。

---

# Tool/MCPの境界

私ならこう切ります。

```text
Mastra
│
├─ MediaVault MCP
│   ├─ search_library
│   ├─ get_item_context
│   ├─ get_item_text
│   └─ jobs...
│
├─ Vault MCP
│   ├─ search_notes
│   ├─ read_note
│   ├─ create_note
│   ├─ update_note
│   ├─ move_note
│   ├─ list_links
│   └─ get_backlinks
│
└─ Internal Tools
    ├─ normalizeKnowledge
    ├─ validateFrontmatter
    ├─ calculateNotePath
    └─ diffNote
```

MastraはMCPClient経由でMCP serverのtools/resourcesをAgentへ渡せます。現在の `intrahub-mastra` には `@mastra/mcp` がまだ依存関係にないので、MediaVault MCP接続を実装する段階で追加することになります。 

特に、

**Vaultを単純なfilesystem MCPとして渡すのはあまり勧めません。**

`write_file` のような低レベルツールではなく、

```text
create_note
update_note
find_related_notes
search_notes
resolve_note
```

くらいの意味論を持った `vault-mcp` を作る方が安全です。

これはMediaVault MCPの「REST APIをそのままAIへ公開しない」という設計思想とも揃います。 

---

# Knowledge Vaultのデータモデル

Markdown本文だけでなく、最低限このfrontmatterを共通化するとよいです。

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
    
related:
  - "[[攻殻機動隊]]"
  - "[[電脳化]]"

provenance:
  generated_by: knowledge-writer
  reviewed_by: knowledge-critic
  generated_at: 2026-08-11T00:00:00Z

status: verified
---
```

そして本文は、

```markdown
# ゴースト

## 概要

## 定義

## 作品内での扱い

## 解釈

## 関連概念

## 出典
```

程度にします。

重要なのは、

```text
MediaVault ID
       ↓
Knowledge Note
       ↓
他Knowledge Note
```

というprovenance graphを失わないことです。

---

# RAGはどこに置くか

ここもMastraのAgentとは分離した方がいいです。

```text
                Knowledge Vault
                     │
              index / chunk
                     │
                Vector DB
                     │
User ──► Orchestrator ──► Knowledge Retrieval
                     │
                     └──► MediaVault Research
```

つまり検索順序は原則、

```text
1. Knowledge Vault RAG
2. 足りなければMediaVault
3. 必要なら全文
4. 新しい知識が得られたらVault更新
```

です。

毎回MediaVaultの原典から回答すると重いので、Knowledge Vaultを**semantic cacheではなく「整理済み二次知識」**として利用します。

ただし、

```text
Vault = derived knowledge
MediaVault = source of truth
```

という関係は維持します。

---

# 質問への処理例

ユーザー：

> 押井守の映画で身体性についてどういう傾向がある？

処理：

```text
Orchestrator
 │
 ├─ Vault検索
 │    ├─ [[押井守]]
 │    ├─ [[身体性]]
 │    └─ 関連ノート
 │
 └─ 情報不足を検出
      │
      ▼
 ResearchAgent
      │
      ├─ MediaVault search_library
      │      ├─ 攻殻機動隊
      │      ├─ イノセンス
      │      └─ ...
      │
      ├─ get_item_context
      └─ get_item_text
             │
             ▼
      structured ResearchResult
             │
      ┌──────┴───────┐
      ▼              ▼
   Writer          Answer
      │
    Critic
      │
   Curator
      │
 Vault更新
```

この構造にすると、ユーザーとの会話そのものがVaultを徐々に育てます。

---

# ディレクトリ構成

現在の `weather-*` を置き換えて、私はこうします。

```text
src/mastra/
├── agents/
│   ├── knowledge-orchestrator.ts
│   ├── media-research-agent.ts
│   ├── knowledge-writer-agent.ts
│   ├── knowledge-critic-agent.ts
│   └── vault-curator-agent.ts
│
├── workflows/
│   ├── generate-item-knowledge.ts
│   ├── update-item-knowledge.ts
│   ├── research-topic.ts
│   ├── digest-new-items.ts
│   └── curate-vault.ts
│
├── mcp/
│   ├── mediavault.ts
│   └── vault.ts
│
├── tools/
│   ├── knowledge/
│   │   ├── normalize-knowledge.ts
│   │   ├── validate-sources.ts
│   │   └── diff-knowledge.ts
│   └── vault/
│       └── validate-frontmatter.ts
│
├── schemas/
│   ├── research-result.ts
│   ├── knowledge-note.ts
│   └── provenance.ts
│
├── prompts/
│   ├── researcher.ts
│   ├── writer.ts
│   ├── critic.ts
│   └── curator.ts
│
├── models/
│   └── litellm.ts
│
├── scorers/
│   ├── citation-grounding.ts
│   ├── hallucination.ts
│   ├── knowledge-quality.ts
│   └── vault-structure.ts
│
└── index.ts
```

今の `intrahub-mastra` にはすでにscorer/observability/storageの基盤があるので、特にScorerは活用した方がいいです。 

---

## 実装順

一気にMulti-Agent化するより、次の順が安定します。

1. `vault-mcp` のRead/Write APIを決める。
2. `MediaVault MCP Client` をMastraへ接続。
3. `mediaResearchAgent` を作る。
4. `knowledgeWriterAgent` を作る。
5. `generateItemKnowledgeWorkflow` を作る。
6. `vaultCuratorAgent` を追加。
7. `knowledgeCriticAgent` を追加。
8. 最後に `knowledgeOrchestrator` を作って各Workflow/Agentを束ねる。

特に最初の完成形は、

```text
MediaVault
   ↓
ResearchAgent
   ↓
WriterAgent
   ↓
CuratorAgent
   ↓
Knowledge Vault
```

だけで十分です。

その後、

```text
Knowledge Vault
     ↑       ↓
     └ Orchestrator
           ↓
       MediaVault
```

という自己成長型のKnowledge Vaultに発展させるのが、この2リポジトリの現在の設計と最も整合します。MediaVaultは原典・メタデータの正本、Mastraは知識生成ロジック、Knowledge Vaultは生成された知識の正本、という3者分離です。 

次に詰めるなら、`intrahub-mastra` にそのまま実装できるレベルまで、**各Agentのsystem prompt、Zod入出力schema、使用可能MCP tools、Mastra Workflowの具体的なTypeScript構成**まで落とすのがよいです。