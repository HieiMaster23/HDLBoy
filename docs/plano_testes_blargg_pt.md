# Plano de Progressão para Testes Blargg

Este documento registra a análise local do pacote `gb-test-roms-master` e define
como vamos progredir dos testes próprios do projeto até os testes reais do
Blargg.

## 1. Pacote Encontrado

O pacote está em:

`C:\Users\Rafael\Documents\Projetos\Vhdlboy\gb-test-roms-master`

A estrutura principal encontrada foi:

- `cpu_instrs`: testes de comportamento das instruções da CPU.
- `instr_timing`: testes de tempo de execução das instruções.
- `mem_timing`: testes de temporização de acesso à memória.
- `mem_timing-2`: outra versão dos testes de temporização de memória.
- `interrupt_time`: teste de tempo de interrupções.
- `halt_bug.gb`: teste específico do comportamento de `HALT`.
- `dmg_sound`: testes de áudio para DMG.
- `cgb_sound`: testes de áudio para CGB.
- `oam_bug`: testes de comportamento do bug de OAM.

Para o estágio atual do projeto, o alvo correto é `cpu_instrs`, especialmente
as ROMs individuais dentro de:

`gb-test-roms-master\cpu_instrs\individual`

Essas ROMs individuais têm 32 KiB e não exigem MBC para começar. Isso é melhor
para o nosso estágio atual do que usar primeiro a ROM agregada `cpu_instrs.gb`,
que tem 64 KiB.

## 2. Saída dos Testes

Os readmes confirmam que os testes imprimem texto na tela e também enviam tudo
pela serial do Game Boy:

- `0xFF01`: SB, byte de dados serial.
- `0xFF02`: SC, controle serial.
- escrita de `$81` em `0xFF02`: inicia a transferência.

Isso encaixa diretamente com o stub serial que já criamos no projeto. Portanto,
o caminho de validação deve ser:

1. Rodar a ROM em simulação.
2. Capturar writes em `0xFF01` e `0xFF02`.
3. Montar um transcript textual.
4. Procurar `Passed`, `Failed`, códigos de falha ou opcodes reportados.

Não precisamos de PPU funcional para começar a usar a saída textual dos testes.

## 3. Ponto Crítico: O Shell do Blargg

Mesmo uma ROM individual do Blargg não começa testando diretamente apenas um
opcode. Ela usa um shell comum, localizado em:

`gb-test-roms-master\cpu_instrs\source\common`

Esse shell faz várias coisas antes do teste principal:

- entra em `0x0100` com `NOP; JP $0213`;
- executa código de inicialização;
- copia aproximadamente 4 KiB de ROM de `0x4000` para `0xC000`;
- passa a executar parte do código a partir da WRAM;
- usa stack em torno de `0xDFFF`;
- usa variáveis em torno de `0xD800`;
- imprime resultados pela serial e pelo console de vídeo.

Consequência: não basta implementar a instrução testada. Precisamos ter um
conjunto mínimo de suporte para o shell conseguir rodar.

## 4. Bloqueios Atuais Antes de Rodar Blargg Real

O projeto já tem uma boa base, mas ainda existem bloqueios importantes para
rodar uma ROM Blargg sem adaptação:

- WRAM atual no hardware é apenas uma página pequena. O Blargg precisa de WRAM
  real em `0xC000..0xDFFF`, pelo menos em simulação.
- A CPU ainda não tem várias instruções usadas pelo shell:
  - `LD A,(HL+)`
  - `LD A,(HL-)`
  - `LD (HL+),A`
  - `LD (HL-),A`
  - `LD (BC),A`
  - `LD (DE),A`
  - `LD A,(BC)`
  - `LD A,(DE)`
  - `LD rr,nn` para `BC` e `DE`
  - `INC rr` e `DEC rr`
  - `ADD HL,rr`
  - branches condicionais
  - returns condicionais
  - `JP HL`
  - `LD SP,HL`
  - `LD (nn),SP`
  - `CPL`, `SCF`, `CCF`, `DAA`
  - `ADC`, `SBC`
  - rotates não-CB
  - CB-prefix completo
- O timer ainda não é funcional o suficiente para `instr_timing`,
  `mem_timing`, `interrupt_time` e `halt_bug`.
- Interrupções ainda não fazem push de PC nem salto para vetores.
- O comportamento completo de `HALT`, `EI`, `DI` e `RETI` ainda está
  incompleto.

## 5. Ordem Recomendada dos Testes

### Fase A: Preparação do Runner

Antes de mirar uma ROM Blargg, precisamos melhorar o runner:

1. Criar um mecanismo para converter `.gb` em uma ROM de simulação.
2. Permitir carregar pelo menos uma ROM individual de 32 KiB.
3. Iniciar a CPU em `0x0100` ou permitir que ela execute NOPs até `0x0100`.
4. Usar uma memória de simulação de 64 KiB.
5. Capturar transcript serial.
6. Parar a simulação quando encontrar `Passed`, `Failed` ou timeout.

Essa fase é infraestrutura de simulação e não deve consumir recursos do FPGA.

### Fase B: Fazer o Shell do Blargg Respirar

O primeiro objetivo não é passar um teste Blargg. É fazer a ROM avançar pelo
shell comum e começar a imprimir algo pela serial.

Para isso, devemos priorizar:

1. `LD rr,nn` para `BC`, `DE`, `HL`, `SP`.
2. `LD A,(BC)`, `LD A,(DE)`, `LD (BC),A`, `LD (DE),A`.
3. `LD A,(HL+)`, `LD A,(HL-)`, `LD (HL+),A`, `LD (HL-),A`.
4. `INC rr` e `DEC rr`.
5. `JP HL`.
6. Branches condicionais:
   - `JR NZ,e`, `JR Z,e`, `JR NC,e`, `JR C,e`;
   - `JP NZ,nn`, `JP Z,nn`, `JP NC,nn`, `JP C,nn`.
7. `CALL` e `RET` condicionais.
8. `LD (nn),SP`.
9. `LD SP,HL`.

Quando isso estiver funcionando, o shell deve conseguir copiar código para WRAM
e chegar mais perto dos testes reais.

### Fase C: Primeiro Alvo Blargg Real

O primeiro alvo recomendado é:

`cpu_instrs\individual\06-ld r,r.gb`

Motivo:

- O teste específico cobre `LD r,r`, que já está quase todo implementado.
- Ainda assim, ele força o shell e o framework de CRC a funcionarem.
- Se ele falhar, a falha provavelmente estará no suporte do shell, no CRC ou em
  algum detalhe de memória/flags, não necessariamente no grupo `LD r,r`.

Esse teste será um excelente divisor de águas: quando ele imprimir `Passed`,
teremos provado que a CPU já sustenta uma parte relevante do ecossistema Blargg.

### Fase D: Próximos Testes de CPU

Depois de `06-ld r,r.gb`, a ordem mais racional é:

1. `04-op r,imm.gb`
   - exige `LD (HL),n` e ALU imediata (`ADD n`, `ADC n`, `SUB n`, `SBC n`,
     `AND n`, `XOR n`, `OR n`, `CP n`).
2. `08-misc instrs.gb`
   - testa `LDH`, `LD (nn),A`, `LD A,(nn)`, stack, `LD rr,nn`, `LD (nn),SP`,
     `LD (C),A`, `LD A,(C)`.
3. `05-op rp.gb`
   - testa `INC rr`, `DEC rr`, `ADD HL,rr`.
4. `03-op sp,hl.gb`
   - testa operações específicas com `SP` e `HL`.
5. `07-jr,jp,call,ret,rst.gb`
   - testa controle de fluxo, condicionais, `RST` e `RETI`.
6. `09-op r,r.gb`
   - testa ALU entre registradores, `ADC`, `SBC`, `CPL`, `SCF`, `CCF`,
     rotates e parte de CB.
7. `11-op a,(hl).gb` — Passed
   - testa acessos indiretos via `HL`, ALU com `(HL)`, `DAA` e CB em `(HL)`.
8. `10-bit ops.gb` — Passed
   - testa `BIT`, `RES` e `SET` em registradores.
9. `01-special.gb` — próximo alvo
   - inclui casos especiais como `JR`, `JP HL`, `POP AF` e `DAA`.
10. `02-interrupts.gb`
   - deve ficar para depois do timer e do controlador de interrupções.

Essa ordem não é a ordem numérica original. É a ordem mais adequada para o
estado atual do nosso core.

## 6. Testes Que Devem Ficar Para Depois

Os seguintes grupos não devem ser priorizados agora:

- `instr_timing`
- `mem_timing`
- `mem_timing-2`
- `interrupt_time`
- `halt_bug.gb`
- `oam_bug`
- `dmg_sound`
- `cgb_sound`

Motivo:

- `instr_timing` depende de timer funcional e temporização por ciclo.
- `mem_timing` depende de acessos de memória nos ciclos corretos.
- `interrupt_time` depende de interrupções reais.
- `halt_bug` depende do comportamento exato de `HALT`.
- `oam_bug` depende de PPU/OAM.
- `dmg_sound` e `cgb_sound` dependem de APU.

Esses testes são valiosos, mas pertencem a fases posteriores.

## 7. Próximo Passo Concreto

O próximo passo de implementação deve ser:

1. Rodar `cpu_instrs\individual\01-special.gb` no `tb_cpu_rom_runner`.
2. Capturar `Passed`, `Failed` ou a primeira falha útil via serial.
3. Se falhar, implementar apenas a menor correção necessária.
4. Repetir os testes curtos de CPU e as ROMs `10-bit ops`/`11-op a,(hl)`.
5. Atualizar este plano e o controle central.

Esse ciclo deve guiar a expansão da CPU a partir de agora.

## 8. Critério de Sucesso da Fase Atual

A fase atual estará concluída quando:

- `01-special.gb` chegar a `Passed` ou falhar com uma mensagem serial
  compreensível;
- `10-bit ops.gb` e `11-op a,(hl).gb` continuarem passando depois das mudanças;
- `DAA` continuar coberto por teste unitário de ALU;
- CB `(HL)` continuar coberto por smoke test de CPU e por Blargg.

Falhas em `02-interrupts.gb` ainda pertencem à fase seguinte, porque dependem
de interrupções completas, timer e comportamento exato de `EI`/`HALT`.
## 9. Progresso em 2026-05-14

O primeiro alvo Blargg real passou em simulação:

- ROM: `gb-test-roms-master/cpu_instrs/individual/06-ld r,r.gb`
- Runner: `tb/cpu/tb_cpu_rom_runner.vhd`
- Script: `sim/modelsim/run_cpu_rom_runner.do`
- Resultado serial observado: `06-ld r,r`, linha em branco, `Passed`

Fatia implementada para isso:

- carga binária direta de ROM `.gb` no testbench;
- memória completa de simulação com escrita em WRAM/VRAM/HRAM;
- captura serial por `FF01/FF02`;
- stubs de I/O suficientes para o shell, incluindo `LY`/`DIV` de simulação;
- `LD rr,nn` para BC/DE/HL/SP;
- loads indiretos por BC/DE e HL com incremento/decremento;
- `INC rr`, `DEC rr`, `ADD HL,rr`;
- branches, jumps, calls e returns condicionais;
- `JP HL`;
- ALU imediata;
- `ADC`/`SBC`;
- rotates de A;
- CB-prefix para operações em registradores.

Próximo alvo recomendado:

`cpu_instrs/individual/04-op r,imm.gb`

Motivo: depois de `06-ld r,r`, o próximo ganho natural é consolidar operações
imediatas e `LD (HL),n`. A infraestrutura do runner já está pronta; daqui em
diante o ciclo deve ser rodar a ROM, observar o primeiro opcode ou divergência
real e implementar a menor fatia correta.

## 10. Progresso adicional em 2026-05-14

Novas ROMs individuais Blargg passaram via transcript serial:

- `04-op r,imm.gb`
- `08-misc instrs.gb`
- `05-op rp.gb`
- `03-op sp,hl.gb`
- `07-jr,jp,call,ret,rst.gb`

Fatia adicional implementada:

- `LD (HL),n`;
- `LDH (C),A` e `LDH A,(C)`;
- `LD (nn),SP`;
- `LD SP,HL`;
- `ADD SP,e`;
- `LD HL,SP+e`;
- `RETI`;
- `RST` para todos os vetores de `00h` a `38h`;
- `CPL`, `SCF`, `CCF`;
- máscara de boot no runner: antes de chegar a `0x0100`, o testbench entrega
  `NOP` em `0x0000..0x00FF`; depois disso os vetores reais da ROM ficam
  visíveis. Isso é necessário para ROMs como `07-jr,jp,call,ret,rst.gb`, que
  colocam handlers `RST` na página zero.

## 11. Resultado do teste `09-op r,r.gb`

O teste `09-op r,r.gb` tambem passou via transcript serial.

Diagnóstico:

- com `10_000_000` ciclos, o runner não estava travado; ele já tinha avançado
  até a instrução temporária `CB 15` (`RL L`) em `instr=$DEF8`;
- isso mostrou que era um problema de orçamento de simulação, não uma falha
  funcional imediata;
- a própria fonte desse teste informa que ele leva cerca de 10 segundos no Game
  Boy, logo ele é naturalmente muito mais longo que `06`, `04`, `08`, `05`,
  `03` e `07`.

Solução:

- `tb_cpu_rom_runner` agora tem o generic `G_TIMEOUT_CYCLES`;
- o script `sim/modelsim/run_cpu_blargg_09.do` roda a ROM com
  `G_TIMEOUT_CYCLES=25000000`;
- resultado observado: `09-op r,r`, linha em branco, `Passed`.

Próximo alvo recomendado:

`cpu_instrs/individual/01-special.gb`

Motivo: `11-op a,(hl).gb` e `10-bit ops.gb` já passaram. O próximo risco
comportamental de CPU está nas instruções especiais restantes antes de entrar em
interrupções.

## 12. Resultado dos testes `10-bit ops.gb` e `11-op a,(hl).gb`

Os testes `10-bit ops.gb` e `11-op a,(hl).gb` passaram via transcript serial.

Fatia implementada para isso:

- `DAA` na ALU, com cobertura unitária;
- execução de `DAA` no controle da CPU;
- CB-prefix em `(HL)` com leitura de memória, cálculo, escrita de volta e flags;
- smoke test de CPU cobrindo `RLC (HL)`, `BIT 0,(HL)`, `RES 0,(HL)` e
  `SET 0,(HL)`;
- scripts dedicados:
  - `sim/modelsim/run_cpu_blargg_10.do`;
  - `sim/modelsim/run_cpu_blargg_11.do`.

Resultados observados:

- `10-bit ops.gb`: `Passed`, com `G_TIMEOUT_CYCLES=50000000`;
- `11-op a,(hl).gb`: `Passed`, com `G_TIMEOUT_CYCLES=50000000`.

Próximo alvo recomendado:

`cpu_instrs/individual/01-special.gb`

Motivo: esse teste deve consolidar o comportamento das instruções especiais
antes de entrarmos em `02-interrupts.gb`, que pertence à fase de timer e
interrupções reais.
