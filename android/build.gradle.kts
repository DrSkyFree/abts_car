allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// 统一所有子模块（含 Flutter 插件）的 JVM 字节码目标版本。
//
// 部分插件（如 umeng_common_sdk）没有声明 compileOptions，Java 侧会落到
// AGP 默认的 1.8，而 Kotlin 插件（KGP 2.x）默认跟随当前 JDK（17），
// 构建时报 "Inconsistent JVM Target Compatibility Between Java and Kotlin Tasks"。
//
// 为什么放在 taskGraph.whenReady：
//  * 直接改 JavaCompile 任务属性，会被 AGP 在自己的 configureEach 里
//    用 compileOptions 的值回写覆盖（发生在配置期）；
//  * whenReady 在所有项目求值完成、任务图构建好之后、任何任务执行之前触发，
//    此时赋值不会再被配置期逻辑覆盖；而 Kotlin 插件的目标一致性校验
//    发生在任务执行期，读到的就是改后的值。
// 直接改 android 扩展上的 compileOptions（AGP 唯一的真值来源），
// 而不是 JavaCompile 任务的属性——任务属性会被 AGP 在自己的 configureEach 里
// 用 compileOptions 的值回写覆盖。
// 也不能用 tasks.withType(...).forEach：forEach 会提前实例化所有任务，
// 破坏 AGP 基于 variant 的任务配置，导致 android.jar 脱离编译 classpath
// （表现为「找不到 android.content.Context」）。
// 这里用 afterEvaluate + Groovy 动态调用：compileOptions 是 Groovy 生成的
// 动态属性，Kotlin DSL 里无法静态引用其类型。
subprojects {
    val target = this
    afterEvaluate {
        alignJvmTarget(target)
    }
}

// 把插件的 Java 字节码目标对齐到 17，与 Kotlin 侧保持一致
fun alignJvmTarget(project: Project) {
    val androidExt = project.extensions.findByName("android") ?: return
    runCatching {
        androidExt.javaClass.methods
            .firstOrNull { it.name == "compileOptions" && it.parameterCount == 0 }
            ?.invoke(androidExt)
            ?.let { options ->
                val cls = options.javaClass
                cls.methods.firstOrNull { it.name == "setSourceCompatibility" }
                    ?.invoke(options, JavaVersion.VERSION_17)
                cls.methods.firstOrNull { it.name == "setTargetCompatibility" }
                    ?.invoke(options, JavaVersion.VERSION_17)
            }
    }.onFailure {
        project.logger.warn("alignJvmTarget failed: ${it.message}")
    }
}

// umeng_common_sdk 1.3.1 的 main 源码目录里同时存在
//   src/main/java/.../UmengCommonSdkPlugin.java
//   src/main/kotlin/.../UmengCommonSdkPlugin.kt
// 两份都声明 com.umeng.umeng_common_sdk.UmengCommonSdkPlugin。
// 旧版 KGP 不检查这种重复声明，新版 KGP 会报 Redeclaration 导致构建失败。
//
// 这里在配置期删掉重复的 Kotlin 源文件，保留 Java 实现
//（两者内容等价，Flutter 按类名注册插件，不受影响）。
// 用源文件级 exclude 无效：Kotlin 编译会把 java 源目录也纳入解析范围。
subprojects {
    if (name == "umeng_common_sdk") {
        plugins.withId("com.android.library") {
            val dup =
                file("src/main/kotlin/com/umeng/umeng_common_sdk/UmengCommonSdkPlugin.kt")
            if (dup.exists()) {
                dup.delete()
                logger.lifecycle("已移除重复的 Kotlin 源：$dup")
            }
        }
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
