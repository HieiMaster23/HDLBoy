# Game Boy CPU (LR35902/SM83)

Este documento resume a organização lógica da CPU do Game Boy com base na documentação do [Pan Docs](https://gbdev.io/pandocs/), servindo como referência inicial para a implementação em VHDL. A ideia é manter a equipe alinhada sobre os blocos principais, os registradores visíveis e o comportamento básico do conjunto de instruções.

## Visão Geral

* **Arquitetura:** núcleo de 8 bits com unidade de endereçamento de 16 bits.
* **Registradores de propósito geral:** pares AF, BC, DE e HL (A e F com flags; B/C, D/E e H/L podem ser utilizados como pares de 16 bits para operações de endereço).
* **Registradores especiais:** PC (Program Counter), SP (Stack Pointer) e IR (Instruction Register).
* **Flags:** Z (Zero), N (Add/Sub), H (Half Carry) e C (Carry/Borrow).
* **Interrupções:** cinco fontes (VBlank, LCD STAT, Timer, Serial e Joypad) controladas por IF/IE e habilitadas globalmente via IME.

## Conjunto de Instruções (resumo)

O LR35902 utiliza opcodes de 8 bits. A tabela completa está disponível no Pan Docs, mas para a **Fase 1** focaremos em um subconjunto mínimo para validação da infraestrutura:

| Opcode | Mnemônico       | Descrição resumida                                         |
|--------|-----------------|------------------------------------------------------------|
| `0x00` | `NOP`           | Não faz nada.                                              |
| `0x01` | `LD BC, d16`    | Carrega imediato de 16 bits em `BC`.                       |
| `0x02` | `LD (BC), A`    | Escreve `A` na memória apontada por `BC`.                  |
| `0x06` | `LD B, d8`      | Carrega imediato de 8 bits em `B`.                         |
| `0x08` | `LD (nn), SP`   | Escreve `SP` (low depois high) no endereço imediato.       |
| `0x0A` | `LD A, (BC)`    | Lê a memória apontada por `BC` para `A`.                   |
| `0x0E` | `LD C, d8`      | Carrega imediato de 8 bits em `C`.                         |
| `0x11` | `LD DE, d16`    | Carrega imediato de 16 bits em `DE`.                       |
| `0x12` | `LD (DE), A`    | Escreve `A` na memória apontada por `DE`.                  |
| `0x16` | `LD D, d8`      | Carrega imediato de 8 bits em `D`.                         |
| `0x1A` | `LD A, (DE)`    | Lê a memória apontada por `DE` para `A`.                   |
| `0x1E` | `LD E, d8`      | Carrega imediato de 8 bits em `E`.                         |
| `0x21` | `LD HL, d16`    | Carrega imediato de 16 bits em `HL`.                       |
| `0x22` | `LD (HL+), A`   | Escreve `A` em `(HL)` e incrementa `HL`.                   |
| `0x23` | `INC HL`        | Incrementa o par `HL`.                                     |
| `0x26` | `LD H, d8`      | Carrega imediato de 8 bits em `H`.                         |
| `0x2A` | `LD A, (HL+)`   | Lê `(HL)` para `A` e incrementa `HL`.                      |
| `0x2B` | `DEC HL`        | Decrementa o par `HL`.                                     |
| `0x2E` | `LD L, d8`      | Carrega imediato de 8 bits em `L`.                         |
| `0x32` | `LD (HL-), A`   | Escreve `A` em `(HL)` e decrementa `HL`.                   |
| `0x34` | `INC (HL)`      | Incrementa o byte apontado por `HL`, preservando `C`.      |
| `0x35` | `DEC (HL)`      | Decrementa o byte apontado por `HL`, preservando `C`.      |
| `0x36` | `LD (HL), d8`   | Escreve imediato de 8 bits na memória apontada por `HL`.   |
| `0x3A` | `LD A, (HL-)`   | Lê `(HL)` para `A` e decrementa `HL`.                      |
| `0x3C` | `INC A`         | Incrementa `A`, preservando `C`.                           |
| `0x3D` | `DEC A`         | Decrementa `A`, preservando `C`.                           |
| `0x3E` | `LD A, d8`      | Carrega imediato de 8 bits em `A`.                         |
| `0x47` | `LD B, A`       | Copia `A` para `B`.                                        |
| `0x76` | `HALT`          | Entra em estado de espera até uma interrupção.             |
| `0x77` | `LD (HL), A`    | Escreve `A` na memória apontada por `HL`.                  |
| `0x78` | `LD A, B`       | Copia `B` para `A`.                                        |
| `0x7E` | `LD A, (HL)`    | Lê a memória apontada por `HL` para `A`.                   |
| `0x87` | `ADD A, A`      | Soma `A` com `A`.                                          |
| `0x8F` | `ADC A, A`      | Soma `A` com `A` e `C`.                                    |
| `0x97` | `SUB A, A`      | Subtrai `A` de `A` (gera zero, atualiza flags).            |
| `0x9F` | `SBC A, A`      | Subtrai `A` e `C` de `A`.                                  |
| `0xA7` | `AND A`         | `A := A AND A` (força bits de flags conforme LR35902).     |
| `0xAF` | `XOR A`         | `A := A XOR A` (zera acumulador, limpa `C`).               |
| `0xB7` | `OR A`          | `A := A OR A` (mantém valor, ajusta flags).                |
| `0xC6` | `ADD A, d8`     | Soma imediato com `A`.                                     |
| `0xC1` | `POP BC`        | Lê dois bytes da pilha para `BC`.                          |
| `0xC5` | `PUSH BC`       | Empilha o par `BC` (high primeiro).                        |
| `0xCE` | `ADC A, d8`     | Soma imediato e `C` com `A`.                               |
| `0xD6` | `SUB A, d8`     | Subtrai imediato de `A`.                                   |
| `0xD1` | `POP DE`        | Lê dois bytes da pilha para `DE`.                          |
| `0xD5` | `PUSH DE`       | Empilha o par `DE` (high primeiro).                        |
| `0xDE` | `SBC A, d8`     | Subtrai imediato e `C` de `A`.                             |
| `0xE0` | `LDH (n), A`    | Escreve `A` em `0xFF00 + n`.                               |
| `0xE2` | `LD (C), A`     | Escreve `A` em `0xFF00 + C`.                               |
| `0xE6` | `AND d8`        | `A := A AND d8`.                                           |
| `0xE1` | `POP HL`        | Lê dois bytes da pilha para `HL`.                          |
| `0xE5` | `PUSH HL`       | Empilha o par `HL` (high primeiro).                        |
| `0xEA` | `LD (nn), A`    | Escreve `A` na memória apontada por endereço imediato.     |
| `0xEE` | `XOR d8`        | `A := A XOR d8`.                                           |
| `0xF0` | `LDH A, (n)`    | Lê `0xFF00 + n` para `A`.                                  |
| `0xF2` | `LD A, (C)`     | Lê `0xFF00 + C` para `A`.                                  |
| `0xF6` | `OR d8`         | `A := A OR d8`.                                            |
| `0xF1` | `POP AF`        | Lê dois bytes da pilha para `AF` (flags ajustados).        |
| `0xF5` | `PUSH AF`       | Empilha `AF` (flags comprimidos nos bits 7-4).             |
| `0xF8` | `LD HL, SP+e8`  | Soma deslocamento assinado ao `SP` e grava em `HL` (flags `H/C`). |
| `0xF9` | `LD SP, HL`     | Copia o par `HL` para `SP`.                                |
| `0xFA` | `LD A, (nn)`    | Lê endereço imediato de 16 bits para `A`.                  |
| `0xFE` | `CP d8`         | Compara `A` com imediato (flags como `SUB`).               |

Além das instruções explícitas acima, toda a matriz `0x40–0x7F` (`LD r,r'`) foi habilitada, permitindo transferências entre quaisquer registradores de 8 bits ou entre registrador e `(HL)`.

Os loads indiretos que usam `HL` e os incrementos/decrementos de 16 bits são resolvidos pela `idu.vhd`, que fornece os valores atualizados de `PC/SP/HL` e seleciona o endereço ativo no barramento. O estágio atual cobre também os loads de 16 bits (`LD rr,d16`, `LD (nn),SP`, `LD HL,SP+e8`, `LD SP,HL`) e as operações de pilha (`PUSH/POP rr`), preparando a FSM para a próxima leva de saltos e aritmética ampla. Os demais opcodes serão adicionados progressivamente. Quando necessário, consultar as seções "CPU Instruction Set" e "Instruction Timing" do Pan Docs para detalhes de ciclos e efeitos nos registradores/flags.

## Pipeline de Execução Simplificado

1. **Fetch**: ler `PC` no barramento, capturar opcode em `IR` e incrementar `PC`.
2. **Decode**: interpretar o opcode no `IR` e decidir os sinais de controle.
3. **Read Immediate / Prep**: quando necessário, buscar operandos imediatos e preparar entradas da ALU.
4. **Execute**: acionar ALU ou outras unidades de acordo com o micro-op selecionado.
5. **Write-back**: atualizar registros (`A`, `F`, pares, `PC`, `SP`) conforme o resultado.
6. **Check IRQ**: após cada instrução, verificar `IME` e os bits setados em `IF & IE`; se habilitado, vetorar para o endereço correspondente.

O controlador atualiza `PC` em múltiplos estágios (`FETCH`, leitura de imediato e serviço de interrupção) para refletir os ciclos de máquina do LR35902. A unidade de endereços (`idu.vhd`) calcula incrementos/decrementos de `PC`, `SP` e `HL`, além de selecionar qual registrador alimenta o barramento externo (tipicamente `PC`, mas também `HL` para loads indiretos). A preparação da ALU ocupa um ciclo dedicado para estabilizar operandos/flags antes da escrita.

## Próximos Passos

* Exercitar em simulação o caminho completo de loads (8 e 16 bits) incluindo `PUSH/POP`, `LD (nn),SP` e `LD HL,SP+e8`, conferindo flags e sequenciamento do `SP`.
* Estender a FSM para aritmética de 16 bits (`ADD HL,rr`, `INC/DEC rr`, `ADD SP,e8`) e preparar o caminho de empilhamento automático do `PC` para interrupções.
* Adicionar saltos e retornos (`JR`, `JP`, `CALL`, `RET`) com temporização aproximada aos ciclos do LR35902.
* Incluir rotações, shifts e operações bitwise adicionais (prefixo `CB`) na ALU e na FSM.
* Evoluir o bloco de interrupções para suportar `EI`/`DI`, empilhamento do `PC` e sequenciamento completo de acknowledge.

Este arquivo deve ser mantido sincronizado com o avanço da implementação para que a documentação reflita fielmente o estado dos módulos VHDL.
