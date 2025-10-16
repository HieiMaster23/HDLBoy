# Análise do andamento do projeto

## Visão geral do que foi feito até agora
- Repositório inicializado com objetivo de criar uma CPU/Game Boy completo para a placa Cyclone IV EP4CE6 (Quartus II 13.0sp1).
- Estrutura básica de diretórios criada (`rtl/`, `sim/`, `fpga/`, `docs/`, `scripts/`, `assets/`).
- Documentação inicial (`README.md`) alinhada com o novo alvo de hardware.
- Documento `docs/architecture/GameboyCpu.md` criado com um resumo baseado no Pan Docs para orientar a implementação da CPU.
- Primeira versão dos módulos VHDL da CPU (pacote de tipos, arquivo de registradores, ALU parcial, unidade de controle, barramento interno e stub de interrupções) adicionada em `rtl/cpu/`.

## Etapas implícitas no processo até aqui
1. **Definição do objetivo**: estabelecer o escopo do projeto e a plataforma alvo (Cyclone IV EP4CE6).
2. **Configuração do controle de versão e layout do repositório**: criação de diretórios e documentação inicial.
3. **Início da arquitetura da CPU**: preparação da documentação técnica e esqueleto dos blocos principais para evoluções incrementais.

## Planejamento proposto para as próximas etapas
1. **Documentação complementar**
   - Registrar convenções de codificação VHDL, padrões de reset, clock e estilo de FSM.
   - Expandir a documentação técnica com mapas de memória e cronogramas de instruções.
2. **Evolução da CPU**
   - Integrar a unidade de endereços (`idu.vhd`) ao fluxo da `control_unit`, habilitando manipulação de `PC`, `SP` e `HL` sem lógica duplicada.
   - Estender a ALU com operações `ADC`, `SBC`, rotações e shifts; ajustar os cálculos de flags conforme especificação do LR35902.
   - Implementar mais instruções na FSM (loads indiretos, incrementos/decrementos, saltos simples) e validar com testbenches.
   - Completar o bloco de interrupções com espelhamento realista de IF/IE/IME e interface com a control unit.
3. **Infraestrutura de testes e simulação**
   - Configurar testbenches para `register_file`, `alu` e `control_unit`, garantindo regressões automáticas.
   - Documentar como executar simulações (ModelSim/ghdl) e registrar resultados esperados.
4. **Planejamento de integração**
   - Definir marcos para integração com memória externa, PPU e demais subsistemas.
   - Avaliar requisitos específicos da placa (pinos, clock base, memória interna) e preparar um projeto Quartus inicial.

## Próximas ações imediatas sugeridas
- Revisar e detalhar a FSM da `control_unit` para cobrir instruções adicionais de carga e aritmética simples.
- Ajustar o fluxo de escrita de `PC/SP/HL` utilizando a `idu.vhd`, reduzindo redundâncias.
- Criar testes unitários mínimos (por exemplo, um testbench da ALU com os opcodes já suportados).
- Continuar alimentando a documentação conforme novos blocos forem implementados.
