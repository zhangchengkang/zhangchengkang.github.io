---
title: sahrding-JDBC分片策略及算法
author: kangshifu
top: false
cover: false
toc: true
mathjax: false
categories: ShardingSphere
tags:
  - Java
  - ShardingSphere
abbrlink: 2632020453
date: 2019-10-01 16:03:16
img:
coverImg:
password:
summary:
---



<!--more-->  



## 分片策略

### StandardShardingStrategy

标准分片策略。提供对SQL语句中的=, IN和BETWEEN AND的分片操作支持。

StandardShardingStrategy只支持单分片键，提供PreciseShardingAlgorithm和RangeShardingAlgorithm两个分片算法。

* PreciseShardingAlgorithm是必选的，用于处理=和IN的分片。
* RangeShardingAlgorithm是可选的，用于处理BETWEEN AND分片，如果不配置RangeShardingAlgorithm，SQL中的BETWEEN AND将按照全库路由处理。



### ComplexShardingStrategy

复合分片策略。提供对SQL语句中的=, IN和BETWEEN AND的分片操作支持。

ComplexShardingStrategy支持多分片键，由于多分片键之间的关系复杂，因此Sharding-JDBC并未做过多的封装，而是直接将分片键值组合以及分片操作符交于算法接口，完全由应用开发者实现，提供最大的灵活度。



### InlineShardingStrategy

Inline表达式分片策略。使用Groovy的Inline表达式，提供对SQL语句中的=和IN的分片操作支持。

InlineShardingStrategy只支持单分片键，对于简单的分片算法，可以通过简单的配置使用，从而避免繁琐的Java代码开发，如: t*user*${user_id % 8} 表示t_user表按照user_id按8取模分成8个表，表名称为t_user_0到t_user_7。



### HintShardingStrategy

通过Hint而非SQL解析的方式分片的策略。



### NoneShardingStrategy

不分片的策略。



## 自定义分片算法

Sharding提供了以下4种算法接口：

* PreciseShardingAlgorithm
* RangeShardingAlgorithm
* HintShardingAlgorithm
* ComplexKeysShardingAlgorithm



### PreciseShardingAlgorithm

```java
 	@Bean(name = "shardingDataSource")
    @Qualifier("shardingDataSource")
    public DataSource shardingDataSource() throws SQLException {
        // 配置真实数据源
        Map<String, DataSource> dataSourceMap = new HashMap<>();

        // 配置第一个数据源
        BasicDataSource dataSource1 = new BasicDataSource();
        dataSource1.setDriverClassName("com.mysql.jdbc.Driver");
        dataSource1.setUrl("jdbc:mysql://localhost:3306/sharding_0");
        dataSource1.setUsername("root");
        dataSource1.setPassword("");
        dataSourceMap.put("sharding_0", dataSource1);

        // 配置第二个数据源
        BasicDataSource dataSource2 = new BasicDataSource();
        dataSource2.setDriverClassName("com.mysql.jdbc.Driver");
        dataSource2.setUrl("jdbc:mysql://localhost:3306/sharding_1");
        dataSource2.setUsername("root");
        dataSource2.setPassword("");
        dataSourceMap.put("sharding_1", dataSource2);

        // 配置Order表规则
        TableRuleConfiguration orderTableRuleConfig = new TableRuleConfiguration();
        orderTableRuleConfig.setLogicTable("t_order");
        orderTableRuleConfig.setKeyGeneratorColumnName("id");
        orderTableRuleConfig.setActualDataNodes("sharding_${0..1}.t_order${0..1}");

        // 配置分库 + 分表策略
        // 自定义的分片算法实现
        StandardShardingStrategyConfiguration standardStrategy = new StandardShardingStrategyConfiguration("order_id",new MyPreciseShardingAlgorithm());
        orderItemTableRuleConfig.setTableShardingStrategyConfig(standardStrategy);

        ShardingRuleConfiguration shardingRuleConfig = new ShardingRuleConfiguration();
        //分布式数据库主键id生成策略，保证不同库主键id不同
        shardingRuleConfig.setDefaultKeyGenerator(new DefaultKeyGenerator());
        // 配置分片规则
        shardingRuleConfig.getTableRuleConfigs().add(orderTableRuleConfig);

        // 获取数据源对象
        DataSource dataSource = null;
        try {
            dataSource = ShardingDataSourceFactory.createDataSource(dataSourceMap, shardingRuleConfig, new ConcurrentHashMap<>(), new Properties());
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return dataSource;
    }

}
```

自定义的PreciseShardingAlgorithm分片算法，继承PreciseShardingAlgorithm<Long>接口:

```java
public class MyPreciseShardingAlgorithm implements PreciseShardingAlgorithm<Long> {
    @Override
    public String doSharding(Collection<String> collection, PreciseShardingValue<Long> preciseShardingValue) {
        for (String name : collection) {
            if (name.endsWith(preciseShardingValue.getValue() % collection.size() + "")){
                return name;
            }
        }
        return null;
    }
}
```



### RangeShardingAlgorithm

```java
		// 配置分库 + 分表策略
        // 自定义的分片算法实现
        orderTableRuleConfig.setTableShardingStrategyConfig(new StandardShardingStrategyConfiguration("order_id", new MyPreciseShardingAlgorithm()));
```

```java
public class MyRangeShardingAlgorithm implements RangeShardingAlgorithm<Long> {
    @Override
    public Collection<String> doSharding(Collection<String> collection, RangeShardingValue<Long> rangeShardingValue) {
        Collection<String> collect = new ArrayList<>();
        Range<Long> valueRange = rangeShardingValue.getValueRange();
        for (Long i = valueRange.lowerEndpoint(); i <= valueRange.upperEndpoint(); i++) {
            for (String each : collection) {
                if (each.endsWith(i % collection.size() + "")) {
                    collect.add(each);
                }
            }
        }
        return collect;
    }
}
```

### HintShardingAlgorithm

```java
/**分库采用单片键 order_id*/
tableRuleConfig.setDatabaseShardingStrategyConfig(new InlineShardingStrategyConfiguration("order_id", "sharding_${order_id % 2}"));
/**分表采用单片键 uid*/
tableRuleConfig.setTableShardingStrategyConfig(new InlineShardingStrategyConfiguration("uid", "t_order_${uid % 2}"));
```





### ComplexShardingStrategy

```java
// 配置Order表规则
        TableRuleConfiguration orderTableRuleConfig = new TableRuleConfiguration();
        orderTableRuleConfig.setLogicTable("t_order");
		orderTableRuleConfig.setKeyGeneratorColumnName("id");
        orderTableRuleConfig.setActualDataNodes("sharding_${0..1}.t_order_${0..1}_${0..1}");

        // 配置分库 + 分表策略
        // 自定义的分片算法实现
         /**分库采用单片键 order_id*/
        orderTableRuleConfig.setDatabaseShardingStrategyConfig(new StandardShardingStrategyConfiguration("order_id", new MyPreciseShardingAlgorithm()));
        /**分表采用双片键 order_id,uid*/
        orderTableRuleConfig.setTableShardingStrategyConfig(new ComplexShardingStrategyConfiguration("order_id,uid", new MyComplexShardingAlgorithm()));

```

```java
public class MyComplexShardingAlgorithm implements ComplexKeysShardingAlgorithm {

    @Override
    public Collection<String> doSharding(Collection<String> collection, Collection<ShardingValue> shardingValues) {
        Collection<Long> uidValues = getShardingValue(shardingValues, "order_id");
        Collection<Long> idValues = getShardingValue(shardingValues, "uid");
        List<String> shardingSuffix = new ArrayList<>();
        /**例如：source_uid + source_id 双分片键来进行分表*/
        for (Long idVal : idValues) {
            for (Long uidVal : uidValues) {
                String suffix = idVal % 2 + "_" + uidVal % 2;
                collection.forEach(x -> {
                    if (x.endsWith(suffix)) {
                        shardingSuffix.add(x);
                    }
                });
            }
        }

        return shardingSuffix;
    }

    private Collection<Long> getShardingValue(Collection<ShardingValue> shardingValues, final String key) {
        Collection<Long> valueSet = new ArrayList<>();
        Iterator<ShardingValue> iterator = shardingValues.iterator();
        while (iterator.hasNext()) {
            ShardingValue next = iterator.next();
            if (next instanceof ListShardingValue) {
                ListShardingValue value = (ListShardingValue) next;
                if (value.getColumnName().equals(key)) {
                    return value.getValues();
                }
            }
        }
        return valueSet;
    }
}
```



更多内容，请挪步[官方文档](https://shardingsphere.apache.org/)