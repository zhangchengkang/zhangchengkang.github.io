---

title: 问题定位tips
author: kangshifu
top: false
cover: true
toc: true
mathjax: false
categories: 随笔
tags:
  - Java
abbrlink: 4013045822
date: 2021-04-03 15:21:02
img:
coverImg:
password:
summary:

---

<!--more-->  

## 前端排查

1. 通过接口响应的状态码判断 
   1. 404：请求的接口不存在或者页面不存在，我们系统常见的原因：请求方式由get改成了post，但是前端没更新；接口名变更了前端没更新；前端页面资源不存在导致菜单打开404（或先清缓存）。 
   2. 502，504：服务挂了导致连接失败或超时，快速定位下对应服务是否异常，可通过系统日志查看具体错误原因。 
   3. 605：网关超时或者跨域或者域名解析问题，找运维解决。 
2. 页面点击没响应或者资源没加载 
   1. F12看下具体JS报错，或清缓存或者Ctr+F12强制刷新页面解决。 
3. 页面网络异常 
   1. 接口超时导致，调整超时时间解决。 
   2. 网络问题，用非仓库网络验证下是否有问题，有的话可能是网络白名单或者是网络权限设置问题，找运维快速解决。 
4. 普通的业务报错 
   1. 通过系统日志查看具体错误原因。 
   2. 系统日志查询不到进入容器终端输入log命令，直接查看容器中的异常日志



## 后端排查

1. 大量超时报错

   1. 看数据库健康状态

      - 是否有慢sql
      - 最大连接数是否打满
      - CPU使用率是否过
      - IO使用率是否过高
      - Lock等待时间是否过长
      - 主动同步是否有延迟
   2. Arthas监控相关接口,看具体什么慢
   3. 再看服务状态
   
    - top -Hp 1
    - printf "%x\n" 1
    - jstack 1 | grep 1
   
   
   
2. 堆OOM,Metaspace OOM

   - jmap -heap 1 或者  Arthas dashboard 查看 JVM 使用情况
  - 看对象统计信息,找到占用内存较大的对象
     - jmap -histo 1 | sort -k 2 -g -r 
    - jmap -histo : live 1
     - jmap -histo 1 | grep 'com.xxx'
   
   - dump下来用Jprofiler看





   

   