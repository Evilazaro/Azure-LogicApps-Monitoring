---
title: Glossário
description: Definições de termos técnicos, siglas e conceitos utilizados na documentação do projeto
author: Néctar Sistemas
date: 2026-01-13
version: 1.0
tags: [glossário, termos, definições, siglas]
---

# 📖 Glossário

> [!NOTE]
> 🎯 **Para Todos**: Este glossário define os termos técnicos e siglas utilizados na documentação do projeto para garantir entendimento comum entre todos os stakeholders.  
> ⏱️ **Tempo estimado de leitura:** 5 minutos

<details>
<summary>📍 <strong>Navegação Rápida</strong></summary>

| Anterior                                         |          Índice          | Próximo |
| :----------------------------------------------- | :----------------------: | ------: |
| [← Operação e Suporte](./08-operacao-suporte.md) | [📑 Índice](./README.md) |       — |

</details>

---

## 📑 Índice

- [🏬 Termos de Negócio](#-termos-de-negócio)
- [💻 Termos Técnicos](#-termos-técnicos)
- [🏗️ Termos de Arquitetura](#️-termos-de-arquitetura)
- [📊 Termos de Projeto](#-termos-de-projeto)
- [📈 Termos de Observabilidade](#-termos-de-observabilidade)
- [📚 Documentos Relacionados](#-documentos-relacionados)

---

## 🏬 Termos de Negócio

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

---

## 💻 Termos Técnicos

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

---

## 🏗️ Termos de Arquitetura

| Termo                  | Definição                                                             |
| ---------------------- | --------------------------------------------------------------------- |
| **Strangler Pattern**  | Padrão de migração incremental que "estrangula" o sistema legado      |
| **Clean Architecture** | Arquitetura em camadas com separação de responsabilidades             |
| **Event-Driven**       | Arquitetura orientada a eventos para comunicação assíncrona           |
| **Service Bus**        | Infraestrutura de mensageria para comunicação entre serviços          |
| **DLQ**                | Dead Letter Queue – fila para mensagens que falharam no processamento |
| **Source of Truth**    | Sistema autoritativo para um determinado dado/domínio                 |
| **Dual-Write**         | Escrita simultânea em dois sistemas (antipadrão a ser evitado)        |

---

## 📊 Termos de Projeto

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

---

## 📈 Termos de Observabilidade

| Termo                 | Definição                                                                                 |
| --------------------- | ----------------------------------------------------------------------------------------- |
| **APM**               | Application Performance Monitoring – monitoramento de performance                         |
| **Logs Estruturados** | Registros de eventos em formato parseável (ex.: JSON)                                     |
| **p95**               | Percentil 95 – métrica que indica o valor abaixo do qual 95% das observações se encontram |
| **Health Check**      | Verificação automática de saúde de um serviço                                             |
| **Dashboard**         | Painel visual com métricas e indicadores                                                  |

---

## 📚 Documentos Relacionados

| Documento                                              | Descrição                        |
| ------------------------------------------------------ | -------------------------------- |
| [README](./README.md)                                  | Índice da documentação           |
| [Visão Executiva](./01-visao-executiva.md)             | Contexto de negócio              |
| [Fundamentos Técnicos](./02-fundamentos-tecnicos.md)   | Arquitetura e padrões            |
| [Execução do Projeto](./03-execucao-projeto.md)        | Fases e cronograma               |
| [Gestão do Projeto](./04-gestao-projeto.md)            | Governança                       |
| [Riscos e Mitigações](./05-riscos-mitigacoes.md)       | RAID                             |
| [Premissas e Restrições](./06-premissas-restricoes.md) | Premissas e restrições           |
| [Investimentos](./07-investimentos.md)                 | Custos e cronograma de pagamento |
| [Operação e Suporte](./08-operacao-suporte.md)         | Runbooks e treinamento           |

---

<div align="center">

[⬆️ Voltar ao topo](#-glossário) | [📑 Índice](./README.md) | [← Operação e Suporte](./08-operacao-suporte.md)

</div>
