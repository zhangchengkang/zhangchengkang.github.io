---
toc: true
title: Spring源码分析(三) CreateBean()
date: 2019-11-10 20:35:12
tags: [Spring]
categories: JAVA





---

*better late than never*
<!--more-->  

## 入口

```java
public T doGetBean(...) {
    // 省略不相关代码
    if (mbd.isSingleton()) {
       	sharedInstance = getSingleton(beanName, () -> {
						try {
							return createBean(beanName, mbd, args);
                catch (BeansException ex) {
                    destroySingleton(beanName);
                    throw ex;
                }
            }
        });
        bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
```

## createBean

```java
//AbstractAutowireCapableBeanFactory.java
protected Object createBean(String beanName, RootBeanDefinition mbd, Object[] args) throws BeanCreationException {
    if (logger.isDebugEnabled()) {
        logger.debug("Creating instance of bean '" + beanName + "'");
    }
    RootBeanDefinition mbdToUse = mbd;

    // 解析 bean 的类型
    Class<?> resolvedClass = resolveBeanClass(mbd, beanName);
    if (resolvedClass != null && !mbd.hasBeanClass() && mbd.getBeanClassName() != null) {
        mbdToUse = new RootBeanDefinition(mbd);
        mbdToUse.setBeanClass(resolvedClass);
    }

    try {
        // 处理 lookup-method 和 replace-method 配置，Spring 将这两个配置统称为 override method
        mbdToUse.prepareMethodOverrides();
    }
    catch (BeanDefinitionValidationException ex) {
        throw new BeanDefinitionStoreException(mbdToUse.getResourceDescription(),
                beanName, "Validation of method overrides failed", ex);
    }

    try {
        // 给 BeanPostProcessors 机会返回一个代理来代替bean的实例
		// 即在初始化前，应用后置处理器，解析指定的bean是否存在初始化前的短路操作
        Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
        if (bean != null) {
            return bean;
        }
    }
    catch (Throwable ex) {
        throw new BeanCreationException(mbdToUse.getResourceDescription(), beanName,
                "BeanPostProcessor before instantiation of bean failed", ex);
    }

    // 调用 doCreateBean 创建 bean
    Object beanInstance = doCreateBean(beanName, mbdToUse, args);
    if (logger.isDebugEnabled()) {
        logger.debug("Finished creating instance of bean '" + beanName + "'");
    }
    return beanInstance;
}
```

## 处理 lookup-method 和 replace-method 子标签->prepareMethodOverrides

```java
	
	//AbstractBeanDefinition,java
	public void prepareMethodOverrides() throws BeanDefinitionValidationException {
		// Check that lookup methods exist and determine their overloaded status.
		if (hasMethodOverrides()) {
			getMethodOverrides().getOverrides().forEach(this::prepareMethodOverride);
		}
	}

	protected void prepareMethodOverride(MethodOverride mo) throws BeanDefinitionValidationException {
        // 获取对应类的方法的个数,当方法重载时，count 的值就会大于1
		int count = ClassUtils.getMethodCountForName(getBeanClass(), mo.getMethodName());
        // count = 0，表明根据方法名未找到相应的方法，此时抛出异常
		if (count == 0) {
			throw new BeanDefinitionValidationException(
					"Invalid method override: no method with name '" + mo.getMethodName() +
					"' on class [" + getBeanClassName() + "]");
		}
        // count=1,标记 MethodOverride 未被覆盖，避免了后面参数类型检查的开销
		else if (count == 1) {
			mo.setOverloaded(false);
		}
	}
```

## 实例化的前置处理 ->resolveBeforeInstantiation

如果经过前置处理后的结果不为空，则直接返回，不再进行bean的创建过程，AOP功能就是在这里判断的：

```java
	//AbstractAutowireCapableBeanFactory.java
	protected Object resolveBeforeInstantiation(String beanName, RootBeanDefinition mbd) {
		Object bean = null;
        // 检测是否解析过， mbd.beforeInstantiationResolved 的值在下面的代码中会被设置
		if (!Boolean.FALSE.equals(mbd.beforeInstantiationResolved)) {
			// Make sure bean class is actually resolved at this point.
			if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
				Class<?> targetType = determineTargetType(beanName, mbd);
				if (targetType != null) {
                    // bean 的前置处理器
					bean = applyBeanPostProcessorsBeforeInstantiation(targetType, beanName);
					if (bean != null) {
                        //当前置处理方法返回的 bean 不为空时，后置处理才会被执行
						bean = applyBeanPostProcessorsAfterInitialization(bean, beanName);
					}
				}
			}
			mbd.beforeInstantiationResolved = (bean != null);
		}
		return bean;
	}

	protected Object applyBeanPostProcessorsBeforeInstantiation(Class<?> beanClass, String beanName) {
		for (BeanPostProcessor bp : getBeanPostProcessors()) {
			if (bp instanceof InstantiationAwareBeanPostProcessor) {
				InstantiationAwareBeanPostProcessor ibp = (InstantiationAwareBeanPostProcessor) bp;
                // bean 初始化前置处理
				Object result = ibp.postProcessBeforeInstantiation(beanClass, beanName);
				if (result != null) {
					return result;
				}
			}
		}
		return null;
	}

	@Override
	public Object applyBeanPostProcessorsAfterInitialization(Object existingBean, String beanName)
			throws BeansException {

		Object result = existingBean;
		for (BeanPostProcessor processor : getBeanPostProcessors()) {
            // bean 初始化后置处理
			Object current = processor.postProcessAfterInitialization(result, beanName);
			if (current == null) {
				return result;
			}
			result = current;
		}
		return result;
	}
```

## 创建Bean ->doCreateBean 

当经过 resolveBeforeInstantiation 方法后，如果程序创建了代理，或者执行了 applyBeanPostProcessorsBeforeInstantiation 和 applyBeanPostProcessorsAfterInitialization 方法后，bean 被改变了，则直接返回，否则，会进行创建bean操作：

```java
	//AbstractAutowireCapableBeanFactory.java
	protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, final @Nullable Object[] args)
			throws BeanCreationException {

		// 最终返回的 bean 的包装类
        // 通过 BeanWrapper 的实现类可以方便的设置/获取 bean 实例的属性
		BeanWrapper instanceWrapper = null;
		if (mbd.isSingleton()) {
            // 如果是单例，则检查工厂缓存中以前是否创建过
			instanceWrapper = this.factoryBeanInstanceCache.remove(beanName);
		}
		if (instanceWrapper == null) {
            // 创建bean，工厂方法创建，构造方法创建，默认构造方法创建等
			instanceWrapper = createBeanInstance(beanName, mbd, args);
		}
        // 此处的 bean 可以认为是一个原始的 bean 实例，暂未填充属性
		final Object bean = instanceWrapper.getWrappedInstance();
		Class<?> beanType = instanceWrapper.getWrappedClass();
		if (beanType != NullBean.class) {
			mbd.resolvedTargetType = beanType;
		}

		synchronized (mbd.postProcessingLock) {
			if (!mbd.postProcessed) {
				try {
					applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
				}
				catch (Throwable ex) {
					throw new BeanCreationException(mbd.getResourceDescription(), beanName,
							"Post-processing of merged bean definition failed", ex);
				}
				mbd.postProcessed = true;
			}
		}

		// 检查循环依赖：是否是单例 && 是否允许循环依赖 && 当前bean是否正在创建中
		boolean earlySingletonExposure = (mbd.isSingleton() && this.allowCircularReferences &&
				isSingletonCurrentlyInCreation(beanName));
		if (earlySingletonExposure) {
			if (logger.isTraceEnabled()) {
				logger.trace("Eagerly caching bean '" + beanName +
						"' to allow for resolving potential circular references");
			}
            //为了避免后期的循环依赖，在bean初始化完成前，将创建bean的工厂添加到缓存中，
            //如果其他的bean依赖该bean，直接从缓存中获取对应的工厂去创建bean，解决循环依赖
            //Only单例
			addSingletonFactory(beanName, () -> getEarlyBeanReference(beanName, mbd, bean));
		}

		// 初始化 bean
		Object exposedObject = bean;
		try {
            // 填充属性
			populateBean(beanName, mbd, instanceWrapper);
            //进行余下的初始化工作，详细如下
			exposedObject = initializeBean(beanName, exposedObject, mbd);
		}
		catch (Throwable ex) {
			if (ex instanceof BeanCreationException && beanName.equals(((BeanCreationException) ex).getBeanName())) {
				throw (BeanCreationException) ex;
			}
			else {
				throw new BeanCreationException(
						mbd.getResourceDescription(), beanName, "Initialization of bean failed", ex);
			}
		}

        // 只有在检测到循环依赖时才不会为空
		if (earlySingletonExposure) {
			Object earlySingletonReference = getSingleton(beanName, false);
            // 存在循环依赖
			if (earlySingletonReference != null) {
                // 如果 exposedObject 在初始化方法中没有被改变，即没有被增强
				if (exposedObject == bean) {
					exposedObject = earlySingletonReference;
				}
				else if (!this.allowRawInjectionDespiteWrapping && hasDependentBean(beanName)) {
					String[] dependentBeans = getDependentBeans(beanName);
					Set<String> actualDependentBeans = new LinkedHashSet<>(dependentBeans.length);
					for (String dependentBean : dependentBeans) {
                        // 检测依赖
						if (!removeSingletonIfCreatedForTypeCheckOnly(dependentBean)) {
							actualDependentBeans.add(dependentBean);
						}
					}
                    // 因为bean创建后，所依赖的bean一定是已经创建完毕的，actualDependentBeans 不为空则表示所依赖的bean还没有创建完，即存在循环依赖
					if (!actualDependentBeans.isEmpty()) {
						throw new BeanCurrentlyInCreationException(beanName,
								"Bean with name '" + beanName + "' has been injected into other beans [" +
								StringUtils.collectionToCommaDelimitedString(actualDependentBeans) +
								"] in its raw version as part of a circular reference, but has eventually been " +
								"wrapped. This means that said other beans do not use the final version of the " +
								"bean. This is often the result of over-eager type matching - consider using " +
								"'getBeanNamesOfType' with the 'allowEagerInit' flag turned off, for example.");
					}
				}
			}
		}

		try {
            // 注册销毁逻辑
			registerDisposableBeanIfNecessary(beanName, bean, mbd);
		}
		catch (BeanDefinitionValidationException ex) {
			throw new BeanCreationException(
					mbd.getResourceDescription(), beanName, "Invalid destruction signature", ex);
		}

		return exposedObject;
	}
```

1. 从缓存中获取 BeanWrapper 实现类对象，并清理相关记录
2. 若未命中缓存，则创建 bean 实例，并将实例包裹在 BeanWrapper 实现类对象中返回
3. 根据条件决定是否提前暴露 bean 的早期引用（early reference），用于处理循环依赖问题
4. 调用 populateBean 方法向 bean 实例中填充属性
5. 调用 initializeBean 方法完成余下的初始化工作
6. 注册销毁逻辑

## 创建bean实例 ->createBeanInstance

```java
	//AbstractAutowireCapableBeanFactory.java
	protected BeanWrapper createBeanInstance(String beanName, RootBeanDefinition mbd, @Nullable Object[] args) {
		// 获取 bean 对应的 class 
		Class<?> beanClass = resolveBeanClass(mbd, beanName);
		
     	// 检测类的访问权限。默认情况下，对于非 public 的类，是允许访问的。
     	// 若禁止访问，这里会抛出异常
		if (beanClass != null && !Modifier.isPublic(beanClass.getModifiers()) && !mbd.isNonPublicAccessAllowed()) {
			throw new BeanCreationException(mbd.getResourceDescription(), beanName,
					"Bean class isn't public, and non-public access not allowed: " + beanClass.getName());
		}

		Supplier<?> instanceSupplier = mbd.getInstanceSupplier();
		if (instanceSupplier != null) {
			return obtainFromSupplier(instanceSupplier, beanName);
		}

        // 如果工厂方法不为空，则使用工厂方法创建
		if (mbd.getFactoryMethodName() != null) {
			return instantiateUsingFactoryMethod(beanName, mbd, args);
		}

		boolean resolved = false;
		boolean autowireNecessary = false;
		if (args == null) {
			synchronized (mbd.constructorArgumentLock) {
                // 一个类有多个构造方法，带有不同的参数，所以调用前，需要根据参数解析出需要调用的构造方法，
            	// 这里使用了缓存，如果以前解析过构造方法，则在这里直接使用即可。
				if (mbd.resolvedConstructorOrFactoryMethod != null) {
					resolved = true;
					autowireNecessary = mbd.constructorArgumentsResolved;
				}
			}
		}
		if (resolved) {
			if (autowireNecessary) {
                // 通过“构造方法自动注入”的方式构造 bean 对象
				return autowireConstructor(beanName, mbd, null, null);
			}
			else {
                // 通过“默认构造方法”的方式构造 bean 对象
				return instantiateBean(beanName, mbd);
			}
		}

		// 由后置处理器决定返回哪些构造方法
		Constructor<?>[] ctors = determineConstructorsFromBeanPostProcessors(beanClass, beanName);
		if (ctors != null || mbd.getResolvedAutowireMode() == AUTOWIRE_CONSTRUCTOR ||
				mbd.hasConstructorArgumentValues() || !ObjectUtils.isEmpty(args)) {
            // 通过“构造方法自动注入”的方式构造 bean 对象
			return autowireConstructor(beanName, mbd, ctors, args);
		}

		ctors = mbd.getPreferredConstructors();
		if (ctors != null) {
			return autowireConstructor(beanName, mbd, ctors, null);
		}

		// 通过“默认构造方法”的方式构造 bean 对象
		return instantiateBean(beanName, mbd);
	}
```

### 通过构造方法自动注入的方式创建 bean 实例

```java
//ConstructorResolver.java
protected BeanWrapper autowireConstructor(
        String beanName, RootBeanDefinition mbd, Constructor<?>[] ctors, Object[] explicitArgs) {

    // 创建 ConstructorResolver 对象，并调用其 autowireConstructor 方法
    return new ConstructorResolver(this).autowireConstructor(beanName, mbd, ctors, explicitArgs);
}

public BeanWrapper autowireConstructor(final String beanName, final RootBeanDefinition mbd,
        Constructor<?>[] chosenCtors, final Object[] explicitArgs) {

    // 创建 BeanWrapperImpl 对象
    BeanWrapperImpl bw = new BeanWrapperImpl();
    this.beanFactory.initBeanWrapper(bw);

    Constructor<?> constructorToUse = null;
    ArgumentsHolder argsHolderToUse = null;
    Object[] argsToUse = null;

    // 确定参数值列表（argsToUse）
    if (explicitArgs != null) {
        argsToUse = explicitArgs;
    }
    else {
        Object[] argsToResolve = null;
        synchronized (mbd.constructorArgumentLock) {
            // 获取已解析的构造方法
            constructorToUse = (Constructor<?>) mbd.resolvedConstructorOrFactoryMethod;
            if (constructorToUse != null && mbd.constructorArgumentsResolved) {
                // 获取已解析的构造方法参数列表
                argsToUse = mbd.resolvedConstructorArguments;
                if (argsToUse == null) {
                    // 若 argsToUse 为空，则获取未解析的构造方法参数列表
                    argsToResolve = mbd.preparedConstructorArguments;
                }
            }
        }
        if (argsToResolve != null) {
            // 解析参数列表
            argsToUse = resolvePreparedArguments(beanName, mbd, bw, constructorToUse, argsToResolve);
        }
    }

    if (constructorToUse == null) {
        boolean autowiring = (chosenCtors != null ||
                mbd.getResolvedAutowireMode() == RootBeanDefinition.AUTOWIRE_CONSTRUCTOR);
        ConstructorArgumentValues resolvedValues = null;

        int minNrOfArgs;
        if (explicitArgs != null) {
            minNrOfArgs = explicitArgs.length;
        }
        else {
            ConstructorArgumentValues cargs = mbd.getConstructorArgumentValues();
            resolvedValues = new ConstructorArgumentValues();
            /*
             * 确定构造方法参数数量，比如下面的配置：
             *     <bean id="persion" class="xyz.coolblog.autowire.Person">
             *         <constructor-arg index="0" value="xiaoming"/>
             *         <constructor-arg index="1" value="1"/>
             *         <constructor-arg index="2" value="man"/>
             *     </bean>
             *
             * 此时 minNrOfArgs = maxIndex + 1 = 2 + 1 = 3，除了计算 minNrOfArgs，
             * 下面的方法还会将 cargs 中的参数数据转存到 resolvedValues 中
             */
            minNrOfArgs = resolveConstructorArguments(beanName, mbd, bw, cargs, resolvedValues);
        }

        // 获取构造方法列表
        Constructor<?>[] candidates = chosenCtors;
        if (candidates == null) {
            Class<?> beanClass = mbd.getBeanClass();
            try {
                candidates = (mbd.isNonPublicAccessAllowed() ?
                        beanClass.getDeclaredConstructors() : beanClass.getConstructors());
            }
            catch (Throwable ex) {
                throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                        "Resolution of declared constructors on bean Class [" + beanClass.getName() +
                        "] from ClassLoader [" + beanClass.getClassLoader() + "] failed", ex);
            }
        }

        // 按照构造方法的访问权限级别和参数数量进行排序
        AutowireUtils.sortConstructors(candidates);

        int minTypeDiffWeight = Integer.MAX_VALUE;
        Set<Constructor<?>> ambiguousConstructors = null;
        LinkedList<UnsatisfiedDependencyException> causes = null;

        for (Constructor<?> candidate : candidates) {
            Class<?>[] paramTypes = candidate.getParameterTypes();

            /*
             * 下面的 if 分支的用途是：若匹配到到合适的构造方法了，提前结束 for 循环
             * constructorToUse != null 这个条件比较好理解，下面分析一下条件 argsToUse.length > paramTypes.length：
             * 前面说到 AutowireUtils.sortConstructors(candidates) 用于对构造方法进行
             * 排序，排序规则如下：
             *   1. 具有 public 访问权限的构造方法排在非 public 构造方法前
             *   2. 参数数量多的构造方法排在前面
             *
             * 假设现在有一组构造方法按照上面的排序规则进行排序，排序结果如下（省略参数名称）：
             *
             *   1. public Hello(Object, Object, Object)
             *   2. public Hello(Object, Object)
             *   3. public Hello(Object)
             *   4. protected Hello(Integer, Object, Object, Object)
             *   5. protected Hello(Integer, Object, Object)
             *   6. protected Hello(Integer, Object)
             *
             * argsToUse = [num1, obj2]，可以匹配上的构造方法2和构造方法6。由于构造方法2有
             * 更高的访问权限，所以没理由不选他（尽管后者在参数类型上更加匹配）。由于构造方法3
             * 参数数量 < argsToUse.length，参数数量上不匹配，也不应该选。所以 
             * argsToUse.length > paramTypes.length 这个条件用途是：在条件 
             * constructorToUse != null 成立的情况下，通过判断参数数量与参数值数量
             * （argsToUse.length）是否一致，来决定是否提前终止构造方法匹配逻辑。
             */
            if (constructorToUse != null && argsToUse.length > paramTypes.length) {
                break;
            }

            /*
             * 构造方法参数数量低于配置的参数数量，则忽略当前构造方法，并重试。比如 
             * argsToUse = [obj1, obj2, obj3, obj4]，上面的构造方法列表中，
             * 构造方法1、2和3显然不是合适选择，忽略之。
             */
            if (paramTypes.length < minNrOfArgs) {
                continue;
            }

            ArgumentsHolder argsHolder;
            if (resolvedValues != null) {
                try {
                    /*
                     * 判断否则方法是否有 ConstructorProperties 注解，若有，则取注解中的
                     * 值。比如下面的代码：
                     * 
                     *  public class Persion {
                     *      private String name;
                     *      private Integer age;
                     *
                     *      @ConstructorProperties(value = {"coolblog", "20"})
                     *      public Persion(String name, Integer age) {
                     *          this.name = name;
                     *          this.age = age;
                     *      }
                     * }
                     */
                    String[] paramNames = ConstructorPropertiesChecker.evaluate(candidate, paramTypes.length);
                    if (paramNames == null) {
                        ParameterNameDiscoverer pnd = this.beanFactory.getParameterNameDiscoverer();
                        if (pnd != null) {
                            /*
                             * 获取构造方法参数名称列表，比如有这样一个构造方法:
                             *   public Person(String name, int age, String sex)
                             *   
                             * 调用 getParameterNames 方法返回 paramNames = [name, age, sex]
                             */
                            paramNames = pnd.getParameterNames(candidate);
                        }
                    }

                    /* 
                     * 创建参数值列表，返回 argsHolder 会包含进行类型转换后的参数值，比如下
                     * 面的配置:
                     *
                     *     <bean id="persion" class="xyz.coolblog.autowire.Person">
                     *         <constructor-arg name="name" value="xiaoming"/>
                     *         <constructor-arg name="age" value="1"/>
                     *         <constructor-arg name="sex" value="man"/>
                     *     </bean>
                     *
                     * Person 的成员变量 age 是 Integer 类型的，但由于在 Spring 配置中
                     * 只能配成 String 类型，所以这里要进行类型转换。
                     */
                    argsHolder = createArgumentArray(beanName, mbd, resolvedValues, bw, paramTypes, paramNames,
                            getUserDeclaredConstructor(candidate), autowiring);
                }
                catch (UnsatisfiedDependencyException ex) {
                    if (this.beanFactory.logger.isTraceEnabled()) {
                        this.beanFactory.logger.trace(
                                "Ignoring constructor [" + candidate + "] of bean '" + beanName + "': " + ex);
                    }
                    if (causes == null) {
                        causes = new LinkedList<UnsatisfiedDependencyException>();
                    }
                    causes.add(ex);
                    continue;
                }
            }
            else {
                if (paramTypes.length != explicitArgs.length) {
                    continue;
                }
                argsHolder = new ArgumentsHolder(explicitArgs);
            }

            /*
             * 计算参数值（argsHolder.arguments）每个参数类型与构造方法参数列表
             * （paramTypes）中参数的类型差异量，差异量越大表明参数类型差异越大。参数类型差异
             * 越大，表明当前构造方法并不是一个最合适的候选项。引入差异量（typeDiffWeight）
             * 变量目的：是将候选构造方法的参数列表类型与参数值列表类型的差异进行量化，通过量化
             * 后的数值筛选出最合适的构造方法。
             * 
             * 讲完差异量，再来说说 mbd.isLenientConstructorResolution() 条件。
             * 官方的解释是：返回构造方法的解析模式，有宽松模式（lenient mode）和严格模式
             * （strict mode）两种类型可选。具体的细节没去研究，就不多说了。
             */
            int typeDiffWeight = (mbd.isLenientConstructorResolution() ?
                    argsHolder.getTypeDifferenceWeight(paramTypes) : argsHolder.getAssignabilityWeight(paramTypes));
            if (typeDiffWeight < minTypeDiffWeight) {
                constructorToUse = candidate;
                argsHolderToUse = argsHolder;
                argsToUse = argsHolder.arguments;
                minTypeDiffWeight = typeDiffWeight;
                ambiguousConstructors = null;
            }
            /* 
             * 如果两个构造方法与参数值类型列表之间的差异量一致，那么这两个方法都可以作为
             * 候选项，这个时候就出现歧义了，这里先把有歧义的构造方法放入 
             * ambiguousConstructors 集合中
             */
            else if (constructorToUse != null && typeDiffWeight == minTypeDiffWeight) {
                if (ambiguousConstructors == null) {
                    ambiguousConstructors = new LinkedHashSet<Constructor<?>>();
                    ambiguousConstructors.add(constructorToUse);
                }
                ambiguousConstructors.add(candidate);
            }
        }

        // 若上面未能筛选出合适的构造方法，这里将抛出 BeanCreationException 异常
        if (constructorToUse == null) {
            if (causes != null) {
                UnsatisfiedDependencyException ex = causes.removeLast();
                for (Exception cause : causes) {
                    this.beanFactory.onSuppressedException(cause);
                }
                throw ex;
            }
            throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                    "Could not resolve matching constructor " +
                    "(hint: specify index/type/name arguments for simple parameters to avoid type ambiguities)");
        }
        /*
         * 如果 constructorToUse != null，且 ambiguousConstructors 也不为空，表明解析
         * 出了多个的合适的构造方法，此时就出现歧义了。Spring 不会擅自决定使用哪个构造方法，
         * 所以抛出异常。
         */
        else if (ambiguousConstructors != null && !mbd.isLenientConstructorResolution()) {
            throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                    "Ambiguous constructor matches found in bean '" + beanName + "' " +
                    "(hint: specify index/type/name arguments for simple parameters to avoid type ambiguities): " +
                    ambiguousConstructors);
        }

        if (explicitArgs == null) {
            /*
             * 缓存相关信息，比如：
             *   1. 已解析出的构造方法对象 resolvedConstructorOrFactoryMethod
             *   2. 构造方法参数列表是否已解析标志 constructorArgumentsResolved
             *   3. 参数值列表 resolvedConstructorArguments 或 preparedConstructorArguments
             *
             * 这些信息可用在其他地方，用于进行快捷判断
             */
            argsHolderToUse.storeCache(mbd, constructorToUse);
        }
    }

    try {
        Object beanInstance;

        if (System.getSecurityManager() != null) {
            final Constructor<?> ctorToUse = constructorToUse;
            final Object[] argumentsToUse = argsToUse;
            beanInstance = AccessController.doPrivileged(new PrivilegedAction<Object>() {
                @Override
                public Object run() {
                    return beanFactory.getInstantiationStrategy().instantiate(
                            mbd, beanName, beanFactory, ctorToUse, argumentsToUse);
                }
            }, beanFactory.getAccessControlContext());
        }
        else {
            /*
             * 调用实例化策略创建实例，默认情况下使用反射创建实例。如果 bean 的配置信息中
             * 包含 lookup-method 和 replace-method，则通过 CGLIB 增强 bean 实例
             */
            beanInstance = this.beanFactory.getInstantiationStrategy().instantiate(
                    mbd, beanName, this.beanFactory, constructorToUse, argsToUse);
        }

        // 设置 beanInstance 到 BeanWrapperImpl 对象中
        bw.setBeanInstance(beanInstance);
        return bw;
    }
    catch (Throwable ex) {
        throw new BeanCreationException(mbd.getResourceDescription(), beanName,
                "Bean instantiation via constructor failed", ex);
    }
}
```

1. 创建 BeanWrapperImpl 对象
2. 解析构造方法参数，并算出 minNrOfArgs
3. 获取构造方法列表，并排序
4. 遍历排序好的构造方法列表，筛选合适的构造方法
   1. 获取构造方法参数列表中每个参数的名称
   2. 再次解析参数，此次解析会将value 属性值进行类型转换，由 String 转为合适的类型。
   3. 计算构造方法参数列表与参数值列表之间的类型差异量，以筛选出更为合适的构造方法
5. 缓存已筛选出的构造方法以及参数值列表，若再次创建 bean 实例时，可直接使用，无需再次进行筛选
6. 使用初始化策略创建 bean 对象
7. 将 bean 对象放入 BeanWrapperImpl 对象中，并返回该对象

### 通过默认构造方法创建 bean 对象

```java
protected BeanWrapper instantiateBean(final String beanName, final RootBeanDefinition mbd) {
    try {
        Object beanInstance;
        final BeanFactory parent = this;
        // if 条件分支里的一大坨是 Java 安全相关的代码，可以忽略，直接看 else 分支
        if (System.getSecurityManager() != null) {
            beanInstance = AccessController.doPrivileged(new PrivilegedAction<Object>() {
                @Override
                public Object run() {
                    return getInstantiationStrategy().instantiate(mbd, beanName, parent);
                }
            }, getAccessControlContext());
        }
        else {
            /*
             * 调用实例化策略创建实例，默认情况下使用反射创建对象。如果 bean 的配置信息中
             * 包含 lookup-method 和 replace-method，则通过 CGLIB 创建 bean 对象
             */
            beanInstance = getInstantiationStrategy().instantiate(mbd, beanName, parent);
        }
        // 创建 BeanWrapperImpl 对象
        BeanWrapper bw = new BeanWrapperImpl(beanInstance);
        initBeanWrapper(bw);
        return bw;
    }
    catch (Throwable ex) {
        throw new BeanCreationException(
                mbd.getResourceDescription(), beanName, "Instantiation of bean failed", ex);
    }
}

public Object instantiate(RootBeanDefinition bd, String beanName, BeanFactory owner) {
    // 检测 bean 配置中是否配置了 lookup-method 或 replace-method，若配置了，则需使用 CGLIB 构建 bean 对象
    if (bd.getMethodOverrides().isEmpty()) {
        Constructor<?> constructorToUse;
        synchronized (bd.constructorArgumentLock) {
            constructorToUse = (Constructor<?>) bd.resolvedConstructorOrFactoryMethod;
            if (constructorToUse == null) {
                final Class<?> clazz = bd.getBeanClass();
                if (clazz.isInterface()) {
                    throw new BeanInstantiationException(clazz, "Specified class is an interface");
                }
                try {
                    if (System.getSecurityManager() != null) {
                        constructorToUse = AccessController.doPrivileged(new PrivilegedExceptionAction<Constructor<?>>() {
                            @Override
                            public Constructor<?> run() throws Exception {
                                return clazz.getDeclaredConstructor((Class[]) null);
                            }
                        });
                    }
                    else {
                        // 获取默认构造方法
                        constructorToUse = clazz.getDeclaredConstructor((Class[]) null);
                    }
                    // 设置 resolvedConstructorOrFactoryMethod
                    bd.resolvedConstructorOrFactoryMethod = constructorToUse;
                }
                catch (Throwable ex) {
                    throw new BeanInstantiationException(clazz, "No default constructor found", ex);
                }
            }
        }
        // 通过无参构造方法创建 bean 对象
        return BeanUtils.instantiateClass(constructorToUse);
    }
    else {
        // 使用 GCLIG 创建 bean 对象
        return instantiateWithMethodInjection(bd, beanName, owner);
    }
}

	// 通过无参构造方法创建 bean 对象
	public static <T> T instantiateClass(Constructor<T> ctor, Object... args) throws BeanInstantiationException {
		Assert.notNull(ctor, "Constructor must not be null");
		try {
            // 设置构造方法为可访问
			ReflectionUtils.makeAccessible(ctor);
			if (KotlinDetector.isKotlinReflectPresent() && KotlinDetector.isKotlinType(ctor.getDeclaringClass())) {
				return KotlinDelegate.instantiateClass(ctor, args);
			}
			else {
				Class<?>[] parameterTypes = ctor.getParameterTypes();
				Assert.isTrue(args.length <= parameterTypes.length, "Can't specify more arguments than constructor parameters");
				Object[] argsWithDefaultValues = new Object[args.length];
				for (int i = 0 ; i < args.length; i++) {
					if (args[i] == null) {
						Class<?> parameterType = parameterTypes[i];
						argsWithDefaultValues[i] = (parameterType.isPrimitive() ? DEFAULT_TYPE_VALUES.get(parameterType) : null);
					}
					else {
						argsWithDefaultValues[i] = args[i];
					}
				}
				return ctor.newInstance(argsWithDefaultValues);
			}
		}
		catch (InstantiationException ex) {
			throw new BeanInstantiationException(ctor, "Is it an abstract class?", ex);
		}
		catch (IllegalAccessException ex) {
			throw new BeanInstantiationException(ctor, "Is the constructor accessible?", ex);
		}
		catch (IllegalArgumentException ex) {
			throw new BeanInstantiationException(ctor, "Illegal arguments for constructor", ex);
		}
		catch (InvocationTargetException ex) {
			throw new BeanInstantiationException(ctor, "Constructor threw exception", ex.getTargetException());
		}
	}
```

## 属性填充 ->populateBean

```java
	protected void populateBean(String beanName, RootBeanDefinition mbd, @Nullable BeanWrapper bw) {
		if (bw == null) {
			if (mbd.hasPropertyValues()) {
				throw new BeanCreationException(
						mbd.getResourceDescription(), beanName, "Cannot apply property values to null instance");
			}
			else {
				// Skip property population phase for null instance.
				return;
			}
		}

		// Give any InstantiationAwareBeanPostProcessors the opportunity to modify the
		// state of the bean before properties are set. This can be used, for example,
		// to support styles of field injection.
		boolean continueWithPropertyPopulation = true;

		if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
			for (BeanPostProcessor bp : getBeanPostProcessors()) {
				if (bp instanceof InstantiationAwareBeanPostProcessor) {
					InstantiationAwareBeanPostProcessor ibp = (InstantiationAwareBeanPostProcessor) bp;
					if (!ibp.postProcessAfterInstantiation(bw.getWrappedInstance(), beanName)) {
						continueWithPropertyPopulation = false;
						break;
					}
				}
			}
		}

		if (!continueWithPropertyPopulation) {
			return;
		}

		PropertyValues pvs = (mbd.hasPropertyValues() ? mbd.getPropertyValues() : null);

		int resolvedAutowireMode = mbd.getResolvedAutowireMode();
		if (resolvedAutowireMode == AUTOWIRE_BY_NAME || resolvedAutowireMode == AUTOWIRE_BY_TYPE) {
			MutablePropertyValues newPvs = new MutablePropertyValues(pvs);
			// 名称注入
			if (resolvedAutowireMode == AUTOWIRE_BY_NAME) {
				autowireByName(beanName, mbd, bw, newPvs);
			}
			// 类型注入
			if (resolvedAutowireMode == AUTOWIRE_BY_TYPE) {
				autowireByType(beanName, mbd, bw, newPvs);
			}
			pvs = newPvs;
		}
 		// 后处理器已经初始化
		boolean hasInstAwareBpps = hasInstantiationAwareBeanPostProcessors();
        // 需要依赖检查
		boolean needsDepCheck = (mbd.getDependencyCheck() != AbstractBeanDefinition.DEPENDENCY_CHECK_NONE);

		PropertyDescriptor[] filteredPds = null;
		if (hasInstAwareBpps) {
			if (pvs == null) {
				pvs = mbd.getPropertyValues();
			}
			for (BeanPostProcessor bp : getBeanPostProcessors()) {
				if (bp instanceof InstantiationAwareBeanPostProcessor) {
					InstantiationAwareBeanPostProcessor ibp = (InstantiationAwareBeanPostProcessor) bp;
                    // 对所有需要依赖检查的属性进行后置处理
					PropertyValues pvsToUse = ibp.postProcessProperties(pvs, bw.getWrappedInstance(), beanName);
					if (pvsToUse == null) {
						if (filteredPds == null) {
							filteredPds = filterPropertyDescriptorsForDependencyCheck(bw, mbd.allowCaching);
						}
						pvsToUse = ibp.postProcessPropertyValues(pvs, filteredPds, bw.getWrappedInstance(), beanName);
						if (pvsToUse == null) {
							return;
						}
					}
					pvs = pvsToUse;
				}
			}
		}
		if (needsDepCheck) {
			if (filteredPds == null) {
				filteredPds = filterPropertyDescriptorsForDependencyCheck(bw, mbd.allowCaching);
			}
			checkDependencies(beanName, mbd, filteredPds, pvs);
		}

		if (pvs != null) {
			applyPropertyValues(beanName, mbd, bw, pvs);
		}
	}
```



## 执行初始化方法 ->initializeBean

```java
	    /*
         * 进行余下的初始化工作，详细如下：
         * 1. 判断 bean 是否实现了 BeanNameAware、BeanFactoryAware、
         *    BeanClassLoaderAware 等接口，并执行接口方法
         * 2. 应用 bean 初始化前置操作
         * 3. 如果 bean 实现了 InitializingBean 接口，则执行 afterPropertiesSet 
         *    方法。如果用户配置了 init-method，则调用相关方法执行自定义初始化逻辑
         * 4. 应用 bean 初始化后置操作
         * 
         * 另外，AOP 相关逻辑也会在该方法中织入切面逻辑，此时的 exposedObject 就变成了
         * 一个代理对象了
         */
	protected Object initializeBean(final String beanName, final Object bean, @Nullable RootBeanDefinition mbd) {
		if (System.getSecurityManager() != null) {
			AccessController.doPrivileged((PrivilegedAction<Object>) () -> {
                // 执行用户自定义的各种 aware 方法
				invokeAwareMethods(beanName, bean);
				return null;
			}, getAccessControlContext());
		}
		else {
			invokeAwareMethods(beanName, bean);
		}

		Object wrappedBean = bean;
		if (mbd == null || !mbd.isSynthetic()) {
            // 在执行 init 方法之前，先执行 前置处理器 applyBeanPostProcessorsBeforeInitialization
			wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
		}

		try {
            // 执行初始化方法
			invokeInitMethods(beanName, wrappedBean, mbd);
		}
		catch (Throwable ex) {
			throw new BeanCreationException(
					(mbd != null ? mbd.getResourceDescription() : null),
					beanName, "Invocation of init method failed", ex);
		}
        // 执行后置处理器 applyBeanPostProcessorsAfterInitialization
		if (mbd == null || !mbd.isSynthetic()) {
			wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
		}

		return wrappedBean;
	}

	private void invokeAwareMethods(final String beanName, final Object bean) {
		if (bean instanceof Aware) {
			if (bean instanceof BeanNameAware) {
				((BeanNameAware) bean).setBeanName(beanName);
			}
			if (bean instanceof BeanClassLoaderAware) {
				ClassLoader bcl = getBeanClassLoader();
				if (bcl != null) {
					((BeanClassLoaderAware) bean).setBeanClassLoader(bcl);
				}
			}
			if (bean instanceof BeanFactoryAware) {
				((BeanFactoryAware) bean).setBeanFactory(AbstractAutowireCapableBeanFactory.this);
			}
		}
	}
```

## getBean全流程图



![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/getBean%E5%85%A8%E6%B5%81%E7%A8%8B.jpg)