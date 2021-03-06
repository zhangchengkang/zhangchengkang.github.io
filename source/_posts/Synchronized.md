---
title: Synchronized
author: kangshifu
top: false
cover: false
toc: true
mathjax: false
categories: Java 并发
tags:
  - Java
  - Java 并发
abbrlink: 4124822084
date: 2018-07-12 20:17:13
img:
coverImg:
password:
summary:
---

<!--more--> 

## 线程安全问题
````java
在线程安全性的定义中，最核心的概念就是正确性。当多个线程访问某个类时，不管运行时环境采用何种调度方式或者这些线程将如何交替执行，并且在主调代码中不需要任何额外的同步或协同，这个类都能表现出正确的行为，那么这个类就是线程安全的。
````

在单线程中不会出现线程安全问题，而在多线程编程中，有可能会出现同时访问同一个 共享、可变资源 的情况，这种资源可以是：一个变量、一个对象、一个文件等。特别注意两点，
* 共享： 意味着该资源可以由多个线程同时访问
* 可变：意味着该资源可以在其生命周期内被修改
所以，当多个线程访问这种资源的时候，就会存在一个问题:由于每个线程执行的过程是不可控的，所以需要采用同步机制来协同对对象可变状态的访问。
## 如何解决线程安全问题
实际上，所有的并发模式在解决线程安全问题时，采用的方案都是 序列化访问临界资源 。即在同一时刻，只能有一个线程访问临界资源，也称作 同步互斥访问。换句话说，就是在访问临界资源的代码前面加上一个锁，当访问完临界资源后释放锁，让其他线程继续访问。
##  synchronized 同步方法
　　在了解 synchronized 关键字的使用方法之前，我们先来看一个概念：互斥锁，即 **能到达到互斥访问目的的锁**。举个简单的例子，如果对临界资源加上互斥锁，当一个线程在访问该临界资源时，其他线程便只能等待。

　　在 Java 中，可以使用 synchronized 关键字来标记一个方法或者代码块，当某个线程调用该对象的synchronized方法或者访问synchronized代码块时，这个线程便获得了该对象的锁，其他线程暂时无法访问这个方法，只有等待这个方法执行完毕或者代码块执行完毕，这个线程才会释放该对象的锁，其他线程才能执行这个方法或者代码块。
* 当一个线程正在访问一个对象的 synchronized 方法，那么其他线程不能访问该对象的其他 synchronized 方法。这个原因很简单，因为一个对象只有一把锁，当一个线程获取了该对象的锁之后，其他线程无法获取该对象的锁，所以无法访问该对象的其他synchronized方法。
* 当一个线程正在访问一个对象的 synchronized 方法，那么其他线程能访问该对象的非 synchronized 方法。这个原因很简单，访问非 synchronized 方法不需要获得该对象的锁，假如一个方法没用 synchronized 关键字修饰，说明它不会使用到临界资源，那么其他线程是可以访问这个方法的.
* 如果一个线程 A 需要访问对象 object1 的 synchronized 方法 fun1，另外一个线程 B 需要访问对象 object2 的 synchronized 方法 fun1，即使 object1 和 object2 是同一类型），也不会产生线程安全问题，因为他们访问的是不同的对象，所以不存在互斥问题。

##  synchronized 同步代码块
````
synchronized (lock){
    //访问共享可变资源
    ...
}
````
　　当在某个线程中执行这段代码块，该线程会获取对象的锁，从而使得其他线程无法同时访问该代码块。其中，括号内可以是 this，代表获取当前对象的锁，也可以是类中的一个属性，代表获取该属性的锁。特别地， 实例同步方法 与 synchronized(this)同步块 是互斥的，因为它们锁的是同一个对象。但与 synchronized(非this)同步块 是异步的，因为它们锁的是不同对象。
　　synchronized代码块 比 synchronized方法 的粒度更细一些，使用起来也灵活得多。因为也许一个方法中只有一部分代码只需要同步，如果此时对整个方法用synchronized进行同步，会影响程序执行效率。而使用synchronized代码块就可以避免这个问题，synchronized代码块可以实现只对需要同步的地方进行同步。

##  class对象锁
　　特别地，每个类也会有一个锁，静态的 synchronized方法 就是以Class对象作为锁。另外，它可以用来控制对 static 数据成员 （static 数据成员不专属于任何一个对象，是类成员） 的并发访问。并且，如果一个线程执行一个对象的非static synchronized 方法，另外一个线程需要执行这个对象所属类的 static synchronized 方法，也不会发生互斥现象。因为访问 static synchronized 方法占用的是类锁，而访问非 static synchronized 方法占用的是对象锁，所以不存在互斥现象。
## 总结
**用一句话来说，synchronized 内置锁 是一种 对象锁 (锁的是对象而非引用)， 作用粒度是对象 ，可以用来实现对 临界资源的同步互斥访问 ，是 可重入 的。**
* 若临界资源是静态的，即被 static 关键字修饰，那么访问它的方法必须是同步且是静态的，synchronized 块必须是 class锁；
* 若临界资源是非静态的，即没有被 static 关键字修饰，那么访问它的方法必须是同步的，synchronized 块是实例对象锁； 
* 对于 synchronized方法 或者 synchronized代码块，当出现异常时，JVM会自动释放当前线程占用的锁，因此不会由于异常导致出现死锁现象。　　