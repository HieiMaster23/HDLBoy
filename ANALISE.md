# Análise do andamento do projeto

## Visão geral do que foi feito até agora
- Repositório inicializado com objetivo de criar uma CPU/Game Boy completo para a placa Cyclone IV EP4CE6 (Quartus II 13.0sp1).
- Estrutura básica de diretórios criada (`rtl/`, `sim/`, `fpga/`, `docs/`, `scripts/`, `assets/`).
- Documentação inicial (`README.md`) alinhada com o novo alvo de hardware.
- Documento `docs/architecture/GameboyCpu.md` criado com um resumo baseado no Pan Docs para orientar a implementação da CPU.
- Primeira versão dos módulos VHDL da CPU (pacote de tipos, arquivo de registradores, ALU parcial, unidade de controle, barramento interno e stub de interrupções) adicionada em `rtl/cpu/`.
- ALU expandida com operações aritméticas (`ADC`/`SBC`) e lógicas adicionais, preservando semântica de flags.
- Máquina de estados da `control_unit` revisada para suportar microciclos de preparação/commit da ALU, leitura de imediatos e verificação de interrupções após cada instrução.
- Bloco de interrupções (`int_ctrl.vhd`) atualizado com priorização, vetores oficiais e handshake de acknowledge com a control unit.
- Unidade de endereços (`idu.vhd`) refeita como bloco combinacional, provendo incrementos/decrementos de `PC/SP/HL` e seleção de endereço centralizada para a control unit.
- FSM ampliada para loads imediatos (`LD r,d8`), transferências simples (`LD A,B`, `LD B,A`) e acessos indiretos via `(HL)` incluindo `INC/DEC (HL)`.
- Cobertura estendida para as instruções de carga de 8 bits: tabela completa `LD r,r'` (0x40–0x7F), `LD (HL),d8`, acessos `A↔(BC/DE/HL±/nn)` e modos `LDH/LD (C),A` mapeados na FSM.
- Cargas de 16 bits e fluxo de pilha conectados (`LD rr,d16`, `LD (nn),SP`, `LD HL,SP+e8`, `LD SP,HL`, `PUSH/POP rr`), incluindo atualização consistente de flags e do `SP`.

## Etapas implícitas no processo até aqui
1. **Definição do objetivo**: estabelecer o escopo do projeto e a plataforma alvo (Cyclone IV EP4CE6).
2. **Configuração do controle de versão e layout do repositório**: criação de diretórios e documentação inicial.
3. **Início da arquitetura da CPU**: preparação da documentação técnica e esqueleto dos blocos principais para evoluções incrementais.

## Planejamento proposto para as próximas etapas
1. **Documentação complementar**
   - Registrar convenções de codificação VHDL, padrões de reset, clock e estilo de FSM.
   - Expandir a documentação técnica com mapas de memória e cronogramas de instruções.
2. **Evolução da CPU**
   - Validar em simulação todas as rotas de carga (8 e 16 bits), garantindo que `PUSH/POP`, `LD (nn),SP`, `LD HL,SP+e8` e `LD SP,HL` atualizem `SP`, `HL` e flags conforme o LR35902.
   - Estender a FSM para operações de 16 bits (`ADD HL,rr`, `INC/DEC rr`, `ADD SP,e8`) e preparar o fluxo de empilhamento automático do `PC` usado em interrupções e `CALL/RET`.
   - Implementar saltos, chamadas e retornos (`JR`, `JP`, `CALL`, `RET`) com temporização aproximada aos ciclos oficiais.
   - Completar a cobertura da ALU com rotações, shifts e operações bit a bit (`CB xx`) validando flags remanescentes.
   - Evoluir o bloco de interrupções com suporte às instruções `EI`/`DI`, empilhamento automático do `PC` e desbloqueio condicional do `IME`.
3. **Infraestrutura de testes e simulação**
   - Configurar testbenches para `register_file`, `alu` e `control_unit`, garantindo regressões automáticas.
   - Documentar como executar simulações (ModelSim/ghdl) e registrar resultados esperados.
4. **Planejamento de integração**
   - Definir marcos para integração com memória externa, PPU e demais subsistemas.
   - Avaliar requisitos específicos da placa (pinos, clock base, memória interna) e preparar um projeto Quartus inicial.

## Próximas ações imediatas sugeridas
- Criar testbenches cobrindo cargas de 8/16 bits e operações de pilha (`LD r,r'`, indiretos via `(HL)`, `LD (nn),SP`, `PUSH/POP`, `LD HL,SP+e8`) confirmando flags e evolução do `SP`.
- Planejar a etapa de simulações completas das rotas recém-adicionadas antes de avançar para aritmética de 16 bits e saltos.
- Mapear os requisitos para empilhamento automático do `PC` (interrupções e `CALL/RET`) a partir das infraestruturas já existentes na `control_unit` e `int_ctrl`.
- Continuar alimentando a documentação conforme novos blocos forem implementados.
