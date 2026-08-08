# knowledge-digest-hub

MastraでKnowledgeHubのエージェントとワークフローを実装するプロジェクトです。LLMアクセスはLiteLLMへ統一し、`wiki-model`を使用します。

## LLM接続

`.env.example`を基に次の環境変数を設定します。

```dotenv
LITELLM_BASE_URL=http://litellm:4000/v1
LITELLM_MASTER_KEY=<LiteLLM master key>
```

コンテナは固定名の外部Dockerネットワーク`llm-net`へ参加させます。`wiki-model`はLiteLLMがvLLMの`local-agent-model`へルーティングし、vLLM停止時のみ外部APIへフォールバックします。Mastraへ`VLLM_API_KEY`を渡してはいけません。

## Getting Started

Start the development server:

```shell
npm run dev
```

Open [http://localhost:4111](http://localhost:4111) in your browser to access [Mastra Studio](https://mastra.ai/docs/studio/overview). It provides an interactive UI for building and testing your agents, along with a REST API that exposes your Mastra application as a local service. This lets you start building without worrying about integration right away.

You can start editing files inside the `src/mastra` directory. The development server will automatically reload whenever you make changes.

## Learn more

To learn more about Mastra, visit our [documentation](https://mastra.ai/docs/). Your bootstrapped project includes example code for [agents](https://mastra.ai/docs/agents/overview), [tools](https://mastra.ai/docs/agents/using-tools), [workflows](https://mastra.ai/docs/workflows/overview), [scorers](https://mastra.ai/docs/evals/overview), and [observability](https://mastra.ai/docs/observability/overview).

If you're new to AI agents, check out our [course](https://mastra.ai/learn) and [YouTube videos](https://youtube.com/@mastra-ai). You can also join our [Discord](https://discord.gg/BTYqqHKUrf) community to get help and share your projects.

## Deploy to the Mastra platform

The [Mastra platform](https://projects.mastra.ai) provides two products for deploying and managing AI applications built with the Mastra framework:

- **Studio**: A hosted visual environment for testing agents, running workflows, and inspecting traces
- **Server**: A production deployment target that runs your Mastra application as an API server

Learn more in the [Mastra platform documentation](https://mastra.ai/docs/mastra-platform/overview).
