const path = require('path');

const rootDir = __dirname;
const venvDir = path.join(rootDir, '.venv');
const venvBin = path.join(venvDir, 'bin');
const processPath = process.env.PATH || '';

const sharedEnv = {
  NODE_ENV: process.env.NODE_ENV || 'production',
  VIRTUAL_ENV: venvDir,
  PATH: `${venvBin}:${processPath}`,
  CONFIG_ENV_PASSPHRASE: process.env.CONFIG_ENV_PASSPHRASE,
  CONFIG_ENV_KEY_FILE: process.env.CONFIG_ENV_KEY_FILE,
  CONFIG_ENV_ALGO: process.env.CONFIG_ENV_ALGO,
};

module.exports = {
  apps: [
    {
      name: 'vcp-main',
      cwd: rootDir,
      script: 'scripts/common/start_with_decrypted_config.sh',
      args: 'server.js',
      interpreter: '/usr/bin/env',
      interpreter_args: 'bash',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
      time: true,
      env: sharedEnv,
    },
    {
      name: 'vcp-admin',
      cwd: rootDir,
      script: 'scripts/common/start_with_decrypted_config.sh',
      args: 'adminServer.js',
      interpreter: '/usr/bin/env',
      interpreter_args: 'bash',
      instances: 1,
      exec_mode: 'fork',
      autorestart: true,
      max_restarts: 10,
      restart_delay: 3000,
      time: true,
      env: sharedEnv,
    },
  ],
};
