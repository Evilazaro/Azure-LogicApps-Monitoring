---
title: Premissas e Restrições
description: Premissas assumidas por fase e restrições conhecidas do projeto de modernização
author: Néctar Sistemas
date: 2026-01-13
version: 1.0
tags: [premissas, restrições, planejamento, riscos]
---

# 📋 Premissas e Restrições do Projeto

> [!NOTE]
> 🎯 **Para BDMs e TDMs**: Esta seção documenta todas as premissas assumidas e restrições conhecidas do projeto.  
> ⏱️ **Tempo estimado de leitura:** 15 minutos

<details>
<summary>📍 <strong>Navegação Rápida</strong></summary>

| Anterior | Índice | Próximo |
|:---------|:------:|--------:|
| [← Riscos e Mitigações](./05-riscos-mitigacoes.md) | [📑 Índice](./README.md) | [Investimentos →](./07-investimentos.md) |

</details>

---

## 📑 Índice

- [✅ Premissas](#-premissas)
  - [🎯 Legenda de Severidade](#-legenda-de-severidade)
  - [Fase 0 – Alinhamento e Contenção de Riscos](#fase-0--alinhamento-e-contenção-de-riscos)
  - [Fase 1 – Definição dos Contratos de Integração](#fase-1--definição-dos-contratos-de-integração)
  - [Fase 2 – Fundação da API](#fase-2--fundação-da-api)
  - [Fase 3 – Fluxo Piloto](#fase-3--fluxo-piloto)
  - [Fase 4 – Migração por Fluxo / Operação Híbrida](#fase-4--migração-por-fluxo--operação-híbrida)
  - [Fase 5 – Simplificação do Legado](#fase-5--simplificação-do-legado)
  - [Fase 6 – Evolução Opcional](#fase-6--evolução-opcional)
  - [Premissas Transversais (Aplicáveis a Todas as Fases)](#premissas-transversais-aplicáveis-a-todas-as-fases)
  - [⚠️ Impacto Financeiro para Premissas Não Cumpridas](#️-impacto-financeiro-para-premissas-não-cumpridas)
- [⛔ Restrições](#-restrições)
- [📚 Documentos Relacionados](#-documentos-relacionados)

---

## ✅ Premissas

As premissas são condições assumidas como verdadeiras para fins de planejamento. Se alguma premissa se mostrar falsa, deve ser tratada como **risco materializado** e seguir o processo de gestão de riscos. As premissas estão organizadas por **fase do ciclo de vida** do projeto e **responsável**, com destaque para impactos financeiros quando aplicável.

> [!IMPORTANT]
> **Monitoramento de Premissas**: Cada premissa deve ser revisada nas reuniões de status semanais.
> Premissas com severidade 🔴 **Crítico** devem ter plano de contingência documentado.

### 🎯 Legenda de Severidade

> **Severidade** = Probabilidade de Falha × Impacto no Projeto

|   Severidade   | Descrição                                                          | Ação Requerida                                                     |
| :------------: | ------------------------------------------------------------------ | ------------------------------------------------------------------ |
| 🔴 **Crítico** | Alta probabilidade de falha com impacto severo no cronograma/custo | Monitoramento semanal no Comitê; plano de contingência obrigatório |
|  🟠 **Alto**   | Probabilidade média-alta com impacto significativo                 | Acompanhamento quinzenal; mitigação documentada                    |
|  🟡 **Médio**  | Probabilidade média com impacto moderado                           | Monitoramento mensal; tratamento quando materializado              |
|  🟢 **Baixo**  | Baixa probabilidade ou impacto controlável                         | Revisão periódica; sem ação imediata necessária                    |

---

### Fase 0 – Alinhamento e Contenção de Riscos

|  ID | Premissa                                                                                        | Responsável          | Impacto se Falsa                                      |   Severidade   | Impacto em Investimentos (Cooperflora)                                                                              |
| --: | ----------------------------------------------------------------------------------------------- | -------------------- | ----------------------------------------------------- | :------------: | ------------------------------------------------------------------------------------------------------------------- |
| P01 | Cooperflora designará interlocutores técnicos e de negócio com autonomia para tomada de decisão | Cooperflora          | Atraso em validações e aprovações; bloqueio de Fase 0 | 🔴 **Crítico** | **Ociosidade da equipe Néctar**: custo de espera estimado em X h/dia por profissional alocado aguardando definições |
| P02 | Cooperflora proverá acesso ao ambiente de produção/homologação para mapeamento do legado        | Cooperflora          | Inventário técnico incompleto; riscos não mapeados    |  🟠 **Alto**   | **Retrabalho**: custo adicional de 20-40% nas fases seguintes por descobertas tardias                               |
| P03 | O legado (Access/VBA) permanecerá estável durante a fase de mapeamento                          | Néctar + Cooperflora | Retrabalho em mapeamento; documentação desatualizada  |  🟡 **Médio**  | —                                                                                                                   |
| P04 | Documentação existente do legado será disponibilizada (se houver)                               | Cooperflora          | Maior esforço de engenharia reversa                   |  🟡 **Médio**  | **Horas adicionais de análise**: 30-50% a mais de esforço na Fase 0                                                 |

---

### Fase 1 – Definição dos Contratos de Integração

|  ID | Premissa                                                                             | Responsável | Impacto se Falsa                                         |   Severidade   | Impacto em Investimentos (Cooperflora)                                                                   |
| --: | ------------------------------------------------------------------------------------ | ----------- | -------------------------------------------------------- | :------------: | -------------------------------------------------------------------------------------------------------- |
| P05 | Cooperflora participará ativamente dos workshops de definição de contratos           | Cooperflora | Contratos mal definidos; retrabalho em fases posteriores |  🟠 **Alto**   | **Reagendamento de workshops**: custo de mobilização de equipe técnica Néctar (especialistas/arquitetos) |
| P06 | Requisitos de negócio para cada fluxo serão validados pelo PO dentro de 5 dias úteis | Cooperflora | Atraso na aprovação de contratos OpenAPI                 | 🔴 **Crítico** | **Ociosidade**: equipe técnica aguardando validação; custo de alocação sem produtividade                 |
| P07 | Requisitos de segurança e autenticação serão definidos pela TI Cooperflora           | Cooperflora | Bloqueio na definição de padrões de API                  |  🟠 **Alto**   | **Atraso cascateado**: impacto em Fase 2 e 3                                                             |

---

### Fase 2 – Fundação da API

|  ID | Premissa                                                                                         | Responsável          | Impacto se Falsa                         |   Severidade   | Impacto em Investimentos (Cooperflora)                                              |
| --: | ------------------------------------------------------------------------------------------------ | -------------------- | ---------------------------------------- | :------------: | ----------------------------------------------------------------------------------- |
| P08 | Acessos e credenciais para ambientes DEV/HML serão providos em até 5 dias úteis após solicitação | Cooperflora          | Bloqueio de desenvolvimento e testes     | 🔴 **Crítico** | **Ociosidade de desenvolvedores**: custo diário da equipe de desenvolvimento parada |
| P09 | Infraestrutura de rede/firewall será configurada para comunicação API ↔ ERP                      | Cooperflora          | Impossibilidade de validar conectividade |  🟠 **Alto**   | **Atraso em smoke tests**: reprogramação de atividades e possível extensão de fase  |
| P10 | Não haverá mudanças estruturais no ERP Néctar durante a fundação                                 | Néctar               | Impacto em conectividade e contratos     |  🟡 **Médio**  | —                                                                                   |
| P11 | Ambiente de HML representará adequadamente o ambiente de produção                                | Néctar + Cooperflora | Defeitos descobertos apenas em PRD       |  🟠 **Alto**   | —                                                                                   |

---

### Fase 3 – Fluxo Piloto

|  ID | Premissa                                                                                     | Responsável | Impacto se Falsa                           |   Severidade   | Impacto em Investimentos (Cooperflora)                                                        |
| --: | -------------------------------------------------------------------------------------------- | ----------- | ------------------------------------------ | :------------: | --------------------------------------------------------------------------------------------- |
| P12 | Cooperflora disponibilizará recursos para homologação nas janelas definidas (mín. 4h/semana) | Cooperflora | Atraso em validação e go-live do piloto    | 🔴 **Crítico** | **Extensão de fase**: custo de equipe Néctar alocada além do previsto; possível remobilização |
| P13 | Dados de teste representativos serão fornecidos ou autorizados para uso                      | Cooperflora | Testes não representam cenários reais      |  🟠 **Alto**   | **Retrabalho pós-produção**: correções emergenciais com custo premium                         |
| P14 | Usuários-chave estarão disponíveis para validação funcional                                  | Cooperflora | Homologação incompleta; riscos em produção |  🟠 **Alto**   | **Atraso de go-live**: custo de sustentação do piloto em HML por período estendido            |
| P15 | Critérios de aceite serão definidos e aprovados antes do início da homologação               | Cooperflora | Divergências sobre conclusão da fase       |  🟡 **Médio**  | —                                                                                             |

---

### Fase 4 – Migração por Fluxo / Operação Híbrida

|  ID | Premissa                                                                    | Responsável | Impacto se Falsa                                    |   Severidade   | Impacto em Investimentos (Cooperflora)                                                     |
| --: | --------------------------------------------------------------------------- | ----------- | --------------------------------------------------- | :------------: | ------------------------------------------------------------------------------------------ |
| P16 | Janelas de homologação serão respeitadas conforme calendário acordado       | Cooperflora | Atraso em ondas de migração                         | 🔴 **Crítico** | **Extensão de projeto**: custo mensal adicional de equipe alocada; renegociação contratual |
| P17 | Comunicação de mudanças será feita aos usuários finais pela Cooperflora     | Cooperflora | Resistência à mudança; incidentes por uso incorreto |  🟡 **Médio**  | —                                                                                          |
| P18 | O legado permanecerá estável (sem novas funcionalidades de integração)      | Cooperflora | Divergência entre legado e API; retrabalho          |  🟠 **Alto**   | **Retrabalho de mapeamento**: custo de análise e ajuste de contratos já definidos          |
| P19 | Incidentes em produção terão resposta da operação Cooperflora dentro do SLA | Cooperflora | Aumento de MTTR; impacto em estabilização           |  🟠 **Alto**   | —                                                                                          |

---

### Fase 5 – Simplificação do Legado

|  ID | Premissa                                                                       | Responsável | Impacto se Falsa                                     |  Severidade  | Impacto em Investimentos (Cooperflora)                                  |
| --: | ------------------------------------------------------------------------------ | ----------- | ---------------------------------------------------- | :----------: | ----------------------------------------------------------------------- |
| P20 | Cooperflora autorizará a remoção de rotinas de integração obsoletas            | Cooperflora | Legado não simplificado; custo de manutenção mantido | 🟡 **Médio** | —                                                                       |
| P21 | Conhecimento do legado será transferido para documentação antes da remoção     | Néctar      | Perda de conhecimento institucional                  | 🟡 **Médio** | —                                                                       |
| P22 | Treinamento de suporte será realizado com participação da operação Cooperflora | Cooperflora | Operação não preparada para novo modelo              | 🟠 **Alto**  | **Incidentes evitáveis**: custo de suporte reativo ao invés de proativo |

---

### Fase 6 – Evolução Opcional

|  ID | Premissa                                                                        | Responsável | Impacto se Falsa                    |  Severidade  | Impacto em Investimentos (Cooperflora) |
| --: | ------------------------------------------------------------------------------- | ----------- | ----------------------------------- | :----------: | -------------------------------------- |
| P23 | Iniciativas de evolução serão aprovadas com justificativa de ROI                | Cooperflora | Investimento sem retorno mensurável | 🟡 **Médio** | —                                      |
| P24 | Decisões estratégicas (ex.: migração Nimbus) serão comunicadas com antecedência | Cooperflora | Falta de preparação arquitetural    | 🟡 **Médio** | —                                      |

---

### Premissas Transversais (Aplicáveis a Todas as Fases)

|  ID | Premissa                                                               | Responsável          | Impacto se Falsa                                      |   Severidade   | Impacto em Investimentos (Cooperflora)                                        |
| --: | ---------------------------------------------------------------------- | -------------------- | ----------------------------------------------------- | :------------: | ----------------------------------------------------------------------------- |
| P25 | O escopo aprovado será respeitado, com mudanças via controle formal    | Néctar + Cooperflora | Scope creep, atraso e estouro de orçamento            | 🔴 **Crítico** | **Renegociação contratual**: custos adicionais para mudanças de escopo        |
| P26 | Reuniões de governança terão quórum mínimo para tomada de decisão      | Néctar + Cooperflora | Decisões postergadas; atrasos em aprovações           |  🟠 **Alto**   | —                                                                             |
| P27 | Comunicação entre equipes seguirá canais e SLAs definidos              | Néctar + Cooperflora | Falhas de comunicação; retrabalho                     |  🟡 **Médio**  | —                                                                             |
| P28 | EMVs serão validados em **2 dias úteis**; após prazo, aprovação tácita | Cooperflora          | Aprovação automática; ajustes viram mudança de escopo | 🔴 **Crítico** | **Investimentos adicionais**: solicitações pós-aprovação impactam prazo/custo |

---

## ⚠️ Impacto Financeiro para Premissas Não Cumpridas

O não cumprimento de premissas sob responsabilidade da Cooperflora pode gerar os seguintes impactos financeiros:

| Tipo de Impacto               | Descrição                                                         | Estimativa de Custo                                           |
| ----------------------------- | ----------------------------------------------------------------- | ------------------------------------------------------------- |
| **Ociosidade de equipe**      | Profissionais Néctar alocados aguardando insumos/aprovações       | Custo/hora × horas de espera × número de profissionais        |
| **Extensão de fase**          | Fases estendidas além do planejado por atrasos do cliente         | Custo mensal da equipe × meses adicionais                     |
| **Retrabalho**                | Refazer atividades por mudanças tardias ou informações incorretas | 20-50% do esforço original da atividade                       |
| **Remobilização**             | Desmobilizar e remobilizar equipe por pausas não planejadas       | Custo de transição + perda de contexto (estimado 1-2 semanas) |
| **Suporte emergencial**       | Correções urgentes fora do horário comercial                      | Custo premium (1,5x a 2x do valor hora normal)                |
| **Ajustes pós-aprovação EMV** | Solicitações após prazo de 2 dias ou aprovação tácita             | Tratado como mudança de escopo (custo + prazo adicional)      |

### 📊 Distribuição de Severidade (P01–P28)

| Severidade        | Quantidade | Percentual |
| ----------------- | :--------: | :--------: |
| 🔴 **Crítico**    |     6      |    21%     |
| 🟠 **Alto**       |     8      |    29%     |
| 🟡 **Médio**      |    14      |    50%     |

> **⚠️ Premissas Críticas (🔴)**: P01, P06, P08, P12, P16, P25 e P28 — requerem acompanhamento **semanal** no Comitê de Projeto.

---

## ⛔ Restrições

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

---

## 📚 Documentos Relacionados

| Documento                                                      | Descrição                            |
| -------------------------------------------------------------- | ------------------------------------ |
| [Riscos e Mitigações](./05-riscos-mitigacoes.md)               | Registro RAID e planos de mitigação  |
| [Gestão do Projeto](./04-gestao-projeto.md)                    | Governança e processos de controle   |
| [Execução do Projeto](./03-execucao-projeto.md)                | Fases e cronograma detalhado         |
| [Investimentos](./07-investimentos.md)                         | Orçamento e custos do projeto        |

---

<div align="center">

[⬆️ Voltar ao topo](#-premissas-e-restrições-do-projeto) | [📑 Índice](./README.md) | [Investimentos →](./07-investimentos.md)

</div>
