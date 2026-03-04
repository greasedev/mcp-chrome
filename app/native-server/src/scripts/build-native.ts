import { execSync } from 'child_process';
import fs from 'fs';
import path from 'path';

const distDir = path.join(__dirname, '..', '..', 'dist');

// 首先运行普通构建
console.log('执行基础构建...');
execSync('ts-node src/scripts/build.ts', { stdio: 'inherit' });

// 读取 package.json
const packageJson = require('../../package.json');

// 安装生产依赖到 dist/node_modules
console.log('安装生产依赖到 dist 目录...');
try {
  // 创建 dist/package.json（只包含生产依赖）
  // 注意：bin 路径需要调整，因为 package.json 在 dist 目录里
  const distPackageJson = {
    name: packageJson.name,
    version: packageJson.version,
    description: packageJson.description,
    main: 'index.js',
    // 调整 bin 路径，移除 ./dist/ 前缀
    bin: Object.fromEntries(
      Object.entries(packageJson.bin || {}).map(([name, binPath]) => {
        const pathStr = binPath as string;
        // 移除 ./dist/ 或 dist/ 前缀
        return [name, './' + pathStr.replace(/^\.?\/?dist\//, '')];
      }),
    ),
    dependencies: packageJson.dependencies,
    engines: packageJson.engines,
  };

  const distPackageJsonPath = path.join(distDir, 'package.json');
  fs.writeFileSync(distPackageJsonPath, JSON.stringify(distPackageJson, null, 2), 'utf8');
  console.log('已创建 dist/package.json');

  // 在 dist 目录运行 npm install --production
  // 注意：原生模块（如 better-sqlite3）会在 npm install 时自动编译
  execSync('npm install --production', {
    cwd: distDir,
    stdio: 'inherit',
  });
  console.log('✅ 生产依赖安装完成');

  // 注意：保留 package.json，cli.js 需要它来读取版本信息
  console.log('已保留 dist/package.json（cli.js 需要读取版本信息）');
} catch (error) {
  console.error('安装生产依赖时出错:', error);
  process.exit(1);
}

console.log('✅ Native 构建完成 - dist 目录已包含所有运行时依赖');
