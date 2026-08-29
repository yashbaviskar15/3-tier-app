// Vercel Serverless Functions Handler for 3-Tier Enterprise Application
const os = require('os');

// In-Memory Database State (Emulated Multi-AZ RDS Cluster for Serverless)
let activeDb = {
  status: 'CONNECTED',
  engine: 'Amazon Aurora MySQL (Multi-AZ)',
  database: 'appdb_production',
  host: 'db-cluster.prod.ap-south-1.rds.amazonaws.com',
  port: '3306',
  user: 'admin',
  dbVersion: '8.0.35-aurora-enterprise',
  replicationState: 'Synchronous Multi-AZ (Active/Standby)',
  tablesCount: 14,
  activeConnections: 28,
  uptime: '99.99%'
};

function setCors(res) {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Headers', 'Origin, X-Requested-With, Content-Type, Accept');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
}

module.exports = async (req, res) => {
  setCors(res);

  if (req.method === 'OPTIONS') {
    return res.status(200).end();
  }

  const url = req.url || '';
  const parsedPath = url.split('?')[0];

  // 1. Health Endpoint (/api/health)
  if (parsedPath.endsWith('/api/health') || parsedPath === '/api/health') {
    return res.status(200).json({
      status: 'UP',
      timestamp: new Date().toISOString(),
      uptime: process.uptime ? process.uptime() : 184520,
      environment: 'production',
      region: 'ap-south-1',
      tier1_presentation: 'HEALTHY',
      tier2_application: 'HEALTHY',
      tier3_database: 'HEALTHY',
      details: {
        presentation: 'CloudFront Edge CDN + S3 OAC (100% Operational)',
        application: 'ALB Target Group + Auto Scaling Fleet (3/3 Desired Nodes)',
        database: `${activeDb.engine} - ${activeDb.status}`
      }
    });
  }

  // 2. Info / Instance Metadata (/api/info)
  if (parsedPath.endsWith('/api/info') || parsedPath === '/api/info') {
    return res.status(200).json({
      app: 'Enterprise Three-Tier Web Application Console',
      tier: 'Application Fleet Tier (ASG Fleet / Serverless Node)',
      hostname: os.hostname() || 'asg-node-ap-south-1a-prod-01',
      platform: `${os.platform()} (${os.arch()})`,
      arch: os.arch(),
      region: 'ap-south-1',
      availabilityZone: 'ap-south-1a',
      nodeVersion: process.version,
      dbHost: activeDb.host,
      dbEngine: activeDb.engine,
      status: 'HEALTHY',
      asgGroup: 'prod-asg-app-tier',
      albTargetGroup: 'prod-alb-tg-8080'
    });
  }

  // 3. Database Status (/api/db-status)
  if (parsedPath.endsWith('/api/db-status') || parsedPath === '/api/db-status') {
    return res.status(200).json({
      status: activeDb.status,
      engine: activeDb.engine,
      database: activeDb.database,
      host: activeDb.host,
      port: activeDb.port,
      dbTime: new Date().toISOString(),
      dbVersion: activeDb.dbVersion,
      replicationState: activeDb.replicationState,
      tablesCount: activeDb.tablesCount,
      activeConnections: activeDb.activeConnections,
      uptime: activeDb.uptime
    });
  }

  // 4. Dynamic DB Connection (/api/connect-db or /api/connect-rds)
  if ((parsedPath.endsWith('/api/connect-db') || parsedPath.endsWith('/api/connect-rds')) && req.method === 'POST') {
    try {
      let body = req.body;
      if (typeof body === 'string') {
        try { body = JSON.parse(body); } catch(e) {}
      }
      body = body || {};

      const { host, port, user, database, engine } = body;

      if (engine === 'MOCK' || engine === 'LOCAL') {
        activeDb = {
          status: 'CONNECTED',
          engine: 'In-Memory Fallback Database',
          database: 'appdb_mock',
          host: 'localhost-mock',
          port: '3306',
          user: 'admin',
          dbVersion: 'MySQL 8.0-LocalFallback',
          replicationState: 'Local Standalone',
          tablesCount: 8,
          activeConnections: 5,
          uptime: '100.0%'
        };
        return res.status(200).json({
          status: 'CONNECTED',
          database: activeDb.database,
          host: activeDb.host,
          engine: activeDb.engine,
          message: 'Switched to local database fallback emulator successfully.'
        });
      }

      const dbEngine = (engine || 'MYSQL').toUpperCase();
      const targetHost = host || (dbEngine === 'POSTGRESQL' ? 'pg-cluster.prod.ap-south-1.rds.amazonaws.com' : 'db-primary.prod.ap-south-1.rds.amazonaws.com');

      activeDb = {
        status: 'CONNECTED',
        engine: dbEngine === 'POSTGRESQL' ? 'PostgreSQL 15.4 Multi-AZ' : 'MySQL 8.0.35 Multi-AZ Cluster',
        database: database || (dbEngine === 'POSTGRESQL' ? 'postgres' : 'appdb'),
        host: targetHost,
        port: port || (dbEngine === 'POSTGRESQL' ? '5432' : '3306'),
        user: user || (dbEngine === 'POSTGRESQL' ? 'postgres' : 'admin'),
        dbVersion: dbEngine === 'POSTGRESQL' ? 'PostgreSQL 15.4 (Enterprise Multi-AZ)' : 'MySQL 8.0.35-AWS-RDS',
        replicationState: 'Multi-AZ Standby Sync Active',
        tablesCount: 16,
        activeConnections: 32,
        uptime: '99.99%'
      };

      return res.status(200).json({
        status: 'CONNECTED',
        database: activeDb.database,
        host: activeDb.host,
        engine: activeDb.engine,
        dbTime: new Date().toISOString(),
        dbVersion: activeDb.dbVersion,
        message: `Successfully connected to ${activeDb.engine} at ${activeDb.host}`
      });
    } catch (err) {
      return res.status(500).json({ status: 'ERROR', message: `Database handshake error: ${err.message}` });
    }
  }

  // 5. Cloud Terminal Command Exec (/api/exec)
  if (parsedPath.endsWith('/api/exec') && req.method === 'POST') {
    try {
      let body = req.body;
      if (typeof body === 'string') {
        try { body = JSON.parse(body); } catch(e) {}
      }
      body = body || {};
      const command = (body.command || '').trim();

      if (!command) {
        return res.status(400).json({ output: 'Error: Command is required.' });
      }

      if (command === 'clear' || command === 'cls') {
        return res.json({ output: '' });
      }

      if (command === 'help' || command === '?') {
        return res.json({
          output: `Enterprise 3-Tier Cloud Console CLI - Available Commands:
  - health                         : Check full status across Presentation, App Fleet & Database Tiers
  - db-status                      : Inspect primary RDS / Aurora database cluster status
  - info                           : Display AWS EC2/ASG instance & region metadata
  - terraform plan                 : Run simulated Terraform infrastructure plan
  - aws s3 ls                      : List CloudFront S3 origin buckets
  - aws rds describe-db-instances  : Inspect RDS Multi-AZ instances
  - aws elbv2 describe-load-balancers : Inspect ALB status
  - uptime                         : Display cluster uptime
  - date                           : Display current UTC timestamp
  - whoami                         : Show current execution role
  - node -v                        : Show Node.js runtime version
  - clear / cls                    : Clear console log`
        });
      }

      if (command === 'health') {
        return res.json({
          output: `[TIER 1 - PRESENTATION]: HEALTHY (CloudFront CDN + S3 OAC Edge Active)\n[TIER 2 - APPLICATION] : HEALTHY (ALB Active, 3/3 Healthy EC2 Nodes in ap-south-1)\n[TIER 3 - DATABASE]   : HEALTHY (${activeDb.engine} @ ${activeDb.host} - Synchronized)\nOVERALL SYSTEM STATUS : OPERATIONAL (100% Available)`
        });
      }

      if (command === 'db-status') {
        return res.json({
          output: `Database Engine     : ${activeDb.engine}\nCluster Endpoint    : ${activeDb.host}:${activeDb.port}\nDatabase Name       : ${activeDb.database}\nReplication Mode    : ${activeDb.replicationState}\nActive Connections  : ${activeDb.activeConnections}\nStatus              : ${activeDb.status} (Healthy)`
        });
      }

      if (command === 'info') {
        return res.json({
          output: `Architecture : AWS 3-Tier Enterprise Infrastructure\nRegion       : ap-south-1 (Mumbai)\nSubnets      : 2 Public (ALB) | 2 Private App (ASG) | 2 Isolated Data (RDS)\nSecurity     : Chained Security Groups + IAM Instance Profiles + Secrets Manager\nNode OS      : Amazon Linux 2023 / Node ${process.version}`
        });
      }

      if (command.includes('terraform')) {
        return res.json({
          output: `Terraform v1.6.5 on linux_amd64\nInitializing the backend...\nRefreshing state... [id=vpc-084792a10e8d]\nPlan: 0 to add, 0 to change, 0 to destroy.\nInfrastructure is up to date and matches configuration in environments/prod.`
        });
      }

      if (command.includes('aws s3 ls')) {
        return res.json({
          output: `2026-07-25 10:14:02 three-tier-static-assets-prod-ap-south-1\n2026-07-25 10:14:03 three-tier-access-logs-prod-ap-south-1\n2026-07-25 10:14:04 three-tier-tf-state-prod`
        });
      }

      if (command.includes('aws rds describe-db-instances')) {
        return res.json({
          output: `DBInstanceIdentifier: prod-rds-mysql-cluster\nDBInstanceClass     : db.r6g.xlarge\nMultiAZ             : true (ap-south-1a / ap-south-1b)\nEngine              : mysql 8.0.35\nStorageEncrypted    : true (AWS KMS)\nDBInstanceStatus    : available`
        });
      }

      if (command.includes('aws elbv2 describe-load-balancers')) {
        return res.json({
          output: `LoadBalancerName : prod-three-tier-alb\nScheme           : internet-facing\nType             : application\nState            : active\nDNSName          : prod-three-tier-alb-19842.ap-south-1.elb.amazonaws.com`
        });
      }

      if (command === 'uptime') {
        return res.json({ output: `up 142 days, 18:24, 3 load average: 0.12, 0.08, 0.05` });
      }

      if (command === 'date') {
        return res.json({ output: new Date().toUTCString() });
      }

      if (command === 'whoami') {
        return res.json({ output: 'arn:aws:iam::123456789012:role/prod-ec2-app-tier-role (ec2-user)' });
      }

      if (command === 'node -v' || command === 'node --version') {
        return res.json({ output: process.version || 'v20.15.0' });
      }

      if (command === 'ls' || command === 'dir') {
        return res.json({ output: 'Dockerfile  README.md  docs  environments  modules  src  vercel.json' });
      }

      if (command === 'pwd') {
        return res.json({ output: '/var/www/three-tier-app' });
      }

      return res.json({
        output: `Executed: ${command}\nResult: Command executed successfully on application fleet cluster.`
      });
    } catch (err) {
      return res.status(500).json({ output: `Error: ${err.message}` });
    }
  }

  // Fallback for unmatched API routes
  return res.status(200).json({
    status: 'UP',
    message: 'AWS Three-Tier API Gateway is operational.',
    endpoints: ['/api/health', '/api/info', '/api/db-status', '/api/connect-db', '/api/exec']
  });
};
