# Controle Central do Projeto Game Boy FPGA

Este documento é o ponto central de orientação do projeto
`gameboy-fpga-core`. Ele deve ser lido no início de qualquer nova conversa,
branch, sessão de implementação ou revisão técnica relacionada ao projeto.

O objetivo deste arquivo é preservar o fio da meada: o que já funciona, o que
está em construção, quais decisões foram tomadas, quais são os próximos alvos e
como cada frente do projeto se conecta às outras.

## 1. Identidade do Projeto

- Projeto: `gameboy-fpga-core`
- Autor: Rafael Siqueira de Oliveira
- Objetivo: recriar em hardware, usando VHDL sintetizável, o Nintendo Game Boy
  DMG-01.
- Natureza: reimplementação de hardware, não emulador de software.
- Plataforma alvo: OMDAZZ RZ-EasyFPGA A2.2 com Altera Cyclone IV EP4CE6.
- Ferramenta alvo: Quartus II 13.0 SP1.
- Simulação: ModelSim-Altera.
- Linguagem técnica principal do repositório: inglês.
- Documentos didáticos em português: permitidos quando explicitamente criados
  para acompanhamento, planejamento e estudo.

## 2. Regra de Uso Deste Documento

Sempre que uma nova conversa ou nova frente de trabalho for aberta, iniciar com
uma instrução equivalente a:

```text
Leia docs/project_control_pt.md antes de agir. Use este arquivo como estado
central do projeto.
```

Ao final de uma fatia relevante, este documento deve ser atualizado com:

- o novo estado do projeto;
- os testes executados;
- as limitações ainda abertas;
- o próximo alvo recomendado;
- qualquer decisão arquitetural importante.

Este arquivo não substitui os documentos técnicos em inglês. Ele é o mapa de
navegação do projeto.

## 3. Estado Atual Resumido

O projeto já possui:

- infraestrutura inicial de Quartus e ModelSim;
- VGA funcional em hardware real usando a placa OMDAZZ e conversor VGA-HDMI;
- framebuffer funcional exibido em monitor;
- top de smoke visual com CPU escrevendo no framebuffer;
- display de sete segmentos validado, com correção da ordem invertida dos
  dígitos observada em hardware;
- CPU LR35902 inicial, multi-ciclo, dividida em módulos;
- registradores A, F, B, C, D, E, H, L, SP e PC;
- ALU inicial com flags Z, N, H e C;
- decoder inicial;
- barramento inicial extraído para `bus_controller.vhd`;
- VRAM inicial real de 8 KiB em `0x8000..0x9FFF`;
- primeiro caminho PPU -> framebuffer implementado para background estático por
  tiles;
- primeiro caminho integrado CPU -> VRAM -> PPU -> framebuffer implementado;
- primeiro caminho integrado CPU -> VRAM -> PPU -> framebuffer -> VGA validado
  em hardware real com padrão de tiles visível no monitor;
- fluxo de ROMs de teste visuais extraído do barramento para módulos ROM
  dedicados;
- `SCX` e `SCY` conectados ao renderer de background;
- renderer de background reorganizado com progressão explícita por scanlines
  visíveis;
- `LY` e `STAT` mínimos conectados à progressão de scanline da PPU;
- scheduler inicial de modos da PPU conectado ao campo de modo de `STAT`;
- primeira geração de interrupções VBlank/STAT a partir do scheduler da PPU;
- scheduler de PPU refinado com contador lógico de dots por scanline:
  456 dots por linha, Mode 2 em `0..79`, Mode 3 em `80..251`, Mode 0 em
  `252..455` e Mode 1 durante VBlank;
- primeiro comportamento de `LCDC` bit 7: o barramento expõe `ppu_lcd_enable`,
  `LY/STAT` são mascarados para linha zero/Mode 0 quando o LCD está desligado,
  e o renderer permanece inativo com contador zerado;
- primeiro bloqueio de acesso CPU a VRAM durante Mode 3, enquanto o LCD está
  ligado;
- OAM inicial exposta em `0xFE00..0xFE9F`, com bloqueio de acesso CPU durante
  Mode 2/3 quando o LCD está ligado;
- primeiro OAM scan da PPU implementado, lendo OAM pelo lado da PPU e
  identificando ate 10 candidatos por scanline, ainda sem renderizar sprites;
- primeira fatia de sprite pixel fetch/composition implementada, consumindo o
  primeiro candidato do OAM scan, buscando tile de sprite e compondo pixels
  OBJ nao-zero sobre o background via `OBP0`;
- renderer de background em loop contínuo de frames enquanto `LCDC(7)` está
  ligado, com `done` convertido em pulso de fim de frame;
- WRAM completa de 8 KiB com leitura registrada;
- HRAM e stubs de I/O;
- IE e IF básicos;
- timer DMG inicial extraído para `rtl/io/timer.vhd`, com DIV/TIMA/TMA/TAC,
  seleção por TAC e pulso de interrupção de timer;
- serial debug stub em `0xFF01` e `0xFF02`;
- runner de ROM em simulação carregando ROMs `.gb` reais e emitindo `Passed`
  via serial;
- pacote local de ROMs Blargg baixado em `gb-test-roms-master`;
- Blargg `cpu_instrs` individuais `01`, `02`, `03`, `04`, `05`, `06`, `07`,
  `08`, `09`, `10` e `11` passando via transcript serial;
- Blargg `instr_timing.gb` passando via transcript serial no runner real.
- Blargg `mem_timing` individual e agregado passando via transcript serial.
- Blargg `mem_timing-2` individual e agregado passando via status de memória
  em `0xA000`;
- Blargg `interrupt_time.gb` passando no runner real.
- Blargg `halt_bug.gb` passando no runner real.

## 4. Checkpoints Confiáveis

Checkpoint conhecido:

- Commit: `202fa47`
- Mensagem: `Checkpoint M3 CPU video smoke and initial bus`
- Significado: checkpoint funcional de CPU + vídeo smoke + barramento inicial.

Checkpoint atual:

- Commit: ver o commit `Checkpoint M3 interrupt Blargg test` no histórico Git.
- Mensagem: `Checkpoint M3 interrupt Blargg test`
- Significado: checkpoint funcional de M3 com despacho inicial real de
  interrupções, Blargg `02-interrupts.gb` passando em simulação, regressões
  principais preservadas e build Quartus completo sem erros.

Checkpoint mais recente:

- Commit: `acb7991`
- Mensagem: `Checkpoint local CPU timing Blargg suite`
- Significado: fechamento da escada local de CPU/timing do Blargg com
  `cpu_instrs`, `instr_timing`, `mem_timing`, `mem_timing-2`,
  `interrupt_time` e `halt_bug` passando.

Depois do checkpoint `202fa47`, foram feitas expansões importantes agora
consolidadas no checkpoint atual:

- WRAM inicial e I/O stubs;
- expansão de opcodes da CPU;
- `INC (HL)` e `DEC (HL)`;
- `LDH (n),A`;
- `LDH A,(n)`;
- `LD (nn),A`;
- `LD A,(nn)`;
- serial debug stub;
- `tb_cpu_rom_runner`;
- carga de ROM `.gb` real no runner;
- máscara de boot em simulação para permitir ROMs com handlers em
  `0x0000..0x00FF`;
- timeout parametrizável para ROMs Blargg longas;
- scripts dedicados de wave e dos testes Blargg `01-special`, `09-op r,r`,
  `10-bit ops` e `11-op a,(hl)`;
- documentação de progressão e plano Blargg.

Antes de qualquer nova tag ou milestone formal, revisar novamente o estado do
Git e decidir se este checkpoint já deve receber uma tag parcial.

Sessão atual em andamento, ainda sem checkpoint:

- extraído um módulo `rtl/io/timer.vhd` para substituir o stub de timer duplicado
  no runner e no barramento;
- adicionado `tb/io/tb_timer.vhd` e `sim/modelsim/run_timer.do`;
- `tb_cpu_rom_runner` passou a carregar até 64 KiB, permitindo executar a ROM
  agregada `cpu_instrs.gb`;
- adicionado modo `G_VERBOSE_SERIAL` ao runner para evitar logs enormes em
  testes longos;
- adicionado suporte mínimo a `STOP` como instrução de dois bytes, apenas para
  permitir que a ROM agregada prossiga; o comportamento real de STOP ainda não
  foi implementado;
- adicionados scripts individuais para Blargg `03`, `04`, `05`, `06`, `07` e
  `08`;
- a ROM agregada `cpu_instrs.gb` foi testada como experimento longo: depois do
  suporte mínimo a `STOP`, ela avançou sem falha imediata e chegou pelo menos a
  `29:ok`, mas foi interrompida por tempo de simulação. Ela fica classificada
  como teste longo opcional, não como regressão diária.
- a primeira fatia de fidelidade temporal foi criada com fast paths de fetch,
  `S_JR_TAKEN` e a sonda local `tb_cpu_timing_probe`;
- a reorganização inicial do controle de execução foi concluída: a roteirização
  de loads por endereço de registrador passou a usar predicados compartilhados,
  e os corpos redundantes de instruções já resolvidas no fetch foram removidos
  de `S_DECODE`;
- uma tentativa de roteirização genérica de `LD_MEM` por metadados do decoder
  foi rejeitada após quebrar o fluxo de cópia para WRAM usado pelas ROMs Blargg.
- a primeira falha real de `instr_timing.gb` foi corrigida na fronteira
  CPU/barramento/timer: leituras de TIMA agora enxergam o incremento normal
  visível ao fim do ciclo M, preservando o atraso separado de overflow.
- `mem_timing` foi promovido para regressão real do Blargg: os três individuais
  e a ROM agregada alcançam `Passed`.
- `mem_timing-2` foi promovido para regressão real do Blargg: os três
  individuais e a ROM agregada alcançam `Passed` via protocolo de status em
  memória.
- `interrupt_time.gb` foi promovido para regressão real do Blargg e alcança
  `Passed`, confirmando os 13 ciclos esperados pelo teste.
- `halt_bug.gb` também alcança `Passed` no runner atual.
- a primeira fatia da fase seguinte começou com VRAM real de 8 KiB em
  `0x8000..0x9FFF`, preservando o framebuffer experimental em `0xA000..0xBFFF`
  apenas para o smoke visual atual;
- `rtl/ppu/ppu_background_renderer.vhd` passou a consumir a porta de leitura da
  VRAM e gerar um background estático por tiles;
- `rtl/top/ppu_background_demo_top.vhd` passou a ser o top visual da fase atual,
  ligando loader de demonstração, barramento, VRAM, PPU mínima, framebuffer e
  VGA.
- `rtl/top/cpu_ppu_background_demo_top.vhd` integra CPU e PPU: a CPU escreve
  tile data e tile map em VRAM, sinaliza conclusão em `0xFF80`, e só então a PPU
  renderiza;
- o mesmo top foi validado em hardware real: borda preta, área central clara e
  primeira faixa alternando tiles brancos e quadriculados.
- `bus_controller.vhd` deixou de possuir o conteúdo dos programas de integração;
  agora ele recebe `rom_data`, enquanto `cpu_video_smoke_rom.vhd` e
  `cpu_ppu_background_demo_rom.vhd` guardam os programas específicos.
- `cpu_ppu_background_demo_rom.vhd` agora escreve `SCY=1` e `SCX=8` antes de
  liberar o renderer, tornando a imagem dependente de registradores LCD reais.
- `ppu_background_renderer.vhd` agora possui estados explícitos de início e fim
  de linha, expondo `current_line`, `line_active` e `line_done` para preparar
  LY/STAT, VBlank e modos reais da PPU em etapas futuras.
- `bus_controller.vhd` agora lê `LY` a partir de `current_line` e calcula um
  `STAT` mínimo com bits graváveis, coincidência `LY=LYC` e modo provisório de
  linha ativa.
- `ppu_background_renderer.vhd` agora emite `ppu_mode` explicitamente, cobrindo
  os modos 2, 3, 0 e 1 de forma determinística no nível de linha;
- `bus_controller.vhd` deixou de inferir o modo de `STAT` por linha ativa e
  passou a rotear o modo recebido da PPU.
- `bus_controller.vhd` agora solicita IF bit 0 na entrada inicial de VBlank e
  IF bit 1 nas condições STAT habilitadas: Mode 0, Mode 1, Mode 2 e
  coincidência `LY=LYC`.

Validação rápida executada nesta sessão:

- `run_timer.do` — Passed;
- `run_bus_controller.do` — Passed;
- `run_cpu_blargg_02.do` — Passed com o timer novo;
- `run_cpu_blargg_03.do` — Passed;
- `run_cpu_blargg_04.do` — Passed;
- `run_cpu_blargg_05.do` — Passed;
- `run_cpu_blargg_06.do` — Passed;
- `run_cpu_blargg_08.do` — Passed;
- rodada longa iniciada com `run_cpu_blargg_01.do` — Passed;
- `run_cpu_blargg_02.do` — Passed na rodada longa;
- `run_cpu_blargg_07.do` — Passed na rodada longa;
- `run_cpu_blargg_09.do` — Passed na rodada longa;
- `run_cpu_blargg_10.do` — Passed na rodada longa;
- `run_cpu_blargg_11.do` — Passed na rodada longa;
- `run_cpu_video_smoke_top.do` — Passed;
- `run_cpu_timing_probe.do` — Passed;
- `run_cpu_instr_timing.do` — Passed;
- `run_cpu_mem_timing_01.do` — Passed;
- `run_cpu_mem_timing_02.do` — Passed;
- `run_cpu_mem_timing_03.do` — Passed;
- `run_cpu_mem_timing.do` — Passed;
- `run_cpu_mem_timing_aggregate.do` — Passed;
- `run_cpu_mem_timing2_01.do` — Passed;
- `run_cpu_mem_timing2_02.do` — Passed;
- `run_cpu_mem_timing2_03.do` — Passed;
- `run_cpu_mem_timing2.do` — Passed;
- `run_cpu_mem_timing2_aggregate.do` — Passed;
- `run_cpu_interrupt_time.do` — Passed;
- `run_cpu_halt_bug.do` — Passed;
- `run_cpu_timer_blargg_probe.do` — diagnóstico concluído com `LD BC,nn = 3`;
- `run_vram.do` — Passed;
- `run_ppu_background_renderer.do` — Passed;
- `run_ppu_background_demo_top.do` — Passed;
- `run_cpu_ppu_background_demo_top.do` — Passed;
- extração das ROMs de integração — validada mantendo `run_bus_controller.do`,
  `run_cpu_video_smoke_top.do`, `run_ppu_background_demo_top.do` e
  `run_cpu_ppu_background_demo_top.do` funcionais;
- suporte inicial a `SCX`/`SCY` — validado por `run_ppu_background_renderer.do`,
  `run_bus_controller.do`, `run_ppu_background_demo_top.do` e
  `run_cpu_ppu_background_demo_top.do`;
- reorganização inicial por scanlines — validada por
  `run_ppu_background_renderer.do`, `run_bus_controller.do`,
  `run_ppu_background_demo_top.do` e `run_cpu_ppu_background_demo_top.do`;
- `LY/STAT` mínimo — validado por `run_bus_controller.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do`, `run_cpu_timing_probe.do` e
  `run_cpu_instr_timing.do`;
- scheduler inicial de modos da PPU — validado por `run_ppu_background_renderer.do`,
  `run_bus_controller.do`, `run_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do`,
  `run_cpu_ppu_background_demo_top.do`, `run_cpu_timing_probe.do` e
  `run_cpu_instr_timing.do`;
- interrupções iniciais VBlank/STAT — validadas por `run_bus_controller.do`,
  `run_ppu_background_renderer.do`, `run_ppu_background_demo_top.do`,
  `run_cpu_ppu_background_demo_top.do`, `run_cpu_video_smoke_top.do`,
  `run_timer.do`, `run_cpu_timing_probe.do`, `run_cpu_instr_timing.do`,
  `run_cpu_interrupt_time.do` e `run_cpu_halt_bug.do`;
- scheduler por dots da PPU — validado por `run_ppu_background_renderer.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_bus_controller.do`, `run_cpu_video_smoke_top.do`, `run_timer.do`,
  `run_cpu_instr_timing.do`, `run_cpu_interrupt_time.do` e
  `run_cpu_halt_bug.do`;
- comportamento inicial de `LCDC` enable — validado por
  `run_ppu_background_renderer.do`, `run_bus_controller.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do`, `run_cpu_instr_timing.do`,
  `run_cpu_interrupt_time.do` e `run_cpu_halt_bug.do`;
- bloqueio inicial de acesso CPU a VRAM durante Mode 3 — validado por
  `run_bus_controller.do`, `run_ppu_background_renderer.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do`, `run_cpu_instr_timing.do`,
  `run_cpu_interrupt_time.do` e `run_cpu_halt_bug.do`;
- OAM inicial com bloqueio CPU durante Mode 2/3 — validada por
  `run_bus_controller.do`, `run_ppu_background_demo_top.do`,
  `run_cpu_ppu_background_demo_top.do`, `run_cpu_video_smoke_top.do`,
  `run_timer.do`, `run_cpu_instr_timing.do`, `run_cpu_interrupt_time.do` e
  `run_cpu_halt_bug.do`;
- loop contínuo de frames da PPU — validado por
  `run_ppu_background_renderer.do`, `run_bus_controller.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do`, `run_cpu_instr_timing.do`,
  `run_cpu_interrupt_time.do` e `run_cpu_halt_bug.do`;
- lookup de paleta `BGP` no write do framebuffer — validado por
  `run_ppu_background_renderer.do`, `run_bus_controller.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_video_smoke_top.do` e
  `run_cpu_ppu_background_demo_top.do`;
- controles iniciais de background por `LCDC` — validados por
  `run_ppu_background_renderer.do`, `run_bus_controller.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_video_smoke_top.do` e
  `run_cpu_ppu_background_demo_top.do`;
- build Quartus completo em `2026-05-16` — Passed, com `4.283 / 6.272` LEs
  usados (`68%`) e temporização fechada após o checkpoint de timing Blargg.
- build Quartus completo da primeira fatia de VRAM em `2026-05-16` — Passed,
  com `4.290 / 6.272` LEs usados (`68%`), `177.152 / 276.480` bits de memória
  (`64%`) e `22 / 30` blocos M9K usados (`73%`).
- build Quartus completo do `ppu_background_demo_top` em `2026-05-16` —
  Passed, com `405 / 6.272` LEs usados (`6%`), `111.616 / 276.480` bits de
  memória (`40%`) e `14 / 30` blocos M9K usados (`47%`). Este top é parcial e
  não inclui a CPU/WRAM completas, portanto não substitui o custo do top de
  sistema.
- build Quartus completo do `cpu_ppu_background_demo_top` em `2026-05-16` —
  Passed, com `4.235 / 6.272` LEs usados (`68%`), `177.152 / 276.480` bits de
  memória (`64%`) e `22 / 30` blocos M9K usados (`73%`).
- validação em hardware real do `cpu_ppu_background_demo_top` em `2026-05-16`
  — Passed visualmente no monitor VGA-HDMI com o padrão esperado de tiles.
- build Quartus completo após a extração das ROMs em `2026-05-17` — Passed,
  preservando `4.235 / 6.272` LEs usados (`68%`), `177.152 / 276.480` bits de
  memória (`64%`) e `22 / 30` blocos M9K usados (`73%`).
- build Quartus completo após `SCX`/`SCY` em `2026-05-18` — Passed, com
  `4.251 / 6.272` LEs usados (`68%`), `177.152 / 276.480` bits de memória
  (`64%`) e `22 / 30` blocos M9K usados (`73%`).
- build Quartus completo após a reorganização por scanlines em `2026-05-19` —
  Passed, com `4.271 / 6.272` LEs usados (`68%`), `177.152 / 276.480` bits de
  memória (`64%`) e `22 / 30` blocos M9K usados (`73%`).
- build Quartus completo após `LY/STAT` mínimo em `2026-05-19` — Passed, com
  `4.283 / 6.272` LEs usados (`68%`), `177.152 / 276.480` bits de memória
  (`64%`) e `22 / 30` blocos M9K usados (`73%`).
- build Quartus completo após o scheduler inicial de modos da PPU em
  `2026-05-19` — Passed, com `4.300 / 6.272` LEs usados (`69%`),
  `177.152 / 276.480` bits de memória (`64%`) e `22 / 30` blocos M9K usados
  (`73%`).
- build Quartus completo após as interrupções iniciais VBlank/STAT em
  `2026-05-20` — Passed, com `4.324 / 6.272` LEs usados (`69%`),
  `177.152 / 276.480` bits de memória (`64%`) e `22 / 30` blocos M9K usados
  (`73%`).
- build Quartus completo após o scheduler por dots da PPU em `2026-05-20` —
  Passed, com `4.342 / 6.272` LEs usados (`69%`),
  `177.152 / 276.480` bits de memória (`64%`) e `22 / 30` blocos M9K usados
  (`73%`).
- build Quartus completo após o comportamento inicial de `LCDC` enable em
  `2026-05-20` — Passed, com `4.362 / 6.272` LEs usados (`70%`),
  `177.152 / 276.480` bits de memória (`64%`) e `22 / 30` blocos M9K usados
  (`73%`).
- build Quartus completo após o bloqueio inicial de VRAM em Mode 3 em
  `2026-05-20` — Passed, com `4.361 / 6.272` LEs usados (`70%`),
  `177.152 / 276.480` bits de memória (`64%`) e `22 / 30` blocos M9K usados
  (`73%`).
- build Quartus completo após a OAM inicial em `2026-05-20` — Passed, com
  `4.344 / 6.272` LEs usados (`69%`), `179.200 / 276.480` bits de memória
  (`65%`) e `23 / 30` blocos M9K usados (`77%`).
- build Quartus completo após o loop contínuo de frames da PPU em
  `2026-05-20` — Passed, com `4.357 / 6.272` LEs usados (`69%`),
  `179.200 / 276.480` bits de memória (`65%`) e `23 / 30` blocos M9K usados
  (`77%`).
- build Quartus completo após o lookup de paleta `BGP` em `2026-05-20` —
  Passed, com `4.342 / 6.272` LEs usados (`69%`),
  `179.200 / 276.480` bits de memória (`65%`) e `23 / 30` blocos M9K usados
  (`77%`).
- build Quartus completo após os controles iniciais de background por `LCDC` em
  `2026-05-20` — Passed, com `4.382 / 6.272` LEs usados (`70%`),
  `179.200 / 276.480` bits de memória (`65%`) e `23 / 30` blocos M9K usados
  (`77%`).
- build Quartus completo após o primeiro OAM scan da PPU em `2026-05-20` —
  Passed, com `4.438 / 6.272` LEs usados (`71%`),
  `179.200 / 276.480` bits de memória (`65%`) e `23 / 30` blocos M9K usados
  (`77%`).
- build Quartus completo após a primeira fatia de sprite pixel
  fetch/composition em `2026-05-20` — Passed, com `4.551 / 6.272` LEs usados
  (`73%`), `179.200 / 276.480` bits de memória (`65%`) e `23 / 30` blocos M9K
  usados (`77%`).

Checkpoint pronto para formalização:

- a escada local de CPU/timing disponível no pacote Blargg foi concluída;
- o conjunto de regressão relevante está registrado acima;
- a primeira fatia real de PPU já está em andamento com scheduler por dots,
  LCDC enable inicial, bloqueio inicial de VRAM em Mode 3, OAM inicial e loop
  contínuo de frames;
- o `BGP` no write do framebuffer foi aplicado e validado;
- os controles iniciais de background por `LCDC` foram aplicados e validados;
- o primeiro OAM scan da PPU foi implementado e validado;
- a primeira fatia de sprite pixel fetch/composition foi implementada e
  validada;
- o próximo passo recomendado é expandir sprites para `OBP1`, prioridade,
  ordenação e mais de um candidato por linha, em cortes pequenos.

## 5. Estado Atual por Área

### CPU

Implementado:

- `NOP`
- `LD r,n`
- `LD r,r`
- `LD r,(HL)`
- `LD (HL),r`
- `LD rr,nn` para BC, DE, HL e SP
- `LD A,(BC)`
- `LD A,(DE)`
- `LD (BC),A`
- `LD (DE),A`
- `LD A,(HL+)`
- `LD A,(HL-)`
- `LD (HL+),A`
- `LD (HL-),A`
- `LD (HL),n`
- `LDH (n),A`
- `LDH A,(n)`
- `LDH (C),A`
- `LDH A,(C)`
- `LD (nn),A`
- `LD A,(nn)`
- `LD (nn),SP`
- `LD SP,HL`
- `LD HL,SP+e`
- `INC r`
- `DEC r`
- `INC (HL)`
- `DEC (HL)`
- `INC rr`
- `DEC rr`
- `ADD HL,rr`
- `ADD SP,e`
- `ADD A,r`
- `ADC A,r`
- `SUB r`
- `SBC A,r`
- `AND A,r`
- `OR A,r`
- `XOR A,r`
- `CP r`
- ALU imediata: `ADD/ADC/SUB/SBC/AND/XOR/OR/CP A,n`
- `ADD A,(HL)`
- `ADC A,(HL)`
- `SUB (HL)`
- `SBC A,(HL)`
- `AND A,(HL)`
- `OR A,(HL)`
- `XOR A,(HL)`
- `CP (HL)`
- `DAA`
- despacho inicial real de interrupções com IME, IE/IF, prioridade, push de PC,
  salto para vetor, `interrupt_ack` e `RETI`
- `JP nn`
- `JP cc,nn`
- `JP HL`
- `JR e`
- `JR cc,e`
- `CALL nn`
- `CALL cc,nn`
- `RET`
- `RET cc`
- `RETI`
- `RST 00h/08h/10h/18h/20h/28h/30h/38h`
- `PUSH BC/DE/HL/AF`
- `POP BC/DE/HL/AF`
- `RLCA`
- `RRCA`
- `RLA`
- `RRA`
- `CPL`
- `SCF`
- `CCF`
- CB-prefix em registradores para RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL, BIT, RES e
  SET
- CB-prefix em `(HL)` para RLC/RRC/RL/RR/SLA/SRA/SWAP/SRL, BIT, RES e SET
- `DI`
- `EI` com atraso básico
- `HALT` básico com saída por interrupção pendente
- `STOP` mínimo para avanço de PC, sem modo stop real

Ainda pendente:

- temporização exata de aceitação de interrupções;
- temporização exata de instruções;
- timer real com frequências TAC, atraso de overflow e bordas fiéis ao DMG;
- refinamento de escala de ciclo do timer contra a temporização exata da CPU;
- comportamento completo do bug de `HALT`.
- comportamento real de `STOP`.

### Barramento e Memória

Implementado:

- ROM interna temporária em simulação/top smoke;
- VRAM real de 8 KiB em `0x8000..0x9FFF`;
- janela experimental de framebuffer mantida separadamente em `0xA000..0xBFFF`
  para o smoke visual legado;
- WRAM completa de 8 KiB em `0xC000..0xDFFF`, com leitura registrada;
- espelho de WRAM em `0xE000..0xFDFF`;
- HRAM em `0xFF80..0xFFFE`;
- overlay temporário de debug em `0xFF80` e `0xFF81`;
- handshake `mem_ready`/`cpu_ready` entre CPU e barramento para wait states de memória;
- stubs de JOYP, serial, timer, LCD/PPU, DMA e paletas;
- IE em `0xFFFF`;
- IF em `0xFF0F`;
- serial debug em `0xFF01/0xFF02`;
- timer inicial compartilhado capaz de gerar IF bit 2 em simulação e no
  barramento inicial;
- limpeza de IF por `interrupt_ack` conforme vetor atendido.

Risco atual:

- A WRAM agora é inferida como `altsyncram`, mas a HRAM pequena ainda fica como
  lógica local por causa do tamanho reduzido e dos overlays temporários de
  debug.
- O próximo crescimento de memória deve manter o padrão de leitura registrada e
  wait states, evitando retornar a RAMs grandes combinacionais.
- A temporização de CPU ainda não é exata ciclo a ciclo do LR35902; o handshake
  atual é uma base arquitetural para crescer, não uma validação final de timing.

### Vídeo

Implementado:

- VGA 640x480 funcional;
- framebuffer 160x144 com escala para VGA;
- padrão visual validado em hardware;
- smoke top com CPU escrevendo pixels no framebuffer;
- primeiro produtor PPU mínimo lendo tile data e tile map da VRAM;
- top visual `ppu_background_demo_top` com integração VRAM -> PPU ->
  framebuffer -> VGA;
- top visual `cpu_ppu_background_demo_top` com integração CPU -> VRAM -> PPU ->
  framebuffer -> VGA;
- validação visual em hardware real do top integrado, confirmando que a imagem
  exibida já depende de conteúdo escrito pela CPU e lido pela PPU;
- progressão explícita por 144 scanlines visíveis no renderer de background;
- scheduler inicial por dots com 456 dots por linha;
- `LY` e `STAT` mínimos visíveis pela CPU;
- modos iniciais 2, 3, 0 e 1 visíveis em `STAT`;
- IF bit 0 solicitado na entrada de VBlank inicial;
- IF bit 1 solicitado por condições STAT habilitadas;
- loop contínuo de frames enquanto `LCDC(7)` está ligado;
- lookup de `BGP` no write do framebuffer;
- controles iniciais de background por `LCDC(3)`, `LCDC(4)` e `LCDC(0)`;
- primeiro OAM scan da PPU detectando ate 10 candidatos por scanline;
- primeira composição de sprite: um candidato, tile row fetch, pixels OBJ
  nao-zero sobre o background, paleta `OBP0`;
- display de sete segmentos mostrando `1234` em caso de sucesso.

Ainda pendente:

- PPU dot-accurate completa com fetcher/FIFO reais;
- scroll completo dentro do modelo temporal real da PPU;
- sprite composition completa: múltiplos candidatos, prioridade, ordenação e
  `OBP1`;
- window;
- VBlank dot-accurate e alinhado ao LCD real;
- STAT dot-accurate, com bloqueios e coincidência fiéis;
- DMA OAM.

### Testes

Implementado:

- testes de ALU;
- testes de registradores;
- testes de decoder;
- smoke test da CPU;
- smoke test CPU + vídeo;
- teste direto do `bus_controller`;
- runner de ROM real imprimindo `Passed` por serial;
- wave setup dedicado para visualizar o runner;
- scripts para Blargg `01-special`, `09-op r,r`, `10-bit ops` e
  `11-op a,(hl)`;
- script dedicado para Blargg `02-interrupts`;
- scripts individuais adicionados para `03`, `04`, `05`, `06`, `07` e `08`;
- teste unitário de timer em `tb/io/tb_timer.vhd`.

Blargg `cpu_instrs` individuais passando:

- `06-ld r,r.gb`
- `04-op r,imm.gb`
- `08-misc instrs.gb`
- `05-op rp.gb`
- `03-op sp,hl.gb`
- `01-special.gb`
- `07-jr,jp,call,ret,rst.gb`
- `09-op r,r.gb`
- `10-bit ops.gb`
- `11-op a,(hl).gb`
- `02-interrupts.gb`

Próximo alvo de teste:

- `instr_timing.gb` já foi iniciado;
- a primeira execução falhava ainda no autoteste do timer;
- depois da primeira correção de fast-path da CPU, a ROM passou pela calibração
  inicial e agora falha dentro da fase real de medição de opcodes;
- manter `mem_timing-2`, `interrupt_time` e `halt_bug` para depois de fechar o
  primeiro bloco de timing de instruções.
- a sonda local agora cobre também `LD (BC),A`, `LD A,(BC)`, `RLCA`,
  `LD (nn),SP`, `DAA`, `CPL`, `SCF`, `CCF` e `JR cc,e` tomado/não tomado.
- a reorganização do controle reduziu o custo da fatia de timing de
  `4.511 / 6.272` para `4.268 / 6.272` LEs sem perder os testes rápidos.

## 6. Linha de Evolução do Projeto

### Etapa Atual: Início de M5 com Base M3/M4 Preservada

Estamos na transição entre:

- M4: barramento e mapa de memória já utilizável;
- M5: primeira PPU real ainda mínima.

O foco imediato não é jogo ainda. O foco agora é fazer a PPU crescer de modo
verificável sem perder a base de CPU/timing que já foi conquistada.

O marco visual atual prova que os blocos já cooperam fisicamente no hardware:

```text
CPU -> barramento -> VRAM -> PPU -> framebuffer -> VGA
```

Ele ainda não prova uma PPU fiel ao DMG-01. O renderer já possui scroll básico
por `SCX`/`SCY`, progressão explícita por scanlines visíveis, scheduler inicial
por dots, modos 2/3/0/1, solicitações iniciais de VBlank/STAT, controles
iniciais de `LCDC`, lookup de `BGP`, primeiro OAM scan e primeira composição de
um sprite por linha via `OBP0`. Ainda não possui fetcher/FIFO real, composição
completa de múltiplos sprites, window, comportamento LCD completo ou DMA.

### Próxima Linha de Trabalho

1. Preservar a suíte Blargg de CPU/timing como regressão obrigatória.
2. Expandir sprite composition para prioridade, `OBP1` e múltiplos candidatos.
3. Atualizar documentação e recursos após cada corte verificável.

Depois disso:

1. refinar o timing dos modos da PPU;
2. adicionar window;
3. adicionar OAM/sprites;
4. implementar DMA;
5. retomar joypad e fluxo de ROM para começar a aproximar o sistema de ROMs
   gráficas reais.

## 7. Ordem Recomendada para Blargg

Ordem prática, considerando o estado atual do core:

1. `06-ld r,r.gb` — Passed
2. `04-op r,imm.gb` — Passed
3. `08-misc instrs.gb` — Passed
4. `05-op rp.gb` — Passed
5. `03-op sp,hl.gb` — Passed
6. `07-jr,jp,call,ret,rst.gb` — Passed
7. `09-op r,r.gb` — Passed com timeout longo parametrizado
8. `11-op a,(hl).gb` — Passed com timeout longo parametrizado
9. `10-bit ops.gb` — Passed com timeout longo parametrizado
10. `01-special.gb` — Passed
11. `02-interrupts.gb` — Passed com suporte inicial real de interrupções
12. `instr_timing.gb` — Passed depois do ajuste de visibilidade da TIMA
13. `mem_timing/individual/01-read_timing.gb` — Passed
14. `mem_timing/individual/02-write_timing.gb` — Passed
15. `mem_timing/individual/03-modify_timing.gb` — Passed
16. `mem_timing/mem_timing.gb` — Passed
17. `mem_timing-2/rom_singles/01-read_timing.gb` — Passed
18. `mem_timing-2/rom_singles/02-write_timing.gb` — Passed
19. `mem_timing-2/rom_singles/03-modify_timing.gb` — Passed
20. `mem_timing-2/mem_timing.gb` — Passed
21. `interrupt_time/interrupt_time.gb` — Passed
22. `halt_bug.gb` — Passed

Próximos grupos sensíveis:

- `oam_bug`;
- `dmg_sound`;
- `cgb_sound`.

`instr_timing.gb`, `mem_timing`, `mem_timing-2`, `interrupt_time.gb` e
`halt_bug.gb` já passaram depois da correção da fronteira CPU/barramento/timer,
do suporte ao status de memória do Blargg e da confirmação do caminho de
interrupção. Os demais grupos dependem de PPU/OAM ou APU, e pertencem às
próximas fases.

## 8. Dependências Principais

### Para rodar Blargg CPU

Necessário:

- runner carregando ROM real;
- PC iniciando corretamente em `0x0100`, ou simulação equivalente;
- ROM de 32 KiB mapeada em `0x0000..0x7FFF`;
- WRAM suficiente em simulação;
- HRAM;
- serial debug;
- opcodes do shell comum;
- stack funcional;
- flags confiáveis.

### Para testes visuais controlados pela CPU

Necessário:

- CPU executando programa próprio;
- barramento escrevendo no framebuffer;
- VGA funcional;
- programa de teste visual simples;
- checker por LED/display ou serial.

### Para PPU mínima

Necessário:

- VRAM;
- tile data;
- tile map;
- pipeline de pixels;
- integração com VGA/framebuffer;
- leitura de registradores LCD.

### Para jogos

Necessário:

- CPU muito mais completa;
- PPU mínima funcional;
- timer;
- joypad;
- interrupções;
- mapa de memória mais fiel;
- ROM loading;
- eventualmente SDRAM/MBC.

## 9. Regras de Trabalho

Cada fatia deve ter um alvo explícito.

Exemplo bom:

```text
Fazer cpu_instrs/individual/11-op a,(hl).gb avançar até Passed ou até a
primeira falha diagnosticável via serial.
```

Exemplo ruim:

```text
Implementar mais opcodes.
```

Toda fatia deve terminar com:

- resumo do que mudou;
- testes executados;
- resultado dos testes;
- impacto de recursos, se houve alteração sintetizável;
- limitações restantes;
- próximo alvo recomendado.

Para preservar material do futuro artigo/TCC, toda fatia relevante também deve
deixar um rastro publicável com:

- contexto;
- objetivo;
- decisão de projeto;
- implementação;
- verificação;
- resultado;
- lições aprendidas.

O modelo de registro está em `docs/base_artigo_tcc_pt.md`.

## 10. Uso de Subagentes

Subagentes podem ser usados, mas sempre com tarefas delimitadas.

Papéis recomendados:

- Analista de opcodes:
  - lê fontes Blargg;
  - compara com o decoder atual;
  - lista dependências mínimas.
- Infraestrutura de testes:
  - cuida do runner;
  - carrega ROMs;
  - captura serial;
  - implementa timeout e logs.
- Implementador de CPU:
  - implementa uma fatia pequena de opcodes aprovada.
- Verificador:
  - roda ModelSim;
  - revisa VHDL-1993;
  - checa bibliotecas proibidas;
  - roda Quartus quando necessário.
- Documentador:
  - atualiza este arquivo;
  - registra checkpoints e próximos passos.

Regra central:

Subagentes não decidem a arquitetura sozinhos. Eles produzem análise ou mudanças
pequenas. A integração e a decisão final ficam na conversa principal.

## 11. Como Dividir Conversas

Conversas recomendadas:

### Conversa-Mãe: Arquitetura e Controle

Uso:

- decisões de direção;
- revisão de roadmap;
- dúvidas conceituais;
- conexão entre CPU, bus, PPU, Blargg e hardware real.

### M3 CPU Blargg Bring-Up

Uso:

- runner de ROM;
- Blargg `cpu_instrs`;
- opcodes;
- flags;
- serial transcript.

### M4 Barramento e Memória

Uso:

- WRAM;
- HRAM;
- ROM;
- mapa de memória;
- wait states;
- otimização para EP4CE6.

### Testes Visuais

Uso:

- CPU desenhando no framebuffer;
- padrões visuais;
- VGA;
- validação em hardware.

### M5 PPU

Uso futuro:

- VRAM;
- tiles;
- tile map;
- sprites;
- VBlank;
- STAT;
- DMA.

## 12. Prompt Base para Novas Conversas

Usar este modelo ao iniciar uma nova conversa:

```text
Estamos trabalhando no projeto gameboy-fpga-core em
C:\Users\Rafael\Documents\Projetos\Vhdlboy.

Leia docs/project_control_pt.md antes de agir.

Regras principais:
- VHDL-1993.
- Quartus II 13.0 SP1.
- Usar apenas ieee.std_logic_1164 e ieee.numeric_std.
- Não usar std_logic_arith nem std_logic_unsigned.
- Considerar o limite do Cyclone IV EP4CE6.
- Código e documentação técnica do projeto em inglês.
- Documentos didáticos em português devem ter acentuação correta.

Foco desta conversa:
[descrever foco específico]

Alvo concreto:
[descrever alvo verificável]
```

## 13. Alvo Oficial Recém-Concluído

O alvo oficial anterior era:

```text
Refatorar o fast path de fetch para reduzir duplicação de lógica entre
`S_FETCH` e `S_DECODE`, preservando as famílias de timing já corrigidas antes
de expandir mais a cobertura de `instr_timing.gb`.
```

Resultado:

- a roteirização de `LD_MEM` passou a usar predicados pequenos compartilhados
  entre fetch e decode;
- a versão genérica baseada apenas em metadados do decoder foi descartada após
  causar regressão em ROM real;
- os corpos redundantes de `LD r,r`, `INC/DEC r`, `ALU r`, rotações do
  acumulador e controle de flags de 1 ciclo foram removidos de `S_DECODE`;
- `run_cpu_timing_probe.do`, `03`, `04`, `05`, `06`, `07`, `08`,
  `run_timer.do` e `run_cpu_video_smoke_top.do` continuaram passando;
- a síntese caiu de `4.511 / 6.272` para `4.268 / 6.272` LEs, recuperando 243
  LEs sem perder a cobertura temporal já conquistada.

## 14. Alvo Oficial Recém-Concluído

O alvo oficial recém-concluído foi:

```text
Evoluir o renderer de background de preenchimento único para uma organização por
scanlines, mantendo `SCX`/`SCY`, o fluxo explícito de ROM de teste e toda a
regressão já conquistada.
```

Critério de sucesso:

- manter `run_ppu_background_renderer.do` passando;
- manter `run_ppu_background_demo_top.do` passando;
- manter `run_cpu_ppu_background_demo_top.do` passando;
- manter `run_cpu_timing_probe.do` passando;
- manter `run_cpu_instr_timing.do` passando;
- manter `run_cpu_mem_timing.do` passando;
- manter `run_cpu_mem_timing2.do` passando;
- manter `run_cpu_interrupt_time.do` passando;
- manter `run_cpu_halt_bug.do` passando;
- manter os rápidos `03`, `04`, `05`, `06` e `08` passando;
- manter `run_timer.do` passando;
- manter `07-jr,jp,call,ret,rst.gb` passando;
- preservar `JR cc,e` em `2/3` ciclos para não tomado/tomado;
- preservar a porta dual de VRAM já inferida;
- manter o primeiro renderer restrito a background, sem sprites, window ou DMA;
- preservar `SCX`/`SCY` já ativos no cálculo de background;
- repetir a síntese e registrar o custo do top completo à medida que a PPU
  crescer.

Resultado:

- `ppu_background_renderer.vhd` agora possui estados explícitos de começo e fim
  de scanline;
- o renderer expõe `current_line`, `line_active` e `line_done`;
- o testbench unitário confirma 144 scanlines completas por render;
- os testes de pixel e scroll por `SCX`/`SCY` continuam passando;
- `run_ppu_background_renderer.do`, `run_bus_controller.do`,
  `run_ppu_background_demo_top.do` e `run_cpu_ppu_background_demo_top.do`
  passaram;
- `run_cpu_timing_probe.do`, `run_timer.do` e `run_cpu_instr_timing.do`
  também passaram como regressão de segurança;
- o build Quartus completo passou com `4.271 / 6.272` LEs, `177.152 / 276.480`
  bits de memória e `22 / 30` M9Ks.

Alvo seguinte concluído:

```text
Conectar a progressão por scanline a um modelo mínimo de registradores LY/STAT,
sem ainda implementar sprites, window, DMA ou modos dot-accurate completos.
```

Resultado:

- `LY` em `0xFF44` agora reflete `current_line` vindo da PPU;
- `STAT` em `0xFF41` preserva os bits graváveis 6..3, calcula a coincidência
  `LY=LYC` no bit 2 e expõe um modo provisório;
- o modo provisório é `3` enquanto a linha de background está ativa e `0` fora
  dela;
- `tb_bus_controller` valida `LY`, coincidência `LY=LYC`, modo ativo e modo
  inativo;
- as regressões rápidas de PPU, CPU/PPU, smoke visual, timer e
  `instr_timing.gb` passaram;
- o build Quartus completo passou com `4.283 / 6.272` LEs, `177.152 / 276.480`
  bits de memória e `22 / 30` M9Ks.

Alvo seguinte concluído:

```text
Substituir o modo provisório de `STAT` por um scheduler inicial de linha da PPU,
com fases visíveis, HBlank e VBlank mínimos, mantendo o caminho visual atual.
```

Critério de sucesso sugerido:

- preservar `LY` e `LYC`;
- reportar modos básicos 2, 3, 0 e 1 de forma determinística;
- gerar uma base para VBlank futuro sem ainda exigir sprites ou DMA;
- manter o padrão visual atual;
- manter `run_bus_controller.do`, `run_ppu_background_renderer.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do` e `run_cpu_instr_timing.do` passando;
- sintetizar e registrar custo antes de expandir para interrupções STAT reais.

Resultado:

- `ppu_background_renderer.vhd` agora emite `ppu_mode` como fonte explícita dos
  bits de modo de `STAT`;
- o renderer reporta Mode 2 no começo da linha visível, Mode 3 durante a
  renderização do background, Mode 0 no fim da linha visível e Mode 1 durante a
  faixa inicial de VBlank `144..153`;
- `bus_controller.vhd` passou a rotear `ppu_mode` diretamente para `STAT`, sem
  inferir o modo por `line_active`;
- `tb_bus_controller` valida os modos 0, 1, 2 e 3 em `STAT`;
- `tb_ppu_background_renderer` confirma que os quatro modos aparecem durante a
  renderização completa;
- as regressões rápidas de PPU, top integrado, smoke visual, timer e
  `instr_timing.gb` passaram;
- o build Quartus completo passou com `4.300 / 6.272` LEs, `177.152 / 276.480`
  bits de memória e `22 / 30` M9Ks.

Limitação importante:

- este scheduler ainda é de nível de linha, não de nível de dot. Ele cria a
  fonte correta para o barramento e para os próximos testes, mas ainda não
  representa os 80 dots de Mode 2, a janela variável de Mode 3 nem o HBlank
  restante com precisão de hardware real.

Alvo seguinte concluído:

```text
Usar o scheduler inicial de modos da PPU para implementar a base de VBlank e
STAT interrupt: IF bit 0 no início do VBlank, condições iniciais de STAT
selecionadas pelos bits 6..3, e testes controlados sem alterar o visual atual.
```

Critério de sucesso sugerido:

- levantar IF bit 0 quando `LY` entra em 144;
- manter `LY`, `LYC` e o campo de modo de `STAT` funcionando;
- implementar a primeira versão de solicitações STAT para Mode 0, Mode 1,
  Mode 2 e coincidência `LY=LYC`;
- manter o padrão visual atual;
- preservar as regressões Blargg de CPU/timing como teste de segurança;
- manter `run_bus_controller.do`, `run_ppu_background_renderer.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do` e `run_cpu_instr_timing.do`
  passando;
- sintetizar e registrar custo antes de avançar para timing por dot.

Resultado:

- `bus_controller.vhd` agora detecta a borda de entrada em VBlank inicial e
  seta IF bit 0;
- as condições STAT habilitadas por bits 6..3 agora setam IF bit 1 para
  coincidência `LY=LYC`, Mode 2, Mode 1 e Mode 0;
- a solicitação STAT é detectada por borda da condição combinada, evitando
  rearme imediato quando a CPU reconhece a interrupção enquanto a condição
  continua ativa;
- `tb_bus_controller` valida VBlank, acknowledge sem rearme, Mode 0, Mode 1,
  Mode 2 e coincidência `LY=LYC`;
- as regressões rápidas de PPU, top integrado, smoke visual, timer,
  `instr_timing.gb`, `interrupt_time.gb` e `halt_bug.gb` passaram;
- o build Quartus completo passou com `4.324 / 6.272` LEs, `177.152 / 276.480`
  bits de memória e `22 / 30` M9Ks.

Limitação importante:

- esta ainda é uma base de interrupções em nível de linha. A geração ocorre a
  partir do scheduler atual da PPU, que ainda não modela duração real de Mode 2,
  duração variável de Mode 3, HBlank restante por dot, LCD enable ou os detalhes
  finos de bloqueio de STAT do hardware original.

Alvo seguinte concluído:

```text
Refinar a PPU de scheduler por linha para um scheduler por dots, mantendo o
contrato atual de LY/STAT/IF e preservando o padrão visual CPU -> VRAM -> PPU.
```

Critério de sucesso sugerido:

- introduzir contador de dots por scanline;
- manter 456 dots por linha como base arquitetural;
- preservar Mode 2, Mode 3, Mode 0 e Mode 1 no campo `STAT`;
- manter VBlank em `LY=144..153`;
- preservar IF bit 0 e IF bit 1 já implementados;
- não adicionar sprites, window ou DMA nesta fatia;
- manter as regressões visuais e Blargg de CPU/timing passando;
- sintetizar e registrar custo antes de avançar para OAM/sprites.

Resultado:

- `ppu_background_renderer.vhd` agora possui um contador lógico de dots de
  `0..455` por scanline;
- o renderer expõe `current_dot` para testbenches e futuras sondas;
- Mode 2 cobre os dots `0..79` das linhas visíveis;
- Mode 3 cobre os dots `80..251` das linhas visíveis;
- Mode 0 cobre os dots `252..455` das linhas visíveis;
- Mode 1 cobre as linhas `144..153`, também com contagem de `0..455`;
- o caminho visual CPU -> VRAM -> PPU -> framebuffer -> VGA foi preservado;
- VBlank/STAT/IF continuam passando pelo contrato existente do barramento;
- o build Quartus completo passou com `4.342 / 6.272` LEs,
  `177.152 / 276.480` bits de memória e `22 / 30` M9Ks.

Limitação importante:

- o contador de dots já estabelece a estrutura temporal observável para
  `LY/STAT/IF`, mas o fetch de pixels ainda é o renderer simples de background:
  ele não modela FIFO, fetcher real, janela variável de Mode 3, bloqueios de
  VRAM/OAM, sprites, window, LCD enable ou DMA.

Alvo seguinte concluído:

```text
Conectar o scheduler por dots a um primeiro modelo de LCDC enable e reset de
LY/STAT, preservando o caminho visual e sem adicionar sprites, window ou DMA.
```

Critério de sucesso sugerido:

- respeitar o bit 7 de `LCDC` como liga/desliga inicial do LCD;
- quando LCD estiver desligado, manter `LY=0` e modo coerente para a fase atual;
- preservar o comportamento atual quando LCD estiver ligado;
- manter VBlank/STAT/IF sem regressão nos testes existentes;
- manter `run_ppu_background_renderer.do`, `run_bus_controller.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do`, `run_cpu_instr_timing.do`,
  `run_cpu_interrupt_time.do` e `run_cpu_halt_bug.do` passando;
- sintetizar e registrar custo antes de avançar para OAM/sprites.

Resultado:

- `bus_controller.vhd` agora expõe `ppu_lcd_enable` a partir de `LCDC(7)`;
- quando `LCDC(7)=0`, leituras de `LY` retornam `0x00` e `STAT` usa linha zero
  e Mode 0 como estado efetivo;
- solicitações de VBlank/STAT vindas da PPU ficam mascaradas enquanto o LCD está
  desligado;
- `ppu_background_renderer.vhd` recebe `lcd_enable` e mantém estado, linha, dot,
  framebuffer write e busy/done inativos quando o LCD está desligado;
- o comportamento visual atual permanece inalterado porque o reset de `LCDC` é
  `0x91`, com bit 7 ligado.

Limitação importante:

- este ainda não é o comportamento completo de ligar/desligar LCD do DMG. Falta
  modelar atrasos e efeitos finos de enable/disable, restrições de acesso,
  efeitos sobre janela/sprites e interação com uma FIFO real.

Próximo alvo oficial recomendado:

```text
Adicionar os primeiros bloqueios de acesso CPU a VRAM/OAM por modo da PPU,
começando por VRAM durante Mode 3, preservando o renderer de background e os
testes visuais atuais.
```

Critério de sucesso sugerido:

- quando PPU estiver em Mode 3 e LCD ligado, leituras/escritas de CPU em VRAM
  devem seguir um comportamento controlado de bloqueio inicial;
- quando LCD estiver desligado, VRAM deve permanecer acessível;
- preservar o caminho de escrita CPU -> VRAM antes do início do render visual;
- manter `run_bus_controller.do`, `run_ppu_background_renderer.do`,
  `run_ppu_background_demo_top.do`, `run_cpu_ppu_background_demo_top.do`,
  `run_cpu_video_smoke_top.do`, `run_timer.do`, `run_cpu_instr_timing.do`,
  `run_cpu_interrupt_time.do` e `run_cpu_halt_bug.do` passando;
- sintetizar e registrar custo antes de avançar para OAM/sprites.

Resultado:

- `bus_controller.vhd` agora bloqueia acessos de CPU a VRAM quando
  `LCDC(7)=1`, a PPU está em Mode 3 e o endereço selecionado está em
  `0x8000..0x9FFF`;
- leituras bloqueadas retornam `0xFF`;
- escritas bloqueadas são ignoradas, preservando o conteúdo anterior da VRAM;
- com o LCD desligado, a VRAM permanece acessível mesmo que a entrada bruta de
  modo da PPU esteja em Mode 3;
- o comportamento visual atual permanece preservado porque a CPU carrega a VRAM
  antes do início do render.

Limitação importante:

- este é um bloqueio inicial e conservador de VRAM. Ainda falta modelar OAM,
  sprite scan, DMA, conflitos mais finos de barramento e o comportamento exato
  de open bus por caso.

Próximo alvo oficial recomendado:

```text
Adicionar a memória OAM inicial de 160 bytes em 0xFE00..0xFE9F e bloquear
acessos de CPU durante Mode 2/3 enquanto o LCD estiver ligado, ainda sem
renderizar sprites.
```

Critério de sucesso sugerido:

- CPU deve ler/escrever OAM fora das janelas bloqueadas;
- durante Mode 2 ou Mode 3 com LCD ligado, leituras de CPU em OAM devem retornar
  um valor controlado e escritas devem ser ignoradas;
- durante LCD desligado, OAM deve permanecer acessível;
- preservar VRAM, background renderer, `LY/STAT/IF` e os tops visuais atuais;
- manter a regressão atual passando e sintetizar antes de avançar para OAM scan
  real.

Resultado:

- `bus_controller.vhd` agora decodifica OAM em `0xFE00..0xFE9F`;
- CPU pode ler/escrever OAM fora das janelas bloqueadas;
- leituras CPU em OAM retornam `0xFF` durante Mode 2 ou Mode 3 com LCD ligado;
- escritas CPU em OAM durante Mode 2 ou Mode 3 com LCD ligado são ignoradas;
- com LCD desligado, OAM permanece acessível mesmo se a entrada bruta de modo
  estiver em Mode 2 ou Mode 3;
- `0xFEA0..0xFEFF` continua como região não usável e lê `0xFF`;
- para evitar explodir LEs, a memória física foi inferida como RAM M9K de
  256 bytes, expondo somente a janela DMG real de 160 bytes.

Limitação importante:

- ainda não existe porta PPU dedicada para OAM scan, nem seleção de 10 sprites
  por scanline, nem DMA OAM real. Esta fatia estabelece apenas armazenamento e
  ownership inicial pelo barramento.

Próximo alvo oficial recomendado:

```text
Adicionar o primeiro OAM scan mínimo, lendo a OAM pelo lado da PPU e
identificando sprites candidatos por LY, ainda sem renderizar sprites nem
misturar pixels ao background.
```

Critério de sucesso sugerido:

- adicionar uma porta de leitura PPU para OAM ou um módulo `ppu_oam_scan`
  mínimo com acesso controlado;
- preservar o bloqueio CPU em Mode 2/3;
- detectar até 10 sprites candidatos para uma linha visível;
- não alterar a saída visual de background ainda;
- manter regressão e Quartus fechando antes de iniciar composição de sprites.

Alvo seguinte concluído:

```text
Transformar o renderer de background de one-shot para loop contínuo de frames
enquanto LCDC bit 7 estiver ligado, preservando os tops visuais atuais.
```

Resultado:

- `ppu_background_renderer.vhd` agora reinicia automaticamente em line 0, dot 0
  após a linha 153, dot 455;
- `done` deixou de ser estado terminal permanente e virou pulso de um ciclo no
  fim do frame;
- `start` continua sendo usado como kick inicial, o que preserva os demos que
  precisam carregar VRAM antes do primeiro frame;
- `lcd_enable=0` ainda segura o renderer inativo com linha/dot zerados;
- os tops visuais registram o pulso de frame em `ppu_frame_seen` para manter o
  LED de debug estável sem mudar a semântica limpa do núcleo.

Limitação importante:

- o renderer ainda é uma base simples de background. Ainda faltam seleção real
  por bits de `LCDC`, fetcher/FIFO de pixels, window, sprites e DMA.

Próximo alvo oficial recomendado:

```text
Aplicar o registrador BGP no write do framebuffer, convertendo o color id de
tile em shade final de 2 bits antes de gravar o pixel.
```

Critério de sucesso sugerido:

- expor `BGP` do barramento para o renderer;
- mapear color id `00/01/10/11` pelos pares de bits de `BGP`;
- preservar o padrão visual atual quando `BGP = 0xFC`;
- adicionar teste específico mudando `BGP` e verificando o framebuffer;
- manter regressão e Quartus fechando.

Alvo concluído:

```text
Aplicar o registrador BGP no write do framebuffer, convertendo o color id de
tile em shade final de 2 bits antes de gravar o pixel.
```

Resultado:

- `bus_controller.vhd` agora expõe `ppu_bgp`, espelhando o registrador CPU
  `FF47`;
- `ppu_background_renderer.vhd` recebe `bgp` e aplica os pares de bits do DMG:
  color id `00 -> BGP(1 downto 0)`, `01 -> BGP(3 downto 2)`,
  `10 -> BGP(5 downto 4)` e `11 -> BGP(7 downto 6)`;
- o valor padrão `BGP = 0xFC` preserva a imagem visual anterior;
- `tb_ppu_background_renderer` agora testa explicitamente uma paleta identidade
  `BGP = 0xE4` com pixels `00/01/10/11`;
- `tb_bus_controller` confirma que `ppu_bgp` acompanha o reset e a escrita em
  `FF47`;
- os tops visuais roteiam `ppu_bgp` do barramento para a PPU.

Regressões executadas:

- `run_ppu_background_renderer.do` — Passed;
- `run_bus_controller.do` — Passed;
- `run_ppu_background_demo_top.do` — Passed;
- `run_cpu_video_smoke_top.do` — Passed;
- `run_cpu_ppu_background_demo_top.do` — Passed;
- build Quartus completo em `2026-05-20` — Passed, com
  `4.342 / 6.272` LEs usados (`69%`), `179.200 / 276.480` bits de memória
  (`65%`) e `23 / 30` blocos M9K usados (`77%`).

Próximo alvo oficial recomendado:

```text
Completar os bits de LCDC que afetam o background antes de iniciar OAM scan.
```

Critério de sucesso sugerido:

- aplicar `LCDC(3)` para selecionar tile map base `0x9800/0x9C00`;
- aplicar `LCDC(4)` para selecionar modo unsigned/signed de tile data;
- decidir a semântica inicial de `LCDC(0)` para background enable no DMG;
- preservar a regressão BGP/scroll/frame loop;
- manter Quartus fechado antes de avançar para OAM scan.

Alvo concluído:

```text
Completar os bits de LCDC que afetam o background antes de iniciar OAM scan.
```

Resultado:

- `bus_controller.vhd` agora expõe `ppu_lcdc`, espelhando o registrador CPU
  `FF40`;
- `ppu_background_renderer.vhd` usa `LCDC(3)` para selecionar a tile map base
  `0x9800/0x9C00`, mapeada localmente como VRAM `0x1800/0x1C00`;
- `LCDC(4)` seleciona tile data unsigned em VRAM local `0x0000` ou signed
  centralizado em VRAM local `0x1000`;
- `LCDC(0)` recebeu a semântica inicial de background disable: força color id
  `0` antes do lookup de `BGP`;
- os tops visuais roteiam `ppu_lcdc` do barramento para a PPU;
- `tb_ppu_background_renderer` cobre tile map 1, modo signed de tile data e
  background disable.

Regressões executadas:

- `run_ppu_background_renderer.do` — Passed;
- `run_bus_controller.do` — Passed;
- `run_ppu_background_demo_top.do` — Passed;
- `run_cpu_video_smoke_top.do` — Passed;
- `run_cpu_ppu_background_demo_top.do` — Passed;
- build Quartus completo em `2026-05-20` — Passed, com
  `4.382 / 6.272` LEs usados (`70%`), `179.200 / 276.480` bits de memória
  (`65%`) e `23 / 30` blocos M9K usados (`77%`).

Próximo alvo oficial recomendado:

```text
Implementar o primeiro OAM scan da PPU, detectando candidatos por scanline sem
renderizar sprites ainda.
```

Critério de sucesso sugerido:

- dar à PPU uma porta de leitura de OAM ou uma interface dedicada de scan;
- respeitar o bloqueio CPU em Mode 2/3 já existente;
- detectar até 10 sprites candidatos em uma linha visível;
- preservar a saída visual de background;
- manter regressão e Quartus fechando antes de iniciar composição de sprites.

Alvo concluido:

```text
Implementar o primeiro OAM scan da PPU, detectando candidatos por scanline sem
renderizar sprites ainda.
```

Resultado:

- criado `rtl/ppu/ppu_oam_scan.vhd`;
- `bus_controller.vhd` agora expoe uma porta de leitura OAM para a PPU,
  preservando o bloqueio de acesso da CPU durante Mode 2/3;
- o scanner inicia no pulso de Mode 2 dot zero das linhas visiveis;
- a varredura percorre os 40 sprites em 80 ciclos, usando um ciclo para pedir o
  byte Y e outro para capturar/avaliar;
- a deteccao usa `LY + 16`, o byte Y do sprite e `LCDC(2)` para selecionar
  altura 8x8 ou 8x16;
- ate 10 indices de sprites candidatos sao registrados por scanline;
- `LCDC(1)` desabilita a coleta de candidatos quando sprites estao desligados;
- os tops visuais preservam a saida de background e usam LED de debug apenas
  para manter a atividade do scan observavel.

Regressoes executadas:

- `run_ppu_oam_scan.do` - Passed;
- `run_bus_controller.do` - Passed;
- `run_ppu_background_demo_top.do` - Passed;
- `run_cpu_video_smoke_top.do` - Passed;
- `run_cpu_ppu_background_demo_top.do` - Passed;
- build Quartus completo em `2026-05-20` - Passed, com
  `4.438 / 6.272` LEs usados (`71%`), `179.200 / 276.480` bits de memoria
  (`65%`) e `23 / 30` blocos M9K usados (`77%`).

Limitacao importante:

- esta fatia apenas seleciona candidatos de sprite. Ainda nao ha fetch de tile
  de sprite, FIFO/composicao com background, prioridade, atributos, DMA OAM ou
  comportamento de OAM bug.

Proximo alvo oficial recomendado:

```text
Implementar a primeira fatia de sprite pixel fetch/composition, usando os
candidatos do OAM scan, ainda sem buscar precisao completa de prioridade.
```

Criterio de sucesso sugerido:

- consumir os indices candidatos produzidos pelo OAM scan;
- buscar os bytes de tile do primeiro sprite candidato visivel;
- compor um primeiro sprite sobre o background de forma controlada;
- preservar a saida visual quando `LCDC(1)=0`;
- manter regressao e Quartus fechando antes de ampliar prioridade, atributos e
  limite completo de sprites.

Alvo concluido:

```text
Implementar a primeira fatia de sprite pixel fetch/composition, usando os
candidatos do OAM scan, ainda sem buscar precisao completa de prioridade.
```

Resultado:

- `bus_controller.vhd` agora expoe `ppu_obp0` para o caminho PPU;
- `ppu_background_renderer.vhd` consome o primeiro indice candidato produzido
  pelo OAM scan;
- o renderer busca Y, X, tile index e atributos desse sprite pela porta OAM da
  PPU;
- a linha do tile de sprite e buscada pela porta VRAM da PPU antes da escrita
  dos pixels da linha;
- pixels OBJ com color id `00` permanecem transparentes;
- pixels OBJ nao-zero sao compostos sobre o background usando `OBP0`;
- `LCDC(1)=0` preserva o caminho background-only;
- atributos de flip horizontal e vertical ja sao considerados nesta fatia;
- os tops visuais arbitram a porta OAM da PPU entre OAM scan e renderer.

Regressoes executadas:

- `run_ppu_background_renderer.do` - Passed;
- `run_bus_controller.do` - Passed;
- `run_ppu_background_demo_top.do` - Passed;
- `run_cpu_ppu_background_demo_top.do` - Passed;
- `run_ppu_oam_scan.do` - Passed;
- `run_cpu_video_smoke_top.do` - Passed;
- build Quartus completo em `2026-05-20` - Passed, com
  `4.551 / 6.272` LEs usados (`73%`), `179.200 / 276.480` bits de memoria
  (`65%`) e `23 / 30` blocos M9K usados (`77%`).

Limitacao importante:

- esta ainda nao e a composicao completa de sprites do DMG. Falta `OBP1`,
  prioridade BG/OBJ, ordenacao entre sprites, composicao de multiplos
  candidatos, janela, FIFO real e timings finos de Mode 3.

Proximo alvo oficial recomendado:

```text
Expandir a composicao de sprites para OBP1, prioridade basica e mais de um
candidato por linha, mantendo cada comportamento coberto por teste.
```

Criterio de sucesso sugerido:

- aplicar `OBP1` quando o atributo do sprite selecionar a segunda paleta;
- respeitar pelo menos a prioridade inicial BG/OBJ para pixels de background
  nao-zero;
- compor mais de um candidato por linha de forma deterministica;
- preservar transparencia de color id `00`;
- manter regressao e Quartus fechando abaixo de 80% de LEs.

## 15. Princípio de Engenharia do Projeto

Este projeto deve crescer por evidência, não por suposição.

O ciclo correto é:

1. Definir um alvo pequeno.
2. Implementar o mínimo necessário.
3. Simular.
4. Sintetizar quando houver mudança em RTL.
5. Medir recursos.
6. Testar em hardware quando fizer sentido.
7. Documentar.
8. Avançar.

Essa disciplina é o que evita que o projeto perca coerência à medida que a CPU,
o barramento, a memória, o vídeo e os testes reais começam a se cruzar.

## 16. Atualização da Fase de Timing

Nesta etapa, o foco foi estabilizar a temporização sem quebrar os testes já
conquistados.

Resultado técnico:

- a fase inicial do divisor do timer foi ajustada para o modelo atual de CPU em
  ciclos M, permitindo que `instr_timing.gb` saia da calibração inicial do timer;
- `JP nn` incondicional passou a preservar o quarto ciclo M;
- `CALL nn` incondicional passou a preservar o ciclo interno antes dos writes de
  pilha;
- `RET` e `RETI` passaram a preservar o quarto ciclo M após a leitura do endereço
  de retorno;
- `tb_cpu_timing_probe` agora testa explicitamente `JP nn`, `CALL nn` e `RET`.

Regressões executadas e aprovadas:

- `run_cpu_smoke.do`;
- `run_cpu_timing_probe.do`;
- `run_timer.do`;
- `run_cpu_blargg_02.do`;
- `run_bus_controller.do`;
- `run_cpu_video_smoke_top.do`.

Estado de `instr_timing.gb`:

- a ROM já avança além do erro inicial `Timer doesn't work properly`;
- a investigação mostrou que as primeiras diferenças por opcode eram causadas
  pela fronteira CPU/barramento/timer, não pelos opcodes isolados;
- a ROM agora alcança `Passed` no runner real de ROM.

Próximo alvo:

1. manter `instr_timing.gb` como regressão obrigatória;
2. avançar para as próximas ROMs de timing do Blargg;
3. usar sondas locais apenas para localizar falhas já observadas nas ROMs reais;
4. repetir as regressões rápidas;
5. depois sintetizar e medir custo em LEs.

Observação para hardware real:

Quando a simulação de timing estiver mais estável, devemos levar uma parte desse
trabalho para a placa OMDAZZ Cyclone IV EP4CE6 usando SignalTap. A validação deve
capturar poucos sinais por vez, por exemplo `debug_pc`, `debug_state`,
`mem_read`, `mem_write`, `mem_addr`, `timer_interrupt_set` e alguns sinais do
timer. Isso é importante porque a simulação comprova o modelo lógico, mas o
hardware real também revela problemas de fase, reset, clock, constraints e
observabilidade que podem não aparecer no ModelSim.

## 17. Diagnóstico Seguinte de `instr_timing`

Nesta etapa, evitamos corrigir opcodes às cegas. A ROM `instr_timing.gb`
começou a imprimir diferenças logo nos opcodes iniciais, mas a sonda local
mostrou que muitos desses opcodes já possuem a contagem direta correta de ciclos
M dentro da CPU.

Alterações feitas:

- o timer recebeu o genérico `G_DIV_COUNTER_RESET`, mantendo o valor padrão `4`;
- o script `run_cpu_instr_timing.do` agora passa explicitamente essa fase para
  deixar a hipótese visível;
- `tb_cpu_rom_runner` também recebeu o genérico correspondente para permitir
  varreduras curtas de fase sem editar o RTL;
- `tb_cpu_timing_probe` foi ampliado com `INC BC`, `DEC BC`, `LD (HL+),A`,
  `LD A,(HL+)`, `LDH A,(n)`, `LD A,(nn)` e `LD SP,HL`;
- a hipótese de leitura de `TIMA` pós-tick foi refinada: o incremento normal da
  TIMA passa a ser visível no fim do ciclo M atual, enquanto o atraso de
  overflow continua preservado e coberto por `tb_timer`.

Resultado:

- `tb_cpu_timing_probe` continua passando com a cobertura ampliada;
- `run_cpu_instr_timing.do` agora alcança `Passed`;
- `run_timer.do` continua passando;
- `run_cpu_smoke.do` continua passando;
- `run_cpu_blargg_02.do` continua passando;
- `run_bus_controller.do` continua passando;
- `run_cpu_video_smoke_top.do` continua passando.

Conclusão técnica:

As primeiras linhas de `instr_timing.gb`, como `01:4-3`, `02:3-2` e `06:1-2`,
não eram erro isolado nesses opcodes. A causa estava no ponto em que o timer
torna `TIMA` visível para uma leitura de I/O da CPU dentro do ciclo M.

Próximo alvo:

1. manter essa correção como checkpoint de `instr_timing.gb`;
2. manter `interrupt_time.gb` como regressão já conquistada;
3. avançar para `halt_bug.gb`;
4. comparar qualquer nova falha com a ROM real antes de mexer na FSM;
5. só criar novas sondas locais quando elas ajudarem a explicar uma falha real.

## 18. Sonda de Debug CPU/Timer

Foi criada uma sonda local chamada `tb_cpu_timer_blargg_probe`. Ela não é um
substituto para o Blargg e não deve ser usada como critério independente de
aprovação. A função dela é apenas reduzir o problema e permitir observar a
fronteira CPU/bus/timer com menos ruído do que a ROM completa.

O que a sonda faz:

- executa um pequeno programa real na CPU;
- usa o timer compartilhado do projeto;
- usa laços no estilo `start_timer`/`stop_timer` do Blargg;
- mede `NOP`;
- mede `LD BC,nn`, que é o primeiro opcode reportado como `01:4-3` na ROM
  `instr_timing.gb`.

Resultado observado:

- `NOP` mede `1`, como esperado;
- depois do ajuste de visibilidade da TIMA, `LD BC,nn` mede `3`, como esperado;
- o teste direto `tb_cpu_timing_probe` ainda mede `LD BC,nn` como `3` ciclos.

Conclusão:

Esse foi o ponto decisivo desta investigação: a CPU já estava contando
`LD BC,nn` corretamente, e a correção precisava acontecer na fronteira de
observação CPU/barramento/timer. A ROM real `instr_timing.gb` confirmou isso ao
alcançar `Passed` depois do ajuste.

Regressões executadas após a correção:

- `run_cpu_instr_timing.do` — Passed;
- `run_timer.do` — Passed;
- `run_cpu_smoke.do` — Passed;
- `run_cpu_blargg_02.do` — Passed;
- `run_bus_controller.do` — Passed;
- `run_cpu_video_smoke_top.do` — Passed;
- `run_cpu_timer_blargg_probe.do` — diagnóstico concluído com `LD BC,nn = 3`.

Próximo passo técnico:

- avançar para as próximas ROMs Blargg de temporização;
- não criar testes locais como substitutos de aceite;
- usar sondas locais apenas para explicar falhas que aparecerem nas ROMs reais.

## 19. Primeira Expansao de Sprite Composition

Nesta etapa fechamos a fatia recomendada depois do primeiro OBJ pixel: `OBP1`,
prioridade basica BG/OBJ e mais de um candidato por linha.

Alteracoes feitas:

- `bus_controller.vhd` agora expoe `ppu_obp1` para o caminho PPU;
- `ppu_background_renderer.vhd` agora possui dois slots pequenos de sprite para
  composicao da scanline atual;
- o renderer busca ate os dois primeiros candidatos vindos do OAM scan;
- atributo bit 4 seleciona `OBP0` ou `OBP1`;
- atributo bit 7 implementa a primeira regra de prioridade: sprite atras do BG
  nao sobrescreve BG com color id diferente de zero, mas ainda aparece sobre BG
  color id zero;
- a composicao e deterministica nesta fatia: candidatos sao avaliados na ordem
  recebida do OAM scan, e o primeiro pixel OBJ nao transparente visivel vence.

Testes executados:

- `run_ppu_background_renderer.do` passou, cobrindo `OBP1`, prioridade sobre BG
  nao zero, prioridade sobre BG zero e segundo candidato quando o primeiro e
  transparente;
- `run_bus_controller.do` passou, incluindo espelhamento de `OBP1`;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- `run_ppu_oam_scan.do` passou;
- build Quartus completo passou.

Resultado de sintese:

- 4,649 / 6,272 LEs, 74%;
- 1,670 registradores;
- 179,200 / 276,480 bits de memoria, 65%;
- 23 / 30 M9Ks, 77%;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 22.991 ns no clock VGA e 177.401 ns no clock CPU;
- pior hold slack: 0.425 ns no clock CPU e 0.503 ns no clock VGA.

Conclusao tecnica:

A fatia aumenta o custo em 98 LEs e 56 registradores em relacao ao checkpoint de
um sprite, sem adicionar M9K. O projeto permanece dentro do orcamento, mas ja
esta na faixa em que cada nova expansao de PPU deve ser medida.

Proximo passo recomendado:

1. expandir de 2 para ate 10 candidatos com cuidado de custo;
2. refinar a ordenacao de sprites para aproximar melhor o DMG;
3. preparar a interacao com Window antes de tentar uma FIFO mais fiel;
4. manter esta fatia como baseline automatizado de `OBP1` e prioridade.

## 20. Sprite Composition com 10 Candidatos

Nesta etapa expandimos a fatia anterior de 2 sprites para os 10 candidatos por
scanline que o OAM scan ja produzia.

Alteracoes feitas:

- `MAX_COMPOSE_SPRITES` passou de 2 para 10 no `ppu_background_renderer`;
- o renderer agora busca e armazena os 10 candidatos da scanline atual;
- a regra de composicao continua simples e deterministica: ordem recebida do OAM
  scan, primeiro pixel OBJ nao transparente visivel vence;
- a regra de `OBP0`/`OBP1` e prioridade BG/OBJ da fatia anterior foi preservada;
- foi feita uma otimizacao de registradores: Y e tile index do sprite viraram
  registradores do fetch corrente, nao arrays por slot, porque nao sao usados na
  composicao depois que a linha do tile foi lida.

Teste novo:

- `tb_ppu_background_renderer` agora cobre 10 candidatos na mesma linha, com os
  9 primeiros transparentes e o decimo sendo o primeiro pixel OBJ visivel.

Regressoes executadas:

- `run_ppu_background_renderer.do` passou;
- `run_bus_controller.do` passou;
- `run_ppu_oam_scan.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou.

Resultado de sintese:

- 5,286 / 6,272 LEs, 84%;
- 1,935 registradores;
- 179,200 / 276,480 bits de memoria, 65%;
- 23 / 30 M9Ks, 77%;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 26.370 ns no clock VGA e 178.275 ns no clock CPU;
- pior hold slack: 0.452 ns no clock CPU e 0.502 ns no clock VGA.

Conclusao tecnica:

A funcionalidade cabe e passa, mas cruzou o limite de alerta de 80% de LEs. A
otimizacao de Y/tile reduziu o custo de 5,445 LEs para 5,286 LEs, mas ainda
temos pouco espaco para Window, FIFO fiel, DMA e integracao final.

Proximo passo recomendado:

1. reduzir custo da composicao de sprites antes de adicionar novas camadas;
2. estudar uma estrutura sequencial/compacta para escolha do sprite visivel;
3. depois refinar ordenacao DMG e interacao com Window;
4. manter esta versao como baseline funcional de 10 candidatos.

## 21. Otimizacao Sequencial de Sprite Composition

Nesta etapa atacamos o problema de recursos aberto pela composicao completa de
10 candidatos. A decisao foi preservar a funcionalidade ja conquistada, mas
trocar a selecao combinacional de 10 sprites por uma caminhada sequencial de um
candidato por ciclo interno.

Alteracoes feitas:

- `ppu_background_renderer.vhd` ganhou os estados `S_COMPOSE_INIT` e
  `S_COMPOSE_CHECK`;
- o color id de background e o shade final inicial sao registrados antes da
  verificacao de sprites;
- cada candidato armazenado e avaliado em um ciclo interno de composicao;
- o primeiro pixel OBJ nao transparente que passa pela regra de prioridade
  atualiza o shade do framebuffer e encerra a caminhada;
- `OBP0`, `OBP1`, transparencia de color id `00` e prioridade BG/OBJ foram
  preservados;
- o caminho combinacional grande que avaliava todos os 10 candidatos no output
  do framebuffer foi removido.

Regressoes executadas:

- `run_ppu_background_renderer.do` passou;
- `run_bus_controller.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou.

Resultado de sintese:

- 5,013 / 6,272 LEs, 80%;
- 1,945 registradores;
- 179,200 / 276,480 bits de memoria, 65%;
- 23 / 30 M9Ks, 77%;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 25.084 ns no clock VGA e 178.146 ns no clock CPU;
- pior hold slack: 0.452 ns no clock CPU e 0.518 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 5,286 LEs para 5,013 LEs, economia de 273 LEs;
- `ppu_background_renderer`: 1,004 logic cells para 740 logic cells, economia
  local de 264 logic cells;
- custo: +10 registradores e maior latencia interna por pixel quando sprites
  estao habilitados.

Conclusao tecnica:

A otimizacao foi boa e necessaria: voltamos de 84% para 80% de LEs, sem perder a
fatia funcional de 10 candidatos. Mas 80% ainda e limite apertado, nao margem
confortavel. Antes de adicionar Window, DMA ou uma FIFO mais fiel, devemos buscar
mais economia estrutural.

Decisao de escopo:

- APU nao e prioridade neste projeto agora;
- audio so deve ser retomado depois que CPU, barramento, PPU, input, ROM loading
  e primeira integracao jogavel estiverem funcionais;
- a prioridade de otimizacao deve ficar no caminho grafico, barramento e logica
  de debug temporaria.

Proximo passo recomendado:

1. otimizar o `vga_pixel_pipeline`, especialmente os multiplicadores inferidos
   para o endereco do framebuffer;
2. depois revisar custo de `bus_controller` e remover ou condicionar debug que
   nao precisa existir no top final jogavel;
3. somente entao voltar para refinamento de ordering de sprites, Window e DMA.

## 22. Otimizacao do VGA Pixel Pipeline

Nesta etapa otimizamos o caminho de saida de video que ainda inferia logica de
multiplicacao para calcular a escala fixa 3x.

Alteracoes feitas:

- `vga_pixel_pipeline.vhd` deixou de calcular `(pixel - offset) / 3` por
  multiplicacao reciproca;
- o pipeline agora assume coordenadas em ordem raster vindas de
  `vga_controller`;
- a escala horizontal e vertical 3x passou a ser acompanhada por fases
  modulo-3 pequenas;
- o endereco do framebuffer passou a usar uma base de linha registrada mais a
  coordenada X atual;
- os sinais internos antigos `gb_x` e `gb_y`, que geravam avisos por nao serem
  lidos, foram removidos;
- `run_pixel_pipeline.do` foi atualizado para observar os novos registradores
  internos de fase/base;
- `tb_vga_pixel_pipeline` agora testa o contrato correto: entrada rasterizada,
  nao saltos arbitrarios de coordenada.

Regressoes executadas:

- `run_pixel_pipeline.do` passou;
- `run_framebuffer_top.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou com timeout ampliado;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou.

Resultado de sintese:

- 4,995 / 6,272 LEs, 80%;
- 1,965 registradores;
- 179,200 / 276,480 bits de memoria, 65%;
- 23 / 30 M9Ks, 77%;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 29.175 ns no clock VGA e 175.177 ns no clock CPU;
- pior hold slack: 0.377 ns no clock CPU e 0.454 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 5,013 LEs para 4,995 LEs, economia de 18 LEs;
- `vga_pixel_pipeline`: 141 logic cells para 117 logic cells, economia local de
  24 logic cells;
- custo: +20 registradores para fases/base de linha;
- warnings totais do build cairam de 36 para 34.

Conclusao tecnica:

A economia e menor que a obtida na composicao de sprites, mas e uma otimizacao
correta: removemos logica de multiplicacao de um caminho de pixel fixo e
substituimos por estado sequencial barato. O projeto agora esta abaixo de 5,000
LEs, embora o Quartus ainda arredonde a utilizacao para 80%.

Proximo passo recomendado:

1. revisar o `bus_controller`, que ainda e o maior bloco depois da CPU;
2. separar claramente logica necessaria para o top jogavel de logica de debug,
   smoke e conveniencia de simulacao;
3. buscar economia sem quebrar os contratos de WRAM, HRAM, VRAM, OAM, timer,
   IF/IE e LCD registers;
4. manter APU fora do escopo ate o sistema nao-audio estar funcional.

## 23. Separacao Configuravel de Debug/Smoke no Barramento

Nesta etapa revisamos o `bus_controller` para separar logica temporaria de
smoke/debug da logica que o top CPU/PPU visual realmente precisa.

Alteracoes feitas:

- `bus_controller.vhd` recebeu os genericos:
  - `G_ENABLE_FB_WINDOW`;
  - `G_ENABLE_SMOKE_CHECKER`;
  - `G_ENABLE_SERIAL_DEBUG`;
- os valores padrao continuam `true`, preservando os testes de barramento e o
  `cpu_video_smoke_top`;
- `ppu_background_demo_top` e `cpu_ppu_background_demo_top` agora desabilitam
  explicitamente esses recursos temporarios;
- o marcador de conclusao em `0xFF80` permanece ativo, pois ele ainda e usado
  para iniciar a PPU no demo CPU -> VRAM -> PPU.

Regressoes executadas:

- `run_bus_controller.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou.

Resultado de sintese:

- 4,995 / 6,272 LEs, 80%;
- 1,965 registradores;
- 179,200 / 276,480 bits de memoria, 65%;
- 23 / 30 M9Ks, 77%;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 29.175 ns no clock VGA e 175.177 ns no clock CPU;
- pior hold slack: 0.377 ns no clock CPU e 0.454 ns no clock VGA.

Conclusao tecnica:

A separacao melhorou a arquitetura, mas nao reduziu o numero final de LEs no top
atual. Isso indica que o Quartus ja eliminava boa parte da logica de debug sem
fanout no `cpu_ppu_background_demo_top`. Ainda assim, a mudanca vale porque
deixa explicito quais recursos sao temporarios e evita que futuros tops carreguem
logica de smoke por acidente.

Tentativa descartada:

- trocamos experimentalmente comparadores largos de faixa de endereco por
  decodes diretos de bits;
- a simulacao passou, mas o fit final piorou para 5,025 LEs;
- a tentativa foi revertida e nao deve ser considerada uma otimizacao valida.

Proximo passo recomendado:

1. nao insistir em debug sem fanout, pois o Quartus ja esta podando isso;
2. atacar logica realmente retida, especialmente HRAM e caminhos de leitura do
   barramento;
3. se mexermos em HRAM, reestruturar o read path em vez de apenas tentar
   atributo `ramstyle`, pois essa tentativa ja falhou em inferir M9K;
4. manter APU fora do escopo ate o sistema nao-audio estar funcional.

## 24. Otimizacao da HRAM em M9K

Nesta etapa atacamos a maior logica retida que ainda parecia artificial: a HRAM
implementada dentro do `bus_controller`. O objetivo era tentar empurrar o
projeto para a faixa de 4,600 LEs, preservando o escopo enxuto para jogos
simples.

Alteracoes feitas:

- foi criado `rtl/memory/hram.vhd`, uma RAM sincrona single-port de 128 x 8
  bits;
- a HRAM saiu do array interno do `bus_controller` e passou a ser uma entidade
  dedicada;
- o caminho de escrita usa `hram_cpu_we <= cpu_write and hram_selected`;
- a leitura continua integrada ao contrato existente de CPU/barramento;
- os scripts ModelSim e o projeto Quartus passaram a compilar `hram.vhd` antes
  do `bus_controller`.

Regressoes executadas:

- `run_bus_controller.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou com 0 erros e 34 warnings.

Resultado de sintese:

- 3,674 / 6,272 LEs, 59%;
- 941 registradores, 15%;
- 180,224 / 276,480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- 0 multiplicadores;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 29.546 ns no clock VGA e 177.118 ns no clock CPU;
- pior hold slack: 0.439 ns no clock CPU e 0.452 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 4,995 LEs para 3,674 LEs, economia de 1,321 LEs;
- registradores: 1,965 para 941, economia de 1,024 registradores;
- memoria: 179,200 bits para 180,224 bits, custo de +1,024 bits;
- M9Ks: 23 para 24, custo de +1 bloco;
- `bus_controller`: 1,870 logic cells / 1,210 registradores para 543 logic
  cells / 186 registradores;
- `hram:u_hram`: 1,024 bits em 1 M9K, sem LEs relevantes.

Conclusao tecnica:

A otimizacao superou a meta. Queriamos tentar chegar perto de 4,600 LEs e o
design caiu para 3,674 LEs, deixando uma margem aproximada de 2,598 LEs antes
do limite fisico do EP4CE6. Isso muda o risco imediato: logica voltou a ter
folga razoavel, enquanto block RAM agora precisa continuar sendo acompanhada
com cuidado porque ja estamos em 24 / 30 M9Ks.

Proximo passo recomendado:

1. seguir para recursos de jogabilidade, nao para micro-otimizacoes agora;
2. implementar OAM DMA, pois muitos jogos dependem de copia rapida para sprites;
3. implementar joypad real no barramento;
4. adicionar Window depois que DMA/input estiverem estabilizados;
5. retomar fluxo de ROM/SDRAM quando a base CPU/PPU/input estiver pronta para
   rodar programas maiores;
6. manter APU fora ate o sistema nao-audio estar jogavel.

## 25. Primeira Fatia de OAM DMA

Nesta etapa implementamos a primeira versao funcional de DMA para OAM,
priorizando o caminho necessario para jogos simples: copia de shadow OAM em
WRAM/Echo para `0xFE00..0xFE9F`.

Escopo escolhido:

- escrita em `0xFF46` inicia DMA;
- o byte escrito e mantido em `dma_reg`;
- fontes suportadas nesta fatia:
  - `0xC000..0xDF9F`;
  - `0xE000..0xFD9F`;
- a transferencia copia 160 bytes para OAM;
- `cpu_ready` fica em `0` enquanto o DMA esta ativo, travando a CPU ate o fim
  da copia;
- a implementacao usa a WRAM e a OAM ja inferidas em M9K, sem criar nova RAM.

Limitacao assumida:

Esta ainda nao e uma DMA OAM completa do DMG. Nesta fatia, ROM/cartucho,
VRAM, HRAM e fontes externas ainda nao sao copiadas. Tambem mantivemos a copia
serializada pelo caminho de leitura registrada da WRAM, em vez de tentar
modelar imediatamente a duracao exata de 160 M-cycles. A escolha foi
intencional: entregar o caminho mais importante para jogos basicos com baixo
custo de area.

Alteracoes feitas:

- `bus_controller.vhd` ganhou sinais `dma_active`, `dma_phase`, `dma_index`,
  `dma_wram_addr`, `dma_source_wram` e `dma_oam_we`;
- o endereco de leitura da WRAM agora e multiplexado entre CPU e DMA;
- o caminho de escrita da OAM agora multiplexa escrita normal da CPU e escrita
  vinda do DMA;
- `cpu_ready` passa a ficar baixo durante DMA ativo;
- `tb_bus_controller` agora preenche 160 bytes de WRAM, escreve `0xC0` em
  `0xFF46` e valida bytes copiados em `0xFE00`, `0xFE01` e `0xFE9F`.

Regressoes executadas:

- `run_bus_controller.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou com 0 erros e 34 warnings.

Resultado de sintese:

- 3,741 / 6,272 LEs, 60%;
- 951 registradores, 15%;
- 180,224 / 276,480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- 0 multiplicadores;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 28.883 ns no clock VGA e 179.754 ns no clock CPU;
- pior hold slack: 0.436 ns no clock CPU e 0.453 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 3,674 LEs para 3,741 LEs, custo de +67 LEs;
- registradores: 941 para 951, custo de +10 registradores;
- memoria e M9K permaneceram iguais;
- `bus_controller`: 543 logic cells / 186 registradores para 600 logic cells /
  196 registradores.

Conclusao tecnica:

A fatia ficou dentro da estrategia do core enxuto. Ela adiciona um recurso
relevante para o caminho jogavel com custo pequeno e sem consumir mais M9Ks. O
projeto permanece com folga logica razoavel apos a otimizacao da HRAM, mas o
limite de block RAM continua sendo acompanhado porque ja estamos em 24 / 30
M9Ks.

Proximo passo recomendado:

1. implementar joypad real no barramento;
2. depois adicionar Window;
3. manter o refinamento de DMA para outras fontes como tarefa futura, quando
   ROM/cartucho/SDRAM estiverem mais definidos;
4. manter APU fora do escopo ate o sistema nao-audio estar jogavel.

## 26. Joypad Real em `0xFF00`

Nesta etapa substituimos o stub de JOYP por uma primeira implementacao real no
barramento Game Boy, mantendo a logica pequena e adequada para o EP4CE6.

Escopo implementado:

- `bus_controller.vhd` recebeu entradas logicas `btn_right`, `btn_left`,
  `btn_up`, `btn_down`, `btn_a`, `btn_b`, `btn_select` e `btn_start`;
- as entradas sao active-high internamente, mas o registrador `0xFF00` retorna
  bits 3..0 em active-low, como no DMG;
- bits 5 e 4 continuam escritos pela CPU e selecionam os grupos:
  - bit 5 = `0`: A, B, Select, Start;
  - bit 4 = `0`: Right, Left, Up, Down;
- bits 7..6 leem como `1`;
- quando ambos os grupos estao selecionados, o resultado e combinado em
  active-low;
- uma transicao selecionada de solto para pressionado solicita Joypad interrupt
  em IF bit 4;
- `cpu_ppu_background_demo_top` agora expoe `key_n[3..0]` e mapeia as quatro
  teclas fisicas verificadas para A, B, Select e Start;
- direcional permanece inativo no top atual ate definirmos a entrada fisica
  final, provavelmente DIP confirmado por esquema ou PS/2.

Regressoes executadas:

- `run_bus_controller.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou com 0 erros e 29 warnings.

Resultado de sintese:

- 3,739 / 6,272 LEs, 60%;
- 955 registradores, 15%;
- 180,224 / 276,480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- 0 multiplicadores;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 26.459 ns no clock VGA e 175.981 ns no clock CPU;
- pior hold slack: 0.373 ns no clock CPU e 0.452 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 3,741 LEs para 3,739 LEs;
- registradores: 951 para 955, custo de +4 registradores;
- memoria e M9K permaneceram iguais;
- pinos passaram de 11 para 15 porque as quatro teclas fisicas entraram no top
  sintetizado.

Conclusao tecnica:

A fatia fechou o caminho minimo de input para jogos simples sem pressionar
memoria de bloco e praticamente sem custo logico. O sistema ainda precisa de
debounce/sincronizacao fisica mais cuidadosa antes de um teste longo em
hardware, mas o contrato do barramento `0xFF00` e a solicitacao de interrupcao
de Joypad ja estao validados em simulacao.

Proximo passo recomendado:

1. implementar Window no renderer/PPU;
2. depois definir o mapeamento fisico completo de direcional, por DIP
   confirmado ou PS/2;
3. manter refinamentos de DMA e fluxo ROM/SDRAM para depois da base visual/input
   estar estabilizada.

## 27. Primeira Fatia de Window Rendering

Nesta etapa adicionamos a primeira implementacao funcional da Window do DMG ao
renderer atual, sem criar FIFO nova e sem consumir memoria de bloco adicional.

Escopo implementado:

- `ppu_background_renderer.vhd` recebeu `window_y` e `window_x`;
- Window e habilitada por `LCDC(5)`;
- a tile map da Window e escolhida por `LCDC(6)`;
- a entrada horizontal segue a regra do DMG: `screen_x + 7 >= WX`;
- as coordenadas de fetch da Window usam:
  - `window_x_internal = screen_x + 7 - WX`;
  - `window_y_internal = screen_y - WY`;
- fora da regiao ativa da Window, o renderer preserva o caminho de background
  com `SCX/SCY`;
- `bus_controller.vhd` agora expoe `ppu_wy` e `ppu_wx`, espelhando `WY/WX`;
- os tops PPU conectam `WY/WX` ao renderer;
- `tb_ppu_background_renderer` valida Window ativa, `WX - 7`, tile map 1 e
  desabilitacao por `LCDC(5)`;
- `tb_bus_controller` valida que `ppu_wy/ppu_wx` espelham escritas em
  `0xFF4A/0xFF4B`.

Regressoes executadas:

- `run_ppu_background_renderer.do` passou;
- `run_bus_controller.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou com 0 erros e 29 warnings.

Resultado de sintese:

- 3,809 / 6,272 LEs, 61%;
- 955 registradores, 15%;
- 180,224 / 276,480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- 0 multiplicadores;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 28.253 ns no clock VGA e 176.395 ns no clock CPU;
- pior hold slack: 0.445 ns no clock CPU e 0.452 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 3,739 LEs para 3,809 LEs, custo de +70 LEs;
- registradores permaneceram em 955;
- memoria e M9K permaneceram iguais;
- pinos permaneceram em 15.

Conclusao tecnica:

A Window entrou com custo controlado e sem pressionar o limite mais critico do
projeto, que hoje e M9K. Como o renderer ainda e simplificado e nao FIFO
pixel-perfect, esta fatia deve ser tratada como compatibilidade funcional
inicial: suficiente para avancar rumo a jogos simples, mas ainda sujeita a
refinamentos de timing/fetch quando o core se aproximar dos testes visuais mais
exigentes.

Proximo passo recomendado:

1. revisar o caminho de boot/ROM para permitir programas maiores de teste;
2. definir o input direcional final, por DIP confirmado ou PS/2;
3. refinar detalhes de sprites/Window apenas se um ROM alvo demonstrar falha
   visual concreta.

## 28. Refino de Prioridade DMG entre Sprites

Nesta etapa corrigimos a prioridade entre sprites sobrepostos no renderer.
Antes, a composicao aceitava o primeiro candidato nao transparente em ordem de
OAM scan. Isso era deterministico, mas ainda nao representava a regra do DMG
para sprites com X diferentes.

Regra implementada:

- entre sprites sobrepostos, menor coordenada X tem prioridade;
- se X for igual, permanece o candidato anterior, preservando menor indice OAM;
- o limite de ate 10 candidatos por scanline foi mantido;
- a regra de prioridade BG/OBJ por atributo bit 7 foi preservada.

Alteracoes feitas:

- `ppu_background_renderer.vhd` ganhou um acumulador pequeno de sprite
  selecionado por pixel:
  - `selected_obj_valid_reg`;
  - `selected_obj_x_reg`;
  - `selected_obj_attr_reg`;
  - `selected_obj_color_reg`;
- durante `S_COMPOSE_CHECK`, o renderer continua varrendo os candidatos e
  substitui o sprite selecionado apenas quando encontra um OBJ elegivel com X
  menor;
- em empate de X, nao substitui, entao o menor indice OAM continua vencendo;
- `tb_ppu_background_renderer` agora cobre:
  - sprite posterior em OAM vencendo por X menor;
  - sprite anterior em OAM vencendo quando X empata;
  - composicao ate o decimo candidato continua preservada.

Regressoes executadas:

- `run_ppu_background_renderer.do` passou;
- `run_bus_controller.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou com 0 erros e 29 warnings.

Resultado de sintese:

- 3,831 / 6,272 LEs, 61%;
- 967 registradores, 15%;
- 180,224 / 276,480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- 0 multiplicadores;
- 1 / 2 PLLs;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 29.631 ns no clock VGA e 174.824 ns no clock CPU;
- pior hold slack: 0.445 ns no clock CPU e 0.453 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 3,809 LEs para 3,831 LEs, custo de +22 LEs;
- registradores: 955 para 967, custo de +12 registradores;
- memoria e M9K permaneceram iguais.

Conclusao tecnica:

O refino fecha uma diferenca importante de comportamento DMG sem criar uma
ordenacao paralela de 10 sprites. A escolha por acumulador serial conserva area
e combina com a arquitetura atual do renderer, que ja percorre os candidatos
por pixel. O custo ficou pequeno e nao pressiona o gargalo de M9K.

Proximo passo recomendado:

1. iniciar o caminho de ROM/boot para permitir programas maiores;
2. definir input direcional fisico;
3. usar ROMs alvo simples para decidir quais refinamentos PPU ainda sao
   realmente necessarios antes de investir em FIFO pixel-perfect.

## 29. Entrada Fisica por Teclado PS/2 para JOYP

Nesta etapa fechamos o primeiro caminho fisico completo de entrada para o
joypad. Os quatro botoes `key_n` continuam mapeados para A, B, Select e Start,
mas o direcional agora deixa de ser apenas sinal logico interno: o top atual
expoe `ps2_clk` e `ps2_data` e usa um decodificador PS/2 Set-2 enxuto.

Mapeamento implementado:

- `D` -> Right;
- `A` -> Left;
- `W` -> Up;
- `S` -> Down;
- `J` -> A;
- `K` -> B;
- Space -> Select;
- Enter -> Start.

Alteracoes feitas:

- novo modulo `ps2_keyboard_joypad.vhd`;
- novo teste `tb_ps2_keyboard_joypad.vhd`;
- novo script `run_ps2_keyboard_joypad.do`;
- `cpu_ppu_background_demo_top` agora instancia o decoder PS/2;
- PS/2 alimenta os sinais reais do JOYP no `bus_controller`;
- botoes de acao vindos do PS/2 sao combinados com os `key_n` fisicos;
- `pin_assignments.qsf` habilita `ps2_clk` em `PIN_119` e `ps2_data` em
  `PIN_120`;
- `timing.sdc` marca `ps2_clk` e `ps2_data` como entradas assincronas em false
  path;
- `quartus/gameboy_core.qsf` inclui o novo RTL.

Regressoes executadas:

- `run_ps2_keyboard_joypad.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `run_bus_controller.do` passou;
- `run_ppu_background_demo_top.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- build Quartus completo passou com 0 erros e 29 warnings.

Resultado de sintese:

- 3,887 / 6,272 LEs, 62%;
- 994 registradores, 16%;
- 180,224 / 276,480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- 0 multiplicadores;
- 1 / 2 PLLs;
- 17 / 92 pinos, 18%;
- TimeQuest totalmente constrained para setup e hold;
- pior setup slack: 29.313 ns no clock VGA e 173.511 ns no clock CPU;
- pior hold slack: 0.432 ns no clock CPU e 0.453 ns no clock VGA.

Comparacao com o checkpoint anterior:

- top completo: 3,831 LEs para 3,887 LEs, custo de +56 LEs;
- registradores: 967 para 994, custo de +27 registradores;
- pinos: 15 para 17, custo de +2 pinos;
- memoria e M9K permaneceram iguais.

Conclusao tecnica:

A escolha por PS/2 foi mais segura do que tentar usar DIP switches neste
momento, porque o arquivo de pinos registra que os DIP podem compartilhar os
mesmos quatro pinos dos botoes na revisao publica da placa. O PS/2 usa pinos
ja documentados, custa pouca logica e entrega um controle completo para testes
de jogos simples sem consumir M9K. O modulo ainda e intencionalmente simples:
decodifica make/break Set-2 e ignora sequencias estendidas, suficiente para o
mapeamento escolhido.

Proximo passo recomendado:

1. iniciar o caminho de ROM/boot para programas maiores e controlados;
2. preparar um ROM de teste visual/interativo que leia JOYP e mova um sprite;
3. depois disso, decidir se o proximo gargalo e ROM/cartridge/MBC ou refinamento
   de temporizacao da PPU.

## 30. Primeiro Controlador SDRAM Isolado

Nesta etapa iniciamos a linha correta para carregar ROMs maiores, incluindo o
Tetris ROM-only de 32 KiB, sem depender de cabo RS-232. A decisao arquitetural
e usar a SDRAM externa como armazenamento de cartucho e, em uma etapa posterior,
carregar os bytes via USB-Blaster/JTAG.

Escopo fechado nesta fatia:

- criar `sdram_controller.vhd`;
- manter o controlador isolado, ainda fora do top principal;
- validar inicializacao basica;
- validar escrita/leitura de palavra de 16 bits;
- validar `DQM`/byte enable;
- validar refresh periodico;
- criar testbench comportamental simples da SDRAM;
- adicionar script ModelSim dedicado.

Interface criada:

- `cmd_valid`;
- `cmd_write`;
- `cmd_addr[21:0]`, endereco linear em palavras de 16 bits;
- `write_data[15:0]`;
- `byte_enable[1:0]`;
- `ready`;
- `read_valid`;
- `read_data[15:0]`;
- `init_done`;
- sinais externos SDRAM: clock, CKE, CS/RAS/CAS/WE, DQM, BA, ADDR e DQ.

Comportamento validado:

- espera inicial parametrizavel;
- precharge-all;
- dois auto-refresh iniciais;
- load mode register;
- activate -> write -> precharge;
- activate -> read -> capture -> precharge;
- refresh automatico enquanto idle.

Regressoes executadas:

- `run_sdram_controller.do` passou.
- build Quartus completo do top atual passou com 0 erros e 29 warnings.

Recursos do top atual apos incluir a fonte no projeto:

- 3,887 / 6,272 LEs, 62%;
- 994 registradores, 16%;
- 180,224 / 276,480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- sem alteracao em relacao ao checkpoint PS/2, pois o controlador ainda nao e
  instanciado.

Observacoes tecnicas:

- o controlador foi adicionado ao `quartus/gameboy_core.qsf`, mas ainda nao e
  instanciado pelo `cpu_ppu_background_demo_top`;
- por isso, o top principal nao deve mudar recursos nesta fatia;
- os pinos SDRAM permanecem comentados em `pin_assignments.qsf` ate criarmos um
  top de teste fisico dedicado;
- esta escolha reduz risco: primeiro validamos o protocolo em simulacao, depois
  fazemos bring-up fisico com LEDs/SignalTap, e so entao ligamos ao mapper de
  ROM.

Conclusao tecnica:

Esta e a primeira fatia de M7. Ela nao roda Tetris ainda, mas cria a base
necessaria para chegar la de forma controlada. O caminho agora e:

1. top de teste fisico da SDRAM;
2. habilitar pinos SDRAM confirmados;
3. checker de escrita/leitura em hardware;
4. loader via Virtual JTAG;
5. mapper ROM-only para `0x0000..0x7FFF`;
6. carregar Tetris na SDRAM.

## 31. Top Fisico de Teste SDRAM

Nesta etapa fechamos a primeira ponte entre o controlador SDRAM simulado e a
placa fisica. A ideia foi manter o teste pequeno, observavel por LEDs e
separado do top principal do Game Boy, para validar a memoria externa antes de
coloca-la no caminho de cartucho.

Escopo fechado nesta fatia:

- criar `sdram_test_top.vhd`;
- expor os pinos fisicos da SDRAM em um arquivo QSF dedicado;
- criar um SDC temporario para o bring-up inicial;
- adicionar `cmd_accept` ao controlador para handshake real de comando aceito;
- escrever dois padroes de 16 bits em enderecos diferentes;
- ler e comparar os dois padroes;
- validar escrita parcial com `DQM` no byte baixo;
- reportar inicializacao, PASS, FAIL e refresh por LEDs;
- criar testbench de integracao com modelo comportamental simples de SDRAM;
- criar script Quartus dedicado para compilar o top de teste sem poluir o QSF
  principal.

Mapa dos LEDs no `sdram_test_top`:

- LED0 aceso: `init_done`;
- LED1 aceso: teste passou;
- LED2 aceso: teste falhou;
- LED3 aceso: pelo menos um refresh periodico foi observado.

Como os LEDs da placa sao active-low, o RTL dirige nivel baixo para acender o
indicador.

Regressoes executadas:

- `run_sdram_controller.do` passou;
- `run_sdram_test_top.do` passou;
- `build_sdram_test.tcl` passou com 0 erros;
- `build.tcl` do top principal passou com 0 erros.

Recursos do top fisico SDRAM:

- 243 / 6,272 LEs, 4%;
- 148 registradores, 2%;
- 0 bits de memoria interna;
- 0 M9Ks;
- 0 multiplicadores;
- 0 PLLs;
- 44 / 92 pinos, 48%.

Timing do top SDRAM:

- pior setup slack em 50 MHz: 13.950 ns;
- pior hold slack em 50 MHz: 0.453 ns;
- minimo pulse width em `clk_50mhz`: 9.741 ns;
- TimeQuest totalmente constrained para setup e hold internos.

Observacoes tecnicas:

- o clock externo da SDRAM foi dirigido como `not clk` para dar cerca de meio
  ciclo de acomodacao aos sinais registrados de comando, endereco e dados antes
  da borda de amostragem da memoria;
- o SDC de SDRAM ainda usa false paths para I/O externo. Isso e aceitavel para
  o primeiro teste funcional com LEDs, mas nao substitui constraints reais de
  interface SDRAM quando a memoria virar barramento de cartucho;
- os pinos SDRAM ficam em `constraints/sdram_pin_assignments.qsf` e nao sao
  mantidos no QSF principal;
- o script `build_sdram_test.tcl` salva o QSF original, aplica top/pinos/SDC
  temporariamente, compila e restaura o projeto principal ao final.

Proximo passo recomendado:

1. programar o `sdram_test_top` via USB-Blaster;
2. observar os quatro LEDs;
3. se LED1 acender e LED2 permanecer apagado, seguir para loader via Virtual
   JTAG;
4. se LED2 acender, capturar com SignalTap sinais como estado do checker,
   `init_done`, `cmd_valid`, `cmd_accept`, `ready`, `read_valid`, `read_data`
   e comandos SDRAM externos.

## 32. Nucleo de Loader ROM para SDRAM

Nesta etapa iniciamos o caminho do loader sem ainda acoplar o bloco ao
Virtual JTAG fisico. A decisao foi separar a logica de transporte da logica de
escrita em SDRAM: primeiro um nucleo recebe bytes, empacota em palavras de
16 bits e conversa com o `sdram_controller`; depois um wrapper pequeno de
Virtual JTAG fornecera esses bytes.

Escopo fechado nesta fatia:

- criar `sdram_rom_loader.vhd`;
- receber fluxo de bytes por `stream_valid`, `stream_data` e `stream_ready`;
- iniciar uma nova carga com `start`;
- finalizar a carga com `finish`;
- empacotar bytes em formato little-endian para SDRAM de 16 bits;
- emitir comandos de escrita com `sdram_cmd_valid`, `sdram_cmd_addr`,
  `sdram_write_data` e `sdram_byte_enable`;
- respeitar `sdram_cmd_accept` antes de avancar;
- esperar `sdram_ready` antes de aceitar os proximos bytes;
- suportar flush de byte impar final com `byte_enable = "01"`;
- reportar `busy`, `done`, `error` e `loaded_words`;
- criar testbench dedicado e script ModelSim.

Contrato de empacotamento:

- byte ROM 0 -> SDRAM word 0 bits `7 downto 0`;
- byte ROM 1 -> SDRAM word 0 bits `15 downto 8`;
- byte ROM 2 -> SDRAM word 1 bits `7 downto 0`;
- byte ROM 3 -> SDRAM word 1 bits `15 downto 8`;
- se a carga terminar com byte impar, apenas o byte baixo da ultima palavra e
  escrito.

Regressao executada:

- `run_sdram_rom_loader.do` passou.

Impacto no top principal:

- o novo arquivo foi adicionado ao QSF, mas ainda nao e instanciado pelo
  `cpu_ppu_background_demo_top`;
- portanto, o top principal deve permanecer no mesmo patamar de recursos ate a
  criacao do top fisico de loader.

Conclusao tecnica:

Esta fatia reduz risco antes do Virtual JTAG. Agora ja temos um contrato limpo:
qualquer transporte que entregue bytes com `valid/ready/start/finish` consegue
carregar uma ROM na SDRAM. A proxima etapa recomendada e criar o wrapper
Virtual JTAG minimo e um top fisico de loader que combine:

1. `sdram_controller`;
2. `sdram_rom_loader`;
3. wrapper Virtual JTAG;
4. LEDs de estado para init, loading, done e error.

## 33. Top Fisico de Loader ROM via Virtual JTAG

Nesta etapa criamos o primeiro caminho fisico para carregar bytes na SDRAM
usando apenas o USB-Blaster/JTAG. A implementacao ainda nao carrega um arquivo
`.gb` automaticamente pelo PC; ela fecha o hardware de recepcao, protocolo,
CDC e escrita em SDRAM. O script host vem na proxima fatia.

Escopo fechado nesta fatia:

- criar `virtual_jtag_rom_stream_core.vhd`;
- criar `virtual_jtag_rom_stream.vhd` como wrapper fino de `sld_virtual_jtag`;
- criar `sdram_jtag_loader_top.vhd`;
- criar `sdram_jtag_loader_timing.sdc`;
- criar `build_sdram_jtag_loader.tcl`;
- criar testbench do core de protocolo/CDC;
- validar o wrapper fisico com build Quartus completo.

Protocolo JTAG definido:

- IR `001`: DATA, desloca 8 bits de byte ROM;
- IR `010`: CONTROL, bit 0 gera `start`, bit 1 gera `finish`, bit 2 limpa erro
  de overflow;
- IR `011`: STATUS, retorna bits de estado;
- STATUS bit 0: stream pronto;
- STATUS bit 1: loader ocupado;
- STATUS bit 2: loader concluido;
- STATUS bit 3: erro do loader;
- STATUS bit 4: SDRAM inicializada;
- STATUS bit 5: byte pendente no dominio JTAG;
- STATUS bit 6: overflow de protocolo;
- STATUS bit 7: assinatura fixa em 1.

Decisao arquitetural importante:

O Virtual JTAG trabalha no dominio `altera_reserved_tck`, enquanto a SDRAM e o
loader trabalham em `clk_50mhz`. Por isso, o core usa toggle handshakes e
sincronizadores entre dominios, em vez de simplesmente amarrar `tdi/tdo` a
logica de 50 MHz. O dado de 8 bits fica estavel no dominio JTAG ate o dominio
de 50 MHz reconhecer a transferencia.

Mapa dos LEDs no `sdram_jtag_loader_top`:

- LED0 aceso: SDRAM inicializada;
- LED1 aceso: loader ocupado;
- LED2 aceso: carga concluida;
- LED3 aceso: erro de loader ou overflow de protocolo.

Regressoes executadas:

- `run_virtual_jtag_rom_stream_core.do` passou;
- `run_sdram_rom_loader.do` passou;
- `run_sdram_controller.do` passou;
- `run_sdram_test_top.do` passou;
- `build_sdram_jtag_loader.tcl` passou com 0 erros;
- `build.tcl` do top principal passou com 0 erros.

Recursos do top fisico Virtual JTAG loader:

- 473 / 6,272 LEs, 8%;
- 316 registradores, 5%;
- 0 bits de memoria interna;
- 0 M9Ks;
- 0 multiplicadores;
- 0 PLLs;
- 44 / 92 pinos, 48%.

Timing do top Virtual JTAG loader:

- pior setup slack em `clk_50mhz`: 13.508 ns;
- pior setup slack em `altera_reserved_tck`: 45.302 ns;
- pior hold slack: 0.453 ns;
- minimo pulse width em `clk_50mhz`: 9.735 ns;
- minimo pulse width em `altera_reserved_tck`: 49.442 ns;
- TimeQuest totalmente constrained para setup e hold depois do SDC dedicado.

Observacoes tecnicas:

- o top principal do Game Boy continua sem instanciar o loader;
- os pinos SDRAM continuam aplicados apenas durante o build dedicado;
- `sdram_jtag_loader_timing.sdc` marca o dominio JTAG e `clk_50mhz` como
  assincronos e mantem false paths temporarios para I/O SDRAM;
- a proxima etapa e criar o script host para enviar uma ROM via Virtual JTAG e
  observar `done/error` nos LEDs.

## 34. Script Host de Carga ROM via Virtual JTAG

Nesta etapa criamos o primeiro utilitario pratico do lado do PC para enviar uma
ROM `.gb` ao top fisico `sdram_jtag_loader_top` usando apenas o USB-Blaster.
Isto fecha o caminho operacional basico:

1. Quartus programa o bitstream do loader dedicado;
2. `quartus_stp` acessa a instancia `sld_virtual_jtag`;
3. o script le o arquivo `.gb`;
4. cada byte e enviado pelo IR DATA;
5. o hardware escreve os bytes empacotados na SDRAM.

Arquivo criado:

- `scripts/load_rom_virtual_jtag.tcl`.

Comando principal:

```text
quartus_stp -t scripts/load_rom_virtual_jtag.tcl caminho/rom.gb
```

Comando de validacao sem placa:

```text
quartus_stp -t scripts/load_rom_virtual_jtag.tcl --dry-run --max-bytes 16 caminho/rom.gb
```

Opcoes uteis:

- `--hardware-name <name>` seleciona manualmente o USB-Blaster;
- `--device-name <name>` seleciona manualmente o FPGA na cadeia JTAG;
- `--instance-index <n>` seleciona a instancia Virtual JTAG, padrao 0;
- `--max-bytes <n>` limita a carga para bring-up incremental;
- `--progress-step <n>` ajusta a frequencia dos logs de progresso;
- `--quiet` reduz saida textual.

Estrategia de transferencia:

- primeiro espera `STATUS bit 4 = 1`, indicando SDRAM inicializada;
- envia CONTROL bit 2 para limpar eventual overflow anterior;
- envia CONTROL bit 0 para iniciar uma nova carga;
- antes de cada byte, espera:
  - `stream_ready = 1`;
  - `pending = 0`;
  - `loader_error = 0`;
  - `overflow = 0`;
- envia o byte pelo IR DATA;
- ao final, espera o ultimo byte ser aceito e envia CONTROL bit 1 para
  finalizar;
- espera `done = 1`.

Esta estrategia e propositalmente conservadora. O objetivo desta fatia nao e
maximizar throughput JTAG; e reduzir ambiguidade no primeiro teste de placa. Se
algo falhar, o erro tende a ficar localizado em uma destas regioes:

- SDRAM nao inicializou;
- instancia Virtual JTAG nao foi encontrada;
- byte pendente nao foi consumido;
- overflow de protocolo;
- erro interno do loader.

Validacao executada:

- `quartus_stp -t scripts/load_rom_virtual_jtag.tcl --dry-run --max-bytes 16
  gb-test-roms-master\cpu_instrs\individual\01-special.gb` passou.

Limite importante:

Este script carrega bytes na SDRAM, mas ainda nao faz a CPU buscar instrucoes a
partir da SDRAM. A proxima fatia funcional e criar um caminho de leitura
ROM-only no barramento da CPU, inicialmente sem MBC, para ROMs de ate 32 KiB.

## 35. Leitor ROM-only da SDRAM para CPU

Nesta etapa criamos o primeiro caminho de leitura para a futura ROM de cartucho
armazenada na SDRAM. O objetivo nao foi ainda criar o top jogavel completo; foi
fechar o contrato minimo entre CPU/barramento e uma fonte ROM com latencia.

Arquivos criados:

- `rtl/memory/sdram_rom_reader.vhd`;
- `tb/memory/tb_sdram_rom_reader.vhd`;
- `sim/modelsim/run_sdram_rom_reader.do`.

Arquivos atualizados:

- `rtl/memory/bus_controller.vhd`;
- tops e testbenches que instanciam `bus_controller`;
- `quartus/gameboy_core.qsf`.

Contrato novo no `bus_controller`:

- `rom_data` continua fornecendo o byte da area `0x0000..0x7FFF`;
- `rom_ready` agora indica se esse byte esta valido;
- ROMs internas existentes usam `rom_ready = '1'`;
- uma ROM vinda de SDRAM pode segurar `rom_ready = '0'` e estender o ciclo da
  CPU ate a leitura completar.

Comportamento do `sdram_rom_reader`:

- aceita `cpu_addr` e `cpu_read`;
- atende apenas enderecos `0x0000..0x7FFF`;
- converte endereco de byte em endereco de palavra SDRAM:
  - `0x0000` e `0x0001` -> palavra SDRAM `0x0000`;
  - `0x7FFE` e `0x7FFF` -> palavra SDRAM `0x3FFF`;
- seleciona byte baixo para endereco par;
- seleciona byte alto para endereco impar;
- emite comando de leitura para o `sdram_controller`;
- espera `sdram_read_valid`;
- entrega o byte com `rom_ready = '1'`;
- mantem um cache simples de um byte para repetir uma leitura identica sem nova
  transacao SDRAM.

Validacao executada:

- `run_sdram_rom_reader.do` passou;
- `run_bus_controller.do` passou;
- `run_cpu_video_smoke_top.do` passou;
- `run_cpu_ppu_background_demo_top.do` passou;
- `build.tcl` do top principal passou com 0 erros.

Impacto de recursos no top principal:

- sem impacto medido no `cpu_ppu_background_demo_top`, porque o leitor SDRAM
  ainda nao esta instanciado no top principal;
- recursos continuam em 3.887 LEs, 994 registradores e 180.224 bits de memoria.

Limite atual:

Agora temos as duas metades isoladas:

```text
PC -> Virtual JTAG -> loader -> SDRAM
CPU -> bus -> sdram_rom_reader -> SDRAM
```

Mas ainda nao temos um top unico que permita carregar a ROM e depois liberar a
CPU para executa-la. A proxima etapa natural e criar um top dedicado de
experimento que combine SDRAM controller, Virtual JTAG loader, `sdram_rom_reader`
e CPU/bus, com uma chave/estado de selecao entre fase de carga e fase de
execucao.

## 36. Top load-then-execute com CPU buscando ROM da SDRAM

Nesta etapa fechamos o primeiro top unico que junta as duas metades isoladas da
fase anterior:

```text
PC -> Virtual JTAG -> loader -> SDRAM -> reader -> bus -> CPU
```

Arquivos criados:

- `rtl/top/sdram_cpu_rom_top.vhd`;
- `constraints/sdram_cpu_rom_timing.sdc`;
- `scripts/build_sdram_cpu_rom.tcl`.

Arquivo atualizado:

- `quartus/gameboy_core.qsf`, apenas para incluir o novo top na lista de fontes.

Arquitetura adotada:

- o top e dedicado a bring-up, separado do top principal com VGA/PPU;
- `virtual_jtag_rom_stream` recebe bytes do USB-Blaster;
- `sdram_rom_loader` empacota bytes em palavras SDRAM de 16 bits;
- `sdram_controller` inicializa, refresca e atende escrita/leitura;
- `sdram_rom_reader` converte fetches da CPU em leituras SDRAM;
- `bus_controller` usa `rom_data` e `rom_ready` vindos do reader;
- a CPU fica em reset ate:
  - SDRAM inicializada;
  - loader finalizado;
  - sem erro de loader;
  - sem erro de protocolo JTAG.

Decisao importante de clock:

- neste top inicial, SDRAM controller, loader, reader, CPU e bus rodam no
  dominio `clk_cpu`;
- isso evita CDC no caminho de leitura da ROM nesta primeira prova funcional;
- como o clock e lento, `G_REFRESH_INTERVAL` foi reduzido para 32 ciclos.

LEDs:

- durante carga/erro:
  - LED0 indica SDRAM inicializada;
  - LED1 indica loader busy;
  - LED2 indica loader done;
  - LED3 indica erro fatal;
- durante execucao sem erro, a ROM carregada pode escrever em `0xFF80` para
  dirigir o padrao de LEDs.

Comando de build dedicado:

```text
quartus_sh -t scripts\build_sdram_cpu_rom.tcl
```

O script:

- salva o QSF atual;
- muda temporariamente o top para `sdram_cpu_rom_top`;
- aplica os pinos SDRAM e o SDC dedicado;
- roda a compilacao completa;
- restaura o top principal e o QSF original ao final.

Validacao executada:

- `quartus_sh -t scripts\build_sdram_cpu_rom.tcl` passou com 0 erros;
- `quartus_sh -t scripts\build.tcl` passou com 0 erros depois disso.

Recursos do top dedicado:

- 3.159 LEs;
- 774 registradores;
- 134.144 bits de memoria;
- 1 PLL;
- setup slack minimo no clock CPU: 182,038 ns;
- hold slack minimo no clock CPU: 0,452 ns.

Recursos do top principal apos restauracao:

- 3.887 LEs;
- 994 registradores;
- 180.224 bits de memoria;
- 1 PLL.

Limites atuais:

- ainda nao e o top jogavel completo;
- nao ha PPU/VGA neste experimento;
- nao ha MBC;
- o alvo inicial deve ser uma ROM pequena/no-MBC ou uma ROM propria de teste
  que escreva em `0xFF80` para confirmar que a CPU realmente executou codigo
  vindo da SDRAM.

Proxima etapa recomendada:

1. gerar ou selecionar uma ROM minima de teste;
2. programar `sdram_cpu_rom_top` na placa;
3. carregar a ROM via `scripts/load_rom_virtual_jtag.tcl`;
4. confirmar nos LEDs a transicao de load para execucao;
5. so depois disso integrar a mesma ideia ao top com PPU/VGA.

## 37. ROM minima no-MBC para prova CPU -> SDRAM -> LED

Criamos uma ROM propria e reproduzivel para testar o top
`sdram_cpu_rom_top` antes de tentar Tetris.

Arquivos criados:

- `scripts/generate_minimal_led_rom.py`;
- `roms/minimal_led_blink.gb`;
- `roms/README.md`.

Caracteristicas da ROM:

- 32 KiB;
- cartridge type `0x00`, ou seja, `ROM ONLY`;
- ROM size code `0x00`, ou seja, 32 KiB;
- RAM size code `0x00`, sem RAM externa;
- titulo no header: `MINLED`;
- checksum de header: `0x2D`;
- checksum global: `0x2551`.

Programa:

```text
0x0000: JP 0x0150
0x0100: JP 0x0150
0x0150: DI
        LD SP,$DFFE
loop:   LD A,$05
        LDH ($80),A
        delay
        LD A,$0A
        LDH ($80),A
        delay
        JR loop
```

O salto em `0x0000` existe porque a CPU atual do projeto reseta PC em zero. O
salto em `0x0100` preserva o entry point padrao de cartucho Game Boy para
ferramentas e para uma futura etapa com boot/handoff mais realista.

Comando para regenerar:

```text
python scripts/generate_minimal_led_rom.py
```

Validacao executada:

- header conferido localmente;
- `quartus_stp -t scripts\load_rom_virtual_jtag.tcl --dry-run --max-bytes 32
  roms\minimal_led_blink.gb` passou;
- `quartus_stp -t scripts\load_rom_virtual_jtag.tcl --dry-run
  roms\minimal_led_blink.gb` passou para os 32 KiB completos;
- simulação curta com `tb_cpu_rom_runner` carregou a ROM sem erro de opcode no
  trecho inicial executado.

Uso esperado em hardware:

1. compilar/programar `sdram_cpu_rom_top`;
2. carregar `roms/minimal_led_blink.gb` pela Virtual JTAG;
3. observar os LEDs alternando entre os padroes derivados de `0x05` e `0x0A`.

Se isso funcionar, teremos prova pratica de:

```text
PC -> USB-Blaster -> Virtual JTAG -> SDRAM -> sdram_rom_reader -> bus -> CPU
```

Nesse ponto, Tetris passa a ser o proximo teste no-MBC realista, mas ainda
depende de integrar o mesmo caminho SDRAM-ROM ao top com PPU/VGA.

## 38. Primeiro carregamento real da ROM LED via USB-Blaster

Executamos o primeiro teste real de placa com `sdram_cpu_rom_top` e
`roms/minimal_led_blink.gb`.

Sequencia executada:

```text
quartus_sh -t scripts\build_sdram_cpu_rom.tcl
quartus_pgm -l
quartus_pgm -m jtag -o "p;quartus\output_files\gameboy_core.sof"
quartus_stp -t scripts\load_rom_virtual_jtag.tcl --progress-step 4096 roms\minimal_led_blink.gb
```

Resultado:

- USB-Blaster detectado como `USB-Blaster [USB-0]`;
- FPGA `EP4CE6E22` configurada com sucesso;
- carga completa de 32 KiB concluida pela Virtual JTAG;
- status inicial do loader: `0x90`, ou seja, SDRAM init + assinatura;
- progresso confirmado a cada 4096 bytes;
- status final: `0x94`, ou seja, loader done + SDRAM init + assinatura.

Bug encontrado durante o primeiro teste:

- a primeira tentativa de leitura STATUS retornou `0x20`;
- esse valor era compativel com o status real deslocado por um bit;
- causa: `vj_tdo` era registrado no mesmo edge de shift, atrasando a primeira
  amostra de STATUS no `sld_virtual_jtag`;
- correcao: `vj_tdo` agora e dirigido combinacionalmente por
  `status_shift_reg(0)` durante `IR_STATUS` + `vj_state_sdr`;
- o testbench `tb_virtual_jtag_rom_stream_core` foi ajustado para amostrar TDO
  no momento correto do shift.

Validacao apos correcao:

- `run_virtual_jtag_rom_stream_core.do` passou;
- `build_sdram_cpu_rom.tcl` passou;
- `quartus_pgm` configurou a FPGA com 0 erros;
- `load_rom_virtual_jtag.tcl` carregou `minimal_led_blink.gb` com 0 erros.

Recursos do top dedicado apos a correcao:

- 3.158 LEs;
- 773 registradores;
- 134.144 bits de memoria;
- 1 PLL.

Leitura importante:

Agora temos prova de carga real:

```text
PC -> USB-Blaster -> Virtual JTAG -> SDRAM
```

O proximo ponto de observacao fisica e visual: confirmar nos LEDs da placa se a
CPU saiu do reset e alternou os padroes escritos pela ROM em `0xFF80`. Se os
LEDs nao alternarem, o problema fica localizado no trecho:

```text
SDRAM -> sdram_rom_reader -> bus_controller -> CPU execute -> 0xFF80
```

## 39. Debug do reader SDRAM-ROM durante execucao real da CPU

Esta foi uma das primeiras falhas de bring-up realmente representativas do
projeto, porque a carga da ROM funcionava, a SDRAM inicializava e a CPU chegava
a escrever em `0xFF80`, mas a execucao nao avancava de forma confiavel ate o
checkpoint final.

Sintoma observado em hardware:

- `load_rom_virtual_jtag.tcl` concluia com status final `0x94`;
- o caminho `PC -> USB-Blaster -> Virtual JTAG -> SDRAM` estava confirmado;
- os LEDs indicavam que a CPU fazia ao menos uma escrita em `0xFF80`;
- porem a ROM minima nao chegava claramente ao padrao final esperado.

Metodo de diagnostico:

- reduzir a ROM minima para checkpoints deterministas;
- testar primeiro `LD A,$0F` + `LDH ($80),A`;
- depois remover a dependencia do imediato usando varias instrucoes `INC A`;
- instrumentar `sdram_cpu_rom_top` para resumir nos LEDs:
  - fetch do checkpoint final;
  - quantidade de writes em `0xFF80`;
  - registrador `A = 0x0F`;
  - ausencia de erro fatal;
- criar `tb_cpu_minimal_led_rom` para provar que o CPU puro executa a sequencia;
- reforcar `tb_sdram_rom_reader` com o caso de troca de endereco mantendo
  `cpu_read` ativo.

Causa raiz:

O `sdram_rom_reader` podia manter `rom_ready` ativo para o byte do endereco
anterior enquanto a CPU ja havia avancado para o proximo endereco de fetch. Como
o barramento nao carrega uma tag de endereco junto com o dado, a CPU podia
aceitar byte antigo como se fosse valido para o endereco atual.

Correcao aplicada:

```vhdl
rom_ready <= ready_reg when cpu_read = '1' and cpu_addr = addr_reg else '0';
```

Validacao:

- `run_sdram_rom_reader.do` passou;
- `run_cpu_minimal_led_rom.do` passou;
- `build_sdram_cpu_rom.tcl` passou com timing fechado;
- apos programar o bitstream e carregar a ROM via Virtual JTAG, os 4 LEDs
  ficaram acesos no resumo de execucao.

Significado dos 4 LEDs acesos no resumo:

- checkpoint final de fetch alcancado;
- ao menos quatro writes em `0xFF80`;
- registrador `A` chegou a `0x0F`;
- nenhum erro fatal.

Licao tecnica:

Esta falha deve ser mencionada no TCC como exemplo de debug incremental de
hardware. O problema nao estava em um bloco grande como CPU, SDRAM ou loader,
mas em um contrato de validade de um bit na fronteira entre modulos. A solucao
veio de reduzir o programa, tornar o progresso observavel em hardware e depois
transformar o caso em regressao de simulacao.

## 40. Primeiro top integrado SDRAM-ROM com video

Criamos o primeiro top dedicado que une o caminho de ROM em SDRAM com o caminho
visual ja existente do projeto.

Top novo:

```text
sdram_video_rom_top
```

Fluxo integrado:

```text
PC -> USB-Blaster -> Virtual JTAG -> SDRAM loader -> SDRAM
SDRAM -> sdram_rom_reader -> bus_controller -> CPU
CPU -> VRAM/OAM/PPU registers -> PPU -> framebuffer -> VGA
```

O objetivo desta fatia nao e ainda rodar Tetris diretamente, mas remover a
separacao artificial entre dois checkpoints anteriores:

- `sdram_cpu_rom_top`, que provava execucao da CPU a partir da SDRAM;
- `cpu_ppu_background_demo_top`, que provava o caminho visual CPU/PPU/VGA.

Decisoes de arquitetura:

- manter um top dedicado de bring-up, sem trocar o top canonico do projeto;
- segurar a CPU em reset ate a SDRAM inicializar e o loader finalizar;
- reutilizar o contrato `rom_ready` do `bus_controller`, em vez de criar um
  caminho paralelo especial para cartucho;
- manter o SDRAM controller no clock da CPU durante esta fase para evitar CDC
  adicional no primeiro bring-up integrado;
- preservar o start do renderer pelo bit de debug ja usado no projeto
  (`0xFF80`, bit 0), para que uma ROM minima possa preparar VRAM/registradores
  e depois liberar o PPU.

Resultado de build Quartus:

- `scripts/build_sdram_video_rom.tcl` passou com 0 erros;
- top sintetizado: `sdram_video_rom_top`;
- 4.372 / 6.272 LEs, 70%;
- 1.379 registradores;
- 180.224 / 276.480 bits de memoria, 65%;
- 24 / 30 M9Ks, 80%;
- 1 / 2 PLLs;
- pior setup slack no clock VGA: 29,202 ns;
- pior setup slack no clock CPU: 179,383 ns;
- pior hold slack: 0,451 ns.

Leitura do checkpoint:

O projeto agora tem o primeiro ponto compilavel onde uma ROM carregada pela
USB-Blaster pode, em principio, programar o estado de video do Game Boy e ser
exibida via VGA. Ainda falta validar esse caminho em hardware com uma ROM visual
minima. A diferenca e importante: ja temos a estrutura integrada, mas ainda nao
temos a prova fisica de imagem vinda de uma ROM carregada na SDRAM.

Proxima etapa recomendada:

Criar uma ROM minima no-MBC para o novo top. Ela deve escrever tile data, tile
map, `LCDC`, `BGP`, `SCX/SCY` e, ao final, escrever em `0xFF80` para iniciar o
renderer. Depois disso, programar `sdram_video_rom_top`, carregar a ROM pela
Virtual JTAG e observar se a imagem aparece na VGA.

## 41. ROM visual minima para o top SDRAM/video

Criamos a primeira ROM propria do projeto para validar imagem vinda do caminho
SDRAM-ROM, e nao mais de uma ROM interna em VHDL.

Arquivos adicionados:

- `scripts/generate_minimal_visual_rom.py`;
- `roms/minimal_visual.gb`;
- `tb/cpu/tb_cpu_minimal_visual_rom.vhd`;
- `sim/modelsim/run_cpu_minimal_visual_rom.do`.

Comportamento da ROM:

- imagem `ROM ONLY`, 32 KiB, sem MBC;
- salto em `0x0000` e `0x0100` para o programa em `0x0150`;
- desliga `LCDC` antes de preparar VRAM;
- limpa o tile 0 em `0x8000..0x800F`;
- escreve o tile 1 quadriculado em `0x8010..0x801F`;
- limpa a background map `0x9800..0x9BFF`;
- escreve a primeira linha alternando tile 1 e tile 0;
- configura `BGP = 0xFC`, `SCY = 1`, `SCX = 8` e `LCDC = 0x91`;
- escreve `0x01` em `0xFF80` para liberar o renderer atual;
- estaciona em `JR $`.

Validacao executada:

- `python scripts\generate_minimal_visual_rom.py` gerou uma ROM de 32 KiB;
- `vsim -c -do run_cpu_minimal_visual_rom.do` passou;
- o testbench confirmou writes de VRAM, conteudo final do tile map, registradores
  `BGP/SCY/SCX/LCDC` e o marcador `0xFF80 = 0x01`;
- `quartus_stp -t scripts\load_rom_virtual_jtag.tcl --dry-run --max-bytes 32
  roms\minimal_visual.gb` passou;
- `quartus_stp -t scripts\load_rom_virtual_jtag.tcl --dry-run
  roms\minimal_visual.gb` passou para a ROM completa.

Proximo teste fisico recomendado:

```text
quartus_sh -t scripts\build_sdram_video_rom.tcl
quartus_pgm -m jtag -o "p;quartus\output_files\gameboy_core.sof"
quartus_stp -t scripts\load_rom_virtual_jtag.tcl --progress-step 4096 roms\minimal_visual.gb
```

Resultado esperado:

- loader finaliza com status de done;
- os LEDs devem indicar SDRAM init, loader done, renderer start e frame visto,
  conforme o resumo ativo do `sdram_video_rom_top`;
- a VGA deve mostrar a area Game Boy centralizada com a primeira linha de tiles
  alternando branco/quadriculado, deslocada por `SCX = 8`.

Leitura do checkpoint:

Esta ROM fecha a ponte entre o mundo "programa interno de demo" e o mundo
"cartucho carregado pela USB-Blaster". Se a imagem aparecer no monitor, teremos
prova pratica do caminho:

```text
PC -> USB-Blaster -> Virtual JTAG -> SDRAM -> CPU -> VRAM -> PPU -> VGA
```

## 42. Validacao visual em hardware com ROM carregada na SDRAM

Executamos o teste fisico do caminho `sdram_video_rom_top` com a ROM
`roms/minimal_visual.gb`.

Comandos executados:

```text
quartus_pgm -m jtag -o "p;quartus\output_files\gameboy_core.sof"
quartus_stp -t scripts\load_rom_virtual_jtag.tcl --progress-step 4096 roms\minimal_visual.gb
```

Resultado do loader:

- status inicial: `0x90`, indicando `sdram_init` e assinatura do protocolo;
- 32 KiB transferidos para a SDRAM;
- status final: `0x94`, indicando `done`, `sdram_init` e assinatura.

Observacao em hardware:

- os 4 LEDs da placa ficaram acesos;
- a VGA exibiu a area Game Boy centralizada;
- a primeira linha visivel apresentou o padrao esperado de tiles alternando
  branco e quadriculado, conforme a ROM minima visual.

Significado dos 4 LEDs acesos neste top:

- SDRAM inicializada;
- loader finalizado;
- CPU escreveu o marcador de start em `0xFF80`;
- PPU concluiu ao menos um frame.

Leitura do checkpoint:

Este e o primeiro marco em que uma ROM carregada pelo PC via USB-Blaster passa
por SDRAM, e nao por ROM interna em VHDL, e ainda assim produz imagem real no
monitor VGA. Na pratica, o caminho abaixo foi validado em hardware:

```text
PC -> USB-Blaster -> Virtual JTAG -> SDRAM -> CPU -> VRAM -> PPU -> framebuffer -> VGA
```

Isso nao significa que Tetris ja deve rodar sem ajustes, mas significa que o
caminho de cartucho no-MBC ate video esta funcional para uma ROM minima
controlada. A proxima etapa recomendada e aproximar essa ROM minima de um
ambiente de jogo simples: remover dependencias de debug quando possivel,
confirmar interrupcoes/VBlank usadas por jogos reais e entao tentar uma ROM
no-MBC pequena com comportamento mais proximo de software comercial.
