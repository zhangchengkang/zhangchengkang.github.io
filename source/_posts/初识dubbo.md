---
title: 初识Dubbo
author: kangshifu
top: false
cover: false
toc: true
mathjax: false
categories: Dubbo
tags:
  - Dubbo
abbrlink: 317826436
date: 2022-04-04 10:23:17
img:
coverImg:
password:
summary:
---

<!--more-->  

解析流程

```java
refresh-obtainFreshBeanFactory-refreshBeanFactory-loadBeanDefinitions-doLoadBeanDefinitions-registerBeanDefinitions-doRegisterBeanDefinitions-parseBeanDefinitions-parseDefaultElement-parseCustomElement      
NamespaceHandler handler = this.readerContext.getNamespaceHandlerResolver().resolve(namespaceUri);//需要在spring.handles配置dubboNamespaceHandler      
namespaceHandler.init(){          registerBeanDefinitionParser("service", new DubboBeanDefinitionParser(ServiceBean.class, true));        registerBeanDefinitionParser("reference", new DubboBeanDefinitionParser(ReferenceBean.class, false));      };   
DubboBeanDefinitionParser parse =   NamespaceHandlerSupport.findParserForElement   
parse.parse//解析xml标签
```

服务导出

```
serviveBean  serviceConfig  InitializingBean-afterPropertiesSet-publishEvent-onApplicationEvent-export-doExportUrls    -doExportUrlsFor1Protocol-protocol.export-RegistryProtocol.export-register-registry.register-zkregistry.register
```

服务引用

```
referenceBean  referenceConfig  InitializingBean-afterPropertiesSet-getObject-get-init-createProxy-putToMap
```