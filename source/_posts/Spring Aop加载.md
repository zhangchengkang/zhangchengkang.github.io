---
title: Spring源码分析(四) AOP加载过程
author: kangshifu
top: false
cover: false
toc: true
mathjax: false
categories: Spring
tags:
  - Java
  - Spring
abbrlink: 3067935259
date: 2019-11-16 21:06:23
img:
coverImg:
password:
summary:
---

*Real dream is the other shore of reality*
<!--more-->  



## 入口



```java
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
						parseDefaultElement(ele, delegate);
					}
					// 如果该节点非默认命名空间，执行自定义解析
					else {
						delegate.parseCustomElement(ele);//↓↓↓↓↓
					}
				}
			}
		}
		else {
			delegate.parseCustomElement(root);
		}
	}
```

```xml
	<aop:config>
		<aop:pointcut expression="execution(* cn.ytk.dao.UserDao.*(..))" id="pointcut1"/>
		<aop:aspect ref="project">
			<aop:before method="before1" pointcut-ref="pointcut1"/>
			<aop:after-returning method="after1" pointcut-ref="pointcut1"/>
			<aop:around method="around" pointcut-ref="pointcut1"/>
		</aop:aspect>
	</aop:config>

```

<aop:config>属于自定义标签,所以会执行parseCustomElement



## 自定义标签的解析

```java
	//BeanDefinitionParserDelegate.java
	public BeanDefinition parseCustomElement(Element ele) {
		return parseCustomElement(ele, null);//↓↓↓↓↓
	}


	public BeanDefinition parseCustomElement(Element ele, @Nullable BeanDefinition containingBd) {
		String namespaceUri = getNamespaceURI(ele);
		if (namespaceUri == null) {
			return null;
		}
		NamespaceHandler handler = this.readerContext.getNamespaceHandlerResolver().resolve(namespaceUri);//↓↓↓↓↓
		if (handler == null) {
			error("Unable to locate Spring NamespaceHandler for XML schema namespace [" + namespaceUri + "]", ele);
			return null;
		}
		return handler.parse(ele, new ParserContext(this.readerContext, this, containingBd));//↓↓↓↓↓
	}
```

### resolve

```java
	//DefaultNamespaceHandlerResolver.java
	public NamespaceHandler resolve(String namespaceUri) {
		Map<String, Object> handlerMappings = getHandlerMappings();
		Object handlerOrClassName = handlerMappings.get(namespaceUri);
		if (handlerOrClassName == null) {
			return null;
		}
		else if (handlerOrClassName instanceof NamespaceHandler) {
			return (NamespaceHandler) handlerOrClassName;
		}
		else {
			String className = (String) handlerOrClassName;
			try {
				Class<?> handlerClass = ClassUtils.forName(className, this.classLoader);
				if (!NamespaceHandler.class.isAssignableFrom(handlerClass)) {
					throw new FatalBeanException("Class [" + className + "] for namespace [" + namespaceUri +
							"] does not implement the [" + NamespaceHandler.class.getName() + "] interface");
				}
				NamespaceHandler namespaceHandler = (NamespaceHandler) BeanUtils.instantiateClass(handlerClass);
				namespaceHandler.init();//↓↓↓↓↓
				handlerMappings.put(namespaceUri, namespaceHandler);
				return namespaceHandler;
			}
			catch (ClassNotFoundException ex) {
				throw new FatalBeanException("Could not find NamespaceHandler class [" + className +
						"] for namespace [" + namespaceUri + "]", ex);
			}
			catch (LinkageError err) {
				throw new FatalBeanException("Unresolvable class definition for NamespaceHandler class [" +
						className + "] for namespace [" + namespaceUri + "]", err);
			}
		}
	}
```

```java
	//AopNamespaceHandler.java
	public void init() {
		//初始化方法并且注册配置的解析类到Spring容器中
		registerBeanDefinitionParser("config", new ConfigBeanDefinitionParser());
		registerBeanDefinitionParser("aspectj-autoproxy", new AspectJAutoProxyBeanDefinitionParser());
		registerBeanDefinitionDecorator("scoped-proxy", new ScopedProxyBeanDefinitionDecorator());

		// Only in 2.0 XSD: moved to context namespace as of 2.1
		registerBeanDefinitionParser("spring-configured", new SpringConfiguredBeanDefinitionParser());
	}
```

### parse

```java
	//NamespaceHandlerSupport.java
	public BeanDefinition parse(Element element, ParserContext parserContext) {
		BeanDefinitionParser parser = findParserForElement(element, parserContext);
		return (parser != null ? parser.parse(element, parserContext) : null);//↓↓↓↓↓
	}
```

```java
	//ConfigBeanDefinitionParser.java
	public BeanDefinition parse(Element element, ParserContext parserContext) {
		//设置元素组件描述信息
		CompositeComponentDefinition compositeDef =
				new CompositeComponentDefinition(element.getTagName(), parserContext.extractSource(element));
		parserContext.pushContainingComponent(compositeDef);
		//配置代理自动创建器
		configureAutoProxyCreator(parserContext, element);//↓↓↓↓↓
		//解析孩子节点  并完成Bean描述信息的注册
		List<Element> childElts = DomUtils.getChildElements(element);
		for (Element elt: childElts) {
			String localName = parserContext.getDelegate().getLocalName(elt);
			if (POINTCUT.equals(localName)) {
				//解析Pointcut标签并完成注册
				parsePointcut(elt, parserContext);
			}
			else if (ADVISOR.equals(localName)) {
				//解析advisor标签并完成注册
				parseAdvisor(elt, parserContext);
			}
			else if (ASPECT.equals(localName)) {
				//解析aspect标签并完成注册
				parseAspect(elt, parserContext);//↓↓↓↓↓
			}
		}

		parserContext.popAndRegisterContainingComponent();
		return null;
	}
```

#### configureAutoProxyCreator

```java
	//ConfigBeanDefinitionParser.java
	private void configureAutoProxyCreator(ParserContext parserContext, Element element) {
		AopNamespaceUtils.registerAspectJAutoProxyCreatorIfNecessary(parserContext, element);//↓↓↓↓↓
	}
```

```java
	//AopNamespaceUtils.java
	public static void registerAspectJAutoProxyCreatorIfNecessary(
			ParserContext parserContext, Element sourceElement) {
		//如果需要,则注册在ApsectJ场景下为指定的Bean创建代理的工具类示例,并将其注册到BeanFactory中
		BeanDefinition beanDefinition = AopConfigUtils.registerAspectJAutoProxyCreatorIfNecessary(
				parserContext.getRegistry(), parserContext.extractSource(sourceElement));//↓↓↓↓↓
		useClassProxyingIfNecessary(parserContext.getRegistry(), sourceElement);
		registerComponentIfNecessary(beanDefinition, parserContext);
	}



	public static BeanDefinition registerAspectJAutoProxyCreatorIfNecessary(
			BeanDefinitionRegistry registry, @Nullable Object source) {
		//如果需要,则将AspectJAwareAdvisorAutoProxyCreator.class类型的Bean描述信息注册到BeanFactory中
		return registerOrEscalateApcAsRequired(AspectJAwareAdvisorAutoProxyCreator.class, registry, source);//↓↓↓↓↓
	}



	private static BeanDefinition registerOrEscalateApcAsRequired(
			Class<?> cls, BeanDefinitionRegistry registry, @Nullable Object source) {

		Assert.notNull(registry, "BeanDefinitionRegistry must not be null");

		//如果存在"org.springframework.aop.config.internalAutoProxyCreator"  则不创建
		if (registry.containsBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME)) {
			BeanDefinition apcDefinition = registry.getBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME);
			if (!cls.getName().equals(apcDefinition.getBeanClassName())) {
				//如果当前Bean的Class与容器中已存在的Bean描述信息的class不一致,则按照类的优先级来选择使用目标类
				int currentPriority = findPriorityForClass(apcDefinition.getBeanClassName());
				int requiredPriority = findPriorityForClass(cls);
				if (currentPriority < requiredPriority) {
					apcDefinition.setBeanClassName(cls.getName());
				}
			}
			return null;
		}

		//如果在当前BeanFactory中没有这个Bean的描述信息,则为当前对象创建Bean描述信息并将其注册到BeanFactory中
		RootBeanDefinition beanDefinition = new RootBeanDefinition(cls);
		beanDefinition.setSource(source);
		beanDefinition.getPropertyValues().add("order", Ordered.HIGHEST_PRECEDENCE);
		beanDefinition.setRole(BeanDefinition.ROLE_INFRASTRUCTURE);
		registry.registerBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME, beanDefinition);
		return beanDefinition;
	}
```



#### parseAspect

```java
	//ConfigBeanDefinitionParser.java
	private void parseAspect(Element aspectElement, ParserContext parserContext) {
		//获取定义的切面ID和ref
		String aspectId = aspectElement.getAttribute(ID);
		String aspectName = aspectElement.getAttribute(REF);

		try {
			//将获取到的切面ID和ref封装到AspectEntry这个类中
			this.parseState.push(new AspectEntry(aspectId, aspectName));
			//把<aop:before>等通知相关的信息封装到AspectJPointcutAdvisor中，然后放到该集合里
			List<BeanDefinition> beanDefinitions = new ArrayList<>();
			//把ref相关的信息如aop.xml中的logger，updateUserMethod等封装到RunTimeBeanReference中，然后放到这个集合中
			List<BeanReference> beanReferences = new ArrayList<>();

			List<Element> declareParents = DomUtils.getChildElementsByTagName(aspectElement, DECLARE_PARENTS);
			for (int i = METHOD_INDEX; i < declareParents.size(); i++) {
				Element declareParentsElement = declareParents.get(i);
				beanDefinitions.add(parseDeclareParents(declareParentsElement, parserContext));
			}

			NodeList nodeList = aspectElement.getChildNodes();
			boolean adviceFoundAlready = false;
			//循环切面的子节点，然后判断是否是通知，然后进行对应的处理
			for (int i = 0; i < nodeList.getLength(); i++) {
				Node node = nodeList.item(i);
				if (isAdviceNode(node, parserContext)) {
					if (!adviceFoundAlready) {
						adviceFoundAlready = true;
						if (!StringUtils.hasText(aspectName)) {
							parserContext.getReaderContext().error(
									"<aspect> tag needs aspect bean reference via 'ref' attribute when declaring advices.",
									aspectElement, this.parseState.snapshot());
							return;
						}
						//封装ref信息
						beanReferences.add(new RuntimeBeanReference(aspectName));
					}
					//把通知相关信息封装到AspectJPointcutAdvisor这个类中，同时封装ref信息然后放到BeanReferences中
					AbstractBeanDefinition advisorDefinition = parseAdvice(
							aspectName, i, aspectElement, (Element) node, parserContext, beanDefinitions, beanReferences);
					beanDefinitions.add(advisorDefinition);
				}
			}
			//把切面信息和通知信息封装到这个类中　
			AspectComponentDefinition aspectComponentDefinition = createAspectComponentDefinition(
					aspectElement, aspectId, beanDefinitions, beanReferences, parserContext);
			parserContext.pushContainingComponent(aspectComponentDefinition);
			//解析切入点，然后封装信息　
			List<Element> pointcuts = DomUtils.getChildElementsByTagName(aspectElement, POINTCUT);
			for (Element pointcutElement : pointcuts) {
				//这个是具体解析切入点的方法
				parsePointcut(pointcutElement, parserContext);
			}

			parserContext.popAndRegisterContainingComponent();
		}
		finally {
			this.parseState.pop();
		}
	}
```



```java
	//ConfigBeanDefinitionParser.java
	private void parseAspect(Element aspectElement, ParserContext parserContext) {
		//获取定义的切面ID和ref
		String aspectId = aspectElement.getAttribute(ID);
		String aspectName = aspectElement.getAttribute(REF);

		try {
			//将获取到的切面ID和ref封装到AspectEntry这个类中
			this.parseState.push(new AspectEntry(aspectId, aspectName));
			//把<aop:before>等通知相关的信息封装到AspectJPointcutAdvisor中，然后放到该集合里
			List<BeanDefinition> beanDefinitions = new ArrayList<>();
			//把ref相关的信息如aop.xml中的logger，updateUserMethod等封装到RunTimeBeanReference中，然后放到这个集合中
			List<BeanReference> beanReferences = new ArrayList<>();

			List<Element> declareParents = DomUtils.getChildElementsByTagName(aspectElement, DECLARE_PARENTS);
			for (int i = METHOD_INDEX; i < declareParents.size(); i++) {
				Element declareParentsElement = declareParents.get(i);
				beanDefinitions.add(parseDeclareParents(declareParentsElement, parserContext));
			}

			NodeList nodeList = aspectElement.getChildNodes();
			boolean adviceFoundAlready = false;
			//循环切面的子节点，然后判断是否是通知，然后进行对应的处理
			for (int i = 0; i < nodeList.getLength(); i++) {
				Node node = nodeList.item(i);
				if (isAdviceNode(node, parserContext)) {
					if (!adviceFoundAlready) {
						adviceFoundAlready = true;
						if (!StringUtils.hasText(aspectName)) {
							parserContext.getReaderContext().error(
									"<aspect> tag needs aspect bean reference via 'ref' attribute when declaring advices.",
									aspectElement, this.parseState.snapshot());
							return;
						}
						//封装ref信息
						beanReferences.add(new RuntimeBeanReference(aspectName));
					}
					//把通知相关信息封装到AspectJPointcutAdvisor这个类中，同时封装ref信息然后放到BeanReferences中
					AbstractBeanDefinition advisorDefinition = parseAdvice(
							aspectName, i, aspectElement, (Element) node, parserContext, beanDefinitions, beanReferences);
					beanDefinitions.add(advisorDefinition);
				}
			}
			//把切面信息和通知信息封装到这个类中　
			AspectComponentDefinition aspectComponentDefinition = createAspectComponentDefinition(
					aspectElement, aspectId, beanDefinitions, beanReferences, parserContext);
			parserContext.pushContainingComponent(aspectComponentDefinition);
			//解析切入点，然后封装信息　
			List<Element> pointcuts = DomUtils.getChildElementsByTagName(aspectElement, POINTCUT);
			for (Element pointcutElement : pointcuts) {
				//这个是具体解析切入点的方法
				parsePointcut(pointcutElement, parserContext);
			}

			parserContext.popAndRegisterContainingComponent();
		}
		finally {
			this.parseState.pop();
		}
	}
```

