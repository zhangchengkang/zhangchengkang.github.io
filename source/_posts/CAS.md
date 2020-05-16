---
title: CAS
date: 2019-10-13 17:02:54
author: kangshifu
img: 
top: false
cover: false
coverImg: 
password: 
toc: true
mathjax: false
summary: 
categories: Java 并发
tags:
  - Java 
  - Java 并发



---


<!--more--> 



### 概述

　　　　CAS是乐观锁技术，当多个线程尝试使用CAS同时更新同一个变量时，只有其中一个线程能更新变量的值，而其它线程都失败，失败的线程并不会被挂起，而是被告知这次竞争中失败，并可以再次尝试。　　　

　　　　CAS 操作中包含三个操作数 —— 需要读写的内存位置（V）、进行比较的预期原值（A）和拟写入的新值(B)。如果内存位置V的值与预期原值A相匹配，那么处理器会自动将该位置值更新为新值B。否则处理器不做任何操作。无论哪种情况，它都会在 CAS 指令之前返回该位置的值。（在 CAS 的一些特殊情况下将仅返回 CAS 是否成功，而不提取当前值。）CAS 有效地说明了“ 我认为位置 V 应该包含值 A；如果包含该值，则将 B 放到这个位置；否则，不要更改该位置，只告诉我这个位置现在的值即可。 ”这其实和乐观锁的冲突检查+数据更新的原理是一样的。

　　　　乐观锁是一种思想。CAS是这种思想的一种实现方式。

### JAVA对CAS的支持

　　　　在JDK1.5 中新增 java.util.concurrent (J.U.C)就是建立在CAS之上的。相对于对于 synchronized 这种阻塞算法，CAS是非阻塞算法的一种常见实现。所以J.U.C在性能上有了很大的提升。

　　　　以 java.util.concurrent 中的 AtomicInteger 为例，看一下在不使用锁的情况下是如何保证线程安全的。

```java
 public class AtomicInteger extends Number implements java.io.Serializable {  
 2     private volatile int value; 
 3 
 4     public final int get() {  
 5         return value;  
 6     }  
 7 
 8     public final int getAndIncrement() {  
 9         for (;;) {  
10             int current = get();  
11             int next = current + 1;  
12             if (compareAndSet(current, next))  
13                 return current;  
14         }  
15     }  
16 
17     public final boolean compareAndSet(int expect, int update) {  
18         return unsafe.compareAndSwapInt(this, valueOffset, expect, update);  
19     }  
20 }
```

　　　　在没有锁的机制下,字段value要借助volatile原语，保证线程间的数据是可见性。这样在获取变量的值的时候才能直接读取。然后来看看 ++i 是怎么做到的。

　　　  getAndIncrement 采用了CAS操作，每次从内存中读取数据然后将此数据和 +1 后的结果进行CAS操作，如果成功就返回结果，否则重试直到成功为止。

　　　  而 compareAndSet 利用JNI（Java Native Interface）来完成CPU指令的操作 , 其中unsafe.compareAndSwapInt(this, valueOffset, expect, update);类似如下逻辑：

```java
if (this == expect) {
     this = update
     return true;
 } else {
     return false;
 }
```

### CAS缺点

#### ABA问题

　　　　CAS需要在操作值的时候，检查值有没有发生变化，如果没有发生变化则更新，但是如果一个值原来是A，变成了B，又变成了A，那么CAS进行检查的时候发现它的值没有发生变化，但是实质上它已经发生了改变 。可能会造成数据的缺失。

```
解决方法:
1. 使用版本号机制，如手动增加版本号字段
2. Java 1.5开始，JDK的Atomic包里提供了一个类AtomicStampedReference来解决ABA问题。这个类的compareAndSet方法的作用是首先检查当前引用是否等于预期引用，并且检查当前的标志是否等于预期标志，如果全部相等，则以原子方式将该应用和该标志的值设置为给定的更新值。
```



#### 自旋CAS

　　　　不成功，就一直循环执行，直到成功，如果长时间不成功，会给CPU带来非常大的执行开销。

```
解决方法
1. 破坏掉for死循环，当超过一定时间或者一定次数时，return退出。JDK8新增的LongAddr,和ConcurrentHashMap类似的方法。当多个线程竞争时，将粒度变小，将一个变量拆分为多个变量，达到多个线程访问多个资源的效果，最后再调用sum把它合起来。
2. 如果JVM能支持处理器提供的pause指令，那么效率会有一定的提升。pause指令有两个作用：第一，它可以延迟流水线执行指令（de-pipeline），使CPU不会消耗过多的执行资源，延迟的时间取决于具体实现的版本，在一些处理器上延迟时间是零；第二，它可以避免在循环的时候因内存顺序冲突（Memory Order Violation）而引起CPU流水线被清空，从而提高CPU的实行效率。
```



#### 只能保证一个共享变量的原子操作

　　　　当对一个共享变量执行操作时，我们可以使用循环CAS的方式来保证原子操作，但是对多个共享变量操作时，循环CAS就无法保证操作的原子性，

```
解决方法:
1. 用锁
2. 把多个共享变量合并成一个共享变量来操作。比如，有两个共享变量i=2,j=a,合并一下ji=2a,然后用CAS来操作ij。
3. 封装成对象。注：从Java 1.5开始，JDK提供了AtomicReference类来保证引用对象之前的原子性，可以把多个变量放在一个对象里来进行CAS操作。
```



### CAS与Synchronized的使用情景

1. 对于资源竞争较少（线程冲突较轻）的情况，使用synchronized同步锁进行线程阻塞和唤醒切换以及用户态内核态间的切换操作额外浪费消耗cpu资源；而CAS基于硬件实现，不需要进入内核，不需要切换线程，操作自旋几率较少，因此可以获得更高的性能。
2. 对于资源竞争严重（线程冲突严重）的情况，CAS自旋的概率会比较大，从而浪费更多的CPU资源，效率低于synchronized。
3.  synchronized在jdk1.6之后，已经改进优化。synchronized的底层实现主要依靠Lock-Free的队列，基本思路是自旋后阻塞，竞争切换后继续竞争锁，稍微牺牲了公平性，但获得了高吞吐量。在线程冲突较少的情况下，可以获得和CAS类似的性能；而线程冲突严重的情况下，性能远高于CAS。



















