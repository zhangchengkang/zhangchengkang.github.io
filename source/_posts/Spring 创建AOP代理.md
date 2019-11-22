---
toc: true
title: Spring源码分析(五) 创建AOP代理
date: 2019-11-17 15:16:51
tags: [Spring]
categories: JAVA






---

*I know that my future is not just a dream*
<!--more-->  



## 入口

```java
	//AbstractAutowireCapableBeanFactory.java
	protected Object initializeBean(final String beanName, final Object bean, @Nullable RootBeanDefinition mbd) {
		if (System.getSecurityManager() != null) {
			AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
				invokeAwareMethods(beanName, bean);
				return null;
			}, getAccessControlContext());
		}
		else {
			invokeAwareMethods(beanName, bean);
		}

		Object wrappedBean = bean;
		if (mbd == null || !mbd.isSynthetic()) {
			wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
		}

		try {
			invokeInitMethods(beanName, wrappedBean, mbd);
		}
		catch (Throwable ex) {
			throw new BeanCreationException(
					(mbd != null ? mbd.getResourceDescription() : null),
					beanName, "Invocation of init method failed", ex);
		}
		if (mbd == null || !mbd.isSynthetic()) {
            // 执行后置处理器 applyBeanPostProcessorsAfterInitialization
			wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);//↓↓↓↓↓
		}

		return wrappedBean;
	}
```

## **创建AOP代理**

```java
	//AbstractAutowireCapableBeanFactory.java
	public Object applyBeanPostProcessorsAfterInitialization(Object existingBean, String beanName)
			throws BeansException {

		Object result = existingBean;
		for (BeanPostProcessor processor : getBeanPostProcessors()) {
			Object current = processor.postProcessAfterInitialization(result, beanName);//↓↓↓↓↓
			if (current == null) {
				return result;
			}
			result = current;
		}
		return result;
	}
```

```java
	//AbstractAutoProxyCreator
	public Object postProcessAfterInitialization(@Nullable Object bean, String beanName) {
		if (bean != null) {
			// 根据beanClass 和 beanName 创建缓存的 key
			Object cacheKey = getCacheKey(bean.getClass(), beanName);
			if (this.earlyProxyReferences.remove(cacheKey) != bean) {
				return wrapIfNecessary(bean, beanName, cacheKey);//↓↓↓↓↓
			}
		}
		return bean;
	}
```

创建代理主要包含了两个步骤:

1. 获取增强方法或者增强器
2. 根据获取的增强进行代理

```java
	//AbstractAutoProxyCreator.java
	protected Object wrapIfNecessary(Object bean, String beanName, Object cacheKey) {
		// 如果已经处理过，则直接返回
		if (StringUtils.hasLength(beanName) && this.targetSourcedBeans.contains(beanName)) {
			return bean;
		}
		// 该bean无需增强，则直接返回
		if (Boolean.FALSE.equals(this.advisedBeans.get(cacheKey))) {
			return bean;
		}
		//如果bean是Advice.class, Pointcut.class, Advisor.class, AopInfrastructureBean.class, 则直接返回
		if (isInfrastructureClass(bean.getClass()) || shouldSkip(bean.getClass(), beanName)) {
			// 添加该bean不需要增强的标志到缓存中
			this.advisedBeans.put(cacheKey, Boolean.FALSE);
			return bean;
		}

		// 获取bean所有的增强
		Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);//↓↓↓↓↓
		if (specificInterceptors != DO_NOT_PROXY) {
			this.advisedBeans.put(cacheKey, Boolean.TRUE);
			// 如果获取到增强，则需要对增强创建代理
			Object proxy = createProxy(
					bean.getClass(), beanName, specificInterceptors, new SingletonTargetSource(bean));//↓↓↓↓↓
			this.proxyTypes.put(cacheKey, proxy.getClass());
			return proxy;
		}
		// 不需要增强，直接返回
		this.advisedBeans.put(cacheKey, Boolean.FALSE);
		return bean;
	}
```

###  获取增强方法或者增强器

```java
	//AbstractAdvisorAutoProxyCreator.java
	protected Object[] getAdvicesAndAdvisorsForBean(
			Class<?> beanClass, String beanName, @Nullable TargetSource targetSource) {
		//获取当前Bean匹配的Advisor
		List<Advisor> advisors = findEligibleAdvisors(beanClass, beanName);//↓↓↓↓↓
		if (advisors.isEmpty()) {
			return DO_NOT_PROXY;
		}
		return advisors.toArray();
	}
```

对于指定bean的增强方法的获取一定是包含两个步骤的，获取所有的增强以及寻找所有增强中适用于bean的增强并应用，那么findCandidateAdvisors与findAdvisorsThatCanApply便做了这两件事情。当然，如果无法找到对应的增强器便返回DO_NOT_PROXY,这个值为null

```java
	//AbstractAdvisorAutoProxyCreator.java		
	protected List<Advisor> findEligibleAdvisors(Class<?> beanClass, String beanName) {
		// 获取可用的Advisor
		List<Advisor> candidateAdvisors = findCandidateAdvisors();//↓↓↓↓↓
		// 获取匹配Bean的所有Advisor
		List<Advisor> eligibleAdvisors = findAdvisorsThatCanApply(candidateAdvisors, beanClass, beanName);
		// 获取在子类中扩展的Advisor并排序
		extendAdvisors(eligibleAdvisors);
		if (!eligibleAdvisors.isEmpty()) {
			eligibleAdvisors = sortAdvisors(eligibleAdvisors);
		}
		return eligibleAdvisors;
	}
```

#### findCandidateAdvisors

```java
	//AbstractAdvisorAutoProxyCreator.java	
	protected List<Advisor> findCandidateAdvisors() {
		Assert.state(this.advisorRetrievalHelper != null, "No BeanFactoryAdvisorRetrievalHelper available");
		return this.advisorRetrievalHelper.findAdvisorBeans();//↓↓↓↓↓
	}
```

```java
	//BeanFactoryAdvisorRetrievalHelper.java
	public List<Advisor> findAdvisorBeans() {
		// cachedAdvisorBeanNames 是 advisor 名称的缓存
		String[] advisorNames = this.cachedAdvisorBeanNames;

		// 如果 cachedAdvisorBeanNames 为空，这里到容器中查找， 并设置缓存，后续直接使用缓存即可
		if (advisorNames == null) {
			// 从容器中查找 Advisor 类型 bean 的名称
			advisorNames = BeanFactoryUtils.beanNamesForTypeIncludingAncestors(
					this.beanFactory, Advisor.class, true, false);
			this.cachedAdvisorBeanNames = advisorNames;
		}
		if (advisorNames.length == 0) {
			return new ArrayList<>();
		}

		List<Advisor> advisors = new ArrayList<>();
		for (String name : advisorNames) {
			if (isEligibleBean(name)) {
				// 忽略正在创建中的 advisor bean
				if (this.beanFactory.isCurrentlyInCreation(name)) {
					if (logger.isTraceEnabled()) {
						logger.trace("Skipping currently created advisor '" + name + "'");
					}
				}
				else {
					try {
						//调用 getBean 方法从容器中获取名称为 name 的 bean，并将 bean 添加到 advisors 中
						advisors.add(this.beanFactory.getBean(name, Advisor.class));
					}
					catch (BeanCreationException ex) {
						Throwable rootCause = ex.getMostSpecificCause();
						if (rootCause instanceof BeanCurrentlyInCreationException) {
							BeanCreationException bce = (BeanCreationException) rootCause;
							String bceBeanName = bce.getBeanName();
							if (bceBeanName != null && this.beanFactory.isCurrentlyInCreation(bceBeanName)) {
								if (logger.isTraceEnabled()) {
									logger.trace("Skipping advisor '" + name +
											"' with dependency on currently created bean: " + ex.getMessage());
								}
								// Ignore: indicates a reference back to the bean we're trying to advise.
								// We want to find advisors other than the currently created bean itself.
								continue;
							}
						}
						throw ex;
					}
				}
			}
		}
		return advisors;
	}
```

#### buildAspectJAdvisors

```java
	public List<Advisor> buildAspectJAdvisors() {
		List<String> aspectNames = this.aspectBeanNames;

		if (aspectNames == null) {
			synchronized (this) {
				aspectNames = this.aspectBeanNames;
				if (aspectNames == null) {
					List<Advisor> advisors = new ArrayList<>();
					aspectNames = new ArrayList<>();
					// 从容器中获取所有 bean 的名称
					String[] beanNames = BeanFactoryUtils.beanNamesForTypeIncludingAncestors(
							this.beanFactory, Object.class, true, false);
					for (String beanName : beanNames) {
						if (!isEligibleBean(beanName)) {
							continue;
						}
						// 根据 beanName 获取 bean 的类型
						Class<?> beanType = this.beanFactory.getType(beanName);
						if (beanType == null) {
							continue;
						}
						// 检测 beanType 是否包含 Aspect 注解
						if (this.advisorFactory.isAspect(beanType)) {
							aspectNames.add(beanName);
							AspectMetadata amd = new AspectMetadata(beanType, beanName);
							if (amd.getAjType().getPerClause().getKind() == PerClauseKind.SINGLETON) {
								MetadataAwareAspectInstanceFactory factory =
										new BeanFactoryAspectInstanceFactory(this.beanFactory, beanName);
								// 获取通知器
								List<Advisor> classAdvisors = this.advisorFactory.getAdvisors(factory);//↓↓↓↓↓
								if (this.beanFactory.isSingleton(beanName)) {
									this.advisorsCache.put(beanName, classAdvisors);
								}
								else {
									this.aspectFactoryCache.put(beanName, factory);
								}
								advisors.addAll(classAdvisors);
							}
							else {
								// Per target or per this.
								if (this.beanFactory.isSingleton(beanName)) {
									throw new IllegalArgumentException("Bean with name '" + beanName +
											"' is a singleton, but aspect instantiation model is not singleton");
								}
								MetadataAwareAspectInstanceFactory factory =
										new PrototypeAspectInstanceFactory(this.beanFactory, beanName);
								this.aspectFactoryCache.put(beanName, factory);
								advisors.addAll(this.advisorFactory.getAdvisors(factory));
							}
						}
					}
					this.aspectBeanNames = aspectNames;
					return advisors;
				}
			}
		}

		if (aspectNames.isEmpty()) {
			return Collections.emptyList();
		}
		List<Advisor> advisors = new ArrayList<>();
		for (String aspectName : aspectNames) {
			List<Advisor> cachedAdvisors = this.advisorsCache.get(aspectName);
			if (cachedAdvisors != null) {
				advisors.addAll(cachedAdvisors);
			}
			else {
				MetadataAwareAspectInstanceFactory factory = this.aspectFactoryCache.get(aspectName);
				advisors.addAll(this.advisorFactory.getAdvisors(factory));
			}
		}
		return advisors;
	}
```

```java
	public List<Advisor> getAdvisors(MetadataAwareAspectInstanceFactory aspectInstanceFactory) {
		// 获取 aspectClass 和 aspectName
		Class<?> aspectClass = aspectInstanceFactory.getAspectMetadata().getAspectClass();
		String aspectName = aspectInstanceFactory.getAspectMetadata().getAspectName();
		validate(aspectClass);

		// We need to wrap the MetadataAwareAspectInstanceFactory with a decorator
		// so that it will only instantiate once.
		MetadataAwareAspectInstanceFactory lazySingletonAspectInstanceFactory =
				new LazySingletonAspectInstanceFactoryDecorator(aspectInstanceFactory);

		List<Advisor> advisors = new ArrayList<>();
		// getAdvisorMethods 用于返回不包含 @Pointcut 注解的方法
		for (Method method : getAdvisorMethods(aspectClass)) {//↓↓↓↓↓
			Advisor advisor = getAdvisor(method, lazySingletonAspectInstanceFactory, advisors.size(), aspectName);
			if (advisor != null) {
				advisors.add(advisor);
			}
		}

		// If it's a per target aspect, emit the dummy instantiating aspect.
		if (!advisors.isEmpty() && lazySingletonAspectInstanceFactory.getAspectMetadata().isLazilyInstantiated()) {
			Advisor instantiationAdvisor = new SyntheticInstantiationAdvisor(lazySingletonAspectInstanceFactory);
			advisors.add(0, instantiationAdvisor);
		}

		// Find introduction fields.
		for (Field field : aspectClass.getDeclaredFields()) {
			Advisor advisor = getDeclareParentsAdvisor(field);
			if (advisor != null) {
				advisors.add(advisor);
			}
		}

		return advisors;
	}
```

```java
	private List<Method> getAdvisorMethods(Class<?> aspectClass) {
		final List<Method> methods = new ArrayList<>();
		ReflectionUtils.doWithMethods(aspectClass, method -> {
			//声明为Pointcut的方法不处理
			if (AnnotationUtils.getAnnotation(method, Pointcut.class) == null) {
				methods.add(method);
			}
		}, ReflectionUtils.USER_DECLARED_METHODS);
		methods.sort(METHOD_COMPARATOR);
		return methods;
	}
```

### 对增强创建代理

```java
	//AbstractAutoProxyCreator.java
	protected Object createProxy(Class<?> beanClass, @Nullable String beanName,
			@Nullable Object[] specificInterceptors, TargetSource targetSource) {

		if (this.beanFactory instanceof ConfigurableListableBeanFactory) {
			AutoProxyUtils.exposeTargetClass((ConfigurableListableBeanFactory) this.beanFactory, beanName, beanClass);
		}

        //决定对于给定的bean是否应该使用targetClass而不是他的接口代理
		//检查proxyTargeClass设置以及preserveTargetClass属性
		ProxyFactory proxyFactory = new ProxyFactory();
		proxyFactory.copyFrom(this);

        //默认配置下，或用户显式配置 proxy-target-class = "false" 时，这里的 proxyFactory.isProxyTargetClass() 也为 false
		if (!proxyFactory.isProxyTargetClass()) {
			if (shouldProxyTargetClass(beanClass, beanName)) {
				proxyFactory.setProxyTargetClass(true);
			}
			else {
                //检测 beanClass 是否实现了接口，若未实现，则将proxyFactory 的成员变量 proxyTargetClass 设为 true 
				evaluateProxyInterfaces(beanClass, proxyFactory);
			}
		}

        // specificInterceptors 中若包含有 Advice，此处将 Advice 转为 Advisor
		Advisor[] advisors = buildAdvisors(beanName, specificInterceptors);
		proxyFactory.addAdvisors(advisors);
		proxyFactory.setTargetSource(targetSource);
		customizeProxyFactory(proxyFactory);

		proxyFactory.setFrozen(this.freezeProxy);
		if (advisorsPreFiltered()) {
			proxyFactory.setPreFiltered(true);
		}

        // 创建代理
		return proxyFactory.getProxy(getProxyClassLoader());//↓↓↓↓↓
	}
```

```java
    //ProxyFactory.java
	public Object getProxy(ClassLoader classLoader) {
        // 先创建 AopProxy 实现类对象，然后再调用 getProxy 为目标 bean 创建代理对象
        return createAopProxy().getProxy(classLoader);//↓↓↓↓↓
    }
```

```java
	//ProxyCreatorSupport.java
	protected final synchronized AopProxy createAopProxy() {
		if (!this.active) {
			activate();
		}
		return getAopProxyFactory().createAopProxy(this);
	}
```

```java
	//DefaultAopProxyFactory.java
	public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
		if (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config)) {
			Class<?> targetClass = config.getTargetClass();
			if (targetClass == null) {
				throw new AopConfigException("TargetSource cannot determine target class: " +
						"Either an interface or a target is required for proxy creation.");
			}
			if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
				return new JdkDynamicAopProxy(config);
			}
            // 创建 CGLIB 代理，ObjenesisCglibAopProxy 继承自 CglibAopProxy
			return new ObjenesisCglibAopProxy(config);
		}
		else {
            // 创建 JDK 动态代理
			return new JdkDynamicAopProxy(config);
		}
	}
```

