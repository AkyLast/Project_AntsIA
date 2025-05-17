```markdown
# README - Projeto de IA: Simulação de Colônia de Formigas

**Objetivo do Projeto**:  
Criar uma simulação de colônias de formigas com comportamentos adaptativos (Q-learning), combates estratégicos e dinâmica ambiental.  

---

## 📂 Estrutura do Projeto

### 1. Ambiente Dinâmico e Geração Aleatória *(Kellyson)*  
- **O que implementar**:  
  - Células (`patches`) com atributos: comida, árvores, ninhos.  
  - Geração aleatória de árvores/comida no `setup`.  
  - Regeneração de recursos (ex: árvores morrendo/renascendo, comida reaparecendo após X *ticks*).  

### 2. Definição de Colônias e Papéis *(Hugo)*  
- **O que implementar**:  
  - Classes de formigas (`breeds`) com atributos: `colony-id`, `role` (operária, soldado, rainha).  
  - Atributos individuais: `health`, `energy`, `attack`, `state`.  
  - Mecânicas de combate (detecção de inimigos, cálculo de dano, fuga).  

### 3. Estado do Ambiente *(Paulo)*  
- **O que implementar**:  
  - Dinâmica ambiental: mudanças de clima, variação na produção de comida.  
  - Atualização periódica do ambiente (ex: comida some após colheita, árvores regeneram comida).  

### 4. Aprendizado por Reforço *(Luis)*  
- **O que implementar**:  
  - Tabela Q individual para formigas (estados: distância da comida, energia; ações: mover, atacar, fugir).  
  - Política ε-greedy para decisões.  
  - Compartilhamento coletivo de Q-tables entre a colônia.  

---

## 👥 Responsabilidades da Equipe

| Membro    | Tarefas                                                       | Branch         |
|-----------|---------------------------------------------------------------|----------------|
| Kellyson  | Estrutura do ambiente (árvores, ninhos, regeneração)          | `feature/env`  |
| Hugo      | Classes de formigas, combate, atributos                       | `feature/combat` |
| Paulo     | Dinâmica ambiental, ciclos de comida/clima                    | `feature/climate` |
| Luis      | Q-learning individual/coletivo, vetores de sucesso            | `feature/qlearn` |

---

## 🔄 Fluxo de Trabalho no Git

### Passos para Todos:  
1. **Criar seu Branch**:  
   ```bash  
   git checkout -b feature/nome-da-sua-feature  
   ```  
   Ex: `git checkout -b feature/env` (Kellyson).  


2. Envie seu Branch para o GitHub:
   
   ```bash
   git push origin nome-do-seu-branch 
   ```
   Primeira vez? Use: 
   ```bash
   git push -u origin nome-do-branch
   ```

3. **Commits**:  
   - Use mensagens claras:  
     ```bash  
     git add .                         		# Adiciona TODOS os arquivos modificados
     git commit -m "[TAG] Mensagem"			# Ex.:  "[ENV] Adicionada geração aleatória de árvores"  
     ```  
   - Prefixos sugeridos: `[ENV]`, `[COMBAT]`, `[CLIMATE]`, `[QLEARN]`.  

4. **Acesso ao Branch**:  
   - Trabalhe sempre no seu branch. Para atualizá-lo com a `main`:  
   ```bash  
   git pull origin main  
   ```  

### Mesclagem Periódica:  
-  Farei merge dos branches na `main` a cada etapa concluída.  
- **Sincronizem seus branches com a `main` antes de começar novas tarefas!**  
	```bash
	git checkout seu-branche Ex.: git checkout feature/qlearn
	git rebase origin/main
	```
---

**Equipe**: Kellyson, Hugo, Paulo, Luis  
**Prazo**: [22/05]  
``` 

### 📌 Dicas Extras:  
- **Comuniquem-se** no grupo se houver conflitos no código.  
- **Testem** suas partes individualmente antes de mesclar.  
- **Documentem** funções complexas com comentários no código.
- **Dúvidas** podem perguntar no grupo, talvez alguém saiba a resposta ou aprederam juntos
