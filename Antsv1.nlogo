extensions [table]

breed [operarias operaria]
breed [soldados soldado]
breed [rainhas rainha]
breed [arvores arvore]

globals [
  ; Sistema Q-learning
  q-table-operarias
  q-table-soldados
  q-table-rainhas
  actions
  epochs

  ; Hierarquia de colônias
  rainha-principal
  rainha-rival

  ; Ambiente dinâmico
  ambiente-atual
  tempo-restante
  ambiente-anterior

  max-arvores             ; número máximo de árvores
  tempo-producao-frutos   ; ticks entre produções de frutos
  max-frutos-por-arvore   ; máximo de frutos por árvore

  ; Sistema de salvamento
  save-file-operarias
  save-file-soldados
  save-file-rainhas
]

patches-own [
  chemical
  nest?
  nest-scent
  food
  food-source-number
  efeito-ambiente
  gota-ativa?
  frames-gota
  tempo-fruto-caido
]

turtles-own [
  prev-x prev-y
  colony-id
  boost
  role
  health
  energy
  attack
  cor-colonia
  idade-arvore
  state
  reward
]

operarias-own [carregando]
soldados-own [target]
rainhas-own [filhos fertilidade]
arvores-own [
  frutos
  tempo-ate-prox-fruto
]

; ==================== SETUP ====================

to setup
  clear-all

  ; Configura arquivos de salvamento
  set save-file-operarias "qtable_operarias.json"
  set save-file-soldados "qtable_soldados.json"
  set save-file-rainhas "qtable_rainhas.json"

  ; Configuração do ambiente
  set ambiente-atual "normal"
  set tempo-restante 150
  set ambiente-anterior "normal"

  ; Configuração do sistema de frutos
  set tempo-producao-frutos 50
  set max-frutos-por-arvore 5

  ; Inicialização do Q-learning
  set epochs 0
  set actions ["search_food" "combat" "furt" "giveQueen"]
  set q-table-operarias table:make
  set q-table-soldados table:make
  set q-table-rainhas table:make

  ; Tenta carregar tabelas salvas
  carefully [
    load-all-tables
    show "Tabelas Q carregadas com sucesso!"
  ] [
    show "Nenhum dado salvo encontrado. Iniciando com tabelas vazias."
  ]

  setup-world
  setup-ants
  reset-ticks
end

to setup-world
  set max-arvores 30
  criar-arvores-iniciais  ; Geração inicial de árvores

  ask patches [
    set nest? (distancexy (min-pxcor + 2) (min-pycor + 2)) < 5
    set nest-scent 200 - distancexy (min-pxcor + 2) (min-pycor + 2)

    if (distancexy (max-pxcor - 2) (max-pycor - 2)) < 5 [
      set nest? true
      set nest-scent 200 - distancexy (max-pxcor - 2) (max-pycor - 2)
    ]

    set food 0
    set food-source-number 0

    if random-float 1 < 0.03 [
      set food-source-number 1 + random 3
      set food 1 + random 3
    ]

    set chemical 0
    set efeito-ambiente "normal"
    set gota-ativa? false
    set frames-gota 0
    recolor-patch
  ]

  ask patches with [random-float 1 < 0.005] [
    set pcolor yellow
  ]
end

to setup-ants
  ; Colônia 1
  create-rainhas 1 [
    set shape "bug"
    set color white
    set cor-colonia white
    setxy min-pxcor + 2 min-pycor + 2
    set colony-id 1
    set role "rainha"
    set health 250
    set energy 600
    set attack 0
    set state define-state-rainhas
    set filhos 0
    set fertilidade 1
  ]
  set rainha-principal one-of rainhas with [colony-id = 1]

  create-operarias 50 [
    set shape "bug"
    set color red
    set cor-colonia red
    setxy (min-pxcor + 2 + random-float 5) (min-pycor + 2 + random-float 3)
    set colony-id 1
    set role "operaria"
    set health 120
    set energy 270
    set attack 1
    set state define-state-operarias
    set carregando false
  ]

  create-soldados 10 [
    set shape "bug"
    set color blue
    set cor-colonia blue
    setxy (min-pxcor + 2 + random-float 5) (min-pycor + 2 + random-float 2)
    set colony-id 1
    set role "soldado"
    set health 70
    set energy 300
    set attack 5
    set state define-state-soldados
  ]

  ; Colônia 2
  create-rainhas 1 [
    set shape "bug"
    set color orange + 2
    set cor-colonia orange + 2
    setxy max-pxcor - 2 max-pycor - 2
    set colony-id 2
    set role "rainha"
    set health 250
    set energy 600
    set attack 0
    set state define-state-rainhas
    set filhos 0
    set fertilidade 1
  ]
  set rainha-rival one-of rainhas with [colony-id = 2]

  create-operarias 50 [
    set shape "bug"
    set color green + 2
    set cor-colonia green + 2
    setxy (max-pxcor - 1 - random-float 5) (max-pycor - 2 - random-float 3)
    set colony-id 2
    set role "operaria"
    set health 120
    set energy 270
    set attack 1
    set state define-state-operarias
    set carregando false
  ]

  create-soldados 10 [
    set shape "bug"
    set color violet
    set cor-colonia violet
    setxy (max-pxcor - 2 - random-float 5) (max-pycor - 2 - random-float 2)
    set colony-id 2
    set role "soldado"
    set health 70
    set energy 300
    set attack 5
    set state define-state-soldados
    set target nobody
  ]
end

; ==================== MAIN LOOP ====================

to go
  if tempo-restante <= 0 [
    set ambiente-anterior ambiente-atual
    set ambiente-atual one-of ["normal" "chuva"]
    set tempo-restante random 100 + 150

    if ambiente-anterior != "normal" and ambiente-atual = "normal" [
      ask patches with [food-source-number > 0] [
        set food food + one-of [1 2 3]
      ]
    ]
  ]
  set tempo-restante tempo-restante - 1

  ask patches [
    if ambiente-atual = "normal" [ aplicar-normal ]
    if ambiente-atual = "chuva" [ aplicar-chuva ]
    recolor-patch
  ]

  diffuse chemical 0.5

  ask turtles with [role != "arvore" and health > 0] [
    observar
    escolher
    agir
  ]

  grow-trees
  frutos-caidos
  atualizar-frutos-caidos

  ask patches [
    set chemical chemical * 0.95
  ]

  ask patches with [gota-ativa?] [
    set frames-gota frames-gota - 10
    if frames-gota <= 0 [
      set gota-ativa? false
    ]
  ]

  ; Gráficos
  if rainha-principal != nobody [
    set-current-plot "Fertilidade da Rainha"
    plot [fertilidade] of rainha-principal
  ]

  set-current-plot "Total de Operarias"
  plot count operarias

  set-current-plot "Frutos Caídos"
  set-current-plot-pen "total"
  plot count patches with [food-source-number = 4]

  verificar-morte-de-rainha
  verificar-fim-de-jogo
  tick
end

; ==================== TREE SYSTEM ====================

to criar-arvores-iniciais
  create-arvores max-arvores [
    set shape "tree"
    set color scale-color green 8 0 10
    set role "arvore"
    set idade-arvore random 50
    set health 100
    set size 2
    set frutos 0
    set tempo-ate-prox-fruto random tempo-producao-frutos
    setxy random-xcor * 0.9 random-ycor * 0.9
    while [pcolor = green or pcolor = yellow] [
      setxy random-xcor * 0.9 random-ycor * 0.9
    ]
  ]
end

to grow-trees
  ; Fase 1: Envelhecimento e produção de frutos
  ask arvores [
    set idade-arvore idade-arvore + 1

    ; Produz frutos periodicamente
    set tempo-ate-prox-fruto tempo-ate-prox-fruto - 1
    if tempo-ate-prox-fruto <= 0 and frutos < max-frutos-por-arvore [
      set frutos frutos + 1
      set tempo-ate-prox-fruto tempo-producao-frutos
    ]

    ; Árvores morrem quando muito velhas (idade > 100)
    if idade-arvore > 100 [
      die
    ]
  ]

  ; Fase 2: Reposição de árvores
  let arvores-atuais count arvores
  let arvores-faltantes max (list 0 (max-arvores - arvores-atuais))  ; Garante número positivo

  if arvores-faltantes > 0 [
    let candidatos patches with [
      pcolor != green and  ; Não nasce em cima de comida
      pcolor != yellow and ; Nem em obstáculos
      not any? turtles-here with [role != "arvore"]  ; Evita formigas/rainhas
    ]

    if any? candidatos [
      create-arvores min (list arvores-faltantes (count candidatos)) [
        set shape "tree"
        set color scale-color green 8 0 10
        set role "arvore"
        set idade-arvore 0
        set size 2
        set frutos 0
        set tempo-ate-prox-fruto random tempo-producao-frutos
        move-to one-of candidatos  ; Posiciona em um local válido
      ]
    ]
  ]
end

to frutos-caidos
  ask arvores with [frutos > 0] [
    if random-float 1 < 0.05 [  ; 5% de chance de um fruto cair a cada tick
      ask one-of patches in-radius 1 [  ; Cai em um patch adjacente
        set food food + 1
        set food-source-number 4  ; Identificador para frutos caídos
        set tempo-fruto-caido 100  ; Tempo de vida do fruto caído
        set pcolor brown  ; Cor diferente para frutos caídos
      ]
      set frutos frutos - 1
    ]
  ]
end

to atualizar-frutos-caidos
  ask patches with [food > 0 and food-source-number = 4] [
    set tempo-fruto-caido tempo-fruto-caido - 1
    if tempo-fruto-caido <= 0 [
      set food 0
      set food-source-number 0
      set tempo-fruto-caido 0
      recolor-patch
    ]
  ]
end

; ==================== ENVIRONMENT ====================

to aplicar-normal
  set efeito-ambiente "normal"
  set gota-ativa? false
end

to aplicar-chuva
  set efeito-ambiente "úmido"
  if random 100 < 3 and not nest? and food = 0 [
    set gota-ativa? true
    set frames-gota 1 + random 2
  ]
end

to recolor-patch
  if nest? [
    if any? rainhas-here with [colony-id = 1] [ set pcolor violet ]
    if any? rainhas-here with [colony-id = 2] [ set pcolor violet - 2 ]
    stop
  ]

  if food > 0 [
    if food-source-number = 1 [ set pcolor cyan stop ]
    if food-source-number = 2 [ set pcolor sky stop ]
    if food-source-number = 3 [ set pcolor blue stop ]
    if food-source-number = 4 [ set pcolor brown stop ]  ; Frutos caídos
  ]

  if gota-ativa? [ set pcolor blue - 1 stop ]
  if ambiente-atual = "chuva" [ set pcolor green - 1 stop ]

  set pcolor green
end

; ==================== Q-LEARNING ====================

to-report define-state-operarias
  let enemy-turtles other turtles with [colony-id != [colony-id] of myself]
  let enemy-near? false
  let enemy-distance 0
  let carrying? [carregando] of self
  let has-fruits? any? arvores-here with [frutos > 0]

  if any? enemy-turtles [
    let nearest-enemy min-one-of enemy-turtles [distance myself]
    set enemy-near? true
    set enemy-distance distance nearest-enemy
  ]

  report (word xcor "|" ycor "|" carrying? "|" enemy-near? "|" enemy-distance "|" health "|" [chemical] of patch-here "|" has-fruits?)
end

to-report define-state-soldados
  let enemy-turtles other turtles with [colony-id != [colony-id] of myself]
  let enemy-near? false
  let enemy-distance 0

  if any? enemy-turtles [
    let nearest-enemy min-one-of enemy-turtles [distance myself]
    set enemy-near? true
    set enemy-distance distance nearest-enemy
  ]

  report (word xcor "|" ycor "|" enemy-near? "|" enemy-distance "|" health "|" [chemical] of patch-here)
end

to-report define-state-rainhas
  let enemy-turtles other turtles with [colony-id != [colony-id] of myself]
  let enemy-near? false
  let enemy-distance 0

  if any? enemy-turtles [
    let nearest-enemy min-one-of enemy-turtles [distance myself]
    set enemy-near? true
    set enemy-distance distance nearest-enemy
  ]

  report (word xcor "|" ycor "|" enemy-near? "|" enemy-distance "|" health "|" [chemical] of patch-here)
end

to observar
  if health <= 0 [ die stop ]
  if role = "rainha"   [ set state define-state-rainhas ]
  if role = "soldado"  [ set state define-state-soldados ]
  if role = "operaria" [ set state define-state-operarias ]
end

to escolher
  let q-table 0
  if role = "rainha"   [ set q-table q-table-rainhas ]
  if role = "soldado"  [ set q-table q-table-soldados ]
  if role = "operaria" [ set q-table q-table-operarias ]

  let action escolher-action q-table state
  set state list state action
end

to agir
  if health <= 0 [ die stop ]

  let q-table 0
  if role = "rainha"   [ set q-table q-table-rainhas ]
  if role = "soldado"  [ set q-table q-table-soldados ]
  if role = "operaria" [ set q-table q-table-operarias ]

  let action last state
  let old-state item 0 state
  let resul execute self action
  let state_future item 0 resul
  let reward_ants item 1 resul

  update-Q old-state action reward_ants state_future
end

to-report escolher-action [ q-table state_agents ]
  let epsilon 0.3
  ifelse random-float 1 < epsilon [ report one-of actions ]
  [ report best-action q-table state_agents]
end

to-report best-action [ q-table state_agents ]
  let values []
  foreach actions [ a ->
    ifelse table:has-key? q-table (list state_agents a) [
      set values lput (table:get q-table (list state_agents a)) values
    ] [
      set values lput 0 values
    ]
  ]
  let best-index position max values values
  report item best-index actions
end

to-report q-value [ q-table state_agents action ]
  if table:has-key? q-table (list state_agents action) [
    report table:get q-table (list state_agents action)
  ]
  report random-float 0.1
end

to-report execute [ ants_agent action ]
  if [health] of ants_agent <= 0 [
    report (list [state] of ants_agent -9999)
  ]

  if action = "search_food" [
    move ants_agent
    if [role] of ants_agent = "operaria" and not [carregando] of ants_agent [
      ; Pode coletar comida do chão ou frutos das árvores
      if [food] of patch-here > 0 [
        ask patch-here [ set food food - 1 ]
        set carregando true
        set reward reward + 50
      ]
      if any? arvores-here with [frutos > 0] [
        ask one-of arvores-here with [frutos > 0] [
          set frutos frutos - 1
        ]
        set carregando true
        set reward reward + 70  ; Recompensa maior por coletar frutos
      ]
      ask patch-here [ set chemical chemical + 60 ]
    ]
  ]

  if action = "combat" [
    combat ants_agent
  ]

  if action = "furt" [
    furt ants_agent
  ]

  if action = "giveQueen" [
    return_for_rainha ants_agent
    if [role] of ants_agent = "operaria" and [carregando] of ants_agent [
      ask patch-here [ set chemical chemical + 80 ]
    ]
  ]

  let new_state 0
  if [role] of ants_agent = "operaria" [
    set new_state [define-state-operarias] of ants_agent
  ]
  if [role] of ants_agent = "soldado" [
    set new_state [define-state-soldados] of ants_agent
  ]
  if [role] of ants_agent = "rainha" [
    set new_state [define-state-rainhas] of ants_agent
  ]

  let earned_reward [reward] of ants_agent
  report (list new_state earned_reward)
end

to update-Q [ state-agents action reward-ants state-future ]
  if role = "rainha" [
    queen_atualizar-Q state-agents action reward-ants state-future
  ]
  if role = "soldado" [
    soldier_atualizar-Q state-agents action reward-ants state-future
  ]
  if role = "operaria" [
    operarias_atualizar-Q state-agents action reward-ants state-future
  ]
end

to queen_atualizar-Q [state-agents action reward-ants state-future]
  let alpha 0.5
  let gamma 0.9

  let q-last q-value q-table-rainhas state-agents action
  let best-future max map [ a -> q-value q-table-rainhas state-future a ] actions
  let q-new q-last + alpha * ( reward-ants + gamma * best-future - q-last )

  table:put q-table-rainhas (list state-agents action) q-new
end

to soldier_atualizar-Q [state-agents action reward-ants state-future]
  let alpha 0.5
  let gamma 0.9

  let q-last q-value q-table-soldados state-agents action
  let best-future max map [ a -> q-value q-table-soldados state-future a ] actions
  let q-new q-last + alpha * ( reward-ants + gamma * best-future - q-last )

  table:put q-table-soldados (list state-agents action) q-new
end

to operarias_atualizar-Q [state-agents action reward-ants state-future]
  let alpha 0.5
  let gamma 0.9

  let q-last q-value q-table-operarias state-agents action
  let best-future max map [ a -> q-value q-table-operarias state-future a ] actions
  let q-new q-last + alpha * ( reward-ants + gamma * best-future - q-last )

  table:put q-table-operarias (list state-agents action) q-new
end

; ==================== ANT BEHAVIORS ====================

to move [ants_agents]
  if [health] of ants_agents <= 0 [ stop ]

  ask ants_agents [
    set prev-x xcor
    set prev-y ycor

    let velocidade 1.0
    if [efeito-ambiente] of patch-here = "úmido" [ set velocidade 0.4 ]

    if role = "operaria" and not carregando and [chemical] of patch-here > 0.1 [
      uphill-chemical
    ]

    if role = "soldado" [
      let minha-rainha one-of rainhas with [colony-id = [colony-id] of myself]
      if minha-rainha != nobody and distance minha-rainha > 10 [
        uphill-nest-scent
      ]
    ]

    rt random 40
    lt random 40
    if not can-move? velocidade [ rt 180 ]
    fd velocidade

    check-bounds self
  ]
end

to combat [ants_agent]
  if [health] of ants_agent <= 0 [ stop ]

  let inimigos other turtles with [colony-id != [colony-id] of ants_agent and health > 0]

  ifelse any? inimigos [
    let alvo min-one-of inimigos [distance ants_agent]
    face alvo
    fd 1

    ifelse distance alvo < 1 [
      ask alvo [
        set health health - [attack] of ants_agent
        if health <= 0 [
          die
          ask ants_agent [ set reward reward + 20 ]
        ]
      ]

      ifelse [role] of ants_agent = "soldado" [
        if (alvo != nobody and member? alvo turtles and [role] of alvo = "rainha") [
          set reward reward + 100
        ]
      ] [
        set reward reward - 1
      ]
    ] [
      set reward 0
    ]
  ] [
    set reward reward - 10
  ]
end

to furt [ants_agent]
  let inimigos other turtles with [colony-id != [colony-id] of ants_agent and health > 0]
  ifelse any? inimigos [
    let inimigo-proximo min-one-of inimigos [distance ants_agent]
    ask ants_agent [
      set boost 2
      set reward reward + 4
      face inimigo-proximo
      rt 180
      fd 1 + boost
    ]
  ] [
    set reward reward - 10
  ]
end

to return_for_rainha [ ants_agent ]
  let meu-role [role] of ants_agent
  let minha-rainha one-of rainhas with [colony-id = [colony-id] of ants_agent]

  ifelse meu-role = "rainha" [
    ask ants_agent [
      set reward reward - 100
    ]
  ]
  [
    ifelse meu-role = "soldado" [
      ask ants_agent [
        if minha-rainha != nobody [
          face minha-rainha
          fd 1
          if distance minha-rainha < 3 [
            set reward reward + 5
          ]
        ]
      ]
    ]
    [ ; operária
      ask ants_agent [
        ifelse carregando [
          if minha-rainha != nobody [
            face minha-rainha
            fd 1
            ifelse distance minha-rainha < 2 [
              set carregando false
              set reward reward + 100
              ask minha-rainha [
                set fertilidade fertilidade + 1
              ]
            ] [
              set reward reward + 0.2
            ]
          ]
        ] [
          set reward reward - 1000
        ]
      ]
    ]
  ]
end

to check-bounds [ant]
  ask ant [
    if xcor > max-pxcor or xcor < min-pxcor or
       ycor > max-pycor or ycor < min-pycor [
      set xcor prev-x
      set ycor prev-y
      set reward reward - 100
    ]
  ]
end

; ==================== NAVIGATION ====================

to uphill-nest-scent
  let scent-ahead nest-scent-at-angle 0
  let scent-right nest-scent-at-angle 45
  let scent-left nest-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead) [
    ifelse scent-right > scent-left [ rt 45 ] [ lt 45 ]
  ]
end

to uphill-chemical
  let scent-ahead chemical-scent-at-angle 0
  let scent-right chemical-scent-at-angle 45
  let scent-left chemical-scent-at-angle -45
  if (scent-right > scent-ahead) or (scent-left > scent-ahead) [
    ifelse scent-right > scent-left [ rt 45 ] [ lt 45 ]
  ]
end

to-report nest-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [nest-scent] of p
end

to-report chemical-scent-at-angle [angle]
  let p patch-right-and-ahead angle 1
  if p = nobody [ report 0 ]
  report [chemical] of p
end

; ==================== GAME STATE ====================

to verificar-morte-de-rainha
  if rainha-principal != nobody and not member? rainha-principal turtles [
    ask turtles with [colony-id = 1] [ set reward reward - 1500 ]
    ask turtles with [colony-id = 2] [ set reward reward + 1500 ]
    set rainha-principal nobody
  ]

  if rainha-rival != nobody and not member? rainha-rival turtles [
    ask turtles with [colony-id = 2] [ set reward reward - 1500 ]
    ask turtles with [colony-id = 1] [ set reward reward + 1500 ]
    set rainha-rival nobody
  ]
end

to verificar-fim-de-jogo
  let col1-vivas any? turtles with [colony-id = 1 and health > 0]
  let col2-vivas any? turtles with [colony-id = 2 and health > 0]

  if not col1-vivas or not col2-vivas [
    setup
    set epochs epochs + 1
    stop
  ]
end

; ==================== SAVE/LOAD SYSTEM ====================

to load-all-tables
  ; Implementação de carregamento seria adicionada aqui
end
@#$#@#$#@
GRAPHICS-WINDOW
257
10
762
516
-1
-1
7.0
1
10
1
1
1
0
0
0
1
-35
35
-35
35
1
1
1
ticks
30.0

BUTTON
38
11
121
44
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
126
10
201
43
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
0

PLOT
28
45
188
165
Food in each pile
time
food
0.0
50.0
0.0
120.0
true
false
"" ""
PENS
"food-in-pile1" 1.0 0 -11221820 true "" "plotxy ticks sum [food] of patches with [pcolor = cyan]"
"food-in-pile2" 1.0 0 -13791810 true "" "plotxy ticks sum [food] of patches with [pcolor = sky]"
"food-in-pile3" 1.0 0 -13345367 true "" "plotxy ticks sum [food] of patches with [pcolor = blue]"

PLOT
24
169
184
289
Fertilidade da Rainha
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot [fertilidade] of rainha-principal"

PLOT
22
291
182
411
Total de Operarias
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"default" 1.0 0 -16777216 true "" "plot count operarias"

PLOT
17
413
181
533
Frutos Caídos
NIL
NIL
0.0
10.0
0.0
10.0
true
false
"" ""
PENS
"total" 1.0 0 -16777216 true "" ""

@#$#@#$#@
## WHAT IS IT?

In this project, a colony of ants forages for food. Though each ant follows a set of simple rules, the colony as a whole acts in a sophisticated way.

## HOW IT WORKS

When an ant finds a piece of food, it carries the food back to the nest, dropping a chemical as it moves. When other ants "sniff" the chemical, they follow the chemical toward the food. As more ants carry food to the nest, they reinforce the chemical trail.

## HOW TO USE IT

Click the SETUP button to set up the ant nest (in violet, at center) and three piles of food. Click the GO button to start the simulation. The chemical is shown in a green-to-white gradient.

The EVAPORATION-RATE slider controls the evaporation rate of the chemical. The DIFFUSION-RATE slider controls the diffusion rate of the chemical.

If you want to change the number of ants, move the POPULATION slider before pressing SETUP.

## THINGS TO NOTICE

The ant colony generally exploits the food source in order, starting with the food closest to the nest, and finishing with the food most distant from the nest. It is more difficult for the ants to form a stable trail to the more distant food, since the chemical trail has more time to evaporate and diffuse before being reinforced.

Once the colony finishes collecting the closest food, the chemical trail to that food naturally disappears, freeing up ants to help collect the other food sources. The more distant food sources require a larger "critical number" of ants to form a stable trail.

The consumption of the food is shown in a plot.  The line colors in the plot match the colors of the food piles.

## EXTENDING THE MODEL

Try different placements for the food sources. What happens if two food sources are equidistant from the nest? When that happens in the real world, ant colonies typically exploit one source then the other (not at the same time).

In this project, the ants use a "trick" to find their way back to the nest: they follow the "nest scent." Real ants use a variety of different approaches to find their way back to the nest. Try to implement some alternative strategies.

The ants only respond to chemical levels between 0.05 and 2.  The lower limit is used so the ants aren't infinitely sensitive.  Try removing the upper limit.  What happens?  Why?

In the `uphill-chemical` procedure, the ant "follows the gradient" of the chemical. That is, it "sniffs" in three directions, then turns in the direction where the chemical is strongest. You might want to try variants of the `uphill-chemical` procedure, changing the number and placement of "ant sniffs."

## NETLOGO FEATURES

The built-in `diffuse` primitive lets us diffuse the chemical easily without complicated code.

The primitive `patch-right-and-ahead` is used to make the ants smell in different directions without actually turning.

## HOW TO CITE

If you mention this model or the NetLogo software in a publication, we ask that you include the citations below.

For the model itself:

* Wilensky, U. (1997).  NetLogo Ants model.  http://ccl.northwestern.edu/netlogo/models/Ants.  Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

Please cite the NetLogo software as:

* Wilensky, U. (1999). NetLogo. http://ccl.northwestern.edu/netlogo/. Center for Connected Learning and Computer-Based Modeling, Northwestern University, Evanston, IL.

## COPYRIGHT AND LICENSE

Copyright 1997 Uri Wilensky.

![CC BY-NC-SA 3.0](http://ccl.northwestern.edu/images/creativecommons/byncsa.png)

This work is licensed under the Creative Commons Attribution-NonCommercial-ShareAlike 3.0 License.  To view a copy of this license, visit https://creativecommons.org/licenses/by-nc-sa/3.0/ or send a letter to Creative Commons, 559 Nathan Abbott Way, Stanford, California 94305, USA.

Commercial licenses are also available. To inquire about commercial licenses, please contact Uri Wilensky at uri@northwestern.edu.

This model was created as part of the project: CONNECTED MATHEMATICS: MAKING SENSE OF COMPLEX PHENOMENA THROUGH BUILDING OBJECT-BASED PARALLEL MODELS (OBPML).  The project gratefully acknowledges the support of the National Science Foundation (Applications of Advanced Technologies Program) -- grant numbers RED #9552950 and REC #9632612.

This model was developed at the MIT Media Lab using CM StarLogo.  See Resnick, M. (1994) "Turtles, Termites and Traffic Jams: Explorations in Massively Parallel Microworlds."  Cambridge, MA: MIT Press.  Adapted to StarLogoT, 1997, as part of the Connected Mathematics Project.

This model was converted to NetLogo as part of the projects: PARTICIPATORY SIMULATIONS: NETWORK-BASED DESIGN FOR SYSTEMS LEARNING IN CLASSROOMS and/or INTEGRATED SIMULATION AND MODELING ENVIRONMENT. The project gratefully acknowledges the support of the National Science Foundation (REPP & ROLE programs) -- grant numbers REC #9814682 and REC-0126227. Converted from StarLogoT to NetLogo, 1998.

<!-- 1997 1998 MIT -->
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
