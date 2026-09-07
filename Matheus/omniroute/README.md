# OmniRoute — parar de bater no limite do Claude Code

Guia montado a partir do vídeo (`thetechniko`). O que ele mostra é o
**OmniRoute**: um *gateway* de IA que roda **na sua máquina** (`localhost:20128`)
e faz o Claude Code (e Codex, Cursor, Cline, etc.) falar com **outros
provedores** — muitos com camada gratuita — em vez de bater direto na API da
Anthropic.

- Repositório: <https://github.com/diegosouzapw/OmniRoute>
- Pacote npm: `omniroute` (MIT)

## O que isso resolve — e o que NÃO resolve

| | |
|---|---|
| ✅ Resolve | Você continua usando a **interface do Claude Code**, mas as requisições vão para modelos gratuitos/baratos (GLM, DeepSeek, Gemini Flash, Kimi, Qwen…). Se um provedor estoura a cota, ele cai automaticamente para o próximo. |
| ❌ Não resolve | Não aumenta e não contorna o limite da sua conta Anthropic. Você **não** ganha Opus/Sonnet de graça — troca o modelo por trás da CLI. |

Ou seja: para o trabalho das aulas (HTML, CSS, exercícios) os modelos grátis dão
conta tranquilo. Para tarefa pesada de arquitetura, o resultado cai de qualidade.

---

## Pré-requisito: versão do Node

O pacote exige `node >=22.22.2 <23 || >=24.0.0 <27`. **Node 23 não serve.**

```bash
node -v
```

Se estiver fora dessa faixa, instale o Node 22 LTS (ou 24) antes de continuar —
com [nvm](https://github.com/nvm-sh/nvm) é `nvm install 22 && nvm use 22`.

---

## Passo a passo (5 minutos)

### 1. Instalar e subir o gateway

```bash
npm install -g omniroute
omniroute
```

Avisos de `npm warn ERESOLVE` / peer-deps são normais, pode ignorar.

- Painel: <http://localhost:20128>
- API: <http://localhost:20128/v1>

Deixe esse terminal aberto (o gateway precisa estar rodando).

### 2. Conectar um provedor grátis

No painel → **Providers** → conecte um destes:

| Provedor | Observação |
|---|---|
| **OpenCode Free** | sem autenticação, já vem pré-ligado |
| **Kiro AI** | Claude grátis, ~50 créditos/mês por conta |
| **Z.AI GLM** | GLM-4.7 / 4.5-Flash, grátis |
| **Cerebras** | ~1M tokens/dia |
| **Qoder AI** | Qwen3-Max, Kimi-K2 |
| **Cloudflare AI** | 50+ modelos, 10K neurons/dia |

Instalação nova já responde no modelo `auto` sem nenhuma chave — dá pra testar
antes de criar conta em qualquer lugar:

```bash
curl http://localhost:20128/v1/chat/completions \
  -H "Content-Type: application/json" \
  -d '{"model":"auto","messages":[{"role":"user","content":"Olá!"}]}'
```

### 3. Apontar o Claude Code para o gateway

Jeito automático (lê o catálogo de modelos ativo e escreve a config sozinho):

```bash
omniroute setup-claude
```

Jeito manual — `~/.claude/settings.json` (no Windows:
`%USERPROFILE%\.claude\settings.json`):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "http://localhost:20128",
    "ANTHROPIC_AUTH_TOKEN": "sk-sua-chave-do-omniroute"
  }
}
```

> ⚠️ Aqui é a **raiz** do gateway, sem `/v1` no final. O `/v1` só vale para
> clientes OpenAI-compatíveis.

A chave (`ANTHROPIC_AUTH_TOKEN`) você copia no painel → **Endpoints**.

### 4. Testar

```bash
claude "diga olá"
```

O cabeçalho do Claude Code deve mostrar o modelo roteado (ex.:
`gemini-2.5-flash · API Usage Billing`), igual no vídeo.

Para conferir os modelos disponíveis:

```bash
curl http://localhost:20128/v1/models -H "Authorization: Bearer SUA_CHAVE"
```

---

## Rodar sem mexer na config global

Se você não quiser alterar o `~/.claude/settings.json`, dá para lançar a CLI só
naquela sessão, com as variáveis injetadas no processo:

```bash
omniroute run claude --model glm/glm-5.2
```

Outros alvos: `codex`, `aider`, `goose`, `opencode`, `qwen`, `gemini`.
`--dry-run` mostra o que seria executado sem rodar.

---

## Voltar ao normal

Apague o bloco `env` do `~/.claude/settings.json` (ou restaure o backup que o
script gera). O Claude Code volta a usar sua conta Anthropic na hora.

---

## Alternativas de instalação

### Docker (mais isolado)

⚠️ Importante: a imagem vem com `OMNIROUTE_MEMORY_MB=1024`, que serve para chat
leve. **Agente de código estoura essa heap.** Suba com mais memória:

```bash
docker run -d --name omniroute --restart unless-stopped --stop-timeout 40 \
  -e OMNIROUTE_MEMORY_MB=8192 --memory=10g \
  -p 127.0.0.1:20128:20128 -v omniroute-data:/app/data \
  diegosouzapw/omniroute:latest
```

| Uso | `OMNIROUTE_MEMORY_MB` | `--memory` |
|---|---|---|
| Painel / chat leve | `1024` | ≥ 2g |
| Um agente de código | `8192` | ≥ 10g |
| Dois contextos longos | `10240`–`12288` | ≥ 12–16g |

### Podman (o do vídeo)

```bash
git clone https://github.com/diegosouzapw/OmniRoute.git
cd OmniRoute
podman unshare chown 1000:1000 ./data   # só Linux com Podman rootless local
echo "CONTAINER_HOST=podman" >> .env
podman compose --profile base up -d --build
```

No macOS/Windows o Podman usa uma Machine remota: pule o `podman unshare` e siga
`contrib/podman/README.md` do projeto.

---

## Antes de sair colando chave — leia

1. **É um gateway de terceiros.** Ele guarda as chaves de API dos provedores que
   você conectar (o projeto diz que ficam locais e cifradas em AES-256-GCM, mas
   quem instala assume o risco). Use conta/chave descartável quando der.
2. **Seu código sai da sua máquina.** Vai para o provedor que o roteador
   escolher. Não use em nada confidencial — estágio, trabalho, dados de terceiros.
3. **Cada camada gratuita tem os termos dela.** Você precisa da sua própria conta
   em cada provedor; abusar de free tier é problema com aquele provedor.
4. **Deixe a porta em `127.0.0.1`.** Não exponha `20128` na rede sem autenticação.
