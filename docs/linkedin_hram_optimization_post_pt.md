# LinkedIn Post Draft - HRAM Resource Optimization

Este documento registra uma proposta de post profissional para LinkedIn sobre a
otimizacao de recursos realizada no projeto `gameboy-fpga-core`.

## Versao Principal do Post

Estou desenvolvendo uma reimplementacao em hardware do Game Boy DMG em VHDL,
mirando uma FPGA Cyclone IV EP4CE6. E uma placa pequena para esse tipo de
projeto: sao apenas 6.272 logic elements e 30 blocos M9K.

Por isso, uma parte importante do trabalho nao e apenas "fazer funcionar", mas
fazer caber.

Recentemente cheguei a um ponto interessante da integracao CPU/PPU. A primeira
fatia de composicao de sprites ja estava funcionando, incluindo ate 10
candidatos por scanline, mas o uso de logica subiu para uma faixa desconfortavel:

- 5.286 / 6.272 LEs
- 84% da FPGA
- 23 / 30 blocos M9K

Ainda cabia, mas com pouca margem para o que vem depois: DMA, joypad, Window,
fluxo de ROM/SDRAM e ajustes finais.

Entao entrei em uma etapa de otimizacao guiada por sintese. A ideia foi manter
a funcionalidade, mas reduzir estruturas caras no hardware.

O processo foi incremental:

1. Primeiro, serializei a composicao dos 10 sprites.
   Em vez de avaliar todos os candidatos em um grande caminho combinacional no
   pixel final, passei a avaliar um candidato por ciclo interno.

   Resultado: 5.286 -> 5.013 LEs.

2. Depois, otimizei o pipeline VGA.
   A escala fixa 3x deixou de usar calculos de divisao/multiplicacao por
   constante e passou a usar fases raster simples.

   Resultado: 5.013 -> 4.995 LEs.

3. Em seguida, separei logica de debug/smoke por generics.
   Foi uma boa limpeza arquitetural, mas o Quartus ja podava boa parte dessa
   logica no top atual.

   Resultado: sem reducao final relevante.

4. O maior ganho veio da HRAM.

   A HRAM do Game Boy e pequena, mas estava implementada dentro do
   `bus_controller`. O Quartus nao inferia uma RAM embarcada e acabava mantendo
   essa estrutura como registradores/logica distribuida.

   A solucao foi mover a HRAM para um modulo sincrono dedicado, com template
   simples de RAM single-port e inferencia em M9K.

   Resultado:

   - 4.995 -> 3.674 LEs
   - 1.965 -> 941 registradores
   - 23 -> 24 blocos M9K

No total, a ultima etapa economizou 1.321 logic elements e 1.024 registradores,
ao custo de um bloco M9K adicional.

Esse foi um bom exemplo pratico de trade-off em FPGA: em uma arquitetura pequena,
trocar logica distribuida por memoria embarcada pode ser decisivo.

O ponto mais importante para mim foi a confirmacao de uma regra simples:
otimizacao em FPGA precisa ser guiada por relatorios de sintese, nao apenas por
intuicao olhando o RTL.

Uma mudanca que parece limpa no codigo pode nao reduzir nada no fit final. Por
outro lado, ajustar a forma como uma memoria e descrita pode liberar uma parte
grande da FPGA.

Agora o projeto voltou para uma faixa bem mais confortavel:

- 3.674 / 6.272 LEs
- 59% da FPGA
- 24 / 30 blocos M9K

Isso cria margem para continuar o caminho do primeiro sistema jogavel, mantendo
o foco em um core enxuto para jogos simples antes de pensar em APU ou recursos
mais completos.

Para mim, esse tipo de checkpoint e uma das partes mais interessantes de
projetos em FPGA: o resultado nao depende apenas de implementar a especificacao,
mas de entender como a descricao VHDL se transforma em recursos fisicos reais.

## Versao Mais Curta

Estou desenvolvendo uma reimplementacao em hardware do Game Boy DMG em VHDL,
mirando uma FPGA Cyclone IV EP4CE6.

Depois da primeira fatia de composicao de sprites, o projeto chegou a 5.286 LEs,
ou 84% da FPGA. Cabia, mas a margem ficou apertada para DMA, joypad, Window e
integracao final.

Entao fiz uma rodada de otimizacao guiada por sintese:

- composicao de sprites serializada: 5.286 -> 5.013 LEs;
- escala VGA 3x por fases raster: 5.013 -> 4.995 LEs;
- separacao de debug/smoke por generics: limpeza arquitetural, sem ganho final;
- HRAM movida para um modulo sincrono inferido como M9K: 4.995 -> 3.674 LEs.

O maior ganho veio da HRAM. Ela era pequena, mas estava sendo mantida como
registradores/logica distribuida dentro do `bus_controller`. Ao isola-la em um
template de RAM single-port, o Quartus passou a inferir um bloco M9K.

Resultado final:

- 1.321 LEs economizados;
- 1.024 registradores a menos;
- custo de apenas +1 bloco M9K;
- utilizacao final: 3.674 / 6.272 LEs, ou 59%.

Esse checkpoint reforcou uma licao importante: em FPGA, otimizacao precisa ser
guiada pelos relatorios de sintese. O RTL descreve a intencao, mas o que decide
a viabilidade e como essa descricao vira hardware real.

## Estrutura de Carrossel

### Slide 1 - Titulo

**Otimizando um core de Game Boy em FPGA**

Subtitulo:

De 84% para 59% de uso de logic elements sem remover funcionalidade.

Visual sugerido:

- imagem simples da placa/FPGA ou um bloco "Game Boy DMG core -> Cyclone IV";
- destaque numerico: `5.286 LEs -> 3.674 LEs`.

### Slide 2 - Restricao do Projeto

Texto:

O alvo e uma Cyclone IV EP4CE6:

- 6.272 logic elements;
- 30 blocos M9K;
- 2 PLLs.

Objetivo: um core enxuto para rodar jogos simples antes de adicionar recursos
como APU.

Visual sugerido:

- barra de capacidade da FPGA;
- marcadores para LEs, M9K e PLLs.

### Slide 3 - Problema

Texto:

A primeira composicao de sprites com ate 10 candidatos por scanline funcionou,
mas elevou o uso para:

- 5.286 / 6.272 LEs;
- 84% da FPGA;
- pouca margem para DMA, joypad, Window e integracao final.

Visual sugerido:

- gauge ou barra em vermelho/laranja mostrando 84%;
- pequena lista "ainda faltava: DMA, joypad, Window, ROM flow".

### Slide 4 - Metodo

Texto:

O processo foi guiado por sintese:

1. medir;
2. localizar bloco caro;
3. criar hipotese;
4. alterar uma estrutura por vez;
5. rodar regressao;
6. sintetizar novamente;
7. comparar antes/depois.

Visual sugerido:

- fluxograma circular ou linear;
- icones simples: report, RTL, simulation, synthesis, result.

### Slide 5 - Primeiras Otimizacoes

Texto:

1. Sprite composition serializada:
   `5.286 -> 5.013 LEs`

2. VGA scaler por fases raster:
   `5.013 -> 4.995 LEs`

3. Debug/smoke por generics:
   melhor arquitetura, sem ganho final no top.

Visual sugerido:

- mini timeline;
- tabela com etapa, antes, depois.

### Slide 6 - O Insight Principal

Texto:

A HRAM era pequena, mas estava cara.

Como estava dentro do `bus_controller`, o Quartus nao inferia RAM embarcada e
mantinha a estrutura como registradores/logica distribuida.

Visual sugerido:

Antes:

```text
bus_controller
  └── HRAM as distributed registers
```

Depois:

```text
bus_controller
  └── hram.vhd -> inferred M9K
```

### Slide 7 - Resultado

Texto:

Mover a HRAM para um modulo sincrono dedicado:

- `4.995 -> 3.674 LEs`
- `1.965 -> 941 registradores`
- `23 -> 24 M9Ks`

Economia:

- 1.321 LEs;
- 1.024 registradores;
- custo de +1 M9K.

Visual sugerido:

- tabela antes/depois;
- setas verdes para reducao de LEs/regs;
- seta cinza para aumento de M9K.

### Slide 8 - Licao de Engenharia

Texto:

Em FPGA, o RTL nao e apenas codigo. Ele e uma descricao que precisa ser
reconhecida pela ferramenta como hardware eficiente.

Uma memoria pequena pode ser cara se virar flip-flops. Um template sincrono
simples pode permitir que ela vire block RAM.

Visual sugerido:

- comparacao "LUT/FF fabric" vs "M9K block RAM";
- frase de destaque: "Otimizar e alinhar a descricao VHDL ao hardware fisico".

### Slide 9 - Estado Atual

Texto:

Checkpoint atual:

- 3.674 / 6.272 LEs;
- 59% da FPGA;
- 24 / 30 M9Ks;
- APU fora do escopo inicial;
- proximo foco: OAM DMA, joypad, Window e ROM flow.

Visual sugerido:

- barra verde em 59%;
- roadmap curto com proximas etapas.

### Slide 10 - Fechamento

Texto:

Esse tipo de otimizacao e uma das partes mais interessantes do desenvolvimento
em FPGA: fazer a arquitetura funcionar e tambem fazer a arquitetura caber.

Visual sugerido:

- quote final;
- imagem/diagrama do pipeline CPU -> bus -> PPU -> framebuffer -> VGA.

## Exemplos Visuais Simples

### Grafico 1 - Uso de LEs por checkpoint

Dados:

| Checkpoint | LEs |
| --- | ---: |
| 10-sprite composition | 5.286 |
| Serialized sprite composition | 5.013 |
| VGA raster scaler | 4.995 |
| HRAM as M9K | 3.674 |

Formato sugerido:

- grafico de barras vertical;
- linha horizontal em 4.600 LEs;
- linha horizontal em 6.272 LEs.

### Grafico 2 - Antes/depois da HRAM

Dados:

| Recurso | Antes | Depois |
| --- | ---: | ---: |
| LEs | 4.995 | 3.674 |
| Registradores | 1.965 | 941 |
| M9Ks | 23 | 24 |

Formato sugerido:

- tres barras duplas;
- LEs e registradores em verde por reducao;
- M9K em cinza por aumento controlado.

### Diagrama 1 - Estrutura da HRAM

Antes:

```text
CPU
  |
bus_controller
  |-- address decode
  |-- IO registers
  |-- HRAM array as local logic
  |-- read mux
```

Depois:

```text
CPU
  |
bus_controller
  |-- address decode
  |-- IO registers
  |-- hram interface
        |
        v
      hram.vhd
      single-port synchronous RAM
      inferred as M9K
```

### Diagrama 2 - Metodologia de otimizacao

```text
Quartus report
      |
      v
Find expensive retained logic
      |
      v
Create local hypothesis
      |
      v
Change RTL structure
      |
      v
Run regression tests
      |
      v
Synthesize full top
      |
      v
Keep only measured wins
```

## Sugestao de Legenda para Imagens

Legenda curta:

```text
Resource optimization checkpoint in my VHDL Game Boy FPGA core.

The largest gain came from moving HRAM out of distributed bus-controller logic
and into a synchronous RAM template inferred as Cyclone IV M9K block RAM.
```

Legenda em portugues:

```text
Checkpoint de otimizacao de recursos no meu core de Game Boy em VHDL.

O maior ganho veio ao mover a HRAM de logica distribuida dentro do controlador
de barramento para uma RAM sincrona inferida como bloco M9K da Cyclone IV.
```

## Hashtags Possiveis

- `#FPGA`
- `#VHDL`
- `#DigitalDesign`
- `#HardwareDesign`
- `#EmbeddedSystems`
- `#ComputerArchitecture`
- `#GameBoy`
- `#RetroComputing`
- `#Engineering`
- `#Quartus`
