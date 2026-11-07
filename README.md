# cockpit-dev

Cockpit de instalação e configuração de um ciclo de desenvolvimento agêntico com Claude Code,
agnóstico ao projeto:

```
/rito-descoberta  →  /parallel-work  →  /feature-00c  →  bmad-code-review  →  /rito-dev  →  registro na PR
  Fase 0, Gate 0       worktree          pipeline SDD      revisão do diff      PR→CI→gate     specs + achados
```

A Fase 0 (`/rito-descoberta`) é dispensada em docs, trivial e hotfix com incidente real.

Modo autônomo (opcional): a chave `MODO_AUTONOMO` do `cockpit.config` (`ligado` ou `desligado`; ausente,
vazia ou inválida vale `desligado`, com aviso na inválida) grava a linha `Merge autônomo:` da constituição
semente. Ligado, o agente mergeia sozinho a PR de código com CI verde e `caminhos-previstos` verde; exige
identidade própria do agente (fora do CODEOWNERS, sem papel admin nem maintain), o segredo `TOKEN_AUTOMACAO`
(usado pelo `release.yml`, também com integração = produção) e rulesets sem bypass, que o `configurar.sh` apenas
lista e nunca cria. A trava `caminhos-previstos` só roda se estiver na branch padrão do repositório; quando ela
exige dono, o dono aprova no commit atual da PR e reexecuta o workflow (Re-run). Vale a linha da constituição: se
ela divergir do `cockpit.config`, o `configurar.sh` avisa. Desligado, o rito é o de sempre. Contrato:
`docs/specs/modo-autonomo/`.

Ao trocar o modo (ligar ou desligar), o owner reexecuta a trava e o `require-codeowner-approval` nas PRs abertas,
porque os status antigos continuam valendo; ao desligar, confere que nenhuma PR do agente ficou com auto-merge
armado (`gh pr merge <n> --disable-auto`). Limite conhecido: a trava não confere o autor da PR. No modo ligado,
qualquer identidade com escrita cuja PR caiba no registro de uma frente (inclusive de frente antiga) passa sem
leitura humana.

Dois comandos: `instalar.sh` (uma vez por máquina) e `configurar.sh` (uma vez por projeto).

> **Em construção.** A governança deste repositório está em [`docs/constitution.md`](docs/constitution.md)
> e o escopo em [`docs/briefing.md`](docs/briefing.md).

Licença: [MIT](LICENSE).
