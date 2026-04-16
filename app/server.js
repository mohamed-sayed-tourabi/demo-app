const express = require("express");
const os = require("node:os");

const app = express();
const PORT = process.env.PORT || 3000;
const START_TIME = new Date();

// ──────────────────────────────────────────────
// API Endpoints
// ──────────────────────────────────────────────

// Health check
app.get("/api/health", (req, res) => {
  console.log("Health check called - status: healthy");
  res.json({ status: "healthy", uptime: process.uptime() });
});

// App info — shows container/environment details
app.get("/api/info", (req, res) => {
  console.log("Info requested - hostname: " + os.hostname());
  res.json({
    app: "From Code to Cloud Demo",
    version: "1.0.0",
    hostname: os.hostname(),
    platform: os.platform(),
    arch: os.arch(),
    nodeVersion: process.version,
    environment: process.env.NODE_ENV || "development",
    region: process.env.AZURE_REGION || "local",
    startedAt: START_TIME.toISOString(),
    uptime: `${Math.floor(process.uptime())}s`,
    memoryUsage: `${Math.round(process.memoryUsage().rss / 1024 / 1024)}MB`,
  });
});

// Simple visitor counter (in-memory, resets on restart)
let visitorCount = 0;
app.get("/api/visit", (req, res) => {
  visitorCount++;
  console.log("🎉 New visitor! Visitor count is now: " + visitorCount);
  res.json({ visitors: visitorCount });
});

// ──────────────────────────────────────────────
// Embedded UI
// ──────────────────────────────────────────────
app.get("/", (req, res) => {
  res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>From Code to Cloud</title>
  <style>
    * { margin: 0; padding: 0; box-sizing: border-box; }
    body {
      font-family: 'Segoe UI', system-ui, -apple-system, sans-serif;
      background: #1E194B;
      color: #fff;
      min-height: 100vh;
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      padding: 2rem;
    }
    .container {
      max-width: 700px;
      text-align: center;
    }
    .badge {
      display: inline-block;
      background: linear-gradient(135deg, #E6007E, #005FFF);
      padding: 0.4rem 1.2rem;
      border-radius: 20px;
      font-size: 0.85rem;
      font-weight: 600;
      letter-spacing: 1px;
      text-transform: uppercase;
      margin-bottom: 1.5rem;
    }
    h1 {
      font-size: 2.8rem;
      font-weight: 700;
      margin-bottom: 0.5rem;
      background: linear-gradient(135deg, #fff 0%, #008CFF 100%);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .subtitle {
      font-size: 1.1rem;
      color: #B8B5D4;
      margin-bottom: 2rem;
    }
    .rocket { font-size: 3rem; margin-bottom: 1rem; }
    .info-grid {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 1rem;
      margin: 2rem 0;
      text-align: left;
    }
    .info-card {
      background: #2D2868;
      border-radius: 12px;
      padding: 1.2rem;
      border-left: 4px solid #E6007E;
      transition: transform 0.2s;
    }
    .info-card:hover { transform: translateY(-2px); }
    .info-card:nth-child(even) { border-left-color: #005FFF; }
    .info-card .label {
      font-size: 0.75rem;
      color: #B8B5D4;
      text-transform: uppercase;
      letter-spacing: 1px;
      margin-bottom: 0.3rem;
    }
    .info-card .value {
      font-size: 1.1rem;
      font-weight: 600;
      color: #fff;
      word-break: break-all;
    }
    .visitor-section {
      margin: 2rem 0;
      padding: 1.5rem;
      background: #2D2868;
      border-radius: 12px;
      text-align: center;
    }
    .visitor-count {
      font-size: 3rem;
      font-weight: 700;
      background: linear-gradient(135deg, #E6007E, #008CFF);
      -webkit-background-clip: text;
      -webkit-text-fill-color: transparent;
      background-clip: text;
    }
    .visitor-label { color: #B8B5D4; font-size: 0.9rem; }
    .clock {
      font-size: 1.4rem;
      color: #008CFF;
      font-weight: 600;
      margin: 1rem 0;
      font-variant-numeric: tabular-nums;
    }
    .api-links {
      margin-top: 2rem;
      display: flex;
      gap: 1rem;
      justify-content: center;
      flex-wrap: wrap;
    }
    .api-link {
      display: inline-block;
      background: rgba(0, 95, 255, 0.15);
      color: #008CFF;
      padding: 0.5rem 1rem;
      border-radius: 8px;
      text-decoration: none;
      font-size: 0.85rem;
      font-family: 'Consolas', monospace;
      border: 1px solid rgba(0, 95, 255, 0.3);
      transition: all 0.2s;
    }
    .api-link:hover {
      background: rgba(0, 95, 255, 0.25);
      border-color: #008CFF;
    }
    .footer {
      margin-top: 2rem;
      font-size: 0.8rem;
      color: #4B4B91;
    }
    .footer a { color: #E6007E; text-decoration: none; }
  </style>
</head>
<body>
  <div class="container">
    <div class="rocket">🚀</div>
    <div class="badge">Live on Azure Container Apps</div>
    <h1>From Code to Cloud</h1>
    <p class="subtitle">Your First Azure Deployment — Global Azure Tunisia 2026</p>

    <div class="clock" id="clock"></div>

    <div class="visitor-section">
      <div class="visitor-count" id="visitors">-</div>
      <div class="visitor-label">page visits since deploy</div>
    </div>

    <div class="info-grid" id="info-grid">
      <div class="info-card">
        <div class="label">Loading...</div>
        <div class="value">Fetching container info...</div>
      </div>
    </div>

    <div class="api-links">
      <a class="api-link" href="/api/health">GET /api/health</a>
      <a class="api-link" href="/api/info">GET /api/info</a>
      <a class="api-link" href="/api/visit">GET /api/visit</a>
    </div>

    <div class="footer">
      Built by <a href="#">Mohmed Sayed Tourabi</a> · MaibornWolff GmbH
    </div>
  </div>

  <script>
    // Live clock
    function updateClock() {
      document.getElementById('clock').textContent = new Date().toLocaleTimeString('en-US', {
        hour12: false, hour: '2-digit', minute: '2-digit', second: '2-digit',
        timeZoneName: 'short'
      });
    }
    updateClock();
    setInterval(updateClock, 1000);

    // Fetch visitor count
    fetch('/api/visit')
      .then(r => r.json())
      .then(data => {
        document.getElementById('visitors').textContent = data.visitors;
      });

    // Fetch container info
    fetch('/api/info')
      .then(r => r.json())
      .then(data => {
        const grid = document.getElementById('info-grid');
        const items = [
          { label: 'Hostname', value: data.hostname },
          { label: 'Platform', value: data.platform + ' / ' + data.arch },
          { label: 'Node Version', value: data.nodeVersion },
          { label: 'Environment', value: data.environment },
          { label: 'Region', value: data.region },
          { label: 'Uptime', value: data.uptime },
          { label: 'Memory', value: data.memoryUsage },
          { label: 'Started At', value: new Date(data.startedAt).toLocaleString() },
        ];
        grid.innerHTML = items.map(i =>
          '<div class="info-card"><div class="label">' + i.label + '</div><div class="value">' + i.value + '</div></div>'
        ).join('');
      });
  </script>
</body>
</html>`);
});

// ──────────────────────────────────────────────
// Start server
// ──────────────────────────────────────────────
app.listen(PORT, "0.0.0.0", () => {
  console.log("🚀 Server started on port " + PORT);
  console.log("📦 Hostname: " + os.hostname());
  console.log("🌍 Region: " + (process.env.AZURE_REGION || "local"));
});
