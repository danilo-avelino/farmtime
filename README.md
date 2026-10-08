# Farm Time

Add-on para **WoW Classic / WoW Forever** que deixa a erva ou o minério que
está na sua frente mais fácil de notar. Quando o jogo escolhe uma erva ou um
minério como alvo de interação, aparece em cima do nó uma placa no estilo
nameplate (ícone do item + nome + tipo, borda verde para erva e laranja para
minério), toca um som e a tecla F coleta. Inclui fast loot e uma janela da
sessão com o valor do que foi coletado (preços do Auctionator).

## Instalação (uso local)

1. Baixe o **[FarmTime.zip](https://github.com/danilo-avelino/farmtime/raw/claude/farm-time-wow-addon-9ehzt2/FarmTime.zip)**
   (contém só a pasta `FarmTime`) e extraia em
   `World of Warcraft/<versão>/Interface/AddOns/` (a pasta do cliente que você
   usa para o Classic/Forever). Ao atualizar, apague a pasta `FarmTime` antiga
   antes de extrair.
2. O `.toc` declara `## Interface: 16001, 11509` (WoW Forever beta e Classic Era).
   Se o addon aparecer como desatualizado, rode `/dump select(4, GetBuildInfo())`
   e coloque o número na linha `## Interface:` (ou marque "Carregar add-ons
   desatualizados" na tela de personagens).
3. `/reload`. Deve aparecer `Farm Time: carregado` no chat e um botão com uma
   flor no minimapa.

## Uso

- **Botão do minimapa:** clique abre as configurações, clique direito liga/desliga,
  arrastar move o botão pela borda do minimapa.
- **Painel:** liga/desliga o destaque, filtro só ervas/minérios, som, tecla F,
  fast loot, janela da sessão, ícones de interação do jogo, debug, tamanho do
  ícone e alcance. Os botões "Diagnóstico" (`/ft status`), "Sessão" e "Testar
  alerta" ficam no rodapé.
- **Tecla F:** o addon liga o F ao comando "Interagir com o alvo"
  (`INTERACTTARGET`), então apertar F coleta a erva/minério destacado. O que o F
  fazia antes fica salvo; desmarcar a opção no painel (ou `/ft key`) devolve.
- **Aviso "aperte F":** perto de uma erva, minério ou corpo que pode ser
  esfolado, aparece abaixo do centro da tela `[F] Gather Kingsblood` /
  `[F] Mine Copper Vein` / `[F] Skin Plainstrider`. A tecla mostrada é a que
  está ligada a "Interagir com o alvo". O corpo esfolável é reconhecido pelo
  texto "Skinnable" do tooltip. Só aparece quando você está **no alcance** de
  coletar/esfolar (alcance do feitiço da profissão sobre o alvo, conferido
  enquanto você se aproxima). Opção no painel ou `/ft prompt`.
- **Ícone:** mostra o ícone do item do recurso (ex.: Kingsblood). Para nós que
  não estão na tabela, o ícone é aprendido no primeiro saque.
- **Fast loot:** pega todo o saque assim que a janela abre. Segurar Shift (a
  tecla de "inverter auto loot") desativa naquele saque. Opção no painel ou `/ft loot`.
- **Idioma:** inglês por padrão; português (BR) pode ser escolhido no painel
  (seção "Language") ou com `/ft lang` (`/ft lang en` / `/ft lang pt`). Troca na hora.
- **Janela da sessão:** lista ervas, minérios, skinning e peixes coletados e
  também **materiais de profissão saqueados de qualquer lugar** (carne, pano,
  couro, metal, elementais — itens da categoria "Trade Goods"; itens de missão
  ficam de fora; opção no painel ou `/ft mats`), com
  quantidade e valor pelo **último preço visto no Auctionator** (sem Auctionator
  aparece "—"). Mostra o total, um timer desde a primeira coleta da sessão e um
  botão **Reset**. É móvel (arraste) e lembra a posição. A sessão fica só na
  memória: ao relogar (ou `/reload`) ela zera e a janela some até a próxima
  coleta, quando reaparece sozinha. `/ft session` mostra/esconde; `/ft reset` zera.
- **Nós salvos na visão (HUD):** toda erva/minério coletado tem a posição
  gravada. Quando você volta à área, o ícone do recurso aparece **na visão do
  personagem**, na direção e distância do nó, com a distância embaixo.
  - **Cinza** = não confirmado. **Colorido** = confirmado: passe o mouse sobre o
    ponto do nó no **minimapa** (rastreamento de ervas/minérios ligado) — o addon
    lê o nome no tooltip e converte a posição do cursor para posição no mundo — ou
    chegue perto até o jogo escolher o nó como alvo de interação.
  - A confirmação vale 5 minutos; depois de coletado, o nó volta a ficar cinza.
  - A posição na tela é **aproximada** (a API não dá acesso à câmera): acompanha
    bem andando/girando com o botão direito; girar a câmera com o botão esquerdo
    não move os ícones. Ajuste com `/ft fov`.
  - Opções no painel (liga/desliga e alcance). `/ft hud`, `/ft nodes`,
    `/ft clearnodes [all]`.
- **Comandos:** `/ft` abre o painel; `/ft help` lista os demais.

## Estrutura

| Arquivo | Função |
|---|---|
| `build.sh` | Gera o `FarmTime.zip` (só a pasta `FarmTime`); rodar a cada atualização |
| `FarmTime.toc` | Metadados, SavedVariables (`FarmTimeDB`) e ordem de carregamento |
| `Core.lua` | Configurações padrão, despacho de eventos, comandos `/ft` |
| `Locale.lua` | Textos em inglês (padrão) e português (BR) e troca de idioma |
| `Detection.lua` | Decide se o objeto é erva, minério ou outra coisa (listas do Classic + nomes aprendidos ao coletar) |
| `Highlight.lua` | Liga as opções de alvo de interação do jogo e mostra o alerta |
| `Prompt.lua` | Aviso "aperte F para coletar/minerar/esfolar" |
| `Nodes.lua` | Guarda a posição dos nós coletados, confirma pelo minimapa e desenha os marcadores 3D |
| `Keybind.lua` | Liga a tecla F ao "Interagir com o alvo" e guarda o atalho anterior |
| `Loot.lua` | Fast loot e registro do que foi saqueado de coletas e dos materiais de profissão |
| `Session.lua` | Janela da sessão: itens, valores do Auctionator, total, timer e reset |
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
3. Se for erva/minério, mostra a placa com o ícone do item (ou, se não souber,
   o ícone que o jogo usaria no cursor, via `SetUnitCursorTexture`) e toca um som.

**Diagnóstico:** `/ft status` mostra a versão do cliente, as opções do jogo e o
alvo de interação atual; `/ft debug` imprime cada mudança de alvo no chat.

**Limitações**

- O jogo escolhe **um objeto por vez** (o mais à frente). Não dá para destacar
  todas as ervas visíveis ao mesmo tempo.
- O jogo só escolhe o alvo de interação **de perto** (poucas jardas), mesmo com
  `/ft range` maior.
- No WoW Forever o jogo desenha uma placa com o nome sobre o nó; o Farm Time
  prende a sua placa nela e esconde o nome/ícone do jogo (opção "Esconder o
  nome do jogo sobre o nó"), restaurando quando o alvo muda. Se a placa não
  existir, o alerta fica fixo acima do centro da tela.
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

- Alerta arrastável (hoje a posição é fixa acima do centro da tela).
