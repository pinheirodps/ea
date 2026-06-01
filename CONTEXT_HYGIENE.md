# Context Hygiene

Regras praticas para reduzir custo de tokens neste workspace:

- Use `rg` e leituras por trecho quando procurar contexto.
- Evite anexar logs completos; envie apenas o trecho com erros, entradas e resumo do tester.
- Guarde rascunhos descartaveis em `scratch/`.
- Execute `tools/cleanup_scratch.ps1` para limpar dumps antigos.
- Nao coloque binarios MetaTrader (`.ex5`) nem logs do tester no contexto.

Comandos uteis:

```powershell
.\tools\cleanup_scratch.ps1 -DryRun
.\tools\cleanup_scratch.ps1
```

Para investigacao de EA, prefira:

```powershell
rg -n "Entrada|Stop curto|SL invalido|ORDEM ABERTA|take profit|stop loss" path\to\tester.log
```

Isto mantem a conversa curta e evita reprocessar arquivos grandes a cada iteracao.
