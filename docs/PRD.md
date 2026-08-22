# PRD: intrahub-mastra

**作成日**: 2026-08-22 ／ **ステータス**: Draft ／ **種別**: バックエンドサービス（Agent/Workflow 実行基盤）

## 1. 概要

MediaVault と外部資料から Knowledge Vault を生成・維持するための知識処理層。作品・論文・専門書の
抽出済みテキストと書誌メタデータを入力に、要約・批評・概念整理を行い、その結果を Obsidian Vault
（`second-brain`）のノートとして書き込み、更新し続ける。

Mastra の Agent と Workflow で構成し、LLM アクセスは LiteLLM の論理モデル名経由に統一する。
MediaVault へは MCP 経由の読み取りのみで接触し、書き込みは行わない。Vault のディレクトリ構成・
命名・frontmatter・タグ規約は Vault リポジトリの `KnowledgeVault/README.md` が正本であり、本サービスは
その規約に**従う実装側**として位置づける。

| 構成要素 | 責務 |
|---|---|
| MediaVault | 作品・文献のメタデータ、ファイル参照、抽出済みテキストを管理するサービス |
| intrahub-mastra | 資料収集、分析、要約、批評、知識統合、Vault 更新の制御 |
| Knowledge Vault (`second-brain`) | 作品・文献など外部資料に由来する整理済み知識の正本 |

## 2. 背景と目的

観たアニメ、読んだ論文や専門書は MediaVault に登録され、PDF の抽出テキストまで手元にある。
しかし「その資料から何を理解したか」は残っていない。話数ごとの印象は視聴直後に消え、論文は
読み返すたびに最初から読むことになり、複数の資料で同じ概念（たとえば「唯識」）に触れても、
それぞれの資料の中に閉じたままで結びつかない。

手で Obsidian に書けば残るが、話数単位・章単位の要約を継続して書ける量ではない。結果として、
資料は増え続ける一方で、そこから取り出せる知識は増えない。

このギャップを埋めるのが本サービスの目的である。抽出テキストという機械可読な入力が既に
MediaVault にある以上、要約・批評・概念抽出とノート化は自動化でき、人間の仕事を「確認と判断」
に寄せられる。同時に、AI が書いた推測が検証済みの顔をして Vault に混ざることは Vault の価値を
壊すため、出典追跡と人間の編集領域の保護を最初から設計に含める。

## 3. ビジョンと成功指標

MediaVault に資料を登録すれば、その資料に対応するノートが Vault に生成され、話数や章が増えれば
差分だけが追記される。概念やテーマのノートは複数資料からの言及を集約して育ち、人間は Obsidian で
読み、疑わしい箇所だけを直す。「あの概念、他に何で読んだか」に Vault が答えられる状態にする。

- MediaVault に登録済みの作品・論文・専門書について、`10-Sources` 配下の `index.md` と話数／章ノートが
  人手の追記なしに生成されている
- 生成されたノートの主張が、`sources` / `source_refs` から MediaVault の該当箇所まで辿れる
- 同一資料を再処理しても、`owner: human` および `status: human_verified` のノート本文が変更されない
- 3件以上の資料に登場する概念について、Concept ノートが資料横断の言及を保持している
- Vault への更新が Git のコミットとして記録され、任意の時点へ戻せる

## 4. ターゲットユーザーとユーザーストーリー

利用者は自宅インフラの運用者本人ひとり。Obsidian で Vault を読み書きし、Mastra Studio または
`intrahub` の UI からワークフローを起動する。外部公開はしない。

- 視聴者として、観終わった話数の要約と批評を自動で残したい。なぜなら、作品全体を語ろうとしたときに
  個々の話数の記憶が既に失われているから。
- 読者として、論文・専門書を章ごとに要約させたい。なぜなら、再読のたびに全文を読み直す時間がなく、
  どの章に何が書いてあったかだけを先に思い出したいから。
- 学習者として、複数の資料を横断した概念・テーマのノートを持ちたい。なぜなら、同じ用語が資料ごとに
  違う定義で使われていることに、資料単位のノートだけでは気づけないから。
- Vault の管理者として、AI が書いた内容と自分が確認した内容を区別したい。なぜなら、検証していない
  推測が正本に紛れると、Vault 全体の信頼性が失われるから。
- 利用者として、Vault の内容に基づいて質問に答えさせたい。なぜなら、蓄積した知識を読み返す以外の
  方法で引き出したいから。

## 5. 主要機能

### MVP（最初のバージョンに必ず入れる）

**MediaVault 参照（読み取り専用）**
MCP 経由で作品・文献のメタデータ、ファイル参照、抽出済みテキストを取得する。書き込み系ツールは
使用しない。取得結果は `ai-workspace` に中間データとして保持し、同一資料の再処理で使い回す。

**作品ノートの生成・更新**
作品全体の `index.md`（概要、構成、主題、関連資料）を生成する。作品名は MediaVault 上の正名を用い、
対応は `item_id` で保つ。MediaVault 側の正名変更はディレクトリ名へ自動追従させず、確認対象とする。

**話数ノートの生成・更新**
話数ごとに要約、構成、登場人物、主題、批評、作品全体での位置づけを生成する。原典に明示された内容
（要約）と解釈（批評）を本文中で区別する。話数の追加時は差分のみを処理する。

**章ノートの生成・更新**
論文・専門書を章／節単位で要約する。章の目的、要約、主要な主張、根拠・事例、重要語、疑問・反論を
持たせる。章境界は抽出結果のラベルや目次を優先し、OCR 本文から推定した場合は `review_needed` とする。

**概念・テーマの横断整理**
作品・論文・専門書・Web 資料を横断して Concept / Theme ノートを生成・更新する。Web 資料には資料
ノートを作らず、内容は Concept / Theme 本文へ書き、根拠は URL と取得日で `sources` に残す。

**タグ・カテゴリ・リンクの整理**
候補生成 → 既存語彙への正規化 → 差分検証 → 適用の順で処理する。未登録語は提案として蓄積し、直ちに
正式タグにしない。人間が追加したタグは保護し、再生成されなかったことを理由に削除しない。

**Vault 更新と保護**
`owner: human` のノートを上書きしない。上書きが必要と判断した場合も直接編集せず、差分を検証レポート
または `00-Inbox` へ出す。更新は Git のコミットとして `/srv/knowledge` に記録する。

**Vault を用いた検索・回答**
複数の Vault ルート（`second-brain` / `tech-notes`）を対象に検索し、根拠ノートへのリンク付きで回答する。
回答の過程で得た不足・矛盾は、更新対象の候補として残す。

### フェーズ2以降

- MediaVault の登録・更新イベントを契機とした自動起動
- `30-Syntheses`（比較・年表・論考）と `40-Maps`（MOC・索引）の生成
- 出典失効（`extraction_version` 変更など）の検出と `stale` 付与の定期実行
- スコアラーによる生成品質の継続評価

## 6. スコープ外

- **Vault の構造・命名・frontmatter 規約を本リポジトリで定義しない**（正本は `KnowledgeVault/README.md`。
  二重定義は必ず食い違う）
- **MediaVault への書き込みを行わない**（メタデータの正本は MediaVault 側にあり、Vault 側の分類結果を
  逆流させると表記と分類の判断が二重になる）
- **PDF・映像・OCR 全文を Vault へ複製しない**（Vault に置くのは生成した知識と出典参照だけ）
- **`tech-notes` の本文生成を行わない**（開発由来の知識は `knowledge-capture` 等のスキルが担当。
  本サービスは横断検索の対象として読むに留める）
- **Obsidian 側の UI やプラグインを作らない**（人間の読み書きは素の Obsidian で完結させる）
- **抽出処理（OCR、PDF パース）を実装しない**（MediaVault の extractor の責務）

## 7. 構成

| 要素 | 技術 |
|---|---|
| フレームワーク | Mastra（Agent / Workflow / Tool / Scorer） |
| 言語・実行環境 | TypeScript、Node.js 22 以上、ESM |
| LLM 接続 | LiteLLM（OpenAI 互換）。`wiki-model` などの論理モデル名で参照 |
| 外部連携 | MediaVault MCP（Read Only ツールのみ）、Vault MCP、Web 検索 |
| ストレージ | Vault は `/srv/knowledge`（コンテナ内 `/workspace`）へマウント。実行状態は libsql |
| デプロイ | Docker。外部ネットワーク `llm-net` に参加 |

Agent は `.env.example` の想定に沿って役割ごとに分ける。Media Research（資料収集・調査）、
Knowledge Writer（要約・批評・本文生成）、Vault Curator（配置、リンク、タグ、保護規則の適用）。
モデルは Agent ごとに `MODEL_*` で論理名を上書きでき、既定値はコード側に持つ。

Vault への書き込みは Vault Curator に集約し、他の Agent はファイルを直接書かない。書き込み前に
リンクの絶対パス解決、Vault 全体で一意にすべきノートの重複確認、`owner` / `status` による保護判定を
通す。ノート移動・改名時は Vault 内の絶対パスリンクを走査して更新差分に含める。

`/srv/knowledge` は既存運用どおり Git で履歴を保存し、人手編集と AI 更新の双方から復旧できるようにする。

frontmatter のスキーマは Vault 側の `second-brain/90-Meta/Schema/frontmatter.schema.json` を正本とし、
本リポジトリでは再定義しない。ビルド時にこのスキーマから Zod を生成し、Vault Curator の書き込み前
検証に用いる。生成物と Vault 側スキーマの一致は CI で検査する。Vault の骨格・規約ファイル・スキーマ・
テンプレートは `intrahub/services/knowledge` の seed が配布元で、IntraHub 起動時の `knowledge-init` が
バージョンを比較して配置する。

中間データ（MediaVault からの取得結果、チャンク、抽出済みの候補タグなど）は `ai-workspace` に置き、
Vault の正本とは分離する。

環境変数は `LITELLM_BASE_URL` / `LITELLM_MASTER_KEY` / `MEDIAVAULT_MCP_URL` / `MEDIAVAULT_MCP_TOKEN` /
`KNOWLEDGE_ROOT` / `AI_WORKSPACE_DIR` / `SECOND_BRAIN_DIR` を用いる。`VLLM_API_KEY` は渡さない。

既存の `src/mastra` 配下は Mastra テンプレートの雛形（`weather-*`）のみで、本 PRD の実装は白紙から
始める。Agent・Tool・Workflow・Scorer はすべて `src/mastra/index.ts` に登録する。

## 8. 未確定事項

- [ ] ワークフローの起動方法 — Mastra Studio からの手動起動のみで始めるか、`intrahub` の UI や
      MediaVault のイベントから起動できるようにするか。MVP の範囲が変わる
- [ ] Vault MCP の実体 — 別リポジトリのサービスとして立てるか、本リポジトリ内の Mastra Tool として
      実装するか。複数 Vault ルート対応とリンク形式の切り替えをどこが持つかが決まっていない
- [ ] Git コミットの実行主体と粒度 — Vault Curator が書き込みごとにコミットするか、外部の cron が
      まとめてコミットするか。コミットメッセージの規約も未定
- [ ] 検索・回答の検索方式 — frontmatter とファイル名によるキーワード検索で足りるか、ベクトル検索
      （埋め込みモデルとストア）を導入するか。導入する場合、埋め込みの再計算契機も決める必要がある
- [ ] 再処理の判定条件 — 同じ資料をいつ再処理するか（`extraction_version` の変化、話数の追加、
      モデル更新など）。無条件の再生成はコストと差分ノイズの両方を招く
- [ ] 人手確認のインターフェース — `00-Inbox` へノートを置く以外に、検証レポートの形式や通知が
      必要か。Obsidian で読むだけで運用が回るかは試してみないと分からない
- [ ] Agent ごとのモデル選択 — 批評・論考のようにローカルモデルで品質が出にくい処理をどこまで
      外部 API へ回すか。`MODEL_*` の既定値が決まっていない
- [ ] Vault 側の未確定事項への依存 — `id`（`kv_...`）の採番規則と、`categories` の語彙および
      `20-Knowledge` 配下のディレクトリ名との対応規則が未確定。スキーマ側では `id` を接頭辞のみの
      暫定パターンにしてあり、確定後に厳密化する
- [ ] `90-Meta` の上書き方針 — `90-Meta` は Vault 規約上「人間の領域」だが、seed のバージョン更新で
      上書きされる。運用で `taxonomy.yaml` に育てた語彙を seed へ戻す手順を決めないと、更新のたびに
      差分が消える（コミットからは復旧できる）

## 9. 関連文書

- [../README.md](../README.md) — LLM 接続とローカル開発手順
- [../AGENTS.md](../AGENTS.md) — 実装規約（Mastra スキルの読み込み、登録先）
- [KnowledgeVault/README.md](../../KnowledgeVault/README.md) — Vault 構造・命名・frontmatter の正本（実環境では `/srv/knowledge/README.md`）
- [intrahub/services/knowledge/README.md](../../intrahub/services/knowledge/README.md) — Vault の初期化（seed とバージョン比較）
- [intrahub-mediavault/docs/PRD.md](../../intrahub-mediavault/docs/PRD.md) — MediaVault の PRD
