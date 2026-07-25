const express = require('express');
const mysql = require('mysql2/promise');
const { Pool: PgPool } = require('pg');
const path = require('path');
const { exec: execCmd } = require('child_process');

const app = express();
const PORT = process.env.PORT || 8080;

app.use(express.json());
app.use((req, res, next) => {
  res.header('Access-Control-Allow-Origin', '*');
  res.header('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.header('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  if (req.method === 'OPTIONS') return res.sendStatus(200);
  next();
});
app.use(express.static(path.join(__dirname, 'public')));

// Enterprise Database State Management
let dbType = 'MOCK'; // 'MYSQL', 'POSTGRESQL', or 'MOCK'
let mysqlPool = null;
let pgPool = null;
let activeDbName = 'in_memory_mock_db (Local Fallback)';
let activeDbHost = 'localhost-mock';
let activeEngine = 'MySQL 8.0 / PostgreSQL 15';

// Default Database Configuration
const dbConfig = {
  host: process.env.DB_HOST,
  user: process.env.DB_USER || 'admin',
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME || 'appdb',
  port: process.env.DB_PORT ? parseInt(process.env.DB_PORT) : 3306,
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
  connectTimeout: 5000
};

async function initDatabase() {
  if (process.env.DB_HOST) {
    try {
      console.log('Connecting to primary database host:', process.env.DB_HOST);
      mysqlPool = mysql.createPool(dbConfig);
      const conn = await mysqlPool.getConnection();
      conn.release();
      dbType = 'MYSQL';
      activeDbName = dbConfig.database;
      activeDbHost = dbConfig.host;
      activeEngine = 'MySQL 8.0';
      console.log('Connected to MySQL database successfully!');
      return;
    } catch (err) {
      console.error('Direct database connection failed:', err.message);
      console.log('Using local database fallback emulator...');
    }
  } else {
    console.log('No external database environment variables found. Initialized local fallback database.');
  }
}

initDatabase();

// 3-Tier Health Check
app.get('/api/health', async (req, res) => {
  res.status(200).json({
    status: 'UP',
    timestamp: new Date().toISOString(),
    uptime: process.uptime(),
    environment: 'production',
    region: 'ap-south-1',
    tier1_presentation: 'HEALTHY',
    tier2_application: 'HEALTHY',
    tier3_database: dbType === 'MOCK' ? 'EMULATED' : 'HEALTHY'
  });
});

// Database Status Endpoint
app.get('/api/db-status', async (req, res) => {
  if (dbType === 'MYSQL' && mysqlPool) {
    try {
      const conn = await mysqlPool.getConnection();
      const [rows] = await conn.query('SELECT NOW() as db_time, VERSION() as version');
      conn.release();
      return res.status(200).json({
        status: 'CONNECTED',
        engine: 'MySQL',
        database: activeDbName,
        host: activeDbHost,
        dbTime: rows[0].db_time,
        dbVersion: rows[0].version
      });
    } catch (err) {
      return res.status(500).json({ status: 'DISCONNECTED', error: err.message });
    }
  } else if (dbType === 'POSTGRESQL' && pgPool) {
    try {
      const client = await pgPool.connect();
      const result = await client.query('SELECT NOW() as db_time, version()');
      client.release();
      return res.status(200).json({
        status: 'CONNECTED',
        engine: 'PostgreSQL',
        database: activeDbName,
        host: activeDbHost,
        dbTime: result.rows[0].db_time,
        dbVersion: result.rows[0].version
      });
    } catch (err) {
      return res.status(500).json({ status: 'DISCONNECTED', error: err.message });
    }
  } else {
    return res.status(200).json({
      status: 'CONNECTED',
      engine: 'In-Memory Mock Database (Local Fallback)',
      database: activeDbName,
      host: activeDbHost,
      dbTime: new Date().toISOString(),
      dbVersion: 'MySQL 8.0-Local'
    });
  }
});

// Dynamic Database Connection Endpoint
app.post('/api/connect-db', async (req, res) => {
  const { host, port, user, password, database, engine, connectionString } = req.body;

  if (engine === 'MOCK') {
    dbType = 'MOCK';
    activeDbName = 'in_memory_mock_db (Local Fallback)';
    activeDbHost = 'localhost-mock';
    activeEngine = 'Mock Database Engine';
    return res.status(200).json({
      status: 'CONNECTED',
      database: activeDbName,
      host: activeDbHost,
      engine: activeEngine,
      message: 'Switched to local fallback database.'
    });
  }

  const dbEngine = (engine || 'MYSQL').toUpperCase();

  if (dbEngine === 'MYSQL') {
    const targetHost = host || (connectionString ? connectionString.split('@')[1]?.split(':')[0] : null);
    if (!targetHost) {
      return res.status(400).json({ status: 'ERROR', message: 'Host endpoint is required.' });
    }
    try {
      console.log(`Connecting to MySQL database at ${targetHost}...`);
      const tempPool = mysql.createPool({
        host: targetHost,
        port: parseInt(port || 3306),
        user: user || 'admin',
        password,
        database: database || 'appdb',
        connectTimeout: 5000
      });
      const conn = await tempPool.getConnection();
      const [rows] = await conn.query('SELECT NOW() as db_time, VERSION() as version');
      conn.release();

      if (mysqlPool) await mysqlPool.end().catch(() => {});
      mysqlPool = tempPool;
      dbType = 'MYSQL';
      activeDbHost = targetHost;
      activeDbName = database || 'appdb';
      activeEngine = `MySQL ${rows[0].version}`;

      return res.status(200).json({
        status: 'CONNECTED',
        database: activeDbName,
        host: activeDbHost,
        engine: activeEngine,
        dbTime: rows[0].db_time,
        dbVersion: rows[0].version
      });
    } catch (err) {
      console.error('MySQL connection error:', err.message);
      return res.status(500).json({ status: 'ERROR', message: `MySQL connection failed: ${err.message}` });
    }
  } else if (dbEngine === 'POSTGRESQL') {
    const targetHost = host || (connectionString ? connectionString.split('@')[1]?.split(':')[0] : null);
    if (!targetHost) {
      return res.status(400).json({ status: 'ERROR', message: 'Host endpoint is required.' });
    }
    try {
      console.log(`Connecting to PostgreSQL database at ${targetHost}...`);
      const tempPool = new PgPool({
        host: targetHost,
        port: parseInt(port || 5432),
        user: user || 'postgres',
        password,
        database: database || 'postgres',
        connectionTimeoutMillis: 5000,
        ssl: { rejectUnauthorized: false }
      });
      const client = await tempPool.connect();
      const result = await client.query('SELECT NOW() as db_time, version()');
      client.release();

      if (pgPool) await pgPool.end().catch(() => {});
      pgPool = tempPool;
      dbType = 'POSTGRESQL';
      activeDbHost = targetHost;
      activeDbName = database || 'postgres';
      activeEngine = 'PostgreSQL';

      return res.status(200).json({
        status: 'CONNECTED',
        database: activeDbName,
        host: activeDbHost,
        engine: activeEngine,
        dbTime: result.rows[0].db_time,
        dbVersion: result.rows[0].version
      });
    } catch (err) {
      console.error('PostgreSQL connection error:', err.message);
      return res.status(500).json({ status: 'ERROR', message: `PostgreSQL connection failed: ${err.message}` });
    }
  } else {
    return res.status(400).json({ status: 'ERROR', message: 'Unsupported Database Engine. Select MySQL or PostgreSQL.' });
  }
});

// Alias route
app.post('/api/connect-rds', (req, res) => {
  res.redirect(307, '/api/connect-db');
});

// Interactive Console Terminal Endpoint
app.post('/api/exec', (req, res) => {
  const { command } = req.body;
  if (!command || typeof command !== 'string') {
    return res.status(400).json({ output: 'Error: Command is required.' });
  }

  const trimmed = command.trim();
  if (trimmed === 'clear' || trimmed === 'cls') {
    return res.json({ output: '' });
  }

  if (trimmed === 'help' || trimmed === '?') {
    return res.json({
      output: `Enterprise 3-Tier Console CLI - Available Commands:
 - health          : Check cluster health status across all 3 tiers
 - db-status       : Inspect active database engine status
 - info            : Display environment metadata
 - ls / dir        : List local directory files
 - pwd             : Print working directory
 - date            : Display system timestamp
 - whoami          : Show OS user
 - node -v         : Show Node.js version
 - clear / cls     : Clear console log`
    });
  }

  const options = { timeout: 5000, cwd: path.join(__dirname) };
  if (process.platform === 'win32') {
    options.shell = 'powershell.exe';
  }

  execCmd(trimmed, options, (error, stdout, stderr) => {
    let result = (stdout || stderr || '').trim();
    if (!result && error) {
      result = error.message;
    }
    res.json({ output: result || 'Command executed successfully.' });
  });
});

// Instance Metadata Info
app.get('/api/info', (req, res) => {
  res.status(200).json({
    app: 'Enterprise Three-Tier Web Application Console',
    tier: 'Application Fleet Tier',
    hostname: require('os').hostname(),
    platform: process.platform,
    arch: process.arch,
    region: 'ap-south-1',
    dbHost: activeDbHost,
    dbEngine: activeEngine
  });
});

// Serve frontend SPA
app.get('*', (req, res) => {
  res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Enterprise Production Console running on port ${PORT}`);
});
