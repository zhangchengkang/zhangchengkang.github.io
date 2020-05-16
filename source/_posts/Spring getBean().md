---
title: Spring源码分析(二) GetBean()
date: 2019-11-09 19:02:01
author: kangshifu
img: 
top: false
cover: false
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



## FactoryBean 接口

这个接口和 BeanFactory 接口非常的像，但是作用却截然不同，先来看看 javadoc 文档的定义，大致意思就是：如果某个 bean 实现了这个接口，通过 getBean 方法来获取 bean 的时候，并不是返回自己的实例，而是返回其 getObject() 方法的返回值；此外 FactoryBeans 可以支持 singletons 和  prototypes 模式。它的源码如下，只有 三个方法：

```java
public interface FactoryBean<T> {
	String OBJECT_TYPE_ATTRIBUTE = "factoryBeanObjectType";

    //getBean 方法获取到的是 getObject 方法的返回值，而不是 FactoryBean 实例本身；但是，如果就想获取到 FactoryBean 的实例本身，也是可以的，在 bean 的名字前加 & 符号就可以了，即 getBean("&beanName")；
	@Nullable
	T getObject() throws Exception;

    // 返回 bean 的类型
	@Nullable
	Class<?> getObjectType();

    // 该 bean 是否是单例模式
	default boolean isSingleton() {
		return true;
	}
}
```

我们熟知的第三方 ORM 框架 Mybatis 也提供了该接口的实现 SqlSessionFactoryBean ：

```java
<bean id="sqlSessionFactory" class="org.mybatis.spring.SqlSessionFactoryBean">
	// 其他配置
</bean>

public class SqlSessionFactoryBean implements FactoryBean<SqlSessionFactory>, InitializingBean, ApplicationListener<ApplicationEvent> {
  private SqlSessionFactory sqlSessionFactory;
  //所以通过 getBean 方法获取的时候，得到的是 SqlSessionFactory 而不是 SqlSessionFactoryBean
  @Override
  public SqlSessionFactory getObject() throws Exception {
    if (this.sqlSessionFactory == null) {
      afterPropertiesSet();
    }

    return this.sqlSessionFactory;
  }
}
```

## BeanFactory 接口 

BeanFactory 它是 Spring  IOC 容器的核心接口，它定义了 容器的主要功能，如创建 bean，获取 bean 等，它是用来管理 bean 的，即它是用来 实例化、定位、配置应用程序中的对象及建立这些对象间的依赖关系的。它的源码如下：

```java
public interface BeanFactory {
    //表示 FactoryBean 接口的 beanName 的前缀。
	String FACTORY_BEAN_PREFIX = "&";
	Object getBean(String name) throws BeansException;
	<T> T getBean(String name, Class<T> requiredType) throws BeansException;
	Object getBean(String name, Object... args) throws BeansException;
	<T> T getBean(Class<T> requiredType) throws BeansException;
	<T> T getBean(Class<T> requiredType, Object... args) throws BeansException;
	boolean containsBean(String name);
	boolean isSingleton(String name) throws NoSuchBeanDefinitionException;
	boolean isPrototype(String name) throws NoSuchBeanDefinitionException;
	boolean isTypeMatch(String name, ResolvableType typeToMatch);
	boolean isTypeMatch(String name, Class<?> typeToMatch) throws NoSuchBeanDefinitionException;
	Class<?> getType(String name) throws NoSuchBeanDefinitionException;
	String[] getAliases(String name);
}
```

FactoryBean 可以看做一个工厂，用它来创建一些负责的 bean

BeanFactory 定义了 Spring 容器基本的功能，交由子类去实现，用于管理 bean

## getBean()

废话不多说 ,下面直接进入源码分析

```java
	@Override
	public Object getBean(String name) throws BeansException {
		return doGetBean(name, null, null, false);
	}

	protected <T> T doGetBean(final String name, @Nullable final Class<T> requiredType,
							  @Nullable final Object[] args, boolean typeCheckOnly) throws BeansException {
		// 提取对应的 beanName，处理别名和FactoryBean接口的实现类，即 beanName 以 & 开头
		final String beanName = transformedBeanName(name);
		Object bean;

		// 从缓存中或者实例工厂中获取 Bean 对象
		Object sharedInstance = getSingleton(beanName);
		// 如果 sharedInstance = null，则说明缓存里没有对应的实例，表明这个实例还没创建。
		if (sharedInstance != null && args == null) {
			if (logger.isTraceEnabled()) {
				if (isSingletonCurrentlyInCreation(beanName)) {
					logger.trace("Returning eagerly cached instance of singleton bean '" + beanName +
							"' that is not fully initialized yet - a consequence of a circular reference");
				} else {
					logger.trace("Returning cached instance of singleton bean '" + beanName + "'");
				}
			}
			/*
			 * 如果 sharedInstance 是普通的单例 bean，下面的方法会直接返回。但如果
			 * sharedInstance 是 FactoryBean 类型的，则需调用 getObject 工厂方法获取真正的
			 * bean 实例。如果用户想获取 FactoryBean 本身，这里也不会做特别的处理，直接返回
			 * 即可。毕竟 FactoryBean 的实现类本身也是一种 bean，只不过具有一点特殊的功能而已。
			 */
			bean = getObjectForBeanInstance(sharedInstance, name, beanName, null);
		}

		/*
		 * 如果上面的条件不满足，则表明 sharedInstance 可能为空，此时 beanName 对应的 bean
		 * 实例可能还未创建。这里还存在另一种可能，如果当前容器有父容器，beanName 对应的 bean 实例
		 * 可能是在父容器中被创建了，所以在创建实例前，需要先去父容器里检查一下。
		 */
		else {
			// BeanFactory 不缓存 Prototype 类型的 bean，无法处理该类型 bean 的循环依赖问题
			if (isPrototypeCurrentlyInCreation(beanName)) {
				throw new BeanCurrentlyInCreationException(beanName);
			}

			// 如果当前的的beanDefinitionMap即配置文件不包含该bean，则从父容器中查找
			BeanFactory parentBeanFactory = getParentBeanFactory();
			if (parentBeanFactory != null && !containsBeanDefinition(beanName)) {
				// 获取 name 对应的 beanName，如果 name 是以 & 字符开头，则返回 & + beanName
				String nameToLookup = originalBeanName(name);
				// 根据 args 是否为空，以决定调用父容器哪个方法获取 bean
				if (parentBeanFactory instanceof AbstractBeanFactory) {
					return ((AbstractBeanFactory) parentBeanFactory).doGetBean(
							nameToLookup, requiredType, args, typeCheckOnly);
				} else if (args != null) {
					return (T) parentBeanFactory.getBean(nameToLookup, args);
				} else if (requiredType != null) {
					return parentBeanFactory.getBean(nameToLookup, requiredType);
				} else {
					return (T) parentBeanFactory.getBean(nameToLookup);
				}
			}

			// 如果不仅仅是做类型检查，则是创建bean，则进行标记，标记该bean以创建
			if (!typeCheckOnly) {
				markBeanAsCreated(beanName);
			}

			try {
				// 将配置文件中GenericBeanDefinition转换为RootBeanDefinition，如果beanName是子bean的话，会合并父类的属性
				final RootBeanDefinition mbd = getMergedLocalBeanDefinition(beanName);
				checkMergedBeanDefinition(mbd, beanName, args);

				// 处理依赖，如果存在依赖，则递归实例化依赖的bean
				String[] dependsOn = mbd.getDependsOn();
				if (dependsOn != null) {
					for (String dep : dependsOn) {
						/*
						 * 检测是否存在 depends-on 循环依赖，若存在则抛异常。比如 A 依赖 B，
						 * B 又依赖 A，他们的配置如下：
						 *   <bean id="beanA" class="BeanA" depends-on="beanB">
						 *   <bean id="beanB" class="BeanB" depends-on="beanA">
						 *
						 * beanA 要求 beanB 在其之前被创建，但 beanB 又要求 beanA 先于它
						 * 创建。这个时候形成了循环，对于 depends-on 循环，Spring 会直接
						 * 抛出异常
						 */
						if (isDependent(beanName, dep)) {
							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
									"Circular depends-on relationship between '" + beanName + "' and '" + dep + "'");
						}
						// 注册依赖记录
						registerDependentBean(dep, beanName);
						try {
							// 加载 depends-on 依赖
							getBean(dep);
						} catch (NoSuchBeanDefinitionException ex) {
							throw new BeanCreationException(mbd.getResourceDescription(), beanName,
									"'" + beanName + "' depends on missing bean '" + dep + "'", ex);
						}
					}
				}

				// 创建 bean 实例
				if (mbd.isSingleton()) {
					sharedInstance = getSingleton(beanName, () -> {
						try {
							/*
							 * 这里并没有直接调用 createBean 方法创建 bean 实例，而是通过
							 * getSingleton(String, ObjectFactory) 方法获取 bean 实例。
							 * getSingleton(String, ObjectFactory) 方法会在内部调用
							 * ObjectFactory 的 getObject() 方法创建 bean，并会在创建完成后，
							 * 将 bean 放入缓存中。
							 */
							return createBean(beanName, mbd, args);
						} catch (BeansException ex) {
							destroySingleton(beanName);
							throw ex;
						}
					});
					// 如果 bean 是 FactoryBean 类型，则调用工厂方法获取真正的 bean 实例。否则直接返回 bean 实例
					bean = getObjectForBeanInstance(sharedInstance, name, beanName, mbd);
				} else if (mbd.isPrototype()) {
					// 创建 prototype 类型的 bean 实例
					Object prototypeInstance = null;
					try {
						beforePrototypeCreation(beanName);
						prototypeInstance = createBean(beanName, mbd, args);
					} finally {
						afterPrototypeCreation(beanName);
					}
					bean = getObjectForBeanInstance(prototypeInstance, name, beanName, mbd);
				} else {
					// 创建其他类型的 bean 实例
					String scopeName = mbd.getScope();
					final Scope scope = this.scopes.get(scopeName);
					if (scope == null) {
						throw new IllegalStateException("No Scope registered for scope name '" + scopeName + "'");
					}
					try {
						Object scopedInstance = scope.get(beanName, () -> {
							beforePrototypeCreation(beanName);
							try {
								return createBean(beanName, mbd, args);
							} finally {
								afterPrototypeCreation(beanName);
							}
						});
						bean = getObjectForBeanInstance(scopedInstance, name, beanName, mbd);
					} catch (IllegalStateException ex) {
						throw new BeanCreationException(beanName,
								"Scope '" + scopeName + "' is not active for the current thread; consider " +
										"defining a scoped proxy for this bean if you intend to refer to it from a singleton",
								ex);
					}
				}
			} catch (BeansException ex) {
				cleanupAfterBeanCreationFailure(beanName);
				throw ex;
			}
		}

		// 处理参数类型的转换
		if (requiredType != null && !requiredType.isInstance(bean)) {
			try {
				T convertedBean = getTypeConverter().convertIfNecessary(bean, requiredType);
				if (convertedBean == null) {
					throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
				}
				return convertedBean;
			} catch (TypeMismatchException ex) {
				if (logger.isTraceEnabled()) {
					logger.trace("Failed to convert bean '" + name + "' to required type '" +
							ClassUtils.getQualifiedName(requiredType) + "'", ex);
				}
				throw new BeanNotOfRequiredTypeException(name, requiredType, bean.getClass());
			}
		}
		return (T) bean;
	}

```

doGetBean执行流程总结:

1. 转换 beanName
2. 从缓存中获取实例
3. 如果实例不为空，且 args = null。调用 getObjectForBeanInstance 方法，并按 name 规则返回相应的 bean 实例
4. 若上面的条件不成立，则到父容器中查找 beanName 对有的 bean 实例，存在则直接返回
5. 若父容器中不存在，则进行下一步操作 – 合并 BeanDefinition
6. 处理 depends-on 依赖
7. 创建并缓存 bean
8. 调用 getObjectForBeanInstance 方法，并按 name 规则返回相应的 bean 实例
9. 按需转换 bean 类型，并返回转换后的 bean 实例。

![](https://blog-1257031229.cos.ap-shanghai.myqcloud.com/spring/getBean%E6%B5%81%E7%A8%8B%E5%9B%BE.jpg)

### beanName 转换 ->transformedBeanName

```java
	//AbstractBeanFactory.java
    protected String transformedBeanName(String name) {
		return canonicalName(BeanFactoryUtils.transformedBeanName(name));
	}
```

```java
	//BeanFactoryUtils.java
	// 使用工具类 BeanFactoryUtils 来转名字
	public static String transformedBeanName(String name) {
		Assert.notNull(name, "'name' must not be null");
		if (!name.startsWith(BeanFactory.FACTORY_BEAN_PREFIX)) {
			return name;
		}
        // 如果 beanName 以 & 开头，则去掉 &,并添加到transformedBeanNameCache中
        //computeIfAbsent->如果map里没有这个key，那么就按照后面的这个function添加对应的key和value
		return transformedBeanNameCache.computeIfAbsent(name, beanName -> {
			do {
				beanName = beanName.substring(BeanFactory.FACTORY_BEAN_PREFIX.length());
			}
			while (beanName.startsWith(BeanFactory.FACTORY_BEAN_PREFIX));
            // 返回去掉 & 后的 beanName
			return beanName;
		});
	}
```

```java
	//SimpleAliasRegistry.java
	//该方法用于转换别名,返回原始的bean的名字
	public String canonicalName(String name) {
		String canonicalName = name;
		String resolvedName;
        // while 循环，因为 bean 的别名可以有多个
		do {
			resolvedName = this.aliasMap.get(canonicalName);
			if (resolvedName != null) {
				canonicalName = resolvedName;
			}
		}
		while (resolvedName != null);
		return canonicalName;
	}
```



### 从缓存中获取 bean 实例 ->getSingleton

```java
	//用于存放完全初始化好的 bean，从该缓存中取出的 bean 可以直接使用
	private final Map<String, Object> singletonObjects = new ConcurrentHashMap<>(256);
	// 用于存放 bean 工厂。bean 工厂所产生的 bean 是还未完成初始化的 bean。如代码所示，bean 工厂所生成的对象最终会被缓存到 earlySingletonObjects 中
	private final Map<String, ObjectFactory<?>> singletonFactories = new HashMap<>(16);
	//用于存放还在初始化中的 bean，用于解决循环依赖
	private final Map<String, Object> earlySingletonObjects = new HashMap<>(16);


    //DefaultSingletonBeanRegistry
	public Object getSingleton(String beanName) {
		return getSingleton(beanName, true);
	}

	//allowEarlyReference      表示是否允许其他 bean 引用
	protected Object getSingleton(String beanName, boolean allowEarlyReference) {
		// 从 singletonObjects 获取实例，singletonObjects 中缓存的实例都是完全实例化好的 bean，可以直接使用
		Object singletonObject = this.singletonObjects.get(beanName);
		if (singletonObject == null && isSingletonCurrentlyInCreation(beanName)) {
			synchronized (this.singletonObjects) {
				// 从 earlySingletonObjects 中获取提前曝光的 bean，用于处理循环引用
				singletonObject = this.earlySingletonObjects.get(beanName);
				// 如果如果 singletonObject = null，且允许提前曝光 bean 实例，则从相应的 ObjectFactory 获取一个原始的bean（尚未填充属性）
				if (singletonObject == null && allowEarlyReference) {
					// 获取相应的工厂类
					ObjectFactory<?> singletonFactory = this.singletonFactories.get(beanName);
					if (singletonFactory != null) {
						// 提前曝光 bean 实例，用于解决循环依赖
						singletonObject = singletonFactory.getObject();
						// 放入缓存中，如果还有其他 bean 依赖当前 bean，其他 bean 可以直接从 earlySingletonObjects 取结果
						this.earlySingletonObjects.put(beanName, singletonObject);
						this.singletonFactories.remove(beanName);
					}
				}
			}
		}
		return singletonObject;
	}
```

先从 singletonObjects 获取实例，如果获取不到，即该 bean 还没有创建；再从 earlySingletonObjects 获取，如果获取不到，即该bean没有正在创建，再从 ObjectFactory 获取对应的工厂来创建，如果到最后还是获取不到，则返回 null



###  合并父 BeanDefinition 与子 BeanDefinition ->getMergedLocalBeanDefinition

Spring 支持配置继承，在标签中可以使用parent属性配置父类 bean。这样子类 bean 可以继承父类 bean 的配置信息，同时也可覆盖父类中的配置。比如下面的配置：

```xml
<bean id="hello" class="xyz.coolblog.innerbean.Hello">
    <property name="content" value="hello"/>
</bean>

<bean id="hello-child" parent="hello">
    <property name="content" value="I`m hello-child"/>
</bean>
```

因为从 XML 配置文件中读取到的 Bean 信息是存储在GenericBeanDefinition 中的。但是，所有的 Bean 后续处理都是针对于 RootBeanDefinition 的，所以这里需要进行一个转换。

转换的同时，如果父类 bean 不为空的话，则会一并合并父类的属性。

```java
// AbstractBeanFactory.java

/** Map from bean name to merged RootBeanDefinition. */
private final Map<String, RootBeanDefinition> mergedBeanDefinitions = new ConcurrentHashMap<>(256);

protected RootBeanDefinition getMergedLocalBeanDefinition(String beanName) throws BeansException {
    // 快速从缓存中获取，如果不为空，则直接返回
    RootBeanDefinition mbd = this.mergedBeanDefinitions.get(beanName);
    if (mbd != null) {
        return mbd;
    }
    // 获取 RootBeanDefinition，
    // 如果返回的 BeanDefinition 是子类 bean 的话，则合并父类相关属性
    return getMergedBeanDefinition(beanName, getBeanDefinition(beanName));

```



### 从 FactoryBean 中获取 bean 实例 ->getObjectForBeanInstance

```java
// AbstractBeanFactory.java

protected Object getObjectForBeanInstance(
        Object beanInstance, String name, String beanName, @Nullable RootBeanDefinition mbd) {
    //  若为工厂类引用（name 以 & 开头）
    if (BeanFactoryUtils.isFactoryDereference(name)) {
        // 如果是 NullBean，则直接返回
        if (beanInstance instanceof NullBean) {
            return beanInstance;
        }
        // 如果 beanInstance 不是 FactoryBean 类型，则抛出异常
        if (!(beanInstance instanceof FactoryBean)) {
            throw new BeanIsNotAFactoryException(transformedBeanName(name), beanInstance.getClass());
        }
    }

   /*
	* 如果上面的判断通过了，表明 beanInstance 可能是一个普通的 bean，也可能是一个FactoryBean。
    * 如果是一个普通的 bean，这里直接返回 beanInstance 即可。
    * 如果是FactoryBean，则要调用工厂方法生成一个 bean 实例。
	*/
    if (!(beanInstance instanceof FactoryBean) || BeanFactoryUtils.isFactoryDereference(name)) {
        return beanInstance;
    }

    Object object = null;
    // 若 BeanDefinition 为 null，则从缓存中加载 Bean 对象
    if (mbd == null) {
        object = getCachedObjectForFactoryBean(beanName);
    }
    // 若 object 依然为空，则可以确认，beanInstance 一定是 FactoryBean 。从而，使用 FactoryBean 获得 Bean 对象
    if (object == null) {
        FactoryBean<?> factory = (FactoryBean<?>) beanInstance;
        // containsBeanDefinition 检测 beanDefinitionMap 中也就是在所有已经加载的类中
        // 检测是否定义 beanName
        if (mbd == null && containsBeanDefinition(beanName)) {
            // 将存储 XML 配置文件的 GenericBeanDefinition 转换为 RootBeanDefinition，
            // 如果指定 BeanName 是子 Bean 的话同时会合并父类的相关属性
            mbd = getMergedLocalBeanDefinition(beanName);
        }
        // 是否是用户定义的，而不是应用程序本身定义的
        boolean synthetic = (mbd != null && mbd.isSynthetic());
        // 核心处理方法，使用 FactoryBean 获得 Bean 对象
        object = getObjectFromFactoryBean(factory, beanName, !synthetic);
    }
    return object;
}
```

```java
// FactoryBeanRegistrySupport.java

/**
 * 缓存 FactoryBean 创建的单例 Bean 对象的映射
 * beanName ===> Bean 对象
 */
private final Map<String, Object> factoryBeanObjectCache = new ConcurrentHashMap<>(16);

protected Object getObjectFromFactoryBean(FactoryBean<?> factory, String beanName, boolean shouldPostProcess) {
    /*
     * FactoryBean 也有单例和非单例之分，针对不同类型的 FactoryBean，这里有两种处理方式：
     *   1. 单例 FactoryBean 生成的 bean 实例也认为是单例类型。需放入缓存中，供后续重复使用
     *   2. 非单例 FactoryBean 生成的 bean 实例则不会被放入缓存中，每次都会创建新的实例
     */
    if (factory.isSingleton() && containsSingleton(beanName)) {
        synchronized (getSingletonMutex()) { // 单例锁
            // 从缓存中获取指定的 factoryBean
            Object object = this.factoryBeanObjectCache.get(beanName);
            if (object == null) {
                // 为空，则从 FactoryBean 中获取对象
                object = doGetObjectFromFactoryBean(factory, beanName);
                // 从缓存中获取
                Object alreadyThere = this.factoryBeanObjectCache.get(beanName);
                if (alreadyThere != null) {
                    object = alreadyThere;
                } else {
                    //  需要后续处理
                    if (shouldPostProcess) {
                        // 若该 Bean 处于创建中，则返回非处理对象，而不是存储它
                        if (isSingletonCurrentlyInCreation(beanName)) {
                            return object;
                        }
                        // 单例 Bean 的前置处理
                        beforeSingletonCreation(beanName);
                        try {
                            // 对从 FactoryBean 获取的对象进行后处理
                            // 生成的对象将暴露给 bean 引用
                            object = postProcessObjectFromFactoryBean(object, beanName);
                        } catch (Throwable ex) {
                            throw new BeanCreationException(beanName,
                                    "Post-processing of FactoryBean's singleton object failed", ex);
                        } finally {
                            // 单例 Bean 的后置处理
                            afterSingletonCreation(beanName);
                        }
                    }
                    // <1.4> 添加到 factoryBeanObjectCache 中，进行缓存
                    if (containsSingleton(beanName)) {
                        this.factoryBeanObjectCache.put(beanName, object);
                    }
                }
            }
            return object;
        }
   // 获取非单例实例
    } else {
        // 为空，则从 FactoryBean 中获取对象
        Object object = doGetObjectFromFactoryBean(factory, beanName);
        // 需要后续处理
        if (shouldPostProcess) {
            try {
                // 对从 FactoryBean 获取的对象进行后处理
                // 生成的对象将暴露给 bean 引用
                object = postProcessObjectFromFactoryBean(object, beanName);
            }
            catch (Throwable ex) {
                throw new BeanCreationException(beanName, "Post-processing of FactoryBean's object failed", ex);
            }
        }
        return object;
    }

    
    private Object doGetObjectFromFactoryBean(final FactoryBean<?> factory, final String beanName)
    throws BeanCreationException {
    Object object;
    try {
        // if 分支的逻辑是 Java 安全方面的代码，可以忽略，直接看 else 分支的代码
        if (System.getSecurityManager() != null) {
            AccessControlContext acc = getAccessControlContext();
            try {
                // 从 FactoryBean 中，获得 Bean 对象
                object = AccessController.doPrivileged((PrivilegedExceptionAction<Object>) factory::getObject, acc);
            } catch (PrivilegedActionException pae) {
                throw pae.getException();
            }
        } else {
            // 从 FactoryBean 中，获得 Bean 对象
            object = factory.getObject();
        }
    } catch (FactoryBeanNotInitializedException ex) {
        throw new BeanCurrentlyInCreationException(beanName, ex.toString());
    } catch (Throwable ex) {
        throw new BeanCreationException(beanName, "FactoryBean threw exception on object creation", ex);
    }
    if (object == null) {
        if (isSingletonCurrentlyInCreation(beanName)) {
            throw new BeanCurrentlyInCreationException(
                    beanName, "FactoryBean which is currently in creation returned null from getObject");
        }
        object = new NullBean();
    }
    return object;
}
```

getObjectForBeanInstance 及它所调用的方法主要做了如下几件事情：

1. 检测参数 beanInstance 的类型，如果是非 FactoryBean 类型的 bean，直接返回
2. 检测 FactoryBean 实现类是否单例类型，针对单例和非单例类型进行不同处理
3. 对于单例 FactoryBean，先从缓存里获取 FactoryBean 生成的实例
4. 若缓存未命中，则调用 FactoryBean.getObject() 方法生成实例，并放入缓存中
5. 对于非单例的 FactoryBean，每次直接创建新的实例即可，无需缓存
6. 如果 shouldPostProcess = true，不管是单例还是非单例 FactoryBean 生成的实例，都要进行后置处理

###  











