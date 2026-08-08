import { createOpenAICompatible } from '@ai-sdk/openai-compatible';

const litellm = createOpenAICompatible({
  name: 'litellm',
  baseURL: process.env.LITELLM_BASE_URL ?? 'http://litellm:4000/v1',
  apiKey: process.env.LITELLM_MASTER_KEY ?? 'missing-litellm-master-key',
  includeUsage: true,
});

export const wikiModel = litellm.chatModel('wiki-model');
