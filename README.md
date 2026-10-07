# Farm Time

Add-on para **WoW Classic / WoW Forever** que deixa a erva ou o minério que
está na sua frente mais fácil de notar. Quando o jogo escolhe uma erva ou um
minério como alvo de interação, aparece um alerta grande perto do centro da
tela (ícone pulsando + nome + som), e o próprio jogo passa a desenhar um ícone
em cima do nó. Não usa mapa nem minimapa.

## Instalação (uso local)

1. Copie a pasta `FarmTime/` para `World of Warcraft/<versão>/Interface/AddOns/`
   (a pasta do cliente que você usa para o Classic/Forever).
2. O `.toc` declara `## Interface: 16001, 11509` (WoW Forever beta e Classic Era).
   Se o addon aparecer como desatualizado, rode `/dump select(4, GetBuildInfo())`
   e coloque o número na linha `## Interface:` (ou marque "Carregar add-ons
   desatualizados" na tela de personagens).
3. `/reload`. Deve aparecer `Farm Time: carregado` no chat e um botão com uma
   flor no minimapa.

## Uso

- **Botão do minimapa:** clique abre as configurações, clique direito liga/desliga,
  arrastar move o botão pela borda do minimapa.
- **Painel:** liga/desliga o destaque, filtro só ervas/minérios, pulsar, som,
  ícones de interação do jogo, debug, tamanho do ícone e alcance. Os botões
  "Diagnóstico" (`/ft status`) e "Testar alerta" ficam no rodapé.
- **Comandos:** `/ft` abre o painel; `/ft help` lista os demais.

## Estrutura

| Arquivo | Função |
|---|---|
| `FarmTime.toc` | Metadados, SavedVariables (`FarmTimeDB`) e ordem de carregamento |
| `Core.lua` | Configurações padrão, despacho de eventos, comandos `/ft` |
| `Detection.lua` | Decide se o objeto é erva, minério ou outra coisa (listas do Classic + nomes aprendidos ao coletar) |
| `Highlight.lua` | Liga as opções de alvo de interação do jogo e mostra o alerta |
| `Config.lua` | Painel de configurações e botão do minimapa (sem bibliotecas externas) |

## Como funciona

A API de add-ons **não deixa** um add-on listar objetos do mundo nem converter
uma posição 3D em posição na tela. O que dá para usar é a **tecla Interagir**
do próprio jogo: ele escolhe o objeto interagível à sua frente e o expõe pelo
token de unidade `softinteract`. O Farm Time:

1. Liga as opções do jogo (`SoftTargetInteract`, `SoftTargetIconGameObject`,
   `SoftTargetLowPriorityIcons` etc.; os nomes foram conferidos na interface
   oficial do Classic 1.15.9). Por padrão o jogo **não** mostra ícone sobre
   objetos como ervas; com isso ligado, ele desenha. Os valores originais ficam
   salvos e `/ft restore` os devolve.
2. Quando o alvo de interação muda (`PLAYER_SOFT_INTERACT_CHANGED`), lê o nome
   do objeto e classifica como erva, minério ou outro.
3. Se for erva/minério, mostra o alerta com o ícone que o jogo usaria no cursor
   (`SetUnitCursorTexture`) e toca um som.

**Diagnóstico:** `/ft status` mostra a versão do cliente, as opções do jogo e o
alvo de interação atual; `/ft debug` imprime cada mudança de alvo no chat.

**Limitações**

- O jogo escolhe **um objeto por vez** (o mais à frente). Não dá para destacar
  todas as ervas visíveis ao mesmo tempo.
- O jogo só escolhe o alvo de interação **de perto** (poucas jardas), mesmo com
  `/ft range` maior.
- No WoW Forever o jogo desenha uma placa com o nome sobre o nó; o Farm Time
  prende o ícone grande nela. Se a placa não existir, o alerta fica fixo acima
  do centro da tela.
- O alcance é o do jogo; `/ft range` pede mais, mas o cliente pode limitar.
- A classificação usa nomes em inglês. Em outro idioma ou para nós novos do
  Forever, use `/ft all` até coletar cada tipo uma vez (depois o nome fica gravado).

## Regras da Blizzard (ESP de recursos)

- **Add-ons em Lua que usam só a API oficial são permitidos.** A própria API é o
  limite: se ela não expõe algo (como objetos do mundo), o add-on não tem como
  obter. O Farm Time fica 100% dentro disso.
- **Programas externos que leem a memória do jogo, injetam código ou desenham
  sobre a janela para mostrar nós são "third-party programs/hacks"** e violam os
  Termos de Uso — gera banimento **mesmo em uso pessoal**. Uso local não é exceção.
- **Distribuição pública** (CurseForge, Wago etc.) segue a *UI Add-On Development
  Policy*: o add-on deve ser gratuito, com código não ofuscado, sem cobrar por
  recursos, sem pedir doação dentro do jogo de forma intrusiva, e sem afetar
  negativamente servidores ou outros jogadores. Destacar o alvo de interação que o
  próprio jogo já escolheu é o mesmo tipo de coisa que addons de nameplate
  (Plater etc.) já fazem.

## Próximos passos sugeridos

- Ícone específico por recurso (mapear nome do nó → item).
- Alerta arrastável (hoje a posição é fixa acima do centro da tela).
