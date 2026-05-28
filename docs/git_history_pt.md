# Historico Git e Organizacao do Projeto

Este documento resume como ler o historico Git do projeto depois do primeiro
checkpoint funcional com Tetris em hardware.

## Regra principal

A branch oficial do projeto e:

```text
main
```

A `main` deve ser lida como a linha cronologica principal do desenvolvimento.
Ela contem os checkpoints relevantes em ordem, desde a infraestrutura inicial
ate o primeiro jogo comercial no-MBC renderizado em hardware.

Branches com prefixo `codex/` foram usadas como branches temporarias de
desenvolvimento. Depois que o conteudo foi integrado na `main`, elas deixam de
ser a referencia principal.

## Linha do tempo resumida

| Tag | Commit | Marco |
| --- | --- | --- |
| `v0.0-infra` | `8d6460a` | Infraestrutura inicial do projeto, estrutura RTL/tb/docs e base Quartus |
| `v0.1-cpu-smoke` | `202fa47` | Primeiro checkpoint CPU + barramento + video smoke |
| `v0.2-cpu-tests` | `acb7991` | CPU validada localmente com a suite Blargg/timing principal |
| `v0.3-ppu-foundation` | `b398e96` | Primeira base de PPU, modos, LCDC e bloqueio inicial de VRAM |
| `v0.4-sprites-window-input` | `c145c95` | Sprites, Window, Joypad, PS/2 e entrada fisica inicial |
| `v0.5-resource-optimization` | `5e57e16` | Otimizacao importante de recursos com HRAM inferida em block RAM |
| `v0.6-sdram-loader` | `f9c7b89` | Base de SDRAM e loader via Virtual JTAG |
| `v0.7-sdram-video` | `22fee2c` | Top integrado SDRAM -> CPU -> PPU -> framebuffer -> VGA |
| `v0.8-vblank-scroll` | `fb6f5aa` | ROM propria usando VBlank interrupt para atualizar scroll |
| `v1.0-tetris-checkpoint` | `86867b9` | Primeiro checkpoint com ROM comercial: Tetris renderizado em hardware |

## Como visualizar a evolucao

Para ver a historia principal em ordem:

```text
git log --first-parent --oneline --reverse main
```

Para ver a arvore com tags e branches:

```text
git log --graph --decorate --oneline --all
```

Para listar somente os marcos:

```text
git tag --list --sort=creatordate
```

## Politica recomendada daqui para frente

1. Manter `main` sempre como estado estavel/documentado.
2. Criar branches temporarias para novas fatias:

```text
codex/<nome-da-fatia>
```

3. Integrar na `main` apenas depois de:

- simular a fatia relevante;
- rodar build Quartus quando houver mudanca de RTL/top;
- atualizar documentacao;
- registrar recursos quando houver impacto de sintese;
- criar commit com mensagem em ingles.

4. Criar tags apenas para checkpoints de marco, nao para todo commit.

## Estado atual

O estado atual da `main` representa o primeiro checkpoint funcional com Tetris:

- ROM comercial no-MBC de 32 KiB carregada na SDRAM via USB-Blaster/Virtual
  JTAG;
- CPU buscando instrucoes da SDRAM;
- PPU/framebuffer/VGA renderizando a tela inicial do Tetris;
- APU ainda fora do escopo;
- proximos testes recomendados: entrada no menu, inicio de partida e
  estabilidade durante gameplay.
