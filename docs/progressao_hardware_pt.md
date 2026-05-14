# Progressão da Criação do Hardware do Game Boy FPGA

Este documento explica, em português, como o hardware deste projeto cresce de
forma incremental. Ele não substitui a documentação técnica oficial do projeto,
que permanece em inglês dentro do repositório, mas serve como guia didático para
entender o processo.

## 1. A Ideia Principal

Este projeto não é um emulador de software. A meta é reconstruir, em VHDL
sintetizável, blocos de hardware equivalentes aos blocos internos do Game Boy
DMG-01.

Isso significa que cada parte precisa virar circuito:

- CPU vira uma máquina de estados, registradores, ALU e barramento.
- Memória vira RAM, ROM, registradores de I/O e decodificação de endereços.
- Vídeo vira PPU, framebuffer ou pipeline de pixels.
- Timer vira contadores reais.
- Joypad vira leitura de entradas físicas.
- Interrupções viram sinais, flags e sequenciamento de CPU.

O crescimento do projeto precisa ser incremental porque o FPGA alvo, Cyclone IV
EP4CE6, é pequeno. Não podemos simplesmente implementar tudo de uma vez sem
testar, medir recursos e controlar a complexidade.

## 2. Por Que Não Começar Direto por Jogos

Um jogo de Game Boy depende de quase tudo funcionando ao mesmo tempo:

- CPU com muitos opcodes.
- Flags corretos.
- Pilha e chamadas de subrotina.
- Interrupções.
- Timer.
- Joypad.
- Mapa de memória.
- PPU renderizando tiles, sprites, window e scrolling.
- Acesso correto a VRAM, OAM e registradores de I/O.

Se tentarmos rodar um jogo cedo demais e ele falhar, não saberemos onde está o
problema. Pode ser CPU, memória, timer, vídeo, interrupção, ou uma combinação de
tudo.

Por isso o caminho correto é construir testes pequenos, onde cada falha aponta
para uma parte específica do hardware.

## 3. A Progressão Geral

A progressão recomendada é:

1. Infraestrutura básica do FPGA.
2. Vídeo VGA simples.
3. Framebuffer.
4. CPU mínima.
5. CPU escrevendo em memória e I/O.
6. Runner de ROM com saída serial.
7. Testes de CPU estilo Blargg.
8. Testes visuais controlados pela CPU.
9. PPU mínima com tiles.
10. Timer, joypad e interrupções.
11. ROMs homebrew simples.
12. Jogos básicos.

Cada etapa aumenta a semelhança com o Game Boy real, mas preserva uma forma de
teste clara.

## 4. Etapa M0/M1: Infraestrutura e VGA

Antes da CPU, precisamos provar que a placa está viva e que conseguimos gerar
sinais estáveis.

Nesta fase entram:

- Clock de 50 MHz da placa.
- PLL para gerar clocks internos.
- Reset.
- LEDs.
- Saída VGA.
- Sincronismo horizontal e vertical.

O primeiro teste visual é simples: barras de cor, padrões estáticos ou formas
na tela. Isso prova que o monitor, o conversor VGA-HDMI e o timing de vídeo
estão funcionando.

Nesta etapa ainda não existe Game Boy. Existe apenas uma base de hardware
confiável.

## 5. Etapa M2: Framebuffer

O framebuffer é uma memória de pixels.

No Game Boy real, a PPU não funciona exatamente como um framebuffer simples, mas
usar um framebuffer no início é muito útil porque permite testar vídeo sem
implementar a PPU inteira.

A ideia é:

- Uma parte do hardware escreve pixels.
- O VGA lê esses pixels.
- A tela mostra o resultado.

Com isso conseguimos testar:

- memória de vídeo;
- leitura em outro clock;
- conversão de coordenadas;
- escala de 160x144 para VGA;
- tons de cinza.

Este passo cria uma saída visual estável para os próximos testes.

## 6. Etapa M3: CPU Mínima

A CPU do Game Boy, Sharp LR35902, é o coração do sistema.

Ela precisa ser implementada como hardware, não como um interpretador de
software. No projeto atual, ela cresce em blocos:

- registradores A, F, B, C, D, E, H, L;
- registradores PC e SP;
- ALU;
- decoder de opcodes;
- máquina de estados;
- interface de memória;
- base para interrupções.

O ponto mais importante: a CPU não deve executar uma instrução inteira como se
fosse uma CPU ideal de ciclo único. Ela deve passar por estados como:

- buscar opcode;
- decodificar;
- ler imediato;
- acessar memória;
- escrever resultado;
- atualizar PC ou SP.

Isso aproxima o projeto do comportamento real do Game Boy e permite adicionar
wait states, barramento, PPU e memória real depois.

## 7. Etapa M4: Barramento e Mapa de Memória

O barramento é o bloco que decide para onde cada acesso da CPU vai.

Exemplos:

- endereço `0x0000` vai para ROM;
- endereço `0x8000` vai para VRAM ou framebuffer experimental;
- endereço `0xC000` vai para WRAM;
- endereço `0xFF01` vai para serial SB;
- endereço `0xFF02` vai para serial SC;
- endereço `0xFFFF` vai para IE, o registrador de interrupção.

Esse bloco é essencial porque o Game Boy inteiro é organizado em torno do mapa
de memória.

No projeto atual, o barramento ainda é inicial e econômico. Isso é proposital.
Já descobrimos que RAMs grandes implementadas como registradores combinacionais
consomem muitos recursos no EP4CE6. Então a expansão de memória precisa ser
feita com cuidado, preferindo estruturas que o Quartus consiga mapear para RAMs
internas quando possível.

## 8. Por Que Testar por Serial Antes de Testar por Vídeo

Testes como Blargg geralmente comunicam o resultado pela serial do Game Boy.
Eles escrevem caracteres em:

- `0xFF01`: dado serial;
- `0xFF02`: controle da transferência.

No nosso caso, ainda não precisamos implementar a serial real bit a bit. Para
testes de CPU, basta um stub:

- a CPU escreve um caractere em `0xFF01`;
- a CPU escreve `0x81` em `0xFF02`;
- o testbench captura esse caractere;
- no final, o testbench verifica se a mensagem foi `Passed`.

Isso é poderoso porque permite testar a CPU sem depender da PPU, do VGA ou de
um jogo completo.

Se uma ROM de teste imprime `Passed`, sabemos que uma parte importante da CPU
está funcionando. Se ela falha, podemos olhar qual opcode ou comportamento ainda
está faltando.

## 9. O Runner de ROM

O runner de ROM é uma bancada de teste em simulação.

Ele instancia a CPU, fornece uma memória e observa a saída serial. A ROM pode
ser inicialmente embutida em VHDL, como um pequeno programa que imprime
`Passed`.

Com o tempo, esse runner deve evoluir para:

- carregar bytes de ROMs pequenas;
- executar programas de teste mais longos;
- capturar texto pela serial;
- comparar a saída com o esperado;
- apontar quando a CPU encontrou opcode não implementado.

Esse runner é a ponte entre nossos testes pequenos e ROMs reais de validação.

## 10. Onde Entra o Blargg

Blargg é uma suíte de testes muito conhecida para Game Boy. Ela testa detalhes
da CPU, instrução por instrução.

Mas Blargg não deve ser visto como uma única etapa gigante. Ele deve ser usado
como guia incremental.

O ciclo ideal é:

1. Rodar um teste pequeno.
2. Ver onde falha.
3. Implementar o menor conjunto de opcodes ou comportamento necessário.
4. Rodar de novo.
5. Repetir.

Isso evita implementar muita coisa sem validação.

Antes de Blargg completo, provavelmente precisaremos de:

- branches condicionais;
- ALU imediata;
- loads adicionais;
- `RST`;
- melhor comportamento de flags;
- opcodes CB;
- interrupções mais completas;
- comportamento correto de `HALT`, `EI` e `DI`.

## 11. Primeiro Teste Visual Depois da CPU

Depois que os testes seriais básicos estiverem funcionando, o próximo teste
visual deve ser controlado pela CPU, mas ainda sem exigir a PPU completa.

Exemplos:

- CPU limpa a tela.
- CPU desenha uma faixa vertical.
- CPU desenha um xadrez.
- CPU desenha blocos 8x8.
- CPU move um bloco pela tela.

Esse teste prova que:

- a CPU executa um programa;
- a CPU escreve em memória de vídeo;
- o barramento entrega esses writes ao framebuffer;
- o VGA mostra o resultado.

Esse é o primeiro "hello world visual" do sistema.

## 12. Depois Vem a PPU Real

O Game Boy real não desenha jogos escrevendo cada pixel diretamente em um
framebuffer. Ele usa tiles, tile maps, sprites e registradores de controle.

Então, depois dos testes visuais simples, precisamos substituir aos poucos o
modelo de framebuffer direto por uma PPU mais realista.

Primeira PPU mínima:

- VRAM em `0x8000`;
- tile data;
- tile map;
- leitura de tiles;
- geração de pixels;
- envio para o pipeline VGA.

O primeiro teste visual de PPU deve ser uma tela de tiles estáticos.

Depois entram:

- scrolling;
- window;
- sprites;
- OAM;
- modos da PPU;
- VBlank;
- STAT;
- DMA.

## 13. Quando Jogos Entram

Jogos entram apenas quando CPU, memória, timer, joypad e uma PPU mínima já
estiverem funcionando.

Antes disso, ROMs homebrew pequenas são melhores que jogos comerciais, porque
são mais simples e mais controláveis.

A ordem provável é:

1. ROM própria imprimindo `Passed` via serial.
2. ROM própria desenhando na tela.
3. Testes Blargg parciais.
4. ROM homebrew simples.
5. Testes de PPU como `dmg-acid2`, quando a PPU estiver madura.
6. Jogos pequenos.

## 14. Como Pensar no Crescimento do Hardware

Cada nova etapa deve responder três perguntas:

1. O que este bloco novo precisa fazer?
2. Como eu provo que ele faz isso?
3. Quanto recurso ele custou no FPGA?

Para este projeto, a terceira pergunta é muito importante. O EP4CE6 tem apenas
6.272 logic elements. Se uma implementação funcionar mas consumir recursos
demais, ela ainda não é boa o bastante para o objetivo final.

Por isso o projeto deve sempre crescer assim:

- implementar uma fatia pequena;
- simular;
- sintetizar quando houver mudança em RTL;
- medir recursos;
- documentar;
- só então expandir.

## 15. Resumo da Linha Atual

O projeto já tem:

- VGA funcionando em hardware;
- framebuffer exibindo imagem;
- CPU inicial multi-ciclo;
- ALU e registradores;
- subconjunto inicial de opcodes;
- barramento inicial;
- WRAM pequena;
- HRAM e I/O stubs;
- serial debug stub;
- runner de ROM em simulação imprimindo `Passed`.

O próximo crescimento natural é usar o runner para guiar a expansão da CPU até
ela conseguir rodar testes estilo Blargg de forma progressiva.

Depois disso, voltamos para testes visuais mais ricos e iniciamos a PPU real.
