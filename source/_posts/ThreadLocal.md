---
toc: true
title: ThreadLocal
date: 2018-07-20 20:07:33
tags: [Java 并发]
categories: JAVA
---
*Add this line to Using the more label,but it's too short to look bad,addition point length*
<!--more--> 
ThreadLocal 又名线程局部变量，是 Java 中一种较为特殊的线程绑定机制，用于保证变量在不同线程间的隔离性，以方便每个线程处理自己的状态。
## ThreadLocal 概述
　　ThreadLocal 又名 线程局部变量 ，是 Java 中一种较为特殊的线程绑定机制，可以为每一个使用该变量的线程都提供一个变量值的副本，并且每一个线程都可以独立地改变自己的副本，而不会与其它线程的副本发生冲突。一般而言，通过 ThreadLocal 存取的数据总是与当前线程相关，也就是说，JVM 为每个运行的线程绑定了私有的本地实例存取空间，从而为多线程环境常出现的并发访问问题提供了一种 隔离机制 。

　　如果一段代码中所需要的数据必须与其他代码共享，那就看看这些共享数据的代码能否保证在同一个线程中执行？如果能保证，我们就可以把共享数据的可见范围限制在同一个线程之内，这样，无须同步也能保证线程之间不出现数据争用的问题。也就是说，如果一个某个变量要被某个线程 独享，那么我们就可以通过ThreadLocal来实现线程本地存储功能。

### ThreadLocal 在 JDK 中的定义
