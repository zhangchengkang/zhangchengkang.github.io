---
toc: true
title: ThreadLocal
date: 2018-07-20 20:07:33
tags: [Java 并发]
categories: JAVA
---
*Add this line to Using the more label,but it's too short to look bad,addition point length*
<!--more--> 

## ThreadLocal 概述
　　**ThreadLocal 又名 线程局部变量 ，是 Java 中一种较为特殊的线程绑定机制，可以为每一个使用该变量的线程都提供一个变量值的副本，并且每一个线程都可以独立地改变自己的副本，而不会与其它线程的副本发生冲突,以方便每个线程处理自己的状态.** 一般而言，通过 ThreadLocal 存取的数据总是与当前线程相关，也就是说，JVM 为每个运行的线程绑定了私有的本地实例存取空间，从而为多线程环境常出现的并发访问问题提供了一种 隔离机制 。

　　如果一段代码中所需要的数据必须与其他代码共享，那就看看这些共享数据的代码能否保证在同一个线程中执行？如果能保证，我们就可以把共享数据的可见范围限制在同一个线程之内，这样，无须同步也能保证线程之间不出现数据争用的问题。也就是说，如果一个某个变量要被某个线程 独享，那么我们就可以通过ThreadLocal来实现线程本地存储功能。

　　ThreadLocal 在 JDK 中的定义要点：
* 每个线程都有关于该 ThreadLocal变量 的私有值 ：每个线程都有一个独立于其他线程的上下文来保存这个变量的值，并且对其他线程是不可见的。
* 独立于变量的初始值 ：ThreadLocal 可以给定一个初始值，这样每个线程就会获得这个初始化值的一个拷贝，并且每个线程对这个值的修改对其他线程是不可见的。
* 将某个类的状态与线程相关联 ：我们从JDK中对ThreadLocal的描述中可以看出，ThreadLocal的一个重要作用是就是将类的状态与线程关联起来，这个时候通常的解决方案就是在这个类中定义一个 private static ThreadLocal 实例。

  
## 深入分析ThreadLocal类   

　　下面，我们来看一下 ThreadLocal 的具体实现，该类一共提供的四个方法：

````java
    public T get() { }
    public void set(T value) { }
    public void remove() { }
    protected T initialValue() { }
````

　　其中，get()方法是用来获取 ThreadLocal变量 在当前线程中保存的值，set() 用来设置 ThreadLocal变量 在当前线程中的值，remove() 用来移除当前线程中相关 ThreadLocal变量，initialValue() 是一个 protected 方法，一般需要重写。

### get()

````java
    public T get() {
        Thread t = Thread.currentThread();    // 获取当前线程对象
        ThreadLocalMap map = getMap(t);     // 获取当前线程的成员变量 threadLocals
        if (map != null) {
            // 从当前线程的 ThreadLocalMap 获取该 thread-local variable 对应的 entry
            ThreadLocalMap.Entry e = map.getEntry(this);    
            if (e != null)      
                return (T)e.value;   // 取得目标值
        }
        return setInitialValue();  
    }
````

### setInitialValue()

````java
    private T setInitialValue() {
        T value = initialValue();     // 默认实现返回 null
        Thread t = Thread.currentThread();   // 获得当前线程
        ThreadLocalMap map = getMap(t);     // 得到当前线程 ThreadLocalMap类型域 threadLocals
        if (map != null)
            map.set(this, value);  // 该 map 的键是当前 ThreadLocal 对象
        else
            createMap(t, value);   
        return value;
    }
````

###  initialValue()

````java
    protected T initialValue() {
        return null;            // 默认实现返回 null
    }
````

###  createMap()

````java
   void createMap(Thread t, T firstValue) {
        t.threadLocals = new ThreadLocalMap(this, firstValue); // this 指代当前 ThreadLocal 变量，为 map 的键  
    }
````

###  原理
* 每个线程内部有一个 ThreadLocal.ThreadLocalMap 类型的成员变量 threadLocals，这个 threadLocals 存储了与该线程相关的所有 ThreadLocal 变量及其对应的值（”ThreadLocal 变量及其对应的值” 就是该Map中的一个 Entry）。我们知道，Map 中存放的是一个个 Entry，其中每个 Entry 都包含一个 Key 和一个 Value。在这里，就threadLocals 而言，它的 Entry 的 Key 是 ThreadLocal 变量， Value 是该 ThreadLocal 变量对应的值；

* 初始时，在Thread里面，threadLocals为空，当通过ThreadLocal变量调用get()方法或者set()方法，就会对Thread类中的threadLocals进行初始化，并且以当前ThreadLocal变量为键值，以ThreadLocal要保存的值为value，存到 threadLocals；

* 然后在当前线程里面，如果要使用ThreadLocal对象，就可以通过get方法获得该线程的threadLocals，然后以该ThreadLocal对象为键取得其对应的 Value，也就是ThreadLocal对象中所存储的值。

## ThreadLocal的应用场景
　　在 Java 中，类 ThreadLocal 解决的是变量在不同线程间的隔离性。最常见的 ThreadLocal 使用场景有 数据库连接问题、Session管理等。

### 数据库连接问题

````java
    private static ThreadLocal<Connection> connectionHolder = new ThreadLocal<Connection>() {
        public Connection initialValue() {
           return DriverManager.getConnection(DB_URL);
      }
    };

    public static Connection getConnection() {
        return connectionHolder.get();
    }


	//Java 8
	 private static ThreadLocal<Connection> connectionHolder2 = ThreadLocal.withInitial(() -> {
        Connection conn = null;
        try {
            conn = DriverManager.getConnection("url");
        } catch (SQLException e) {
            e.printStackTrace();
        }
        return conn;
    });
````

###  Session管理

````java
    private static final ThreadLocal threadSession = new ThreadLocal();

    public static Session getSession() throws InfrastructureException {
        Session s = (Session) threadSession.get();
        try {
            if (s == null) {
                s = getSessionFactory().openSession();
                threadSession.set(s);
            }
        } catch (HibernateException ex) {
            throw new InfrastructureException(ex);
        }
        return s;
    }    
````
### SimpleDateFormat
　　大家都知道，SimpleDateFomat是线程不安全的，因为里面用了Calendar 这个成员变量来实现SimpleDataFormat,并且在Parse 和Format的时候对Calendar 进行了修改，calendar.clear()，calendar.setTime(date)。总之在多线程情况下，若是用同一个SimpleDateFormat是要出问题的
````java
public static final ThreadLocal<DateFormat> df = new ThreadLocal<DateFormat>(){
        @Override
        protected DateFormat initialValue(){
            return new SimpleDateFormat("yyyy-mm-dd");
        }
    };

	//Java 8
    public static final ThreadLocal<DateFormat> df1 = ThreadLocal.withInitial(()-> new SimpleDateFormat("yyyy-mm-dd"));

````

## ThreadLocal内存泄露问题
　　每个Thread含有的ThreadLocalMap中的Key为ThreadLocal变量的弱引用，如果一个ThreadLocal变量没有外部强引用来引用它，那么它在JVM下一次GC的时候会被垃圾回收掉，这时候，Map中就存在了key为NULL的value，这个value无法被访问。如果当前线程再迟迟不结束的话（例如当前线程在一个线程池中），那么value所指向的对象可能永远无法释放，也即不能被回收，造成内存泄露。

　　ThreadLocalMap的设计者很显然也想到了这个问题，所以其在每一次对ThreadLocalMap的set，get，remove等操作中，都会清除Map中key为null的Entry。因此，ThreadLocal一般是不会存在内存泄露风险的。

　　但是，将清除NULL对象的工作交给别人，并不是一个明智的选择，所以，在Thread中使用完ThreadLocal对象后，一定要记得调用ThreadLocal的remove方法，进行手动清除。

## ThreadLocal 一般使用步骤
　　ThreadLocal 使用步骤一般分为三步：

* 创建一个 ThreadLocal 对象 threadXxx，用来保存线程间需要隔离处理的对象 xxx；

* 提供一个获取要隔离访问的数据的方法 getXxx()，在方法中判断，若 ThreadLocal对象为null时候，应该 new() 一个隔离访问类型的对象；

* 在线程类的run()方法中，通过getXxx()方法获取要操作的数据，这样可以保证每个线程对应一个数据对象，在任何时刻都操作的是这个对象，不会交叉。