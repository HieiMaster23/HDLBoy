# Processo de Otimizacao de Recursos para o TCC

Este documento registra o processo de otimizacao realizado durante a fase de
integracao CPU/PPU do projeto `gameboy-fpga-core`. O objetivo e preservar, em
formato reaproveitavel para o TCC, nao apenas o resultado final, mas tambem o
raciocinio tecnico: qual problema foi observado, quais hipoteses foram testadas,
quais alternativas foram rejeitadas e qual evidencia de sintese confirmou a
decisao.

## 1. Contexto

O alvo fisico do projeto e a FPGA Cyclone IV EP4CE6, com:

- 6.272 logic elements;
- 276.480 bits de block RAM;
- 30 blocos M9K;
- 2 PLLs.

Esse dispositivo e pequeno para uma reimplementacao em hardware do Game Boy DMG.
Por isso, a viabilidade do projeto depende de manter um nucleo enxuto, sem APU
no caminho critico inicial, suficiente para jogos simples como `Tetris`,
`Dr. Mario` e ROMs de menor complexidade grafica.

Durante a evolucao da PPU, o projeto chegou a um ponto de alerta: a composicao
completa de ate 10 sprites por linha elevou o uso para 5.286 LEs, ou 84% do
dispositivo. Esse numero ainda cabia fisicamente, mas deixava pouca margem para
DMA, joypad, Window, fluxo de ROM/SDRAM e ajustes finais.

## 2. Objetivo da Otimizacao

O objetivo definido foi reduzir o uso de logic elements para uma faixa proxima
de 4.600 LEs, mantendo:

- o renderer de background;
- o loop continuo de frames da PPU;
- lookup de paleta BGP;
- controles iniciais de LCDC;
- OAM storage e bloqueio de acesso;
- OAM scan;
- composicao inicial de sprites com ate 10 candidatos por linha;
- integracao CPU -> VRAM -> PPU -> framebuffer -> VGA.

Ou seja, a meta nao era remover funcionalidade, mas trocar estruturas caras por
implementacoes mais adequadas ao hardware da FPGA.

## 3. Metodologia Usada

A otimizacao foi conduzida por medicao incremental, nao por suposicao.

O fluxo adotado foi:

1. identificar o maior crescimento de recursos no relatorio do Quartus;
2. formular uma hipotese de otimizacao localizada;
3. alterar apenas a estrutura relacionada;
4. executar simulacoes de regressao;
5. sintetizar novamente o top completo;
6. comparar os numeros antes e depois;
7. manter apenas mudancas que preservassem comportamento e reduzissem custo real.

Esse metodo e importante para o TCC porque mostra que a arquitetura foi guiada
por evidencia experimental. Em FPGA, uma mudanca que parece menor no RTL pode
ser irrelevante para o fitter, enquanto uma pequena mudanca na forma de inferir
memoria pode economizar centenas ou milhares de LEs.

## 4. Linha do Tempo das Otimizacoes

| Etapa | Uso de LEs | M9Ks | Observacao |
| --- | ---: | ---: | --- |
| Composicao direta de 10 sprites | 5.286 | 23 | Caminho combinacional grande no pixel final |
| Composicao serializada de sprites | 5.013 | 23 | Economia de 273 LEs |
| Escala VGA por fases raster | 4.995 | 23 | Remove logica de multiplicacao/divisao por 3 |
| Gates configuraveis de debug/smoke | 4.995 | 23 | Boa limpeza arquitetural, sem reducao final no top |
| HRAM inferida como M9K | 3.674 | 24 | Economia de 1.321 LEs |

Essa progressao mostra um ponto central: nem toda limpeza arquitetural gera
ganho de area no top final. A separacao de debug/smoke foi correta, mas o
Quartus ja removia boa parte da logica sem fanout. A maior reducao veio quando
a HRAM deixou de ser implementada como registradores distribuidos e passou a ser
inferida como memoria embarcada.

## 5. Caso Principal: HRAM como M9K

### 5.1 Problema observado

A HRAM do Game Boy ocupa a faixa `0xFF80..0xFFFE`. Embora seja pequena, a sua
implementacao anterior ficava dentro do `bus_controller` como array local, com
leitura registrada e sobreposicao temporaria dos enderecos de debug `0xFF80` e
`0xFF81`.

O resultado era ruim para o EP4CE6: o Quartus nao inferia uma RAM embarcada e a
estrutura permanecia como logica distribuida no proprio controlador de
barramento. Isso aumentava bastante o custo do `bus_controller`.

### 5.2 Hipotese

A hipotese foi que a HRAM poderia ser inferida como um bloco M9K se fosse
isolada em uma entidade propria, com template de RAM sincrona simples. O projeto
ja possuia `mem_ready` no caminho da CPU, entao a arquitetura estava preparada
para memorias com leitura registrada.

### 5.3 Implementacao

Foi criado o modulo `rtl/memory/hram.vhd`:

- RAM sincrona single-port;
- 128 palavras de 8 bits;
- endereco de 7 bits;
- escrita controlada por `we`;
- leitura registrada;
- atributo `ramstyle` definido como `"M9K"`.

No `bus_controller`, o array interno da HRAM foi removido. O controlador passou
a instanciar `entity work.hram`, usando:

- `hram_cpu_we <= cpu_write and hram_selected`;
- `cpu_addr(6 downto 0)` como endereco local;
- `cpu_data_out` como dado de escrita;
- `hram_q` como dado de leitura.

Os scripts ModelSim e o projeto Quartus tambem foram atualizados para compilar
`hram.vhd` antes de `bus_controller.vhd`.

### 5.4 Verificacao

As seguintes regressoes foram executadas:

- `run_bus_controller.do`;
- `run_cpu_ppu_background_demo_top.do`;
- `run_ppu_background_demo_top.do`;
- `run_cpu_video_smoke_top.do`;
- build Quartus completo.

Todas passaram. O build Quartus terminou com 0 erros e 34 warnings, com
TimeQuest totalmente constrained para setup e hold.

## 6. Resultado Medido

| Recurso | Antes | Depois | Variacao |
| --- | ---: | ---: | ---: |
| Logic elements | 4.995 | 3.674 | -1.321 |
| Registradores | 1.965 | 941 | -1.024 |
| Bits de memoria | 179.200 | 180.224 | +1.024 |
| M9Ks | 23 | 24 | +1 |
| Multiplicadores | 0 | 0 | 0 |
| PLLs | 1 | 1 | 0 |

O `bus_controller` caiu de 1.870 logic cells e 1.210 registradores para 543
logic cells e 186 registradores. O novo bloco `hram:u_hram` passou a consumir
1.024 bits em 1 M9K, sem custo relevante em LEs.

O resultado superou a meta inicial. A intencao era chegar perto de 4.600 LEs; o
projeto caiu para 3.674 LEs, ou 59% da FPGA, deixando aproximadamente 2.598 LEs
livres.

## 7. Interpretacao Academica

Este caso e relevante para o TCC porque ilustra uma caracteristica pratica de
projetos em FPGA: o custo de uma arquitetura nao depende apenas da quantidade
abstrata de memoria, mas da forma como o RTL permite que a ferramenta de sintese
infira os recursos fisicos corretos.

Uma memoria pequena, se descrita de forma inconveniente ou acoplada a muita
logica de controle, pode ser implementada com flip-flops e LUTs. Em uma FPGA
pequena, isso pode consumir uma parcela desproporcional dos logic elements. Ao
isolar a memoria em um template sincrono compativel com o inferidor do Quartus,
o projeto trocou logica distribuida por um bloco M9K dedicado.

O trade-off foi favoravel:

- perdeu-se 1 M9K;
- ganharam-se 1.321 LEs;
- reduziram-se 1.024 registradores;
- preservou-se o comportamento verificado por testbench;
- recuperou-se margem para continuar a integracao jogavel.

Essa decisao tambem mostra que otimizacao em FPGA deve ser orientada por
relatorios de sintese. A tentativa de apenas separar debug/smoke melhorou a
arquitetura, mas nao reduziu o top porque o Quartus ja removia aquela logica.
Ja a reestruturacao da HRAM atacou logica realmente retida, por isso gerou
resultado expressivo.

## 8. Texto Reaproveitavel para o TCC

Um trecho possivel para a secao de discussao:

```text
Durante a integracao inicial da CPU com a PPU, a utilizacao de logic elements
atingiu uma faixa critica para o dispositivo EP4CE6. A composicao de sprites
com ate 10 candidatos por linha elevou o projeto para 5.286 LEs, equivalente a
84% da FPGA. Para preservar margem de integracao, foi adotada uma estrategia de
otimizacao incremental baseada em relatorios de sintese do Quartus. A primeira
reducao relevante veio da serializacao da composicao de sprites, que removeu um
caminho combinacional de selecao de pixels. Em seguida, a escala VGA 3x foi
reestruturada para usar contadores de fase em vez de calculos de divisao por
constante.

O maior ganho, entretanto, ocorreu na HRAM. A implementacao anterior mantinha a
memoria dentro do controlador de barramento, levando o Quartus a implementa-la
como registradores distribuidos. Ao mover a HRAM para um modulo sincrono
dedicado, com template compativel com inferencia de RAM M9K, o uso do top caiu
de 4.995 para 3.674 LEs. O custo foi o uso de um bloco M9K adicional, enquanto
a economia foi de 1.321 LEs e 1.024 registradores. Esse resultado evidencia a
importancia de adaptar a descricao VHDL aos recursos fisicos disponiveis na
FPGA, especialmente em dispositivos de baixa capacidade.
```

## 9. Licoes Aprendidas

- Otimizacao deve mirar logica retida, nao apenas logica que parece existir no
  RTL.
- Relatorios de hierarquia do Quartus sao essenciais para localizar blocos
  caros.
- Em Cyclone IV pequeno, trocar LEs por M9Ks pode ser um excelente negocio,
  desde que ainda exista margem de block RAM.
- Memorias devem ser descritas em templates simples e sincronos para favorecer
  inferencia de `altsyncram`.
- Pequenas memorias nao sao automaticamente baratas se forem inferidas como
  registradores.
- Cada fatia funcional deve ser acompanhada por sintese, porque o fitter pode
  mudar significativamente a area real.

## 10. Impacto no Plano do Projeto

Depois dessa otimizacao, a pressao imediata sobre logic elements diminuiu. O
projeto passou a ter margem suficiente para continuar o caminho jogavel sem
parar para micro-otimizacoes prematuras.

A proxima sequencia recomendada e:

1. implementar OAM DMA;
2. implementar joypad real;
3. adicionar Window;
4. retomar fluxo de ROM/SDRAM;
5. manter APU fora do escopo ate o sistema nao-audio estar funcional.

O ponto de atencao passa a ser o uso de M9K: o projeto esta em 24 / 30 blocos.
Ainda ha margem, mas cada nova memoria deve ser planejada com cuidado.
