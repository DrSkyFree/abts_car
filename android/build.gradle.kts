allprojects {
    repositories {
        google()
        mavenCentral()
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

// umeng_common_sdk 1.3.1 同时带了两份同名类：src/main/java 下是真正干活的 Java 实现，
// src/main/kotlin 下是 Flutter 模板自动生成的空壳（只有 getPlatformVersion）。
// Kotlin 2.x 会把同模块的 Java 源也一起纳入分析，两份同名类直接报
// "Redeclaration: class UmengCommonSdkPlugin"，导致 compileReleaseKotlin 失败。
// 这里在配置阶段删掉那个空壳，保留 Java 实现。
subprojects {
    if (name == "umeng_common_sdk") {
        val kotlinStub = file("src/main/kotlin/com/umeng/umeng_common_sdk/UmengCommonSdkPlugin.kt")
        if (kotlinStub.exists()) {
            logger.lifecycle("[abts] 移除 umeng_common_sdk 中与 Java 实现重名的 Kotlin 模板桩")
            kotlinStub.delete()
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
