# Fortress X99 — Escudo Adulto & SafeSearch

Infraestrutura automatizada para filtragem de conteúdo adulto e imposição de Busca Segura (SafeSearch) via `/etc/hosts`, implantada com Ansible e mantida por um systemd timer.

---

## Como funciona

A cada execução, o script `fortress-update`:

1. Faz backup do `/etc/hosts` atual
2. Baixa a lista de bloqueio de conteúdo adulto do [StevenBlack/hosts](https://github.com/StevenBlack/hosts)
3. Aplica a lista como novo `/etc/hosts`
4. Injeta entradas que forçam o modo restrito no Google, Bing e DuckDuckGo
5. Limpa o cache DNS

A execução é automática: 5 minutos após o boot e semanalmente.

---

## Pré-requisitos

| Ferramenta | Finalidade |
|---|---|
| `ansible` | Implantação da infraestrutura |
| `curl` | Download da lista de bloqueio |
| `getent` | Resolução DNS dos endpoints de SafeSearch |
| `resolvectl` ou `NetworkManager` | Flush do cache DNS |

**Instalar o Ansible no Arch/CachyOS:**

```bash
sudo pacman -S ansible
```

---

## Instalação

### 1. Clonar o repositório

```bash
git clone <url-do-repositório> fortress-iac
cd fortress-iac
```

### 2. Executar o playbook Ansible

```bash
sudo ansible-playbook playbook.yml
```

O playbook irá:
- Copiar o script para `/usr/local/sbin/fortress-update`
- Instalar as unidades systemd (`fortress-update.service` e `fortress-update.timer`)
- Habilitar e iniciar o timer automático

### 3. Verificar se o timer está ativo

```bash
systemctl status fortress-update.timer
```

Você deve ver `Active: active (waiting)`.

---

## Execução manual

Para rodar o escudo imediatamente, sem esperar o timer:

```bash
sudo fortress-update
```

---

## Verificação

Confirmar que o bloqueio está funcionando:

```bash
# Deve retornar o IP de SafeSearch, não o IP real do Google
getent hosts www.google.com

# Verificar o log da última execução automática
journalctl -u fortress-update.service -n 30
```

---

## Desinstalação

```bash
# Parar e desabilitar o timer
sudo systemctl stop fortress-update.timer
sudo systemctl disable fortress-update.timer

# Remover os arquivos instalados
sudo rm /usr/local/sbin/fortress-update
sudo rm /etc/systemd/system/fortress-update.service
sudo rm /etc/systemd/system/fortress-update.timer
sudo systemctl daemon-reload

# Restaurar o hosts original (se o backup existir)
sudo cp /etc/hosts.x99.bak /etc/hosts
```

---

## Estrutura do repositório

```
fortress-iac/
├── playbook.yml              # Playbook Ansible de implantação
└── files/
    ├── fortress-update        # Script principal de filtragem
    ├── fortress-update.service # Unidade systemd (serviço oneshot)
    └── fortress-update.timer  # Unidade systemd (agendamento)
```
