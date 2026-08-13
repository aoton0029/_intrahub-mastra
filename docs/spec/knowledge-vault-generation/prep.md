# knowledge-vault-generation 準備タスク（ユーザー作業）

> **仕様**: [requirements.md](requirements.md)
> **生成日**: 2026-08-13
> **最終更新**: 2026-08-13（実施結果を反映）

**【信頼性レベル凡例】**:
- 🔵 **青信号**: 要件定義書・設計文書・ユーザヒアリングで明確に必要と判明したタスク
- 🟡 **黄信号**: 要件定義書・設計文書から妥当に推測されるタスク
- 🔴 **赤信号**: 推測による予防的タスク（実装時に不要と判明する可能性あり）

**【状態凡例】**: ✅ 完了 / 🔧 設定投入済み・ミニPCでの実行待ち / ⏳ 未着手

## 必須（実装開始前に完了が必要）

- [x] ✅ **Knowledge Vault を `mastra` コンテナへ mount する** 🔵 *ユーザヒアリング Q9・PRD §15.3*
  - **調査の結果、すでに構成済みだった。** [`intrahub/services/mastra/compose.yaml`](../../../../intrahub/services/mastra/compose.yaml) に `${KNOWLEDGE_SOURCE:-knowledge}:/workspace` が read-write で定義されている（`:ro` 指定なし）
  - `intrahub/.env.example` の `KNOWLEDGE_SOURCE=/srv/knowledge`（ミニPCの実値。[README](../../../../homelab/デバイス/ミニPC/IntraHub/README.md)）
  - 関連要件: REQ-014, REQ-017, REQ-405, REQ-406, REQ-407, NFR-102

- [x] 🔧 **MediaVault MCP の接続情報を用意する** 🔵 *ユーザヒアリング Q9「これから用意」・PRD §17*
  - **配線を実装した。** 次のファイルを変更済み:
    - `intrahub/services/mastra/compose.yaml` — `MEDIAVAULT_MCP_URL: http://mediavault-mcp:8081` と `MEDIAVAULT_MCP_TOKEN: ${MCP_AUTH_TOKEN}` を追加
    - `intrahub/services/mastra/README.md` — MCP接続とナレッジ領域パスの節を追加
    - `intrahub/.env.example` — Mastra節へトークン共有の注記を追加
    - `intrahub-mastra/.env.example` — `MEDIAVAULT_MCP_URL` / `MEDIAVAULT_MCP_TOKEN` ほかを追加
  - ネットワーク経路は確認済み。`mastra` と `mediavault-mcp` はどちらも `mediavault-api` ネットワークに属するため、サービス名で到達できる
  - トークンは新規発行不要。MediaVault が既に使っている `MCP_AUTH_TOKEN` を共有する
  - **残作業（ミニPC）**: `/opt/docker/.env` の `MCP_AUTH_TOKEN` が空でないことを確認し、`docker compose up -d mastra` で反映する
  - 関連要件: REQ-001, REQ-401, NFR-101

- [x] 🔧 **Knowledge Vault を git リポジトリとして初期化する** 🔵 *ユーザヒアリング Q3「git管理する」*
  - **手順とスクリプトを作成した。**
    - [`homelab/デバイス/ミニPC/IntraHub/運用.md`](../../../../homelab/デバイス/ミニPC/IntraHub/運用.md) に「ナレッジVaultのgit管理」節を追加（初期化・systemd timer・確認・復旧）
    - [`homelab/デバイス/ミニPC/scripts/knowledge-vault-commit.sh`](../../../../homelab/デバイス/ミニPC/scripts/knowledge-vault-commit.sh) を作成
  - mergerfs 対策として `core.fileMode false` を設定する。`/srv` 未マウント時は commit しない（全ファイル削除としてコミットされ履歴が壊れるため、スクリプトが `mountpoint` で確認して停止する）
  - cron ではなく systemd timer を使う。`RequiresMountsFor=/srv` でマウント完了後に走らせるため
  - **残作業（ミニPC）**: 運用.md の手順を実行する（`git init` → スクリプト配置 → timer 有効化）
  - 関連要件: REQ-019, NFR-042

- [x] ✅ **`ai-workspace` と `second-brain` の実パスを確定する** 🔵 *ユーザヒアリング Q2・PRD §15.1*
  - **確定済み。**

    | 領域 | ホスト（ミニPC） | コンテナ内 |
    |---|---|---|
    | ナレッジ領域全体 | `/srv/knowledge` | `/workspace` |
    | 中間ファイル | `/srv/knowledge/ai-workspace` | `/workspace/ai-workspace` |
    | 最終ファイル | `/srv/knowledge/second-brain` | `/workspace/second-brain` |

  - 物理実体は `/mnt/hdd4/knowledge/{ai-workspace,second-brain}`（[ストレージ構築](../../../../homelab/デバイス/ミニPC/構築/ストレージ.md)）
  - コンテナへは `KNOWLEDGE_ROOT` / `AI_WORKSPACE_DIR` / `SECOND_BRAIN_DIR` の3変数で渡す（compose に追加済み）
  - 関連要件: REQ-016, REQ-017, REQ-405, REQ-406

## 推奨（実装中に用意できればOK）

- [x] ✅ **LiteLLM に Agent 別の論理モデル名を登録する** 🔵 *ユーザヒアリング Q10「未確認」・PRD §11*
  - **確認の結果、すでに登録済みだった。** [`intrahub/services/litellm/config/config.yaml`](../../../../intrahub/services/litellm/config/config.yaml) の `model_list` に `anthropic` / `openai` / `vllm` の3つが定義されている。PRD §11 が要求する割当をそのまま使える
  - **⚠️ ただし `wiki-model` は LiteLLM に存在しない。** 現在の `src/mastra/models/litellm.ts` と `README.md` が参照している `wiki-model` は LiteLLM 側に対応するルートがなく、呼べば失敗する。REQ-024・REQ-025 のモデル定義実装（実装順3）で置き換える
  - 関連要件: REQ-024, REQ-025, EDGE-009

- [x] ✅ **`@mastra/mcp` を導入する** 🔵 *note.md「package.json に未導入」*
  - `npm install @mastra/mcp` を実行済み。8パッケージが追加された
  - 関連要件: REQ-001, REQ-401

- [ ] ⏳ **Anthropic / OpenAI の API キーを LiteLLM へ設定する** 🟡 *PRD §11 のプロバイダ分離要求から妥当な推測*
  - `intrahub/.env` の `ANTHROPIC_API_KEY` / `ANTHROPIC_MODEL` が設定済みか確認する。`knowledgeWriterAgent` に `anthropic` を割り当てるため必要
  - `OPENAI_API_KEY` は第2段階（Critic）で必要になるため今回は保留可
  - **Mastra へ直接キーを渡さない。LiteLLM に集約する**（REQ-415）
  - 必要になるフェーズ: Phase 2
  - 関連要件: REQ-024, REQ-415

- [ ] ⏳ **代表 Item 10件以上の評価データセットを選定する** 🔵 *PRD §19・NFR-303*
  - 品質の基準値はデータセット作成後に確定する、と PRD が明記している
  - メディア種別が偏らないよう選ぶ（映画、漫画、小説、論文など）
  - MVP 受け入れ基準「代表 Item の自動評価で出典欠落と重複作成が 0件」の測定対象になる
  - 必要になるフェーズ: Phase 5
  - 関連要件: NFR-301, NFR-302, NFR-303

- [x] ✅ **Samba の `Knowledge` 共有を公開する** 🔵 *PRD §15.2・§15.3*
  - **調査の結果、すでに構成済みだった。** [`intrahub/services/samba/config/smb.conf`](../../../../intrahub/services/samba/config/smb.conf) に `[Knowledge]`（`path = /knowledge`、`read only = no`）が定義され、compose が `${KNOWLEDGE_SOURCE}:/knowledge` を mount している
  - この経路では一致確認（REQ-018）と保護（REQ-202）が効かない。対話セッションには人間が介在するため許容する（PRD §15.2）
  - 関連要件: NFR-204

## 確認事項（判断が必要）

- [x] ✅ **`calculateNotePath` の `topic` をどこから決めるか** 🔵 *ヒアリング Q6 の派生*
  - **決定: MediaVault Item の作品名（シリーズがある場合はシリーズ名）から決める。** LLM の推測による生成を行わない
  - REQ-016a として要件化。EDGE-006（作品名・シリーズ名がない場合は未分類へ）が 🟡 → 🔵 へ向上
  - 関連要件: REQ-016, REQ-016a, EDGE-006

- [x] ✅ **`second-brain` への昇格を誰がいつ行うか** 🔵 *ヒアリング Q2 の派生*
  - **決定: `moveNote` を人間が叩く。** 配置先を REQ-016・REQ-016a の規則で再算出し、frontmatter の整合を確認する。実行の起点は人間
  - REQ-017a として要件化。人間が直接ファイル移動する案は採らないため、配置規則と frontmatter の整合が保たれる
  - 関連要件: REQ-017, REQ-017a, REQ-204

- [ ] ⏳ **`get_item_text` が連番インデックスを返す前提で MediaVault 側と合意する** 🔵 *ヒアリング Q5 の決定*
  - `sourceRefs` を `(fileId, chunkIndex)` に統一する決定は、PDFページ・EPUB章の差を **MediaVault 側が吸収する**ことを前提としている
  - MediaVault 側の `get_item_text` 実装仕様と整合するか確認する。`intrahub-mediavault` 側の設計文書更新が必要になる可能性がある
  - 判断が必要なフェーズ: Phase 4（MVP-1）着手前。**MVP-0 の実装はブロックしない**
  - 関連要件: REQ-005, REQ-006

- [ ] 🔁 **CI の回帰評価でモデルを固定する運用ルールを決める** 🟡 *ヒアリング Q4 の派生*
  - **判断: Phase 5（評価データセット作成）まで保留する**
  - REQ-026（`provenance` と trace への記録）で追跡は確保されているため、保留してもモデルと評価結果の対応は失われない
  - 関連要件: REQ-025, REQ-026, NFR-302

---

## サマリー

| 優先度 | 件数 | ✅ 完了 | 🔧 実行待ち | ⏳ 未着手 | 🔁 保留 |
|--------|------|--------|-----------|---------|--------|
| 必須 | 4 | 2 | 2 | 0 | 0 |
| 推奨 | 5 | 3 | 0 | 2 | 0 |
| 確認事項 | 4 | 2 | 0 | 1 | 1 |
| **合計** | **13** | **7** | **2** | **3** | **1** |

**実装着手の可否**: MVP-0 の実装を開始できます。必須4件のうち mount とパス確定は元から満たされており、MCP 配線と git 管理は設定・手順を投入済みでミニPCでの実行を残すのみです。

**ミニPCで実行する残作業**:

1. `/opt/docker` を `git pull` し、`.env` の `MCP_AUTH_TOKEN` が空でないことを確認して `docker compose up -d mastra`
2. [運用.md「ナレッジVaultのgit管理」](../../../../homelab/デバイス/ミニPC/IntraHub/運用.md)の手順で `/srv/knowledge` を git 初期化し、timer を有効化

**設計フェーズで扱う持ち越し**: `wiki-model` の置き換え（LiteLLM に存在しないモデル名を参照している既存の不整合）。

## 関連文書

- **要件定義書**: [requirements.md](requirements.md)
- **ヒアリング記録**: [interview-record.md](interview-record.md)
- **コンテキストノート**: [note.md](note.md)
