# HDLBoy

Experimental Game Boy emulator implemented in VHDL and targeting an Intel/Altera Cyclone IV EP4CE6 FPGA. The design is developed with Quartus II 13.0sp1 and leverages AI assistants (Codex and Cursor) to accelerate exploration.

## Estrutura do repositório

- `rtl/`: código-fonte VHDL organizado por blocos (CPU, PPU, APU, memória, barramentos e periféricos).
- `sim/`: ambientes de simulação e testbenches unitários e de integração.
- `fpga/`: arquivos específicos da placa (projeto Quartus, constraints e scripts de programação).
- `docs/`: documentação técnica, arquitetura e referências (incluindo materiais do gbdev).
- `scripts/`: automações auxiliares para build, testes e geração de artefatos.
- `assets/`: recursos adicionais como diagramas, imagens ou ROMs de teste autorizadas.

## Progresso atual

- Documentação de referência inicial disponível em `docs/architecture/GameboyCpu.md`, alinhando o design com o Pan Docs.
- Estrutura mínima da CPU (`rtl/cpu/`) implementada com pacote de tipos, banco de registradores, ALU expandida, unidade de controle com microciclos, unidade de endereços integrada e bloco de interrupções com vetores priorizados. O subconjunto atual cobre loads imediatos/indiretos, a matriz completa `LD r,r'` (0x40–0x7F), `LD (HL),d8`, formas `A↔(BC/DE/HL±/nn)`, modos `LDH/LD (C),A`, as cargas de 16 bits (`LD rr,d16`, `LD (nn),SP`, `LD HL,SP+e8`, `LD SP,HL`), `PUSH/POP rr` e operações aritméticas/lógicas em `A`.

As próximas etapas incluem detalhar cada módulo do sistema, incorporar documentação de referência e iniciar a implementação incremental dos blocos principais do hardware.
