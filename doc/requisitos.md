# Requisitos do Projeto HDLBoy

Este documento resume as principais funcionalidades do Game Boy original que deverão ser implementadas no projeto:

- **CPU LR35902**: processador de 8 bits compatível com o conjunto de instruções do Z80, incluindo operações aritméticas, lógicas e de controle de fluxo.
- **Memória**: gerenciamento de ROM, RAM interna e externa, além de registros de hardware mapeados em memória.
- **PPU (unidade de processamento de pixels)**: geração de gráficos em tela LCD com suporte a tiles, sprites e paletas de cores.
- **APU (unidade de áudio)**: quatro canais de som independentes (dois quadrados, um wave e um ruído) com controle de volume e frequência.
- **Temporizadores**: temporizador de divisão e temporizador programável para sincronização de eventos.
- **Interrupções**: atendimento a interrupções de vídeo, temporizadores, serial e botões.
- **Interface de Entrada**: leitura do teclado de botões (direcionais e botões A/B/Start/Select).
- **Comunicação Serial**: suporte à porta link para troca de dados entre consoles.

Esses requisitos servirão como base para o desenvolvimento e verificação do HDLBoy.
