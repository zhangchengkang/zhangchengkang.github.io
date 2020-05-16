---


title: Spring源码分析(一) Beanfactory初始化
date: 2019-11-03 18:22:31
author: kangshifu
img: 
top: false
cover: true
coverImg: 
password: 
toc: true
mathjax: false
summary: 
categories: Spring
tags:
  - Java 
  - Spring

---


<!--more-->  



## 两张图

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/spring/spring%E5%AD%A6%E4%B9%A0%E6%80%9D%E8%B7%AF.png)

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/spring/spring%E6%80%9D%E7%BB%B4%E5%AF%BC%E5%9B%BE.png)

## Spring入口

```java
//1. 创建 Spring 的 IOC 容器
ApplicationContext context = new ClassPathXmlApplicationContext("applicationContext.xml");//↓↓↓↓↓

//2. 从 IOC 容器中获取 bean 的实例
 User user = context.getBean("User");
```

## Beanfactory初始化

```java
	//ClassPathXmlApplicationContext.java
	public ClassPathXmlApplicationContext(String configLocation) throws BeansException {
		this(new String[] {configLocation}, true, null);//↓↓↓↓↓
	}

    /**
     * 
     * @param configLocations Spring的xml配置文件
     * @param refresh 是否需要刷新，决定了是否进行bean解析、注册及实例化
     * @param parent 父ApplicationContext
     * @throws BeansException
     */
	public ClassPathXmlApplicationContext(
			String[] configLocations, boolean refresh, @Nullable ApplicationContext parent)
			throws BeansException {

		super(parent);
		setConfigLocations(configLocations);
		if (refresh) {
			refresh();//↓↓↓↓↓
		}
	}
```

```java
	//AbstractApplicationContext.java
	public void refresh() throws BeansException, IllegalStateException {
		synchronized (this.startupShutdownMonitor) {
			// 容器预先准备，记录容器启动时间和标记
			prepareRefresh();

			// 获取Beanfactory，并且初始化Beanfactory内容，包括了定位、加载和注册过程
			ConfigurableListableBeanFactory beanFactory = obtainFreshBeanFactory();

			// 为BeanFactory配置某些使用到的工具类，类加载器、事件处理器等
			prepareBeanFactory(beanFactory);

			try {
				// 为容器的某些子类指定特殊的BeanPost事件处理器
				postProcessBeanFactory(beanFactory);

				// 调用所有注册的BeanFactoryPostProcessor的postProcessBeanFactory方法
				invokeBeanFactoryPostProcessors(beanFactory);

				// 注册BeanPostProcessor的实例bean到Beanfactory，在实例化Bean时会调用BeanPostProcessor的两个方法
				registerBeanPostProcessors(beanFactory);

				//初始化信息源
				initMessageSource();

				 // 初始化容器事件广播器
				initApplicationEventMulticaster();

				//调用子类的某些特殊Bean初始化方法
				onRefresh();

				 // 注册监听器
				registerListeners();

				//根据Beandefinition实例化所有非延时加载的Bean
				finishBeanFactoryInitialization(beanFactory);

				// 并发布容器的生命周期事件
				finishRefresh();
			}

			catch (BeansException ex) {
				if (logger.isWarnEnabled()) {
					logger.warn("Exception encountered during context initialization - " +
							"cancelling refresh attempt: " + ex);
				}

				// Destroy already created singletons to avoid dangling resources.
				destroyBeans();

				// Reset 'active' flag.
				cancelRefresh(ex);

				// Propagate exception to caller.
				throw ex;
			}

			finally {
				// Reset common introspection caches in Spring's core, since we
				// might not ever need metadata for singleton beans anymore...
				resetCommonCaches();
			}
		}
	}
```

## ## 定位

```java
	//AbstractApplicationContext.java
	protected ConfigurableListableBeanFactory obtainFreshBeanFactory() {
		refreshBeanFactory();//↓↓↓↓↓
		return getBeanFactory();
	}
```

```java
	//AbstractRefreshableApplicationContext.java
	protected final void refreshBeanFactory() throws BeansException {
		if (hasBeanFactory()) {
            //如果已经存在了Beanfactory，就销毁已经存在的Beanfactory
			destroyBeans();
			closeBeanFactory();
		}
		try {
            //新建一个Beanfactory
			DefaultListableBeanFactory beanFactory = createBeanFactory();
			beanFactory.setSerializationId(getId());
			customizeBeanFactory(beanFactory);
            //定位、加载、注册BeanDefinition
			loadBeanDefinitions(beanFactory);//↓↓↓↓↓
			synchronized (this.beanFactoryMonitor) {
				this.beanFactory = beanFactory;
			}
		}
		catch (IOException ex) {
			throw new ApplicationContextException("I/O error parsing bean definition source for " + getDisplayName(), ex);
		}
	}
```

```java
//AbstractXmlApplicationContext.java
//我们的例子是基于xml配置的，因此使用AbstractXmlApplicationContext进行loadBeanDefinitions
//假如我们是使用注解配置，那么就是使用AnnotationConfigWebApplicationContext#loadBeanDefinitions的操作了
	protected void loadBeanDefinitions(DefaultListableBeanFactory beanFactory) throws BeansException, IOException {
		// xml配置为例，新建解析配置文件的解析器
		XmlBeanDefinitionReader beanDefinitionReader = new XmlBeanDefinitionReader(beanFactory);

		//设置解析器的必要信息
		beanDefinitionReader.setEnvironment(this.getEnvironment());
		beanDefinitionReader.setResourceLoader(this);
		beanDefinitionReader.setEntityResolver(new ResourceEntityResolver(this));

		initBeanDefinitionReader(beanDefinitionReader);
        //使用解析器进行加载、然后进行注册
		loadBeanDefinitions(beanDefinitionReader);//↓↓↓↓↓
	}

	protected void loadBeanDefinitions(XmlBeanDefinitionReader reader) throws BeansException, IOException {
        //获取一开始配置的资源信息
		Resource[] configResources = getConfigResources();
		if (configResources != null) {
            //根据资源路径最终定位，到此定位可以认定完成，接下来是根据配置进行加载
			reader.loadBeanDefinitions(configResources);
		}
		String[] configLocations = getConfigLocations();
		if (configLocations != null) {
			reader.loadBeanDefinitions(configLocations);//↓↓↓↓↓
		}
	}
```

## 加载

```java
	//XmlBeanDefinitionReader.java
	public int loadBeanDefinitions(EncodedResource encodedResource) throws BeanDefinitionStoreException {
		Assert.notNull(encodedResource, "EncodedResource must not be null");
		if (logger.isTraceEnabled()) {
			logger.trace("Loading XML bean definitions from " + encodedResource);
		}

		Set<EncodedResource> currentResources = this.resourcesCurrentlyBeingLoaded.get();
		if (currentResources == null) {
			currentResources = new HashSet<>(4);
			this.resourcesCurrentlyBeingLoaded.set(currentResources);
		}
		if (!currentResources.add(encodedResource)) {
			throw new BeanDefinitionStoreException(
					"Detected cyclic loading of " + encodedResource + " - check your import definitions!");
		}
		try {
			// 将资源文件转为 InputStream 的 IO 流
			InputStream inputStream = encodedResource.getResource().getInputStream();
			try {
				// 从 InputStream 中得到 XML 的解析源
				InputSource inputSource = new InputSource(inputStream);
				if (encodedResource.getEncoding() != null) {
					inputSource.setEncoding(encodedResource.getEncoding());
				}
				// ... 具体的读取过程
				return doLoadBeanDefinitions(inputSource, encodedResource.getResource());//↓↓↓↓↓
			}
			finally {
				inputStream.close();
			}
		}
		catch (IOException ex) {
			throw new BeanDefinitionStoreException(
					"IOException parsing XML document from " + encodedResource.getResource(), ex);
		}
		finally {
			currentResources.remove(encodedResource);
			if (currentResources.isEmpty()) {
				this.resourcesCurrentlyBeingLoaded.remove();
			}
		}
	}
```

```java
	//XmlBeanDefinitionReader.java
	protected int doLoadBeanDefinitions(InputSource inputSource, Resource resource)
			throws BeanDefinitionStoreException {

		try {
			// 获取 XML Document 实例
			Document doc = doLoadDocument(inputSource, resource);
			// 根据 Document 实例，注册 Bean 信息
			int count = registerBeanDefinitions(doc, resource);//↓↓↓↓↓
			if (logger.isDebugEnabled()) {
				logger.debug("Loaded " + count + " bean definitions from " + resource);
			}
			return count;
		}
		catch (BeanDefinitionStoreException ex) {
			throw ex;
		}
		catch (SAXParseException ex) {
			throw new XmlBeanDefinitionStoreException(resource.getDescription(),
					"Line " + ex.getLineNumber() + " in XML document from " + resource + " is invalid", ex);
		}
		catch (SAXException ex) {
			throw new XmlBeanDefinitionStoreException(resource.getDescription(),
					"XML document from " + resource + " is invalid", ex);
		}
		catch (ParserConfigurationException ex) {
			throw new BeanDefinitionStoreException(resource.getDescription(),
					"Parser configuration exception parsing XML from " + resource, ex);
		}
		catch (IOException ex) {
			throw new BeanDefinitionStoreException(resource.getDescription(),
					"IOException parsing XML document from " + resource, ex);
		}
		catch (Throwable ex) {
			throw new BeanDefinitionStoreException(resource.getDescription(),
					"Unexpected exception parsing XML document from " + resource, ex);
		}
	}
```

```java
	//XmlBeanDefinitionReader.java
	public int registerBeanDefinitions(Document doc, Resource resource) throws BeanDefinitionStoreException {
		// 创建 BeanDefinitionDocumentReader 对象
		BeanDefinitionDocumentReader documentReader = createBeanDefinitionDocumentReader();
		// 获取已注册的 BeanDefinition 数量
		int countBefore = getRegistry().getBeanDefinitionCount();
		// 创建 XmlReaderContext 对象
		// 注册 BeanDefinition
		documentReader.registerBeanDefinitions(doc, createReaderContext(resource));//↓↓↓↓↓
		// 计算新注册的 BeanDefinition 数量
		return getRegistry().getBeanDefinitionCount() - countBefore;
	}
```

## 注册

```java
	//DefaultBeanDefinitionDocumentReader.java
	protected void doRegisterBeanDefinitions(Element root) {
		BeanDefinitionParserDelegate parent = this.delegate;
		this.delegate = createDelegate(getReaderContext(), root, parent);

		if (this.delegate.isDefaultNamespace(root)) {
			String profileSpec = root.getAttribute(PROFILE_ATTRIBUTE);
			if (StringUtils.hasText(profileSpec)) {
				String[] specifiedProfiles = StringUtils.tokenizeToStringArray(
						profileSpec, BeanDefinitionParserDelegate.MULTI_VALUE_ATTRIBUTE_DELIMITERS);
				// We cannot use Profiles.of(...) since profile expressions are not supported
				// in XML config. See SPR-12458 for details.
				if (!getReaderContext().getEnvironment().acceptsProfiles(specifiedProfiles)) {
					if (logger.isDebugEnabled()) {
						logger.debug("Skipped XML bean definition file due to specified profiles [" + profileSpec +
								"] not matching: " + getReaderContext().getResource());
					}
					return;
				}
			}
		}

	    //开始解析xml前预处理，目前默认实现无处理
		preProcessXml(root);
		//根据root节点解析xml，this.delegate是BeanDefinitionParserDelegate，最终实现解析操作的类
		parseBeanDefinitions(root, this.delegate);//↓↓↓↓↓
		//解析后置xml前预处理，目前默认实现无处理
		postProcessXml(root);

		this.delegate = parent;
	}
```

```java
	//DefaultBeanDefinitionDocumentReader.java
	protected void parseBeanDefinitions(Element root, BeanDefinitionParserDelegate delegate) {
		// 如果根节点使用默认命名空间，执行默认解析
		if (delegate.isDefaultNamespace(root)) {
			// 遍历子节点
			NodeList nl = root.getChildNodes();
			for (int i = 0; i < nl.getLength(); i++) {
				Node node = nl.item(i);
				if (node instanceof Element) {
					Element ele = (Element) node;
					// 如果该节点使用默认命名空间，执行默认解析
					if (delegate.isDefaultNamespace(ele)) {
						parseDefaultElement(ele, delegate);//↓↓↓↓↓
					}
					// 如果该节点非默认命名空间，执行自定义解析
					else {
						delegate.parseCustomElement(ele);
					}
				}
			}
		}
		else {
			delegate.parseCustomElement(root);
		}
	}
```

```java
	//DefaultBeanDefinitionDocumentReader.java
	private void parseDefaultElement(Element ele, BeanDefinitionParserDelegate delegate) {
        // import标签解析
		if (delegate.nodeNameEquals(ele, IMPORT_ELEMENT)) {
			importBeanDefinitionResource(ele);
		}
        // alias标签解析
		else if (delegate.nodeNameEquals(ele, ALIAS_ELEMENT)) { 
			processAliasRegistration(ele);
		}
        // bean标签的解析
		else if (delegate.nodeNameEquals(ele, BEAN_ELEMENT)) {
			processBeanDefinition(ele, delegate);//↓↓↓↓↓
		}
        // beans标签解析
		else if (delegate.nodeNameEquals(ele, NESTED_BEANS_ELEMENT)) {
			doRegisterBeanDefinitions(ele);
		}
	}
```

```java
	//DefaultBeanDefinitionDocumentReader.java
	protected void processBeanDefinition(Element ele, BeanDefinitionParserDelegate delegate) {
        //解析xml文件
		BeanDefinitionHolder bdHolder = delegate.parseBeanDefinitionElement(ele);
		if (bdHolder != null) {
			bdHolder = delegate.decorateBeanDefinitionIfRequired(ele, bdHolder);
			try {
				//注册解析得出的Beandefinition实例到Beanfactory
				BeanDefinitionReaderUtils.registerBeanDefinition(bdHolder, getReaderContext().getRegistry());//↓↓↓↓↓
			}
			catch (BeanDefinitionStoreException ex) {
				getReaderContext().error("Failed to register bean definition with name '" +
						bdHolder.getBeanName() + "'", ele, ex);
			}
			// Send registration event.
			getReaderContext().fireComponentRegistered(new BeanComponentDefinition(bdHolder));
		}
	}

```

```java
	//BeanDefinitionReaderUtils.java
	public static void registerBeanDefinition(
			BeanDefinitionHolder definitionHolder, BeanDefinitionRegistry registry)
			throws BeanDefinitionStoreException {

		String beanName = definitionHolder.getBeanName();
        //注册Beandefinition
		registry.registerBeanDefinition(beanName, definitionHolder.getBeanDefinition());//↓↓↓↓↓

		// 注册Bean的别名
		String[] aliases = definitionHolder.getAliases();
		if (aliases != null) {
			for (String alias : aliases) {
				registry.registerAlias(beanName, alias);
			}
		}
	}
```

```java
	//DefaultListableBeanFactory.java

	/** Map of bean definition objects, keyed by bean name. */
	private final Map<String, BeanDefinition> beanDefinitionMap = new ConcurrentHashMap<>(256);

	public void registerBeanDefinition(String beanName, BeanDefinition beanDefinition)
			throws BeanDefinitionStoreException {

		Assert.hasText(beanName, "Bean name must not be empty");
		Assert.notNull(beanDefinition, "BeanDefinition must not be null");

		if (beanDefinition instanceof AbstractBeanDefinition) {
			try {
				((AbstractBeanDefinition) beanDefinition).validate();
			}
			catch (BeanDefinitionValidationException ex) {
				throw new BeanDefinitionStoreException(beanDefinition.getResourceDescription(), beanName,
						"Validation of bean definition failed", ex);
			}
		}

		BeanDefinition existingDefinition = this.beanDefinitionMap.get(beanName);
		if (existingDefinition != null) {
			if (!isAllowBeanDefinitionOverriding()) {
				throw new BeanDefinitionOverrideException(beanName, beanDefinition, existingDefinition);
			}
			else if (existingDefinition.getRole() < beanDefinition.getRole()) {
				// e.g. was ROLE_APPLICATION, now overriding with ROLE_SUPPORT or ROLE_INFRASTRUCTURE
				if (logger.isInfoEnabled()) {
					logger.info("Overriding user-defined bean definition for bean '" + beanName +
							"' with a framework-generated bean definition: replacing [" +
							existingDefinition + "] with [" + beanDefinition + "]");
				}
			}
			else if (!beanDefinition.equals(existingDefinition)) {
				if (logger.isDebugEnabled()) {
					logger.debug("Overriding bean definition for bean '" + beanName +
							"' with a different definition: replacing [" + existingDefinition +
							"] with [" + beanDefinition + "]");
				}
			}
			else {
				if (logger.isTraceEnabled()) {
					logger.trace("Overriding bean definition for bean '" + beanName +
							"' with an equivalent definition: replacing [" + existingDefinition +
							"] with [" + beanDefinition + "]");
				}
			}
            //将BeanDefinition存储到DefaultListableBeanFactory中。
			this.beanDefinitionMap.put(beanName, beanDefinition);
		}
		else {
			if (hasBeanCreationStarted()) {
				// Cannot modify startup-time collection elements anymore (for stable iteration)
				synchronized (this.beanDefinitionMap) {
					this.beanDefinitionMap.put(beanName, beanDefinition);
					List<String> updatedDefinitions = new ArrayList<>(this.beanDefinitionNames.size() + 1);
					updatedDefinitions.addAll(this.beanDefinitionNames);
					updatedDefinitions.add(beanName);
					this.beanDefinitionNames = updatedDefinitions;
					removeManualSingletonName(beanName);
				}
			}
			else {
				// Still in startup registration phase
				this.beanDefinitionMap.put(beanName, beanDefinition);
				this.beanDefinitionNames.add(beanName);
				removeManualSingletonName(beanName);
			}
			this.frozenBeanDefinitionNames = null;
		}

		if (existingDefinition != null || containsSingleton(beanName)) {
			resetBeanDefinition(beanName);
		}
	}
```

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/spring/BeanDefinition%E5%AE%9A%E4%BD%8D%E5%8A%A0%E8%BD%BD%E6%B3%A8%E5%86%8C%E6%B5%81%E7%A8%8B%E5%9B%BE.png)