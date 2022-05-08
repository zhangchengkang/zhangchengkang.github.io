---
title: TIDB
author: kangshifu
top: false
cover: true
toc: true
mathjax: false
categories: SQL
tags:
  - Java
  - SQL
abbrlink: 4013045821
date: 2021-06-03 14:02:21
img:
coverImg:
password:
summary:
---

<!--more-->  

## 简介 

TiDB是可以同时支持OLTP/OLAP场景的国产开源分布式关系型数据库，可无限水平扩展，多副本强一致，高度兼容MySQL 5.7协议和语法 

**特性：** 

- 分布式架构，解决业务持续增长MySQL单机存储、CPU IO性能瓶颈问题 
- 解决MySQL分库分表后对应用不透明不友好的痛点 
- TiFlash（基于ClickHouse）解决大表实时OLAP需求

|           | **相对优势**                                       | **相对劣势**                              | **参考数据**                      |
| --------- | -------------------------------------------------- | ----------------------------------------- | --------------------------------- |
| **MySQL** | 稳定性优  读写响应快 架构简单  生态完善            | 单机性能瓶颈  扩展困难 大表OLAP场景难支撑 | ~ 2w QPS  ~ 5ms响应 ~ 2TB容量     |
| **TiDB**  | 容量水平扩展  数据分片透明 TiFlash加速大表OLAP场景 | 稳定性  读写响应慢 架构复杂  binlog不兼容 | ~ 10w QPS  ~ 20ms响应 ~ 100TB容量 |



##  防止TiDB同步失败MySQL DDL操作尽量避免以下操作 

- 删除字段 
- 修改字段类型 
- 将字段长度调小 
- 修改主键 
- 添加或修改多个字段，避免加括号 



##  TiDB与MySQL差异 

https://blog.csdn.net/m0_37683758/article/details/86738403



## 使用建议

### 1.主键为bigint not null auto_random

读写tidb业务，表主键id需为 **bigint not null auto_random**，主键由tidb自身生成唯一随机数（不保证顺序递增），数据离散写入多个存储region，避免写入热点，提升读写性能 

[AUTO_RANDOM 处理自增主键热点表](https://docs.pingcap.com/zh/tidb/stable/troubleshoot-hot-spot-issues#使用-auto_random-处理自增主键热点表) 

下图所示为MySQL自增主键数据同步至TiDB产生了热点写入问题 

![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=MzJiODI5ZDU3ODUxOWE5NzQ2ZWM5OTlhMmEwMDBmYTNfME9MSFVyamhJZGRyN2NINW9ZenBUZzhiYlVXeXVJV01fVG9rZW46Ym94Y25jMW14VVV3eG0xV0xZVEh2MXlhY3plXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA)

 

### 2、不查询大量表数据 

tidb计算层、存储层分离，查询大量数据会把多个存储节点数据汇总到计算节点再返回给应用端，会占用计算节点大量内存，造成计算节点OOM重启 

> 如：单select在存储节点扫描65w数据->计算节点内存排序->返回应用端，1个连接select消耗计算节点500M内存，50个并发连接消耗25G内存，造成了计算节点OOM 

![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=YjRiYmM4NmIxMTY4OWQ5MDc3NzY1NTdlNTU1ZTgwMjlfYzVTcXZsczh3YkZZcDRFRXBveWxjejBMaFkwWVBOVEZfVG9rZW46Ym94Y25ES2U2ZktWYlV1Y28xc0Y5aE90cU1oXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA)

![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=YTdkZTU0ZWY2MWQ3ZTRiZGY0NjQ2NWNiYjY1ZmNjNjhfZHQ0U2NlR2xkbmtFYmZ1bnZNNUU0dTFRSDRheTVGMWVfVG9rZW46Ym94Y25CekhYektQWlV4QkJZNmhMSTFVWDdlXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA)

![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=NjNiY2ZmZGExNDk5YzZlNjNmNDkzNGZhZWE1M2ZhMjZfS05qNk5SZUNnVjN6dUR5cFQxMXBqbG9tV1RLcDFCaWNfVG9rZW46Ym94Y245TWduMHZFZmFoRVE1RFBmbno0UFFoXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA)

 

### 3、不使用多个大表JOIN复杂查询 

tidb计算层、存储层分离，会把满足条件的所有数据汇总到计算节点，再由计算节点关联排序，大量数据JOIN易造成计算节点OOM重启；尽量减少表join关联(如增加冗余数据) 

### 4、不使用大事务 

单行不超过 6MB，批量提交不超过100MB（否则报错transaction is too large） 

tidb分布式DB，有两阶段提交，并且底层还需要做 Raft 复制，事务越大越耗时；建议业务应用层update, delete语句影响行数不超过50000行（idb2 DB平台-TiDB工单 DML影响行数已限制在100000内） 

### 5、表索引需提前规划设计 

 tidb DDL 创建索引，添加字段都是串行执行，多个DDL任务会排队等待第一个DDL完成 

> 如下图为第一个加索引正在执行，后面4个加索引操作在等待状态；tidb创建索引很耗时， 

> 如下下图5亿表加索引耗时10h 

![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=ZjI5YjdiMjdmYmFiYTc0MDE2NjI4OWY0OWQxYzkwZjlfUU16V0pNMUo5dVJNNXJDM2IzSTBqZnhwcEhoZ1FIdWRfVG9rZW46Ym94Y25nbDkzZE9BTzZwalo5dDBMV3NWMG9mXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA)

![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=NDJlYTE1Y2VlNDBhODYxNTcyYWFiN2E2Nzk0NzlkYjlfUjRwRHFFRlZhRU9LWFZHbks4Y0tzQTczR3pZeFNPT09fVG9rZW46Ym94Y25US1gzUkZpR0tzdjYybW1QQXlGMkVkXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA)

 

### 6、查询务必走索引 

tidb分布式DB，同一个查询SQL会用到多个CPU核，若未使用索引，多个CPU核全表扫描表，消耗大量IO资源，会引起雪崩、搞垮整个tidb集群；尽量通过索引过滤出少量数据；tiflash列式存储除外(tiflash 列式存储不使用索引) 

### 7、提前规划设计好字段类型&数值精度 

tidb不支持将字段类型修改为其超集；不支持数值decimal精度的修改 

> 能支持：varchar增加长度、int类型修改为bigint 

```SQL
#int类型不支持修改为varchar类型
ALTER TABLE payment_bill MODIFY COLUMN account_period_days VARCHAR(255) NULL DEFAULT NULL; 
ERROR 8200 (HY000): Unsupported modify column: type varchar(255) not match origin int(11)

#decimal修改精度不支持
alter table test_0701_value modify test_num decimal(10,5);
ERROR 8200 (HY000): Unsupported modify column: can't change decimal column precision
```

### 8、表名查找&列值比较与MySQL有差异 

tidb中默认校对规则为utf8mb4_bin，字段值比较区分大小写；[lower-case-table-names](https://dev.mysql.com/doc/refman/5.7/en/server-system-variables.html#sysvar_lower_case_table_names) 为2，表名查找不区分大小写 

| MySQL表名比较区分大小写 ![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=YThhN2Y1NGVhNTM3ODUyZmZhNTBkMTkwNWZhMzdkMmZfQnc4RnhqbWY2c3RGSFVKTVg2NDhWZVI0RFFGdkphSkdfVG9rZW46Ym94Y25NRzlJSlhXZTBmYlUyQlQ5RDdhQlllXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA) | TiDB表名比较不区分大小写 ![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=YTJiZTVkNmI5NDEyNGY2MmIyZDBhM2MyYzJiZjAxZTBfdUdzdm5sUEZiSDRrc3RoUWdBVFh3NXZHRlBrY2I4TFhfVG9rZW46Ym94Y25NS3NFSnlvcnd4eG5nMW5JTjg1SUVZXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA) |
| ------------------------------------------------------------ | ------------------------------------------------------------ |
| MySQL字段值比较不区分大小写 ![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=YTQ0Y2M2ZTMxZWIzODg1ZDQ5ZGE4NWU1N2FjNzdiY2RfRU5YdUFIVGxhNDNwTUFwWml5NDlCZzlPMjhKR1QzTW1fVG9rZW46Ym94Y244UHJLWGp6b2NubEFKYjE5TVhNSFFjXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA) | TiDB字段值比较区分大小写 ![img](https://duodian.feishu.cn/space/api/box/stream/download/asynccode/?code=MGE4MGM1YzU1YmI5Y2U1NDdhN2JhMTFkMTI4MGZkNzNfR2pyYUNzVmdjNHR0WDVJV1d5STV3bUhCNGJLdnluVTNfVG9rZW46Ym94Y25Yamw5WmpJRWNmcjNZQ2Zzc2swZjhkXzE2NTE4ODkzNjA6MTY1MTg5Mjk2MF9WNA) |

### 9、不支持在单个DDL中对多个列或者多个索引做操作 

```SQL
alter table test_0701_value add char1 varchar(10),add char2 varchar(10);
ERROR 8200 (HY000): Unsupported multi schema change

alter table test_0701_value add index idx_char1(char1),add index idx_char2(char2);
ERROR 8200 (HY000): Unsupported multi schema change
```

### 10、尽量批量写入数据 

每次批量插入条数不超过200条，提升写入数据响应时间；tidb分布式DB存在两阶段提交增加了写入响应时间