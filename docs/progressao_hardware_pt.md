# Progressão do Hardware do Game Boy FPGA

Este documento é a referência em português para entender a evolução do projeto
`gameboy-fpga-core`: o que estamos construindo, por que a ordem escolhida faz
sentido, o que já foi implementado e quais são os próximos passos até chegarmos
a um sistema capaz de executar ROMs simples de Game Boy.

Ele complementa:

- `docs/project_control_pt.md`, que registra o estado operacional do projeto;
- `docs/development_roadmap.md`, que descreve a mesma linha de evolução em
  inglês para a documentação técnica do repositório.
- `docs/base_artigo_tcc_pt.md`, que define como transformar a documentação
  acumulada do projeto em material para um futuro artigo ou TCC.

## 1. O Que Estamos Construindo

Este projeto não é um emulador de software. A meta é recriar, em VHDL
sintetizável, os blocos de hardware que formam o Game Boy DMG-01:

- CPU Sharp LR35902;
- barramento e mapa de memória;
- temporizador;
- controlador de interrupções;
- joypad;
- PPU;
- memória de vídeo e RAMs internas;
- mais tarde, APU e carregamento de ROMs.

Cada parte precisa existir como circuito real no FPGA. Isso muda a forma de
pensar o desenvolvimento: não basta que um programa "dê o resultado certo"; os
blocos precisam trocar sinais no instante certo, ocupar o barramento da forma
correta e caber no Cyclone IV EP4CE6.

## 2. A Ideia Central da Progressão

O projeto cresce por evidência, não por acúmulo de código.

O ciclo correto é:

1. escolher uma fatia pequena e verificável;
2. implementar apenas o necessário para essa fatia;
3. simular;
4. sintetizar quando houver mudança em RTL;
5. medir recursos no FPGA;
6. testar em hardware quando houver efeito observável;
7. documentar;
8. avançar.

Essa disciplina evita um problema clássico em projetos de console em FPGA:
quando muitos blocos são criados cedo demais, um erro visual ou funcional deixa
de ter causa clara. Pode ser CPU, barramento, timer, PPU, memória ou uma
interação entre todos eles.

## 3. Visão Geral da Linha de Evolução

```text
Bring-up da placa
  -> VGA e framebuffer
  -> CPU funcional
  -> Barramento, WRAM, timer e interrupções
  -> Fidelidade temporal da CPU
  -> PPU real
  -> Joypad, ROM loading e integração jogável
  -> APU e refinamentos de compatibilidade
```

O caminho crítico até o primeiro jogo rodando é:

```text
CPU com timing confiável
  -> timer/interrupções mais fiéis
  -> PPU real
  -> entrada e fluxo de ROM
  -> jogos simples
```

## 4. Por Que Não Começamos Diretamente por Jogos

Um jogo comercial depende de quase todo o hardware ao mesmo tempo:

- CPU com instruções corretas;
- flags corretos;
- stack;
- temporização;
- interrupções;
- timer;
- joypad;
- mapa de memória;
- VRAM;
- PPU;
- sprites;
- DMA;
- eventualmente MBC e ROM externa.

Se tentássemos rodar um jogo logo no início, uma falha não ensinaria quase nada.
Por isso começamos com testes muito menores e ampliamos a fidelidade aos poucos.

## 5. O Que Já Foi Implementado

### 5.1 Base da Placa e Vídeo

Já foi validado em hardware real:

- clock da placa;
- reset;
- programação via JTAG;
- VGA 640x480;
- funcionamento do conversor VGA-HDMI ativo;
- framebuffer 160x144 com escala para VGA;
- display de sete segmentos;
- top visual em que a CPU escreve pixels no framebuffer.

Isso significa que já temos uma saída visual confiável e um caminho físico de
vídeo comprovado.

### 5.2 CPU

A CPU LR35902 já deixou de ser uma CPU "mínima". Hoje ela possui:

- registradores A, F, B, C, D, E, H, L, SP e PC;
- ALU com flags Z, N, H e C;
- decoder separado;
- máquina de estados multi-ciclo;
- loads principais;
- ALU entre registradores, imediatos e `(HL)`;
- jumps, calls, returns, stack e RST;
- instruções CB em registradores e em `(HL)`;
- `DAA`;
- base real de interrupções com IME, IE/IF, prioridade, push de PC, vetores e
  `RETI`;
- `EI`, `DI`, `HALT` básico e `STOP` mínimo.

O resultado mais importante até aqui é:

- todos os testes individuais de `cpu_instrs` do Blargg já passam via transcript
  serial.

Isso mostra que a CPU está amplamente correta do ponto de vista funcional.

### 5.3 Barramento e Memória

Já existe:

- `bus_controller.vhd`;
- ROM temporária de smoke test;
- WRAM completa de 8 KiB;
- espelho de WRAM;
- HRAM;
- IE em `0xFFFF`;
- IF em `0xFF0F`;
- serial debug em `0xFF01/0xFF02`;
- stubs de I/O;
- handshake `mem_ready/cpu_ready`;
- leitura registrada para permitir uso eficiente de RAM interna.

Esse ponto foi importante para o projeto não se perder no EP4CE6. Quando a WRAM
foi tentada como grande arranjo combinacional, o custo subiu demais. A solução
com leitura registrada permitiu que o Quartus inferisse RAM interna e manteve o
projeto viável.

### 5.4 Timer e Interrupções

Já temos:

- timer inicial extraído para `rtl/io/timer.vhd`;
- `DIV`, `TIMA`, `TMA` e `TAC`;
- seleção por TAC;
- pulso de interrupção de timer;
- integração com IF;
- testes unitários e regressão preservada.

O timer já é muito melhor do que o stub inicial, mas ainda não está encerrado:
ele precisa ser alinhado à temporização final da CPU.

### 5.5 Situação de Recursos

No checkpoint atual, o `cpu_video_smoke_top` usa:

- `4.268 / 6.272` logic elements, ou `68%`;
- `111.616 / 276.480` bits de memória;
- `14 / 30` blocos M9K.

Ainda há espaço, mas não há espaço para desperdício. Isso confirma que decisões
de compartilhamento de estados, RAM inferida e crescimento incremental não são
luxo; são necessidade.

## 6. Por Que a CPU Veio Antes da PPU Real

À primeira vista, pode parecer natural começar logo a PPU, porque ela é a parte
mais visível do Game Boy. Mas a PPU real depende de contratos que vêm antes:

- temporização da CPU;
- acesso a registradores;
- interrupções;
- uso do barramento;
- acesso à VRAM;
- depois, DMA e sincronização por scanline.

Se começarmos a PPU com uma CPU funcional, porém ainda imprecisa em timing,
qualquer defeito visual futuro fica ambíguo. Pode ser um erro da PPU, da CPU, do
timer ou da interação entre eles.

Por isso a ordem correta agora é:

1. CPU amplamente correta em comportamento;
2. barramento realista;
3. refinamento temporal;
4. PPU real.

Não estamos atrasando a PPU. Estamos preparando o terreno para que ela nasça em
um sistema compreensível.

## 7. Por Que Testamos por Serial Antes de Depender de Vídeo

Os testes do Blargg enviam texto pela serial do Game Boy:

- `0xFF01`: byte de dados;
- `0xFF02`: controle da transferência.

No estágio atual, usamos um stub de serial apenas para capturar esse texto em
simulação. Assim, a CPU consegue informar `Passed` ou `Failed` sem depender da
PPU estar pronta.

Isso é muito valioso porque separa as causas:

- se um teste de CPU falha pela serial, o problema está no domínio CPU/bus/timer;
- se um teste visual falha mais tarde, já teremos uma base muito mais confiável.

## 8. O Que Significa "Passar cpu_instrs"

Passar todos os `cpu_instrs` individuais é um marco grande, mas não encerra a
CPU.

Esses testes provam principalmente:

- comportamento das instruções;
- flags;
- fluxo de controle;
- stack;
- várias interações de memória;
- base de interrupções.

Eles não provam completamente:

- número exato de ciclos por instrução;
- temporização de barramento;
- temporização de interrupções;
- bug de `HALT`;
- comportamento real de `STOP`.

Por isso a próxima fase não é "mais opcodes", e sim **fidelidade temporal**.

## 9. Onde Estamos Agora

Estamos na transição entre:

- uma CPU funcionalmente forte;
- e uma CPU suficientemente fiel para servir de base à PPU e a softwares mais
  reais.

O checkpoint mais recente fechou:

- todos os `cpu_instrs` individuais;
- timer inicial compartilhado;
- regressão do smoke visual;
- síntese Quartus com recursos medidos.

O projeto está agora na fase:

```text
instr_timing -> mem_timing -> interrupt_time -> halt_bug
```

A primeira execução de `instr_timing` mostrou um detalhe importante do processo:
a ROM primeiro calibra o próprio temporizador antes de medir os opcodes. No
estado inicial, ela falhava nessa calibração. Depois da primeira correção de
temporização da CPU, ela passou dessa etapa e chegou à fase real de medição das
instruções.

Na sequência, surgiram três tipos diferentes de ajuste:

1. remover um ciclo de decode desnecessário em instruções simples;
2. preservar operações de 1 ciclo que já executam tudo no fetch;
3. separar caminhos condicionais com tempos diferentes, como `JR cc,e`, que
   leva 2 ciclos quando não toma o salto e 3 quando toma.

Essa terceira etapa é especialmente importante porque mostra por que a
temporização não deve ser tratada como uma simples tabela de números. Ela muda a
própria organização do controle interno da CPU.

Depois disso, fizemos a primeira reorganização deliberada do controle de
execução:

- mantivemos os fast paths necessários para timing;
- removemos de `S_DECODE` corpos de execução que já eram resolvidos no fetch;
- centralizamos a classificação de loads por endereço de registrador em
  predicados pequenos compartilhados;
- rejeitamos uma versão aparentemente mais genérica de `LD_MEM` porque ela
  quebrou o fluxo de cópia para WRAM usado pelas ROMs de teste.

O resultado foi importante para o projeto como um todo: a lógica caiu de
`4.511` para `4.268` LEs, preservando os testes e recuperando margem no FPGA sem
abrir mão da fidelidade temporal já conquistada.

Atualização mais recente:

- o autoteste inicial de timer do `instr_timing.gb` deixou de ser o bloqueio
  principal;
- a ROM agora alcança a tabela de medição por opcode;
- os caminhos incondicionais `JP nn`, `CALL nn`, `RET` e `RETI` foram corrigidos
  para preservar os ciclos M internos esperados;
- a sonda local `tb_cpu_timing_probe` passou a cobrir `JP nn`, `CALL nn` e
  `RET`;
- as regressões rápidas de CPU, timer, barramento, interrupções e smoke visual
  continuaram passando.

Isso confirma que a progressão está correta: primeiro estabilizamos o tempo das
instruções que sustentam o próprio mecanismo de teste, depois avançamos para as
diferenças restantes por família de opcode.

## 10. Próximos Passos Recomendados

### 10.1 Próxima Fase Imediata: Fidelidade Temporal da CPU

Ordem recomendada:

1. manter uma sonda local self-checking para os ciclos já corrigidos;
2. manter `instr_timing.gb` como regressão obrigatória já conquistada;
3. manter `mem_timing` como regressão obrigatória já conquistada;
4. manter `mem_timing-2` como regressão obrigatória já conquistada;
5. manter `interrupt_time` como regressão obrigatória já conquistada;
6. manter `halt_bug.gb` como regressão obrigatória já conquistada;
7. repetir a síntese após cada nova família relevante;
8. importar uma suíte específica de timer mais adiante, se quisermos ampliar a
   cobertura além do pacote Blargg local.

Essa sequência deve tornar mais confiável:

- a duração das instruções;
- o momento dos acessos ao barramento;
- a relação entre CPU e timer;
- o comportamento de interrupções e `HALT`.

### 10.2 Depois Disso: PPU Real

Quando a base temporal estiver melhor consolidada, o próximo grande bloco será a
PPU real.

Ordem sugerida:

1. VRAM real;
2. tile data;
3. tile map;
4. background estático;
5. scrolling;
6. window;
7. sprites e OAM;
8. modos da PPU;
9. VBlank, STAT e DMA.

O primeiro grande marco visual da PPU deve ser uma imagem formada por tiles,
gerada pela PPU, não mais pixels escritos diretamente pela CPU no framebuffer.

### 10.3 Depois da PPU Mínima

Para chegar a jogos simples, ainda precisaremos de:

- joypad real;
- fluxo de ROM mais realista;
- mais fidelidade de timer/interrupções;
- possivelmente MBC para ROMs maiores;
- integração do sistema em um top mais próximo do Game Boy final.

Só então faz sentido mirar:

- homebrews simples;
- `Tetris`;
- `Dr. Mario`.

### 10.4 Depois do Primeiro Sistema Jogável

A APU entra como etapa de completude e refinamento:

- canais de pulso;
- wave channel;
- noise channel;
- mistura e saída de áudio.

Ela é importante para um Game Boy completo, mas não é o bloqueador principal
para o primeiro alvo jogável.

## 11. Como Ler o Estado do Projeto Sem Se Perder

Pense sempre em três níveis:

### Nível 1: Blocos

- CPU
- bus/memória
- timer/interrupções
- PPU
- joypad
- APU

### Nível 2: Contratos Entre Blocos

- quem responde a qual endereço;
- quando a CPU pode ler;
- quando uma interrupção é levantada;
- quando a PPU pode usar memória;
- como dados atravessam clocks diferentes.

### Nível 3: Evidência

- qual teste prova que aquele comportamento existe;
- qual bitstream já foi validado em hardware;
- quanto custou no FPGA;
- o que ainda é stub.

Enquanto esses três níveis estiverem claros, o projeto continua sob controle.

## 12. O Que Já É Real e O Que Ainda É Provisório

### Já É Real no Projeto

- VGA em hardware;
- framebuffer em hardware;
- CPU multi-ciclo;
- WRAM completa;
- caminho serial de testes;
- timer inicial;
- base de interrupções;
- regressão Blargg `cpu_instrs`;
- medição contínua de recursos.

### Ainda É Provisório ou Incompleto

- framebuffer direto no smoke test;
- ROM interna temporária;
- parte dos registradores de I/O;
- joypad;
- PPU real;
- timing exato da CPU;
- comportamento completo de `HALT` e `STOP`;
- carregamento final de ROMs;
- APU.

## 13. Como Sabemos Que a Progressão Está Correta

A progressão está correta quando cada nova etapa:

- reduz uma incerteza importante;
- cria um teste novo;
- evita acoplar muitos blocos imaturos ao mesmo tempo;
- preserva espaço no FPGA;
- deixa o próximo passo mais claro do que o anterior.

Foi exatamente isso que aconteceu até aqui:

- VGA tornou o hardware observável;
- framebuffer tornou o vídeo controlável;
- CPU tornou programas possíveis;
- serial tornou ROMs de teste observáveis sem PPU;
- barramento tornou a memória realista;
- timer começou a unir CPU e interrupções;
- agora o timing vai preparar o caminho da PPU.

## 14. Resumo Executivo

Hoje, o projeto já possui:

- base FPGA validada;
- vídeo funcionando em hardware;
- CPU ampla em comportamento;
- toda a suíte individual `cpu_instrs` passando;
- `instr_timing.gb` passando;
- `mem_timing` individual e agregado passando;
- `mem_timing-2` individual e agregado passando;
- `interrupt_time.gb` passando;
- `halt_bug.gb` passando;
- barramento com WRAM completa;
- serial debug;
- timer inicial;
- interrupções básicas;
- integração CPU + vídeo preservada;
- recursos medidos e ainda dentro do limite da placa.

O próximo passo correto é:

```text
fechar a fidelidade temporal da CPU antes de iniciar a PPU real
```

Depois disso, o grande capítulo seguinte será a PPU. A partir dela, começaremos
a sair do território dos testes de subsistema e a entrar no território de uma
máquina cada vez mais parecida com um Game Boy de verdade.

## 15. Atualização: Timing de CPU Contra o Timer

A etapa atual mostrou uma diferença importante entre dois tipos de validação:

- contar ciclos diretamente dentro da CPU;
- medir ciclos usando uma ROM real que depende do timer do Game Boy.

O `tb_cpu_timing_probe` conta os ciclos M observando a própria CPU. Ele foi
ampliado para cobrir mais opcodes que aparecem cedo no `instr_timing.gb`, como
`INC BC`, `DEC BC`, `LD (HL+),A`, `LD A,(HL+)`, `LDH A,(n)`, `LD A,(nn)` e
`LD SP,HL`. Todos esses casos passaram.

Mesmo assim, o `instr_timing.gb` ainda imprimia diferenças. Isso indicava que o
problema não era simplesmente "adicionar um ciclo" ou "remover um ciclo" desses
opcodes. O ponto sensível era a fronteira entre CPU, bus e timer: em qual ciclo a
escrita em `TIMA` acontece, em qual ciclo a leitura de `TIMA` enxerga o valor, e
como isso se alinha à borda interna do divisor.

Essa distinção é importante para o projeto inteiro. Um jogo não depende apenas
de a CPU chegar ao resultado correto; ele depende de a CPU ocupar o barramento
no tempo correto. Mais adiante, a PPU, DMA, interrupções e joypad também vão
depender dessa mesma disciplina temporal.

O passo técnico seguinte foi criar uma sonda específica para o laço de timer
usado por Blargg, antes de mexer novamente nos opcodes. Isso reduziu o risco de
corrigir um sintoma e quebrar testes que já estavam bons.

Essa sonda foi criada como ferramenta de depuração, não como substituta do
Blargg. O resultado inicial é útil:

- `NOP` mediu `1`, como esperado;
- `LD BC,nn` mediu `4` antes da correção de visibilidade da TIMA, embora o
  Blargg espere `3`;
- a mesma instrução mede `3` quando observamos apenas a distância entre fetches
  da CPU.

Isso ensina uma coisa importante: existem duas verdades parciais sendo
observadas ao mesmo tempo. A CPU, isolada, parece contar corretamente os ciclos
da instrução. A medição pelo timer, porém, ainda vê um ciclo a mais. Portanto, o
erro mais provável está na fronteira entre CPU, barramento e timer, não
necessariamente no opcode isolado.

O Blargg continua sendo a referência. A sonda local serve apenas para descobrir
onde olhar dentro do nosso hardware.

A correção final desta etapa foi ajustar a visibilidade de leitura da TIMA: no
modelo atual de barramento por ciclo M, a CPU deve enxergar o valor visível ao
fim do ciclo de acesso. Para incrementos normais do timer, isso significa ver a
TIMA já incrementada após a borda do divisor naquele ciclo. O caminho de overflow
continua com atraso separado: TIMA ainda passa por `0x00` antes do reload por
TMA e do pulso de interrupção.

Com isso, a ROM real `instr_timing.gb` passou. Esse é um checkpoint importante
porque confirma a regra de desenvolvimento do projeto: quando um teste local e a
ROM real parecem discordar, a ROM real decide o alvo; o teste local serve apenas
para revelar onde a implementação precisa ser observada.

Na sequência, a família `mem_timing` também passou:

- `01-read_timing.gb`;
- `02-write_timing.gb`;
- `03-modify_timing.gb`;
- `mem_timing.gb` agregado.

Isso mostra que, para as instruções já cobertas, a CPU está posicionando leituras
e escritas de memória no ciclo correto dentro do modelo atual. É um avanço
importante porque começa a validar não só "quanto tempo a instrução dura", mas
também "em qual ciclo o barramento é realmente acessado".

A família `mem_timing-2` também passou. Ela foi importante por outro motivo:
essa versão do Blargg publica o resultado por memória em `0xA000`, com assinatura
em `0xA001..0xA003`. Portanto, o runner foi ampliado para observar esse
protocolo oficial além da saída serial. Isso deixa o ambiente de teste mais
próximo da diversidade real dos testes Blargg.

Na sequência, `interrupt_time.gb` também passou. Essa ROM mede a entrada de
interrupção e espera 13 ciclos entre a solicitação e o retorno do handler. O
resultado confirma que o caminho atual de IME, prioridade, push de `PC`, vetor,
`interrupt_ack` e retorno está coerente com o teste.

Dentro do pacote Blargg local, o próximo alvo de CPU diretamente disponível é
`halt_bug.gb`, e ele também já passou no runner atual. Não há uma suíte separada
de timer nesse pacote além das famílias já usadas e dos helpers internos dos
testes de timing.

Com isso, a escada local de CPU/timing disponível neste pacote ficou fechada:
`cpu_instrs`, `instr_timing`, `mem_timing`, `mem_timing-2`, `interrupt_time` e
`halt_bug` passam. O próximo passo mais coerente deixa de ser procurar outra ROM
de CPU dentro desse mesmo pacote e passa a ser consolidar um checkpoint formal
dessa fase antes de abrir a primeira fatia real da PPU.

Essa primeira fatia real de PPU deve ser pequena e verificável:

1. VRAM real;
2. leitura de tile data;
3. leitura de tile map;
4. geração de background estático por tiles;
5. ainda sem sprites, window, STAT ou DMA.
