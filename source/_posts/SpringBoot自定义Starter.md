---
title: SpringBoot自定义Starter
author: kangshifu
top: false
cover: false
toc: true
mathjax: false
categories: SpringBoot
tags:
  - Java
  - SpringBoot
abbrlink: 317826433
date: 2020-12-04 22:03:45
img:
coverImg:
password:
summary:
---

<!--more-->  

## 为什么要自定义Starter

**No Why**

## 实现步骤

###  TestClient

```java
//随便定义一个Service  用来验证
@Data//lombok
@Builder
public class TestClient {
    private String ip;
    private Integer port;

    public String getAddress() {
        return ip + ":" + port;
    }
}
```

### UserProperties

```java
//定义一个实体类  接收配置
@Data
@Configuration
//当配置文件中test.client.enabled=true时,才会注入
@ConditionalOnProperty(prefix = "test.client", name = "enable", havingValue = "true")
@ConfigurationProperties(prefix = "test.client")//批量注入配置文件的属性,前提是前缀匹配
public class UserProperties {

    private String ip;
    private Integer port;
}

```

### TestAutoConfiguration

```java
//编写AutoConfigure类
@Configuration
@EnableConfigurationProperties({UserProperties.class})//开启@ConfigurationProperties。
@ConditionalOnBean({UserProperties.class})//当给定的bean存在时,实例化下面@Bean指定的Bean
public class TestAutoConfiguration {

    @Bean
    @ConditionalOnMissingBean//当Spring Context中不存在该Bean时才会注册
    public TestClient makeTestClient(UserProperties userProperties) {
        return TestClient.builder().ip(userProperties.getIp()).port(userProperties.getPort()).build();
    }
}
```

### spring.factories

```json
//在resources/META-INF/下创建spring.factories文件
org.springframework.boot.autoconfigure.EnableAutoConfiguration=com.ksf.spring.boot.starter.test.TestAutoConfiguration
```

```java
//如果有多个AutoConfiguration
org.springframework.boot.autoconfigure.EnableAutoConfiguration=\
com.ksf.spring.boot.starter.test.TestAutoConfiguration,\
com.ksf.spring.boot.starter.test.TestAutoConfiguration,\
com.ksf.spring.boot.starter.test.TestAutoConfiguration
```

至此自定义Strater创建完毕

## 使用

### 引入依赖

```xml
        <dependency>
            <groupId>com.ksf.spring.boot.starter.test</groupId>
            <artifactId>test-spring-boot-starter</artifactId>
            <version>0.0.1-SNAPSHOT</version>
        </dependency>
```

### 配置文件

```properties
# application.properties
server.port=8082

test.client.enable = true
test.client.ip = "http://192.168.0.131"
test.client.port = 8080

```

### 测试

```java
@SpringBootApplication
@ComponentScan(value = "com.*")
@RestController
public class TestServiceApplication {

    public static void main(String[] args) {
        SpringApplication.run(TestServiceApplication.class, args);
    }

    @Autowired
    private TestClient testClient;

    @GetMapping("/init")
    public String init() {
        return testClient.getAddress();
    }

}
```

启动TestServiceApplication  访问http://localhost:8082/init

```
输出:"http://192.168.0.131":8080
```



## 工作原理

- Spring Boot在启动时扫描项目所依赖的JAR包，寻找包含spring.factories文件的JAR包，
- 然后读取spring.factories文件获取配置的自动配置类AutoConfiguration，
- 然后将自动配置类下满足条件(@ConditionalOnXxx)的@Bean放入到Spring容器中(Spring Context)
- 这样使用者就可以直接用来注入，因为该类已经在容器中了



## 常用注解

- @ConditionalOnClass：当类路径classpath下有指定的类的情况下进行自动配置

- @ConditionalOnMissingBean:当容器(Spring Context)中没有指定Bean的情况下进行自动配置

- @ConditionalOnProperty(prefix = “example.service”, value = “enabled”, matchIfMissing = true)，当配置文件中example.service.enabled=true时进行自动配置，如果没有设置此值就默认使用matchIfMissing对应的值

- @ConditionalOnMissingBean，当Spring Context中不存在该Bean时。

- @ConditionalOnBean:当容器(Spring Context)中有指定的Bean的条件下

- @ConditionalOnMissingClass:当类路径下没有指定的类的条件下

- @ConditionalOnExpression:基于SpEL表达式作为判断条件

- @ConditionalOnJava:基于JVM版本作为判断条件

- @ConditionalOnJndi:在JNDI存在的条件下查找指定的位置

- @ConditionalOnNotWebApplication:当前项目不是Web项目的条件下

- @ConditionalOnWebApplication:当前项目是Web项目的条件下

- @ConditionalOnResource:类路径下是否有指定的资源

- @ConditionalOnSingleCandidate:当指定的Bean在容器中只有一个，或者在有多个Bean的情况下，用来指定首选的Bean

- @ConfigurationProperties:把properties配置文件转化为对应的XxxProperties来使用的，并不会把该类放入到IOC容器中，如果想放入到容器中可以在XxxProperties上使用@Component
- @EnableConfigurationProperties(XxxProperties.class):使@ConfigurationProperties注解生效。相当于给类上加上了@Component注解，让IOC注入一下

## 源码地址

```java
https://github.com/zhangchengkang/demo-spring-boot-starter.git
```

