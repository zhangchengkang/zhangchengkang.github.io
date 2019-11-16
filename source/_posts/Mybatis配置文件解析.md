---
toc: true
title: Mybatis源码分析(一) 配置文件解析过程
date: 2019-10-19 16:12:35
tags: [Mybatis]
categories: JAVA


---

*There is only one me in this world*
<!--more-->  



## 概述

xml文件中的sql节点会在初始化时被解析成MappedStatement对象，其中的sql语句会被解析成SqlSource对象，动态Sql节点等由SqlNode接口的相应实现类进行表示

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/BaseBuilder%E7%B1%BB%E5%9B%BE.png)

- **XMLConfigBuilder**：解析mybatis中configLocation属性中的全局xml文件，内部会使用 XMLMapperBuilder 解析各个xml文件。
- **XMLMapperBuilder**：遍历mybatis中mapperLocations属性中的xml文件中每个节点的Builder，比如user.xml，内部会使用 XMLStatementBuilder 处理xml中的每个节点。
-  **XMLStatementBuilder**：解析xml文件中各个节点，比如`select,insert,update,delete`节点，内部会使用 XMLScriptBuilder 处理节点的sql部分，遍历产生的数据会丢到Configuration的mappedStatements中。。
-  **XMLScriptBuilder**：解析xml中各个节点sql部分的Builder

## XML解析入口

```java
public static void main(String[] args) {
    InputStream inputStream = Resources.getResourceAsStream("mybatis-config.xml");
    SqlSessionFactory factory = new SqlSessionFactoryBuilder().build(inputStream);//↓↓↓↓↓
    SqlSession sqlSession = factory.openSession();
    UserMapper mapper = sqlSession.getMapper(UserMapper.class);
    List<User> list = mapper.getUserByName("ksf");
}

```

SqlSessionFactory初始化的时候会执行XMLConfigBuilder的parse方法解析所有XML文件



```java
  //SqlSessionFactoryBuilder.java
  public SqlSessionFactory build(Reader reader) {
    return build(reader, null, null);
  }


  public SqlSessionFactory build(InputStream inputStream, String environment, Properties properties) {
    try {
      // 创建 XMLConfigBuilder 对象
      XMLConfigBuilder parser = new XMLConfigBuilder(inputStream, environment, properties);
      // 执行 XML 解析
      // 创建 DefaultSqlSessionFactory 对象
      return build(parser.parse());//↓↓↓↓↓
    } catch (Exception e) {
      throw ExceptionFactory.wrapException("Error building SqlSession.", e);
    } finally {
      ErrorContext.instance().reset();
      try {
        inputStream.close();
      } catch (IOException e) {
        // Intentionally ignore. Prefer previous error.
      }
    }
  }
```

## XMLConfigBuilder

解析XML配置文件

```java
  public Configuration parse() {
    if (parsed) {
      throw new BuilderException("Each XMLConfigBuilder can only be used once.");
    }
    parsed = true;
    parseConfiguration(parser.evalNode("/configuration"));//↓↓↓↓↓
    return configuration;
  }
```

```java
  private void parseConfiguration(XNode root) {
    try {
      //issue #117 read properties first
      // 解析 <properties /> 标签
      propertiesElement(root.evalNode("properties"));
      Properties settings = settingsAsProperties(root.evalNode("settings"));
      loadCustomVfs(settings);
      loadCustomLogImpl(settings);
      typeAliasesElement(root.evalNode("typeAliases"));
      pluginElement(root.evalNode("plugins"));
      objectFactoryElement(root.evalNode("objectFactory"));
      objectWrapperFactoryElement(root.evalNode("objectWrapperFactory"));
      reflectorFactoryElement(root.evalNode("reflectorFactory"));
      settingsElement(settings);
      // read it after objectFactory and objectWrapperFactory issue #631
      environmentsElement(root.evalNode("environments"));
      databaseIdProviderElement(root.evalNode("databaseIdProvider"));
      typeHandlerElement(root.evalNode("typeHandlers"));
      mapperElement(root.evalNode("mappers"));//↓↓↓↓↓
    } catch (Exception e) {
      throw new BuilderException("Error parsing SQL Mapper Configuration. Cause: " + e, e);
    }
  }
```

```java
  //解析 <mappers /> 标签
  private void mapperElement(XNode parent) throws Exception {
    if (parent != null) {
      //  遍历子节点
      for (XNode child : parent.getChildren()) {
        if ("package".equals(child.getName())) { //  如果是 package 标签，则扫描该包
          // 获得包名
          String mapperPackage = child.getStringAttribute("name");
          configuration.addMappers(mapperPackage);
        } else {// 如果是 mapper 标签，
          // 获得 resource、url、class 属性
          String resource = child.getStringAttribute("resource");
          String url = child.getStringAttribute("url");
          String mapperClass = child.getStringAttribute("class");
          if (resource != null && url == null && mapperClass == null) { //  使用相对于类路径的资源引用
            ErrorContext.instance().resource(resource);
            InputStream inputStream = Resources.getResourceAsStream(resource);
            XMLMapperBuilder mapperParser = new XMLMapperBuilder(inputStream, configuration, resource, configuration.getSqlFragments());
            // 调用XMLMapperBuilder解析mapper对应的XML
            mapperParser.parse();//↓↓↓↓↓
          } else if (resource == null && url != null && mapperClass == null) { //  使用完全限定资源定位符（URL）
            ErrorContext.instance().resource(url);
            InputStream inputStream = Resources.getUrlAsStream(url);
            XMLMapperBuilder mapperParser = new XMLMapperBuilder(inputStream, configuration, url, configuration.getSqlFragments());
            mapperParser.parse();
          } else if (resource == null && url == null && mapperClass != null) { //  使用映射器接口实现类的完全限定类名
            Class<?> mapperInterface = Resources.classForName(mapperClass);
            configuration.addMapper(mapperInterface);
          } else {
            throw new BuilderException("A mapper element may only specify a url, resource or class, but not more than one.");
          }
        }
      }
    }
  }
```

## XMLMapperBuilder

解析XML映射文件

```java
  public void parse() {
    // <1> 判断当前 Mapper 是否已经加载过
    if (!configuration.isResourceLoaded(resource)) {
      // <2> 解析 `<mapper />` 节点
      configurationElement(parser.evalNode("/mapper"));//↓↓↓↓↓
      // <3> 标记该 Mapper 已经加载过
      configuration.addLoadedResource(resource);
      // <4> 绑定 Mapper
      bindMapperForNamespace();
    }

    // <5> 解析待定的 <resultMap /> 节点
    parsePendingResultMaps();
    // <6> 解析待定的 <cache-ref /> 节点
    parsePendingCacheRefs();
    // <7> 解析待定的 SQL 语句的节点
    parsePendingStatements();
  }
```

```java
  //解析 <mapper /> 节点
  private void configurationElement(XNode context) {
    try {
      // <1> 获得 namespace 属性
      String namespace = context.getStringAttribute("namespace");
      if (namespace == null || namespace.equals("")) {
        throw new BuilderException("Mapper's namespace cannot be empty");
      }
      // <1> 设置 namespace 属性
      builderAssistant.setCurrentNamespace(namespace);
      cacheRefElement(context.evalNode("cache-ref"));
      cacheElement(context.evalNode("cache"));
      parameterMapElement(context.evalNodes("/mapper/parameterMap"));
      resultMapElements(context.evalNodes("/mapper/resultMap"));
      sqlElement(context.evalNodes("/mapper/sql"));
      buildStatementFromContext(context.evalNodes("select|insert|update|delete"));//↓↓↓↓↓
    } catch (Exception e) {
      throw new BuilderException("Error parsing Mapper XML. The XML location is '" + resource + "'. Cause: " + e, e);
    }
  }
```

```java
  private void buildStatementFromContext(List<XNode> list) {
    if (configuration.getDatabaseId() != null) {
      buildStatementFromContext(list, configuration.getDatabaseId());
    }
    buildStatementFromContext(list, null);//↓↓↓↓↓
  }
```

```java
  private void buildStatementFromContext(List<XNode> list, String requiredDatabaseId) {
    // <1> 遍历 <select /> <insert /> <update /> <delete /> 节点们
    for (XNode context : list) {
      // <1> 创建 XMLStatementBuilder 对象，执行解析
      final XMLStatementBuilder statementParser = new XMLStatementBuilder(configuration, builderAssistant, context, requiredDatabaseId);
      try {
        statementParser.parseStatementNode();//↓↓↓↓↓
      } catch (IncompleteElementException e) {
        configuration.addIncompleteStatement(statementParser);
      }
    }
  }
```

## XMLStatementBuilder

解析XML select|insert|update|delete 节点

```java
  public void parseStatementNode() {
    // <1> 获得 id 属性，编号。
    String id = context.getStringAttribute("id");

    // <2> 获得 databaseId ， 判断 databaseId 是否匹配
    String databaseId = context.getStringAttribute("databaseId");

    if (!databaseIdMatchesCurrent(id, databaseId, this.requiredDatabaseId)) {
      return;
    }

    // <3> 获得各种属性
    String nodeName = context.getNode().getNodeName();
    SqlCommandType sqlCommandType = SqlCommandType.valueOf(nodeName.toUpperCase(Locale.ENGLISH));
    boolean isSelect = sqlCommandType == SqlCommandType.SELECT;
    boolean flushCache = context.getBooleanAttribute("flushCache", !isSelect);
    boolean useCache = context.getBooleanAttribute("useCache", isSelect);
    boolean resultOrdered = context.getBooleanAttribute("resultOrdered", false);

    // Include Fragments before parsing
    XMLIncludeTransformer includeParser = new XMLIncludeTransformer(configuration, builderAssistant);
    includeParser.applyIncludes(context.getNode());

    String parameterType = context.getStringAttribute("parameterType");
    Class<?> parameterTypeClass = resolveClass(parameterType);

    String lang = context.getStringAttribute("lang");
    //使用LanguageDriver进行解析SQL
    LanguageDriver langDriver = getLanguageDriver(lang);

    // Parse selectKey after includes and remove them.
    processSelectKeyNodes(id, parameterTypeClass, langDriver);

    // Parse the SQL (pre: <selectKey> and <include> were parsed and removed)
    KeyGenerator keyGenerator;
    String keyStatementId = id + SelectKeyGenerator.SELECT_KEY_SUFFIX;
    keyStatementId = builderAssistant.applyCurrentNamespace(keyStatementId, true);
    if (configuration.hasKeyGenerator(keyStatementId)) {
      keyGenerator = configuration.getKeyGenerator(keyStatementId);
    } else {
      keyGenerator = context.getBooleanAttribute("useGeneratedKeys",
          configuration.isUseGeneratedKeys() && SqlCommandType.INSERT.equals(sqlCommandType))
          ? Jdbc3KeyGenerator.INSTANCE : NoKeyGenerator.INSTANCE;
    }

    // 创建SqlSource
    SqlSource sqlSource = langDriver.createSqlSource(configuration, context, parameterTypeClass);//↓↓↓↓↓
    //获取各种属性
    StatementType statementType = StatementType.valueOf(context.getStringAttribute("statementType", StatementType.PREPARED.toString()));
    Integer fetchSize = context.getIntAttribute("fetchSize");
    Integer timeout = context.getIntAttribute("timeout");
    String parameterMap = context.getStringAttribute("parameterMap");
    String resultType = context.getStringAttribute("resultType");
    Class<?> resultTypeClass = resolveClass(resultType);
    String resultMap = context.getStringAttribute("resultMap");
    String resultSetType = context.getStringAttribute("resultSetType");
    ResultSetType resultSetTypeEnum = resolveResultSetType(resultSetType);
    String keyProperty = context.getStringAttribute("keyProperty");
    String keyColumn = context.getStringAttribute("keyColumn");
    String resultSets = context.getStringAttribute("resultSets");
    //创建MappedStatement,包含了节点的一堆信息
    builderAssistant.addMappedStatement(id, sqlSource, statementType, sqlCommandType,
        fetchSize, timeout, parameterMap, parameterTypeClass, resultMap, resultTypeClass,
        resultSetTypeEnum, flushCache, useCache, resultOrdered,
        keyGenerator, keyProperty, keyColumn, databaseId, langDriver, resultSets);
  }
```

```java
//XMLLanguageDriver.java
  @Override
  public SqlSource createSqlSource(Configuration configuration, XNode script, Class<?> parameterType) {
    // 创建 XMLScriptBuilder 对象，执行解析
    XMLScriptBuilder builder = new XMLScriptBuilder(configuration, script, parameterType);
    return builder.parseScriptNode();//↓↓↓↓↓
  }
```

## XMLScriptBuilder

解析每个节点的SQL部分

```java
  /**
   * 负责将 SQL 解析成 SqlSource 对象。
   */
  public SqlSource parseScriptNode() {
    //  解析 SQL,创建包含很多动态Sql节点(SQLNode)的对象
    MixedSqlNode rootSqlNode = parseDynamicTags(context);//↓↓↓↓↓
    //  创建 SqlSource 对象 
    SqlSource sqlSource;
    if (isDynamic) {
      //动态SQL持有MixedSqlNode对象  后面解析用
      sqlSource = new DynamicSqlSource(configuration, rootSqlNode);
    } else {
      //静态SQL直接在这一步就解析了SQL
      sqlSource = new RawSqlSource(configuration, rootSqlNode, parameterType);
    }
    return sqlSource;
  }
```

```java
  protected MixedSqlNode parseDynamicTags(XNode node) {
    //创建 SqlNode 数组
    List<SqlNode> contents = new ArrayList<>();
    // 遍历 SQL 节点的所有子节点
    NodeList children = node.getNode().getChildNodes();
    for (int i = 0; i < children.getLength(); i++) {
      XNode child = node.newXNode(children.item(i));
      if (child.getNode().getNodeType() == Node.CDATA_SECTION_NODE || child.getNode().getNodeType() == Node.TEXT_NODE) {
        String data = child.getStringBody("");
        //创建 TextSqlNode 对象
        TextSqlNode textSqlNode = new TextSqlNode(data);
        // 如果是动态的 TextSqlNode 对象
        if (textSqlNode.isDynamic()) {
          // 添加到 contents 中
          contents.add(textSqlNode);
          // 标记为动态 SQL
          isDynamic = true;
        } else {
          //创建 StaticTextSqlNode 添加到 contents 中
          contents.add(new StaticTextSqlNode(data));
        }
      } else if (child.getNode().getNodeType() == Node.ELEMENT_NODE) {
        //根据子节点的标签，获得对应的 NodeHandler 对象
        String nodeName = child.getNode().getNodeName();
        NodeHandler handler = nodeHandlerMap.get(nodeName);
        if (handler == null) {
          throw new BuilderException("Unknown element <" + nodeName + "> in SQL statement.");
        }
        //执行 NodeHandler 处理
        handler.handleNode(child, contents);
        isDynamic = true;
      }
    }
    return new MixedSqlNode(contents);
  }
```

##  Mapper接口绑定

映射文件解析完成后，并不意味着整个解析过程就结束了。此时还需要通过命名空间绑 定 mapper 接口，这样才能将映射文件中的 SQL 语句和 mapper 接口中的方法绑定在一起， 后续可直接通过调用 mapper 接口方法执行与之对应的 SQL 语句

让我们来到XMLMapperBuilder解析mapper之后

```java
  //XMLMapperBuilder.java
  public void parse() {
    // <1> 判断当前 Mapper 是否已经加载过
    if (!configuration.isResourceLoaded(resource)) {
      // <2> 解析 `<mapper />` 节点
      configurationElement(parser.evalNode("/mapper"));
      // <3> 标记该 Mapper 已经加载过
      configuration.addLoadedResource(resource);
      // <4> 绑定 Mapper
      bindMapperForNamespace();//↓↓↓↓↓
    }

    // <5> 解析待定的 <resultMap /> 节点
    parsePendingResultMaps();
    // <6> 解析待定的 <cache-ref /> 节点
    parsePendingCacheRefs();
    // <7> 解析待定的 SQL 语句的节点
    parsePendingStatements();
  }

```

```java
  //XMLMapperBuilder.java
  private void bindMapperForNamespace() {
    //获取映射文件的命名空间 namespace 。
    String namespace = builderAssistant.getCurrentNamespace();
    if (namespace != null) {
      Class<?> boundType = null;
      try {
        //根据命名空间解析mapper类型
        boundType = Resources.classForName(namespace);
      } catch (ClassNotFoundException e) {
        //ignore, bound type is not required
      }
      if (boundType != null) {
        // 不存在该 Mapper 接口，则进行添加
        if (!configuration.hasMapper(boundType)) {
          // 标记 namespace 已经添加，避免 重复加载
          configuration.addLoadedResource("namespace:" + namespace);
          // 绑定mapper
          configuration.addMapper(boundType);//↓↓↓↓↓
        }
      }
    }
  }
```

```java
public class Configuration {
    protected final MapperRegistry mapperRegistry = new MapperRegistry(this);
        
	public <T> void addMapper(Class<T> type) {
    	mapperRegistry.addMapper(type);//↓↓↓↓↓
  	}
 }
```

```java
    //MapperRegistry.java
    public <T> void addMapper(Class<T> type) {
        // 判断，必须是接口。
        if (type.isInterface()) {
            // 已经添加过，则抛出 BindingException 异常
            if (hasMapper(type)) {
                throw new BindingException("Type " + type + " is already known to the MapperRegistry.");
            }
            boolean loadCompleted = false;
            try {
                // 添加到 knownMappers 中
                // 对应文章开头sqlSession.getMapper(),mapper就是在这里放进去的
                knownMappers.put(type, new MapperProxyFactory<>(type));
                MapperAnnotationBuilder parser = new MapperAnnotationBuilder(config, type);
                parser.parse();
                // 标记加载完成
                loadCompleted = true;
            } finally {
                /// 若加载未完成，从 knownMappers 中移除
                if (!loadCompleted) {
                    knownMappers.remove(type);
                }
            }
        }
    }
```

