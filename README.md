# Fortress IaC

O Fortress IaC é uma solução de automação de infraestrutura projetada para aplicar filtragem de conteúdo adulto e imposição de Busca Segura (SafeSearch) nos principais motores de busca (Google, Bing, DuckDuckGo). A ferramenta opera gerenciando dinamicamente o arquivo `hosts` do sistema operacional e possui suporte para ambientes Linux e Windows.

## Arquitetura

O script de automação é executado durante a inicialização do sistema e de forma programada semanalmente. O fluxo de execução consiste em:

1. Identificar e preservar configurações locais de rede por meio de um arquivo auxiliar (`hosts.local`).
2. Realizar o download da lista pública de bloqueio de conteúdo adulto do repositório [StevenBlack/hosts](https://github.com/StevenBlack/hosts).
3. Resolver e injetar os endpoints de DNS para forçar o modo estrito de SafeSearch.
4. Aplicar as alterações de forma atômica para prevenir a corrupção do roteamento local.
5. Executar a limpeza do cache de DNS do sistema.

## Estrutura do Repositório

```text
fortress-iac/
├── README.md
├── linux/
│   ├── playbook.yml             # Playbook de implantação Ansible
│   └── files/                   # Script principal e unidades do Systemd
└── windows/
    ├── install.ps1              # Script de implantação (Task Scheduler)
    └── fortress-update.ps1      # Script principal em PowerShell
```

## Obtenção do Repositório

Para iniciar a instalação em qualquer ambiente, é necessário obter os arquivos do projeto para a sua máquina local.

**Via Git (Recomendado):**
```bash
git clone https://github.com/FelipeArtur/fortress-iac.git
cd fortress-iac
```

**Via Arquivo Compactado (ZIP):**
Caso não possua o Git instalado (cenário comum em servidores ou estações Windows), você pode obter os arquivos sem depender de linha de comando:
1. Acesse a página do repositório no navegador.
2. Clique no botão **Code** e selecione **Download ZIP**.
3. Extraia o arquivo e abra o Terminal ou PowerShell dentro da pasta `fortress-iac`.

## Implantação no Linux

### Pré-requisitos
*   `ansible` (Para implantação)
*   `curl`
*   `getent`

### Instalação

1. Navegue até o diretório Linux:
   ```bash
   cd linux
   ```
2. Execute o playbook do Ansible com privilégios de superusuário:
   ```bash
   sudo ansible-playbook playbook.yml
   ```
3. Verifique o status de agendamento do serviço:
   ```bash
   systemctl status fortress-update.timer
   ```

## Implantação no Windows

### Pré-requisitos
*   PowerShell 5.1 ou superior
*   Privilégios de Administrador

### Instalação

1. Abra o PowerShell como Administrador.
2. Navegue até o diretório Windows:
   ```powershell
   cd windows
   ```
3. Execute o script de instalação:
   ```powershell
   .\install.ps1
   ```
   *Nota: Caso as políticas do sistema bloqueiem a execução, utilize o comando `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` previamente.*

O instalador configurará uma Tarefa Agendada operando sob a conta de sistema (`SYSTEM`), programada para ser executada na inicialização da máquina e semanalmente.

## Gestão de Entradas Locais Customizadas

Para preservar configurações de rede locais que não devem ser sobrescritas (como IPs de servidores de desenvolvimento local ou atalhos internos), as rotas devem ser declaradas no arquivo correspondente abaixo. O sistema incluirá automaticamente este conteúdo no início do arquivo `hosts` principal em todas as execuções.

*   **Linux:** `/etc/hosts.local`
*   **Windows:** `C:\Windows\System32\drivers\etc\hosts.local`
