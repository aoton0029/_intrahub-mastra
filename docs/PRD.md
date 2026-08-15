# PRD: intrahub-mastra Knowledge Vault

**作成日**: 2026-08-16 ／ **ステータス**: Draft ／ **種別**: 既存プロジェクトへの追加（Mastra製のAgent・Workflow層）

## 1. 概要

intrahub-mastraを、MediaVaultと外部資料からKnowledge Vaultを生成・維持するための知識処理層にする。

作品と話数の要約・批評、論文と専門書の章要約、テーマ・専門用語の横断整理、タグとカテゴリの整理を、LiteLLM経由のLLMとMediaVault MCPを使ったWorkflowとして実行し、結果をObsidian Vault（`/srv/knowledge/second-brain`）へMarkdownノートとして蓄積する。

Vaultに保存するのは知識と出典参照だけであり、PDF、映像、OCR全文は複製しない。中間データは`ai-workspace`へ置き、Vaultには検証を通った成果だけを残す。

## 2. 背景と目的

現状、素材は揃っているのに知識として残っていない。

- 作品を観ても論文を読んでも、要約や批評が手元に残らない。数か月後に「あの話数で何が語られていたか」「あの論文の第3章の主張は何だったか」を追えず、同じ資料を読み直している。
- 「トランスメディアストーリーテリングとメディアミックスの定義と関係」「唯識」のようなテーマ・専門用語は、作品・論文・専門書・Web資料に記述が散らばっている。突き合わせて一枚にまとめる作業が完全に手作業で、着手しても最後まで終わらない。
- MediaVault Extractorが抽出したOCR済み文献の全文はMediaVaultにあるが、量が多く読み返せない。章単位の要約が無いため、実質的に死蔵している。
- Obsidian側のタグとカテゴリが表記揺れと重複で増え続け、手作業の整理が追いつかない。分類として機能していない。

これらは「AIに聞けば答える」では解決しない。回答が毎回ゼロから生成され、蓄積されないからである。目的は、出典を追跡できる形で知識をVaultへ蓄積し、次の調査がその蓄積の上から始まる状態を作ることにある。

## 3. ビジョンと成功指標

資料をMediaVaultへ登録すれば、章要約・作品ノート・概念ノートがVaultへ積み上がり、テーマを調べるときはまずVault内の既存ノートが答えの土台になる。各記述からは、どのItem・どのファイル・どのチャンクに基づくのかを常に辿れる。人間は生成物をゼロから書くのではなく、Inboxと差分を確認する側に回る。

- OCR済みの論文・専門書1冊に対し、`index.md`と章ノート一式が生成され、各章ノートの主要な主張が`(itemId, fileId, chunkIndex)`まで遡れる。
- テーマ調査を依頼したとき、Vault内の既存ノートが根拠として引用され、外部検索だけに依存した回答にならない。
- 生成ノートのうち出典不足・推定・競合を含むものが`review_needed`として分離され、`reviewed`と混ざらない。
- タグ・カテゴリが`90 Meta`のtaxonomyに登録された語彙へ正規化され、未登録語は提案として蓄積されるだけで正式タグに混入しない。
- 人手で編集したノートと人手で付けたタグが、AIの再生成によって黙って消えない。

## 4. ターゲットユーザーとユーザーストーリー

単一ユーザーのセルフホスト環境。利用者はミニPC上のIntraHubを運用している本人で、Mastra Studio（`:4111`）またはスケジューラからWorkflowを起動し、生成結果をObsidianとSamba経由で読み書きする。認証・マルチテナント・権限分離は考慮しない。

- `コレクション所有者` として `OCRした論文・専門書を章ごとに要約してVaultへ保存` したい。なぜなら 全文は量が多くて読み返せず、章単位の要約が無いと参照できないから。
- `コレクション所有者` として `作品全体と話数ごとの要約・批評をノートとして残` したい。なぜなら 観た内容が残らず、作品内での位置づけを後から追えないから。
- `コレクション所有者` として `テーマや専門用語について作品・論文・専門書・Webを横断した整理ノートを得` たい。なぜなら 定義や関係の突き合わせが手作業では終わらないから。
- `コレクション所有者` として `タグとカテゴリを既存の語彙へ自動で正規化・提案` してほしい。なぜなら 表記揺れと重複で分類が破綻しているから。
- `コレクション所有者` として `生成物のうち信頼できないものだけを分離して確認` したい。なぜなら 全件を人手で確認する余裕はないが、誤りが正本へ混ざるのも避けたいから。

## 5. 主要機能

### MVP（最初のバージョンに必ず入れる）

**Knowledge Vaultのディレクトリ構成とノート規約**
`00 Inbox` / `10 Sources` / `20 Knowledge` / `30 Syntheses` / `40 Maps` / `90 Meta` / `Attachments` の大分類を定義し、ノート種別は frontmatter の `type` で管理する。共通frontmatter（`id` / `type` / `categories` / `tags` / `status` / `sources` / `source_refs` / `provenance`）と`status`遷移（`draft` → `review_needed` / `reviewed` → `human_verified` / `stale`）を規約として確定する。

**`summarizeDocumentWorkflow`（MVPの中核）**
MediaVaultの抽出済みテキストを章・節へ分割し、チャンク→章→文献全体の順に階層要約する。全文を一度にLLMへ渡さない。出力は`10 Sources/Papers/{著者}-{年}-{短縮タイトル}/`または`Academic Books/`配下の`index.md`と章ノート。各段階で出典参照を維持し、章境界をOCR本文から推定した場合は`review_needed`にする。

**Vault MCPとして公開するノート操作**
汎用ファイル操作ではなく、`search_notes` / `read_note` / `create_note` / `update_note` / `find_related_notes` という意味を持つ操作としてVaultを扱う。書き込み前に既存内容の一致確認を行い、競合時は上書きしない。

**MediaVault MCPからの資料取得（Read Only）**
実装済みのmediavault-mcp（Streamable HTTP、`http://<ホスト>:8081/mcp`、Bearer認証）へMCPクライアントとして接続する。使うのは`search_library`（対象Item解決）、`get_item_context`（Item本体・関連・ファイル一覧）、`get_item_text`（抽出済み全文のチャンク取得）の3ツールに限る。接続には`MCP_READONLY_TOKEN`を使い、書き込みツールが`tools/list`に見えない状態で運用する。`extraction_version`を記録し、再抽出で変化した場合は既存参照を自動で読み替えず`stale`として再確認対象にする。

**役割別の論理モデル名によるLLM切り替え**
要約・批評・分類などの役割ごとに論理モデル名を定義し、LiteLLM側で実体（vLLMのローカルモデル／外部API）を差し替える。Mastra側のコードは論理モデル名だけを知る。`VLLM_API_KEY`をMastraへ渡さない。

**書き込みポリシー: 新規は自動、更新は差分確認**
新規ノートは`draft`として自動作成する。既存ノートの上書き、タグ削除、taxonomyの統合は自動確定させず、`00 Inbox`または`90 Meta`の検証レポートへ送って人が承認する。人間が追加したタグは既定で保護し、再生成されなかったことだけを理由に削除しない。

### フェーズ2以降

- `generateWorkKnowledgeWorkflow` / `generateEpisodeKnowledgeWorkflow` — 作品全体ノートと話数ごとの要約・批評。`10 Sources/Works/{作品名}/index.md` と `Episodes/S01E01 ….md` に分け、要約（原典に明示された内容）と批評（解釈）を区別する。
- `researchTopicWorkflow` — テーマ・専門用語の横断調査。Themeノートは問い・対象範囲・資料ごとの定義・共通点と相違点・論争点を、Conceptノートは定義・原語・別名・系譜・学説上の相違・誤解しやすい点を整理する。Web検索結果は補助資料として扱い、スニペットだけを根拠にしない。
- `curateTaxonomyWorkflow` — タグ・カテゴリ・リンクの整理。候補生成 → 既存語彙への正規化 → 差分検証 → 適用の順で行う。
- `refreshStaleSourcesWorkflow` — `extraction_version`の変化などで失効した出典参照の再調査。
- `digestNewItemsWorkflow` — MediaVaultへ追加された資料の定期処理。
- `knowledgeOrchestrator` — 要求の解釈と、上記Workflowの選択・組み合わせ。

## 6. スコープ外

- **Vault専用のベクター検索基盤を持たない** — embedding生成とベクトルDBをMastra側に持たない。検索はMediaVaultの検索、Vault MCPの全文検索、Obsidianに任せる。ここを持つと、Vaultとインデックスの二重管理と再構築運用が増える。
- **MediaVaultへの書き戻しを行わない** — 知識生成の副作用としてItem、評価、視聴・読了状況、タグ、カテゴリ、関連を変更しない。mediavault-mcpの書き込み系7ツール（`import_external_item` / `create_item` / `update_consumption` / `organize_item` / `relate_items` / `add_access_link` / `add_citation`）はいかなるAgentにも渡さない。読み取り専用トークンで接続することで、Mastra側のツール選択ミスがあってもサーバー側で拒否される状態にする。Knowledge Vault側の分類はMediaVaultとは別体系として扱う。
- **OCR・テキスト抽出そのものを実装しない** — PDF・画像からの抽出はMediaVault Extractorの責務。Mastraは抽出済みテキストだけを使い、未抽出のファイルは`not_extracted`として抽出依頼を促す。
- **PDF・映像・OCR全文をVaultへ複製しない** — Vaultに置くのは生成した知識と出典参照だけ。原本はMediaVaultと共有ライブラリに残す。
- **UIを作らない** — 起動はMastra Studioとスケジューラ、閲覧はObsidianとSambaで行う。専用のWeb UIは作らない。

## 7. 構成

**実行環境**: IntraHubのDocker Compose上の`mastra`コンテナ（`:4111`）。ミニPC（Debian trixie / RTX 5060 Ti 16GB）でmergerfs `/srv`を使用する。

**技術スタック**: TypeScript + Mastra。Agent・Tool・Workflow・Scorerはすべて`src/mastra/index.ts`へ登録する。開発は`npm run dev`、ビルドは`npm run build`（`mastra dev` / `mastra build`を直接叩かない）。

**MediaVault MCP接続**: 実装済みのmediavault-mcpコンテナへ`http://mediavault-mcp:8081/mcp`（Streamable HTTP）で接続し、`Authorization: Bearer <MCP_READONLY_TOKEN>`を付ける。mediavault-mcpはmediavault-apiとは別コンテナで、apiが停止していても起動を維持する。トランスポートはHTTPのみで、stdioは第2段階（mediavault-mcp側TASK-0027以降）。ツール仕様の正本は[mediavault-mcp docs](../../intrahub-mediavault/docs/backend/mediavault-mcp/)に置かれ、intrahub-mastraはその仕様に従う側であって、ツールを定義する側ではない。

**LLM接続**: LiteLLM（`http://litellm:4000/v1`）へ統一し、`LITELLM_BASE_URL`と`LITELLM_MASTER_KEY`で接続する。固定名の外部Dockerネットワーク`llm-net`へ参加する。役割別の論理モデル名を定義し、実体の割り当てはLiteLLMのconfig側で行う。

**データソース**:

| ソース | 用途 | 経路 |
|---|---|---|
| MediaVault メタデータ | Item・関連作品・スタッフ・ファイル一覧 | mediavault-mcp `get_item_context` |
| OCR済みテキスト（論文・専門書PDF） | 章要約の材料 | mediavault-mcp `get_item_text`（0起点の連番チャンク） |
| 共有ライブラリ `/srv/media` | 作品の実ファイル・付属テキスト | read-writeマウント |
| Samba共有 `/srv/knowledge` | 人手で投入した資料・メモ | `/workspace`としてマウント |
| `ai-workspace` | 章分割、下書き、レビュー結果などの中間データ | `/srv/knowledge/ai-workspace` |
| Web検索 | 補助資料 | 外部API |

**Vaultの配置**: `/srv/knowledge`（物理: `/mnt/hdd4/knowledge`）をMastraへ`/workspace`としてマウントする。`ai-workspace`（再生成可能な中間データ）と`second-brain`（Obsidian Vault＝正本）を分ける。所有者はIntraHubの`LIBRARY_UID`と人間の編集者で揃える。

**履歴と復旧**: `/srv/knowledge`は`knowledge-vault-commit.sh`（systemd timer）でgit commitする。Mastraの書き込み前一致確認は競合の事前防止であり、人手編集とSamba経由の編集は一致確認を通らないため、gitを事後回復手段として併用する。

**Agent構成**: `knowledgeOrchestrator`（要求解釈とWorkflow選択）、`mediaResearchAgent`（Read Onlyの資料調査）、`knowledgeWriterAgent`（知識への変換）、`knowledgeCriticAgent`（出典・事実と解釈・矛盾の検証）、`vaultCuratorAgent`（重複判定・配置・frontmatter・タグ・差分）。Agent間はMarkdownではなく、出典・主張・概念・関係・不確実性を含む構造化データで受け渡す。

## 8. 未確定事項

- [ ] 役割別の論理モデル名の具体的な命名と、各役割に割り当てる実体モデル — READMEには`wiki-model`、intrahub側READMEには`anthropic` / `openai` / `vllm`があり、どちらの名前空間に揃えるか未決。LiteLLMのconfigを確認して統一する。
- [ ] `MCP_READONLY_TOKEN`で`get_item_text`が使えるか — mediavault-mcpのREADMEでは読み取り専用トークンに見えるツールが6件（`health` / `search_library` / `search_external_catalog` / `get_item_context` / `collection_overview` / `list_citations`）と書かれており、後から追加された`get_item_text`が含まれていない。MVPの中核である章要約が成立しないため、mediavault-mcp側で読み取り専用トークンの対象に含まれるかを確認して合意する。
- [ ] Vault MCPの実装形態 — Mastra内部のToolとして実装するか、mediavault-mcpと同様の独立したMCPサーバーとして立てるか。Obsidian以外のクライアントから使う予定があるかで決まる。
- [ ] 抽出未実行ファイルへの対応 — mediavault-mcpは`request_extraction` / `get_extraction_status` / `cancel_extraction`を提供しているが、これらは書き込み扱いになる可能性がある。Mastraから抽出を依頼するのか、`not_extracted`を検出したら人へ通知するだけにするかが未決。
- [ ] 章分割の判定基準 — 抽出結果のラベルや目次を優先するとしているが、`get_item_text`が返す`label`が`null`の場合にどこまで推定を許容し、どの条件で`review_needed`にするかの閾値が未定。
- [ ] 話数とMediaVault上のファイルの対応づけ — 一意に対応づけられない場合は「確認対象にする」としているが、確認待ちのキューをどこに持つか（`00 Inbox`か`ai-workspace`か）が未定。
- [ ] Workflowの起動方式 — Mastra Studioからの手動実行に加え、`digestNewItemsWorkflow`のような定期処理をどのスケジューラ（systemd timer / Mastraのスケジュール機能）で回すか未決。
- [ ] 動画・音声の文字起こしを将来スコープに入れるか — 話数の要約はメタデータと既存テキストで足りるのか、字幕・音声が必要かを実際に1作品試してから判断する。
- [ ] Web検索の経路 — Mastraから直接検索APIを叩くか、`compose.research.yaml`のOpen Deep Researchへ委譲するか未決。
- [ ] 生成コストと処理時間の許容範囲 — 専門書1冊あたりの章要約にかかる時間とトークン量を実測していないため、ローカルモデルで完結できるか外部APIが必要かを判断できない。

## 9. 関連文書

- [Knowledge Vault設計方針](./codex-chat.md) — 本PRDの設計側の下敷き。ディレクトリ構成、ノート種別、frontmatter、Workflow一覧の詳細
- [intrahub README](../../intrahub/README.md) — コンテナ構成、ネットワーク境界、公開ポート
- [MediaVault PRD](../../intrahub-mediavault/docs/PRD.md)
- [MediaVault Extractor PRD](../../intrahub-mediavault/docs/extractor/PRD.md) — テキスト抽出の責務境界
- [mediavault-mcp docs](../../intrahub-mediavault/docs/backend/mediavault-mcp/) — MediaVault MCPの正本ディレクトリ（PRD / spec / design / tasks / implements）
  - [README](../../intrahub-mediavault/docs/backend/mediavault-mcp/README.md) — 提供ツール一覧、接続設定、読み取り専用トークン
  - [PRD](../../intrahub-mediavault/docs/backend/mediavault-mcp/PRD.md)
  - [design/mcp-tools.md](../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mcp-tools.md) — ツール仕様、`outcome`とエラー形式
  - [design/mastra-integration.md](../../intrahub-mediavault/docs/backend/mediavault-mcp/design/mastra-integration.md) — `get_item_text`の仕様、チャンク連番と`extraction_version`
  - [design/api-tool-mapping.md](../../intrahub-mediavault/docs/backend/mediavault-mcp/design/api-tool-mapping.md) — エンドポイント単位の露出可否
- [ミニPC ストレージ設計](../../インフラ設計/デバイス/ミニPC/設計/ストレージ.md) — `/srv/knowledge`の物理配置と権限
- [knowledge-vault-commit.sh](../../インフラ設計/デバイス/ミニPC/scripts/knowledge-vault-commit.sh) — Vaultのgit履歴管理
- [AGENTS.md](../AGENTS.md) — Mastra実装時の規約
