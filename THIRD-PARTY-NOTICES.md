# Aviso de dependências de terceiros

Este repositório (o cockpit) compõe ferramentas de terceiros (`cstk`,
`context-mode`, `ponytail`) sem reimplementá-las nem embuti-las — cada uma é
instalada pela própria pessoa, pelo canal oficial dela (Princípio IV da
`docs/constitution.md`). A única exceção — a única cópia de código de
terceiro que este repositório de fato versiona — é a skill abaixo.

---

## `bmad-code-review`

| Campo | Valor |
|---|---|
| Nome do projeto de origem | BMAD-METHOD |
| Repositório | <https://github.com/bmad-code-org/BMAD-METHOD> |
| Licença | MIT (com nota de marca registrada adicional) |
| Skill copiada | `skills/bmad-code-review/` (`SKILL.md`, `customize.toml`, `steps/*.md`) — cópia integral, sem mudança de comportamento |

### Texto da licença (verbatim, arquivo `LICENSE` oficial do repositório de origem, branch `main`)

```
MIT License

Copyright (c) 2025 BMad Code, LLC

This project incorporates contributions from the open source community.
See [CONTRIBUTORS.md](CONTRIBUTORS.md) for contributor attribution.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

TRADEMARK NOTICE:
BMad™, BMad Method™, and BMad Core™ are trademarks of BMad Code, LLC, covering all
casings and variations (including BMAD, bmad, BMadMethod, BMAD-METHOD, etc.). The use of
these trademarks in this software does not grant any rights to use the trademarks
for any other purpose. See [TRADEMARK.md](TRADEMARK.md) for detailed guidelines.
```

Fonte: <https://raw.githubusercontent.com/bmad-code-org/BMAD-METHOD/main/LICENSE>,
consultada via `context-mode` (`ctx_fetch_and_index`), conforme o Princípio V da
`docs/constitution.md` ("Fonte Oficial Antes de Afirmar").
