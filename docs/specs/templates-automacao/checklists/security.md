# Security Checklist: templates-automacao

**Purpose**: Qualidade dos requisitos de segurança dos fluxos, permissões de token e gate de dono
**Created**: 2026-09-30
**Feature**: [spec.md](../spec.md)

## Permissões e credenciais

- [x] CHK001 - Cada fluxo tem `permissions:` explícito, com o que não é listado em `none`? [Completude, Contracts §Regras comuns, F4] {auto}
- [x] CHK002 - Credenciais entram só pelo mecanismo de segredos do provedor, sem segredo embutido? [Completude, Spec §FR-010, §FR-016] {auto}
- [x] CHK003 - O escopo mínimo do `TOKEN_AUTOMACAO` opcional está definido (contents, pull-requests, issues, restrito ao repositório)? [Clareza, Plan §Superfície S2] {auto}
- [x] CHK004 - O escopo exigido pelo `task.sh` (`project`) e a falha sem ele estão definidos? [Completude, Contracts §task.sh código 4, F12] {auto}
- [x] CHK005 - A credencial do `actions/checkout` é impedida de ficar disponível a passos seguintes? [Cobertura, Contracts §Regras comuns, Plan S4] {auto}

## Injeção e cadeia de suprimentos

- [x] CHK006 - Está proibido interpolar dado de evento (`${{ github.event.* }}`) em `run:`? [Clareza, Research Decision 2, Contracts §Regras comuns] {auto}
- [x] CHK007 - Valores do `cockpit.config` têm regra que impede injeção em YAML e no script (bloco literal, formatos restritos de `BOARD` e donos)? [Cobertura, Spec §Edge Cases, §FR-015, Research Decision 1] {auto}
- [x] CHK008 - O corpo da issue de auditoria é montado fora de `run:` (arquivo + `--body-file`)? [Cobertura, Plan S5] {auto}
- [x] CHK009 - Actions de terceiro estão limitadas e fixadas por SHA? [Completude, Contracts §Regras comuns, Research Decision 3] {auto}
- [x] CHK010 - O risco residual do `npx semantic-release@<pin>` sem lockfile, num job com `contents: write`, é aceitável para o produto? [Risco, Plan S3] {humano}
- [x] CHK011 - O uso de `pull_request_target` é restrito a fluxo sem checkout e sem executar código do PR? [Cobertura, Research Decision 6, Plan S6, F9] {auto}

## Gate de dono

- [x] CHK012 - A spec diz que a garantia de aprovação de dono é a regra nativa da branch (aprovações obrigatórias + "Require review from Code Owners") e não o fluxo, que é forjável? Hoje isso está só no plan/quickstart; o US2 promete "PR só é mergeável com aprovação de um dono". [Gap, Spec §FR-007, Plan S1, dec-025] {auto} — resolvido: spec US2 (Garantia, dec-025) e FR-007
- [x] CHK013 - O `CODEOWNERS` é lido da base, e não da cabeça do PR? [Clareza, Research Decision 5] {auto}
- [x] CHK014 - A semântica de review está definida (último review por `user.login`, `dismissed` reavalia, comparação sem diferenciar maiúsculas)? [Clareza, Research Decision 5, Contracts §require-codeowner-approval] {auto}
- [x] CHK015 - O comportamento sem `CODEOWNERS` na base está definido? [Edge Case, Contracts §require-codeowner-approval] {auto}
- [x] CHK016 - O comportamento em PR de fork está definido (token somente-leitura basta)? [Cobertura, Research Decision 5, F9] {auto}
- [x] CHK017 - Está definido o que acontece quando um dono de `DONOS_CODEOWNERS` não tem permissão de escrita (F8: "must have write permissions")? O fluxo o aceitaria e a regra nativa não. [Gap, Spec §FR-015, F8] {auto}
- [x] CHK018 - A opção "Allow GitHub Actions to create and approve pull requests" tem recomendação explícita (manter desligada quando houver `TOKEN_AUTOMACAO`)? [Clareza, Plan S2, F5] {auto}

## Vazamento

- [x] CHK019 - Há critério mensurável de ausência de valor de projeto, e-mail pessoal e credencial nos templates? [Mensurabilidade, Spec §FR-016, §SC-003] {auto}

## Notes

- Items `{auto}` resolvidos com a seção citada. CHK012: spec US2 (Garantia) e FR-007; CHK017: spec FR-007 e quickstart §Validação manual; CHK010: aceito pelo dono do produto (block-005, dec-031), plan S3.
