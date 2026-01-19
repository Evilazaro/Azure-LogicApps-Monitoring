# 📄 Plano de Projeto – Modernização do Módulo Integrador do Sistema Néctar (Cooperflora)

> 📅 **Data de referência:** 13 de janeiro de 2026

---

## 📋 Sobre Este Documento

Este documento é o **índice principal** do Plano de Projeto de Modernização do Módulo Integrador do Sistema Néctar (Cooperflora). O conteúdo completo foi organizado em **documentos modulares** para facilitar a navegação e manutenção.

> **📁 Localização:** Todos os documentos detalhados estão na pasta [plano-modernizacao](./plano-modernizacao/)

---

## 🎯 Resumo Executivo

Este projeto visa modernizar o **Módulo Integrador/Interface (Access + VBA)** utilizado pela Cooperflora para integrar com o ERP Néctar, substituindo o modelo de **acesso direto ao SQL Server** por uma **camada de serviços (API)** com contratos explícitos, segurança e observabilidade.

### Números-Chave

| Métrica               | Valor                 |
| --------------------- | --------------------- |
| **Duração**           | 28 semanas (~7 meses) |
| **Investimento**      | R$ 240.000,00         |
| **Horas Estimadas**   | 1.600 horas           |
| **Fases**             | 6 (0 a 5)             |
| **Recursos Alocados** | 4 profissionais       |

---

## 📑 Índice de Documentos

A documentação completa está organizada nos seguintes documentos:

### Parte I – Visão Executiva (Para BDMs)

| # | Documento | Descrição | Tempo de Leitura |
|---|-----------|-----------|:----------------:|
| 1 | [**Visão Executiva**](./plano-modernizacao/01-visao-executiva.md) | Introdução, escopo, stakeholders, top 5 riscos, critérios de sucesso | ~15 min |

### Parte II – Execução do Projeto (Para BDMs + TDMs)

| # | Documento | Descrição | Tempo de Leitura |
|---|-----------|-----------|:----------------:|
| 3 | [**Execução do Projeto**](./plano-modernizacao/03-execucao-projeto.md) | Strangler Pattern, fases 0-6, roadmap, Gantt chart | ~20 min |
| 4 | [**Gestão do Projeto**](./plano-modernizacao/04-gestao-projeto.md) | RACI, governança, change control, comunicação | ~15 min |
| 5 | [**Riscos e Mitigações**](./plano-modernizacao/05-riscos-mitigacoes.md) | Registro RAID, severidade, contingência, KPIs | ~10 min |
| 6 | [**Premissas e Restrições**](./plano-modernizacao/06-premissas-restricoes.md) | 28 premissas por fase, 7 restrições | ~10 min |
| 7 | [**Investimentos**](./plano-modernizacao/07-investimentos.md) | WBS, custos por recurso, cronograma de pagamento | ~15 min |
| 8 | [**Operação e Suporte**](./plano-modernizacao/08-operacao-suporte.md) | Runbooks, treinamento, Nimbus, event-driven | ~10 min |

### Parte III – Fundamentos Técnicos (Para TDMs)

| # | Documento | Descrição | Tempo de Leitura |
|---|-----------|-----------|:----------------:|
| 2 | [**Fundamentos Técnicos**](./plano-modernizacao/02-fundamentos-tecnicos.md) | Arquitetura, princípios BDAT, padrões técnicos, EMVs | ~25 min |

### Referência

| # | Documento | Descrição |
|---|-----------|-----------|
| 9 | [**Glossário**](./plano-modernizacao/09-glossario.md) | Termos de negócio, técnicos, arquitetura e projeto |
| - | [**README**](./plano-modernizacao/README.md) | Índice detalhado com navegação completa |

---

## 🎯 Guia de Navegação por Interesse

| Se você precisa de... | Vá para... |
| --------------------- | ---------- |
| Entender o problema e a solução proposta | [Visão Executiva](./plano-modernizacao/01-visao-executiva.md) |
| Ver a arquitetura técnica | [Fundamentos Técnicos](./plano-modernizacao/02-fundamentos-tecnicos.md) |
| Saber o que será entregue em cada fase | [Execução do Projeto](./plano-modernizacao/03-execucao-projeto.md) |
| Entender quem decide o quê | [Gestão do Projeto](./plano-modernizacao/04-gestao-projeto.md) |
| Avaliar riscos do projeto | [Riscos e Mitigações](./plano-modernizacao/05-riscos-mitigacoes.md) |
| Conhecer premissas e dependências | [Premissas e Restrições](./plano-modernizacao/06-premissas-restricoes.md) |
| Ver estimativa de horas e custos | [Investimentos](./plano-modernizacao/07-investimentos.md) |
| Planejar operação pós-implantação | [Operação e Suporte](./plano-modernizacao/08-operacao-suporte.md) |
| Definições de termos técnicos | [Glossário](./plano-modernizacao/09-glossario.md) |

---

## 📊 Visão Geral do Cronograma

`mermaid
gantt
    title Cronograma Macro do Projeto
    dateFormat  YYYY-MM-DD

    section Fundação
    Fase 0 - Alinhamento     :f0, 2026-02-03, 2w
    Fase 1 - Contratos       :f1, after f0, 2w
    Fase 2 - Fundação API    :f2, after f1, 3w
    
    section Execução
    Fase 3 - Piloto          :f3, after f2, 4w
    Fase 4 - Migração        :f4, after f3, 12w
    Fase 5 - Simplificação   :f5, after f4, 5w
`

---

## 📂 Estrutura de Arquivos

`
docs/
├── planoProjetoModernizacao.md     ← Este arquivo (índice)
└── plano-modernizacao/
    ├── README.md                    ← Índice detalhado
    ├── 01-visao-executiva.md        ← Visão executiva
    ├── 02-fundamentos-tecnicos.md   ← Arquitetura e padrões
    ├── 03-execucao-projeto.md       ← Fases e cronograma
    ├── 04-gestao-projeto.md         ← Governança e RACI
    ├── 05-riscos-mitigacoes.md      ← Registro RAID
    ├── 06-premissas-restricoes.md   ← Premissas e restrições
    ├── 07-investimentos.md          ← WBS e custos
    ├── 08-operacao-suporte.md       ← Runbooks e operação
    └── 09-glossario.md              ← Glossário de termos
`

---

## 🚀 Próximos Passos

1. **Aprovar** este plano de projeto com os stakeholders
2. **Mobilizar** equipe para início da Fase 0
3. **Realizar** kick-off com Cooperflora
4. **Iniciar** inventário técnico do módulo Access/VBA

---

> **📚 Documentação Completa:** Para navegar por todos os documentos detalhados, acesse o [README do Plano de Modernização](./plano-modernizacao/README.md).
