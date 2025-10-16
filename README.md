# HDLBoy

Experimental Game Boy emulator implemented in VHDL and targeting an Intel/Altera Cyclone IV EP4CE6 FPGA. The design is developed with Quartus II 13.0sp1 and leverages AI assistants (Codex and Cursor) to accelerate exploration.

## Estrutura do repositório

- `rtl/`: código-fonte VHDL organizado por blocos (CPU, PPU, APU, memória, barramentos e periféricos).
- `sim/`: ambientes de simulação e testbenches unitários e de integração.
- `fpga/`: arquivos específicos da placa (projeto Quartus, constraints e scripts de programação).
- `docs/`: documentação técnica, arquitetura e referências (incluindo materiais do gbdev).
- `scripts/`: automações auxiliares para build, testes e geração de artefatos.
- `assets/`: recursos adicionais como diagramas, imagens ou ROMs de teste autorizadas.

As próximas etapas incluem detalhar cada módulo do sistema, incorporar documentação de referência e iniciar a implementação incremental dos blocos principais do hardware.
