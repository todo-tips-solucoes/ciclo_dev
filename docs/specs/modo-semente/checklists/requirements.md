# Requirements Checklist: modo semente no configurar.sh

**Purpose**: qualidade dos requisitos de spec.md/plan.md antes de create-tasks.
**Created**: 2026-10-01
**Feature**: [spec.md](../spec.md)

## Completude

- [x] CHK001 - O criterio de "semente existe" esta definido para todos os tipos de destino (arquivo, diretorio, link quebrado)? [Completude, Spec §FR-002, Edge Cases] {auto}
- [x] CHK002 - Esta definido o efeito de `--forcar` e do modo interativo sobre semente existente? [Completude, Spec §FR-003, US1.3] {auto}
- [x] CHK003 - Esta definido o efeito sobre o manifesto para semente gravada e para semente pulada? [Completude, Spec §FR-006] {auto}
- [x] CHK004 - Esta definido o formato exato da linha de relatorio e da contagem? [Completude, Spec §FR-007; Plan contracts/cli.md] {auto}
- [x] CHK005 - O comportamento de `--atualizar` com semente apagada/editada esta especificado? [Completude, Spec §US2, Clarifications] {auto}
- [x] CHK006 - O exit code quando so ha sementes mantidas esta especificado? [Completude, Spec §Clarifications] {auto}
- [x] CHK007 - Os tres templates a converter estao nomeados e a documentacao afetada identificada? [Completude, Spec §FR-008; Plan §Templates] {auto}

## Clareza e mensurabilidade

- [x] CHK008 - A regra de nome do destino (`.semente.tmpl` sai inteiro) e inequivoca? [Clareza, Spec §FR-001, US3.1] {auto}
- [x] CHK009 - "Pulada sem leitura de conteudo, sem comparacao e sem consulta ao manifesto" (FR-002) e consistente com "entrada anterior e mantida" (FR-006), dado que o plan le o manifesto anterior em gravar_manifesto? [Ambiguity, Spec §FR-002 x §FR-006; Plan §Design.5] {auto}
- [x] CHK010 - SC-001 e SC-002 sao verificaveis objetivamente (cenarios de teste, edicoes preservadas byte a byte)? [Mensurabilidade, Spec §SC-001/SC-002] {auto}

## Consistencia

- [x] CHK011 - O plan cobre todos os FR-001..FR-009 sem requisito orfao? [Consistencia, Plan §Design; coverage gate 9/9] {auto}
- [x] CHK012 - O Constitution Check do plan e consistente com FR-009 (nao-semente inalterado) e com o Principio VII? [Consistencia, Plan §Constitution Check] {auto}

## Cenarios e edge cases

- [x] CHK013 - Idempotencia (duas passagens) e template semente removido apos gravado estao cobertos? [Cobertura, Spec §Edge Cases] {auto}
- [x] CHK014 - A colisao `X.tmpl` x `X.semente.tmpl` tem comportamento definido (erro, exit 1)? [Cobertura, Spec §FR-005; Plan contracts/cli.md] {auto}
- [x] CHK015 - Semente com placeholder sem valor e destino inexistente: o exit/mensagem esperado esta explicito alem de "como nos demais templates"? [Ambiguity, Spec §FR-004] {auto} <!-- resolvido: spec.md FR-004 -->
- [x] CHK016 - Esta definido o comportamento de semente cujo diretorio-pai nao existe ou e arquivo (destino nao existe, mas gravar falha)? [Gap, Spec §FR-002] {auto} <!-- resolvido: spec.md Edge Cases -->

## Dependencias e premissas

- [x] CHK017 - A premissa "recusa de lote e manifesto de orfas ja existentes" esta referenciada ao contrato base? [Assumption, Plan contracts/cli.md Base] {auto}
- [x] CHK018 - Deve a ausencia de migracao para projetos pre-cockpit (semente existente sem entrada no manifesto nunca ganhar entrada) ser aceita como definitiva pelo dono do produto? [Assumption, Spec §Clarifications] {humano} <!-- aceito pelo owner em 2026-10-01 -->
- [x] CHK019 - O escopo "fora de escopo" (sem merge de semente existente) reflete o apetite do produto, dado que o dono perde atualizacoes futuras dos templates? [Risco, Spec §Fora de escopo] {humano} <!-- aceito pelo owner em 2026-10-01 -->

## Notes

- {auto} resolvidos [x] com citacao; CHK015/CHK016 sao gaps (viram tarefas de requisito/teste em create-tasks).
- Gate requirement-coverage: requirements=9 covered=9 errors=0.
- {humano} CHK018/CHK019 aceitos pelo owner em 2026-10-01, como estao na spec.
