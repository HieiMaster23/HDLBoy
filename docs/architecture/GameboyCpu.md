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

| Opcode | Mnemônico      | Descrição resumida                            |
|--------|----------------|-----------------------------------------------|
| `0x00` | `NOP`          | Não faz nada.                                 |
| `0x3C` | `INC A`        | Incrementa `A`, preservando `C`.              |
| `0x3D` | `DEC A`        | Decrementa `A`, preservando `C`.              |
| `0x3E` | `LD A, d8`     | Carrega imediato de 8 bits em `A`.            |
| `0x76` | `HALT`         | Entra em estado de espera até uma interrupção.|
| `0x87` | `ADD A, A`     | Soma `A` com `A`.                             |
| `0x8F` | `ADC A, A`     | Soma `A` com `A` e `C`.                       |
| `0x97` | `SUB A, A`     | Subtrai `A` de `A` (gera zero, atualiza flags).|
| `0x9F` | `SBC A, A`     | Subtrai `A` e `C` de `A`.                     |
| `0xA7` | `AND A`        | `A := A AND A` (força bits de flags conforme LR35902). |
| `0xAF` | `XOR A`        | `A := A XOR A` (zera acumulador, limpa `C`).  |
| `0xB7` | `OR A`         | `A := A OR A` (mantém valor, ajusta flags).   |
| `0xC6` | `ADD A, d8`    | Soma imediato com `A`.                        |
| `0xCE` | `ADC A, d8`    | Soma imediato e `C` com `A`.                  |
| `0xD6` | `SUB A, d8`    | Subtrai imediato de `A`.                      |
| `0xDE` | `SBC A, d8`    | Subtrai imediato e `C` de `A`.                |
| `0xE6` | `AND d8`       | `A := A AND d8`.                              |
| `0xEE` | `XOR d8`       | `A := A XOR d8`.                              |
| `0xF6` | `OR d8`        | `A := A OR d8`.                               |
| `0xFE` | `CP d8`        | Compara `A` com imediato (flags como `SUB`).  |

Os demais opcodes serão adicionados progressivamente. Quando necessário, consultar as seções "CPU Instruction Set" e "Instruction Timing" do Pan Docs para detalhes de ciclos e efeitos nos registradores/flags.

## Pipeline de Execução Simplificado

1. **Fetch**: ler `PC` no barramento, capturar opcode em `IR` e incrementar `PC`.
2. **Decode**: interpretar o opcode no `IR` e decidir os sinais de controle.
3. **Read Immediate / Prep**: quando necessário, buscar operandos imediatos e preparar entradas da ALU.
4. **Execute**: acionar ALU ou outras unidades de acordo com o micro-op selecionado.
5. **Write-back**: atualizar registros (`A`, `F`, pares, `PC`, `SP`) conforme o resultado.
6. **Check IRQ**: após cada instrução, verificar `IME` e os bits setados em `IF & IE`; se habilitado, vetorar para o endereço correspondente.

O controlador atualiza `PC` em múltiplos estágios (`FETCH`, leitura de imediato e serviço de interrupção) para refletir os ciclos de máquina do LR35902. A preparação da ALU ocupa um ciclo dedicado para estabilizar operandos/flags antes da escrita.

## Próximos Passos

* Incluir rotações, shifts e operações bitwise adicionais (`CB` prefix) na ALU.
* Integrar a unidade de endereços (`idu.vhd`) para manipular `PC`, `SP` e `HL` de forma centralizada.
* Adicionar loads indiretos e operações nos demais registradores (B/C/D/E/H/L, pares BC/DE/HL).
* Implementar manipulação completa de `IF/IE/IME`, incluindo instruções `EI`/`DI` e empilhamento do `PC` ao atender interrupções.

Este arquivo deve ser mantido sincronizado com o avanço da implementação para que a documentação reflita fielmente o estado dos módulos VHDL.
