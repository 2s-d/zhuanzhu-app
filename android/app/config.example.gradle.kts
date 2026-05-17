/**
 * Android 构建配置文件示例（可以上传到 Git）
 * 
 * 使用方法：
 * 1. 复制此文件为 config.gradle.kts
 * 2. 填入真实的 AUTH_SECRET（从阿里云号码认证控制台获取）
 * 3. config.gradle.kts 已在 .gitignore 中排除，不会上传到 Git
 */

// 阿里云号码认证 SDK 密钥（从号码认证控制台获取）
// 获取方式：登录阿里云号码认证服务控制台 -> 创建认证方案 -> 获取密钥
ext {
    AUTH_SECRET = "\"your_auth_secret_here\""
}
