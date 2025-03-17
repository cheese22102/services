buildscript {
    repositories {
        google()  // Ensure that Google's repository is added
        mavenCentral()
    }
    dependencies {
        classpath("com.google.gms:google-services:4.3.15")  // Ensure the latest version of this plugin
        classpath("com.android.tools.build:gradle:7.0.4")   // Ensure compatibility with your compileSdk version
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
