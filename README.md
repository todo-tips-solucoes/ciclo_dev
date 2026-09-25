# cockpit-dev

Cockpit de instalação e configuração de um ciclo de desenvolvimento agêntico com Claude Code,
agnóstico ao projeto:

```
/parallel-work  →  /feature-00c  →  bmad-code-review  →  /rito-dev  →  registro na PR
   worktree        pipeline SDD      revisão do diff      PR→CI→gate     specs + achados
```

Dois comandos: `instalar.sh` (uma vez por máquina) e `configurar.sh` (uma vez por projeto).

> **Em construção.** A governança deste repositório está em [`docs/constitution.md`](docs/constitution.md)
> e o escopo em [`docs/briefing.md`](docs/briefing.md).

Licença: [MIT](LICENSE).
