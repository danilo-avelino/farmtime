# Farm Time

Add-on de World of Warcraft que destaca ervas e minérios **no campo de visão 3D**
(um HUD sobre a tela), em vez de no minimapa.

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
| `Core.lua` | Namespace, configurações padrão, despacho de eventos, comandos `/ft` |
| `Detection.lua` | Registra a posição de cada erva/minério que você coleta |
| `Overlay.lua` | Projeta os nós conhecidos na tela (sobre o `WorldFrame`) com `C_Timer.NewTicker` |

## Como funciona — e por que não é um "ESP" de verdade

O que o prompt original imaginava (ler os nós próximos e converter a posição 3D
para a tela) **não é possível pela API oficial de add-ons**:

- **Não existe API para listar objetos do mundo.** Ervas e minérios são
  *GameObjects*; o add-on não consegue enumerá-los. Os pontinhos do minimapa
  (Rastrear Ervas/Minérios) são desenhados pelo cliente e não são legíveis por Lua.
- **Não existe `WorldToScreen` nem acesso à câmera** (posição, pitch, yaw, zoom).
  Placas de nome (nameplates) só existem para unidades (NPCs/jogadores), não para nós.

Por isso o Farm Time usa uma abordagem dentro das regras:

1. **Detecção por aprendizado** — quando você coleta (feitiços "Herborismo" /
   "Mineração"), o addon grava sua posição (`UnitPosition`) e o nome do nó
   (`UNIT_SPELLCAST_SENT`). É a mesma ideia do GatherMate2. Nós a menos de 10
   jardas um do outro são mesclados.
2. **Projeção aproximada** — com sua posição e direção (`GetPlayerFacing`), o
   addon faz uma projeção em perspectiva assumindo a câmera atrás do personagem.
   Funciona bem andando/girando com o botão direito; se girar a câmera com o
   botão esquerdo, os ícones não acompanham. Calibre com `/ft test`, `/ft fov`
   e `/ft height`.
3. Nós fora do campo de visão aparecem esmaecidos na borda esquerda/direita.

Limitações: `UnitPosition` e `GetPlayerFacing` retornam `nil` dentro de
instâncias, então o HUD só funciona no mundo aberto. A API muda entre patches
(especialmente com as restrições introduzidas em Midnight/12.x) — se algo parar
de funcionar, verifique primeiro essas duas funções.

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
  negativamente servidores ou outros jogadores. Um HUD baseado em nós que você
  mesmo coletou é equivalente ao que GatherMate2/HandyNotes já fazem.

## Próximos passos sugeridos

- Importar nós do banco de dados do GatherMate2 (se instalado) convertendo
  coordenadas de mapa com `C_Map.GetWorldPosFromMapPos`.
- Ícone específico por recurso (mapear nome do nó → item e usar `C_Item.GetItemIconByID`).
- Painel de configurações (`Settings.RegisterCanvasLayoutCategory`).
- Esconder/marcar como "coletado recentemente" nós que você acabou de coletar.
