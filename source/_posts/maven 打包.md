---
title: Maven 打包
author: kangshifu
top: false
cover: false
toc: true
mathjax: false
categories: Maven
tags:
  - Maven
abbrlink: 3589231934
date: 2020-05-20 20:31:23
img:
coverImg:
password:
summary:
---

<!--more-->  

### 三种打包插件

| plugin                | function                                       |
| --------------------- | ---------------------------------------------- |
| maven-jar-plugin      | maven 默认打包插件，用来创建 project jar       |
| maven-shade-plugin    | 用来打可执行包，executable(fat) jar            |
| maven-assembly-plugin | 支持定制化打包方式，例如 apache 项目的打包方式 |

![项目结构及依赖](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/%E9%A1%B9%E7%9B%AE%E7%BB%93%E6%9E%84%E5%8F%8A%E4%BE%9D%E8%B5%96.png)

### maven-jar-plugin

```xml
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-jar-plugin</artifactId>
                <version>2.4</version>
                <configuration>
                    <archive>
                        <manifest>
                            <addClasspath>true</addClasspath>
                            <classpathPrefix>lib/</classpathPrefix>
                            <mainClass>com.example.demo.Test</mainClass>
                        </manifest>
                    </archive>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-dependency-plugin</artifactId>
                <version>2.10</version>
                <executions>
                    <execution>
                        <id>copy-dependencies</id>
                        <phase>package</phase>
                        <goals>
                            <goal>copy-dependencies</goal>
                        </goals>
                        <configuration>
                            <outputDirectory>${project.build.directory}/lib</outputDirectory>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
```

maven-jar-plugin用于生成META-INF/MANIFEST.MF文件的部分内容，<addClasspath>true</addClasspath>会在MANIFEST.MF加上Class-Path项并配置依赖包，<mainClass>com.xxg.Main</mainClass>指定MANIFEST.MF中的Main-Class，<classpathPrefix>lib/</classpathPrefix>指定依赖包所在目录。

```MF
## MANIFEST.MF文件
Manifest-Version: 1.0
Implementation-Title: demo
Implementation-Version: 0.0.1-SNAPSHOT
Archiver-Version: Plexus Archiver
Built-By: zhangchengkang
Implementation-Vendor-Id: com.example
Class-Path: lib/spring-boot-starter-2.3.0.RELEASE.jar lib/spring-boot-
 2.3.0.RELEASE.jar lib/spring-context-5.2.6.RELEASE.jar lib/spring-aop
 -5.2.6.RELEASE.jar lib/spring-beans-5.2.6.RELEASE.jar lib/spring-expr
 ession-5.2.6.RELEASE.jar lib/spring-boot-autoconfigure-2.3.0.RELEASE.
 jar lib/spring-boot-starter-logging-2.3.0.RELEASE.jar lib/logback-cla
 ssic-1.2.3.jar lib/logback-core-1.2.3.jar lib/slf4j-api-1.7.30.jar li
 b/log4j-to-slf4j-2.13.2.jar lib/log4j-api-2.13.2.jar lib/jul-to-slf4j
 -1.7.30.jar lib/jakarta.annotation-api-1.3.5.jar lib/spring-core-5.2.
 6.RELEASE.jar lib/spring-jcl-5.2.6.RELEASE.jar lib/snakeyaml-1.26.jar
  lib/fastjson-1.2.60.jar lib/jedis-2.9.0.jar lib/commons-pool2-2.8.0.
 jar
Created-By: Apache Maven 3.6.3
Build-Jdk: 1.8.0_73
Implementation-Vendor: Pivotal Software, Inc.
Main-Class: com.example.demo.Test

```



maven-dependency-plugin插件用于将依赖包拷贝到<outputDirectory>${project.build.directory}/lib</outputDirectory>指定的位置，即lib目录下

![maven-jar-plugin-target结构.png](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/maven-jar-plugin-target%E7%BB%93%E6%9E%84.png)

![maven-jar-plugin-jar文件格式.png ](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/maven-jar-plugin-jar%E6%96%87%E4%BB%B6%E6%A0%BC%E5%BC%8F.png)

指定了Main-Class，有了依赖包，那么就可以直接通过java -jar xxx.jar运行jar包。

这种方式生成jar包有个缺点，就是生成的jar包太多不便于管理，下面两种方式只生成一个jar文件，包含项目本身的代码、资源以及所有的依赖包。

### maven-shade-plugin

```XML
        <plugins>
<!--            <plugin>-->
<!--                <groupId>org.springframework.boot</groupId>-->
<!--                <artifactId>spring-boot-maven-plugin</artifactId>-->
<!--            </plugin>-->
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>2.4.3</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                            <transformers>
                                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                                    <mainClass>com.example.demo.Test</mainClass>
                                </transformer>
                            </transformers>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
```

![maven-shade-plugin-jar文件格式.png ](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/maven-shade-plugin-jar%E6%96%87%E4%BB%B6%E6%A0%BC%E5%BC%8F.png)

这个jar文件是可以直接运行的 
springBoot项目不能用此方法打包?



### maven-assembly-plugin

```xml
 <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-assembly-plugin</artifactId>
                <version>2.4</version>
                <executions>
                    <execution>
                        <id>make-assembly</id>
                        <!-- 绑定到package生命周期 -->
                        <phase>package</phase>
                        <goals>
                            <!-- 只运行一次 -->
                            <goal>single</goal>
                        </goals>
                    </execution>
                </executions>
                <configuration>
                    <!-- 配置描述符文件
                    <descriptors>src/main/assembly/assembly.xml</descriptors>-->
                    <!-- 也可以使用Maven预配置的描述符-->
                    <descriptorRefs>
                        <descriptorRef>jar-with-dependencies</descriptorRef>
                    </descriptorRefs>
                    <!--删除后缀-->
                    <appendAssemblyId>false</appendAssemblyId>
                    <!--修改jar名称
                    <finalName>yourName</finalName>-->
                </configuration>
            </plugin>
        </plugins>
    </build>

```

![maven-assembly-plugin-jar文件格式.png ](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/maven-assembly-plugin-jar%E6%96%87%E4%BB%B6%E6%A0%BC%E5%BC%8F.png)

#### 

可自定义配置描述符文件:

```xml
<?xml version='1.0' encoding='UTF-8'?>
<assembly xmlns="http://maven.apache.org/plugins/maven-assembly-plugin/assembly/1.1.0"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
    xsi:schemaLocation="http://maven.apache.org/plugins/maven-assembly-plugin/assembly/1.1.0  
                    http://maven.apache.org/xsd/assembly-1.1.0.xsd">
    <id>demo</id>
    <formats>
        <format>jar</format>
    </formats>
    <includeBaseDirectory>false</includeBaseDirectory>
    <fileSets>
        <fileSet>
            <directory>${project.build.directory}/classes</directory>
            <outputDirectory>/</outputDirectory>
        </fileSet>
    </fileSets>
</assembly>
```

- format：指定打包类型；
- includeBaseDirectory：指定是否包含打包层目录（比如finalName是output，当值为true，所有文件被放在output目录下，否则直接放在包的根目录下）；
- fileSets：指定要包含的文件集，可以定义多个fileSet；
- directory：指定要包含的目录；
- outputDirectory：指定当前要包含的目录的目的地。



### spring-boot-maven-plugin

```xml
        <plugins>
            <plugin>
                <groupId>org.springframework.boot</groupId>
                <artifactId>spring-boot-maven-plugin</artifactId>
            </plugin>
        </plugins>
```

```
## MANIFEST.MF文件
Manifest-Version: 1.0
Spring-Boot-Classpath-Index: BOOT-INF/classpath.idx
Implementation-Title: demo
Implementation-Version: 0.0.1-SNAPSHOT
Start-Class: com.example.demo.DemoApplication
Spring-Boot-Classes: BOOT-INF/classes/
Spring-Boot-Lib: BOOT-INF/lib/
Build-Jdk-Spec: 1.8
Spring-Boot-Version: 2.3.0.RELEASE
Created-By: Maven Jar Plugin 3.2.0
Implementation-Vendor: Pivotal Software, Inc.
Main-Class: org.springframework.boot.loader.JarLauncher

```

spring-boot-maven-plugin所做的工作是在默认的maven-jar-plugin插件打包结束后，将项目依赖的jar包中的.class文件重新进行打包。

```shell
[INFO] --- maven-jar-plugin:3.2.0:jar (default-jar) @ demo ---
[INFO] Building jar: G:\project\package_demo\target\demo-0.0.1-SNAPSHOT.jar
[INFO] 
[INFO] --- spring-boot-maven-plugin:2.3.0.RELEASE:repackage (repackage) @ demo ---
[INFO] Replacing main artifact with repackaged archive
[INFO] 
[INFO] --- maven-install-plugin:2.5.2:install (default-install) @ demo ---
[INFO] Installing G:\project\package_demo\target\demo-0.0.1-SNAPSHOT.jar to C:\Users\zhangchengkang\.m2\repository\com\example\demo\0.0.1-SNAPSHOT\demo-0.0.1-SNAPSHOT.jar
[INFO] Installing G:\project\package_demo\pom.xml to C:\Users\zhangchengkang\.m2\repository\com\example\demo\0.0.1-SNAPSHOT\demo-0.0.1-SNAPSHOT.pom
[INFO] ------------------------------------------------------------------------
[INFO] BUILD SUCCESS
[INFO] ------------------------------------------------------------------------
[INFO] Total time:  2.208 s
[INFO] Finished at: 2020-05-20T11:29:19+08:00
[INFO] ------------------------------------------------------------------------

```



可以看出，在调用maven-jar-plugin的goal:jar任务打包之后，又调用了spring-boot-maven-plugin的goal:repackage任务，这样会产生两个jar包。

一个是demo-0.0.1-SNAPSHOT.jar(spring-boot-maven-plugin重新打包生成的可执行jar包)

另一个demo-0.0.1-SNAPSHOT.jar.original(maven-jar-plugin打包生成的jar包)

可以打开demo-0.0.1-SNAPSHOT.jar.original瞅瞅

![spring-boot-maven-plugin-original.png](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/spring-boot-maven-plugin-original.png)



巧不巧,跟maven-jar-plugin结构一毛一样





最后看看demo-0.0.1-SNAPSHOT.jar结构

![spring-boot-maven-plugin-target](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/spring-boot-maven-plugin-target.png)

![spring-boot-maven-plugin-BOOT-INF ](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/spring-boot-maven-plugin-BOOT-INF.png)

![spring-boot-maven-plugin-classes](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/maven/spring-boot-maven-plugin-classes.png)

