---
title: Visão Executiva
description: Introdução, escopo, governança, riscos e critérios de sucesso do projeto de modernização
author: Néctar Sistemas
date: 2026-01-13
version: 1.0
tags: [visão-executiva, escopo, governança, riscos, bdm]
---

# 📋 PARTE I – Visão Executiva

> [!NOTE]
> 🎯 **Para BDMs**: Esta parte contém tudo o que você precisa para entender o projeto, aprovar escopo e acompanhar a execução.  
> ⏱️ **Tempo estimado de leitura:** 15 minutos

<details>
<summary>📍 <strong>Navegação Rápida</strong></summary>

| Anterior |          Índice          |                                                Próximo |
| :------- | :----------------------: | -----------------------------------------------------: |
| —        | [📑 Índice](./README.md) | [Fundamentos Técnicos →](./02-fundamentos-tecnicos.md) |

</details>

---

## 📑 Índice

- [🎯 Introdução](#-introdução)
  - [🎯 Objetivo do Documento](#-objetivo-do-documento)
  - [⚠️ Situação atual e motivação](#️-situação-atual-e-motivação)
- [🎯 Escopo do Projeto](#-escopo-do-projeto)
  - [🎯 Escopo por Domínio de Negócio](#-escopo-por-domínio-de-negócio)
  - [🚫 Fora do escopo](#-fora-do-escopo)
- [👥 Governança e Tomada de Decisão](#-governança-e-tomada-de-decisão)
  - [💼 Stakeholders Principais](#-stakeholders-principais)
  - [📋 Matriz RACI Simplificada](#-matriz-raci-simplificada)
  - [🏛️ Fóruns de Decisão](#️-fóruns-de-decisão)
- [⚠️ Riscos Principais e Critérios de Sucesso](#️-riscos-principais-e-critérios-de-sucesso)
  - [📝 Top 5 Riscos](#-top-5-riscos)
  - [🏆 Critérios de Sucesso](#-critérios-de-sucesso)
- [📚 Documentos Relacionados](#-documentos-relacionados)

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
| Integração acoplada ao banco do ERP (SQL Server como "hub")             | Acesso direto às tabelas do ERP via SQL Server como camada de integração; Access/VBA e SINC operam sobre tabelas compartilhadas. | Aumenta risco de indisponibilidade e incidentes em mudanças (schema/infra), eleva custo de suporte e dificulta escalar/segregar ambientes; limita decisões de arquitetura e iniciativas futuras. | Substituir o "hub" no banco por uma camada de serviços (API) com controle de acesso e governança, reduzindo dependência de co-localização e viabilizando o cenário sem banco compartilhado.         |
| Contratos de integração implícitos (regras "de fato", não formalizadas) | Semântica de dados conhecida "por tradição" e código legado, sem contratos formais versionados; alto risco de regressões.        | Homologação mais lenta e imprevisível, maior chance de retrabalho e regressões, divergência de entendimento entre áreas e aumento de incidentes em mudanças.                                     | Formalizar contratos e padrões (ex.: OpenAPI, versionamento e erros), reduzindo ambiguidades e permitindo evolução controlada por versão/fluxo.                                                     |
| Orquestração por timers/polling                                         | Rotinas VBA por timers varrem dados "novos" periodicamente; gera concorrência, duplicidades e dificulta rastreio.                | Gera atrasos variáveis, duplicidades e janelas operacionais difíceis de gerenciar; aumenta impacto de falhas silenciosas e dificulta cumprir SLAs por fluxo.                                     | Migrar gradualmente para integrações orientadas a transação/serviço, reduzindo polling e estabelecendo controles (idempotência, reprocessamento) com previsibilidade operacional.                   |
| Regras críticas no legado (VBA/rotinas de tela)                         | Lógica de integração misturada com UI em eventos de formulários VBA; monólito difícil de testar e evoluir.                       | Eleva custo e risco de mudanças, cria dependência de conhecimento específico, dificulta escalabilidade do time e aumenta probabilidade de regressões em produção.                                | Centralizar regras de integração em serviços testáveis e governáveis, reduzindo acoplamento com a UI e melhorando capacidade de evolução com segurança.                                             |
| Governança de dados pouco definida (source of truth)                    | Sem matriz formal de propriedade de dados por domínio; rotinas podem realizar dual-write com precedência não documentada.        | Aumenta inconsistências e conciliações manuais, gera conflitos entre sistemas e amplia risco operacional e de auditoria durante operação híbrida.                                                | Definir propriedade e direção do fluxo por domínio, com critérios claros de resolução de conflitos, suportando migração por fluxo com menor risco.                                                  |
| Baixa visibilidade operacional (observabilidade e rastreabilidade)      | Falhas percebidas tardiamente; rastreio depende de logs esparsos e investigação manual; sem correlação de transações.            | Aumenta MTTR e impacto de incidentes, reduz transparência para gestão e suporte, dificulta governança e tomada de decisão baseada em dados.                                                      | Implementar observabilidade (logs estruturados, métricas, auditoria e correlação por transação), com dashboards/alertas por fluxo para operação e governança.                                       |
| Modelo limita evolução para ambientes segregados/nuvem                  | Arquitetura depende de proximidade física e acesso ao SQL Server; isolamento de rede ou nuvem pode quebrar a integração.         | Bloqueia iniciativas de modernização/segregação, aumenta risco de ruptura em mudanças de infraestrutura e reduz flexibilidade para novas integrações e expansão.                                 | Preparar a integração para operar com segurança em cenários segregados/nuvem, preservando continuidade do negócio e abrindo caminho para evoluções futuras (incl. mensageria quando fizer sentido). |

> [!TIP]
> 📘 **Para detalhes técnicos da arquitetura atual e alvo**, consulte o documento [02 - Fundamentos Técnicos](./02-fundamentos-tecnicos.md).

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

> [!TIP]
> 📘 **Para detalhes completos de cada item de escopo**, consulte o documento [02 - Fundamentos Técnicos](./02-fundamentos-tecnicos.md).

### 🎯 Escopo por Domínio de Negócio

| Domínio                     | Fluxos em Escopo                                                 | Prioridade        |
| --------------------------- | ---------------------------------------------------------------- | ----------------- |
| **Fundação de Plataforma**  | API de Integração, Contratos OpenAPI, Observabilidade, Segurança | Alta (Fase 1–2)   |
| **Cadastros (Master Data)** | Pessoas (piloto), Produtos, Tabelas auxiliares                   | Alta (Fase 3–4)   |
| **Comercial**               | Pedidos e movimentos                                             | Média (Fase 4)    |
| **Fiscal/Faturamento**      | Faturamento, notas fiscais                                       | Média-Baixa (4–5) |
| **Financeiro**              | Contas a pagar/receber, conciliação                              | Média-Baixa (4–5) |
| **Estoque**                 | Movimentações, inventário                                        | Média-Baixa (5)   |

### 🚫 Fora do escopo

| Item fora do escopo                                  | Justificativa                                                                                                         |
| ---------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Reescrita completa do ERP Néctar                     | Programa maior e não necessário para remover o acoplamento de integração                                              |
| Reescrita completa do sistema do cliente             | O projeto foca no integrador; mudanças no cliente serão restritas ao necessário para consumir a API                   |
| Migração completa para arquitetura event-driven      | A Fase 6 prevê evolução opcional; o objetivo principal é remover o banco como camada de integração                    |
| Projeto integral de migração para Nimbus             | O escopo contempla preparação arquitetural e roadmap, não a migração completa                                         |
| Mudanças funcionais profundas no processo de negócio | O foco é modernização técnica e redução de risco, mantendo comportamento funcional compatível                         |
| Novas integrações não listadas                       | Qualquer fluxo não explicitado na tabela de entregáveis deve passar por controle de mudanças antes de ser incorporado |

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

> [!NOTE]
> **Legenda RACI**: R = Responsável | A = Aprovador | C = Consultado | I = Informado

### 🏛️ Fóruns de Decisão

| Fórum                 | Participantes               | Frequência | Propósito                                       |
| --------------------- | --------------------------- | ---------- | ----------------------------------------------- |
| **Comitê Executivo**  | Sponsor, Ger. Projeto, PO   | Mensal     | Decisões estratégicas, mudanças de escopo/custo |
| **Comitê de Projeto** | Ger. Projeto, PO, Arquiteto | Semanal    | Progresso, riscos, priorização                  |
| **Daily Standup**     | Dev Team                    | Diária     | Sincronização, bloqueios                        |

> [!TIP]
> 📘 **Para detalhes completos de governança**, consulte o documento [04 - Gestão do Projeto](./04-gestao-projeto.md).

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

> [!TIP]
> 📘 **Para registro completo de riscos**, consulte o documento [05 - Riscos e Mitigações](./05-riscos-mitigacoes.md).

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

## 📚 Documentos Relacionados

- [02 - Fundamentos Técnicos](./02-fundamentos-tecnicos.md) - Arquitetura e padrões técnicos
- [03 - Execução do Projeto](./03-execucao-projeto.md) - Fases e cronograma
- [04 - Gestão do Projeto](./04-gestao-projeto.md) - Governança detalhada
- [05 - Riscos e Mitigações](./05-riscos-mitigacoes.md) - Registro completo de riscos
- [07 - Investimentos](./07-investimentos.md) - Custos e pagamentos

---

<div align="center">

[⬆️ Voltar ao topo](#-parte-i--visão-executiva) | [📑 Índice](./README.md) | [Fundamentos Técnicos →](./02-fundamentos-tecnicos.md)

</div>
