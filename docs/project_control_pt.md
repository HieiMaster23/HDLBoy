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

Checkpoint pronto para formalização:

- a escada local de CPU/timing disponível no pacote Blargg foi concluída;
- o conjunto de regressão relevante está registrado acima;
- o próximo passo recomendado após o commit é abrir a primeira fatia real de
  PPU.

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
- progressão explícita por 144 scanlines visíveis no renderer de background,
  ainda sem temporização por dot;
- `LY` e `STAT` mínimos visíveis pela CPU;
- modos iniciais 2, 3, 0 e 1 visíveis em `STAT`;
- IF bit 0 solicitado na entrada de VBlank inicial;
- IF bit 1 solicitado por condições STAT habilitadas;
- display de sete segmentos mostrando `1234` em caso de sucesso.

Ainda pendente:

- PPU dot-accurate com modos reais;
- scroll completo dentro do modelo temporal real da PPU;
- sprites;
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
por `SCX`/`SCY`, progressão explícita por scanlines visíveis, um scheduler
inicial de modos 2, 3, 0 e 1, e solicitações iniciais de VBlank/STAT. Ainda não
possui temporização por dot, sprites, window, comportamento LCD completo ou DMA.

### Próxima Linha de Trabalho

1. Preservar a suíte Blargg de CPU/timing como regressão obrigatória.
2. Refinar o scheduler de modos em direção a contagens reais de dot.
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
