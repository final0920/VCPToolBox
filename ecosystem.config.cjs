const path = require('path');

const rootDir = __dirname;
const venvDir = path.join(rootDir, '.venv');
const venvBin = path.join(venvDir, 'bin');
const processPath = process.env.PATH || '';

const sharedEnv = {
  NODE_ENV: process.env.NODE_ENV || 'production',
  VIRTUAL_ENV: venvDir,
  PATH: `${venvBin}:${processPath}`,
};

module.exports = {
  apps: [
    {
      name: 'vcp-main',
      cwd: rootDir,
      script: 'server.js',
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
      script: 'adminServer.js',
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
