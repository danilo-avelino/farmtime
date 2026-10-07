# Farm Time

Add-on de World of Warcraft que deixa **a erva ou o minério que já está na sua
frente** mais fácil de ver: um ícone grande, com brilho pulsando e o nome do nó,
desenhado sobre o próprio objeto no mundo 3D. Não usa mapa nem minimapa.

## Instalação (uso local)

1. Copie a pasta `FarmTime/` para `World of Warcraft/_retail_/Interface/AddOns/`.
2. No jogo, confira a versão da interface com
   `/dump select(4, GetBuildInfo())` e, se for diferente, ajuste a linha
   `## Interface:` em `FarmTime/FarmTime.toc` (ou marque "Carregar add-ons desatualizados").
3. `/reload` e digite `/ft help`.

## Estrutura

| Arquivo | Função |
|---|---|
| `FarmTime.toc` | Metadados, SavedVariables (`FarmTimeDB`) e ordem de carregamento |
| `Core.lua` | Configurações padrão, despacho de eventos, comandos `/ft` |
| `Detection.lua` | Decide se o objeto é erva, minério ou outra coisa (tooltip + nomes aprendidos ao coletar) |
| `Highlight.lua` | Liga o soft target de interação do jogo e ancora o destaque na placa de nome do objeto |

## Como funciona

A API de add-ons **não deixa** um add-on listar objetos do mundo (ervas,
minérios) nem converter uma posição 3D em posição na tela. O que dá para usar é
um recurso do próprio jogo: o **soft target de interação** (Opções → Controles →
"Interagir com alvo"). Com ele, o cliente escolhe o objeto interagível à sua
frente e pode desenhar uma placa de nome sobre ele. O Farm Time:

1. Liga as opções do jogo necessárias (`SoftTargetInteract`,
   `SoftTargetNameplateInteract`, `SoftTargetIconGameObject`,
   `SoftTargetInteractRange` etc.). Os valores originais ficam salvos e
   `/ft restore` os devolve.
2. Quando o alvo de interação muda (`PLAYER_SOFT_INTERACT_CHANGED`), lê o objeto
   pelo token de unidade `softinteract` e classifica: erva, minério ou outro.
3. Ancora um ícone grande e pulsante na placa de nome do objeto. Como a placa é
   posicionada pelo próprio cliente, o ícone fica exatamente sobre o nó e
   acompanha a câmera. Também mostra o nome do nó abaixo do centro da tela.

**Limitações**

- O jogo escolhe **um objeto por vez** (o mais à frente/central). Não dá para
  destacar todas as ervas visíveis ao mesmo tempo.
- O alcance do soft target é limitado pelo cliente; `/ft range` pede mais, mas
  o jogo pode reduzir.
- A primeira vez que você vê um tipo de nó, a classificação depende do tooltip.
  Se não funcionar, use `/ft all` para destacar qualquer objeto; depois de
  coletar um nó, o nome dele fica gravado como erva/minério.
- Em Midnight (12.x) algumas informações de unidades viram "secret values" em
  combate; nesse caso o destaque simplesmente não aparece.

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

- Ícone específico por recurso (mapear nome do nó → item e usar `C_Item.GetItemIconByID`).
- Painel de configurações (`Settings.RegisterCanvasLayoutCategory`).
- Som curto quando um nó novo entra como alvo de interação.
