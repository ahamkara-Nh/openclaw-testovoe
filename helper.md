**Step-by-Step Guide: OpenClaw Setup on Windows with Docker + Telegram Bot**

OpenClaw (also known as ClawdBot/MoltBot) is an open-source personal AI assistant that runs locally in Docker. This guide is tailored for **Windows 10/11** using **Docker Desktop** (which uses WSL2 under the hood). The setup is reliable, secure (sandboxed), and lets you control the AI entirely via your Telegram bot.

### Prerequisites
- **Docker Desktop** installed and running (download from docker.com; enable WSL2 backend during setup if prompted).
- **Git** installed (for Git Bash – download from git-scm.com).
- An LLM API key (e.g., OpenAI, Anthropic/Claude, or any supported provider – OpenClaw will prompt for this).
- At least 4 GB RAM free and ~10 GB disk space.
- Telegram app on your phone/desktop.

**Important**: All commands below are run in **Git Bash** (not regular Command Prompt or PowerShell). Right-click the Git Bash icon → "Run as administrator" if you encounter permission issues.

### Step 1: Clone the OpenClaw Repository
1. Open **Git Bash**.
2. Run these commands one by one:

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
```

### Step 2: Run the Docker Setup (Onboarding + Container Start)
1. In the same Git Bash window, run:

```bash
./docker-setup.sh
```

2. Follow the interactive prompts:
   - Choose **Local gateway (this machine)**.
   - Enter your **LLM provider API key** when asked (e.g., OpenAI or Anthropic).
   - Skip optional services like Tailscale unless you need them.
   - The script will automatically:
     - Pull/build the Docker image.
     - Create persistent volumes (`~/.openclaw` for config + `~/openclaw/workspace` for files).
     - Start the gateway container.

This may take 2–5 minutes the first time.

### Step 3: Access the OpenClaw Dashboard (Web UI)
1. Get the login token:

```bash
docker compose run --rm openclaw-cli dashboard --no-open
```

2. Open your browser and go to:  
   **http://127.0.0.1:18789/**

3. Paste the token from the terminal into the Settings page.

You now have full access to the dashboard for testing agents, files, etc.

### Step 4: Create Your Telegram Bot
1. Open Telegram and search for **@BotFather**.
2. Send `/newbot`.
3. Follow the prompts: give your bot a name and username (e.g., `MyOpenClawBot`).
4. **Copy the bot token** (it looks like `1234567890:ABCDEF...`).

### Step 5: Connect the Telegram Bot to OpenClaw
1. In Git Bash (still in the `openclaw` folder), add the Telegram channel:

```bash
docker compose run --rm openclaw-cli channels add --channel telegram --token "YOUR_BOT_TOKEN_HERE"
```

Replace `YOUR_BOT_TOKEN_HERE` with the token from Step 4.

### Step 6: Pair Your Telegram Account (Critical Step)
1. In Telegram, search for your new bot and start a chat (send `/start` or any message).
2. OpenClaw will automatically send you a private message with a **pairing code** (something like `Approve this pairing with code: 7a8b9c...`).
3. Copy the code and run this command in Git Bash:

```bash
docker compose run --rm openclaw-cli pairing approve telegram YOUR_CODE_HERE
```

Replace `YOUR_CODE_HERE` with the actual code.

✅ **Done!** Your Telegram bot is now fully connected to your local OpenClaw instance.

### Step 7: Test It
- Message your bot in Telegram (e.g., "Hello, summarize my workspace files" or "Run a coding task").
- You should get a response powered by your chosen LLM.
- Use the dashboard to monitor sessions, view logs, or adjust settings.

### Useful Management Commands (Run in Git Bash from the `openclaw` folder)
| Command | What it does |
|---------|--------------|
| `docker compose up -d` | Start/restart OpenClaw |
| `docker compose down` | Stop everything |
| `docker compose logs -f openclaw-gateway` | View live logs |
| `docker compose run --rm openclaw-cli status` | Check status |
| `docker compose run --rm openclaw-cli pairing list telegram` | List pending pairings |
| `docker compose run --rm openclaw-cli doctor` | Run diagnostics/fixes |

### Optional: Install ClawDock Helpers (Easier Commands)
Run these once in Git Bash:

```bash
mkdir -p ~/.clawdock && curl -sL https://raw.githubusercontent.com/openclaw/openclaw/main/scripts/clawdock/clawdock-helpers.sh -o ~/.clawdock/clawdock-helpers.sh
echo 'source ~/.clawdock/clawdock-helpers.sh' >> ~/.bash_profile
source ~/.clawdock/clawdock-helpers.sh
```

Now you can use shortcuts like `clawdock-start`, `clawdock-stop`, `clawdock-dashboard`, etc.

### Troubleshooting Common Windows Issues
- **"Permission denied" or volume errors**: Run Git Bash as Administrator or run `docker compose down` then `docker volume prune`.
- **Pairing not working**: Make sure you messaged the bot first. Run `docker compose run --rm openclaw-cli pairing list telegram` and approve manually.
- **Container won't start**: Check Docker Desktop is running. Restart it if needed.
- **Slow performance**: Increase Docker Desktop resources (Settings → Resources → CPU/Memory).
- **Update OpenClaw**: `git pull` then rerun `./docker-setup.sh`.

Your OpenClaw is now running fully locally in Docker, isolated and secure, with a personal Telegram bot for chatting from anywhere. No cloud VPS required!

For more advanced features (sandbox tools, custom agents, groups), explore the dashboard or the official docs at https://docs.openclaw.ai. 