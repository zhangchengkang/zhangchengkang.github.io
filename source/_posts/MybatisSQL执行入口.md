---
toc: true
title: Mybatis源码分析(二) SQL执行入口
date: 2019-10-20 15:54:12
tags: [Mybatis]
categories: JAVA

---

*one today is worth two tomorrows*
<!--more-->  



## MyBatis工作流程简述

### 使用sqlSession(旧)

````java
public static void main(String[] args) {
		InputStream inputStream = Resources.getResourceAsStream("mybatis-config.xml");
		SqlSessionFactory factory = new SqlSessionFactoryBuilder().build(inputStream);
		SqlSession sqlSession = factory.openSession();
		String name = "ksf";
        List<User> list = sqlSession.selectList("com.demo.mapper.UserMapper.queryById",params);
}
````

### 使用mapper(一般用这个)

```java
public static void main(String[] args) {
		//前三步都相同
		InputStream inputStream = Resources.getResourceAsStream("mybatis-config.xml");
		SqlSessionFactory factory = new SqlSessionFactoryBuilder().build(inputStream);
		SqlSession sqlSession = factory.openSession();
		//这里不再调用SqlSession 的api，而是获得了接口对象，调用接口中的方法。
		UserMapper mapper = sqlSession.getMapper(UserMapper.class);
		List<User> list = mapper.getUserByName("ksf");
}
```

#### 获取sqlsessionFactory

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E8%8E%B7%E5%8F%96SqlSessionFactory%E6%B5%81%E7%A8%8B%E5%9B%BE.jpg)

#### 获取sqlSession

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E8%8E%B7%E5%8F%96SqlSession%E6%B5%81%E7%A8%8B%E5%9B%BE.jpg)

#### 获取接口代理对象MapperProxy

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/%E8%8E%B7%E5%8F%96MapperProxy%E6%B5%81%E7%A8%8B%E5%9B%BE.jpg)

#### 执行增删改查

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/Mapper%E6%89%A7%E8%A1%8C%E5%A2%9E%E5%88%A0%E6%9F%A5%E6%94%B9.jpg)



## getMapper源码分析

```java
public class DefaultSqlSession implements SqlSession {
     private final Configuration configuration;
     private final Executor executor;

      @Override
      public <T> T getMapper(Class<T> type) {
        return configuration.getMapper(type, this);
      }
}
```

```java
public class Configuration {
      protected final MapperRegistry mapperRegistry = new MapperRegistry(this);

      public <T> T getMapper(Class<T> type, SqlSession sqlSession) {
        return mapperRegistry.getMapper(type, sqlSession);
      }
 }

```

```java
public class MapperRegistry {
    @SuppressWarnings("unchecked")
    public <T> T getMapper(Class<T> type, SqlSession sqlSession) {
        final MapperProxyFactory<T> mapperProxyFactory = (MapperProxyFactory<T>) knownMappers.get(type);
        if (mapperProxyFactory == null) {
            throw new BindingException("Type " + type + " is not known to the MapperRegistry.");
        }
        try {
            return mapperProxyFactory.newInstance(sqlSession);
        } catch (Exception e) {
            throw new BindingException("Error getting mapper instance. Cause: " + e, e);
        }
    }
}
```

```java
public class MapperProxyFactory<T> {
    public T newInstance(SqlSession sqlSession) {
        final MapperProxy<T> mapperProxy = new MapperProxy<>(sqlSession, mapperInterface, methodCache);
        return newInstance(mapperProxy);
  	}
    
    @SuppressWarnings("unchecked")
  	protected T newInstance(MapperProxy<T> mapperProxy) {
        //通过Proxy.newProxyInstance产生了一个Mapper的代理对象
    	return (T) Proxy.newProxyInstance(mapperInterface.getClassLoader(), new Class[] { mapperInterface }, mapperProxy);
  	}
}
```

```java
//代理模式中，代理类(MapperProxy)中才真正的完成了方法调用的逻辑。
public class MapperProxy<T> implements InvocationHandler, Serializable {
  @Override
  public Object invoke(Object proxy, Method method, Object[] args) throws Throwable {
    try {
      if (Object.class.equals(method.getDeclaringClass())) {
        return method.invoke(this, args);
      } else if (isDefaultMethod(method)) {
        return invokeDefaultMethod(proxy, method, args);
      }
    } catch (Throwable t) {
      throw ExceptionUtil.unwrapThrowable(t);
    }
    final MapperMethod mapperMethod = cachedMapperMethod(method);
    return mapperMethod.execute(sqlSession, args);
  }
    
  private MapperMethod cachedMapperMethod(Method method) {
    return methodCache.computeIfAbsent(method, k -> new MapperMethod(mapperInterface, method, sqlSession.getConfiguration()));
  }
}
```

```java
public class MapperMethod {
  private final SqlCommand command;
  private final MethodSignature method;
    
  public Object execute(SqlSession sqlSession, Object[] args) {
    Object result;
    switch (command.getType()) {
      case INSERT: {
        // 转换参数
        Object param = method.convertArgsToSqlCommandParam(args);
        result = rowCountResult(sqlSession.insert(command.getName(), param));
        break;
      }
      case UPDATE: {
        Object param = method.convertArgsToSqlCommandParam(args);
        result = rowCountResult(sqlSession.update(command.getName(), param));
        break;
      }
      case DELETE: {
        Object param = method.convertArgsToSqlCommandParam(args);
        result = rowCountResult(sqlSession.delete(command.getName(), param));
        break;
      }
      case SELECT:
        if (method.returnsVoid() && method.hasResultHandler()) {
          executeWithResultHandler(sqlSession, args);
          result = null;
        } else if (method.returnsMany()) {
          result = executeForMany(sqlSession, args);
        } else if (method.returnsMap()) {
          result = executeForMap(sqlSession, args);
        } else if (method.returnsCursor()) {
          result = executeForCursor(sqlSession, args);
        } else {
          Object param = method.convertArgsToSqlCommandParam(args);
          result = sqlSession.selectOne(command.getName(), param);
          if (method.returnsOptional()
              && (result == null || !method.getReturnType().equals(result.getClass()))) {
            result = Optional.ofNullable(result);
          }
        }
        break;
      case FLUSH:
        result = sqlSession.flushStatements();
        break;
      default:
        throw new BindingException("Unknown execution method for: " + command.getName());
    }
    if (result == null && method.getReturnType().isPrimitive() && !method.returnsVoid()) {
      throw new BindingException("Mapper method '" + command.getName()
          + " attempted to return null from a method with a primitive return type (" + method.getReturnType() + ").");
    }
    return result;
  }
  
  //所以mapper最后调的还是sqlSession的SelectList方法..
  private <E> Object executeForMany(SqlSession sqlSession, Object[] args) {
    List<E> result;
    Object param = method.convertArgsToSqlCommandParam(args);
    if (method.hasRowBounds()) {
      RowBounds rowBounds = method.extractRowBounds(args);
      result = sqlSession.selectList(command.getName(), param, rowBounds);
    } else {
      result = sqlSession.selectList(command.getName(), param);
    }
    // issue #510 Collections & arrays support
    if (!method.getReturnType().isAssignableFrom(result.getClass())) {
      if (method.getReturnType().isArray()) {
        return convertToArray(result);
      } else {
        return convertToDeclaredCollection(sqlSession.getConfiguration(), result);
      }
    }
    return result;
  }
}
```









