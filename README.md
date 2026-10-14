# Correção de impressoras compartilhadas — 0x00000709 e 0x0000011B

## Português

### Por que este arquivo existe

Este utilitário nasceu de uma dor recorrente: para tentar corrigir erros ao conectar a impressoras compartilhadas, era necessário executar várias soluções separadas, sem saber qual delas resolveria o caso. O arquivo `.bat` reúne verificações e ajustes comuns em uma única execução, com a intenção de tratar causas frequentes dos erros `0x00000709` e `0x0000011B`. Ele pode ajudar em muitos cenários, mas não garante resolver todos os problemas de impressão em rede.

### O que o arquivo altera

Ao ser executado como Administrador, `Corrigir-Impressoras-Compartilhadas.bat`:

- Cria uma pasta de backup e log em `Documentos\ImpressoraFix-Backup-<data>` e exporta as chaves de Registro existentes antes das alterações.
- Habilita o serviço opcional de impressão LPD e procura/habilita o monitor de porta LPR quando disponível.
- Configura valores DWORD na chave `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC`:
  - `RpcUseNamedPipeProtocol = 1`
  - `RpcOverNamedPipes = 1`
  - `RpcOverTcp = 0`
- Aplica um override legado do Feature Management apenas nas builds do Windows 10 cobertas pelos arquivos de origem: build `17763`, `18363` e `19041` a `19044`. Em outras builds, como Windows 11 build `26200`, registra o item como ignorado.
- Define `HKLM\SYSTEM\CurrentControlSet\Control\Print\RpcAuthnLevelPrivacyEnabled = 0` automaticamente.
- Reinicia o serviço Spooler de Impressão.
- Mostra um resumo por etapa com `OK`, `Ignorado` ou `ERRO`, incluindo um motivo abreviado.

### Aviso de segurança

Definir `RpcAuthnLevelPrivacyEnabled = 0` reduz a proteção de privacidade/autenticação RPC do Spooler. Além disso, a Microsoft informa que RPC por named pipes não é a configuração recomendada para Windows 11 22H2 ou posterior; ela pode ser usada quando RPC sobre TCP não for uma opção no ambiente. Revise se esses ajustes são adequados para a sua rede antes de executar, especialmente em computadores que não sejam o host que compartilha a impressora.

O utilitário não altera regras do Firewall, descoberta de rede, compartilhamentos, credenciais, drivers, políticas Point and Print, filas de impressão ou permissões de usuário. Esses itens podem exigir diagnóstico específico do PC host, do cliente e do modelo da impressora.

### Como usar

1. Leia este README e revise o código do `.bat` antes de executar.
2. Faça o download de `Corrigir-Impressoras-Compartilhadas.bat`.
3. Clique com o botão direito e escolha **Executar como administrador**.
4. Confira o resumo final e consulte o log/backup na pasta indicada.
5. Se houver falhas, use o motivo mostrado e o log para investigar antes de repetir alterações.

O script é destinado a Windows 10/11 cliente com build `17763` ou superior. Não se destina ao Windows Server. Recursos opcionais habilitados podem exigir reinicialização.

### Isenção de responsabilidade

Este arquivo é fornecido “como está”, sem garantia de funcionamento ou adequação a um ambiente específico. O uso é por conta e risco de quem executa. O autor não se responsabiliza por danos, indisponibilidade, perda de dados, alterações de segurança ou quaisquer consequências decorrentes do uso. Revise o código, mantenha backups e valide em um ambiente controlado antes de usar em computadores de produção.

### Referências

- [Corrigir problemas de conexão com impressoras compartilhadas no Windows — Microsoft Support](https://support.microsoft.com/en-us/windows/hardware/printer/fix-shared-printer-connection-problems-in-windows)
- [Atualizações de conexão RPC para impressão no Windows 11 — Microsoft Learn](https://learn.microsoft.com/en-us/troubleshoot/windows-client/printing/windows-11-rpc-connection-updates-for-print)

---

## English

### Why this file exists

This utility came from a recurring pain point: fixing shared-printer connection errors meant running several separate workarounds without knowing which one would solve the issue. The `.bat` file brings common checks and settings into one run, aiming to address frequent causes of errors `0x00000709` and `0x0000011B`. It may help in many cases, but it cannot guarantee a fix for every network-printing problem.

### What the file changes

When run as Administrator, `Corrigir-Impressoras-Compartilhadas.bat`:

- Creates a backup and log folder under `Documents\ImpressoraFix-Backup-<date>` and exports existing Registry keys before changing them.
- Enables the optional LPD printing service and searches for/enables the LPR port monitor when available.
- Sets DWORD values under `HKLM\SOFTWARE\Policies\Microsoft\Windows NT\Printers\RPC`:
  - `RpcUseNamedPipeProtocol = 1`
  - `RpcOverNamedPipes = 1`
  - `RpcOverTcp = 0`
- Applies a legacy Feature Management override only to Windows 10 builds covered by the source files: build `17763`, `18363`, and `19041` through `19044`. Other builds, such as Windows 11 build `26200`, report this step as skipped.
- Sets `HKLM\SYSTEM\CurrentControlSet\Control\Print\RpcAuthnLevelPrivacyEnabled = 0` automatically.
- Restarts the Print Spooler service.
- Displays a per-step `OK`, `Skipped`, or `Error` summary with a short reason.

### Security notice

Setting `RpcAuthnLevelPrivacyEnabled = 0` lowers the Print Spooler's RPC privacy/authentication protection. Microsoft also states that RPC over named pipes is not the recommended configuration for Windows 11 version 22H2 or later; it can be used when RPC over TCP is not an option in the environment. Review whether these settings fit your network before running the utility, especially on computers that are not the printer-sharing host.

The utility does not change Firewall rules, network discovery, shares, credentials, drivers, Point and Print policies, print queues, or user permissions. Those may require separate diagnosis of the host PC, client PC, and printer model.

### Usage

1. Read this README and review the `.bat` source before running it.
2. Download `Corrigir-Impressoras-Compartilhadas.bat`.
3. Right-click it and select **Run as administrator**.
4. Review the final summary and inspect the backup/log folder shown by the script.
5. If a step fails, use its short reason and the log to investigate before repeating changes.

The script targets Windows 10/11 client editions with build `17763` or later. Windows Server is not supported. Enabling optional features may require a restart.

### Disclaimer

This file is provided “as is”, without any warranty of operation or fitness for a particular environment. Use it at your own risk. The author accepts no responsibility for damage, downtime, data loss, security changes, or any other consequences resulting from its use. Review the source code, keep backups, and validate it in a controlled environment before using it on production computers.

### References

- [Fix shared printer connection problems in Windows — Microsoft Support](https://support.microsoft.com/en-us/windows/hardware/printer/fix-shared-printer-connection-problems-in-windows)
- [RPC connection updates for print in Windows 11 — Microsoft Learn](https://learn.microsoft.com/en-us/troubleshoot/windows-client/printing/windows-11-rpc-connection-updates-for-print)

