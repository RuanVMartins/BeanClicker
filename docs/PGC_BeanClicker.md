# Plano de Gerenciamento de Configuração (PGC) — BeanClicker

**Enfoque DevOps — Integração e Entrega Contínuas (CI/CD)**
Versão 1.0 · baseado no modelo *PGC DevOps ONGConecta* (Prof. Camargo), adaptado para um jogo em Godot.

| Campo | Descrição |
| :--- | :--- |
| Projeto | BeanClicker — jogo *idle/clicker* satírico para PC (Godot 4.7, GDScript) |
| Contexto | Disciplina PAC (Projeto de Aprendizagem Colaborativa) |
| Responsável de GCS / DevOps | Ruan Vitor ([@RuanVMartins](https://github.com/RuanVMartins)) — dono do repositório |
| Par de revisão | [@xaibelucas](https://github.com/xaibelucas) — colaborador com acesso de escrita (Write) |
| Equipe | Abner, Athos, Lucas Scheibe, Raoni, Ruan Vitor, Vitor Kill |
| Repositório | https://github.com/RuanVMartins/BeanClicker (público, GitHub plano gratuito) |

## Histórico de Revisões

| Data | Versão | Descrição | Autor |
| :--- | :---: | :--- | :--- |
| 16/11/2026 | 1.0 | Elaboração do PGC e configuração inicial do repositório (Aula 1) | Ruan Vitor |

---

## 1. Introdução

### 1.1 Finalidade
Definir como o BeanClicker é versionado, revisado e entregue, garantindo rastreabilidade de cada mudança no jogo (código, cenas, artes, sons e documentação) com o mínimo de burocracia para uma equipe acadêmica de 6 pessoas.

### 1.2 Escopo
Aplica-se a todos os integrantes da equipe e cobre: o projeto Godot (`game/`), a documentação (`docs/`), as configurações do GitHub (`.github/`) e os builds exportados para Windows.

### 1.3 Definições
| Termo | Significado |
| :--- | :--- |
| GCS | Gestão de Configuração de Software |
| IC | Item de Configuração |
| CI / CD | Integração Contínua / Entrega Contínua |
| PR | Pull Request |
| Baseline | Versão estável e identificada (tag `vX.Y.Z`) |
| SemVer | Versionamento Semântico `MAJOR.MINOR.PATCH` |
| GitHub Flow | `main` sempre estável + branches curtas por funcionalidade |

### 1.4 Referências
- PGC DevOps ONGConecta (modelo da disciplina) e repositório https://github.com/lzcamargo/ongconecta
- [GDD do BeanClicker](GDD_BeanClicker.md)
- Documentação do GitHub (Branch protection, Environments, Actions) e do Godot (Exportação)

## 2. Papéis na Gerência de Configuração

| Papel | Quem | Responsabilidades |
| :--- | :--- | :--- |
| Responsável de GCS / Release | Ruan Vitor (@RuanVMartins) | Mantém o repositório, as regras de proteção, os *environments* e aprova a publicação em `production`. |
| Par de revisão | @xaibelucas | Revisa e aprova os PRs para a `main` (ninguém aprova o próprio PR). |
| Desenvolvedores | Toda a equipe | Abrem Issues, trabalham em branches e enviam PRs. |
| QA | Vitor Kill (com apoio de todos) | Testa manualmente os builds de `staging` antes da release. |

**Comunicação:** assíncrona, pelo grupo da equipe e pelos comentários dos PRs. Prazo de resposta a um PR: até 3 dias úteis.

## 3. Ferramentas, Ambientes e Infraestrutura

### 3.1 Ferramentas
| Categoria | Ferramenta |
| :--- | :--- |
| Controle de versão | Git + GitHub |
| Engine / Build | Godot 4.7 (exportação Windows Desktop) |
| CI/CD | GitHub Actions (a implantar — Aulas 2 e 3) |
| Tarefas | GitHub Issues (templates em `.github/ISSUE_TEMPLATE`) |
| Distribuição | GitHub Releases (`.zip` com `.exe` + `.pck`) |
| Dependências | Dependabot para as *actions* (a habilitar) |

### 3.2 Ambientes
Configurados em **Settings → Environments** do GitHub:

| Ambiente | Finalidade | Proteção | Gatilho |
| :--- | :--- | :--- | :--- |
| `staging` | Build de teste do jogo para a equipe validar | Só branches protegidas | Merge na `main` |
| `production` | Release pública (GitHub Releases) | **Revisor obrigatório: @RuanVMartins**; só branches protegidas | Aprovação manual após validação em `staging` |

### 3.3 Estratégia de Branching e Versionamento
- **`main`** — sempre jogável. **Protegida**: push direto bloqueado, PR obrigatório com 1 aprovação, aprovações antigas descartadas a cada novo commit, histórico linear e sem *bypass* (nem para o administrador).
- **`feature/<issue>-<descricao>`** e **`fix/<issue>-<descricao>`** — uma branch por mudança.
- **Merge:** apenas *squash merge* (cada PR vira um commit na `main`), com exclusão automática da branch.
- **Versão:** SemVer (`v2.0.0` = versão atual do jogo) e Conventional Commits (`feat`, `fix`, `docs`, `chore`, `refactor`).

## 4. Identificação da Configuração

### 4.1 Itens de Configuração
- Código-fonte GDScript (`game/**/*.gd`) e cenas (`game/**/*.tscn`);
- `game/project.godot` (configuração e versão da engine) e `game/export_presets.cfg` (configuração de build);
- Assets: imagens (`game/images/`) e sons (`game/*.mp3`), com os arquivos `.import`;
- Documentação: `README.md`, este PGC e o GDD (`docs/`);
- Configurações do repositório: `.gitignore`, `.gitattributes`, `.github/` (template de PR, CODEOWNERS, templates de Issue) e, futuramente, `.github/workflows/`.

**Não são ICs versionados:** a pasta `.godot/` (cache), builds (`.exe`, `.pck`, `.zip`) e saves locais. Não há segredos no projeto; se surgirem, ficam em GitHub Secrets.

### 4.2 Convenção de Nomenclatura
| Item | Convenção | Exemplo |
| :--- | :--- | :--- |
| Branch | `feature/<issue>-<descricao>` | `feature/12-novo-jogo-cassino` |
| Commit / título de PR | `<tipo>(<escopo>): <descrição>` | `feat(casino): adiciona esquema pirâmide` |
| Tag de release | `vX.Y.Z` | `v2.1.0` |
| Build | `BeanClicker-<versão>-windows.zip` | `BeanClicker-2.1.0-windows.zip` |

### 4.3 Estrutura do Repositório
```
game/      projeto Godot (project.godot, cenas, scripts, assets)
docs/      PGC, GDD e screenshots
.github/   templates de PR/Issue, CODEOWNERS e workflows
```

## 5. Integração Contínua (CI)

- Todo PR para a `main` deve passar por revisão do par (1 aprovação) antes do merge.
- **Planejado (Aula 2):** workflow no GitHub Actions que abre o projeto no Godot em modo *headless* e faz a exportação de teste; o merge só será permitido com o pipeline verde (*status check* obrigatório).
- **Quality gate inicial:** projeto abre sem erros de script e o build Windows é gerado.

## 6. Entrega Contínua (CD)

1. Merge na `main` → build do jogo publicado no ambiente `staging` (artefato para a equipe testar).
2. Teste manual pela equipe.
3. Aprovação de @RuanVMartins no ambiente `production`.
4. Criação da tag `vX.Y.Z` e de uma GitHub Release com o `.zip` do jogo.

**Rollback:** a release anterior continua disponível em *Releases*; basta indicar a versão anterior ou reverter o commit por um novo PR.

## 7. Controle de Mudanças

Fluxo padrão: **Issue → branch → commits → PR → revisão do par → merge (squash) → staging → aprovação → production**. O histórico de Issues, PRs e Actions é o registro formal das mudanças.

Mudanças de maior risco (ex.: alteração do formato do save, que pode apagar o progresso dos jogadores) devem ser discutidas no PR e aprovadas também pelo Responsável de GCS.

## 8. Baselines e Releases

Cada release aprovada em `production` gera uma baseline: tag SemVer no commit da `main` + GitHub Release com notas de versão (geradas a partir dos títulos dos PRs).

## 9. Status e Auditoria

O histórico do GitHub (commits, PRs, aprovações, execuções do Actions e *deployments* dos environments) é a fonte de auditoria de GCS.

## 10. Marcos

- [x] Repositório organizado, PGC publicado e `main` protegida (Aula 1)
- [ ] Pipeline de CI com build do Godot (Aula 2)
- [ ] Pipeline de CD com `staging` e `production` (Aula 3)
- [ ] Primeira release automatizada `v2.1.0`
