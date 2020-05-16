---
title: Mybatis源码分析(三) SQL执行过程
date: 2019-10-26 17:12:23
author: kangshifu
img: 
top: false
cover: false
coverImg: 
password: 
toc: true
mathjax: false
summary: 
categories: Mybatis
tags:
  - Java 
  - Mybatis

---


<!--more-->  



## selectOne方法分析

```java
//DefaultSqlSession.java
 @Override
 public <T> T selectOne(String statement, Object parameter) {
    List<T> list = this.selectList(statement, parameter);
    if (list.size() == 1) {
      return list.get(0);
    } else if (list.size() > 1) {
      //如果查询结果大于1  跑出异常
      throw new TooManyResultsException("Expected one result (or null) to be returned by selectOne(), but found: " + list.size());
    } else {
      return null;
    }
  }


  @Override
  public <E> List<E> selectList(String statement, Object parameter) {
    return this.selectList(statement, parameter, RowBounds.DEFAULT);
  }


  @Override
  public <E> List<E> selectList(String statement, Object parameter, RowBounds rowBounds) {
    try {
      //MappedStatement表示的是XML中的一个SQL
      MappedStatement ms = configuration.getMappedStatement(statement);
      return executor.query(ms, wrapCollection(parameter), rowBounds, Executor.NO_RESULT_HANDLER);
    } catch (Exception e) {
      throw ExceptionFactory.wrapException("Error querying database.  Cause: " + e, e);
    } finally {
      ErrorContext.instance().reset();
    }
  }
```

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/mybatis/Executor%E7%B1%BB%E5%9B%BE.png)

这里executor 的类型为 CachingExecutor(DefaultSqlSessionFactory.openSession()) ，该类是一 个装饰器类，用于给目标 Executor 增加二级缓存功能。那目标 Executor 是谁呢？默认情况 下是SimpleExecutor。

```java
// CachingExecutor.java
 @Override
 public <E> List<E> query(MappedStatement ms, Object parameterObject, RowBounds rowBounds, ResultHandler resultHandler) throws SQLException {
    // 获取 BoundSql,后面分析 
    BoundSql boundSql = ms.getBoundSql(parameterObject);
    //创建CacheKey 
    CacheKey key = createCacheKey(ms, parameterObject, rowBounds, boundSql);
    return query(ms, parameterObject, rowBounds, resultHandler, key, boundSql);
  }


  @Override
  public <E> List<E> query(MappedStatement ms, Object parameterObject, RowBounds rowBounds, ResultHandler resultHandler, CacheKey key, BoundSql boundSql)
      throws SQLException {
    //从Mappedstatement中获取缓存,
    Cache cache = ms.getCache();
    //若映射文件中未配置缓存或参照缓存,此时cache=null,直接调用被装饰类的query  
    if (cache != null) {
      flushCacheIfRequired(ms);
      if (ms.isUseCache() && resultHandler == null) {
        ensureNoOutParams(ms, boundSql);
        @SuppressWarnings("unchecked")
        List<E> list = (List<E>) tcm.getObject(cache, key);
        if (list == null) {
          //若缓存未命中,则调用被装饰类的query方法
          list = delegate.query(ms, parameterObject, rowBounds, resultHandler, key, boundSql);
          tcm.putObject(cache, key, list); // issue #578 and #116
        }
        return list;
      }
    }
    
    return delegate.query(ms, parameterObject, rowBounds, resultHandler, key, boundSql);
  }
```

以上代码涉及到了二级缓存，若二级缓存为空，或未命中，则调用被装饰类的query方 法。下面来看一下BaseExecutor的中的query方法是如何实现的。 

```java
 //BaseExecutor.java
  @SuppressWarnings("unchecked")
  @Override
  public <E> List<E> query(MappedStatement ms, Object parameter, RowBounds rowBounds, ResultHandler resultHandler, CacheKey key, BoundSql boundSql) throws SQLException {
    ErrorContext.instance().resource(ms.getResource()).activity("executing a query").object(ms.getId());
    //  已经关闭，则抛出 ExecutorException 异常
    if (closed) {
      throw new ExecutorException("Executor was closed.");
    }
    //  清空本地缓存，如果 queryStack 为零，并且要求清空本地缓存。
    if (queryStack == 0 && ms.isFlushCacheRequired()) {
      clearLocalCache();
    }
    List<E> list;
    try {
      queryStack++;
      // 从一级缓存中获取缓存项
      list = resultHandler == null ? (List<E>) localCache.getObject(key) : null;
      if (list != null) {
        //存储过程相关逻辑
        handleLocallyCachedOutputParameters(ms, key, parameter, boundSql);
      } else {
        //一级缓存未命中,则从数据库中查询
        list = queryFromDatabase(ms, parameter, rowBounds, resultHandler, key, boundSql);
      }
    } finally {
      queryStack--;
    }
    if (queryStack == 0) {
      //从一级缓存中延迟加载嵌套查询结果
      for (DeferredLoad deferredLoad : deferredLoads) {
        deferredLoad.load();
      }
      deferredLoads.clear();
      if (configuration.getLocalCacheScope() == LocalCacheScope.STATEMENT) {
        clearLocalCache();
      }
    }
    return list;
  }

  private <E> List<E> queryFromDatabase(MappedStatement ms, Object parameter, RowBounds rowBounds, ResultHandler resultHandler, CacheKey key, BoundSql boundSql) throws SQLException {
    List<E> list;
    // 向缓存中存储一个占位符,此处的占位符，和延迟加载有关
    localCache.putObject(key, EXECUTION_PLACEHOLDER);
    try {
      list = doQuery(ms, parameter, rowBounds, resultHandler, boundSql);
    } finally {
      // 从缓存中，移除占位对象
      localCache.removeObject(key);
    }
    // 添加结果到缓存中
    localCache.putObject(key, list);
     //  存储过程相关  
    if (ms.getStatementType() == StatementType.CALLABLE) {
      localOutputParameterCache.putObject(key, parameter);
    }
    return list;
  }
```

```java
  //SimpleExecutor.java
  @Override
  public <E> List<E> doQuery(MappedStatement ms, Object parameter, RowBounds rowBounds, ResultHandler resultHandler, BoundSql boundSql) throws SQLException {
    Statement stmt = null;
    try {
      Configuration configuration = ms.getConfiguration();
      //创建StatementHandler
      StatementHandler handler = configuration.newStatementHandler(wrapper, ms, parameter, rowBounds, resultHandler, boundSql);
      //创建java.sql.Statement,执行SQL
      stmt = prepareStatement(handler, ms.getStatementLog());
      return handler.query(stmt, resultHandler);
    } finally {
      closeStatement(stmt);
    }
  }
```



```java
public class PreparedStatementHandler extends BaseStatementHandler {
  @Override
  public <E> List<E> query(Statement statement, ResultHandler resultHandler) throws SQLException {
    PreparedStatement ps = (PreparedStatement) statement;
    //执行SQL
    ps.execute();
    //处理返回结果
    return resultSetHandler.handleResultSets(ps);
  }
}
```

##  StatementHandler 

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/mybatis/statementHandler%E7%B1%BB%E5%9B%BE.png)

StatementHandler接口的实现大致有四个，其中三个实现类都是和JDBC中的Statement响对应的：

1. SimpleStatementHandler，这个就是对应我们JDBC中常用的Statement接口，用于简单SQL的处理；
2. PreparedStatementHandler，这个对应JDBC中的PreparedStatement，预编译SQL的接口；
3. CallableStatementHandler，这个对应JDBC中CallableStatement，用于执行存储过程相关的接口；
4. RoutingStatementHandler，这个接口是以上三个接口的路由，没有实际操作，只是负责上面三个StatementHandler的创建及调用。



### 创建

```java
 //Configuration.java
 public StatementHandler newStatementHandler(Executor executor, MappedStatement mappedStatement, Object parameterObject, RowBounds rowBounds, ResultHandler resultHandler, BoundSql boundSql) {
    //创建具有路由功能的StatementHandler
    StatementHandler statementHandler = new RoutingStatementHandler(executor, mappedStatement, parameterObject, rowBounds, resultHandler, boundSql);
    //应用插件到StatementHadnler上
    statementHandler = (StatementHandler) interceptorChain.pluginAll(statementHandler);
    return statementHandler;
  }
```

```java
  //RoutingStatementHandler.java
  private final StatementHandler delegate;

  public RoutingStatementHandler(Executor executor, MappedStatement ms, Object parameter, RowBounds rowBounds, ResultHandler resultHandler, BoundSql boundSql) {

    //根据StatmentType创建不同的StatementHandler
    switch (ms.getStatementType()) {
      case STATEMENT:
        delegate = new SimpleStatementHandler(executor, ms, parameter, rowBounds, resultHandler, boundSql);
        break;
      case PREPARED:
        delegate = new PreparedStatementHandler(executor, ms, parameter, rowBounds, resultHandler, boundSql);
        break;
      case CALLABLE:
        delegate = new CallableStatementHandler(executor, ms, parameter, rowBounds, resultHandler, boundSql);
        break;
      default:
        throw new ExecutorException("Unknown statement type: " + ms.getStatementType());
    }

  }
```

- 对于RoutingStatementHandler在整个StatementHandler接口层次中扮演的角色,有人觉得它是一个装饰器,有但它并没有提供功能上的扩展;有人觉得这里使用了策略模式;还有人认为他是一个静态代理类.----摘自mybait技术内幕

