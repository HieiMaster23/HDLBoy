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
| `0x3E` | `LD A, d8`     | Carrega imediato de 8 bits em `A`.            |
| `0x76` | `HALT`         | Entra em estado de espera até uma interrupção.|

Os demais opcodes serão adicionados progressivamente. Quando necessário, consultar as seções "CPU Instruction Set" e "Instruction Timing" do Pan Docs para detalhes de ciclos e efeitos nos registradores/flags.

## Pipeline de Execução Simplificado

1. **Fetch**: ler `PC` no barramento, capturar opcode em `IR` e incrementar `PC`.
2. **Decode**: interpretar o opcode no `IR` e decidir os sinais de controle.
3. **Execute**: acionar ALU, registradores ou acessos adicionais à memória (por exemplo, leitura de imediatos ou escrita em RAM).
4. **Write-back**: atualizar registros (`A`, `F`, pares, `PC`, `SP`) conforme o resultado.
5. **Interrupções**: após cada instrução, verificar `IME` e os bits setados em `IF & IE`; se habilitado, vetorar para o endereço correspondente.

## Próximos Passos

* Expandir a ALU para cobrir operações com carry (`ADC`, `SBC`) e lógicas adicionais.
* Integrar a unidade de endereços (`idu.vhd`) para manipular `PC`, `SP` e `HL` de forma centralizada.
* Completar a FSM de controle com ciclos de memória extras e suporte a leitura/escrita no barramento externo.
* Implementar o bloco de interrupções com espelhamento correto de IF/IE e manipulação do `IME` via instruções `EI`/`DI`.

Este arquivo deve ser mantido sincronizado com o avanço da implementação para que a documentação reflita fielmente o estado dos módulos VHDL.
