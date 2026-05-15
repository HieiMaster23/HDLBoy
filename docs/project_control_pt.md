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
- WRAM inicial reduzida por restrição de recursos;
- HRAM e stubs de I/O;
- IE e IF básicos;
- timer DMG inicial extraído para `rtl/io/timer.vhd`, com DIV/TIMA/TMA/TAC,
  seleção por TAC e pulso de interrupção de timer;
- serial debug stub em `0xFF01` e `0xFF02`;
- runner de ROM em simulação carregando ROMs `.gb` reais e emitindo `Passed`
  via serial;
- pacote local de ROMs Blargg baixado em `gb-test-roms-master`;
- Blargg `cpu_instrs` individuais `01`, `02`, `03`, `04`, `05`, `06`, `07`,
  `08`, `09`, `10` e `11` passando via transcript serial.

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

Validação rápida executada nesta sessão:

- `run_timer.do` — Passed;
- `run_bus_controller.do` — Passed;
- `run_cpu_blargg_02.do` — Passed com o timer novo;
- `run_cpu_blargg_03.do` — Passed;
- `run_cpu_blargg_04.do` — Passed;
- `run_cpu_blargg_05.do` — Passed;
- `run_cpu_blargg_06.do` — Passed.

Ainda falta antes de checkpoint:

- repetir pelo menos `08-misc instrs.gb`;
- repetir os testes longos `01`, `07`, `09`, `10` e `11` quando houver tempo;
- rodar `cpu_video_smoke_top`;
- rodar Quartus para medir impacto de recursos do timer novo;
- atualizar o commit/checkpoint após a regressão combinada.

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
- janela experimental de framebuffer/VRAM em `0x8000`;
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
- display de sete segmentos mostrando `1234` em caso de sucesso.

Ainda pendente:

- PPU real;
- VRAM real com tile data;
- tile map;
- sprites;
- window;
- modos da PPU;
- VBlank;
- STAT;
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

- consolidar por etapas os testes individuais, usando `03`, `04`, `05`, `06` e
  `08` como regressão rápida;
- repetir os testes longos em uma rodada separada: `01`, `02`, `07`, `09`, `10`
  e `11`;
- tratar a ROM agregada `cpu_instrs.gb` como validação longa opcional;
- depois do checkpoint do timer inicial, avançar para `instr_timing`,
  `mem_timing`, `interrupt_time` e `halt_bug`.

## 6. Linha de Evolução do Projeto

### Etapa Atual: M3/M4 de Transição

Estamos na transição entre:

- M3: CPU LR35902;
- M4: barramento e mapa de memória.

O foco imediato não é jogo e não é PPU. O foco é fazer a CPU executar programas
de teste cada vez mais próximos de ROMs reais.

### Próxima Linha de Trabalho

1. Usar o runner de ROM real como ferramenta principal de M3.
2. Avançar pela lista Blargg individual por evidência.
3. Implementar apenas a menor fatia exigida por cada falha real.
4. Manter scripts específicos para ROMs longas quando necessário.
5. Atualizar documentação após cada conjunto de ROMs que passa.

Depois disso:

1. consolidar a regressão individual `cpu_instrs` por grupos;
2. fechar o timer DMG inicial com regressões e síntese;
3. usar a ROM agregada `cpu_instrs.gb` apenas como teste longo de checkpoint;
4. avançar para timing, `HALT` bug, joypad, interrupções com precisão maior e
   PPU.

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

Não começar por:

- `instr_timing`;
- `mem_timing`;
- `interrupt_time`;
- `halt_bug.gb`;
- `oam_bug`;
- `dmg_sound`;
- `cgb_sound`.

Esses grupos dependem de timer, temporização exata, interrupções, PPU/OAM ou
APU, e pertencem a fases posteriores.

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
Preparar e executar gb-test-roms-master\cpu_instrs\individual\02-interrupts.gb
no tb_cpu_rom_runner, capturando a saída serial via 0xFF01/0xFF02 até obter
Passed, Failed ou a primeira falha útil.
```

Resultado:

- `02-interrupts.gb` chegou a `Passed`;
- a CPU agora aceita interrupções quando `IME=1` e `IE & IF` possui bit
  pendente;
- a prioridade inicial segue a ordem VBlank, STAT, Timer, Serial e Joypad;
- o atendimento empilha o PC, limpa IME, salta para `0x40/0x48/0x50/0x58/0x60`
  e emite `interrupt_ack`;
- `RETI` reativa IME;
- `EI` mantém atraso básico;
- `HALT` sai quando há interrupção pendente;
- o runner e o barramento inicial possuem timer inicial e limpeza de IF.

## 14. Próximo Alvo Oficial

O próximo alvo oficial recomendado é:

```text
Fechar a fatia do timer DMG inicial e consolidar a regressão Blargg individual
por grupos, sem depender da ROM agregada como teste diário.
```

Critério de sucesso:

- manter os rápidos `03`, `04`, `05`, `06` e `08` passando;
- repetir os longos `01`, `02`, `07`, `09`, `10` e `11` antes do checkpoint;
- manter `run_timer.do` passando;
- não regredir `cpu_video_smoke_top`;
- manter build Quartus sem erro;
- documentar a ROM agregada como teste longo opcional;
- medir impacto de recursos do timer novo no EP4CE6;
- definir a próxima fatia entre `instr_timing`, `mem_timing`,
  `interrupt_time` e `halt_bug`.

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
