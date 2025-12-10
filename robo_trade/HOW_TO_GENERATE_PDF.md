# Como Gerar PDF do README

## Método 1: Usando Pandoc (Recomendado)

### Instalação:
```bash
# Windows (com Chocolatey)
choco install pandoc

# Ou baixe em: https://pandoc.org/installing.html
```

### Conversão:
```bash
cd "d:\AI projects\robo_trade"
pandoc README.md -o EA_SMC_Documentation.pdf --pdf-engine=xelatex -V geometry:margin=1in
```

---

## Método 2: Usando Visual Studio Code

1. Instale extensão: **Markdown PDF**
2. Abra `README.md`
3. Pressione `Ctrl+Shift+P`
4. Digite: "Markdown PDF: Export (pdf)"
5. PDF será gerado na mesma pasta

---

## Método 3: Online (Sem Instalação)

1. Acesse: https://www.markdowntopdf.com/
2. Cole o conteúdo do README.md
3. Clique em "Convert"
4. Baixe o PDF

---

## Método 4: GitHub (Se hospedar no GitHub)

1. Faça push do projeto para GitHub
2. Acesse: https://gitprint.com/
3. Cole a URL do seu README
4. Imprima como PDF (Ctrl+P → Save as PDF)

---

## Resultado Esperado

PDF com:
- ✅ Índice completo
- ✅ Formatação de tabelas
- ✅ Syntax highlighting
- ✅ Badges coloridos
- ✅ Estrutura hierárquica preservada

---

**Arquivo gerado:** `EA_SMC_Documentation.pdf`
