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
    val workspaceRoot = rootProject.projectDir.toPath().root
    val projectRoot = project.projectDir.toPath().root
    if (workspaceRoot == projectRoot) {
        project.layout.buildDirectory.value(newBuildDir.dir(project.name))
    } else {
        // Flutter plugins live in the Pub cache on C:, while this workspace is
        // on D:. Gradle cannot relativize Android unit-test sources when their
        // build directory is on another Windows drive.
        val externalPluginBuildDir =
            gradle.gradleUserHomeDir
                .resolve("flutter-build")
                .resolve(rootProject.projectDir.parentFile.name)
                .resolve(project.name)
        project.layout.buildDirectory.value(
            project.layout.dir(project.provider { externalPluginBuildDir }),
        )
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
