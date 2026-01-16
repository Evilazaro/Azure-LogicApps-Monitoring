# 📄 Plano de Projeto – Modernização do Módulo Integrador do Sistema Néctar (Cooperflora)

> 📅 **Data de referência:** 13 de janeiro de 2026

### 📋 Controle do Documento

| Campo                 | Valor             |
| --------------------- | ----------------- |
| **Código do Projeto** | COOP-2026-MOD-INT |
| **Versão**            | 1.0               |
| **Status**            | Em elaboração     |
| **Autor**             | Néctar            |
| **Cliente**           | Cooperflora       |
| **Classificação**     | Confidencial      |

#### 📜 Histórico de Revisões

| Versão | Data       | Autor  | Descrição da Alteração                                                 |
| :----: | ---------- | ------ | ---------------------------------------------------------------------- |
|  0.1   | 06/01/2026 | Néctar | Versão inicial – estrutura e escopo                                    |
|  0.2   | 10/01/2026 | Néctar | Adição de arquitetura, cronograma e riscos                             |
|  0.3   | 12/01/2026 | Néctar | Detalhamento de estimativa de horas (WBS) e custos                     |
|  1.0   | 13/01/2026 | Néctar | Versão consolidada para aprovação – ajustes de organização e navegação |

#### ✍️ Aprovações

| Papel                    | Nome | Organização | Data | Assinatura |
| ------------------------ | ---- | ----------- | ---- | ---------- |
| **Sponsor Executivo**    |      | Cooperflora |      |            |
| **Product Owner**        |      | Cooperflora |      |            |
| **Gerente de Projeto**   |      | Néctar      |      |            |
| **Arquiteto de Solução** |      | Néctar      |      |            |

---

## 📑 Sumário e Guia de Navegação

Este documento está organizado em **três partes** para atender às necessidades de diferentes stakeholders. Utilize este guia para navegar diretamente às seções mais relevantes para sua função.

| Parte                          | Seções                                                                  | Público Principal | Tempo de Leitura |
| ------------------------------ | ----------------------------------------------------------------------- | ----------------- | :--------------: |
| **I – VISÃO EXECUTIVA**        | Introdução, Escopo, Cronograma, Governança, Riscos                      | BDMs              |   ~20 minutos    |
| **II – EXECUÇÃO DO PROJETO**   | Fases detalhadas, Premissas/Restrições, Gestão, Investimentos, Operação | BDMs + TDMs       |   ~40 minutos    |
| **III – FUNDAMENTOS TÉCNICOS** | Arquitetura, Padrões técnicos, Evolução futura                          | TDMs              |   ~25 minutos    |

### 🎯 Acesso Rápido por Interesse

| Se você precisa de...                     | Vá para a seção...                                                       |
| ----------------------------------------- | ------------------------------------------------------------------------ |
| Entender o problema e a solução proposta  | [Introdução](#-introdução)                                               |
| Saber o que será entregue                 | [Escopo do Projeto](#-escopo-do-projeto)                                 |
| Ver prazos e marcos                       | [Cronograma Macro](#-fases-do-projeto-e-cronograma-macro)                |
| Entender quem decide o quê                | [Governança](#-gestão-do-projeto-governança-stakeholders-e-controle)     |
| Avaliar riscos do projeto                 | [Riscos e Mitigações](#%EF%B8%8F-riscos-raid-e-mitigações)               |
| Detalhes de cada fase                     | [Fases do Projeto](#-fases-do-projeto-e-cronograma-macro)                |
| Premissas e dependências                  | [Premissas e Restrições](#-premissas-e-restrições-do-projeto)            |
| Como será a operação pós-implantação      | [Operação e Suporte](#-operação-implantação-e-suporte)                   |
| **Ver estimativa de horas por atividade** | [Detalhamento de Horas](#-detalhamento-da-estimativa-de-horas)           |
| **Ver custos e cronograma de pagamentos** | [Estimativa de Investimentos](#-estimativa-de-investimentos-do-projeto)  |
| Arquitetura técnica detalhada             | [Arquitetura](#%EF%B8%8F-arquitetura-e-padrões-técnicos)                 |
| Roadmap de evolução futura                | [Próximos Passos e Evolução Futura](#-próximos-passos-e-evolução-futura) |
| Definições de termos técnicos             | [Glossário](#-glossário)                                                 |

---

# PARTE I – VISÃO EXECUTIVA

> 🎯 **Para BDMs**: Esta parte contém tudo o que você precisa para entender o projeto, aprovar escopo e acompanhar a execução. Tempo estimado: 20 minutos.

---

## 🎯 Introdução

Este projeto visa modernizar o **Módulo Integrador/Interface (Access + VBA)** utilizado pela Cooperflora para integrar com o ERP Néctar, substituindo o modelo de **acesso direto ao SQL Server** por uma **camada de serviços (API)** com contratos explícitos, segurança e observabilidade. A modernização será conduzida de forma **incremental**, por fluxo, seguindo o **Strangler Pattern**, permitindo convivência controlada com o legado até estabilização e migração completa.

Ao final, espera-se uma integração com **contratos OpenAPI versionados**, **controle de acesso**, e **rastreabilidade de ponta a ponta** (logs estruturados, métricas e auditoria por transação). Para BDMs, isso significa menor risco operacional e maior agilidade; para TDMs, uma base técnica governável e preparada para cenários segregados ou em nuvem.

### 🎯 Objetivo do Documento

Este documento consolida o **plano de projeto** para modernização do Módulo Integrador/Interface da Cooperflora, orientando a transição de uma integração baseada em **banco de dados como interface** para uma **camada de serviços (API)**. Ele estrutura o **porquê** (necessidade e urgência), o **o quê** (escopo e entregáveis) e o **como** (estratégia incremental, cronograma, governança e mitigação de riscos).

| Stakeholder                          | O que este documento oferece                                                                         |
| ------------------------------------ | ---------------------------------------------------------------------------------------------------- |
| **BDMs** (Business Decision Makers)  | Visão de valor, riscos de negócio, investimento, critérios de sucesso e impacto em operações         |
| **TDMs** (Technical Decision Makers) | Direcionadores técnicos, arquitetura, contratos, segurança, observabilidade e convivência com legado |

O documento serve como **referência de acompanhamento**, com critérios de aceite e pontos de controle para garantir previsibilidade durante a execução.

### ⚠️ Situação atual e motivação

A integração atual entre o sistema da Cooperflora e o ERP Néctar depende de **acesso direto ao SQL Server**, que opera como "hub" de integração. O módulo legado (Access + VBA) e rotinas SINC leem e escrevem diretamente em tabelas do ERP, criando contratos implícitos baseados em schema e convenções históricas — o que eleva risco operacional, custo de suporte e dificulta evolução.

O cenário futuro **não prevê banco compartilhado** nem acesso direto entre ambientes, tornando a abordagem atual um bloqueio para segregação de rede/credenciais e evolução para nuvem. A motivação central é migrar para uma **camada de serviços** com contratos explícitos e observabilidade, permitindo modernização **fluxo a fluxo** com risco controlado.

| Aspecto da Situação Atual                                               | Descrição Resumida                                                                                                               | Impacto (negócio)                                                                                                                                                                                | Objetivo (negócio e técnico)                                                                                                                                                                        |
| ----------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Integração acoplada ao banco do ERP (SQL Server como “hub”)             | Acesso direto às tabelas do ERP via SQL Server como camada de integração; Access/VBA e SINC operam sobre tabelas compartilhadas. | Aumenta risco de indisponibilidade e incidentes em mudanças (schema/infra), eleva custo de suporte e dificulta escalar/segregar ambientes; limita decisões de arquitetura e iniciativas futuras. | Substituir o “hub” no banco por uma camada de serviços (API) com controle de acesso e governança, reduzindo dependência de co-localização e viabilizando o cenário sem banco compartilhado.         |
| Contratos de integração implícitos (regras “de fato”, não formalizadas) | Semântica de dados conhecida "por tradição" e código legado, sem contratos formais versionados; alto risco de regressões.        | Homologação mais lenta e imprevisível, maior chance de retrabalho e regressões, divergência de entendimento entre áreas e aumento de incidentes em mudanças.                                     | Formalizar contratos e padrões (ex.: OpenAPI, versionamento e erros), reduzindo ambiguidades e permitindo evolução controlada por versão/fluxo.                                                     |
| Orquestração por timers/polling                                         | Rotinas VBA por timers varrem dados "novos" periodicamente; gera concorrência, duplicidades e dificulta rastreio.                | Gera atrasos variáveis, duplicidades e janelas operacionais difíceis de gerenciar; aumenta impacto de falhas silenciosas e dificulta cumprir SLAs por fluxo.                                     | Migrar gradualmente para integrações orientadas a transação/serviço, reduzindo polling e estabelecendo controles (idempotência, reprocessamento) com previsibilidade operacional.                   |
| Regras críticas no legado (VBA/rotinas de tela)                         | Lógica de integração misturada com UI em eventos de formulários VBA; monólito difícil de testar e evoluir.                       | Eleva custo e risco de mudanças, cria dependência de conhecimento específico, dificulta escalabilidade do time e aumenta probabilidade de regressões em produção.                                | Centralizar regras de integração em serviços testáveis e governáveis, reduzindo acoplamento com a UI e melhorando capacidade de evolução com segurança.                                             |
| Governança de dados pouco definida (source of truth)                    | Sem matriz formal de propriedade de dados por domínio; rotinas podem realizar dual-write com precedência não documentada.        | Aumenta inconsistências e conciliações manuais, gera conflitos entre sistemas e amplia risco operacional e de auditoria durante operação híbrida.                                                | Definir propriedade e direção do fluxo por domínio, com critérios claros de resolução de conflitos, suportando migração por fluxo com menor risco.                                                  |
| Baixa visibilidade operacional (observabilidade e rastreabilidade)      | Falhas percebidas tardiamente; rastreio depende de logs esparsos e investigação manual; sem correlação de transações.            | Aumenta MTTR e impacto de incidentes, reduz transparência para gestão e suporte, dificulta governança e tomada de decisão baseada em dados.                                                      | Implementar observabilidade (logs estruturados, métricas, auditoria e correlação por transação), com dashboards/alertas por fluxo para operação e governança.                                       |
| Modelo limita evolução para ambientes segregados/nuvem                  | Arquitetura depende de proximidade física e acesso ao SQL Server; isolamento de rede ou nuvem pode quebrar a integração.         | Bloqueia iniciativas de modernização/segregação, aumenta risco de ruptura em mudanças de infraestrutura e reduz flexibilidade para novas integrações e expansão.                                 | Preparar a integração para operar com segurança em cenários segregados/nuvem, preservando continuidade do negócio e abrindo caminho para evoluções futuras (incl. mensageria quando fizer sentido). |

> 📘 **Para detalhes técnicos da arquitetura atual e alvo**, consulte a [Parte III – Fundamentos Técnicos](#parte-iii--fundamentos-técnicos).

---

## 🎯 Escopo do Projeto

Esta seção define os **entregáveis e limites** do projeto de modernização do Módulo Integrador/Interface. A tabela a seguir apresenta o que será implementado: transição do modelo "banco como integração" para camada de serviços, contratos OpenAPI, segurança, observabilidade e operação híbrida por fluxo — tudo dentro das premissas de migração incremental e continuidade operacional.

> **Nota**: A coluna **Benefícios Esperados** está diretamente vinculada aos **Objetivos (negócio e técnico)** definidos na seção "Situação atual e motivação". Cada benefício endereça um ou mais objetivos estratégicos identificados na análise da situação atual.

| Item de Escopo                           | Descrição Resumida                                                                                    | Benefícios Esperados                                                    |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------- |
| **API de Integração (.NET Web API)**     | Camada intermediária com endpoints, validação, resiliência, health checks, logging e correlation-id   | Reduz dependência de co-localização e do banco como "hub"               |
| **Contratos OpenAPI**                    | Contratos formais por domínio/fluxo com versionamento, taxonomia de erros e checklist de conformidade | Reduz ambiguidades, acelera homologação e viabiliza evolução controlada |
| **Fluxo piloto (Cadastro de Pessoas)**   | Primeiro fluxo completo via API com validações, idempotência, auditoria e plano de estabilização      | Entrega valor cedo, prova padrões e acelera migração por ondas          |
| **Operação híbrida por fluxo**           | Feature flags, critérios de cutover, rollback e observabilidade comparativa                           | Mantém continuidade durante transição e reduz custo de incidentes       |
| **Descomissionamento de timers/polling** | Inventário de timers, substituição por chamadas transacionais e roadmap de desligamento               | Reduz duplicidades e fragilidade por concorrência                       |
| **Observabilidade e auditoria**          | Logs estruturados, métricas, dashboards e correlation-id ponta a ponta                                | Reduz MTTR e dá transparência para gestão                               |
| **Segurança da API**                     | Autenticação/autorização, rate limiting e hardening de endpoints                                      | Reduz risco de exposição e habilita cenários segregados                 |
| **Preparação event-driven (opcional)**   | Modelagem de eventos e guideline para evolução assíncrona                                             | Evita "becos sem saída" arquiteturais                                   |

> 📘 **Para detalhes completos de cada item de escopo**, consulte a seção [Detalhamento do Escopo](#-detalhamento-do-escopo) na Parte II.

### 🎯 Escopo por Domínio de Negócio

| Domínio                     | Fluxos em Escopo                                                 | Prioridade        |
| --------------------------- | ---------------------------------------------------------------- | ----------------- |
| **Fundação de Plataforma**  | API de Integração, Contratos OpenAPI, Observabilidade, Segurança | Alta (Fase 1–2)   |
| **Cadastros (Master Data)** | Pessoas (piloto), Produtos, Tabelas auxiliares                   | Alta (Fase 3–4)   |
| **Comercial**               | Pedidos e movimentos                                             | Média (Fase 4)    |
| **Fiscal/Faturamento**      | Faturamento, notas fiscais                                       | Média-Baixa (4–5) |
| **Financeiro**              | Contas a pagar/receber, conciliação                              | Média-Baixa (4–5) |
| **Estoque**                 | Movimentações, inventário                                        | Média-Baixa (5)   |

---

## 👥 Governança e Tomada de Decisão

### 💼 Stakeholders Principais

| Stakeholder              | Organização | Papel no Projeto                                          | Interesse Principal                                       |
| ------------------------ | ----------- | --------------------------------------------------------- | --------------------------------------------------------- |
| **Sponsor Executivo**    | Cooperflora | Patrocinador; aprova investimento e decisões estratégicas | ROI, continuidade do negócio, redução de riscos           |
| **Gerente de Projeto**   | Néctar      | Coordena execução, reporta progresso, gerencia riscos     | Entregas no prazo, qualidade, satisfação do cliente       |
| **Product Owner (PO)**   | Cooperflora | Define prioridades, aceita entregas, representa o negócio | Valor entregue, aderência às necessidades operacionais    |
| **Arquiteto de Solução** | Néctar      | Define padrões técnicos, valida decisões de arquitetura   | Qualidade técnica, aderência aos princípios arquiteturais |

### 📋 Matriz RACI Simplificada

| Entregável / Decisão           | Sponsor | Ger. Projeto | PO  | Arquiteto |
| ------------------------------ | :-----: | :----------: | :-: | :-------: |
| Aprovação de escopo e baseline |    A    |      R       |  C  |     C     |
| Validação de EMVs (2 dias)     |    I    |      R       |  A  |     C     |
| Definição de contratos OpenAPI |    I    |      C       |  A  |     R     |
| Aprovação de go-live por fluxo |    A    |      R       |  A  |     C     |
| Gestão de mudanças             |    A    |      R       |  C  |     C     |

> **Legenda**: R = Responsável | A = Aprovador | C = Consultado | I = Informado

### 🏛️ Fóruns de Decisão

| Fórum                 | Participantes               | Frequência | Propósito                                       |
| --------------------- | --------------------------- | ---------- | ----------------------------------------------- |
| **Comitê Executivo**  | Sponsor, Ger. Projeto, PO   | Mensal     | Decisões estratégicas, mudanças de escopo/custo |
| **Comitê de Projeto** | Ger. Projeto, PO, Arquiteto | Semanal    | Progresso, riscos, priorização                  |
| **Daily Standup**     | Dev Team                    | Diária     | Sincronização, bloqueios                        |

> 📘 **Para detalhes completos de governança**, consulte a seção [Gestão do Projeto](#-gestão-do-projeto-governança-stakeholders-e-controle) na Parte II.

---

## ⚠️ Riscos Principais e Critérios de Sucesso

### 📝 Top 5 Riscos

| Risco                                                   | Prob. | Impacto |   Severidade   | Mitigação Principal                                   |
| ------------------------------------------------------- | :---: | :-----: | :------------: | ----------------------------------------------------- |
| Dependências ocultas no legado (VBA/SQL)                | Alta  |  Alto   | 🔴 **Crítico** | Inventário e engenharia reversa na Fase 0             |
| Inconsistência de dados durante operação híbrida        | Média |  Alto   |  🟠 **Alto**   | Source of truth por domínio; idempotência obrigatória |
| Atrasos em homologação por indisponibilidade do negócio | Alta  |  Médio  |  🟠 **Alto**   | Cronograma com buffers; janelas pré-acordadas         |
| Scope creep e priorização instável                      | Média |  Alto   |  🟠 **Alto**   | Baseline de escopo; processo de change control        |
| Comportamento do legado diverge do esperado             | Média |  Alto   |  🟠 **Alto**   | Testes E2E extensivos; rollback preparado             |

> 📘 **Para registro completo de riscos**, consulte a seção [Riscos e Mitigações](#%EF%B8%8F-riscos-raid-e-mitigações) na Parte II.

### 🏆 Critérios de Sucesso

| Critério                             | Meta                                             | Medição                                     |
| ------------------------------------ | ------------------------------------------------ | ------------------------------------------- |
| **Fluxos migrados para API**         | 100% dos fluxos críticos em escopo               | Contagem de fluxos em estado "API" vs total |
| **Disponibilidade da integração**    | ≥ 99,5% no horário comercial                     | Monitoramento de uptime                     |
| **Taxa de erro em produção**         | < 1% por fluxo após estabilização                | Métricas de erro por endpoint               |
| **Tempo de resposta (p95)**          | < 2 segundos para operações síncronas            | APM / métricas de latência                  |
| **Incidentes críticos pós-migração** | Zero incidentes P1 causados pela nova integração | Registro de incidentes                      |
| **Aderência ao cronograma**          | Desvio máximo de 15% em relação ao baseline      | Comparativo planejado vs realizado          |

---

# PARTE III – FUNDAMENTOS TÉCNICOS

> 🎯 **Para TDMs**: Esta parte apresenta a arquitetura técnica, princípios e padrões de desenvolvimento. Tempo estimado: 25 minutos.

---

## 🏗️ Arquitetura e Padrões Técnicos

### 🟢 Arquitetura alvo

A arquitetura alvo introduz uma **API de Integração (.NET Web API)** como fronteira explícita entre Cooperflora e ERP Néctar, eliminando o banco como mecanismo de integração. O cliente passa a integrar por **HTTP/REST + JSON**, com a API concentrando validação, mapeamento, regras de integração e persistência interna — tudo com **contratos OpenAPI** versionados, idempotência e resiliência (timeouts/retries).

A arquitetura incorpora **observabilidade** (logs estruturados, métricas, correlation-id) e suporta operação híbrida por fluxo (feature flags), permitindo migração incremental com rollback. O princípio central: **a integração não depende de acesso direto ao banco do ERP** e pode operar em cenários segregados/nuvem.

```mermaid
---
title: Arquitetura Alvo - Integração via Camada de Serviços (API)
---
flowchart LR
  %% ===== DEFINIÇÕES DE ESTILO =====
  classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
  classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
  classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
  classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
  classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
  classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
  classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
  classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

  %% ===== SUBGRAPH: COOPERFLORA =====
  subgraph Cooperflora ["🏢 Cooperflora (Cliente)"]
    CLIENTE["📱 Sistema do Cliente<br>(Cooperflora)"]
  end
  style Cooperflora fill:#F8FAFC,stroke:#334155,stroke-width:2px

  %% ===== SUBGRAPH: INTEGRAÇÃO =====
  subgraph Integracao ["🔗 Camada de Integração"]
    API["🚀 API de Integração<br>.NET Web API"]
  end
  style Integracao fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

  %% ===== SUBGRAPH: ERP NÉCTAR =====
  subgraph Nectar ["📦 ERP Néctar"]
    ERP["⚙️ ERP Néctar"]
    DBERP[("💾 Banco do ERP<br>(interno)")]
    ERP -->|"persistência interna"| DBERP
  end
  style Nectar fill:#F0FDF4,stroke:#10B981,stroke-width:2px

  %% ===== SUBGRAPH: PLATAFORMA =====
  subgraph Plataforma ["📊 Operação e Evolução"]
    OBS["📈 Observabilidade<br>Logs + Métricas + Auditoria"]
    FUTURO["📨 Mensageria<br>(Service Bus - Futuro)"]
  end
  style Plataforma fill:#FDF2F8,stroke:#DB2777,stroke-width:2px

  %% ===== CONEXÕES PRINCIPAIS =====
  CLIENTE -->|"HTTP/REST + JSON"| API
  API -->|"Validação e Mapeamento"| ERP

  %% ===== CONEXÕES AUXILIARES =====
  API -.->|"logs estruturados"| OBS
  API -.->|"eventos futuros"| FUTURO

  %% ===== APLICAÇÃO DE ESTILOS =====
  class CLIENTE input
  class API primary
  class ERP secondary
  class DBERP datastore
  class OBS trigger
  class FUTURO external
```

### 🔄 Visão geral comparativa

Esta tabela sintetiza as diferenças entre a arquitetura atual e a arquitetura alvo, destacando os benefícios esperados para cada dimensão.

> **Nota**: A coluna **Benefícios Esperados** está diretamente vinculada aos **Objetivos (negócio e técnico)** definidos na seção "Situação atual e motivação". Cada benefício endereça um ou mais objetivos estratégicos identificados na análise da situação atual.

| Dimensão                                    | Arquitetura Atual                                                                                                                     | Arquitetura Alvo                                                                                                                   | Benefícios Esperados (→ Objetivo)                                                                                                                           |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Fronteira de integração e acoplamento       | Banco como interface: dependência direta de schema/tabelas, co-localização e credenciais; mudanças de banco/infra afetam integrações. | API como fronteira: contratos e gateways definidos; banco do ERP permanece interno ao ERP (não é interface externa).               | Reduz acoplamento e risco de ruptura; substitui o "hub" no banco por camada de serviços; habilita operação em cenários segregados/nuvem.                    |
| Mecanismo de execução e orquestração        | Timers/polling no Access/VBA; varredura de "novos" registros; concorrência/duplicidade dependem de convenções e estados em tabelas.   | Integração transacional via REST/JSON; orquestração explícita na API; evolução opcional para assíncrono quando houver ganho claro. | Elimina polling/timers; melhora previsibilidade de execução; controle explícito de concorrência e reprocessamento.                                          |
| Contratos e versionamento                   | Contratos implícitos (colunas/flags/convenções); sem versionamento formal; alto risco de regressão em alterações.                     | OpenAPI como fonte de verdade; versionamento semântico (ex.: `/v1`); taxonomia de erros e validações padronizadas.                 | Elimina ambiguidades e "efeitos colaterais"; habilita testes de contrato automatizados e compatibilidade planejada entre versões.                           |
| Observabilidade e rastreabilidade           | Baixa: rastreio por investigação em Access/SQL, logs esparsos e estados em tabelas; correlação entre etapas é limitada.               | Logs estruturados, correlation-id ponta a ponta, métricas por endpoint/fluxo, dashboards/alertas e auditoria por transação.        | Reduz MTTR; diagnóstico end-to-end via correlation-id; governança operacional com métricas, alertas e trilha de auditoria.                                  |
| Resiliência, idempotência e reprocessamento | Tratamento de falhas "informal": retries manuais/rotinas; risco de duplicidade e inconsistência em reprocessos.                       | Timeouts/retries controlados, idempotência por chave, políticas de erro padronizadas e trilha de reprocessamento auditável.        | Elimina duplicidades e inconsistências; aumenta robustez frente a falhas de rede/ERP; reprocessamento seguro e auditável.                                   |
| Evolução e governança de mudança            | Evolução lenta e arriscada; dependência de especialistas no legado; mudanças no banco podem quebrar integrações sem sinalização.      | Migração incremental (strangler) por fluxo; feature flags e rollback; governança de contrato/escopo e padrões repetíveis.          | Acelera evolução com risco controlado; reduz dependência do legado; centraliza regras em serviços governáveis; viabiliza migração incremental com rollback. |

### 📜 Princípios arquiteturais

Os princípios a seguir, organizados conforme o modelo **BDAT** (Business, Data, Application, Technology), orientam todas as decisões técnicas deste projeto. Cada princípio endereça diretamente os problemas da situação atual e sua aderência é **obrigatória** em todas as fases, verificada nos gates de decisão.

Desvios requerem aprovação formal com justificativa documentada e análise de impacto. As tabelas apresentam cada princípio, descrição e justificativa técnica.

#### 💼 Princípios de Negócio (Business)

Os princípios de negócio garantem que a modernização preserve a **continuidade operacional** e entregue valor de forma incremental. Eles refletem o compromisso do projeto em minimizar riscos de transição, manter a previsibilidade para stakeholders e assegurar que mudanças sigam governança formal.

A abordagem incremental (Strangler Pattern) é o pilar central, permitindo que cada fluxo seja migrado de forma independente, com possibilidade de rollback e sem interrupção das operações. Isso traduz-se em menor risco para o negócio e entregas frequentes de valor.

| Princípio                    | Descrição                                                           | Justificativa Técnica                                             |
| ---------------------------- | ------------------------------------------------------------------- | ----------------------------------------------------------------- |
| **Continuidade operacional** | A integração deve funcionar sem interrupções durante a modernização | Operação híbrida por fluxo; rollback controlado via feature flags |
| **Evolução incremental**     | Migração fluxo a fluxo (Strangler Pattern), sem "big bang"          | Feature flags; convivência legado/API por fluxo                   |
| **Governança de mudanças**   | Mudanças seguem controle formal com critérios de aceite             | Versionamento de contratos; breaking changes controlados          |

#### 🗃️ Princípios de Dados (Data)

Os princípios de dados asseguram **governança clara** sobre quem é dono de cada informação (source of truth), eliminando ambiguidades que hoje causam conflitos e conciliações manuais. Com contratos explícitos e rastreabilidade por transação, o projeto habilita auditoria eficiente e diagnóstico rápido de problemas.

A formalização via OpenAPI e o uso de correlation-id ponta a ponta transformam a integração em um sistema observável e governável, reduzindo o tempo de homologação e o risco de regressões em produção.

| Princípio                          | Descrição                                                | Justificativa Técnica                             |
| ---------------------------------- | -------------------------------------------------------- | ------------------------------------------------- |
| **Source of truth definido**       | Cada domínio tem um dono claro (quem é fonte de verdade) | Direção de fluxo explícita; sem dual-write        |
| **Contratos explícitos (OpenAPI)** | Payloads, erros e versões documentados formalmente       | OpenAPI como fonte de verdade; testes de contrato |
| **Rastreabilidade por transação**  | Toda operação é rastreável ponta a ponta                 | Correlation-id propagado; logs estruturados       |

#### ⚙️ Princípios de Aplicação (Application)

Os princípios de aplicação definem a estrutura de **desacoplamento e separação de responsabilidades** que permite evoluir a integração de forma independente do ERP e do sistema do cliente. Com a API como fronteira, mudanças no schema do banco não propagam mais para os consumidores.

A idempotência como requisito obrigatório elimina problemas de duplicidade em reprocessamentos, enquanto a separação entre UI, regras de integração e domínio reduz a dependência de especialistas no legado e viabiliza testes automatizados.

| Princípio                                       | Descrição                                       | Justificativa Técnica                                                   |
| ----------------------------------------------- | ----------------------------------------------- | ----------------------------------------------------------------------- |
| **Desacoplamento (sem acesso direto ao banco)** | Sistema do cliente não depende do schema do ERP | API como fronteira; banco interno ao ERP                                |
| **Separação de responsabilidades**              | UI, regras de integração e domínio separados    | Lógica em serviços testáveis ou stored procedures; legado reduzido a UI |
| **Idempotência e resiliência**                  | Reprocessamentos não corrompem dados            | Chaves de idempotência; retries controlados                             |

#### 💻 Princípios de Tecnologia (Technology)

Os princípios de tecnologia garantem que a solução seja **observável, segura e preparável para cenários futuros** de segregação de ambientes ou evolução para nuvem. Observabilidade não é opcional: tudo que integra deve produzir métricas, logs estruturados e alertas acionáveis.

Segurança por design significa que autenticação, autorização e hardening são implementados desde a primeira linha de código, não como "camada adicional" posterior. A independência de co-localização de banco é requisito arquitetural para habilitar iniciativas futuras de modernização.

| Princípio                            | Descrição                                            | Justificativa Técnica                                                    |
| ------------------------------------ | ---------------------------------------------------- | ------------------------------------------------------------------------ |
| **Observabilidade como requisito**   | Tudo que integra deve ser monitorável e auditável    | Logs estruturados; métricas; dashboards/alertas                          |
| **Segurança por design**             | Autenticação, autorização e hardening desde o início | OAuth2/API Key + mTLS (quando aplicável); TLS obrigatório; rate limiting |
| **Preparação para nuvem/segregação** | Integração funciona sem co-localização de banco      | API REST/JSON; sem dependência de rede local                             |

### 🛠️ Padrões técnicos de integração

Esta subseção detalha os **padrões técnicos** que operacionalizam os princípios arquiteturais definidos acima. Enquanto os princípios orientam "o quê" e "por quê", os padrões definem "como" implementar. A aderência a esses padrões é verificada nos critérios de aceite de cada fase e nos code reviews.

Os padrões abrangem definição de contratos (OpenAPI), tratamento de erros, idempotpência, propriedade de dados e critérios para evolução event-driven. Cada padrão foi selecionado para endereçar riscos específicos identificados na situação atual e garantir consistência entre os fluxos migrados.

#### 📝 Padrão de API e contratos

| Aspecto           | Padrão Definido                                                                     |
| ----------------- | ----------------------------------------------------------------------------------- |
| **Estilo**        | REST/JSON como protocolo de integração                                              |
| **Contratos**     | OpenAPI/Swagger como fonte de verdade; especificação versionada por fluxo           |
| **Versionamento** | Versão no path (`/v1`, `/v2`); política de compatibilidade e deprecação documentada |
| **Geração**       | Clientes gerados a partir do contrato quando aplicável (SDK, tipos)                 |

#### ⚠️ Tratamento de erros

| Código HTTP | Categoria          | Uso                                                      |
| :---------: | ------------------ | -------------------------------------------------------- |
|     4xx     | Erros de validação | Payload inválido, campos obrigatórios, regras de negócio |
|     401     | Autenticação       | Token ausente ou inválido                                |
|     403     | Autorização        | Permissão negada para a operação                         |
|     409     | Conflito           | Violação de idempotência ou estado inconsistente         |
|     503     | Indisponibilidade  | ERP ou dependência fora do ar                            |

**Payload de erro padrão:**

```json
{
  "code": "VALIDATION_ERROR",
  "message": "Descrição legível do erro",
  "details": [{ "field": "campo", "issue": "descrição" }],
  "correlationId": "uuid-da-transacao"
}
```

#### 🔄 Idempotência e reprocessamento

| Aspecto           | Padrão                                                                                |
| ----------------- | ------------------------------------------------------------------------------------- |
| **Chave**         | Header `Idempotency-Key` ou chave de negócio + origem (ex.: `pedido-123-cooperflora`) |
| **Comportamento** | Reenvio retorna mesmo resultado sem duplicar efeitos colaterais                       |
| **Auditoria**     | Resultado do reprocessamento registrado com correlation-id                            |
| **Janela**        | Idempotência garantida por período configurável (ex.: 24h)                            |

#### 🗂️ Propriedade de dados (source of truth)

| Domínio     | Source of Truth | Direção do Fluxo                       | Observação        |
| ----------- | --------------- | -------------------------------------- | ----------------- |
| Pessoas     | A definir       | Cooperflora → ERP ou ERP → Cooperflora | Validar na Fase 0 |
| Produtos    | A definir       | A definir                              | Validar na Fase 0 |
| Pedidos     | A definir       | A definir                              | Validar na Fase 0 |
| Faturamento | A definir       | A definir                              | Validar na Fase 0 |

> **Regra**: Evitar dual-write. Quando inevitável durante transição, exigir governança explícita e trilha de auditoria.

#### 📡 Evolução para event-driven

| Critério para adoção                        | Padrão                             |
| ------------------------------------------- | ---------------------------------- |
| Picos de carga que exigem desacoplamento    | Considerar fila (ex.: Service Bus) |
| Latência tolerável (não crítico tempo-real) | Candidato a assíncrono             |
| Múltiplos consumidores                      | Modelar como evento publicado      |

**Padrões obrigatórios para event-driven:**

- Dead Letter Queue (DLQ) para mensagens não processadas
- Retries com backoff exponencial
- Tratamento de poison messages
- Preservação de correlation-id entre eventos

### 📐 Diretrizes de arquitetura e desenvolvimento

#### 🏛️ Arquitetura em camadas

A arquitetura em camadas organiza a API de Integração em **quatro níveis de responsabilidade** distintos: API (Controllers), Aplicação (Services), Domínio (Entities) e Infraestrutura (Repositories). Essa separação garante que cada camada tenha uma única razão para mudar, facilitando manutenção, testes e evolução independente.

A camada de API é responsável por validação de entrada, autenticação e rate limiting. A camada de Aplicação orquestra os casos de uso e mapeamentos. O Domínio contém as regras de negócio puras. A Infraestrutura abstrai o acesso a dados e gateways externos, incluindo a integração com o ERP.

```mermaid
---
title: Arquitetura em Camadas - API de Integração
---
block-beta
  %% ===== DEFINIÇÕES DE ESTILO =====
  classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
  classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
  classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
  classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
  classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
  classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
  classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
  classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

  columns 1

  %% ===== CAMADA 1: API (Controllers) =====
  block:api["🌐 API (Controllers)"]
    api_desc["Validação de entrada | Autenticação | Rate limiting"]
  end

  space

  %% ===== CAMADA 2: Aplicação (Services) =====
  block:app["⚙️ Aplicação (Services)"]
    app_desc["Orquestração | Mapeamento | Casos de uso"]
  end

  space

  %% ===== CAMADA 3: Domínio (Entities) =====
  block:domain["📦 Domínio (Entities)"]
    domain_desc["Regras de negócio | Validações de domínio"]
  end

  space

  %% ===== CAMADA 4: Infraestrutura (Repositories) =====
  block:infra["🗄️ Infraestrutura (Repositories)"]
    infra_desc["Acesso a dados | Gateways externos | ERP"]
  end

  %% ===== CONEXÕES ENTRE CAMADAS =====
  api --> app
  app --> domain
  domain --> infra

  %% ===== APLICAÇÃO DE ESTILOS =====
  class api primary
  class app trigger
  class domain secondary
  class infra datastore
  class api_desc,app_desc,domain_desc,infra_desc input
```

| Diretriz                       | Descrição                                          |
| ------------------------------ | -------------------------------------------------- |
| Validação na borda             | Validar entrada na camada API antes de propagar    |
| Regras de integração testáveis | Lógica em serviços com injeção de dependência      |
| Desacoplamento do ERP          | Acesso ao ERP via gateways/repositórios abstraídos |

#### 🧪 Estratégia de testes

| Tipo           | Escopo                           | Ferramenta/Abordagem                    |
| -------------- | -------------------------------- | --------------------------------------- |
| **Unitário**   | Regras de validação e mapeamento | xUnit/NUnit + mocks                     |
| **Integração** | API ↔ ERP (ou mocks controlados) | TestServer + dados de referência        |
| **Contrato**   | Validação do OpenAPI             | Mock server / consumer-driven contracts |
| **E2E**        | Cenários por fluxo               | Auditoria de efeitos + correlation-id   |

#### 🚀 DevOps e ambientes

| Ambiente | Propósito                          | Dados                                |
| -------- | ---------------------------------- | ------------------------------------ |
| **DEV**  | Desenvolvimento e testes unitários | Dados sintéticos ou anonimizados     |
| **HML**  | Homologação com stakeholders       | Dados representativos (anonimizados) |
| **PRD**  | Produção                           | Dados reais                          |

**Pipeline CI/CD:**

1. Build + lint
2. Testes unitários
3. Validação de contrato OpenAPI
4. Testes de integração
5. Deploy para ambiente alvo
6. Smoke test pós-deploy

---

### 📝 Detalhamento Técnico dos Entregáveis

Esta subseção detalha os **entregáveis técnicos** do projeto de modernização do Módulo Integrador/Interface. A tabela a seguir apresenta o que será implementado: transição do modelo "banco como integração" para camada de serviços, contratos OpenAPI, segurança, observabilidade e operação híbrida por fluxo — tudo dentro das premissas de migração incremental e continuidade operacional.

> **Nota**: A coluna **Benefícios Esperados** está diretamente vinculada aos **Objetivos (negócio e técnico)** definidos na seção "Situação atual e motivação". Cada benefício endereça um ou mais objetivos estratégicos identificados na análise da situação atual.

| Item de Escopo                                           | Descrição Resumida                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Benefícios Esperados (→ Objetivo)                                                                                                         |
| -------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------- |
| API de Integração (.NET Web API) — fundação técnica      | Implementar a **camada intermediária** responsável por expor endpoints/consumers e centralizar a lógica de integração.<br><br>Inclui (mínimo): estrutura de solução e arquitetura (camadas/limites), validação de entrada, padronização de erros, resiliência (timeouts/retries controlados), health checks, logging estruturado e correlação por transação (correlation-id).<br><br>Integração com o ERP via componentes definidos (ex.: chamadas ao ERP e/ou acesso ao SQL Server do ERP quando aplicável), sem expor o banco como interface externa. | Reduz dependência de co-localização e do banco como “hub”, elevando governança e previsibilidade.                                         |
| Contratos OpenAPI — governança e versionamento           | Definir contratos por domínio/fluxo (ex.: pessoas, produtos, pedidos), com **OpenAPI/Swagger** como fonte de verdade.<br><br>Inclui: modelagem de payloads, validações, códigos de retorno, taxonomia de erros, regras de breaking change, estratégia de versionamento (ex.: `/v1`, `/v2`) e requisitos mínimos por fluxo (idempotência, limites e SLAs alvo quando aplicável).<br><br>Artefatos gerados: especificação OpenAPI versionada e checklist de conformidade por endpoint (DoD de contrato).                                                  | Reduz ambiguidades, acelera homologação e viabiliza evolução controlada por versão.                                                       |
| Fluxo piloto end-to-end — “Cadastro de Pessoas”          | Selecionar e implementar um fluxo piloto de alto valor e risco controlado, com execução completa via API.<br><br>Inclui: mapeamento do fluxo no legado (VBA/SQL/SINC), contrato OpenAPI, validações, idempotência, instrumentação (logs/métricas/auditoria), testes (unitário/integração/E2E quando aplicável), e plano de estabilização em produção (janela, métricas de sucesso, rollback).<br><br>Resultado esperado: blueprint repetível para os demais fluxos.                                                                                     | Entrega valor cedo com risco controlado, provando padrões e acelerando a migração por ondas.                                              |
| Operação híbrida por fluxo — roteamento e rollback       | Definir e implementar convivência **por fluxo** (Legado/Híbrido/API), com roteamento explícito e governado.<br><br>Inclui: feature flags por fluxo, critérios de cutover, procedimentos de fallback/rollback, trilha de decisão (quem aprova e quando), e observabilidade comparativa (legado vs API) para detectar desvios.<br><br>Premissa operacional: evitar dual-write e reduzir conflitos com regras claras de propriedade do dado por domínio.                                                                                                   | Mantém continuidade do negócio durante a transição e reduz custo de incidentes em mudanças.                                               |
| Descomissionamento de timers/polling e acessos diretos   | Reduzir progressivamente timers do Access/VBA e rotinas que leem/escrevem direto no SQL do ERP.<br><br>Inclui: inventário e classificação de timers, substituição por chamadas transacionais via API, definição de controles (idempotência/reprocessamento), e roadmap de desligamento com critérios de aceite por fluxo.<br><br>Durante transição, timers remanescentes devem ser tratados como temporários e monitorados (alertas/telemetria).                                                                                                        | Reduz atrasos variáveis, duplicidades e fragilidade por concorrência; aumenta previsibilidade operacional.                                |
| Observabilidade e auditoria por transação                | Implementar capacidade de operação e diagnóstico por fluxo: logs estruturados, métricas (latência, taxa de erro, volume), auditoria por transação e correlação ponta a ponta (correlation-id propagado).<br><br>Inclui: dashboards e alertas operacionais, trilha de reprocessamento e evidências para suporte/auditoria, com visão por ambiente e criticidade.<br><br>Objetivo técnico: reduzir investigação manual em banco/Access e tornar falhas detectáveis rapidamente.                                                                           | Reduz MTTR, melhora governança e dá transparência para gestão e operação.                                                                 |
| Segurança da API — autenticação, autorização e hardening | Definir e implementar autenticação/autorização para consumo da API e padrões de segurança operacional.<br><br>Inclui: mecanismo de auth (ex.: OAuth2, API Key, mTLS conforme restrição), segregação de ambientes/segredos, validação de payload, rate limiting e práticas de hardening de endpoints.<br><br>Também inclui padrões mínimos de acesso a dados internos (princípio do menor privilégio) para reduzir risco de exposição.                                                                                                                   | Reduz risco de exposição e substitui o “acesso ao banco” como mecanismo de integração; habilita cenários com rede/credenciais segregadas. |
| Preparação para evolução event-driven (opcional)         | Planejar (sem implantar obrigatoriamente) a evolução para assíncrono onde fizer sentido.<br><br>Inclui: modelagem de eventos por domínio, critérios para quando usar síncrono vs assíncrono, desenho de padrões (retry, DLQ, idempotência, ordenação), e requisitos para adoção futura de fila (ex.: Service Bus).<br><br>Entregável: guideline técnico e backlog priorizado para evolução, sem desviar do foco do MVP (API + fluxos críticos).                                                                                                         | Evita “becos sem saída” arquiteturais e preserva foco no essencial, mantendo caminho claro para evoluções futuras.                        |

#### 📦 Entregáveis Mínimos Validáveis (EMV)

Para cada item de escopo, a Néctar produzirá um **Entregável Mínimo Validável (EMV)** que permite à Cooperflora validar e aprovar o item de forma objetiva e imediata. Este modelo garante transparência, acelera feedback e reduz risco de retrabalho.

> **⚠️ Regra de Aprovação Tácita**
>
> A Cooperflora terá **2 (dois) dias úteis** para validar e aprovar cada EMV a partir da data de entrega formal. Após esse prazo:
>
> - O EMV será considerado **automaticamente aprovado** (aprovação tácita)
> - Qualquer solicitação de ajuste posterior será tratada como **mudança de escopo**
> - Mudanças de escopo impactarão **custos e prazos** conforme processo de Change Control
>
> **Justificativa**: Esta regra evita bloqueios no cronograma por atrasos de validação e garante cadência previsível de entregas. O prazo de 2 dias é suficiente para revisão técnica e de negócio, mantendo o projeto em ritmo saudável.

| Item de Escopo                           | Entregável Mínimo Validável (EMV)                                                                 | Critério de Aceite do EMV                                                                     | Fase |
| ---------------------------------------- | ------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- | :--: |
| **API de Integração (.NET Web API)**     | Endpoint `/health` funcional em DEV com Swagger, arquitetura em camadas, logging e correlation-id | Health check = 200 OK; Swagger UI acessível; logs com correlation-id; arquitetura documentada |  2   |
| **Contratos OpenAPI**                    | Especificação OpenAPI v1 do fluxo piloto (Pessoas) com payloads, erros e exemplos                 | Especificação válida; payloads documentados; taxonomia de erros; exemplos incluídos           |  1   |
| **Fluxo piloto (Cadastro de Pessoas)**   | Endpoint de cadastro funcional em HML com validação, idempotência, auditoria e testes             | Cadastro cria registro no ERP; reenvio não duplica; auditoria; testes ≥90%                    |  3   |
| **Operação híbrida por fluxo**           | Feature flag do piloto com roteamento Legado/API e rollback testado em HML                        | Flag alterna fluxo; rollback OK em HML; procedimento documentado                              |  3   |
| **Descomissionamento de timers/polling** | Inventário de timers com criticidade e roadmap de desligamento                                    | Lista com descrição, frequência, criticidade; dependências; roadmap com datas                 |  0   |
| **Observabilidade e auditoria**          | Dashboard operacional básico + logs com correlation-id para o piloto                              | Dashboard com métricas; logs por correlation-id; alertas configurados                         |  3   |
| **Segurança da API**                     | Autenticação (API Key/OAuth2) + rate limiting para o piloto                                       | Sem credencial = 401; rate limiting funcional; credenciais segregadas                         |  2   |
| **Preparação event-driven (opcional)**   | Guideline técnico com critérios de adoção, padrões DLQ/retry e backlog de candidatos              | Documento com critérios; padrões definidos; ≥3 candidatos priorizados                         |  4   |

**Fluxo de Validação dos EMVs:**

```mermaid
---
title: Fluxo de Validação dos EMVs (Entregáveis Mínimos Validáveis)
---
flowchart LR
    %% ===== DEFINIÇÕES DE ESTILO =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== SUBGRAPH: ENTREGA =====
    subgraph entrega ["📤 Entrega"]
        direction LR
        A["📦 Néctar entrega<br>EMV"]
        B["📧 Notificação<br>formal ao cliente"]
        A -->|"notifica"| B
    end
    style entrega fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== SUBGRAPH: VALIDAÇÃO =====
    subgraph validacao ["⏱️ Validação (2 dias úteis)"]
        direction LR
        C{"⏱️ Validação em<br>2 dias úteis?"}
        D["📝 Feedback<br>recebido"]
        E["✅ Aprovação<br>Tácita"]
        C -->|"Sim"| D
        C -->|"Não"| E
    end
    style validacao fill:#FFFBEB,stroke:#D97706,stroke-width:2px

    %% ===== SUBGRAPH: RESULTADO =====
    subgraph resultado ["📋 Resultado"]
        direction LR
        F{"🔍 Aprovado?"}
        G["✅ EMV<br>Aprovado"]
        H["📋 Ajustes<br>dentro do escopo"]
        I["➡️ Próxima<br>etapa"]
        F -->|"Sim"| G
        F -->|"Não"| H
        G -->|"avança"| I
    end
    style resultado fill:#F0FDF4,stroke:#10B981,stroke-width:2px

    %% ===== CONEXÕES ENTRE FASES =====
    entrega -->|"inicia validação"| validacao
    D -->|"analisa"| F
    E -->|"aprovado automaticamente"| G
    H -->|"retrabalho"| A

    %% ===== APLICAÇÃO DE ESTILOS =====
    class A,B primary
    class C,F decision
    class E,G secondary
    class D,H,I input
```

> **Nota**: Os EMVs são **marcos de validação intermediários** — não substituem os critérios de aceite completos de cada fase. Servem para garantir alinhamento contínuo e detectar desvios cedo, reduzindo risco de retrabalho ao final das fases.

#### 📦 Premissas Específicas por Item de Escopo

As premissas abaixo são **específicas para cada item de escopo** e complementam as premissas gerais do projeto. Cada premissa está diretamente vinculada a um entregável e define condições técnicas ou operacionais que devem ser verdadeiras para o sucesso do item.

> **🎯 Legenda de Severidade** — Consulte a seção [Premissas e Restrições do Projeto](#-premissas-e-restrições-do-projeto) para definição completa dos níveis.

##### API de Integração (.NET Web API)

|  ID  | Premissa                                                                                              | Responsável | Impacto se Falsa                                                 |  Severidade  | Impacto em Investimentos (Cooperflora)                                       |
| :--: | ----------------------------------------------------------------------------------------------------- | ----------- | ---------------------------------------------------------------- | :----------: | ---------------------------------------------------------------------------- |
| PE01 | Arquitetura de referência (.NET Web API com camadas) será aprovada antes do início do desenvolvimento | Néctar      | Retrabalho estrutural; débito técnico acumulado                  | 🟠 **Alto**  | —                                                                            |
| PE02 | Componentes de integração com ERP (SDK/bibliotecas) estarão disponíveis e documentados                | Néctar      | Atraso no desenvolvimento; necessidade de engenharia reversa     | 🟠 **Alto**  | —                                                                            |
| PE03 | Padrões de resiliência (circuit breaker, retry, timeout) serão definidos na Fase 1                    | Néctar      | Falhas em cascata; comportamento inconsistente sob carga         | 🟠 **Alto**  | —                                                                            |
| PE04 | Ambiente de execução suportará .NET 6+ (ou versão acordada)                                           | Cooperflora | Limitações de runtime; impossibilidade de usar recursos modernos | 🟡 **Médio** | **Custo de adequação de infraestrutura** se ambiente legado for incompatível |

##### Contratos OpenAPI

|  ID  | Premissa                                                                                   | Responsável          | Impacto se Falsa                                                     |   Severidade   | Impacto em Investimentos (Cooperflora)                                      |
| :--: | ------------------------------------------------------------------------------------------ | -------------------- | -------------------------------------------------------------------- | :------------: | --------------------------------------------------------------------------- |
| PE05 | Regras de negócio de cada fluxo serão documentadas pelo PO antes da modelagem do contrato  | Cooperflora          | Contratos incompletos ou incorretos; retrabalho em fases posteriores | 🔴 **Crítico** | **Retrabalho de workshops**: custo de reagendamento e mobilização de equipe |
| PE06 | Taxonomia de erros será padronizada e aprovada antes da implementação do primeiro endpoint | Néctar + Cooperflora | Inconsistência de mensagens de erro; dificuldade de diagnóstico      |  🟡 **Médio**  | —                                                                           |
| PE07 | Política de versionamento e breaking changes será acordada antes do piloto                 | Néctar + Cooperflora | Contratos quebrados sem governança; impacto em consumidores          |  🟠 **Alto**   | —                                                                           |
| PE08 | SLAs de latência e disponibilidade serão definidos por fluxo antes da implementação        | Cooperflora          | Expectativas desalinhadas; discussões pós-implantação                |  🟡 **Médio**  | **Renegociação de SLA**: possível custo de ajustes contratuais              |

##### Fluxo Piloto (Cadastro de Pessoas)

|  ID  | Premissa                                                                                             | Responsável          | Impacto se Falsa                                             |   Severidade   | Impacto em Investimentos (Cooperflora)                               |
| :--: | ---------------------------------------------------------------------------------------------------- | -------------------- | ------------------------------------------------------------ | :------------: | -------------------------------------------------------------------- |
| PE09 | Fluxo de cadastro de pessoas no legado será congelado durante a migração (sem novas funcionalidades) | Cooperflora          | Divergência entre legado e API; necessidade de reconciliação | 🔴 **Crítico** | **Retrabalho de sincronização**: custo de análise e ajuste de regras |
| PE10 | Dados de teste representativos (anonimizados) estarão disponíveis para validação do piloto           | Cooperflora          | Testes não representam cenários reais; defeitos em produção  |  🟠 **Alto**   | **Correções emergenciais**: custo premium de suporte fora do horário |
| PE11 | Critérios de rollback e janela de estabilização serão definidos antes do go-live do piloto           | Néctar + Cooperflora | Rollback desorganizado; tempo de recuperação elevado         |  🟠 **Alto**   | —                                                                    |
| PE12 | Métricas de baseline do legado (volume, latência, erros) serão coletadas antes da migração           | Néctar               | Impossibilidade de comparar performance; falta de baseline   |  🟡 **Médio**  | —                                                                    |

##### Operação Híbrida

|  ID  | Premissa                                                                                       | Responsável | Impacto se Falsa                                       |   Severidade   | Impacto em Investimentos (Cooperflora)                                   |
| :--: | ---------------------------------------------------------------------------------------------- | ----------- | ------------------------------------------------------ | :------------: | ------------------------------------------------------------------------ |
| PE13 | Feature flags por fluxo serão implementadas com capacidade de rollback em tempo real           | Néctar      | Rollback lento ou manual; aumento de MTTR              |  🟠 **Alto**   | —                                                                        |
| PE14 | Matriz de propriedade de dados (source of truth) será validada antes de cada migração de fluxo | Cooperflora | Conflitos de dados; dual-write não governado           | 🔴 **Crítico** | **Reconciliação manual**: custo de análise e correção de inconsistências |
| PE15 | Procedimentos de cutover e fallback serão documentados e testados em HML antes de PRD          | Néctar      | Incidentes em produção por procedimentos não validados |  🟠 **Alto**   | —                                                                        |
| PE16 | Comunicação de mudança de fluxo será feita aos usuários com antecedência mínima de 1 semana    | Cooperflora | Resistência à mudança; erros por desconhecimento       |  🟡 **Médio**  | —                                                                        |

##### Descomissionamento de Timers/Polling

|  ID  | Premissa                                                                                         | Responsável          | Impacto se Falsa                                               |   Severidade   | Impacto em Investimentos (Cooperflora)                      |
| :--: | ------------------------------------------------------------------------------------------------ | -------------------- | -------------------------------------------------------------- | :------------: | ----------------------------------------------------------- |
| PE17 | Inventário completo de timers e rotinas de polling será entregue na Fase 0                       | Néctar               | Timers não mapeados causam efeitos colaterais durante migração | 🔴 **Crítico** | —                                                           |
| PE18 | Cada timer desativado terá critérios de aceite definidos (volume processado via API, zero erros) | Néctar + Cooperflora | Desativação prematura; falhas silenciosas                      |  🟠 **Alto**   | **Reativação emergencial**: custo de diagnóstico e rollback |
| PE19 | Timers remanescentes durante transição serão monitorados com alertas específicos                 | Néctar               | Falhas em timers não detectadas; impacto em dados              |  🟡 **Médio**  | —                                                           |

##### Observabilidade e Auditoria

|  ID  | Premissa                                                                                 | Responsável          | Impacto se Falsa                                  |  Severidade  | Impacto em Investimentos (Cooperflora)                               |
| :--: | ---------------------------------------------------------------------------------------- | -------------------- | ------------------------------------------------- | :----------: | -------------------------------------------------------------------- |
| PE20 | Ferramenta de APM/logging será definida e provisionada antes da Fase 2                   | Néctar + Cooperflora | Logs não estruturados; dificuldade de diagnóstico | 🟠 **Alto**  | **Licenciamento de ferramentas**: possível custo de aquisição de APM |
| PE21 | Padrão de correlation-id será implementado em todas as camadas desde o primeiro endpoint | Néctar               | Rastreabilidade comprometida; investigação manual | 🟠 **Alto**  | —                                                                    |
| PE22 | Dashboards operacionais serão entregues junto com cada fluxo migrado                     | Néctar               | Operação sem visibilidade; aumento de MTTR        | 🟡 **Médio** | —                                                                    |

##### Segurança da API

|  ID  | Premissa                                                                                | Responsável          | Impacto se Falsa                                         |   Severidade   | Impacto em Investimentos (Cooperflora)                                 |
| :--: | --------------------------------------------------------------------------------------- | -------------------- | -------------------------------------------------------- | :------------: | ---------------------------------------------------------------------- |
| PE23 | Mecanismo de autenticação (OAuth2/API Key/mTLS) será definido e aprovado na Fase 1      | Cooperflora + Néctar | Bloqueio de implementação; decisões tardias de segurança | 🔴 **Crítico** | **Custo de adequação**: possível investimento em infraestrutura de IdP |
| PE24 | Políticas de rate limiting e throttling serão definidas por fluxo/consumidor            | Néctar               | Sobrecarga não controlada; degradação de performance     |  🟡 **Médio**  | —                                                                      |
| PE25 | Segregação de segredos (API keys, connection strings) será implementada por ambiente    | Néctar + Cooperflora | Vazamento de credenciais; risco de segurança             | 🔴 **Crítico** | —                                                                      |
| PE26 | Hardening de endpoints seguirá checklist de segurança (OWASP) validado antes do go-live | Néctar               | Vulnerabilidades expostas; risco de ataques              |  🟠 **Alto**   | —                                                                      |

##### Preparação para Event-Driven (Opcional)

|  ID  | Premissa                                                                                       | Responsável          | Impacto se Falsa                                              |  Severidade  | Impacto em Investimentos (Cooperflora) |
| :--: | ---------------------------------------------------------------------------------------------- | -------------------- | ------------------------------------------------------------- | :----------: | -------------------------------------- |
| PE27 | Critérios para adoção de mensageria serão definidos antes de qualquer implementação assíncrona | Néctar + Cooperflora | Adoção prematura ou injustificada; complexidade desnecessária | 🟡 **Médio** | —                                      |
| PE28 | Padrões de DLQ, retry e idempotência para eventos serão documentados como guideline            | Néctar               | Inconsistência em implementações futuras; poison messages     | 🟡 **Médio** | —                                      |
| PE29 | ROI de cada iniciativa event-driven será justificado antes da aprovação de escopo              | Cooperflora          | Investimento sem retorno mensurável                           | 🟢 **Baixo** | —                                      |

> **Resumo das Premissas Específicas por Área**
>
> | Área de Escopo            | Premissas | 🔴 Crítico | 🟠 Alto | 🟡 Médio | 🟢 Baixo | Responsável Principal | Fase(s) Crítica(s) |
> | ------------------------- | :-------: | :--------: | :-----: | :------: | :------: | --------------------- | ------------------ |
> | API de Integração         |     4     |     0      |    3    |    1     |    0     | Néctar                | Fases 1–2          |
> | Contratos OpenAPI         |     4     |     1      |    1    |    2     |    0     | Néctar + Cooperflora  | Fase 1             |
> | Fluxo Piloto              |     4     |     1      |    2    |    1     |    0     | Cooperflora           | Fase 3             |
> | Operação Híbrida          |     4     |     1      |    2    |    1     |    0     | Cooperflora           | Fases 3–4          |
> | Descomissionamento Timers |     3     |     1      |    1    |    1     |    0     | Néctar                | Fases 0, 4         |
> | Observabilidade           |     3     |     0      |    2    |    1     |    0     | Néctar                | Fases 2–4          |
> | Segurança                 |     4     |     2      |    1    |    1     |    0     | Cooperflora + Néctar  | Fases 1–2          |
> | Event-Driven (Opcional)   |     3     |     0      |    0    |    2     |    1     | Cooperflora           | Fase 6             |
> | **TOTAL**                 |  **29**   |   **6**    | **12**  |  **10**  |  **1**   | —                     | —                  |
>
> **Total**: 29 premissas específicas de escopo (PE01–PE29), complementando as 28 premissas gerais do projeto (P01–P28).
>
> **Distribuição de Severidade**: 🔴 6 Críticas (21%) | 🟠 12 Altas (41%) | 🟡 10 Médias (34%) | 🟢 1 Baixa (3%)

#### 🎯 Escopo por domínio de negócio

A tabela acima detalha os entregáveis técnicos. Abaixo, a mesma visão é organizada por **domínio de negócio**, facilitando o entendimento dos stakeholders sobre quais áreas serão impactadas e em qual sequência.

> **Nota**: A coluna **Objetivo** está diretamente vinculada aos **Objetivos (negócio e técnico)** definidos na seção "Situação atual e motivação". Cada objetivo de domínio contribui para a realização dos objetivos estratégicos do projeto.

| Domínio                     | Fluxos em Escopo                                                 | Objetivo (→ Situação Atual)                                                                                                 | Prioridade Sugerida    |
| --------------------------- | ---------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- | ---------------------- |
| **Fundação de Plataforma**  | API de Integração, Contratos OpenAPI, Observabilidade, Segurança | Habilita todos os demais fluxos; sem fundação, não há migração                                                              | Alta (Fase 1–2)        |
| **Cadastros (Master Data)** | Pessoas (piloto), Produtos, Tabelas auxiliares                   | Aumenta previsibilidade e reduz incidentes cadastrais; ideal para validar padrões sem afetar transações de alta criticidade | Alta (Fase 3–4)        |
| **Comercial**               | Pedidos e movimentos                                             | Melhora rastreio operacional e reduz retrabalho; exige governança de consistência (correlation-id, auditoria)               | Média (Fase 4)         |
| **Fiscal/Faturamento**      | Faturamento, notas fiscais                                       | Reduz risco de falhas silenciosas; recomendado após consolidação do padrão nos cadastros                                    | Média-Baixa (Fase 4–5) |
| **Financeiro**              | Contas a pagar/receber, conciliação                              | Reduz inconsistências e conciliações manuais; requer auditoria rigorosa                                                     | Média-Baixa (Fase 4–5) |
| **Estoque**                 | Movimentações, inventário                                        | Melhora rastreabilidade e reduz divergências; integração com outros domínios                                                | Média-Baixa (Fase 5)   |
| **Operação e Governança**   | Runbooks, dashboards, alertas, gestão de mudanças                | Garante continuidade e capacidade de suporte durante operação híbrida                                                       | Contínuo               |

#### 🚫 Fora do escopo

Delimitar explicitamente o que está **fora do escopo** é uma boa prática de gestão de projetos (PMBOK, Change Control). Isso evita "scope creep", mantém o projeto gerenciável e preserva foco na modernização incremental com entregas verificáveis.

**Regra de governança**: Tudo o que não estiver descrito na seção "Escopo do Projeto" é automaticamente considerado fora de escopo. Isso inclui qualquer iniciativa adicional não explicitada, mesmo que correlata ao tema. Qualquer necessidade nova deve seguir o **controle de mudanças**: registrar solicitação, avaliar impacto (prazo/custo/risco/arquitetura/operação), obter aprovação formal e, somente então, atualizar o baseline e planos associados.

| Item fora do escopo                                  | Justificativa                                                                                                         |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Reescrita completa do ERP Néctar                     | Programa maior e não necessário para remover o acoplamento de integração                                              |
| Reescrita completa do sistema do cliente             | O projeto foca no integrador; mudanças no cliente serão restritas ao necessário para consumir a API                   |
| Migração completa para arquitetura event-driven      | A Fase 6 prevê evolução opcional; o objetivo principal é remover o banco como camada de integração                    |
| Projeto integral de migração para Nimbus             | O escopo contempla preparação arquitetural e roadmap, não a migração completa                                         |
| Mudanças funcionais profundas no processo de negócio | O foco é modernização técnica e redução de risco, mantendo comportamento funcional compatível                         |
| Novas integrações não listadas                       | Qualquer fluxo não explicitado na tabela de entregáveis deve passar por controle de mudanças antes de ser incorporado |

---

# PARTE II – EXECUÇÃO DO PROJETO

> 🎯 **Para BDMs e TDMs**: Esta parte detalha as fases de execução, premissas, governança, riscos, investimentos e operação. Tempo estimado: 40 minutos.

---

## 📅 Fases do Projeto e Cronograma Macro

Esta seção apresenta o **roadmap de execução** do projeto, organizado em 7 fases (Fase 0 a Fase 6), com cronograma estimado, marcos de decisão e critérios de aceite. A estrutura foi desenhada para dar visibilidade a **BDMs** (valor entregue, riscos de negócio, pontos de decisão) e **TDMs** (dependências técnicas, entregáveis, critérios de qualidade).

Cada fase possui **gates de decisão** que funcionam como checkpoints obrigatórios antes de avançar para a próxima etapa. O modelo incremental permite ajustes de rota com base em aprendizados, sem comprometer as entregas já estabilizadas. O cronograma é uma estimativa inicial que será refinada na Fase 0 com base no inventário técnico completo.

### 🔄 Estratégia de modernização: Strangler Pattern

A abordagem adotada é o **Strangler Pattern**, com extração gradual da lógica de integração do legado e introdução de uma camada de serviço moderna. O processo é executado **fluxo a fluxo**, garantindo continuidade operacional e redução de risco. Cada fluxo migrado passa por um ciclo completo de validação antes de desativar a rotina equivalente no legado.

O padrão Strangler foi escolhido porque permite **evolução sem "big bang"**: não há necessidade de migrar tudo de uma vez, e o rollback é possível em qualquer etapa via feature flags. Isso reduz drasticamente o risco de indisponibilidade e permite que o negócio valide cada entrega antes de avançar.

```mermaid
---
title: Strangler Pattern - Migração Fluxo a Fluxo
---
flowchart LR
    %% ===== DEFINIÇÕES DE ESTILO =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== SUBGRAPH: LEGADO =====
    subgraph legado ["⚠️ ANTES (Legado)"]
        direction LR
        A1["⏱️ Access/VBA<br>Timer"]
        A2["📋 Leitura tabelas<br>'novos dados'"]
        A3["⚙️ Regras de integração<br>no VBA/SQL"]
        A4["💾 Escrita direta<br>no SQL do ERP"]

        A1 -->|"polling"| A2
        A2 -->|"processa"| A3
        A3 -->|"SQL direto"| A4
    end
    style legado fill:#FFF7ED,stroke:#FB923C,stroke-width:2px

    %% ===== SUBGRAPH: MODERNO =====
    subgraph moderno ["✅ DEPOIS (Com API)"]
        direction LR
        B1["📱 Sistema do Cliente<br>ou Access em modo UI"]
        B2["🚀 API de Integração"]
        B3["⚙️ Validação +<br>Mapeamento +<br>Idempotência"]
        B4["📦 ERP Néctar"]

        B1 -->|"HTTP POST/PUT"| B2
        B2 -->|"valida"| B3
        B3 -->|"persiste controlado"| B4
    end
    style moderno fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== TRANSIÇÃO =====
    legado ==>|"Strangler Pattern"| moderno

    %% ===== APLICAÇÃO DE ESTILOS =====
    class A1,A2,A3,A4 datastore
    class B1,B3,B4 input
    class B2 primary
```

**Mudança fundamental na direção da integração:**

| Modelo Atual (Legado)                                    | Modelo Alvo (API)                                      |
| -------------------------------------------------------- | ------------------------------------------------------ |
| Access **busca** os dados diretamente nas tabelas do ERP | Sistema do cliente **envia** os dados para a API       |
| Integração disparada por timers (polling)                | Integração transacional (request/response)             |
| Responsabilidade difusa entre sistemas                   | Responsabilidade clara: API é o ponto único de entrada |

> **Vantagem**: Sem timers, sem race conditions, responsabilidade clara.

**Ciclo de execução por fluxo:**

| Etapa | Ação                                  | Entregável                                      |
| :---: | ------------------------------------- | ----------------------------------------------- |
|   1   | Mapear fluxo e dependências no legado | Diagrama de fluxo + inventário de dependências  |
|   2   | Definir contrato OpenAPI              | Especificação versionada                        |
|   3   | Implementar fluxo na API              | Endpoint com validação, idempotência, auditoria |
|   4   | Roteamento híbrido (legado → API)     | Feature flag ativa + fallback configurado       |
|   5   | Estabilização e desativação do timer  | Métricas OK + timer desligado                   |
|   6   | Repetir para próximo fluxo            | Padrões consolidados                            |

### ⚖️ Operação híbrida e ciclo de estados

A convivência é gerenciada **por fluxo**, não por "sistema inteiro". Cada fluxo transita por três estados, com critérios de transição e possibilidade de rollback.

```mermaid
---
title: Ciclo de Estados por Fluxo - Operação Híbrida
---
stateDiagram-v2
    %% ===== DIAGRAMA DE ESTADOS: Ciclo de migração por fluxo =====

    %% ===== DEFINIÇÃO DOS ESTADOS =====
    [*] --> Legado: Início do fluxo

    state "🟠 LEGADO" as Legado {
        [*] --> timer_ativo
        timer_ativo: Timers/polling ativos
        timer_ativo --> processando: executa
        processando: Processamento via VBA/SQL
        processando --> [*]
    }

    state "🟡 HÍBRIDO" as Hibrido {
        [*] --> api_ativa
        api_ativa: API ativa (feature flag ON)
        api_ativa --> fallback_disponivel: habilita fallback
        fallback_disponivel: Legado como fallback
        fallback_disponivel --> monitoramento: monitora
        monitoramento: Monitoramento reforçado
        monitoramento --> [*]
    }

    state "🟢 API" as API {
        [*] --> api_exclusiva
        api_exclusiva: Fluxo 100% via API
        api_exclusiva --> timer_desativado: desativa timer
        timer_desativado: Timer legado desativado
        timer_desativado --> [*]
    }

    %% ===== TRANSIÇÕES DE AVANÇO =====
    Legado --> Hibrido: Migração aprovada
    Hibrido --> API: Estabilização concluída

    %% ===== TRANSIÇÕES DE ROLLBACK =====
    Hibrido --> Legado: Rollback controlado
    API --> Hibrido: Rollback excepcional

    %% ===== ESTADO FINAL =====
    API --> [*]: Fluxo migrado

    %% ===== NOTAS EXPLICATIVAS =====
    note right of Legado
        Operação atual via timers/polling
        Acesso direto ao SQL Server
        Contratos implícitos
    end note

    note right of Hibrido
        Período de estabilização: 2 semanas
        Feature flags habilitam rollback instantâneo
        Monitoramento comparativo (legado vs API)
    end note

    note right of API
        Fluxo completamente migrado
        Timer legado desativado
        Observabilidade completa
    end note
```

| Estado      | Descrição                                  | Critério de Transição                                 |
| ----------- | ------------------------------------------ | ----------------------------------------------------- |
| **Legado**  | Fluxo operando via timers/polling          | Contrato aprovado + API implementada                  |
| **Híbrido** | API ativa + legado funcional como fallback | Estabilização OK (≥2 semanas sem incidentes críticos) |
| **API**     | Fluxo 100% via API, timer desativado       | Aceite formal + evidência de desativação              |

**Estratégias de rollback:**

- Feature flags por fluxo com roteamento configurável
- Janela de estabilização (ex.: 2 semanas) com monitoramento reforçado
- Reprocessamento via mecanismos de reenvio/replay com idempotência
- Plano de comunicação com critérios de acionamento de rollback

---

### 🗺️ Visão executiva do roadmap

| Fase | Nome                    | Duração Estimada | Marco de Negócio (BDM)                                 | Marco Técnico (TDM)                                    |
| ---: | ----------------------- | :--------------: | ------------------------------------------------------ | ------------------------------------------------------ |
|    0 | Alinhamento e contenção |   1–2 semanas    | Acordo sobre escopo, riscos mapeados                   | Inventário técnico completo, backlog priorizado        |
|    1 | Definição de contratos  |   1–2 semanas    | Contratos aprovados, governança definida               | OpenAPI v1, padrões de integração documentados         |
|    2 | Fundação da API         |   2–3 semanas    | Infraestrutura pronta para piloto                      | API em DEV/HML, pipeline CI/CD, observabilidade básica |
|    3 | Fluxo piloto            |   2–4 semanas    | **Primeiro fluxo em produção**, valor demonstrado      | Piloto estável, padrões validados, lições aprendidas   |
|    4 | Migração por fluxo      |    1–3 meses     | Fluxos críticos migrados, redução de risco operacional | Timers desativados, operação híbrida governada         |
|    5 | Simplificação do legado |    1–2 meses     | Custo de manutenção reduzido, legado estável           | Rotinas de integração removidas, documentação final    |
|    6 | Evolução opcional       |     Contínuo     | Novas capacidades habilitadas (quando justificado)     | Mensageria, eventos, preparação para Nimbus            |

### 📆 Cronograma macro (referência por semanas)

> **Nota para BDMs**: O cronograma abaixo é uma estimativa baseada em premissas iniciais. Ajustes serão propostos conforme descobertas na Fase 0 e validados em governança antes de impactar prazos/investimento.

> **Nota para TDMs**: As dependências indicam sequência mínima. Algumas atividades podem ser paralelizadas (ex.: setup de infra durante Fase 1), desde que não comprometam qualidade ou criem débito técnico.

Esta seção apresenta **três visualizações complementares** do cronograma, cada uma otimizada para diferentes necessidades:

|     Visualização      |   Público-Alvo   | O que Mostra                                      |
| :-------------------: | :--------------: | :------------------------------------------------ |
|     📊 **Gantt**      |  TDMs + Gestão   | Duração das fases, dependências, caminho crítico  |
|    🚦 **Timeline**    | BDMs + Executivo | Marcos de decisão, datas-chave                    |
| 🔀 **Fluxo de Gates** |    Governança    | Pontos de decisão, caminhos de aprovação/bloqueio |

---

#### 📊 Visão Detalhada – Diagrama de Gantt

O Gantt é a **visão principal** do cronograma, mostrando duração, dependências e o caminho crítico do projeto.

```mermaid
---
title: Roadmap de Fases - Visão Temporal
---
gantt
    %% ===== CONFIGURAÇÃO DO GRÁFICO =====
    dateFormat YYYY-MM-DD
    axisFormat %d/%m/%y
    tickInterval 2week
    todayMarker stroke-width:3px,stroke:#EF4444,opacity:0.8

    %% ===== SEÇÃO: PREPARAÇÃO =====
    section 📋 Preparação
    Fase 0 – Alinhamento e Riscos       :active, f0, 2026-01-13, 2w
    🚦 Gate Go/No-Go                    :milestone, m0, after f0, 0d
    Fase 1 – Contratos OpenAPI          :f1, after f0, 2w
    🚦 Aprovação Contratos              :milestone, m1, after f1, 0d

    %% ===== SEÇÃO: FUNDAÇÃO =====
    section 🏗️ Fundação
    Fase 2 – API e Infraestrutura       :f2, after f1, 3w
    🚦 Checkpoint Infra OK              :milestone, m2, after f2, 0d

    %% ===== SEÇÃO: PILOTO (CRÍTICO) =====
    section 🚀 Piloto
    Fase 3 – Fluxo Piloto (Pessoas)     :crit, f3, after f2, 4w
    🚦 Go-Live Piloto                   :milestone, crit, m3, after f3, 0d

    %% ===== SEÇÃO: MIGRAÇÃO =====
    section 🔄 Migração
    Fase 4 – Operação Híbrida           :f4, after f3, 12w
    Fase 5 – Simplificação Legado       :f5, after f4, 8w
    🏁 Aceite Final                     :milestone, m5, after f5, 0d

    %% ===== SEÇÃO: EVOLUÇÃO =====
    section ✨ Evolução
    Fase 6 – Evoluções Opcionais        :done, f6, after f5, 4w
```

> **Legenda de Cores**:
>
> - 🔴 **Vermelho (crit)**: Caminho crítico – atrasos impactam diretamente a data final
> - 🔵 **Azul (active)**: Fase em andamento
> - ⚫ **Cinza (done)**: Fase opcional/futura
> - 🔷 **Losango**: Marco de decisão (gate)

---

#### 🚦 Visão Executiva – Timeline de Marcos

O Timeline apresenta uma **visão simplificada** focada nas datas-chave e decisões de negócio.

```mermaid
%%{init: {
    'theme': 'base',
    'themeVariables': {
        'cScale0': '#10B981',
        'cScale1': '#3B82F6',
        'cScale2': '#EF4444',
        'cScale3': '#A855F7',
        'cScale4': '#10B981',
        'cScaleLabel0': '#ffffff',
        'cScaleLabel1': '#ffffff',
        'cScaleLabel2': '#ffffff',
        'cScaleLabel3': '#ffffff',
        'cScaleLabel4': '#ffffff'
    }
}}%%
timeline
    title Marcos de Decisão - Visão Executiva
    %% ===== SEÇÃO Q1/2026 =====
    section 📋 Q1/2026
        13/Jan : 🚀 Kick-off Projeto
                : Fase 0 inicia
        27/Jan : 🚦 Gate Go/No-Go
                : Decisão de continuidade
        10/Fev : 📋 Contratos Aprovados
                : OpenAPI v1 validada
    %% ===== SEÇÃO FEV-MAR/2026 =====
    section 🏗️ Fev-Mar/2026
        03/Mar : 🏗️ Infraestrutura Pronta
                : API em DEV/HML
    %% ===== SEÇÃO MAR-ABR/2026 =====
    section 🚀 Mar-Abr/2026
        31/Mar : 🎯 Go-Live Piloto
                : Primeiro fluxo em PRD
    %% ===== SEÇÃO ABR-JUL/2026 =====
    section 🔄 Abr-Jul/2026
        23/Jun : 🔄 Migração Concluída
                : Fluxos críticos OK
    %% ===== SEÇÃO JUL-SET/2026 =====
    section 🏁 Jul-Set/2026
        18/Ago : 🏁 Aceite Final
                : Projeto encerrado
```

> **Paleta de Cores por Seção**:
>
> - 🟢 **Verde**: Preparação e Evolução (baixo risco)
> - 🔵 **Azul**: Fundação (construção técnica)
> - 🔴 **Vermelho**: Piloto (caminho crítico)
> - 🟣 **Roxo**: Migração (maior complexidade)

---

#### 🔀 Fluxo de Decisão – Gates e Aprovações

O fluxograma mostra o **processo de governança**, evidenciando pontos de decisão e caminhos de bloqueio.

```mermaid
%%{init: {
    'theme': 'base',
    'themeVariables': {
        'primaryColor': '#4F46E5',
        'primaryTextColor': '#ffffff',
        'primaryBorderColor': '#312E81',
        'lineColor': '#6B7280',
        'textColor': '#1F2937'
    }
}}%%
flowchart LR
    %% ═══════════════════════════════════════════════════════════════
    %% DIAGRAMA: Fluxo de Gates e Decisões do Projeto
    %% PROPÓSITO: Visualizar pontos de decisão e caminhos de aprovação
    %% ═══════════════════════════════════════════════════════════════

    subgraph prep ["📋 PREPARAÇÃO"]
        direction LR
        F0["🔍 Fase 0<br/>Alinhamento"]
        G0{{"🚦 Go/No-Go"}}
        F1["📝 Fase 1<br/>Contratos"]
        G1{{"🚦 Aprovação"}}
        F0 --> G0
        G0 -->|"✅ Aprovado"| F1
        F1 --> G1
    end

    subgraph fund ["🏗️ FUNDAÇÃO"]
        direction LR
        F2["⚙️ Fase 2<br/>API + Infra"]
        G2{{"🚦 Checkpoint"}}
        F2 --> G2
    end

    subgraph pilot ["🚀 PILOTO"]
        direction LR
        F3["🎯 Fase 3<br/>Fluxo Piloto"]
        G3{{"🚦 Go-Live"}}
        F3 --> G3
    end

    subgraph migr ["🔄 MIGRAÇÃO"]
        direction LR
        F4["🔄 Fase 4<br/>Op. Híbrida"]
        F5["🧹 Fase 5<br/>Simplificação"]
        G5{{"🏁 Aceite"}}
        F4 --> F5
        F5 --> G5
    end

    subgraph evol ["✨ EVOLUÇÃO"]
        direction LR
        F6["📈 Fase 6<br/>Opcional"]
    end

    %% Conexões entre grupos (caminho feliz)
    G1 -->|"✅ Aprovado"| F2
    G2 -->|"✅ OK"| F3
    G3 -->|"✅ Estável"| F4
    G5 -->|"✅ Concluído"| F6

    %% Caminhos de bloqueio/rollback
    G0 -.->|"❌ Bloqueado"| STOP1(("⛔"))
    G1 -.->|"❌ Bloqueado"| STOP2(("⛔"))
    G2 -.->|"❌ Falha"| STOP3(("⛔"))
    G3 -.->|"❌ Instável"| F3

    %% ═══════════════════════════════════════════════════════════════
    %% DEFINIÇÃO DE ESTILOS
    %% ═══════════════════════════════════════════════════════════════
    classDef phase fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px,color:#1E1B4B
    classDef gate fill:#FEF3C7,stroke:#F59E0B,stroke-width:2px,color:#78350F
    classDef critical fill:#FEE2E2,stroke:#EF4444,stroke-width:2px,color:#7F1D1D
    classDef stop fill:#FEE2E2,stroke:#EF4444,stroke-width:2px,color:#991B1B

    class F0,F1,F2,F4,F5,F6 phase
    class F3 critical
    class G0,G1,G2,G3,G5 gate
    class STOP1,STOP2,STOP3 stop

    %% Cores dos grupos
    style prep fill:#F0FDF4,stroke:#10B981,stroke-width:2px
    style fund fill:#EFF6FF,stroke:#3B82F6,stroke-width:2px
    style pilot fill:#FEF2F2,stroke:#EF4444,stroke-width:2px
    style migr fill:#FDF4FF,stroke:#A855F7,stroke-width:2px
    style evol fill:#ECFDF5,stroke:#10B981,stroke-width:2px
```

> **Legenda de Elementos**:
>
> | Forma | Significado |
> |:-----:|:------------|
> | 📦 **Retângulo** | Fase de trabalho |
> | 🔶 **Hexágono** | Gate de decisão |
> | ⭕ **Círculo vermelho** | Ponto de bloqueio |
> | ➡️ **Seta sólida** | Caminho de aprovação |
> | ➡️ **Seta pontilhada** | Caminho de bloqueio/rollback |

---

#### 📋 Resumo Consolidado de Datas

| Janela (semanas) | Fase   | Dependências  | Gate de Decisão                                                  |
| ---------------: | ------ | ------------- | ---------------------------------------------------------------- |
|              1–2 | Fase 0 | —             | **Go/No-Go**: escopo validado, riscos aceitáveis                 |
|              3–4 | Fase 1 | Fase 0        | **Aprovação**: contratos e governança de mudanças                |
|              5–7 | Fase 2 | Fase 1        | **Checkpoint**: infra pronta, smoke test OK                      |
|             8–11 | Fase 3 | Fase 2        | **Go-Live Piloto**: critérios de estabilização atingidos         |
|            12–24 | Fase 4 | Fase 3        | **Checkpoints por onda**: cada domínio migrado tem aceite formal |
|            20–28 | Fase 5 | Fase 4 (80%+) | **Aceite final**: legado simplificado, operação estável          |
|         Contínuo | Fase 6 | Fase 4/5      | **Por demanda**: aprovação de ROI/valor antes de cada iniciativa |

---

### 0️⃣ Fase 0 – Alinhamento e contenção de riscos (1–2 semanas)

| Aspecto       | Descrição                                                                                        |
| ------------- | ------------------------------------------------------------------------------------------------ |
| **Objetivo**  | Criar base de governança, reduzir riscos imediatos e mapear integralmente dependências do legado |
| **Valor BDM** | Visibilidade de riscos e escopo; decisão informada sobre investimento e prioridades              |
| **Valor TDM** | Inventário técnico completo; base para estimativas e arquitetura                                 |

**Principais atividades**

| Atividade                                              | Responsável         | Entregável                        |
| ------------------------------------------------------ | ------------------- | --------------------------------- |
| Inventário técnico do módulo Access/VBA e rotinas SINC | TDM (Néctar)        | Documento de inventário           |
| Mapeamento de pontos de integração                     | TDM (Néctar)        | Diagrama de fluxos e dependências |
| Matriz de propriedade de dados (source of truth)       | BDM + TDM           | Matriz aprovada por domínio       |
| Requisitos não funcionais e restrições                 | TDM (Néctar + Coop) | Lista de requisitos e restrições  |
| Priorização de fluxos para migração                    | BDM (Cooperflora)   | Backlog priorizado                |

**Riscos e mitigação**

| Risco                                    | Probabilidade | Impacto |   Severidade   | Mitigação                                              |
| ---------------------------------------- | :-----------: | :-----: | :------------: | ------------------------------------------------------ |
| Dependências ocultas no VBA/SQL          |     Alta      |  Alto   | 🔴 **Crítico** | Sessões de engenharia reversa + validação com operação |
| Escopo difuso ou expansão não controlada |     Média     |  Alto   |  🟠 **Alto**   | Baseline de escopo formal + controle de mudanças       |

### 1️⃣ Fase 1 – Definição dos contratos de integração (1–2 semanas)

| Aspecto       | Descrição                                                                         |
| ------------- | --------------------------------------------------------------------------------- |
| **Objetivo**  | Transformar integrações implícitas em contratos explícitos e governáveis          |
| **Valor BDM** | Redução de ambiguidades; homologação mais rápida; evolução controlada             |
| **Valor TDM** | Contratos como fonte de verdade; base para testes automatizados e compatibilidade |

**Principais atividades**

| Atividade                                     | Responsável         | Entregável                           |
| --------------------------------------------- | ------------------- | ------------------------------------ |
| Definir endpoints e modelos (DTOs) por fluxo  | TDM (Néctar)        | Especificação OpenAPI v1             |
| Padronizar erros (códigos, mensagens, campos) | TDM (Néctar)        | Taxonomia de erros documentada       |
| Definir estratégia de versionamento           | TDM (Néctar)        | Guideline de versionamento           |
| Definir idempotência por fluxo                | TDM (Néctar)        | Documento de padrões de idempotência |
| Definir autenticação/autorização              | TDM (Néctar + Coop) | Requisitos de segurança aprovados    |

**Riscos e mitigação**

| Risco                             | Probabilidade | Impacto |  Severidade  | Mitigação                                          |
| --------------------------------- | :-----------: | :-----: | :----------: | -------------------------------------------------- |
| Contratos mal definidos           |     Média     |  Alto   | 🟠 **Alto**  | Workshops com exemplos reais + validação com dados |
| Mudanças frequentes nos contratos |     Média     |  Médio  | 🟡 **Médio** | Governança de breaking changes + compatibilidade   |

### 2️⃣ Fase 2 – Fundação da API (2–3 semanas)

| Aspecto       | Descrição                                                                             |
| ------------- | ------------------------------------------------------------------------------------- |
| **Objetivo**  | Disponibilizar a infraestrutura e o esqueleto técnico da API com padrões operacionais |
| **Valor BDM** | Infraestrutura pronta para receber o piloto; redução de risco técnico                 |
| **Valor TDM** | Arquitetura estabelecida; padrões de qualidade definidos; pipeline automatizado       |

**Principais atividades**

| Atividade                                     | Responsável         | Entregável                                 |
| --------------------------------------------- | ------------------- | ------------------------------------------ |
| Estrutura de solução (camadas, DI, validação) | TDM (Néctar)        | Código-fonte da API base                   |
| Logging estruturado e correlação              | TDM (Néctar)        | Padrões de observabilidade implementados   |
| Health checks e métricas                      | TDM (Néctar)        | Endpoints de saúde + métricas expostas     |
| Conectividade segura com ERP                  | TDM (Néctar + Coop) | Conexão validada em DEV/HML                |
| Pipeline CI/CD                                | TDM (Néctar)        | Pipeline funcional com deploy automatizado |
| Configuração de ambientes (DEV/HML/PRD)       | TDM (Néctar + Coop) | Ambientes provisionados e documentados     |

**Riscos e mitigação**

| Risco                                 | Probabilidade | Impacto | Severidade  | Mitigação                                         |
| ------------------------------------- | :-----------: | :-----: | :---------: | ------------------------------------------------- |
| Atraso em provisão de ambientes/infra |     Média     |  Alto   | 🟠 **Alto** | Iniciar setup em paralelo com Fase 1              |
| Falhas de conectividade com ERP       |     Média     |  Alto   | 🟠 **Alto** | Testes antecipados + alinhamento de rede/firewall |

### 3️⃣ Fase 3 – Fluxo Piloto (2–4 semanas)

| Aspecto       | Descrição                                                                                |
| ------------- | ---------------------------------------------------------------------------------------- |
| **Objetivo**  | Implementar o primeiro fluxo via API em produção, com governança, rollback e aprendizado |
| **Valor BDM** | **Primeiro valor em produção**; validação da abordagem; redução de risco para escala     |
| **Valor TDM** | Padrões validados em ambiente real; blueprint repetível para demais fluxos               |

> **Recomendação**: O fluxo **Cadastro de Pessoas** é ideal para piloto por ter alto valor, risco controlado e não afetar transações financeiras críticas.

**Principais atividades**

| Atividade                                   | Responsável         | Entregável                                    |
| ------------------------------------------- | ------------------- | --------------------------------------------- |
| Seleção e definição de critérios de sucesso | BDM + TDM           | Critérios de aceite do piloto                 |
| Implementação do fluxo na API               | TDM (Néctar)        | Endpoint funcional com validação/idempotência |
| Ajustes no legado para convivência          | TDM (Néctar)        | Legado adaptado (quando necessário)           |
| Testes de integração e E2E                  | TDM (Néctar + Coop) | Evidências de testes                          |
| Homologação com usuários                    | BDM (Cooperflora)   | Aceite de homologação                         |
| Go-live com janela de estabilização         | TDM + BDM           | Fluxo em produção                             |
| Elaboração de runbook e alertas             | TDM (Néctar)        | Runbook operacional + dashboards              |

**Riscos e mitigação**

| Risco                               | Probabilidade | Impacto |  Severidade  | Mitigação                                             |
| ----------------------------------- | :-----------: | :-----: | :----------: | ----------------------------------------------------- |
| Incidentes em produção              |     Média     |  Alto   | 🟠 **Alto**  | Rollout progressivo + feature flags + rollback rápido |
| Divergência de dados entre sistemas |     Média     |  Alto   | 🟠 **Alto**  | Auditoria por transação + reprocessamento idempotente |
| Resistência do usuário              |     Baixa     |  Médio  | 🟢 **Baixo** | Comunicação antecipada + acompanhamento pós-go-live   |

### 4️⃣ Fase 4 – Migração por fluxo / Operação híbrida (1–3 meses)

| Aspecto       | Descrição                                                                                        |
| ------------- | ------------------------------------------------------------------------------------------------ |
| **Objetivo**  | Escalar migração fluxo a fluxo, mantendo operação contínua e reduzindo progressivamente o legado |
| **Valor BDM** | Fluxos críticos migrados; redução de risco operacional; menor dependência do legado              |
| **Valor TDM** | Timers desativados; operação híbrida governada; padrões consolidados                             |

**Ondas de migração sugeridas**

| Onda | Domínio                 | Fluxos                                 | Prioridade  | Critério de Conclusão                        |
| :--: | ----------------------- | -------------------------------------- | ----------- | -------------------------------------------- |
|  1   | Cadastros (Master Data) | Pessoas (piloto), Produtos, Auxiliares | Alta        | Todos os cadastros via API + timers inativos |
|  2   | Comercial               | Pedidos, Movimentos                    | Média       | Fluxos transacionais via API                 |
|  3   | Fiscal/Faturamento      | Notas, Faturamento                     | Média-Baixa | Compliance validado + auditoria              |
|  4   | Financeiro              | Contas a pagar/receber, Conciliação    | Média-Baixa | Fluxos financeiros via API + auditoria       |
|  5   | Estoque                 | Movimentações, Inventário              | Média-Baixa | Fluxos de estoque via API + timers inativos  |

**Principais atividades**

| Atividade                                 | Responsável  | Entregável                             |
| ----------------------------------------- | ------------ | -------------------------------------- |
| Migração por domínio (backlog priorizado) | TDM (Néctar) | Fluxos implementados por onda          |
| Desativação de timers por fluxo migrado   | TDM (Néctar) | Timers desligados + evidência          |
| Fortalecimento de observabilidade         | TDM (Néctar) | Dashboards e alertas por fluxo         |
| Gestão de mudanças e comunicação por onda | BDM + TDM    | Comunicados + aceite por onda          |
| Atualização da matriz de fluxos           | TDM (Néctar) | Matriz (legado/híbrido/API) atualizada |

**Riscos e mitigação**

| Risco                                  | Probabilidade | Impacto |  Severidade  | Mitigação                                            |
| -------------------------------------- | :-----------: | :-----: | :----------: | ---------------------------------------------------- |
| Volume/complexidade maior que estimado |     Média     |  Médio  | 🟡 **Médio** | Decomposição do backlog + buffers no cronograma      |
| Fadiga operacional                     |     Média     |  Médio  | 🟡 **Médio** | Cadência de migração com janelas + comunicação clara |
| Regressões em fluxos já migrados       |     Baixa     |  Alto   | 🟡 **Médio** | Testes de regressão + monitoramento contínuo         |

### 5️⃣ Fase 5 – Simplificação do legado (1–2 meses)

| Aspecto       | Descrição                                                                                      |
| ------------- | ---------------------------------------------------------------------------------------------- |
| **Objetivo**  | Reduzir o módulo Access/VBA ao mínimo necessário, removendo responsabilidades de integração    |
| **Valor BDM** | Custo de manutenção reduzido; menor risco operacional; equipe liberada para outras iniciativas |
| **Valor TDM** | Código legado simplificado; documentação final; menor superfície de suporte                    |

**Responsabilidades do módulo legado após simplificação**

O módulo Access/VBA, após a modernização, **deve** se limitar a:

- Exibir informações ao usuário
- Executar código local (validações de UI)
- Invocar a API de integração quando necessário

O módulo **não deve** mais conter:

- Regras de negócio complexas em eventos de formulário
- Funções longas controlando integração
- Acesso direto ao SQL Server do ERP para integrações
- Timers/polling para sincronização de dados

> **Diretriz técnica**: Lógica complexa remanescente deve ser movida para stored procedures (quando necessário manter no banco) ou para a API de integração.

**Principais atividades**

| Atividade                                              | Responsável  | Entregável                      |
| ------------------------------------------------------ | ------------ | ------------------------------- |
| Remoção de formulários/rotinas de integração obsoletas | TDM (Néctar) | Legado sem código de integração |
| Refatoração do VBA remanescente                        | TDM (Néctar) | Código simplificado             |
| Documentação mínima do legado                          | TDM (Néctar) | Documentação operacional        |
| Ajustes finais de runbooks e alertas                   | TDM (Néctar) | Runbooks atualizados            |
| Treinamento de suporte (se necessário)                 | TDM (Néctar) | Equipe capacitada               |

**Riscos e mitigação**

| Risco                                   | Probabilidade | Impacto |  Severidade  | Mitigação                                      |
| --------------------------------------- | :-----------: | :-----: | :----------: | ---------------------------------------------- |
| Dependências remanescentes não mapeadas |     Baixa     |  Alto   | 🟡 **Médio** | Checklist por fluxo antes de remover rotinas   |
| Perda de conhecimento institucional     |     Média     |  Médio  | 🟡 **Médio** | Documentação mínima + sessões de transferência |

### 6️⃣ Fase 6 – Evolução opcional (contínuo)

| Aspecto       | Descrição                                                                                        |
| ------------- | ------------------------------------------------------------------------------------------------ |
| **Objetivo**  | Evoluir a integração para suportar novos requisitos e maior desacoplamento, conforme necessidade |
| **Valor BDM** | Novas capacidades de negócio habilitadas; preparação para iniciativas estratégicas (ex.: Nimbus) |
| **Valor TDM** | Arquitetura event-driven quando justificado; maior resiliência e escalabilidade                  |

> **Nota**: Esta fase é **opcional** e executada **por demanda**. Cada iniciativa deve ser justificada por ROI/valor de negócio e aprovada em governança antes da execução.

**Possíveis iniciativas**

| Iniciativa                       | Gatilho                                      | Benefício                                     |
| -------------------------------- | -------------------------------------------- | --------------------------------------------- |
| Mensageria (Service Bus)         | Picos de carga ou necessidade de assíncrono  | Desacoplamento; resiliência a falhas          |
| Modelagem de eventos por domínio | Necessidade de integração com novos sistemas | Extensibilidade; consistência eventual        |
| Preparação para Nimbus           | Decisão estratégica de migração              | Roadmap técnico; redução de risco de migração |

## 👥 Gestão do Projeto (Governança, Stakeholders e Controle)

Esta seção define a estrutura de **governança, papéis, comunicação e controle** do projeto de modernização do Módulo Integrador. O modelo é **híbrido** — combina práticas formais (controle de mudanças, gestão de riscos, gates de decisão) com elementos ágeis (entregas incrementais, feedback contínuo) para garantir previsibilidade sem perder capacidade de adaptação.

### 💼 Stakeholders e Matriz RACI

A identificação clara dos stakeholders e seus papéis é fundamental para comunicação eficaz e tomada de decisão. A tabela abaixo apresenta os principais grupos de stakeholders e suas responsabilidades no projeto.

| Stakeholder              | Organização | Papel no Projeto                                          | Interesse Principal                                        |
| ------------------------ | ----------- | --------------------------------------------------------- | ---------------------------------------------------------- |
| **Sponsor Executivo**    | Cooperflora | Patrocinador; aprova investimento e decisões estratégicas | ROI, continuidade do negócio, redução de riscos            |
| **Gerente de Projeto**   | Néctar      | Coordena execução, reporta progresso, gerencia riscos     | Entregas no prazo, qualidade, satisfação do cliente        |
| **Product Owner (PO)**   | Cooperflora | Define prioridades, aceita entregas, representa o negócio | Valor entregue, aderência às necessidades operacionais     |
| **Arquiteto de Solução** | Néctar      | Define padrões técnicos, valida decisões de arquitetura   | Qualidade técnica, aderência aos princípios arquiteturais  |
| **Dev Team**             | Néctar      | Implementa, testa, documenta e entrega os componentes     | Viabilidade técnica, qualidade de código, sustentabilidade |
| **TI Cooperflora**       | Cooperflora | Infraestrutura, acessos, integrações do lado cliente      | Segurança, conformidade, impacto mínimo em outros sistemas |
| **Áreas de Negócio**     | Cooperflora | Cadastro, Comercial, Fiscal/Financeiro — usuários finais  | Continuidade operacional, usabilidade, correção funcional  |

#### 📋 Matriz RACI por Entregável

A matriz abaixo define as responsabilidades para cada entregável do projeto, utilizando a notação RACI:

|  Código  | Papel           | Descrição                                                 |
| :------: | --------------- | --------------------------------------------------------- |
| **🔴 R** | **Responsible** | Executa a tarefa — quem "põe a mão na massa"              |
| **🟢 A** | **Accountable** | Aprova e responde pelo resultado — apenas **1 por linha** |
| **🟡 C** | **Consulted**   | Consultado antes da execução — comunicação bidirecional   |
| **🔵 I** | **Informed**    | Informado após conclusão — comunicação unidirecional      |

> **Convenção visual**: Células destacadas indicam o papel dominante. Cada linha possui exatamente **um Accountable (A)**.

| Entregável / Decisão                 | 👔 Sponsor |  📊 GP   |  🎯 PO   |  🏗️ Arq  |  💻 Dev  | 🖥️ TI Coop |
| ------------------------------------ | :--------: | :------: | :------: | :------: | :------: | :--------: |
| Aprovação de escopo e baseline       |  🟢 **A**  | 🔴 **R** |   🟡 C   |   🟡 C   |   🔵 I   |    🟡 C    |
| Validação de EMVs (2 dias úteis)     |    🔵 I    | 🔴 **R** | 🟢 **A** |   🟡 C   |   🔵 I   |    🟡 C    |
| Definição de contratos OpenAPI       |    🔵 I    |   🟡 C   | 🟢 **A** | 🔴 **R** |   🟡 C   |    🟡 C    |
| Implementação de fluxos              |    🔵 I    |   🟡 C   | 🟢 **A** |   🟡 C   | 🔴 **R** |    🔵 I    |
| Decisões de arquitetura              |    🔵 I    |   🟡 C   |   🟡 C   | 🟢 **A** | 🔴 **R** |    🔵 I    |
| Aprovação de go-live por fluxo       |  🟢 **A**  | 🔴 **R** |   🟡 C   |   🟡 C   |   🟡 C   |    🟡 C    |
| Gestão de mudanças (change requests) |  🟢 **A**  | 🔴 **R** |   🟡 C   |   🟡 C   |   🔵 I   |    🟡 C    |
| Monitoramento e alertas              |    🔵 I    |   🔵 I   |   🔵 I   |   🟡 C   | 🔴 **R** |  🟢 **A**  |
| Rollback e gestão de incidentes      |    🔵 I    |   🟡 C   | 🟢 **A** |   🟡 C   | 🔴 **R** |    🟡 C    |

**Resumo de responsabilidades por papel:**

| Papel                 | Total R | Total A | Foco Principal                                      |
| --------------------- | :-----: | :-----: | --------------------------------------------------- |
| 👔 Sponsor            |    0    |    3    | Aprovações estratégicas (escopo, go-live, mudanças) |
| 📊 Gerente de Projeto |    5    |    0    | Execução e coordenação operacional                  |
| 🎯 Product Owner      |    0    |    4    | Aprovação de entregas e decisões de negócio         |
| 🏗️ Arquiteto          |    1    |    1    | Padrões técnicos e contratos                        |
| 💻 Dev Team           |    3    |    0    | Implementação técnica                               |
| 🖥️ TI Cooperflora     |    0    |    1    | Infraestrutura e monitoramento                      |

### 🏛️ Estrutura de Governança e Fóruns de Decisão

A governança do projeto é organizada em três níveis, cada um com responsabilidades, participantes e frequência definidos.

#### 🏛️ Nível Estratégico: Comitê Executivo (Steering Committee)

| Aspecto           | Definição                                                                                              |
| ----------------- | ------------------------------------------------------------------------------------------------------ |
| **Objetivo**      | Decisões estratégicas, aprovação de mudanças de escopo/prazo/custo, resolução de impedimentos críticos |
| **Participantes** | Sponsor Executivo, Gerente de Projeto, PO, Arquiteto (quando necessário)                               |
| **Frequência**    | Mensal ou sob demanda para decisões urgentes                                                           |
| **Artefatos**     | Ata de reunião, registro de decisões, atualização de riscos estratégicos                               |

#### ⚙️ Nível Tático: Comitê de Projeto

| Aspecto           | Definição                                                                                        |
| ----------------- | ------------------------------------------------------------------------------------------------ |
| **Objetivo**      | Acompanhamento de progresso, gestão de riscos, priorização de backlog, coordenação entre equipes |
| **Participantes** | Gerente de Projeto, PO, Arquiteto, Dev Sênior                                                    |
| **Frequência**    | Semanal                                                                                          |
| **Artefatos**     | Status report, burndown/burnup, registro de riscos e issues, backlog atualizado                  |

#### 🎹 Nível Operacional: Cerimônias Ágeis

| Cerimônia           | Objetivo                                            | Participantes              | Frequência       |
| ------------------- | --------------------------------------------------- | -------------------------- | ---------------- |
| **Daily Standup**   | Sincronização da equipe, identificação de bloqueios | Dev Team                   | Diária (15 min)  |
| **Sprint Planning** | Planejamento da iteração, compromisso de entrega    | PO, Dev Team, Arquiteto    | Início de sprint |
| **Sprint Review**   | Demonstração de entregas, feedback do PO            | PO, Dev Team, Stakeholders | Fim de sprint    |
| **Retrospectiva**   | Melhoria contínua do processo                       | Dev Team, Arquiteto        | Fim de sprint    |

### 🔄 Gestão de Mudanças (Change Control)

Todo projeto está sujeito a mudanças. O processo de controle de mudanças garante que alterações sejam avaliadas, aprovadas e implementadas de forma controlada, sem comprometer a baseline do projeto.

#### 📝 Processo de Change Request

```mermaid
---
title: Processo de Change Request (Controle de Mudanças)
---
flowchart LR
    %% ===== DEFINIÇÕES DE ESTILO =====
    classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
    classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
    classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
    classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
    classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
    classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
    classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
    classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

    %% ===== SUBGRAPH: SOLICITAÇÃO =====
    subgraph solicitacao ["📥 Solicitação"]
        direction LR
        A["📝 Solicitação<br>de Mudança"]
        B["📊 Análise<br>de Impacto"]
        A -->|"submete"| B
    end
    style solicitacao fill:#EEF2FF,stroke:#4F46E5,stroke-width:2px

    %% ===== SUBGRAPH: TRIAGEM =====
    subgraph triagem ["🔀 Triagem"]
        direction LR
        C{"🔍 Impacto<br>Significativo?"}
        D["👥 Comitê<br>Executivo"]
        E["👤 Gerente<br>de Projeto"]
        C -->|"Sim"| D
        C -->|"Não"| E
    end
    style triagem fill:#FEF9C3,stroke:#D97706,stroke-width:2px

    %% ===== SUBGRAPH: DECISÃO =====
    subgraph decisao ["⚖️ Decisão"]
        direction LR
        F{"✅ Aprovado?"}
        H["❌ Registrar<br>Decisão"]
        F -->|"Não"| H
    end
    style decisao fill:#FFFBEB,stroke:#F59E0B,stroke-width:2px

    %% ===== SUBGRAPH: EXECUÇÃO =====
    subgraph execucao ["🚀 Execução"]
        direction LR
        G["📋 Atualizar<br>Baseline"]
        I["🚀 Implementar"]
        G -->|"inicia"| I
    end
    style execucao fill:#ECFDF5,stroke:#10B981,stroke-width:2px

    %% ===== CONEXÕES ENTRE FASES =====
    solicitacao -->|"analisa"| triagem
    D -->|"decide"| F
    E -->|"decide"| F
    F -->|"Sim"| execucao

    %% ===== APLICAÇÃO DE ESTILOS =====
    class A,B,G,I input
    class C,F decision
    class D,E secondary
    class H failed
```

| Etapa                   | Responsável                    | Prazo Alvo                | Artefato                                        |
| ----------------------- | ------------------------------ | ------------------------- | ----------------------------------------------- |
| Registro da solicitação | Qualquer stakeholder           | Imediato                  | Formulário de Change Request                    |
| Análise de impacto      | Gerente de Projeto + Arquiteto | 2-5 dias úteis            | Documento de impacto (escopo/prazo/custo/risco) |
| Decisão                 | Comitê apropriado              | Próxima reunião ou ad-hoc | Ata com decisão documentada                     |
| Atualização de baseline | Gerente de Projeto             | 2 dias úteis              | Plano de projeto atualizado                     |
| Comunicação             | Gerente de Projeto             | Imediato                  | Comunicado aos stakeholders afetados            |

#### 🚨 Critérios para Escalação ao Comitê Executivo

- Impacto em prazo superior a **2 semanas**
- Impacto em custo superior a **10% do orçamento** da fase
- Mudança em **princípios arquiteturais** ou decisões estratégicas
- Adição de **novos fluxos** não previstos no escopo original
- Conflitos entre stakeholders que não podem ser resolvidos no nível tático

### 📣 Plano de Comunicação

A comunicação eficaz é crítica para o sucesso do projeto. O plano abaixo define os canais, frequência e responsáveis por cada tipo de comunicação.

| Comunicação                           | Público-Alvo                 | Canal               | Frequência        | Responsável        |
| ------------------------------------- | ---------------------------- | ------------------- | ----------------- | ------------------ |
| **Status Report Executivo**           | Sponsor, Gestão Cooperflora  | E-mail + Reunião    | Mensal            | Gerente de Projeto |
| **Status Report Semanal**             | Comitê de Projeto            | E-mail + Teams/Meet | Semanal           | Gerente de Projeto |
| **Comunicado de Release**             | Todos os stakeholders        | E-mail              | Por release       | Gerente de Projeto |
| **Entrega de EMV (aprovação tácita)** | PO, TI Cooperflora           | E-mail formal       | Por EMV           | Gerente de Projeto |
| **Alerta de Risco/Issue Crítico**     | Sponsor, PO, Gerente         | E-mail + Telefone   | Imediato (ad-hoc) | Gerente de Projeto |
| **Documentação Técnica**              | Dev Team, Arquitetura, TI    | Wiki/Repositório    | Contínuo          | Tech Lead          |
| **Ata de Reunião**                    | Participantes da reunião     | E-mail              | Após cada reunião | Organizador        |
| **Relatório de Incidentes**           | PO, Operação, TI Cooperflora | E-mail + Ticket     | Por incidente     | Operação           |

### 📋 Premissas e Restrições do Projeto

#### ✅ Premissas

As premissas são condições assumidas como verdadeiras para fins de planejamento. Se alguma premissa se mostrar falsa, deve ser tratada como **risco materializado** e seguir o processo de gestão de riscos. As premissas estão organizadas por **fase do ciclo de vida** do projeto e **responsável**, com destaque para impactos financeiros quando aplicável.

> **🎯 Legenda de Severidade** (Probabilidade de Falha × Impacto no Projeto)
>
> |   Severidade   | Descrição                                                          | Ação Requerida                                                     |
> | :------------: | ------------------------------------------------------------------ | ------------------------------------------------------------------ |
> | 🔴 **Crítico** | Alta probabilidade de falha com impacto severo no cronograma/custo | Monitoramento semanal no Comitê; plano de contingência obrigatório |
> |  🟠 **Alto**   | Probabilidade média-alta com impacto significativo                 | Acompanhamento quinzenal; mitigação documentada                    |
> |  🟡 **Médio**  | Probabilidade média com impacto moderado                           | Monitoramento mensal; tratamento quando materializado              |
> |  🟢 **Baixo**  | Baixa probabilidade ou impacto controlável                         | Revisão periódica; sem ação imediata necessária                    |

##### Fase 0 – Alinhamento e Contenção de Riscos

|  ID | Premissa                                                                                        | Responsável          | Impacto se Falsa                                      |   Severidade   | Impacto em Investimentos (Cooperflora)                                                                              |
| --: | ----------------------------------------------------------------------------------------------- | -------------------- | ----------------------------------------------------- | :------------: | ------------------------------------------------------------------------------------------------------------------- |
| P01 | Cooperflora designará interlocutores técnicos e de negócio com autonomia para tomada de decisão | Cooperflora          | Atraso em validações e aprovações; bloqueio de Fase 0 | 🔴 **Crítico** | **Ociosidade da equipe Néctar**: custo de espera estimado em X h/dia por profissional alocado aguardando definições |
| P02 | Cooperflora proverá acesso ao ambiente de produção/homologação para mapeamento do legado        | Cooperflora          | Inventário técnico incompleto; riscos não mapeados    |  🟠 **Alto**   | **Retrabalho**: custo adicional de 20-40% nas fases seguintes por descobertas tardias                               |
| P03 | O legado (Access/VBA) permanecerá estável durante a fase de mapeamento                          | Néctar + Cooperflora | Retrabalho em mapeamento; documentação desatualizada  |  🟡 **Médio**  | —                                                                                                                   |
| P04 | Documentação existente do legado será disponibilizada (se houver)                               | Cooperflora          | Maior esforço de engenharia reversa                   |  🟡 **Médio**  | **Horas adicionais de análise**: 30-50% a mais de esforço na Fase 0                                                 |

##### Fase 1 – Definição dos Contratos de Integração

|  ID | Premissa                                                                             | Responsável | Impacto se Falsa                                         |   Severidade   | Impacto em Investimentos (Cooperflora)                                                                   |
| --: | ------------------------------------------------------------------------------------ | ----------- | -------------------------------------------------------- | :------------: | -------------------------------------------------------------------------------------------------------- |
| P05 | Cooperflora participará ativamente dos workshops de definição de contratos           | Cooperflora | Contratos mal definidos; retrabalho em fases posteriores |  🟠 **Alto**   | **Reagendamento de workshops**: custo de mobilização de equipe técnica Néctar (especialistas/arquitetos) |
| P06 | Requisitos de negócio para cada fluxo serão validados pelo PO dentro de 5 dias úteis | Cooperflora | Atraso na aprovação de contratos OpenAPI                 | 🔴 **Crítico** | **Ociosidade**: equipe técnica aguardando validação; custo de alocação sem produtividade                 |
| P07 | Requisitos de segurança e autenticação serão definidos pela TI Cooperflora           | Cooperflora | Bloqueio na definição de padrões de API                  |  🟠 **Alto**   | **Atraso cascateado**: impacto em Fase 2 e 3                                                             |

##### Fase 2 – Fundação da API

|  ID | Premissa                                                                                         | Responsável          | Impacto se Falsa                         |   Severidade   | Impacto em Investimentos (Cooperflora)                                              |
| --: | ------------------------------------------------------------------------------------------------ | -------------------- | ---------------------------------------- | :------------: | ----------------------------------------------------------------------------------- |
| P08 | Acessos e credenciais para ambientes DEV/HML serão providos em até 5 dias úteis após solicitação | Cooperflora          | Bloqueio de desenvolvimento e testes     | 🔴 **Crítico** | **Ociosidade de desenvolvedores**: custo diário da equipe de desenvolvimento parada |
| P09 | Infraestrutura de rede/firewall será configurada para comunicação API ↔ ERP                      | Cooperflora          | Impossibilidade de validar conectividade |  🟠 **Alto**   | **Atraso em smoke tests**: reprogramação de atividades e possível extensão de fase  |
| P10 | Não haverá mudanças estruturais no ERP Néctar durante a fundação                                 | Néctar               | Impacto em conectividade e contratos     |  🟡 **Médio**  | —                                                                                   |
| P11 | Ambiente de HML representará adequadamente o ambiente de produção                                | Néctar + Cooperflora | Defeitos descobertos apenas em PRD       |  🟠 **Alto**   | —                                                                                   |

##### Fase 3 – Fluxo Piloto

|  ID | Premissa                                                                                     | Responsável | Impacto se Falsa                           |   Severidade   | Impacto em Investimentos (Cooperflora)                                                        |
| --: | -------------------------------------------------------------------------------------------- | ----------- | ------------------------------------------ | :------------: | --------------------------------------------------------------------------------------------- |
| P12 | Cooperflora disponibilizará recursos para homologação nas janelas definidas (mín. 4h/semana) | Cooperflora | Atraso em validação e go-live do piloto    | 🔴 **Crítico** | **Extensão de fase**: custo de equipe Néctar alocada além do previsto; possível remobilização |
| P13 | Dados de teste representativos serão fornecidos ou autorizados para uso                      | Cooperflora | Testes não representam cenários reais      |  🟠 **Alto**   | **Retrabalho pós-produção**: correções emergenciais com custo premium                         |
| P14 | Usuários-chave estarão disponíveis para validação funcional                                  | Cooperflora | Homologação incompleta; riscos em produção |  🟠 **Alto**   | **Atraso de go-live**: custo de sustentação do piloto em HML por período estendido            |
| P15 | Critérios de aceite serão definidos e aprovados antes do início da homologação               | Cooperflora | Divergências sobre conclusão da fase       |  🟡 **Médio**  | —                                                                                             |

##### Fase 4 – Migração por Fluxo / Operação Híbrida

|  ID | Premissa                                                                    | Responsável | Impacto se Falsa                                    |   Severidade   | Impacto em Investimentos (Cooperflora)                                                     |
| --: | --------------------------------------------------------------------------- | ----------- | --------------------------------------------------- | :------------: | ------------------------------------------------------------------------------------------ |
| P16 | Janelas de homologação serão respeitadas conforme calendário acordado       | Cooperflora | Atraso em ondas de migração                         | 🔴 **Crítico** | **Extensão de projeto**: custo mensal adicional de equipe alocada; renegociação contratual |
| P17 | Comunicação de mudanças será feita aos usuários finais pela Cooperflora     | Cooperflora | Resistência à mudança; incidentes por uso incorreto |  🟡 **Médio**  | —                                                                                          |
| P18 | O legado permanecerá estável (sem novas funcionalidades de integração)      | Cooperflora | Divergência entre legado e API; retrabalho          |  🟠 **Alto**   | **Retrabalho de mapeamento**: custo de análise e ajuste de contratos já definidos          |
| P19 | Incidentes em produção terão resposta da operação Cooperflora dentro do SLA | Cooperflora | Aumento de MTTR; impacto em estabilização           |  🟠 **Alto**   | —                                                                                          |

##### Fase 5 – Simplificação do Legado

|  ID | Premissa                                                                       | Responsável | Impacto se Falsa                                     |  Severidade  | Impacto em Investimentos (Cooperflora)                                  |
| --: | ------------------------------------------------------------------------------ | ----------- | ---------------------------------------------------- | :----------: | ----------------------------------------------------------------------- |
| P20 | Cooperflora autorizará a remoção de rotinas de integração obsoletas            | Cooperflora | Legado não simplificado; custo de manutenção mantido | 🟡 **Médio** | —                                                                       |
| P21 | Conhecimento do legado será transferido para documentação antes da remoção     | Néctar      | Perda de conhecimento institucional                  | 🟡 **Médio** | —                                                                       |
| P22 | Treinamento de suporte será realizado com participação da operação Cooperflora | Cooperflora | Operação não preparada para novo modelo              | 🟠 **Alto**  | **Incidentes evitáveis**: custo de suporte reativo ao invés de proativo |

##### Fase 6 – Evolução Opcional

|  ID | Premissa                                                                        | Responsável | Impacto se Falsa                    |  Severidade  | Impacto em Investimentos (Cooperflora) |
| --: | ------------------------------------------------------------------------------- | ----------- | ----------------------------------- | :----------: | -------------------------------------- |
| P23 | Iniciativas de evolução serão aprovadas com justificativa de ROI                | Cooperflora | Investimento sem retorno mensurável | 🟡 **Médio** | —                                      |
| P24 | Decisões estratégicas (ex.: migração Nimbus) serão comunicadas com antecedência | Cooperflora | Falta de preparação arquitetural    | 🟡 **Médio** | —                                      |

##### Premissas Transversais (Aplicáveis a Todas as Fases)

|  ID | Premissa                                                               | Responsável          | Impacto se Falsa                                      |   Severidade   | Impacto em Investimentos (Cooperflora)                                        |
| --: | ---------------------------------------------------------------------- | -------------------- | ----------------------------------------------------- | :------------: | ----------------------------------------------------------------------------- |
| P25 | O escopo aprovado será respeitado, com mudanças via controle formal    | Néctar + Cooperflora | Scope creep, atraso e estouro de orçamento            | 🔴 **Crítico** | **Renegociação contratual**: custos adicionais para mudanças de escopo        |
| P26 | Reuniões de governança terão quórum mínimo para tomada de decisão      | Néctar + Cooperflora | Decisões postergadas; atrasos em aprovações           |  🟠 **Alto**   | —                                                                             |
| P27 | Comunicação entre equipes seguirá canais e SLAs definidos              | Néctar + Cooperflora | Falhas de comunicação; retrabalho                     |  🟡 **Médio**  | —                                                                             |
| P28 | EMVs serão validados em **2 dias úteis**; após prazo, aprovação tácita | Cooperflora          | Aprovação automática; ajustes viram mudança de escopo | 🔴 **Crítico** | **Investimentos adicionais**: solicitações pós-aprovação impactam prazo/custo |

> **⚠️ Impacto Financeiro para Premissas Não Cumpridas pela Cooperflora**
>
> O não cumprimento de premissas sob responsabilidade da Cooperflora pode gerar os seguintes impactos financeiros:
>
> | Tipo de Impacto               | Descrição                                                         | Estimativa de Custo                                           |
> | ----------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------- |
> | **Ociosidade de equipe**      | Profissionais Néctar alocados aguardando insumos/aprovações       | Custo/hora × horas de espera × número de profissionais        |
> | **Extensão de fase**          | Fases estendidas além do planejado por atrasos do cliente         | Custo mensal da equipe × meses adicionais                     |
> | **Retrabalho**                | Refazer atividades por mudanças tardias ou informações incorretas | 20-50% do esforço original da atividade                       |
> | **Remobilização**             | Desmobilizar e remobilizar equipe por pausas não planejadas       | Custo de transição + perda de contexto (estimado 1-2 semanas) |
> | **Suporte emergencial**       | Correções urgentes fora do horário comercial                      | Custo premium (1,5x a 2x do valor hora normal)                |
> | **Ajustes pós-aprovação EMV** | Solicitações após prazo de 2 dias ou aprovação tácita             | Tratado como mudança de escopo (custo + prazo adicional)      |
>
> **📊 Distribuição de Severidade (P01–P28)**: 🔴 6 Críticas (21%) | 🟠 8 Altas (29%) | 🟡 14 Médias (50%)
>
> **⚠️ Premissas Críticas (🔴)**: P01, P06, P08, P12, P16, P25 e P28 — requerem acompanhamento **semanal** no Comitê de Projeto.

#### ⛔ Restrições

As restrições são limitações conhecidas que moldam as decisões do projeto. Diferente das premissas, restrições são fatos aceitos que não podem ser alterados.

|  ID | Restrição                                                              | Origem                 | Implicação                                                        | Fase(s) Afetada(s) |
| --: | ---------------------------------------------------------------------- | ---------------------- | ----------------------------------------------------------------- | ------------------ |
|  R1 | A operação não pode ser interrompida durante a migração                | Cooperflora (Negócio)  | Obriga operação híbrida e rollback por fluxo                      | Fases 3, 4, 5      |
|  R2 | O sistema legado (Access) não será descontinuado até migração completa | Cooperflora (Negócio)  | Necessário manter convivência e sincronização                     | Fases 3, 4, 5      |
|  R3 | Orçamento e equipe são fixos para o escopo definido                    | Néctar + Cooperflora   | Mudanças de escopo exigem trade-off ou aprovação adicional        | Todas              |
|  R4 | Janelas de homologação limitadas à disponibilidade da Cooperflora      | Cooperflora (Operação) | Cronograma deve prever buffers para disponibilidade               | Fases 3, 4         |
|  R5 | Não devem ser criadas novas regras de negócio complexas em VBA         | Néctar (Arquitetura)   | Novas lógicas devem ser implementadas na API ou stored procedures | Fases 2, 3, 4      |
|  R6 | Acesso ao banco do ERP será restrito/eliminado após migração           | Néctar (Arquitetura)   | API deve ser autossuficiente para todas as integrações            | Fases 2, 3, 4, 5   |
|  R7 | Políticas de segurança da Cooperflora devem ser respeitadas            | Cooperflora (TI)       | Autenticação e hardening conforme padrões do cliente              | Fases 1, 2         |

### 🏆 Critérios de Sucesso do Projeto

Os critérios abaixo definem como o sucesso do projeto será medido ao final de cada fase e ao término do projeto.

| Critério                             | Meta                                             | Medição                                      |
| ------------------------------------ | ------------------------------------------------ | -------------------------------------------- |
| **Fluxos migrados para API**         | 100% dos fluxos críticos em escopo               | Contagem de fluxos em estado "API" vs total  |
| **Disponibilidade da integração**    | ≥ 99,5% no horário comercial                     | Monitoramento de uptime                      |
| **Taxa de erro em produção**         | < 1% por fluxo após estabilização                | Métricas de erro por endpoint                |
| **Tempo de resposta (p95)**          | < 2 segundos para operações síncronas            | APM / métricas de latência                   |
| **Incidentes críticos pós-migração** | Zero incidentes P1 causados pela nova integração | Registro de incidentes                       |
| **Satisfação do cliente (PO)**       | Aceite formal de todas as entregas               | Termo de aceite por fase                     |
| **EMVs aprovados no prazo**          | ≥ 80% dos EMVs validados em 2 dias úteis         | Contagem de aprovações vs aprovações tácitas |
| **Aderência ao cronograma**          | Desvio máximo de 15% em relação ao baseline      | Comparativo planejado vs realizado           |
| **Aderência ao orçamento**           | Desvio máximo de 10% em relação ao baseline      | Comparativo planejado vs realizado           |

## ⚠️ Riscos (RAID) e Mitigações

O gerenciamento de riscos é contínuo ao longo do projeto. Esta seção apresenta o registro inicial de **Riscos, Ações, Issues e Decisões (RAID)**, que será atualizado nas reuniões semanais do Comitê de Projeto. Cada risco é classificado por probabilidade e impacto, com responsável e plano de mitigação definidos.

A matriz de riscos segue a escala: **Probabilidade** (Baixa/Média/Alta) × **Impacto** (Baixo/Médio/Alto/Crítico), gerando uma classificação de severidade que orienta a priorização das ações de mitigação.

> **🎯 Legenda de Severidade** (Probabilidade × Impacto)
>
> |   Severidade   | Descrição                                        | Ação Requerida                                           |
> | :------------: | ------------------------------------------------ | -------------------------------------------------------- |
> | 🔴 **Crítico** | Alta probabilidade × Impacto alto/crítico        | Monitoramento semanal; plano de contingência obrigatório |
> |  🟠 **Alto**   | Probabilidade média-alta × Impacto significativo | Acompanhamento quinzenal; mitigação ativa                |
> |  🟡 **Médio**  | Probabilidade média × Impacto moderado           | Monitoramento mensal; tratamento quando materializado    |
> |  🟢 **Baixo**  | Baixa probabilidade ou impacto controlável       | Revisão periódica; sem ação imediata                     |

### 📝 Registro de Riscos

|  ID | Risco                                                         | Probabilidade | Impacto |   Severidade   | Mitigação                                                                            | Responsável        | Status |
| --: | ------------------------------------------------------------- | :-----------: | :-----: | :------------: | ------------------------------------------------------------------------------------ | ------------------ | :----: |
| R01 | Dependências ocultas no legado (VBA/SQL) não documentadas     |     Alta      |  Alto   | 🔴 **Crítico** | Inventário e engenharia reversa na Fase 0; validação com operação                    | Arquiteto          | Aberto |
| R02 | Inconsistência de dados durante operação híbrida              |     Média     |  Alto   |  🟠 **Alto**   | Definir source of truth por domínio; idempotência obrigatória; auditoria comparativa | Tech Lead          | Aberto |
| R03 | Atrasos em homologação por indisponibilidade do negócio       |     Alta      |  Médio  |  🟠 **Alto**   | Cronograma com buffers; janelas pré-acordadas; escalação ao Sponsor se necessário    | Gerente de Projeto | Aberto |
| R04 | Scope creep e priorização instável                            |     Média     |  Alto   |  🟠 **Alto**   | Baseline de escopo; processo de change control; governança formal                    | Gerente de Projeto | Aberto |
| R05 | Comportamento do legado diverge do esperado em produção       |     Média     |  Alto   |  🟠 **Alto**   | Testes E2E extensivos; piloto com monitoramento intensivo; rollback preparado        | Tech Lead          | Aberto |
| R06 | Indisponibilidade de ambiente ou acessos                      |     Média     |  Médio  |  🟡 **Médio**  | Solicitar acessos antecipadamente; ambientes de DEV/HML independentes                | TI Cooperflora     | Aberto |
| R07 | Falhas de comunicação entre equipes                           |     Baixa     |  Médio  |  🟢 **Baixo**  | Plano de comunicação; cerimônias regulares; canais definidos                         | Gerente de Projeto | Aberto |
| R08 | Resistência à mudança por parte dos usuários                  |     Média     |  Médio  |  🟡 **Médio**  | Envolvimento do PO; demonstrações frequentes; treinamento antes do go-live           | PO                 | Aberto |
| R09 | Performance da API inferior ao legado em cenários específicos |     Baixa     |  Alto   |  🟡 **Médio**  | Testes de carga; otimização; cache quando aplicável; métricas de baseline            | Arquiteto          | Aberto |
| R10 | Mudanças no ERP Néctar durante o projeto                      |     Baixa     | Crítico |  🟠 **Alto**   | Comunicação prévia obrigatória; versionamento de contratos; testes de regressão      | Arquiteto          | Aberto |

> **📊 Distribuição de Severidade (R01–R10)**: 🔴 1 Crítico (10%) | 🟠 5 Altos (50%) | 🟡 3 Médios (30%) | 🟢 1 Baixo (10%)

### 🎯 Matriz de Severidade

A matriz abaixo ilustra como a combinação de **Probabilidade** (eixo vertical) e **Impacto** (eixo horizontal) determina a **Severidade** de cada risco ou premissa. Esta classificação é utilizada consistentemente em todo o documento para priorizar ações de mitigação e monitoramento.

```mermaid
---
title: Matriz de Severidade (Probabilidade x Impacto)
---
block-beta
  %% ===== DEFINIÇÕES DE ESTILO =====
  classDef primary fill:#4F46E5,stroke:#3730A3,color:#FFFFFF
  classDef secondary fill:#10B981,stroke:#059669,color:#FFFFFF
  classDef datastore fill:#F59E0B,stroke:#D97706,color:#000000
  classDef external fill:#6B7280,stroke:#4B5563,color:#FFFFFF,stroke-dasharray: 5 5
  classDef failed fill:#F44336,stroke:#C62828,color:#FFFFFF
  classDef trigger fill:#818CF8,stroke:#4F46E5,color:#FFFFFF
  classDef decision fill:#FFFBEB,stroke:#F59E0B,color:#000000
  classDef input fill:#F3F4F6,stroke:#6B7280,color:#000000

  columns 5

  %% ===== CABEÇALHO =====
  EIXOS["Prob. / Imp."]:1 B["Baixo"]:1 M["Médio"]:1 A["Alto"]:1 C["Crítico"]:1

  %% ===== LINHA PROBABILIDADE ALTA =====
  PA["Alta"]:1 PA_B["🟡 Médio"]:1 PA_M["🟠 Alto"]:1 PA_A["🔴 Crítico"]:1 PA_C["🔴 Crítico"]:1

  %% ===== LINHA PROBABILIDADE MÉDIA =====
  PM["Média"]:1 PM_B["🟢 Baixo"]:1 PM_M["🟡 Médio"]:1 PM_A["🟠 Alto"]:1 PM_C["🔴 Crítico"]:1

  %% ===== LINHA PROBABILIDADE BAIXA =====
  PB["Baixa"]:1 PB_B["🟢 Baixo"]:1 PB_M["🟢 Baixo"]:1 PB_A["🟡 Médio"]:1 PB_C["🟠 Alto"]:1

  %% ===== APLICAÇÃO DE ESTILOS =====
  class B,M,A,C,PA,PM,PB primary
  class EIXOS trigger
  class PM_B,PB_B,PB_M secondary
  class PA_B,PM_M,PB_A datastore
  class PA_M,PM_A,PB_C datastore
  class PA_A,PA_C,PM_C failed
```

> **📋 Resumo Visual de Severidade**
>
> | Severidade  | Emoji |    Cor    | Probabilidade × Impacto                       | Ação Requerida                                           |
> | :---------: | :---: | :-------: | :-------------------------------------------- | :------------------------------------------------------- |
> | **Crítico** |  🔴   | `#EF4444` | Alta × Alto/Crítico ou Média × Crítico        | Monitoramento semanal; plano de contingência obrigatório |
> |  **Alto**   |  🟠   | `#F97316` | Alta × Médio, Média × Alto ou Baixa × Crítico | Acompanhamento quinzenal; mitigação ativa                |
> |  **Médio**  |  🟡   | `#F59E0B` | Alta × Baixo, Média × Médio ou Baixa × Alto   | Monitoramento mensal; tratamento quando materializado    |
> |  **Baixo**  |  🟢   | `#10B981` | Média × Baixo ou Baixa × Baixo/Médio          | Revisão periódica; sem ação imediata                     |

### 🚨 Plano de Contingência para Riscos Críticos

| Risco | Gatilho de Ativação                               | Plano de Contingência                                                 |
| ----- | ------------------------------------------------- | --------------------------------------------------------------------- |
| R01   | Descoberta de dependência não mapeada em produção | Rollback imediato do fluxo; análise RCA; replanejar migração          |
| R02   | Divergência de dados detectada entre sistemas     | Pausar migração do fluxo; reconciliação manual; correção e re-teste   |
| R05   | Falha crítica em produção pós-migração            | Ativar rollback via feature flag; restaurar fluxo legado; análise RCA |
| R10   | Mudança no ERP quebra contrato existente          | Versionar contrato; manter versão anterior; migração gradual          |

### 📊 KPIs de Monitoramento do Projeto

Além dos critérios de sucesso, os seguintes KPIs serão monitorados continuamente para detecção precoce de problemas:

| KPI                               | Meta                       | Frequência de Medição | Responsável        |
| --------------------------------- | -------------------------- | --------------------- | ------------------ |
| Percentual de fluxos migrados     | Conforme roadmap por fase  | Semanal               | Gerente de Projeto |
| Taxa de erro por fluxo e ambiente | < 1% após estabilização    | Diária                | Operação           |
| Latência p95 por endpoint         | < 2s (síncrono)            | Contínua (APM)        | Operação           |
| Taxa de timeout                   | < 0,1%                     | Contínua              | Operação           |
| Incidentes por mês (P1/P2/P3)     | 0 P1, < 2 P2               | Mensal                | Operação           |
| MTTR (tempo médio de recuperação) | < 1h para P1, < 4h para P2 | Por incidente         | Operação           |
| Burndown/Burnup do sprint         | Tendência estável          | Semanal               | Tech Lead          |
| Desvio de cronograma              | < 15% do baseline          | Semanal               | Gerente de Projeto |
| EMVs com aprovação tácita         | < 20% do total de EMVs     | Por fase              | Gerente de Projeto |

## 🚀 Operação, Implantação e Suporte

### 🛸 Estratégia de implantação

| Aspecto               | Descrição                                                            |
| --------------------- | -------------------------------------------------------------------- |
| **Ambientes**         | DEV → HML → PRD (progressão controlada)                              |
| **CI/CD**             | Pipeline automatizado com build, testes e deploy                     |
| **Versionamento API** | Versão no path (`/v1`, `/v2`) com política de deprecação documentada |
| **Feature Flags**     | Roteamento por fluxo (Legado/Híbrido/API) com rollback configurável  |
| **Validação**         | Smoke tests e dashboards pós-deploy obrigatórios                     |

### ⚖️ Operação híbrida

| Elemento                  | Descrição                                                             |
| ------------------------- | --------------------------------------------------------------------- |
| Mapa de fluxos migrados   | Matriz atualizada indicando estado de cada fluxo (Legado/Híbrido/API) |
| Alertas separados         | Monitoramento distinto para API e legado durante convivência          |
| Procedimentos de rollback | Documentados por fluxo, com critérios de acionamento                  |
| Janela de estabilização   | 2 semanas por fluxo com monitoramento reforçado                       |

### 📖 Runbooks e suporte

- **Runbooks por fluxo**: o que monitorar, como reprocessar, quando escalar
- **Revisão pós-incidente (RCA)**: obrigatória para P1/P2, com ações documentadas
- **Melhoria contínua**: ajustes em runbooks e alertas conforme aprendizados
- **Matriz de escalação**: definida por severidade e horário (comercial vs. plantão)

### 🎓 Treinamento

| Público      | Conteúdo                                                   | Momento               |
| ------------ | ---------------------------------------------------------- | --------------------- |
| **Técnicos** | API, logs estruturados, suporte L2/L3                      | Antes do piloto       |
| **Operação** | Dashboards, runbooks, procedimentos de escalação           | Antes de cada go-live |
| **Negócio**  | Mudanças de comportamento, novos fluxos, pontos de atenção | Por onda de migração  |

## 🔮 Próximos Passos e Evolução Futura

### 🎯 Ações imediatas (Fase 0)

1. Validar com Cooperflora: **fluxo piloto**, matriz de propriedade de dados e restrições de rede/segurança.
2. Confirmar governança e calendário de homologação.
3. Iniciar Fase 0 com inventário técnico e backlog priorizado.
4. Realizar congelamento de tabelas e VBA relevantes para integração.

### ☁️ Migração futura ao Nimbus

- APIs já preparadas como contratos formais (OpenAPI versionado).
- Modelo de integração moderno e desacoplado.
- Planejamento de módulos candidatos à migração conforme roadmap estratégico.

### 📡 Arquitetura orientada a eventos (evolução opcional)

- Introdução de Service Bus quando justificado por picos de carga ou desacoplamento.
- Modelagem de eventos por domínio (ex.: `PedidoCriado`, `NotaFiscalEmitida`).
- Transformação de integrações síncronas em assíncronas quando houver ganho claro.

---

## 📊 Detalhamento da Estimativa de Horas

Esta seção apresenta a **fundamentação técnica** da estimativa de esforço para o projeto, elaborada pelos recursos da Néctar com base na experiência em projetos similares de modernização e integração. O detalhamento permite rastreabilidade completa entre atividades, horas estimadas e responsáveis.

### 🎯 Metodologia de Estimativa

A estimativa foi construída utilizando a técnica de **decomposição por atividades (WBS)**, combinada com **estimativas de três pontos** (otimista, mais provável, pessimista) para atividades de maior incerteza. O valor final considera o cenário **mais provável** para o planejamento base.

| Critério                   | Descrição                                               |
| :------------------------- | :------------------------------------------------------ |
| **Técnica**                | Work Breakdown Structure (WBS) + Estimativa Paramétrica |
| **Base de referência**     | Projetos anteriores de modernização de legado Néctar    |
| **Fator de complexidade**  | 1.2x (integração com VBA/Access + convivência híbrida)  |
| **Buffer de contingência** | 15–20% recomendado (não incluído na estimativa base)    |

---

### 📋 Fase 0 – Alinhamento e Contenção de Riscos (2 semanas)

**Objetivo:** Criar base de governança, mapear dependências e reduzir riscos imediatos.

| Atividade                                      |      Responsável       |    Horas | Justificativa                            |
| :--------------------------------------------- | :--------------------: | -------: | :--------------------------------------- |
| Kick-off e alinhamento com stakeholders        |        GP + Arq        |       8h | Reuniões iniciais + preparação           |
| Inventário técnico do módulo Access/VBA        | Dev Sênior + Dev Pleno |      24h | Análise de código legado (~3.000 LOC)    |
| Inventário de rotinas SINC                     |       Dev Sênior       |      16h | Mapeamento de jobs e dependências        |
| Mapeamento de pontos de integração             |    Arq + Dev Sênior    |      16h | Diagramas C4 + documentação              |
| Análise de tabelas compartilhadas (SQL Server) | Dev Sênior + Dev Pleno |      16h | Schema, triggers, constraints            |
| Matriz de propriedade de dados                 |        GP + Arq        |       8h | Definição de source of truth por domínio |
| Requisitos não funcionais e restrições         |          Arq           |       8h | SLAs, volumetria, janelas de manutenção  |
| Priorização de fluxos (backlog)                |           GP           |       8h | Critérios MoSCoW + riscos                |
| Documentação e revisão                         |           GP           |       8h | Consolidação de artefatos Fase 0         |
| **Subtotal Fase 0**                            |                        | **112h** |                                          |

**Distribuição por recurso (Fase 0):**

| Recurso              | Horas | % da Fase |
| :------------------- | ----: | --------: |
| Gerente de Projeto   |   24h |       21% |
| Arquiteto de Solução |   32h |       29% |
| Desenvolvedor Sênior |   40h |       36% |
| Desenvolvedor Pleno  |   16h |       14% |

---

### 📝 Fase 1 – Definição dos Contratos de Integração (2 semanas)

**Objetivo:** Transformar integrações implícitas em contratos explícitos e governáveis.

| Atividade                                       |      Responsável       |    Horas | Justificativa                          |
| :---------------------------------------------- | :--------------------: | -------: | :------------------------------------- |
| Workshop de levantamento de regras de negócio   |        GP + Arq        |      12h | 3 sessões de 4h com PO Cooperflora     |
| Modelagem de domínios e entidades               |    Arq + Dev Sênior    |      16h | DTOs, agregados, limites de contexto   |
| Definição de endpoints (fluxo piloto – Pessoas) |    Arq + Dev Sênior    |      12h | CRUD + operações específicas           |
| Especificação OpenAPI v1                        | Dev Sênior + Dev Pleno |      24h | Payloads, validações, exemplos         |
| Taxonomia de erros padronizada                  |          Arq           |       8h | Códigos, mensagens, campos de erro     |
| Política de versionamento                       |          Arq           |       4h | Estratégia /v1, /v2, breaking changes  |
| Definição de idempotência por operação          |    Arq + Dev Sênior    |       8h | Chaves naturais, deduplicação          |
| Requisitos de autenticação/autorização          |        Arq + GP        |       8h | OAuth2 / API Key – decisão com cliente |
| Validação e aprovação dos contratos             |           GP           |       8h | Apresentação + coleta de aceite        |
| Documentação e revisão                          |    GP + Dev Sênior     |      12h | Consolidação de artefatos Fase 1       |
| **Subtotal Fase 1**                             |                        | **112h** |                                        |

**Distribuição por recurso (Fase 1):**

| Recurso              | Horas | % da Fase |
| :------------------- | ----: | --------: |
| Gerente de Projeto   |   28h |       25% |
| Arquiteto de Solução |   40h |       36% |
| Desenvolvedor Sênior |   32h |       29% |
| Desenvolvedor Pleno  |   12h |       11% |

---

### 🏗️ Fase 2 – Fundação da API (3 semanas)

**Objetivo:** Disponibilizar infraestrutura e esqueleto técnico da API com padrões operacionais.

| Atividade                                     |      Responsável       |    Horas | Justificativa                              |
| :-------------------------------------------- | :--------------------: | -------: | :----------------------------------------- |
| Setup de solução .NET (estrutura de projetos) |       Dev Sênior       |       8h | Camadas, DI, organização de código         |
| Implementação de arquitetura base             |    Arq + Dev Sênior    |      24h | Middleware, validação, tratamento de erros |
| Logging estruturado + correlation-id          | Dev Sênior + Dev Pleno |      16h | Serilog/Seq + propagação de contexto       |
| Health checks e métricas                      |       Dev Sênior       |       8h | /health, /ready, métricas Prometheus       |
| Integração com ERP Néctar (conectividade)     | Dev Sênior + Dev Pleno |      24h | Componentes SDK, connection pooling        |
| Swagger/OpenAPI setup                         |       Dev Pleno        |       8h | Documentação auto-gerada                   |
| Pipeline CI/CD                                | Dev Sênior + Dev Pleno |      16h | Build, test, deploy automatizado           |
| Configuração de ambientes (DEV/HML)           |       Dev Sênior       |      12h | Variáveis, secrets, configurações          |
| Testes de conectividade e smoke tests         | Dev Sênior + Dev Pleno |      16h | Validação ponta a ponta                    |
| Code review e ajustes de arquitetura          |          Arq           |      12h | Revisão de padrões e boas práticas         |
| Documentação técnica da fundação              |       Dev Sênior       |       8h | ADRs, README, guias de contribuição        |
| Coordenação e acompanhamento                  |           GP           |      16h | Dailies, gestão de impedimentos            |
| **Subtotal Fase 2**                           |                        | **168h** |                                            |

**Distribuição por recurso (Fase 2):**

| Recurso              | Horas | % da Fase |
| :------------------- | ----: | --------: |
| Gerente de Projeto   |   16h |       10% |
| Arquiteto de Solução |   36h |       21% |
| Desenvolvedor Sênior |   68h |       40% |
| Desenvolvedor Pleno  |   48h |       29% |

---

### 🚀 Fase 3 – Fluxo Piloto (4 semanas)

**Objetivo:** Implementar o primeiro fluxo via API em produção, validando padrões e processos.

| Atividade                                    |      Responsável       |    Horas | Justificativa                          |
| :------------------------------------------- | :--------------------: | -------: | :------------------------------------- |
| Análise detalhada do fluxo Pessoas no legado | Dev Sênior + Dev Pleno |      24h | Mapeamento de regras, edge cases       |
| Implementação de endpoints (CRUD Pessoas)    | Dev Sênior + Dev Pleno |      48h | Controllers, services, repositories    |
| Validações de negócio                        |       Dev Sênior       |      16h | FluentValidation, regras complexas     |
| Idempotência e deduplicação                  |       Dev Sênior       |      12h | Mecanismo de chaves únicas             |
| Auditoria por transação                      |       Dev Pleno        |      12h | Log de operações, rastreabilidade      |
| Testes unitários                             |       Dev Pleno        |      24h | xUnit, cobertura ≥90%                  |
| Testes de integração                         | Dev Sênior + Dev Pleno |      20h | TestContainers, cenários E2E           |
| Implementação de feature flag                |       Dev Sênior       |       8h | Roteamento Legado/API                  |
| Ajustes no legado para convivência           | Dev Sênior + Dev Pleno |      16h | Adaptações mínimas no Access/VBA       |
| Homologação com usuários                     |    GP + Dev Sênior     |      16h | Sessões de validação                   |
| Runbook operacional                          |       Dev Sênior       |       8h | Procedimentos de operação              |
| Dashboards e alertas                         |       Dev Pleno        |      12h | Grafana/Application Insights           |
| Go-live piloto + estabilização               |    GP + Dev Sênior     |      16h | Acompanhamento das 2 primeiras semanas |
| Documentação de lições aprendidas            |           GP           |       8h | Retrospectiva e ajustes de processo    |
| **Subtotal Fase 3**                          |                        | **240h** |                                        |

**Distribuição por recurso (Fase 3):**

| Recurso              | Horas | % da Fase |
| :------------------- | ----: | --------: |
| Gerente de Projeto   |   40h |       17% |
| Arquiteto de Solução |   16h |        7% |
| Desenvolvedor Sênior |  112h |       47% |
| Desenvolvedor Pleno  |   72h |       30% |

---

### 🔄 Fase 4 – Migração por Fluxo (12 semanas)

**Objetivo:** Escalar a migração para os demais fluxos críticos, mantendo operação híbrida governada.

> **Nota:** A estimativa considera a migração de **5 fluxos adicionais** além do piloto, com complexidade variada. O esforço médio por fluxo é de ~120h, considerando reuso de padrões da Fase 3.

| Atividade                              |      Responsável       |    Horas | Justificativa                   |
| :------------------------------------- | :--------------------: | -------: | :------------------------------ |
| **Fluxo 2 – Produtos**                 |                        |          |                                 |
| › Análise e mapeamento                 |       Dev Sênior       |      16h | Catálogo, categorias, atributos |
| › Implementação                        | Dev Sênior + Dev Pleno |      56h | Endpoints + validações          |
| › Testes e homologação                 |     Dev Pleno + GP     |      32h | Unitários, integração, aceite   |
| **Fluxo 3 – Pedidos**                  |                        |          |                                 |
| › Análise e mapeamento                 |       Dev Sênior       |      20h | Fluxo complexo, estados, regras |
| › Implementação                        | Dev Sênior + Dev Pleno |      72h | Endpoints + validações + saga   |
| › Testes e homologação                 |     Dev Pleno + GP     |      40h | Cenários de negócio variados    |
| **Fluxo 4 – Faturamento**              |                        |          |                                 |
| › Análise e mapeamento                 |       Dev Sênior       |      16h | NF-e, integrações fiscais       |
| › Implementação                        | Dev Sênior + Dev Pleno |      56h | Endpoints + validações          |
| › Testes e homologação                 |     Dev Pleno + GP     |      32h | Cenários fiscais críticos       |
| **Fluxo 5 – Financeiro (Contas)**      |                        |          |                                 |
| › Análise e mapeamento                 |       Dev Sênior       |      16h | A pagar, a receber, conciliação |
| › Implementação                        | Dev Sênior + Dev Pleno |      56h | Endpoints + validações          |
| › Testes e homologação                 |     Dev Pleno + GP     |      32h | Integração contábil             |
| **Fluxo 6 – Estoque**                  |                        |          |                                 |
| › Análise e mapeamento                 |       Dev Sênior       |      12h | Movimentações, inventário       |
| › Implementação                        | Dev Sênior + Dev Pleno |      48h | Endpoints + validações          |
| › Testes e homologação                 |     Dev Pleno + GP     |      24h | Cenários de movimentação        |
| **Atividades transversais**            |                        |          |                                 |
| Gestão de feature flags (5 fluxos)     |       Dev Sênior       |      20h | Configuração por fluxo          |
| Monitoramento e ajustes de performance | Dev Sênior + Dev Pleno |      40h | Otimizações, índices, cache     |
| Coordenação e acompanhamento           |           GP           |      96h | Gestão contínua (~8h/sem)       |
| Revisões de arquitetura                |          Arq           |      48h | Validação de padrões (~4h/sem)  |
| Documentação contínua                  |       Dev Pleno        |      24h | Atualização de specs e runbooks |
| Checkpoints por onda (3 ondas)         |        GP + Arq        |      24h | Apresentações e aceites         |
| **Subtotal Fase 4**                    |                        | **780h** |                                 |

**Distribuição por recurso (Fase 4):**

| Recurso              | Horas | % da Fase |
| :------------------- | ----: | --------: |
| Gerente de Projeto   |  120h |       15% |
| Arquiteto de Solução |   72h |        9% |
| Desenvolvedor Sênior |  340h |       44% |
| Desenvolvedor Pleno  |  248h |       32% |

---

### 🧹 Fase 5 – Simplificação do Legado (5 semanas)

**Objetivo:** Descomissionar rotinas de integração legadas e consolidar documentação final.

| Atividade                         |      Responsável       |    Horas | Justificativa                     |
| :-------------------------------- | :--------------------: | -------: | :-------------------------------- |
| Inventário final de timers ativos |       Dev Sênior       |       8h | Validação do que foi migrado      |
| Desativação de timers (por fluxo) | Dev Sênior + Dev Pleno |      24h | 6 fluxos × 4h (com validação)     |
| Remoção de código VBA obsoleto    |       Dev Pleno        |      16h | Limpeza de rotinas não utilizadas |
| Ajustes em tabelas de staging     |       Dev Sênior       |      12h | Remoção de tabelas temporárias    |
| Validação de integridade de dados | Dev Sênior + Dev Pleno |      24h | Reconciliação final               |
| Monitoramento pós-desativação     |       Dev Sênior       |      16h | 2 semanas de observação           |
| Documentação de arquitetura final |    Arq + Dev Sênior    |      24h | Diagramas C4 atualizados          |
| Runbooks de operação consolidados |       Dev Sênior       |      12h | Procedimentos unificados          |
| Guia de troubleshooting           | Dev Sênior + Dev Pleno |      16h | FAQ técnico + scripts             |
| Handover para operação            |    GP + Dev Sênior     |      16h | Sessões de transferência          |
| Relatório de encerramento         |           GP           |      12h | Métricas, lições, recomendações   |
| Aceite final e encerramento       |           GP           |       8h | Apresentação executiva            |
| **Subtotal Fase 5**               |                        | **188h** |                                   |

**Distribuição por recurso (Fase 5):**

| Recurso              | Horas | % da Fase |
| :------------------- | ----: | --------: |
| Gerente de Projeto   |   36h |       19% |
| Arquiteto de Solução |   24h |       13% |
| Desenvolvedor Sênior |   80h |       43% |
| Desenvolvedor Pleno  |   48h |       26% |

---

### 📊 Consolidação da Estimativa de Horas

#### Por Fase

| Fase | Nome                    |  Duração   | Horas Estimadas | % do Total |
| ---: | :---------------------- | :--------: | --------------: | ---------: |
|    0 | Alinhamento e contenção |   2 sem    |            112h |         7% |
|    1 | Definição de contratos  |   2 sem    |            112h |         7% |
|    2 | Fundação da API         |   3 sem    |            168h |        11% |
|    3 | Fluxo piloto            |   4 sem    |            240h |        15% |
|    4 | Migração por fluxo      |   12 sem   |            780h |        49% |
|    5 | Simplificação do legado |   5 sem    |            188h |        12% |
|      | **TOTAL**               | **28 sem** |      **1.600h** |   **100%** |

#### Por Recurso (Total do Projeto)

| Recurso              |   Fase 0 |   Fase 1 |   Fase 2 |   Fase 3 |   Fase 4 |   Fase 5 |  **Total** |    **%** |
| :------------------- | -------: | -------: | -------: | -------: | -------: | -------: | ---------: | -------: |
| Gerente de Projeto   |      24h |      28h |      16h |      40h |     120h |      36h |   **264h** |      17% |
| Arquiteto de Solução |      32h |      40h |      36h |      16h |      72h |      24h |   **220h** |      14% |
| Desenvolvedor Sênior |      40h |      32h |      68h |     112h |     340h |      80h |   **672h** |      42% |
| Desenvolvedor Pleno  |      16h |      12h |      48h |      72h |     248h |      48h |   **444h** |      28% |
| **TOTAL**            | **112h** | **112h** | **168h** | **240h** | **780h** | **188h** | **1.600h** | **100%** |

```mermaid
---
title: Distribuição de Horas por Recurso
---
%%{init: { 'theme': 'base', 'themeVariables': {
    'pie1': '#10B981',
    'pie2': '#3B82F6',
    'pie3': '#4F46E5',
    'pie4': '#8B5CF6'
} } }%%
pie showData
    %% ===== DISTRIBUIÇÃO POR RECURSO =====
    "Gerente de Projeto (17%)" : 264
    "Arquiteto de Solução (14%)" : 220
    "Desenvolvedor Sênior (42%)" : 672
    "Desenvolvedor Pleno (28%)" : 444
```

```mermaid
---
title: Distribuição de Horas por Fase
---
%%{init: { 'theme': 'base', 'themeVariables': {
    'pie1': '#F0FDF4',
    'pie2': '#DCFCE7',
    'pie3': '#BBF7D0',
    'pie4': '#86EFAC',
    'pie5': '#4ADE80',
    'pie6': '#22C55E'
} } }%%
pie showData
    %% ===== DISTRIBUIÇÃO POR FASE =====
    "Fase 0 – Alinhamento (7%)" : 112
    "Fase 1 – Contratos (7%)" : 112
    "Fase 2 – Fundação (11%)" : 168
    "Fase 3 – Piloto (15%)" : 240
    "Fase 4 – Migração (49%)" : 780
    "Fase 5 – Simplificação (12%)" : 188
```

---

### 🔍 Premissas da Estimativa

| ID  | Premissa                                               | Impacto se Falsa                    |
| :-: | :----------------------------------------------------- | :---------------------------------- |
| E01 | Código legado VBA está acessível e documentável        | +20% em Fase 0                      |
| E02 | Schema do SQL Server está estabilizado (sem mudanças)  | Retrabalho em mapeamentos           |
| E03 | Cooperflora fornece SME para workshops em até 48h      | Atraso em Fase 1                    |
| E04 | Ambientes DEV/HML disponíveis até início da Fase 2     | Bloqueio de desenvolvimento         |
| E05 | Fluxos de migração são independentes (sem acoplamento) | +30% em Fase 4 se acoplados         |
| E06 | Não há mudanças funcionais durante a migração          | Escopo adicional via Change Control |

### ⚠️ Riscos que Podem Afetar a Estimativa

| Risco                                        | Probabilidade | Impacto (Horas) | Mitigação                   |
| :------------------------------------------- | :-----------: | --------------: | :-------------------------- |
| Descoberta de regras não documentadas no VBA |     Alta      |    +80h a +160h | Buffer de 15% recomendado   |
| Fluxos mais complexos que o esperado         |     Média     |  +40h por fluxo | Reavaliação por onda        |
| Indisponibilidade de SMEs do cliente         |     Média     |  +20h em espera | Acordar agenda na Fase 0    |
| Problemas de performance em produção         |     Baixa     |            +40h | Testes de carga antecipados |

---

## 💰 Estimativa de Investimentos do Projeto

Esta seção apresenta a **estimativa de custos** do projeto, derivada diretamente do [Detalhamento da Estimativa de Horas](#-detalhamento-da-estimativa-de-horas). Os valores são baseados nas **1.600 horas estimadas** (bottom-up, por atividade) e no valor hora padrão de **R$ 150,00**.

### 👥 Composição do Time Néctar

| Recurso                  | Papel no Projeto                                                  | Horas Estimadas | Justificativa da Alocação                                                      |
| ------------------------ | ----------------------------------------------------------------- | :-------------: | ------------------------------------------------------------------------------ |
| **Gerente de Projeto**   | Coordenação, gestão de riscos, comunicação com stakeholders       |      264h       | Atuação transversal em todas as fases; maior intensidade em gates e cerimônias |
| **Arquiteto de Solução** | Definição de padrões, validação de arquitetura, decisões técnicas |      220h       | Forte atuação nas Fases 0–3; suporte consultivo nas Fases 4–5                  |
| **Desenvolvedor Sênior** | Implementação de endpoints, testes, documentação técnica          |      672h       | Principal executor das entregas técnicas (42% do esforço total)                |
| **Desenvolvedor Pleno**  | Implementação, testes unitários, suporte ao Sênior                |      444h       | Trabalha em par com o Sênior nas implementações                                |

### 📊 Cálculo do Custo por Recurso

**Premissas de cálculo:**

- **Total de horas estimadas (bottom-up):** 1.600 horas
- **Duração do projeto (Fases 0–5):** 28 semanas
- **Valor hora (todos os recursos):** R$ 150,00

| Recurso                  | Horas Estimadas | Valor Hora (R$) | Investimento Total (R$) |
| ------------------------ | :-------------: | :-------------: | ----------------------: |
| **Gerente de Projeto**   |       264       |     150,00      |               39.600,00 |
| **Arquiteto de Solução** |       220       |     150,00      |               33.000,00 |
| **Desenvolvedor Sênior** |       672       |     150,00      |              100.800,00 |
| **Desenvolvedor Pleno**  |       444       |     150,00      |               66.600,00 |
| **TOTAL**                |    **1.600**    |        —        |          **240.000,00** |

### 💵 Resumo Financeiro

| Descrição                                     |        Valor (R$) |
| --------------------------------------------- | ----------------: |
| **Total de Horas Estimadas**                  |   **1.600 horas** |
| **Investimento Total de Recursos Néctar**     | **R$ 240.000,00** |
| **Investimento Médio por Semana**             |       R$ 8.571,43 |
| **Investimento Médio por Mês (4,33 semanas)** |      R$ 37.114,29 |

### 📈 Distribuição de Investimentos por Fase

| Fase | Nome                    | Duração (sem) |   Horas   | % do Custo | Investimento Estimado (R$) |
| ---: | ----------------------- | :-----------: | :-------: | :--------: | -------------------------: |
|    0 | Alinhamento e contenção |       2       |    112    |     7%     |                  16.800,00 |
|    1 | Definição de contratos  |       2       |    112    |     7%     |                  16.800,00 |
|    2 | Fundação da API         |       3       |    168    |    11%     |                  25.200,00 |
|    3 | Fluxo piloto            |       4       |    240    |    15%     |                  36.000,00 |
|    4 | Migração por fluxo      |      12       |    780    |    49%     |                 117.000,00 |
|    5 | Simplificação do legado |       5       |    188    |    12%     |                  28.200,00 |
|      | **TOTAL**               |    **28**     | **1.600** |  **100%**  |          **R$ 240.000,00** |

### 💳 Cronograma de Pagamento

O pagamento do projeto será realizado conforme o fluxo abaixo, vinculado aos marcos de entrega de cada fase:

| Evento de Pagamento                            | % do Total |     Valor (R$) | Condição de Faturamento                                   |
| ---------------------------------------------- | :--------: | -------------: | --------------------------------------------------------- |
| 📋 **Aceite do Projeto**                       |    30%     |      72.000,00 | Imediatamente após assinatura do contrato e aceite formal |
| 🔍 **Conclusão Fase 0** (Alinhamento)          |    10%     |      24.000,00 | Entrega do inventário técnico e backlog priorizado        |
| 📝 **Conclusão Fase 1** (Contratos)            |    10%     |      24.000,00 | Contratos OpenAPI aprovados e governança definida         |
| 🏗️ **Conclusão Fase 2** (Fundação API)         |    10%     |      24.000,00 | API em DEV/HML com pipeline CI/CD funcional               |
| 🚀 **Conclusão Fase 3** (Fluxo Piloto)         |    15%     |      36.000,00 | Primeiro fluxo em produção com critérios de estabilização |
| 🔄 **Conclusão Fase 4** (Migração por Fluxo)   |    15%     |      36.000,00 | Fluxos críticos migrados e operação híbrida governada     |
| ✅ **Conclusão Fase 5** (Simplificação Legado) |    10%     |      24.000,00 | Rotinas de integração removidas e documentação final      |
| 💰 **TOTAL**                                   |  **100%**  | **240.000,00** |                                                           |

#### 📋 Condições Gerais de Pagamento

1. **Prazo de pagamento:** 10 dias úteis após emissão da Nota Fiscal correspondente ao marco.

2. **Faturamento:** A Néctar emitirá a NF após validação formal do marco pela Cooperflora (aceite do EMV correspondente ou aprovação tácita após 2 dias úteis).

3. **Primeiro pagamento (30%):** Devido imediatamente após o aceite formal do projeto, independente do início da execução.

4. **Pagamentos subsequentes:** Condicionados à conclusão e aceite dos critérios de cada fase, conforme definido na seção [Fases do Projeto](#-fases-do-projeto-e-cronograma-macro).

5. **Atrasos por parte do cliente:** Caso haja atraso na validação de entregas ou fornecimento de insumos pela Cooperflora que impacte o cronograma, os pagamentos seguirão o calendário original, não sendo postergados.

```mermaid
%%{init: { 'theme': 'base', 'themeVariables': {
    'cScale0': '#10B981', 'cScaleLabel0': '#ffffff',
    'cScale1': '#4F46E5', 'cScaleLabel1': '#ffffff',
    'cScale2': '#F59E0B', 'cScaleLabel2': '#ffffff'
} } }%%
timeline
    title Cronograma de Pagamento do Projeto
    %% ===== SEÇÃO INÍCIO =====
    section 📋 Início
        Aceite do Projeto : 💰 30% – R$ 72.000,00 : Assinatura e aceite formal
    %% ===== SEÇÃO FUNDAÇÃO =====
    section 🏗️ Fases 0–2 (Fundação)
        Fase 0 : 💰 10% – R$ 24.000,00 : Inventário técnico
        Fase 1 : 💰 10% – R$ 24.000,00 : Contratos OpenAPI
        Fase 2 : 💰 10% – R$ 24.000,00 : API em DEV/HML
    %% ===== SEÇÃO EXECUÇÃO =====
    section 🚀 Fases 3–5 (Execução)
        Fase 3 : 💰 15% – R$ 36.000,00 : Fluxo piloto em PRD
        Fase 4 : 💰 15% – R$ 36.000,00 : Migração completa
        Fase 5 : 💰 10% – R$ 24.000,00 : Simplificação legado
```

```mermaid
---
title: Distribuição dos Pagamentos (R$)
---
%%{init: { 'theme': 'base', 'themeVariables': {
    'pie1': '#10B981',
    'pie2': '#4F46E5',
    'pie3': '#6366F1',
    'pie4': '#818CF8',
    'pie5': '#F59E0B',
    'pie6': '#FBBF24',
    'pie7': '#FCD34D'
} } }%%
pie showData
    %% ===== DISTRIBUIÇÃO DE PAGAMENTOS =====
    "Aceite (30%)" : 72000
    "Fase 0 (10%)" : 24000
    "Fase 1 (10%)" : 24000
    "Fase 2 (10%)" : 24000
    "Fase 3 (15%)" : 36000
    "Fase 4 (15%)" : 36000
    "Fase 5 (10%)" : 24000
```

### ⚠️ Observações Importantes

1. **Fase 6 (Evolução opcional)** não está incluída nesta estimativa por ser executada sob demanda, com escopo e custos a serem definidos caso a caso.

2. **Contingência não incluída:** Recomenda-se reserva de 15–20% para contingências, o que elevaria o investimento total para aproximadamente **R$ 276.000,00 a R$ 288.000,00**.

3. **Investimentos não contemplados:**

   - Licenciamento de ferramentas (APM, Service Bus, etc.) — responsabilidade da Cooperflora conforme premissas
   - Infraestrutura de ambientes (DEV/HML/PRD)
   - Eventuais horas extras ou alocação emergencial

4. **Valores válidos para o escopo definido:** Mudanças de escopo podem impactar custos conforme processo de Change Control.

> **📋 Resumo Executivo de Investimento**
>
> | Métrica                    | Valor                 |
> | -------------------------- | --------------------- |
> | **Investimento Total**     | **R$ 240.000,00**     |
> | **Duração**                | 28 semanas (~7 meses) |
> | **Valor Hora Base**        | R$ 150,00             |
> | **Recursos Alocados**      | 4 profissionais       |
> | **Total de Horas**         | 1.600 horas           |
> | **Com Contingência (15%)** | R$ 276.000,00         |
> | **Com Contingência (20%)** | R$ 288.000,00         |

---

## 📖 Glossário

Esta seção define os termos técnicos e siglas utilizados neste documento para garantir entendimento comum entre todos os stakeholders.

### Termos de Negócio

| Termo           | Definição                                                                            |
| --------------- | ------------------------------------------------------------------------------------ |
| **BDM**         | Business Decision Maker – tomador de decisão de negócio (ex.: Sponsor, PO, Gestores) |
| **TDM**         | Technical Decision Maker – tomador de decisão técnica (ex.: Arquiteto, Tech Lead)    |
| **Cooperflora** | Cliente – cooperativa agrícola que utiliza o módulo integrador                       |
| **Néctar**      | Fornecedor – empresa responsável pelo ERP e pela modernização                        |
| **ERP**         | Enterprise Resource Planning – sistema de gestão empresarial Néctar                  |
| **PO**          | Product Owner – responsável por priorizar backlog e aceitar entregas                 |
| **ROI**         | Return on Investment – retorno sobre o investimento                                  |
| **SLA**         | Service Level Agreement – acordo de nível de serviço                                 |

### Termos Técnicos

| Termo              | Definição                                                                     |
| ------------------ | ----------------------------------------------------------------------------- |
| **API**            | Application Programming Interface – interface para comunicação entre sistemas |
| **REST**           | Representational State Transfer – estilo arquitetural para APIs web           |
| **OpenAPI**        | Especificação para documentar APIs REST (anteriormente Swagger)               |
| **VBA**            | Visual Basic for Applications – linguagem de programação do Microsoft Access  |
| **SQL Server**     | Sistema de gerenciamento de banco de dados relacional da Microsoft            |
| **JSON**           | JavaScript Object Notation – formato de troca de dados                        |
| **Endpoint**       | Ponto de acesso de uma API (URL específica para uma operação)                 |
| **Idempotência**   | Propriedade onde múltiplas execuções produzem o mesmo resultado               |
| **Correlation-ID** | Identificador único para rastrear uma transação entre sistemas                |
| **Feature Flag**   | Chave de configuração para habilitar/desabilitar funcionalidades              |

### Termos de Arquitetura

| Termo                  | Definição                                                             |
| ---------------------- | --------------------------------------------------------------------- |
| **Strangler Pattern**  | Padrão de migração incremental que "estrangula" o sistema legado      |
| **Clean Architecture** | Arquitetura em camadas com separação de responsabilidades             |
| **Event-Driven**       | Arquitetura orientada a eventos para comunicação assíncrona           |
| **Service Bus**        | Infraestrutura de mensageria para comunicação entre serviços          |
| **DLQ**                | Dead Letter Queue – fila para mensagens que falharam no processamento |
| **Source of Truth**    | Sistema autoritativo para um determinado dado/domínio                 |
| **Dual-Write**         | Escrita simultânea em dois sistemas (antipadrão a ser evitado)        |

### Termos de Projeto

| Termo      | Definição                                                                   |
| ---------- | --------------------------------------------------------------------------- |
| **WBS**    | Work Breakdown Structure – estrutura analítica do projeto                   |
| **EMV**    | Entregável Mínimo Validável – entrega verificável pelo cliente              |
| **RACI**   | Responsible, Accountable, Consulted, Informed – matriz de responsabilidades |
| **RAID**   | Risks, Actions, Issues, Decisions – registro de gestão de projetos          |
| **MoSCoW** | Must, Should, Could, Won't – técnica de priorização                         |
| **CI/CD**  | Continuous Integration/Continuous Delivery – práticas de automação          |
| **RCA**    | Root Cause Analysis – análise de causa raiz de incidentes                   |
| **MTTR**   | Mean Time to Recovery – tempo médio de recuperação                          |

### Termos de Observabilidade

| Termo                 | Definição                                                                                 |
| --------------------- | ----------------------------------------------------------------------------------------- |
| **APM**               | Application Performance Monitoring – monitoramento de performance                         |
| **Logs Estruturados** | Registros de eventos em formato parseável (ex.: JSON)                                     |
| **p95**               | Percentil 95 – métrica que indica o valor abaixo do qual 95% das observações se encontram |
| **Health Check**      | Verificação automática de saúde de um serviço                                             |
| **Dashboard**         | Painel visual com métricas e indicadores                                                  |

---

## 📝 Histórico de Alterações do Documento

> Esta seção complementa o [Histórico de Revisões](#-histórico-de-revisões) com detalhes das principais alterações estruturais.

| Data       | Versão | Alteração                                                                                |
| ---------- | ------ | ---------------------------------------------------------------------------------------- |
| 13/01/2026 | 1.0    | Versão consolidada para aprovação                                                        |
| 13/01/2026 | 1.0    | Adição de Glossário                                                                      |
| 13/01/2026 | 1.0    | Reorganização da estrutura em 3 partes (Visão Executiva, Execução, Fundamentos Técnicos) |
| 13/01/2026 | 1.0    | Remoção de duplicações de conteúdo                                                       |

---

**📄 Fim do Documento**

_Plano de Projeto – Modernização do Módulo Integrador do Sistema Néctar (Cooperflora)_
_Versão 1.0 | Janeiro de 2026 | Néctar_
