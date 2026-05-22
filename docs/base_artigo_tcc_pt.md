# Base para Futuro Artigo ou TCC

Este documento define como o projeto `gameboy-fpga-core` deve ser documentado
desde agora para que, no futuro, seja possível transformá-lo em um artigo técnico
ou trabalho acadêmico detalhado, com estrutura próxima à de um TCC.

O objetivo é evitar que o texto final precise ser reconstruído apenas de memória.
Cada avanço relevante do projeto deve deixar material reaproveitável: contexto,
decisão, implementação, verificação, resultado e aprendizado.

## 1. Objetivo da Documentação Acumulativa

Ao final do projeto, queremos ter material suficiente para escrever com clareza:

- por que o projeto foi proposto;
- quais referências técnicas sustentam a arquitetura;
- como o hardware foi dividido em subsistemas;
- por que a ordem de implementação foi escolhida;
- quais alternativas foram consideradas;
- como cada módulo foi testado;
- quais resultados foram medidos em simulação, síntese e hardware;
- quais trade-offs foram impostos pelo Cyclone IV EP4CE6;
- quais limitações permaneceram abertas em cada etapa.

Esse conjunto transforma a documentação do projeto em um arquivo histórico de
engenharia, não apenas em um manual de uso.

## 2. Estrutura Provável do Futuro Artigo

Uma estrutura provável para o artigo ou TCC é:

1. **Introdução**
   - motivação;
   - objetivo;
   - relevância do projeto;
   - escopo.
2. **Referencial Teórico**
   - arquitetura do Game Boy DMG-01;
   - CPU LR35902;
   - PPU;
   - mapa de memória;
   - temporização;
   - fundamentos de FPGA/VHDL.
3. **Plataforma de Desenvolvimento**
   - placa OMDAZZ;
   - Cyclone IV EP4CE6;
   - Quartus II 13.0 SP1;
   - ModelSim;
   - restrições de recursos.
4. **Metodologia**
   - desenvolvimento incremental;
   - estratégia de testes;
   - uso de Blargg;
   - validação em hardware;
   - medição de recursos por milestone.
5. **Arquitetura Proposta**
   - visão geral dos módulos;
   - relógios;
   - barramento;
   - integração entre subsistemas.
6. **Implementação**
   - VGA e framebuffer;
   - CPU;
   - memória;
   - timer/interrupções;
   - PPU;
   - demais blocos.
7. **Verificação e Resultados**
   - testbenches;
   - ROMs de teste;
   - síntese;
   - utilização de recursos;
   - validação em hardware real.
8. **Discussão**
   - trade-offs;
   - dificuldades;
   - limitações;
   - decisões que preservaram viabilidade no EP4CE6.
9. **Conclusão e Trabalhos Futuros**
   - estado final;
   - metas alcançadas;
   - extensões futuras.

## 3. Tipos de Documento que Devemos Manter

### 3.1 Documentos de Controle

Servem para preservar o estado atual e orientar o próximo trabalho.

Exemplos:

- `project_control_pt.md`;
- planos de teste;
- registros de checkpoint.

### 3.2 Documentos Técnicos

Servem para explicar como o sistema funciona.

Exemplos:

- `architecture.md`;
- `design_decisions.md`;
- `m3_cpu.md`;
- `resource_utilization.md`.

### 3.3 Documentos Narrativos

Servem para explicar por que o projeto evoluiu daquela forma.

Exemplos:

- `progressao_hardware_pt.md`;
- este documento;
- futuros resumos por milestone.

Esses documentos narrativos serão especialmente úteis ao escrever a metodologia,
a discussão e a justificativa das decisões de projeto.

## 4. Registro Mínimo por Etapa Relevante

Cada fatia importante do projeto deve deixar registrado:

1. **Contexto**
   - qual problema estava sendo resolvido;
   - por que aquela etapa era necessária naquele momento.
2. **Objetivo**
   - qual comportamento verificável seria alcançado.
3. **Decisão de Projeto**
   - qual solução foi escolhida;
   - quais alternativas foram evitadas;
   - qual trade-off foi aceito.
4. **Implementação**
   - quais módulos mudaram;
   - como a arquitetura foi afetada.
5. **Verificação**
   - quais testbenches foram usados;
   - quais ROMs de teste foram executadas;
   - se houve validação em hardware.
6. **Resultado**
   - o que passou;
   - o que ainda não passou;
   - qual foi o uso de recursos.
7. **Lições Aprendidas**
   - qual conhecimento novo ficou claro;
   - qual risco foi descoberto;
   - qual decisão futura foi influenciada por essa etapa.

## 5. Modelo de Registro Reaproveitável

O modelo abaixo pode ser usado sempre que uma etapa merecer registro mais
formal.

```text
### Nome da etapa

Contexto:
- ...

Objetivo:
- ...

Decisão de projeto:
- ...

Implementação:
- ...

Verificação:
- ...

Resultados:
- ...

Impacto de recursos:
- ...

Limitações restantes:
- ...

Lições aprendidas:
- ...

Próximo passo:
- ...
```

## 6. Exemplos Já Existentes no Projeto

Alguns pontos do projeto já têm valor claro para o futuro artigo:

- a escolha de implementar framebuffer antes da PPU real;
- a validação por serial antes de depender da PPU;
- a WRAM combinacional que quase esgotou os logic elements e a migração para RAM
  inferida;
- a evolução da CPU de funcional para temporalmente fiel;
- o uso de Blargg como trilha de verificação incremental;
- o smoke test visual com `1234` no display de sete segmentos;
- a extração do timer compartilhado e o custo real medido em síntese;
- o processo de otimizacao que reduziu o top de 4.995 para 3.674 LEs ao mover
  a HRAM para um bloco M9K inferido, registrado em
  `optimization_process_pt.md`.

Esses casos são bons porque mostram engenharia de verdade: havia um problema,
uma decisão, uma verificação e uma consequência mensurável.

## 7. Critério para Saber se Uma Etapa Merece Registro Formal

Uma etapa deve receber documentação mais rica quando ela:

- muda a arquitetura;
- fecha um marco importante;
- revela um risco relevante;
- altera significativamente o uso de recursos;
- corrige uma hipótese anterior;
- cria uma nova forma de testar o sistema;
- aproxima o projeto de ROMs reais ou de hardware real.

Mudanças pequenas também devem ser registradas no controle do projeto, mas não
precisam virar texto narrativo extenso se não acrescentarem entendimento novo.

## 8. Regra de Ouro

Ao final de cada avanço importante, devemos conseguir responder:

1. O que mudou?
2. Por que mudou?
3. Como foi provado?
4. Quanto custou?
5. O que aprendemos?

Se essas cinco respostas estiverem documentadas, o futuro artigo não precisará
ser inventado depois. Ele poderá ser organizado a partir de evidências já
preservadas ao longo do desenvolvimento.
